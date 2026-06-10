/**
 * Sprint C3 (2026-04-25): Activity-digest push respects prefs + quiet hours.
 *
 * Before this sprint, `send-activity-digest.ts` called `sendPushToUser`
 * directly, bypassing the master toggle and Europe/Stockholm quiet-hours
 * window introduced in BUT-438.  After this sprint the digest path goes
 * through `sendPushToUserRespectingPreferences` so all three gates apply:
 *
 *   1. Master `enabled` toggle on `user_notification_preferences/{uid}`
 *   2. Quiet hours (Stockholm wall-clock, DST-safe via `Intl`)
 *   3. Token availability (no active FCM token → not counted as sent)
 *
 * The category gate for digest is the existing `digestFrequency !== 'never'`
 * check in the scheduler itself; the helper's category param is wired to
 * `reEngagement` because that is the only literal the BUT-438 contract
 * exposes.  We don't run the full scheduler trigger end-to-end (that needs
 * the emulator); instead we exercise the same `sendPushToUserRespectingPreferences`
 * surface the scheduler now funnels through, which is the only line that
 * changed.
 *
 * Run with: npx ts-node src/__tests__/send-activity-digest.test.ts
 */

import {
  sendPushToUserRespectingPreferences,
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
    // BUT-1223: stub the rate-cap seam — the real checkAndIncrement opens a
    // Firestore transaction via admin.firestore() (no app in unit env).
    checkRateCap: async () => ({
      allowed: true,
      count: 0,
      cap: 10,
      reason: "ok" as const,
    }),
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
const WINTER_AFTERNOON_UTC = "2026-01-19T14:00:00Z"; // a Monday at 15:00 CET
// 23:30 UTC on a winter day → 00:30 Stockholm next day, inside 22:00-08:00.
const WINTER_LATE_NIGHT_UTC = "2026-01-19T23:30:00Z";

const scenarios: Scenario[] = [
  {
    name: "digest sends when prefs allow (master on, weekly digest, daytime)",
    prefs: {
      enabled: true,
      digestFrequency: "weekly",
      quietHoursStart: { hour: 22, minute: 0 },
      quietHoursEnd: { hour: 8, minute: 0 },
    },
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: true,
    expectReason: "sent",
  },
  {
    name: "digest is BLOCKED when master enabled=false",
    prefs: {
      enabled: false,
      digestFrequency: "weekly",
    },
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: false,
    expectReason: "master_disabled",
  },
  {
    name: "digest is BLOCKED during Europe/Stockholm quiet hours",
    prefs: {
      enabled: true,
      digestFrequency: "weekly",
      quietHoursStart: { hour: 22, minute: 0 },
      quietHoursEnd: { hour: 8, minute: 0 },
    },
    nowUtcIso: WINTER_LATE_NIGHT_UTC,
    expectSent: false,
    expectReason: "quiet_hours",
  },
  {
    name: "digest sends when prefs doc is missing (defaults to opted-in)",
    prefs: null,
    nowUtcIso: WINTER_AFTERNOON_UTC,
    expectSent: true,
    expectReason: "sent",
  },
];

async function runTests(): Promise<void> {
  console.log("Sprint C3: Activity-digest preference-aware push tests\n");
  console.log("======================================================\n");

  let failed = 0;

  for (const s of scenarios) {
    const sends: SendCall[] = [];
    const deps = makeDeps(s.prefs, s.nowUtcIso, sends);
    const result = await sendPushToUserRespectingPreferences(
      "user-digest-1",
      {
        title: "Veckans sammanfattning",
        body: "Du hade 3 aktiviteter den här veckan",
      },
      "reEngagement",
      { type: "activity_digest" },
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

  const total = scenarios.length;
  console.log(
    `\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

runTests().catch((err) => {
  console.error(err);
  process.exit(1);
});
