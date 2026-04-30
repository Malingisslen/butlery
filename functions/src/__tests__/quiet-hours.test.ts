/**
 * BUT-647: Server-side quiet-hours gate.
 *
 * Coverage:
 *   1. Inside-window low-importance push is DROPPED (no enqueue).
 *   2. Inside-window high-importance push is DELAYED (enqueued).
 *   3. Outside-window: gate proceeds regardless of importance.
 *   4. DST boundary: spring-forward in Europe/Stockholm doesn't break the
 *      window check.
 *   5. Missing prefs doc: gate proceeds (default-allow, don't black-hole).
 *   6. User-set timezone (America/New_York) vs UTC: window evaluated in
 *      the user's local tz.
 *   7. RC flag disabled (notifications.enabled.<type> = false): drop.
 *
 * Run with: npx ts-node src/__tests__/quiet-hours.test.ts
 */

import { evaluateSendGate } from "../shared/notification-gate";
import { __resetRcFlagsCacheForTests } from "../shared/notification-rc-flags";
import { isInWindow, localHourMinute, QuietHoursConfig } from "../shared/quiet-hours";

interface EnqueueCall {
  userId: string;
  notificationType: string;
  deliverAt: Date;
  payload: { title: string; body: string; data: Record<string, string> };
}

interface RecordCall {
  userId: string;
  notificationType: string;
  channel: string;
}

interface State {
  enqueues: EnqueueCall[];
  recordCalls: RecordCall[];
}

function makeState(): State {
  return { enqueues: [], recordCalls: [] };
}

function makeDeps(state: State, prefs: Partial<QuietHoursConfig> | null) {
  return {
    rcDeps: {
      loader: async () => ({}),
      now: () => Date.now(),
      ttlMs: 1000,
    },
    quietHoursLoader: async () =>
      ({
        timezone: prefs?.timezone ?? "Europe/Stockholm",
        start: prefs?.start ?? null,
        end: prefs?.end ?? null,
        enabled: Boolean(prefs?.start && prefs?.end),
      }) as QuietHoursConfig,
    enqueue: async (opts: EnqueueCall) => {
      state.enqueues.push(opts);
      return "fake-doc-id";
    },
    recordEvent: async (opts: RecordCall) => {
      state.recordCalls.push(opts);
    },
  };
}

let totalRun = 0;
let totalFailed = 0;

function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

async function testCase1InsideWindowLowImportanceDrops(): Promise<void> {
  __resetRcFlagsCacheForTests();
  const state = makeState();
  // 23:30 UTC winter → 00:30 Stockholm, inside 22:00-08:00.
  const now = new Date("2026-01-15T23:30:00Z");
  const decision = await evaluateSendGate({
    userId: "u1",
    notificationType: "win_back_mild", // low importance
    payload: { title: "t", body: "b", data: {} },
    now,
    ...makeDeps(state, {
      start: { hour: 22, minute: 0 },
      end: { hour: 8, minute: 0 },
    }),
  });
  const ok =
    decision.action === "dropped" &&
    state.enqueues.length === 0 &&
    state.recordCalls.length === 0;
  record(
    "inside-window low-importance push is DROPPED",
    ok,
    `action=${decision.action} enqueues=${state.enqueues.length} record=${state.recordCalls.length}`
  );
}

async function testCase2InsideWindowHighImportanceDelays(): Promise<void> {
  __resetRcFlagsCacheForTests();
  const state = makeState();
  const now = new Date("2026-01-15T23:30:00Z"); // 00:30 Stockholm
  const decision = await evaluateSendGate({
    userId: "u2",
    notificationType: "comment_posted", // high importance
    payload: { title: "t", body: "b", data: { route: "/comment_thread" } },
    now,
    ...makeDeps(state, {
      start: { hour: 22, minute: 0 },
      end: { hour: 8, minute: 0 },
    }),
  });
  const ok =
    decision.action === "delayed" &&
    state.enqueues.length === 1 &&
    state.recordCalls.length === 1 &&
    state.recordCalls[0].channel === "scheduled_queue" &&
    decision.deliverAt instanceof Date;
  record(
    "inside-window high-importance push is DELAYED + enqueued",
    ok,
    `action=${decision.action} enqueues=${state.enqueues.length} ` +
      `record=${state.recordCalls.length} channel=${state.recordCalls[0]?.channel}`
  );
}

async function testCase3OutsideWindowProceeds(): Promise<void> {
  __resetRcFlagsCacheForTests();
  const state = makeState();
  // 14:00 UTC winter → 15:00 Stockholm, outside 22:00-08:00.
  const now = new Date("2026-01-15T14:00:00Z");
  const decision = await evaluateSendGate({
    userId: "u3",
    notificationType: "win_back_mild",
    payload: { title: "t", body: "b", data: {} },
    now,
    ...makeDeps(state, {
      start: { hour: 22, minute: 0 },
      end: { hour: 8, minute: 0 },
    }),
  });
  const ok = decision.action === "proceed" && state.enqueues.length === 0;
  record(
    "outside-window pushes PROCEED",
    ok,
    `action=${decision.action} enqueues=${state.enqueues.length}`
  );
}

