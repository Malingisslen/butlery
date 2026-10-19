/**
 * BUT-1354 — emulator-backed integration test for the shared-content-metadata
 * TTL cleanup scheduled function core (`cleanupSharedContentMetadataCore`).
 *
 * The job deletes metadata subcollection docs (views/engagements/dismissals)
 * under shared_content whose `timestamp` is older than 90 days. The
 * `onSchedule` wrapper can't be invoked directly, so we exercise the extracted
 * core against a REAL Firestore emulator — the collection-group cutoff query
 * runs for real.
 *
 * Admin SDK bypasses rules → seeding is plain writes. Pointing Admin at the
 * emulator only needs `FIRESTORE_EMULATOR_HOST` set BEFORE
 * `admin.initializeApp`.
 *
 * Per-run isolation: unique PROJECT_ID per suite + a per-run id suffix on every
 * seeded doc.
 *
 * Prerequisite: Firestore emulator running locally
 * (`bash .claude/hooks/ensure-firestore-emulator.sh`).
 *
 * Run: npx ts-node src/__tests__/cleanup-shared-content-metadata.integration.test.ts
 */

import { requireEmulatorsOrSkip } from "./integration-gate";

const PROJECT_ID = "butlery-cleanup-shared-meta-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

// eslint-disable-next-line @typescript-eslint/no-require-imports
import * as admin from "firebase-admin";

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
  console.log("cleanupSharedContentMetadata integration tests (BUT-1354)\n");
  console.log("=============================\n");

  await requireEmulatorsOrSkip(
    [{ name: "Firestore", hostPort: EMULATOR_HOST }],
    "bash .claude/hooks/ensure-firestore-emulator.sh",
  );

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();

  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const {
    cleanupSharedContentMetadataCore,
  } = require("../cleanup/cleanup-shared-content-metadata");

  const daysAgo = (n: number): admin.firestore.Timestamp => {
    const d = new Date();
    d.setDate(d.getDate() - n);
    return admin.firestore.Timestamp.fromDate(d);
  };

  // ── Seed one share of each content type, each carrying an OLD metadata
  //    entry (100 days) and a FRESH one (1 day) in the `views` subcollection.
  //    We also seed a fresh `engagements` entry to confirm fresh data in other
  //    subcollections survives. ──
  const parents = [
    { col: "shared_content", id: `recipe-${RUN}` },
    { col: "shared_content", id: `menu-${RUN}` },
    { col: "shared_content", id: `list-${RUN}` },
  ];

  const oldRefs: admin.firestore.DocumentReference[] = [];
  const freshRefs: admin.firestore.DocumentReference[] = [];
  const freshEngagementRefs: admin.firestore.DocumentReference[] = [];

  for (const p of parents) {
    const parentRef = db.collection(p.col).doc(p.id);
    await parentRef.set({ seeded: true });

    const oldView = parentRef.collection("views").doc(`old-${RUN}`);
    const freshView = parentRef.collection("views").doc(`fresh-${RUN}`);
    const freshEng = parentRef.collection("engagements").doc(`fresh-${RUN}`);

    await oldView.set({ timestamp: daysAgo(100), uid: "viewer" });
    await freshView.set({ timestamp: daysAgo(1), uid: "viewer" });
    await freshEng.set({ timestamp: daysAgo(1), uid: "engager" });

    oldRefs.push(oldView);
    freshRefs.push(freshView);
    freshEngagementRefs.push(freshEng);
  }

  // An old `views` row under another collection is not shared-content
  // metadata, so the collection-group sweep must leave it.
  const strayOld = db
    .collection("not_shared_content")
    .doc(`p-${RUN}`)
    .collection("views")
    .doc(`old-${RUN}`);
  await strayOld.set({ timestamp: daysAgo(100), uid: "viewer" });

  // ── Run the core ──
  const res = await cleanupSharedContentMetadataCore(db);

  // ── Effect assertions ──
  check(
    "an old views row outside shared_content is kept",
    (await strayOld.get()).exists,
  );
  for (let i = 0; i < parents.length; i++) {
    const col = `${parents[i].col}/${parents[i].id}`;
    check(
      `${col}: old view (>90d) is deleted`,
      !(await oldRefs[i].get()).exists,
    );
    check(
      `${col}: fresh view (<90d) is kept`,
      (await freshRefs[i].get()).exists,
    );
    check(
      `${col}: fresh engagement (<90d) is kept`,
      (await freshEngagementRefs[i].get()).exists,
    );
  }

  // ── Return-summary assertion: 3 old views deleted ──
  check(
    "returns totalDeleted of at least 3 (one old view per share)",
    typeof res.totalDeleted === "number" && res.totalDeleted >= 3,
    JSON.stringify(res),
  );

  // ── Idempotency: re-run deletes nothing new, fresh docs survive ──
  await cleanupSharedContentMetadataCore(db);
  let freshSurvived = true;
  for (const r of freshRefs) {
    if (!(await r.get()).exists) freshSurvived = false;
  }
  check("idempotent: all fresh views still present after re-run", freshSurvived);

  console.log(`\n${run - failed}/${run} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
