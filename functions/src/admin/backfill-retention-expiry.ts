/**
 * One-time backfill of `expireAt` onto rows written before their writer
 * stamped it: parsing_corrections, tag_overrides_log, parse_corrections_v2
 * and feedback. The collections and windows are in
 * backfill-retention-expiry-core.ts.
 *
 * Counts only, unless `--apply` is passed. Stamping is not itself a delete,
 * but every row older than its window gets a past `expireAt` and the TTL
 * policy deletes it, and that cannot be undone. So the
 * dry-run count goes to Malin first.
 *
 * Usage (from functions/):
 *   npm run backfill-retention-expiry -- --project <id>                 # count only
 *   npm run backfill-retention-expiry -- --project <id> --apply         # stamp
 *   npm run backfill-retention-expiry -- --project <id> --collection feedback
 */

import * as admin from "firebase-admin";
import { initializeAdminApp } from "./admin-init";
import { planStamp, RETENTION_TARGETS, RetentionTarget } from "./backfill-retention-expiry-core";

const PAGE_SIZE = 300;
// Firestore caps batches at 500 ops; one op per stamped row.
const MAX_BATCH_OPS = 400;

interface Tally {
  scanned: number;
  stamp: number;
  alreadyExpired: number;
  fallback: number;
}

async function backfill(
  db: admin.firestore.Firestore,
  target: RetentionTarget,
  apply: boolean,
  nowMs: number,
): Promise<Tally> {
  const tally: Tally = { scanned: 0, stamp: 0, alreadyExpired: 0, fallback: 0 };
  let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;

  // A missing field cannot be queried, so the whole collection is paged by id.
  for (;;) {
    let query = db
      .collection(target.collection)
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);
    const page = await query.get();
    if (page.empty) break;

    let batch = db.batch();
    let ops = 0;
    for (const doc of page.docs) {
      tally.scanned++;
      const plan = planStamp(doc.data(), target, nowMs);
      if (!plan.stamp) continue;
      tally.stamp++;
      if (plan.alreadyExpired) tally.alreadyExpired++;
      if (plan.usedFallback) tally.fallback++;
      if (!apply) continue;

      batch.update(doc.ref, {
        expireAt: admin.firestore.Timestamp.fromMillis(plan.expireAtMs),
      });
      ops++;
      if (ops >= MAX_BATCH_OPS) {
        await batch.commit();
        batch = db.batch();
        ops = 0;
      }
    }
    if (apply && ops > 0) await batch.commit();

    lastDoc = page.docs[page.docs.length - 1];
    if (page.size < PAGE_SIZE) break;
  }
  return tally;
}

function selectedTargets(argv: readonly string[]): readonly RetentionTarget[] {
  const i = argv.indexOf("--collection");
  if (i === -1) return RETENTION_TARGETS;
  const name = argv[i + 1];
  const match = RETENTION_TARGETS.filter((t) => t.collection === name);
  if (match.length === 0) {
    throw new Error(
      `REFUSED: --collection "${name ?? ""}" is not one of ` +
        RETENTION_TARGETS.map((t) => t.collection).join(", "),
    );
  }
  return match;
}

async function main(): Promise<void> {
  const argv = process.argv.slice(2);
  const apply = argv.includes("--apply");
  const targets = selectedTargets(argv);
  initializeAdminApp();
  const db = admin.firestore();
  const nowMs = Date.now();

  console.log(apply ? "Mode: APPLY (writes expireAt)" : "Mode: DRY-RUN (no writes)");
  for (const target of targets) {
    const t = await backfill(db, target, apply, nowMs);
    console.log(
      `${target.collection}: scanned ${t.scanned}, ` +
        `missing expireAt ${apply ? "stamped" : "(would stamp)"} ${t.stamp}, ` +
        `of which past the window (TTL deletes them after stamping) ${t.alreadyExpired}, ` +
        `without a readable ${target.baseField} (window starts now) ${t.fallback}`,
    );
  }
}

main().catch((err) => {
  console.error("backfill-retention-expiry failed:", err);
  process.exit(1);
});
