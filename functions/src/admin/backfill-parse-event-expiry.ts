/**
 * BUT-1478: one-time backfill of `expireAt` onto pre-existing parse_events docs.
 *
 * Firestore TTL only reaps docs that HAVE the indexed field, so every parse
 * event written before logParseEvent started stamping `expireAt` (raw userId +
 * the user's imported URL) would otherwise be retained forever — exactly the
 * GDPR Art. 5(1)(e) surface the TTL policy is meant to close. This script
 * stamps `expireAt = timestamp + 30 days` (via the same computeExpireAt seam
 * the handler uses, so the window can't drift) on every doc missing the field.
 * Docs whose window is already in the past get a past `expireAt` and are
 * reaped by the TTL policy within ~24h of enablement — no destructive deletes
 * happen here.
 *
 * Run on deploy day for BUT-1478, together with enabling the TTL policy — see
 * functions/RUNBOOK.md ("Firestore TTL policies").
 *
 * Usage (from functions/):
 *   npm run backfill-parse-event-expiry:dry-run   # count only, no writes
 *   npm run backfill-parse-event-expiry           # stamp missing expireAt
 */

import * as admin from "firebase-admin";
import { computeExpireAt } from "../events/log-parse-event";
import { initializeAdminApp } from "./admin-init";

const PAGE_SIZE = 300;
// Firestore caps batches at 500 ops; stay under it (1 op per stamped doc).
const MAX_BATCH_OPS = 400;

async function main(): Promise<void> {
  const dryRun = process.argv.includes("--dry-run");
  initializeAdminApp();
  const db = admin.firestore();

  let scanned = 0;
  let stamped = 0;
  let alreadyExpiredWindow = 0;
  let lastDoc: admin.firestore.QueryDocumentSnapshot | null = null;

  // `expireAt` missing can't be queried directly (Firestore doesn't index
  // absent fields), so paginate the whole collection by document ID. Pre-beta
  // scale makes the full scan cheap; the script is idempotent either way.
  for (;;) {
    let query = db
      .collection("parse_events")
      .orderBy(admin.firestore.FieldPath.documentId())
      .limit(PAGE_SIZE);
    if (lastDoc) query = query.startAfter(lastDoc);

    const page = await query.get();
    if (page.empty) break;

    let batch = db.batch();
    let opsInBatch = 0;

    for (const doc of page.docs) {
      scanned++;
      const data = doc.data();
      if (data.expireAt !== undefined) continue;

      // Anchor the window at the event's own server timestamp; fall back to
      // `now` for the odd doc without one (still bounds retention).
      const baseMs =
        data.timestamp instanceof admin.firestore.Timestamp
          ? data.timestamp.toMillis()
          : Date.now();
      const expireAt = computeExpireAt(baseMs);
      if (expireAt.toMillis() <= Date.now()) alreadyExpiredWindow++;

      stamped++;
      if (dryRun) continue;

      batch.update(doc.ref, { expireAt });
      opsInBatch++;
      if (opsInBatch >= MAX_BATCH_OPS) {
        await batch.commit();
        batch = db.batch();
        opsInBatch = 0;
      }
    }

    if (!dryRun && opsInBatch > 0) await batch.commit();
    lastDoc = page.docs[page.docs.length - 1];
    if (page.size < PAGE_SIZE) break;
  }

  console.log(
    `${dryRun ? "[dry-run] " : ""}parse_events scanned: ${scanned}, ` +
      `missing expireAt ${dryRun ? "(would stamp)" : "stamped"}: ${stamped}, ` +
      `of which already past the 30-day window (TTL reaps on enablement): ${alreadyExpiredWindow}`
  );
}

main().catch((err) => {
  console.error("backfill-parse-event-expiry failed:", err);
  process.exit(1);
});