async function testCase4DstBoundary(): Promise<void> {
  // 2026-03-29 02:00 Europe/Stockholm jumps to 03:00 (CET → CEST).
  // At 02:30 UTC on that day, local time is 04:30 CEST. Quiet window
  // 22:00-04:00 should still resolve — 04:30 is OUTSIDE the window
  // (window ends at 04:00 local).
  __resetRcFlagsCacheForTests();
  const state = makeState();
  const now = new Date("2026-03-29T02:30:00Z");
  const decision = await evaluateSendGate({
    userId: "u4",
    notificationType: "win_back_mild",
    payload: { title: "t", body: "b", data: {} },
    now,
    ...makeDeps(state, {
      start: { hour: 22, minute: 0 },
      end: { hour: 4, minute: 0 },
    }),
  });
  // Verify the local-time computation lands at 04:30 CEST.
  const local = localHourMinute(now, "Europe/Stockholm");
  const localCorrect = local.hour === 4 && local.minute === 30;
  const ok = decision.action === "proceed" && localCorrect;
  record(
    "DST boundary: 02:30 UTC is 04:30 CEST (outside 22:00-04:00)",
    ok,
    `local=${local.hour}:${local.minute} action=${decision.action}`
  );
}

async function testCase5MissingPrefsDefaultAllow(): Promise<void> {
  __resetRcFlagsCacheForTests();
  const state = makeState();
  const now = new Date("2026-01-15T23:30:00Z"); // would be inside if prefs existed
  const decision = await evaluateSendGate({
    userId: "u5",
    notificationType: "win_back_mild",
    payload: { title: "t", body: "b", data: {} },
    now,
    ...makeDeps(state, null), // no quiet hours configured
  });
  const ok = decision.action === "proceed";
  record(
    "missing prefs / no quiet hours configured → PROCEED (don't black-hole)",
    ok,
    `action=${decision.action}`
  );
}

async function testCase6UserTimezoneOverridesUtc(): Promise<void> {
  __resetRcFlagsCacheForTests();
  const state = makeState();
  // 03:00 UTC. In NY (EST UTC-5) that's 22:00 local — inside 22:00-08:00.
  // Same UTC time in Stockholm (CET UTC+1) is 04:00 — also inside, but
  // the test specifically validates the per-user timezone is respected:
  // we'll use a window that's only quiet in NY.
  // Window 22:00-23:30 — at 03:00 UTC: NY=22:00 (inside), Stockholm=04:00 (outside).
  const now = new Date("2026-01-15T03:00:00Z");
  const decision = await evaluateSendGate({
    userId: "u6",
    notificationType: "win_back_mild",
    payload: { title: "t", body: "b", data: {} },
    now,
    ...makeDeps(state, {
      timezone: "America/New_York",
      start: { hour: 22, minute: 0 },
      end: { hour: 23, minute: 30 },
    }),
  });
  const ok = decision.action === "dropped";
  record(
    "user-set timezone (America/New_York) is honored over UTC",
    ok,
    `action=${decision.action}`
  );
}

async function testCase7RcFlagDisabledDrops(): Promise<void> {
  __resetRcFlagsCacheForTests();
  const state = makeState();
  const now = new Date("2026-01-15T14:00:00Z"); // outside any window
  const decision = await evaluateSendGate({
    userId: "u7",
    notificationType: "win_back_mild",
    payload: { title: "t", body: "b", data: {} },
    now,
    rcDeps: {
      // RC says win_back_mild is disabled.
      loader: async () => ({
        "notifications.enabled.win_back_mild": "false",
      }),
      now: () => Date.now(),
      ttlMs: 1000,
    },
    quietHoursLoader: async () => ({
      timezone: "Europe/Stockholm",
      start: null,
      end: null,
      enabled: false,
    }),
    enqueue: async (opts) => {
      state.enqueues.push(opts);
      return "x";
    },
    recordEvent: async (opts) => {
      state.recordCalls.push(opts);
    },
  });
  const ok = decision.action === "type_disabled";
  record(
    "RC flag notifications.enabled.<type>=false → type_disabled",
    ok,
    `action=${decision.action}`
  );
}

async function unitInWindowWrap(): Promise<void> {
  const ok = isInWindow(
    { hour: 0, minute: 30 },
    { hour: 22, minute: 0 },
    { hour: 8, minute: 0 }
  );
  record("isInWindow handles wrap-around 22:00→08:00 at 00:30", ok);
}

async function runAll(): Promise<void> {
  console.log("BUT-647: Quiet-hours server-side gate tests\n");
  console.log("============================================\n");
  await testCase1InsideWindowLowImportanceDrops();
  await testCase2InsideWindowHighImportanceDelays();
  await testCase3OutsideWindowProceeds();
  await testCase4DstBoundary();
  await testCase5MissingPrefsDefaultAllow();
  await testCase6UserTimezoneOverridesUtc();
  await testCase7RcFlagDisabledDrops();
  await unitInWindowWrap();

  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : "")
  );
  if (totalFailed > 0) process.exit(1);
}

runAll().catch((err) => {
  console.error(err);
  process.exit(1);
});
