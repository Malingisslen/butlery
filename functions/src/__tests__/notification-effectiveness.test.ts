/**
 * BUT-645: Per-type effectiveness tracking + auto-suppression tests.
 *
 * Coverage:
 *   1. RC flag honored (true) → enabled.
 *   2. RC flag honored (false) → disabled.
 *   3. RC flag missing → defaults to enabled (fail-open).
 *   4. RC fetch failure → defaults to enabled (fail-open).
 *   5. CTR threshold edge cases:
 *        a. 49 sends ignored (below MIN_SENDS).
 *        b. 50 sends with 0.04 CTR triggers a flip.
 *        c. 50 sends with 0.10 CTR is a no-op.
 *   6. Auto-suppression idempotent — already-disabled type does not re-flip.
 *
 * Run with: npx ts-node src/__tests__/notification-effectiveness.test.ts
 */

import {
  isNotificationTypeEnabled,
  __resetRcFlagsCacheForTests,
  RC_FLAG_PREFIX,
} from "../shared/notification-rc-flags";
import {
  runSuppressLowPerformers,
  MIN_SENDS,
  CTR_THRESHOLD,
} from "../analytics/suppress-low-performers";
import { runRecordNotificationOpened } from "../notifications/record-notification-opened";

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

// =============================================================================
// RC flag tests
// =============================================================================

async function rcFlagTrue(): Promise<void> {
  __resetRcFlagsCacheForTests();
  const enabled = await isNotificationTypeEnabled("comment_posted", {
    loader: async () => ({
      [`${RC_FLAG_PREFIX}comment_posted`]: "true",
    }),
    now: () => Date.now(),
    ttlMs: 1000,
  });
  record("RC flag set to true → enabled", enabled === true);
}

async function rcFlagFalse(): Promise<void> {
  __resetRcFlagsCacheForTests();
  const enabled = await isNotificationTypeEnabled("comment_posted", {
    loader: async () => ({
      [`${RC_FLAG_PREFIX}comment_posted`]: "false",
    }),
    now: () => Date.now(),
    ttlMs: 1000,
  });
  record("RC flag set to false → disabled", enabled === false);
}

async function rcFlagMissingDefaultsTrue(): Promise<void> {
  __resetRcFlagsCacheForTests();
  const enabled = await isNotificationTypeEnabled("brand_new_type", {
    loader: async () => ({}),
    now: () => Date.now(),
    ttlMs: 1000,
  });
  record(
    "RC flag missing for type → defaults to enabled (fail-open)",
    enabled === true
  );
}

async function rcFetchFailureFailsOpen(): Promise<void> {
  __resetRcFlagsCacheForTests();
  const enabled = await isNotificationTypeEnabled("comment_posted", {
    loader: async () => {
      throw new Error("simulated RC outage");
    },
    now: () => Date.now(),
    ttlMs: 1000,
  });
  record("RC fetch failure → fail-open (enabled)", enabled === true);
}

// =============================================================================
// Suppression tests — exercise runSuppressLowPerformers with a fake DB
// =============================================================================

interface FakeDoc {
  data(): Record<string, unknown>;
}

interface FakeQuery {
  get(): Promise<{ docs: FakeDoc[] }>;
}

interface FakeCol {
  where: (field: string, op: string, value: unknown) => FakeQuery;
}

/**
 * Builds a fake `db` that returns synthetic send/open events. The fake
 * collection is hard-coded by name; queries chain through `where` and
 * we just return all the docs the case constructed.
 */
function makeFakeDb(
  sends: Array<{ type: string }>,
  opens: Array<{ type: string }>
): { collection: (name: string) => FakeCol } {
  return {
    collection(name: string): FakeCol {
      let docs: FakeDoc[];
      if (name === "notification_send_events") {
        docs = sends.map((s) => ({
          data: () => ({ notificationType: s.type }),
        }));
      } else if (name === "notification_opened_events") {
        docs = opens.map((o) => ({
          data: () => ({ notificationType: o.type }),
        }));
      } else {
        docs = [];
      }
      const fakeQuery: FakeQuery = {
        async get() {
          return { docs };
        },
      };
      // Chained .where(...) returns the same fake query.
      const col: FakeCol = {
        where: () => fakeQuery,
      };
      return col;
    },
  };
}

async function ctr49SendsIgnored(): Promise<void> {
  const sends = Array(MIN_SENDS - 1).fill({ type: "win_back_mild" });
  const opens: Array<{ type: string }> = []; // 0 opens
  const flips: Array<{ type: string; enabled: boolean }> = [];
  const result = await runSuppressLowPerformers({
    db: makeFakeDb(sends, opens) as never,
    now: new Date("2026-01-15T00:00:00Z"),
    isEnabled: async () => true,
    flipFlag: async (type, enabled) => {
      flips.push({ type, enabled });
    },
  });
  const ok = result.flipped === 0 && flips.length === 0;
  record(
    "49 sends + 0 opens (below MIN_SENDS) → ignored, no flip",
    ok,
    `flipped=${result.flipped} flips=${flips.length}`
  );
}

async function ctr50Sends004Triggers(): Promise<void> {
  // 50 sends, 2 opens → CTR = 0.04 < 0.05.
  const sends = Array(50).fill({ type: "win_back_mild" });
  const opens = Array(2).fill({ type: "win_back_mild" });
  const flips: Array<{ type: string; enabled: boolean }> = [];
  const result = await runSuppressLowPerformers({
    db: makeFakeDb(sends, opens) as never,
    now: new Date("2026-01-15T00:00:00Z"),
    isEnabled: async () => true,
    flipFlag: async (type, enabled) => {
      flips.push({ type, enabled });
    },
  });
  const ok =
    result.flipped === 1 &&
    flips.length === 1 &&
    flips[0].type === "win_back_mild" &&
    flips[0].enabled === false;
  record(
    `50 sends + 2 opens (CTR=0.04 < ${CTR_THRESHOLD}) → flag flipped to disabled`,
    ok,
    `flipped=${result.flipped} flip=${JSON.stringify(flips[0])}`
  );
}

