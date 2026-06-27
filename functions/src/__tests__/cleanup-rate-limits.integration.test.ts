/**
 * BUT-1354 — emulator-backed integration test for the rate-limit cleanup
 * scheduled function core (`cleanupOldRateLimitsCore`).
 *
 * BUT-1390: the job deletes stale buckets from the live top-level
 * `system_rate_limits` collection (doc id `{uid}_{op}`) whose `updatedAt` is
 * older than 90 days. The `onSchedule` wrapper can't be invoked directly in a
 * test, so we exercise the extracted core against a REAL Firestore emulator —
 * the range query, 90-day cutoff comparison, and batched deletes run for real.
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

  // ── Seed: an OLD bucket (100 days) and a FRESH one (1 day) in the live
  //    system_rate_limits collection, plus a second fresh bucket as a control
  //    that must survive the global scan. Doc ids mirror prod (`${uid}_${op}`). ──
  const userA = `rl-userA-${RUN}`;
  const userB = `rl-userB-${RUN}`;

  const oldRef = db
    .collection("system_rate_limits")
    .doc(`${userA}_structureRecipe-${RUN}`);
  const freshRef = db
    .collection("system_rate_limits")
    .doc(`${userA}_ocrRecipeImage-${RUN}`);
  const controlRef = db
    .collection("system_rate_limits")
    .doc(`${userB}_structureRecipe-${RUN}`);

  await oldRef.set({
    updatedAt: daysAgo(100),
    tokens: 5,
    operationType: "structureRecipe",
  });
  await freshRef.set({
    updatedAt: daysAgo(1),
    tokens: 2,
    operationType: "ocrRecipeImage",
  });
  await controlRef.set({
    updatedAt: daysAgo(10),
    tokens: 1,
    operationType: "structureRecipe",
  });

  // ── Run the core ──
  const res = await cleanupOldRateLimitsCore(db);

  // ── Effect assertions ──
  check(
    "stale bucket (>90d) is deleted",
    !(await oldRef.get()).exists,
  );
  check(
    "fresh bucket (<90d) is kept",
    (await freshRef.get()).exists,
  );
  check(
    "second fresh bucket is kept (global-scan scope control)",
    (await controlRef.get()).exists,
  );

  // ── Return-summary assertion ──
  check(
    "returns a deletedCount of at least 1",
    typeof res.deletedCount === "number" && res.deletedCount >= 1,
    JSON.stringify(res),
  );

  // ── Idempotency: a second run deletes nothing new (stale bucket already gone) ──
  const res2 = await cleanupOldRateLimitsCore(db);
  check(
    "idempotent: fresh bucket still present after re-run",
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
