/**
 * BUT-1354 — emulator-backed integration test for the rate-limit cleanup
 * scheduled function core (`cleanupOldRateLimitsCore`).
 *
 * The job deletes per-user `rate_limits` docs whose `updatedAt` is older than
 * 90 days. The `onSchedule` wrapper can't be invoked directly in a test, so we
 * exercise the extracted core against a REAL Firestore emulator — the
 * pagination, 90-day cutoff comparison, and batched deletes all run for real.
 *
 * The Admin SDK bypasses rules, so seeding is plain writes. Pointing Admin at
 * the emulator only needs `FIRESTORE_EMULATOR_HOST` set BEFORE
 * `admin.initializeApp`.
 *
 * Per-run isolation: the emulator persists data across runs, so we use a unique
 * PROJECT_ID per suite plus a per-run id suffix on every seeded user.
 *
 * Prerequisite: Firestore emulator running locally
 * (`bash .claude/hooks/ensure-firestore-emulator.sh`).
 *
 * Run: npx ts-node src/__tests__/cleanup-rate-limits.integration.test.ts
 */

import { requireEmulatorsOrSkip } from "./integration-gate";

const PROJECT_ID = "butlery-cleanup-rate-limits-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

// eslint-disable-next-line @typescript-eslint/no-require-imports
import * as admin from "firebase-admin";

// Per-run suffix so re-runs against a non-wiped emulator don't collide.
const RUN = Date.now().toString(36);

let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

async function run_(): Promise<void> {
  console.log("cleanupOldRateLimits integration tests (BUT-1354)\n");
  console.log("=============================\n");

  await requireEmulatorsOrSkip(
    [{ name: "Firestore", hostPort: EMULATOR_HOST }],
    "bash .claude/hooks/ensure-firestore-emulator.sh",
  );

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();

  // Import AFTER initializeApp so the module binds to the emulator default app.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const {
    cleanupOldRateLimitsCore,
  } = require("../cleanup/cleanup-rate-limits");

  const daysAgo = (n: number): admin.firestore.Timestamp => {
    const d = new Date();
    d.setDate(d.getDate() - n);
    return admin.firestore.Timestamp.fromDate(d);
  };

  // ── Seed: one user with an OLD rate-limit doc (100 days) and a FRESH one
  //    (1 day). A second user with only a fresh doc acts as a scope control. ──
  const userA = `rl-userA-${RUN}`;
  const userB = `rl-userB-${RUN}`;

  // Parent user docs must exist for the paginated `users` scan to enumerate
  // them (orderBy __name__ over the users collection).
  await db.collection("users").doc(userA).set({ seeded: true });
  await db.collection("users").doc(userB).set({ seeded: true });

  const oldRef = db.collection("users").doc(userA)
    .collection("rate_limits").doc(`old-${RUN}`);
  const freshRef = db.collection("users").doc(userA)
    .collection("rate_limits").doc(`fresh-${RUN}`);
  const controlRef = db.collection("users").doc(userB)
    .collection("rate_limits").doc(`control-${RUN}`);

  await oldRef.set({ updatedAt: daysAgo(100), count: 5 });
  await freshRef.set({ updatedAt: daysAgo(1), count: 2 });
  await controlRef.set({ updatedAt: daysAgo(10), count: 1 });

  // ── Run the core ──
  const res = await cleanupOldRateLimitsCore(db);

  // ── Effect assertions ──
  check(
    "old rate_limit doc (>90d) is deleted",
    !(await oldRef.get()).exists,
  );
  check(
    "fresh rate_limit doc (<90d) is kept",
    (await freshRef.get()).exists,
  );
  check(
    "other user's fresh doc is kept (scope control)",
    (await controlRef.get()).exists,
  );

  // ── Return-summary assertions ──
  check(
    "returns a deletedCount of at least 1",
    typeof res.deletedCount === "number" && res.deletedCount >= 1,
    JSON.stringify(res),
  );
  check(
    "returns processedUsers covering both seeded users",
    typeof res.processedUsers === "number" && res.processedUsers >= 2,
    JSON.stringify(res),
  );

  // ── Idempotency: a second run deletes nothing new (old doc already gone) ──
  const res2 = await cleanupOldRateLimitsCore(db);
  check(
    "idempotent: fresh doc still present after re-run",
    (await freshRef.get()).exists,
  );
  check(
    "idempotent: re-run reports a valid (non-negative) deletedCount",
    typeof res2.deletedCount === "number" && res2.deletedCount >= 0,
    JSON.stringify(res2),
  );

  console.log(`\n${run - failed}/${run} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