async function ctr50Sends010Noop(): Promise<void> {
  // 50 sends, 5 opens → CTR = 0.10 >= 0.05.
  const sends = Array(50).fill({ type: "win_back_mild" });
  const opens = Array(5).fill({ type: "win_back_mild" });
  const flips: Array<{ type: string; enabled: boolean }> = [];
  const result = await runSuppressLowPerformers({
    db: makeFakeDb(sends, opens) as never,
    now: new Date("2026-01-15T00:00:00Z"),
    isEnabled: async () => true,
    flipFlag: async (type, enabled) => {
      flips.push({ type, enabled });
    },
  });
  const ok = result.flipped === 0 && flips.length === 0;
  record(
    `50 sends + 5 opens (CTR=0.10 >= ${CTR_THRESHOLD}) → no flip`,
    ok,
    `flipped=${result.flipped}`
  );
}

/**
 * **Regression guard for security-review C1**: the original bug was that
 * `suppressLowPerformers` read `notification_opened_events` but no code
 * wrote it — CTR was 0/N for every type, every type got auto-disabled
 * within a week. This test wires the real producer
 * (`runRecordNotificationOpened`) to a fake DB shared with the consumer
 * (`runSuppressLowPerformers`) and verifies that a healthy CTR
 * (50 sends, 10 opens via the actual writer) does NOT trigger a flip.
 *
 * If anyone removes the writer in the future, this test goes red because
 * `runSuppressLowPerformers` will see 0 opens and try to disable
 * `comment_posted` — exactly the production bug we're guarding against.
 */
async function producerConsumerEndToEnd(): Promise<void> {
  // Shared fake DB: writes from the producer land in `openedDocs`,
  // reads from the consumer surface them under
  // `notification_opened_events`. Sends are pre-populated.
  const sends: Array<{ type: string }> = Array(50).fill({
    type: "comment_posted",
  });

  // openedDocs path → data
  const openedDocs = new Map<string, Record<string, unknown>>();

  // Producer-side fake (matches the shape `recordNotificationOpened` uses).
  const producerDb = {
    collection(_name: string) {
      return {
        doc(docId: string) {
          const path = `notification_opened_events/${docId}`;
          return {
            async get() {
              return { exists: openedDocs.has(path), data: () => ({}) };
            },
            async set(d: Record<string, unknown>) {
              openedDocs.set(path, d);
            },
          };
        },
      };
    },
  };

  // 10 distinct opens (CTR = 0.20, well above 0.05 threshold).
  for (let i = 0; i < 10; i++) {
    await runRecordNotificationOpened(
      `user-${i}`,
      {
        notificationId: `msg-${i}`,
        notificationType: "comment_posted",
      },
      { db: producerDb as never }
    );
  }

  // Consumer-side fake (matches the shape `runSuppressLowPerformers`
  // uses). Reads sends (synthetic) + opens (from the producer's writes).
  const opens = Array.from(openedDocs.values()).map((d) => ({
    type: d.notificationType as string,
  }));
  const flips: Array<{ type: string; enabled: boolean }> = [];
  const result = await runSuppressLowPerformers({
    db: makeFakeDb(sends, opens) as never,
    now: new Date("2026-04-30T00:00:00Z"),
    isEnabled: async () => true,
    flipFlag: async (type, enabled) => {
      flips.push({ type, enabled });
    },
  });

  const ok =
    openedDocs.size === 10 &&
    opens.length === 10 &&
    result.flipped === 0 &&
    flips.length === 0;
  record(
    "producer→consumer end-to-end: real opens via writer → CTR 0.20 → no flip " +
      "(regression guard for the producerless-aggregator bug)",
    ok,
    `producerWrites=${openedDocs.size} consumerOpens=${opens.length} ` +
      `flipped=${result.flipped}`
  );
}

async function autoSuppressIdempotent(): Promise<void> {
  // 50 sends, 2 opens, but the type is ALREADY disabled. Should not
  // re-flip — `flipFlag` must not be called.
  const sends = Array(50).fill({ type: "win_back_mild" });
  const opens = Array(2).fill({ type: "win_back_mild" });
  const flips: Array<{ type: string; enabled: boolean }> = [];
  const result = await runSuppressLowPerformers({
    db: makeFakeDb(sends, opens) as never,
    now: new Date("2026-01-15T00:00:00Z"),
    isEnabled: async () => false, // already disabled
    flipFlag: async (type, enabled) => {
      flips.push({ type, enabled });
    },
  });
  const ok = result.flipped === 0 && flips.length === 0;
  record(
    "auto-suppression idempotent: already-disabled type is NOT re-flipped",
    ok,
    `flipped=${result.flipped} flips=${flips.length}`
  );
}

async function runAll(): Promise<void> {
  console.log("BUT-645: Notification effectiveness + suppression tests\n");
  console.log("=========================================================\n");
  await rcFlagTrue();
  await rcFlagFalse();
  await rcFlagMissingDefaultsTrue();
  await rcFetchFailureFailsOpen();
  await ctr49SendsIgnored();
  await ctr50Sends004Triggers();
  await ctr50Sends010Noop();
  await autoSuppressIdempotent();
  await producerConsumerEndToEnd();

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
