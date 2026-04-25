/**
 * BUT-438: Preference-aware win-back push tests.
 *
 * The detect-lapsed-users scheduled function used to call sendPushToUser
 * directly, bypassing the preference gate. The new contract:
 *   - Opted-out user (master toggle off OR reEngagement=false) → NOT pinged.
 *   - User inside quiet hours (Stockholm time) → NOT pinged.
 *   - User with no token / token failure → NOT counted as sent.
 *   - Normal user, awake, opted in → pinged.
 *
 * We don't run the scheduler trigger end-to-end — that needs the emulator
 * suite. Instead we exercise the preference-aware helper directly with a
 * fake firestore + fake clock, which is the same surface the trigger now
 * funnels through.
 *
 * Run with: npx ts-node src/__tests__/detect-lapsed-users.test.ts
 */

import {
  sendPushToUserRespectingPreferences,
  isInQuietWindow,
  stockholmHourMinute,
} from "../shared/preference-aware-push";

interface SendCall {
  userId: string;
  title: string;
  body: string;
  data?: Record<string, string>;
}

interface Scenario {
  name: string;
  prefs: Record<string, unknown> | null;
  /** UTC time the test should pretend "now" is. */
  nowUtcIso: string;
  expectSent: boolean;
  expectReason: string;
}

function makeDeps(
  prefs: Record<string, unknown> | null,
  nowUtcIso: string,
  sends: SendCall[]
) {
  return {
    getPreferences: async (_userId: string) => prefs,
    getNow: () => new Date(nowUtcIso),
    send: async (
      userId: string,
      notification: { title: string; body: string },
      data?: Record<string, string>
    ) => {
      sends.push({
        userId,
        title: notification.title,
        body: notification.body,
        data,
      });
      return { successCount: 1, failureCount: 0 };
    },
  };
}

// 14:00 UTC on a non-DST winter day → 15:00 Europe/Stockholm (CET, UTC+1).
const WINTER_AFTERNOON_UTC = "2026-01-15T14:00:00Z";
// 23:30 UTC on a winter day → 00:30 Stockholm next day, inside 22:00-08:00.
const WINTER_LATE_NIGHT_UTC = "2026-01-15T23:30:00Z";

const scenarios: Scenario[] = [
  {
    name: "opted-out user (reEngagement=false) is NOT pinged",
    prefs: {
      enabled: true,
      reEngagement: false,
      quietHoursStart: { hour: 22, minute: 0 },
      quietHoursEnd: { hour: 8, minute: 0 },
    },
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: false,
    expectReason: "opted_out",
  },
  {
    name: "master-disabled user is NOT pinged",
    prefs: {
      enabled: false,
      reEngagement: true,
    },
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: false,
    expectReason: "master_disabled",
  },
  {
    name: "user inside quiet hours is NOT pinged",
    prefs: {
      enabled: true,
      reEngagement: true,
      quietHoursStart: { hour: 22, minute: 0 },
      quietHoursEnd: { hour: 8, minute: 0 },
    },
    nowUtcIso: WINTER_LATE_NIGHT_UTC,
    expectSent: false,
    expectReason: "quiet_hours",
  },
  {
    name: "normal opted-in user during the day IS pinged",
    prefs: {
      enabled: true,
      reEngagement: true,
      quietHoursStart: { hour: 22, minute: 0 },
      quietHoursEnd: { hour: 8, minute: 0 },
    },
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: true,
    expectReason: "sent",
  },
  {
    name: "user with no preferences doc defaults to opted-in",
    prefs: null,
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: true,
    expectReason: "sent",
  },
  {
    name: "fallback: explicit category opt-out via NotificationCategory.system",
    prefs: {
      enabled: true,
      // reEngagement field absent — falls back to categorySettings entry.
      categorySettings: { "NotificationCategory.system": false },
    },
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: false,
    expectReason: "opted_out",
  },
];

