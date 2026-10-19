/**
 * Firestore rules tests that send the REAL payload of two writers whose
 * allowlists drifted on 2026-08-12 (BUT-1482) and were then guarded only by a
 * text comparison (`rules_allowlist_drift_test.dart`) — which proves an
 * allowlist's content matches its writer, not that the allowlist is evaluated.
 *
 *   - `notification_history`: `recordNotification` (create),
 *     `markNotificationDelivered` and `markNotificationOpened` (updates).
 *   - `deep_links/{id}/clicks`: the `.add` in `trackUrlClick`.
 *
 * The `users/{uid}/counters` writer has its own suite
 * (`shared-content-counters-rules.test.ts`).
 *
 * Each allow case has a deny control that differs from it by exactly one
 * thing, so a deny cannot pass for a second reason: the allowlist is what is
 * being exercised, not an auth or ownership check beside it.
 *
 * Prerequisite: Firestore emulator on 127.0.0.1:8080.
 * Run with: npm run test:rules:writer-payloads
 */

import * as fs from "fs";
import * as http from "http";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { serverTimestamp, Timestamp } from "firebase/firestore";

// MUTATION-PROBE SEAM (same contract as poll-votes-rules.test.ts).
const PROJECT_ID = process.env.PROBE_PROJECT_ID ?? "butlery-rules-writer-payloads";
const RULES_PATH =
  process.env.PROBE_RULES_PATH ??
  path.resolve(__dirname, "../../../firestore.rules");

const UID = "wp-user-uid";
const OTHER_UID = "wp-other-uid";
const NOTIFICATION_ID = "wp-notification";
const LINK_ID = "wp-link";

let env: RulesTestEnvironment;

function clearFirestore(): Promise<void> {
  return new Promise((resolve, reject) => {
    const req = http.request(
      {
        host: "127.0.0.1",
        port: 8080,
        method: "DELETE",
        path: `/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
      },
      (res) => {
        res.on("data", () => undefined);
        res.on("end", resolve);
      }
    );
    req.on("error", reject);
    req.end();
  });
}

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await clearFirestore();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

const historyDoc = () =>
  env
    .authenticatedContext(UID)
    .firestore()
    .doc(`notification_history/${NOTIFICATION_ID}`);

/** `recordNotification` verbatim: the nine keys it sets, no more. */
function recordedPayload(): Record<string, unknown> {
  return {
    userId: UID,
    notificationId: NOTIFICATION_ID,
    category: "social",
    type: "friendRequest",
    data: { a: "b" },
    sentAt: serverTimestamp(),
    expireAt: Timestamp.fromDate(new Date(Date.now() + 90 * 24 * 3600 * 1000)),
    delivered: false,
    opened: false,
  };
}

async function seedHistory(): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`notification_history/${NOTIFICATION_ID}`).set({
      ...recordedPayload(),
      sentAt: Timestamp.now(),
    });
  });
}

test("notification_history: recordNotification's real payload is ALLOWED", async () => {
  await assertSucceeds(historyDoc().set(recordedPayload()));
});

test("notification_history: the same payload plus one unknown key is DENIED", async () => {
  await assertFails(historyDoc().set({ ...recordedPayload(), surprise: 1 }));
});

test("notification_history: markNotificationDelivered's update is ALLOWED", async () => {
  await seedHistory();
  await assertSucceeds(
    historyDoc().update({ delivered: true, deliveredAt: serverTimestamp() })
  );
});

test("notification_history: markNotificationOpened's update is ALLOWED", async () => {
  await seedHistory();
  await assertSucceeds(
    historyDoc().update({ opened: true, openedAt: serverTimestamp() })
  );
});

test("notification_history: the delivered update plus one unknown key is DENIED", async () => {
  await seedHistory();
  await assertFails(
    historyDoc().update({
      delivered: true,
      deliveredAt: serverTimestamp(),
      surprise: 1,
    })
  );
});

const clicksCol = (actor: string) =>
  env
    .authenticatedContext(actor)
    .firestore()
    .collection(`deep_links/${LINK_ID}/clicks`);

test("deep_links clicks: trackUrlClick's real payload is ALLOWED", async () => {
  await assertSucceeds(
    clicksCol(UID).add({ timestamp: serverTimestamp(), userId: UID })
  );
});

test("deep_links clicks: the pre-fix shape (clickedAt, referrer) is DENIED", async () => {
  await assertFails(
    clicksCol(UID).add({
      clickedAt: serverTimestamp(),
      referrer: "x",
      userId: UID,
    })
  );
});

test("deep_links clicks: the real payload naming SOMEONE ELSE is DENIED", async () => {
  await assertFails(
    clicksCol(UID).add({ timestamp: serverTimestamp(), userId: OTHER_UID })
  );
});

async function run(): Promise<void> {
  console.log("writer-payload rules tests (BUT-1823)\n");
  console.log("========================================\n");
  await setup();
  let failed = 0;
  for (const t of tests) {
    await clearFirestore();
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(err);
    }
  }
  await env.cleanup();
  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
