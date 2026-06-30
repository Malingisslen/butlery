#!/usr/bin/env node
/**
 * One-off backfill: rewrite legacy zoneless `feedback/{id}.createdAt` strings to UTC.
 *
 * BUT-1441 (follow-up to BUT-1408). The writer was fixed in BUT-1408 so new feedback
 * docs serialize `createdAt` as UTC (`FeedbackEntry.toMap` → `createdAt.toUtc().toIso8601String()`,
 * which ends in `Z`). Docs written BEFORE that fix stored a *zoneless* local wall-clock ISO
 * string (e.g. `2026-06-28T01:30:00.000`, no `Z`, no offset). The daily-snapshot reader
 * (`functions/src/analytics/daily-snapshots.ts` runFeedbackSnapshot) compares lexicographically
 * against UTC `…Z` boundaries, so those legacy docs are mis-bucketed at day boundaries.
 *
 * This script finds zoneless docs and rewrites each `createdAt` to the correct UTC `…Z` value,
 * interpreting the stored wall-clock as **Europe/Stockholm** local time (the documented app
 * timezone — the original offset was not recorded, so this is the stated assumption).
 *
 * SAFETY:
 *   - Dry-run by default. Prints every change it WOULD make and writes nothing.
 *   - Pass `--commit` to actually write, in batches of <=500 ops.
 *   - Idempotent: any value already ending in `Z` (or carrying a numeric offset) is skipped,
 *     so re-running is safe and a partial run can be resumed.
 *
 * USAGE (run by a human with prod credentials — this is the Tier-D ops step):
 *   # Auth: either GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json,
 *   # or `gcloud auth application-default login` with access to the project.
 *   cd functions
 *   node scripts/backfill-feedback-createdat-utc.js                 # dry run (default)
 *   node scripts/backfill-feedback-createdat-utc.js --commit        # apply
 *   node scripts/backfill-feedback-createdat-utc.js --project butlery-app-1 --commit
 */

'use strict';

const admin = require('firebase-admin');

const args = process.argv.slice(2);
const COMMIT = args.includes('--commit');
const projectIdx = args.indexOf('--project');
const PROJECT_ID =
  projectIdx !== -1 && args[projectIdx + 1] ? args[projectIdx + 1] : undefined;

admin.initializeApp(PROJECT_ID ? { projectId: PROJECT_ID } : undefined);
const db = admin.firestore();

/**
 * True when `s` already carries timezone information (a trailing `Z` or a `±HH:MM`
 * offset). Such values are correct UTC-aware ISO strings and must be left untouched.
 */
function hasZoneInfo(s) {
  return /Z$/.test(s) || /[+-]\d{2}:?\d{2}$/.test(s);
}

/**
 * Offset (in minutes, zone-relative-to-UTC) that Europe/Stockholm has at the given
 * absolute instant. Positive in summer (CEST, +120) / winter (CET, +60). Computed via
 * Intl so DST transitions are handled correctly without a tz-data dependency.
 */
function stockholmOffsetMinutes(instant) {
  const dtf = new Intl.DateTimeFormat('en-US', {
    timeZone: 'Europe/Stockholm',
    hourCycle: 'h23',
    year: 'numeric',
    month: '2-digit',
    day: '2-digit',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  });
  const p = Object.fromEntries(
    dtf.formatToParts(instant).map((part) => [part.type, part.value]),
  );
  // The wall-clock Stockholm shows for `instant`, read back as if it were UTC.
  const asUtc = Date.UTC(
    Number(p.year),
    Number(p.month) - 1,
    Number(p.day),
    Number(p.hour),
    Number(p.minute),
    Number(p.second),
  );
  return Math.round((asUtc - instant.getTime()) / 60000);
}

/**
 * Convert a zoneless wall-clock ISO string (assumed Europe/Stockholm local) to the
 * corresponding UTC instant, then return its canonical `…Z` ISO string.
 *
 * Wall-time → instant is the inverse of the offset lookup, so we iterate twice: the
 * offset can differ on the two sides of a DST boundary, and the second pass settles it
 * for all but the (vanishingly rare, ambiguous) fall-back hour, where CET is chosen.
 */
function stockholmWallTimeToUtcIso(zoneless) {
  // Parse the wall-clock components as if they were UTC to get a first guess instant.
  const guess = new Date(zoneless + 'Z');
  if (Number.isNaN(guess.getTime())) return null;

  let offset = stockholmOffsetMinutes(guess);
  let instant = new Date(guess.getTime() - offset * 60000);
  // Re-evaluate the offset at the corrected instant and settle.
  offset = stockholmOffsetMinutes(instant);
  instant = new Date(guess.getTime() - offset * 60000);

  return instant.toISOString(); // always `…Z`
}

async function main() {
  console.log(
    `[backfill-feedback-createdat-utc] mode=${COMMIT ? 'COMMIT' : 'DRY-RUN'}${
      PROJECT_ID ? ` project=${PROJECT_ID}` : ''
    }`,
  );

  const snap = await db.collection('feedback').get();
  console.log(`Scanned ${snap.size} feedback docs.`);

  const changes = [];
  for (const doc of snap.docs) {
    const v = doc.get('createdAt');
    if (typeof v !== 'string') continue; // Timestamp or missing → not a legacy zoneless string
    if (hasZoneInfo(v)) continue; // already UTC-aware → idempotent skip

    const utc = stockholmWallTimeToUtcIso(v);
    if (!utc || utc === v) continue;
    changes.push({ id: doc.id, ref: doc.ref, from: v, to: utc });
  }

  if (changes.length === 0) {
    console.log('No legacy zoneless createdAt values found. Nothing to do.');
    return;
  }

  console.log(`Found ${changes.length} legacy doc(s) to rewrite:`);
  for (const c of changes) {
    console.log(`  ${c.id}: "${c.from}"  ->  "${c.to}"  (assumed Europe/Stockholm)`);
  }

  if (!COMMIT) {
    console.log('\nDRY-RUN: no writes performed. Re-run with --commit to apply.');
    return;
  }

  let written = 0;
  for (let i = 0; i < changes.length; i += 500) {
    const slice = changes.slice(i, i + 500);
    const batch = db.batch();
    for (const c of slice) batch.update(c.ref, { createdAt: c.to });
    await batch.commit();
    written += slice.length;
    console.log(`Committed ${written}/${changes.length}.`);
  }
  console.log(`Done. Rewrote ${written} doc(s).`);
}

main().then(
  () => process.exit(0),
  (err) => {
    console.error('Backfill failed:', err);
    process.exit(1);
  },
);