interface UnitCase {
  name: string;
  fn: () => void;
}

const unitCases: UnitCase[] = [
  {
    name: "isInQuietWindow handles wrap-around 22:00-08:00 at 00:30",
    fn: () => {
      const inWindow = isInQuietWindow(
        { hour: 0, minute: 30 },
        { hour: 22, minute: 0 },
        { hour: 8, minute: 0 }
      );
      if (!inWindow) throw new Error("00:30 should be inside 22:00-08:00");
    },
  },
  {
    name: "isInQuietWindow excludes 15:00 from 22:00-08:00",
    fn: () => {
      const inWindow = isInQuietWindow(
        { hour: 15, minute: 0 },
        { hour: 22, minute: 0 },
        { hour: 8, minute: 0 }
      );
      if (inWindow) throw new Error("15:00 should NOT be inside 22:00-08:00");
    },
  },
  {
    name: "isInQuietWindow handles same-day 13:00-14:00 correctly",
    fn: () => {
      const inWindow = isInQuietWindow(
        { hour: 13, minute: 30 },
        { hour: 13, minute: 0 },
        { hour: 14, minute: 0 }
      );
      if (!inWindow) throw new Error("13:30 should be inside 13:00-14:00");
    },
  },
  {
    name: "isInQuietWindow with equal start/end is empty (never quiet)",
    fn: () => {
      const inWindow = isInQuietWindow(
        { hour: 12, minute: 0 },
        { hour: 12, minute: 0 },
        { hour: 12, minute: 0 }
      );
      if (inWindow) throw new Error("equal start/end should be never quiet");
    },
  },
  {
    name: "stockholmHourMinute converts 14:00 UTC winter to 15:00 CET",
    fn: () => {
      const out = stockholmHourMinute(new Date(WINTER_AFTERNOON_UTC));
      if (out.hour !== 15 || out.minute !== 0) {
        throw new Error(
          `expected 15:00 Europe/Stockholm, got ${out.hour}:${out.minute}`
        );
      }
    },
  },
  {
    name: "stockholmHourMinute converts 23:30 UTC winter to 00:30 next day CET",
    fn: () => {
      const out = stockholmHourMinute(new Date(WINTER_LATE_NIGHT_UTC));
      if (out.hour !== 0 || out.minute !== 30) {
        throw new Error(
          `expected 00:30 Europe/Stockholm, got ${out.hour}:${out.minute}`
        );
      }
    },
  },
];

async function runTests(): Promise<void> {
  console.log("BUT-438: Preference-aware win-back push tests\n");
  console.log("==============================================\n");

  let failed = 0;

  for (const c of unitCases) {
    try {
      c.fn();
      console.log(`  PASS  ${c.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${c.name}`);
      console.log(`        ${err instanceof Error ? err.message : err}`);
    }
  }

  for (const s of scenarios) {
    const sends: SendCall[] = [];
    const deps = makeDeps(s.prefs, s.nowUtcIso, sends);
    const result = await sendPushToUserRespectingPreferences(
      "user-123",
      { title: "Butlery", body: "Vi saknar dig!" },
      "reEngagement",
      { type: "win_back_mild" },
      deps
    );

    const sentMatch = result.sent === s.expectSent;
    const reasonMatch = result.reason === s.expectReason;
    const sendCountMatch = s.expectSent
      ? sends.length === 1
      : sends.length === 0;

    if (sentMatch && reasonMatch && sendCountMatch) {
      console.log(`  PASS  ${s.name}`);
    } else {
      failed++;
      console.log(`  FAIL  ${s.name}`);
      console.log(
        `        expected sent=${s.expectSent} reason=${s.expectReason}, ` +
          `got sent=${result.sent} reason=${result.reason}, ` +
          `send-call count=${sends.length}`
      );
    }
  }

  const total = unitCases.length + scenarios.length;
  console.log(
    `\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error(err);
  process.exit(1);
});
