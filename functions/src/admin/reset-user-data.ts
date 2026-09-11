/**
 * Reset User Data — Clean Slate Script
 *
 * Wipes the collections named in `COLLECTIONS_TO_DELETE` below from Firebase
 * (Auth + Firestore + Storage), preserving config/seed data (site_configs,
 * tag_configs, ingredients, etc.).
 *
 * `analytics` is preserved with an exception: its measurement series survive
 * and the rows about individual people under it do not
 * (`admin/reset-analytics-prune.ts`).
 *
 * Every collection this repo knows about is now DECIDED — it is in
 * `COLLECTIONS_TO_DELETE`, in `COLLECTIONS_TO_KEEP`, or in
 * `COLLECTIONS_DELIBERATELY_UNTOUCHED` with the reason it is left alone. A
 * coverage guard in the account-cascade suite derives that universe from
 * `firestore.rules` AND from `functions/src` and reddens when a collection
 * belongs to none of the three. No counts here: a count in a comment goes
 * stale the next time anyone adds a rules block, and nothing reddens when it
 * does.
 *
 * Phase 1 fires the live `onUserDeleted` trigger, which writes into
 * collections Phase 2 is concurrently deleting. The run therefore SETS a kill
 * switch (`shared/reset-kill-switch.ts`) for its duration and clears it in a
 * `finally`; Phase 4 fails the run if it is still standing.
 *
 * The scheduled jobs write into those same collections and read no flag, so
 * the run also PAUSES every enabled Cloud Scheduler job for its duration
 * (`admin/reset-scheduler-pause.ts`) and releases them when it ends — in the
 * same `finally` as the kill switch, and on SIGINT/SIGTERM, which bypasses it.
 * A run that cannot pause them, or cannot set the kill switch once they are
 * paused, resumes what it paused and refuses before Phase 1, while nothing has
 * been deleted yet.
 *
 * Phase 4 counts what is left and answers CLEAN, NOT CLEAN or INDETERMINATE,
 * and the verdict carries the exit code. It cannot answer "finished": a gen1
 * trigger has no bounded delivery time.
 *
 * What stands between an accidental invocation and a wiped project is the
 * confirmation phrase in `main()`, typed in full, on a live run only. See
 * `CONFIRMATION_PHRASE` for why nothing may pre-satisfy it.
 *
 * Operating instructions, including what to do when the kill switch sticks:
 * `docs/ops/reset-user-data-runbook.md`.
 *
 * Usage:
 *   cd functions
 *   npm run reset-user-data:dry-run   # preview what gets deleted
 *   npm run reset-user-data           # live; asks for the phrase
 */

import * as admin from "firebase-admin";
import * as readline from "readline";
import { randomUUID } from "crypto";
import { initializeAdminApp } from "./admin-init";

// --- Configuration ---

// The three collection lists live in their own side-effect-free module so the
// guards can import the real values instead of parsing this file as text —
// this file runs `main()` at module scope, which is why they had to.
import {
  CollectionTarget,
  COLLECTIONS_TO_DELETE,
  COLLECTIONS_TO_KEEP,
  COLLECTIONS_DELIBERATELY_UNTOUCHED,
} from "./reset-collection-lists";
import {
  clearResetKillSwitch,
  readResetKillSwitch,
  setResetKillSwitch,
  RESET_KILL_SWITCH_PATH,
  RESET_KILL_SWITCH_TTL_MINUTES,
} from "../shared/reset-kill-switch";
import {
  EXIT_CODE_BY_VERDICT,
  Verdict,
  verdictFor,
} from "./reset-verdict";
import {
  findUnknownCollections,
  formatUnknownCollections,
} from "./unknown-collections";
import {
  countAnalyticsResidue,
  pruneAnalytics,
} from "./reset-analytics-prune";
import {
  createSchedulerApi,
  findStillPausedJobs,
  gcloudResumeCommand,
  JobName,
  listEnabledSchedulerJobs,
  pauseJobs,
  resumeJobs,
  SchedulerApi,
} from "./reset-scheduler-pause";

// BUT-2028: `feedback/` was missing. Feedback screenshots are written to
// `feedback/{userId}/{timestamp}.png` (`firebase_feedback_repository.dart`),
// so a reset deleted the Firestore row and left the image standing.
// `ops/` is deliberately NOT here — see `recordRunOutOfBand`.
const STORAGE_PREFIXES_TO_DELETE = ["users/", "shared/", "feedback/"];

const BATCH_SIZE = 500;
/**
 * How long the run may go without re-stamping the kill switch.
 *
 * A TIME cursor, not a count of collections. `deleteDocRecursive` is
 * depth-first over documents, so nearly all of a real wipe's wall time is
 * inside two entries — `users` and `conversations` — and a per-collection
 * counter refreshes freely across the cheap ones while never firing once
 * during the expensive ones. That is the exact shape that would let the
 * suppression lapse mid-walk.
 *
 * The check is a `Date.now()` comparison per document. It cannot fire during
 * `listDocuments()` itself, which enumerates a whole collection in one call —
 * so the bound is this interval plus one enumeration, not this interval
 * alone.
 */
const KILL_SWITCH_REFRESH_INTERVAL_MS = 10 * 60 * 1000;
/**
 * The last human step before a live run, typed in full at the prompt in
 * `main()`. Nothing may pre-satisfy it — an npm script that pipes it in leaves
 * the gate running and proves nothing, which is the shape that let the overlap
 * guard sit broken for five and a half months (BUT-2010).
 */
const CONFIRMATION_PHRASE = "YES DELETE ALL USER DATA";

// --- Helpers ---

async function promptUser(question: string): Promise<string> {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });
  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.trim());
    });
  });
}

async function deleteCollection(
  db: admin.firestore.Firestore,
  collectionPath: string,
  dryRun: boolean
): Promise<number> {
  if (dryRun) {
    const snapshot = await db.collection(collectionPath).count().get();
    return snapshot.data().count;
  }

  let totalDeleted = 0;
  let query = db.collection(collectionPath).limit(BATCH_SIZE);

  while (true) {
    const snapshot = await query.get();
    if (snapshot.empty) break;

    const batch = db.batch();
    snapshot.docs.forEach((doc) => batch.delete(doc.ref));
    await batch.commit();
    totalDeleted += snapshot.size;

    if (snapshot.size < BATCH_SIZE) break;
  }

  return totalDeleted;
}

/**
 * Recursively delete a document and all its subcollections (any depth).
 */
async function deleteDocRecursive(
  docRef: admin.firestore.DocumentReference,
  subCounts: Record<string, number>,
  dryRun: boolean,
  maybeRefreshKillSwitch: () => Promise<void>
): Promise<void> {
  const subCollections = await docRef.listCollections();
  for (const subCol of subCollections) {
    // Delete docs in this subcollection (each may have its own subs)
    const subDocRefs = await subCol.listDocuments();
    for (const subDocRef of subDocRefs) {
      await maybeRefreshKillSwitch();
      await deleteDocRecursive(
        subDocRef,
        subCounts,
        dryRun,
        maybeRefreshKillSwitch
      );
    }
    const count = await deleteCollection(subCol.firestore, subCol.path, dryRun);
    subCounts[subCol.id] = (subCounts[subCol.id] || 0) + count;
  }

  if (!dryRun) {
    await docRef.delete();
  }
}

async function deleteWithSubcollections(
  db: admin.firestore.Firestore,
  target: CollectionTarget,
  dryRun: boolean,
  maybeRefreshKillSwitch: () => Promise<void>
): Promise<{ parentCount: number; subCounts: Record<string, number> }> {
  const subCounts: Record<string, number> = {};

  const docRefs = await db.collection(target.name).listDocuments();
  let parentCount = docRefs.length;

  for (const docRef of docRefs) {
    // Inside the per-document walk, not only between collections: `users` and
    // `conversations` are where a real wipe spends its time, so a refresh that
    // only fires between collections never runs during either of them.
    await maybeRefreshKillSwitch();
    await deleteDocRecursive(docRef, subCounts, dryRun, maybeRefreshKillSwitch);
  }

  // Mop-up over a collection the loop above has already emptied: every
  // document it enumerated is deleted by `deleteDocRecursive`. That is why
  // `deleteCollection`'s own paging loop carries no kill-switch refresh — it
  // breaks on the first empty page. Do not remove the per-document loop and
  // lean on this instead; the refresh would stop reaching the walk.
  const topCount = await deleteCollection(db, target.name, dryRun);
  if (topCount > parentCount) parentCount = topCount;

  return { parentCount, subCounts };
}

// --- Main ---

/** What a phase run produced, so the verification phase can report against it. */
interface PhaseTotals {
  authUsers: number;
  results: { collection: string; docs: number; subs: Record<string, number> }[];
  storageFiles: number;
  /** Non-fatal failures. A run that had any of these cannot verify CLEAN. */
  softFailures: string[];
}

/**
 * Writes the run's own record somewhere this run does not delete.
 *
 * Firestore is not an option: every audit collection this script could write
 * to is in `COLLECTIONS_TO_DELETE`, so the run would erase its own bookkeeping
 * in Phase 2. Cloud Storage under `ops/` works because the storage prefixes
 * this script deletes are enumerated (`STORAGE_PREFIXES_TO_DELETE`) and `ops/`
 * is not one of them.
 *
 * Written BEFORE Phase 1, so an abandoned or crashed run still leaves the
 * record that it started — which is the case where knowing matters most.
 */
async function recordRunOutOfBand(
  projectId: string,
  runId: string,
  args: string[],
  jobsToPause: JobName[],
): Promise<void> {
  const bucket = admin.storage().bucket(`${projectId}.firebasestorage.app`);
  await bucket.file(`ops/resets/${runId}.json`).save(
    JSON.stringify(
      {
        runId,
        projectId,
        startedAt: new Date().toISOString(),
        argv: args,
        killSwitch: RESET_KILL_SWITCH_PATH,
        // Written BEFORE the pause, so a run that dies between the two leaves
        // the operator the list to resume by hand. Firestore could not hold
        // it: Phase 2 deletes every collection this script could write to.
        schedulerJobsToPause: jobsToPause,
        note:
          "Written before Phase 1 by admin/reset-user-data.ts. The presence " +
          "of this file without a matching verification line means the run " +
          "started and did not finish.",
      },
      null,
      2,
    ),
    { contentType: "application/json" },
  );
}

async function runPhases(
  db: admin.firestore.Firestore,
  projectId: string,
  dryRun: boolean,
  /**
   * Re-stamps the kill switch's expiry, but only once
   * `KILL_SWITCH_REFRESH_INTERVAL_MS` has passed. Threaded all the way into
   * the per-document walk, because the expiry bounds the RUN and not merely an
   * abandoned one: a Phase 2 that outlives it disarms its own suppression
   * mid-wipe, with nothing on screen to say so.
   */
  maybeRefreshKillSwitch: () => Promise<void>,
): Promise<PhaseTotals> {
  const softFailures: string[] = [];

  // --- Phase 1: Delete Auth users ---
  console.log("Phase 1: Firebase Auth users");
  let totalAuthDeleted = 0;

  let pageToken: string | undefined;
  do {
    const result = await admin.auth().listUsers(1000, pageToken);
    const uids = result.users.map((u) => u.uid);
    totalAuthDeleted += uids.length;

    if (!dryRun && uids.length > 0) {
      const deleteResult = await admin.auth().deleteUsers(uids);
      if (deleteResult.failureCount > 0) {
        // Recorded, not just printed: a surviving Auth account means Phase 2
        // deleted the data of a user who can still sign in.
        softFailures.push(
          `${deleteResult.failureCount} Auth user(s) failed to delete`,
        );
        console.log(
          `  Warning: ${deleteResult.failureCount} users failed to delete`,
        );
      }
    }

    pageToken = result.pageToken;
  } while (pageToken);

  console.log(
    `  ${dryRun ? "Would delete" : "Deleted"}: ${totalAuthDeleted} users`,
  );
  console.log();
  await maybeRefreshKillSwitch();

  // --- Phase 2: Delete Firestore collections ---
  console.log("Phase 2: Firestore collections");
  const results: PhaseTotals["results"] = [];

  for (const target of COLLECTIONS_TO_DELETE) {
    await maybeRefreshKillSwitch();
    process.stdout.write(`  ${target.name}...`);
    const { parentCount, subCounts } = await deleteWithSubcollections(
      db,
      target,
      dryRun,
      maybeRefreshKillSwitch,
    );
    results.push({
      collection: target.name,
      docs: parentCount,
      subs: subCounts,
    });

    const subSummary = Object.entries(subCounts)
      .filter(([, v]) => v > 0)
      .map(([k, v]) => `${k}=${v}`)
      .join(", ");
    const subStr = subSummary ? ` (subs: ${subSummary})` : "";
    console.log(` ${parentCount} docs${subStr}`);
  }

  // `analytics` is KEPT, and the per-person rows under it are not. The deep
  // delete is the same one the loop above runs on.
  process.stdout.write("  analytics (kept, pruning per-person rows)...");
  const prune = await pruneAnalytics(db, {
    maybeRefreshKillSwitch,
    deleteDocDeep: (docRef) =>
      deleteDocRecursive(docRef, {}, dryRun, maybeRefreshKillSwitch),
  });
  for (const entry of prune.deleted) {
    // `subs` stays EMPTY. `results` is what the unknown-collections report
    // ranges over, and with `analytics` out of COLLECTIONS_TO_DELETE the names
    // beneath it are no longer decided by any list — so naming them here would
    // make the report flag `events` on every run. The report's universe is
    // unchanged by this step.
    results.push({ collection: entry.path, docs: entry.docs, subs: {} });
  }
  const keptSummary = prune.kept
    .map((entry) => `${entry.parentId}/${entry.subId}=${entry.docs}`)
    .join(", ");
  const prunedSummary = prune.deleted
    .map((entry) => `${entry.parentId}/${entry.subId}=${entry.docs}`)
    .join(", ");
  console.log(
    ` ${dryRun ? "would delete" : "deleted"} [${prunedSummary || "none"}], ` +
      `kept [${keptSummary || "none"}]`,
  );
  console.log();
  await maybeRefreshKillSwitch();

  // --- Phase 3: Delete Storage files ---
  console.log("Phase 3: Firebase Storage");
  let totalStorageFiles = 0;

  const bucket = admin.storage().bucket(`${projectId}.firebasestorage.app`);

  // Per PREFIX, not around the loop. A single try meant a failure on `users/`
  // abandoned `shared/` and `feedback/` silently, and the recorded message
  // named no prefix — so the operator could not tell which files were left.
  for (const prefix of STORAGE_PREFIXES_TO_DELETE) {
    try {
      const [files] = await bucket.getFiles({ prefix });
      totalStorageFiles += files.length;
      if (dryRun) {
        console.log(`  ${prefix}: ${files.length} files (would delete)`);
        continue;
      }
      if (files.length > 0) {
        await bucket.deleteFiles({ prefix, force: true });
      }
      // Printed AFTER the delete resolved, not before it was attempted.
      console.log(`  ${prefix}: ${files.length} files deleted`);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      // A skipped prefix used to print and be forgotten. It is a soft failure:
      // the files are still there and nothing else will remove them.
      softFailures.push(`Storage prefix ${prefix} not cleaned: ${message}`);
      console.log(`  ${prefix}: SKIPPED — ${message}`);
    }
  }
  console.log();

  return {
    authUsers: totalAuthDeleted,
    results,
    storageFiles: totalStorageFiles,
    softFailures,
  };
}

/**
 * Counts what is left. Deletes NOTHING.
 *
 * A verification pass that quietly re-deletes is the three-month shape
 * `reconcileMirrors` exists to avoid: it repairs while reporting, so the
 * report says "clean" about a state the pass itself produced.
 *
 * **What this cannot tell you.** `onUserDeleted` is a gen1 trigger with no
 * bounded delivery time and no `retry`, so an event can arrive after this pass
 * or never arrive at all. No stopping rule based on elapsed time or on a
 * number of passes is correct. A second sweep can prove that residue EXISTS;
 * nothing here can prove it is finished.
 *
 * **Report-only is a DECISION, not an omission. Malin's explicit call,
 * 2026-09-07.** BUT-2028's gate recommended repeating the Firestore sweep here,
 * to catch what the triggers wrote behind the first one. She was shown that
 * against the kill switch, which removes the cause rather than the symptom, and
 * against the paragraph above: a second sweep buys a stronger claim about
 * residue and no claim at all about completion, at the cost of a second full
 * pass over every deleted collection on every run. She was NOT shown a
 * measurement of how much residue a real run actually leaves. Do not add the
 * sweep back without one. (Whether any live run has happened at all is not
 * answerable from this repo: the only record a run leaves behind is
 * `ops/resets/{runId}.json` in the Storage bucket, which nothing here reads.)
 */
async function verifyReset(
  db: admin.firestore.Firestore,
  totals: PhaseTotals,
  runId: string,
  scheduler: { api: SchedulerApi; projectId: string; pausedJobs: JobName[] },
): Promise<{ verdict: Verdict; lines: string[] }> {
  const lines: string[] = [];
  let sawRows = false;
  let sawUnanswerable = false;

  for (const target of COLLECTIONS_TO_DELETE) {
    try {
      const snap = await db.collection(target.name).count().get();
      const count = snap.data().count;
      if (count > 0) {
        sawRows = true;
        lines.push(`  ${target.name}: ${count} document(s) remain`);
      }

      // `count()` answers over DOCUMENTS, and a parent document deleted while
      // its subcollections survive is not one — Firestore reports zero over
      // live orphaned children. That is precisely the residue this ticket is
      // about: a late trigger write under a parent Phase 2 already removed.
      // `listDocuments()` returns those phantom parents, which is how
      // `probeResidualData` sees the same shape.
      const refs = await db.collection(target.name).listDocuments();
      if (refs.length > count) {
        sawRows = true;
        lines.push(
          `  ${target.name}: ${refs.length - count} deleted parent(s) still ` +
            "hold subcollection documents",
        );
      }
    } catch (err: unknown) {
      sawUnanswerable = true;
      const message = err instanceof Error ? err.message : String(err);
      lines.push(`  ${target.name}: could not be counted — ${message}`);
    }
  }

  // The kept collection's deleted half. Same two answers as the loop above: a
  // surviving row is residue, and a failed read is unanswerable rather than
  // clean — a pass that cannot see `analytics` must not report on it.
  try {
    const residue = await countAnalyticsResidue(db);
    for (const entry of residue.subcollections) {
      sawRows = true;
      lines.push(`  ${entry.path}: ${entry.docs} document(s) remain`);
    }
    for (const entry of residue.parentFields) {
      sawRows = true;
      lines.push(
        `  ${entry.path}: parent document holds ${entry.fields.join(", ")} — ` +
          "the prune deletes subcollections, so a field here survives it",
      );
    }
  } catch (err: unknown) {
    sawUnanswerable = true;
    const message = err instanceof Error ? err.message : String(err);
    lines.push(`  analytics: pruned paths could not be counted — ${message}`);
  }

  // The kill switch must be gone. `clearResetKillSwitch` deletes rather than
  // setting `active: false`, so this is a question with one right answer, and
  // a flag left standing suppresses `onUserDeleted` for every REAL account
  // deletion until its expiry passes.
  try {
    const state = await readResetKillSwitch(db);
    if (state.exists) {
      sawRows = true;
      if (state.expiresAt === undefined) {
        // `readResetKillSwitch` collapses "no usable expiry" into `expired`,
        // which is the right fail-open answer for the TRIGGER and the wrong
        // word for this report: nothing here establishes that a run was raced,
        // only that a document is standing that cannot be attributed.
        lines.push(
          `  ${RESET_KILL_SWITCH_PATH}: malformed — no usable expiry, so it ` +
            "cannot be attributed to this run. Treat its origin as unknown.",
        );
      } else if (state.runId !== undefined && state.runId !== runId) {
        // Another run's flag. The runbook's remedy — delete the document — is
        // the harmful action here, and it is what a reader would do from the
        // `still present` line alone.
        lines.push(
          `  ${RESET_KILL_SWITCH_PATH}: belongs to run ${state.runId}, not ` +
            "this one — do NOT delete it while that run is in progress",
        );
      } else if (state.expired) {
        // Different fault, different sentence. An expired flag means the
        // suppression LAPSED while the wipe was still running, so
        // `onUserDeleted` resumed mid-Phase-2 and wrote into collections this
        // run was deleting. Reporting that as leftover litter would hide it.
        lines.push(
          `  ${RESET_KILL_SWITCH_PATH}: EXPIRED before the run ended — ` +
            "onUserDeleted resumed while Phase 2 was still deleting. Treat " +
            "this run as raced, not merely unclean.",
        );
      } else {
        lines.push(
          `  ${RESET_KILL_SWITCH_PATH}: still present ` +
            `(active=${state.active}, runId=${state.runId ?? "none"}) — the ` +
            "cleanup trigger stays suppressed until this document is deleted " +
            "by hand; see docs/ops/reset-user-data-runbook.md",
        );
      }
    }
  } catch (err: unknown) {
    sawUnanswerable = true;
    const message = err instanceof Error ? err.message : String(err);
    lines.push(`  ${RESET_KILL_SWITCH_PATH}: could not be read — ${message}`);
  }

  // The scheduled jobs must be running again. Cloud Scheduler is ASKED rather
  // than the resume step's own report being believed: that report says what
  // the requests answered, and what the operator needs to know is what state
  // the jobs are in. A job left paused silently stops the weekly safety work
  // — the block-mirror reconciliation among it — for as long as nobody
  // notices.
  try {
    const stillPaused = await findStillPausedJobs(
      scheduler.api,
      scheduler.projectId,
      scheduler.pausedJobs,
    );
    for (const name of stillPaused) {
      sawRows = true;
      lines.push(
        `  scheduler job still PAUSED: ${name} — ${gcloudResumeCommand(name)}`,
      );
    }
  } catch (err: unknown) {
    sawUnanswerable = true;
    const message = err instanceof Error ? err.message : String(err);
    lines.push(
      "  scheduler jobs: could not be re-read, so this run makes no " +
        `statement about whether they are running — ${message}`,
    );
  }

  for (const failure of totals.softFailures) {
    sawUnanswerable = true;
    lines.push(`  unverified: ${failure}`);
  }

  return { verdict: verdictFor(sawRows, sawUnanswerable), lines };
}

async function main() {
  const args = process.argv.slice(2);
  const dryRun = args.includes("--dry-run");

  initializeAdminApp();

  const db = admin.firestore();
  // Resolved to a STRING here, and refused if it is not one. The old
  // expression fell back to `options.credential`, an object, and every later
  // use went through `String(...)` — which would have produced a bucket named
  // `[object Object].firebasestorage.app` and a baffling failure inside the
  // run record, before Phase 1 but after the operator had typed the
  // confirmation phrase.
  const projectId = admin.app().options.projectId;
  if (typeof projectId !== "string" || projectId.length === 0) {
    console.error(
      "REFUSED: could not resolve the Firebase project id from the " +
        "initialized app. Storage paths are built from it, so continuing " +
        "would wipe Firestore and silently skip every file.",
    );
    process.exit(1);
  }

  console.log("=".repeat(60));
  console.log(dryRun ? "  DRY RUN — no data will be modified" : "  LIVE RUN");
  console.log(`  Project: ${projectId}`);
  console.log("=".repeat(60));
  console.log();

  // Safety: verify preserved collections exist
  console.log("Preserved collections:");
  for (const col of COLLECTIONS_TO_KEEP) {
    // The query answers for every collection whose documents carry fields,
    // and costs one read. `analytics` is the exception: its rows sit under
    // parents that carry no fields of their own, so the query returns none of
    // them and the safety line would say "empty" over the whole measurement
    // series this list exists to protect. `listDocuments()` sees those
    // parents, and bills one read per reference — so it runs only where the
    // cheap answer was "nothing", which is the case it exists for.
    const snapshot = await db.collection(col).limit(1).get();
    const hasData =
      !snapshot.empty ||
      (await db.collection(col).listDocuments()).length > 0;
    console.log(`  ${col}: ${hasData ? "has data" : "empty"}`);
  }
  console.log();

  // Verify no overlap between delete and keep lists
  const deleteNames = new Set(COLLECTIONS_TO_DELETE.map((t) => t.name));
  for (const keep of COLLECTIONS_TO_KEEP) {
    if (deleteNames.has(keep)) {
      console.error(
        `SAFETY ERROR: "${keep}" is in both delete and keep lists!`
      );
      process.exit(1);
    }
  }

  // BUT-2036: the scheduled jobs write into the collections Phase 2 deletes.
  // Enumerated in BOTH modes — a dry run's whole purpose is to show what a
  // live run would do, and this list is not knowable any other way.
  const schedulerApi = createSchedulerApi();
  let jobsToPause: JobName[] = [];
  try {
    jobsToPause = await listEnabledSchedulerJobs(schedulerApi, projectId);
    console.log(
      dryRun
        ? `Cloud Scheduler jobs a live run would pause: ${jobsToPause.length}`
        : `Cloud Scheduler jobs to pause: ${jobsToPause.length}`,
    );
    for (const name of jobsToPause) console.log(`  ${name}`);
    console.log();
  } catch (err: unknown) {
    const message = err instanceof Error ? err.message : String(err);
    if (dryRun) {
      // A dry run changes nothing, so refusing it protects nobody and costs
      // the operator the preview they came for.
      console.error(
        `Could not list Cloud Scheduler jobs: ${message} — this dry run ` +
          "makes no statement about them.",
      );
      console.log();
    } else {
      console.error(
        `REFUSED: could not list Cloud Scheduler jobs — ${message}\n` +
          "  The scheduled jobs write into the collections Phase 2 deletes, " +
          "so a run that cannot pause them cannot protect the wipe.\n" +
          "  The account running this needs cloudscheduler.jobs.list, " +
          "pause and resume (roles/cloudscheduler.admin). Nothing has been " +
          "deleted; fix the access and run again.\n" +
          `  gcloud scheduler jobs list --project=${projectId}`,
      );
      process.exit(1);
    }
  }

  // Confirmation gate (live run only)
  if (!dryRun) {
    console.log("This will PERMANENTLY DELETE all user data.");
    console.log(`Type "${CONFIRMATION_PHRASE}" to proceed:\n`);
    const answer = await promptUser("> ");
    if (answer !== CONFIRMATION_PHRASE) {
      console.log("Aborted.");
      process.exit(0);
    }
    console.log();
  }

  const runId = `${new Date().toISOString().replace(/[:.]/g, "-")}-${randomUUID().slice(0, 8)}`;

  // A dry run neither sets the flag nor writes a run record: it changes
  // nothing, so there is nothing to suppress and nothing to account for.
  //
  // The live-run steps sit ABOVE the `try` rather than in a branch beside it,
  // so exactly one call reaches the phases. A second call in a dry-run branch
  // would stand textually before the set, which makes "the flag is set before
  // anything runs" unreadable from the source — and source is all a test has
  // here, since `main()` takes no injectable store.
  // Declared before the handler that closes over it: it is the live record
  // of what is switched off, and the handler may fire at any point after the
  // first pause lands.
  const pausedJobs: JobName[] = [];

  // Signals bypass `finally`. Without this, Ctrl-C during a wipe leaves the
  // trigger suppressed for the rest of the TTL, with no Phase 4 to report it
  // and nothing on screen saying so.
  let signalHandled = false;
  const onSignal = (signal: NodeJS.Signals) => {
    // Re-entry guard. A second Ctrl-C is the normal reflex when the first
    // appears to do nothing during a long delete, and without this it can
    // reach `process.exit(130)` while the first clear's transaction is still
    // open — leaving the flag set, which is the state this handler exists to
    // prevent.
    if (signalHandled) return;
    signalHandled = true;
    console.error(
      `\nReceived ${signal} — clearing the kill switch and resuming the ` +
        "scheduled jobs.",
    );
    void (async () => {
      try {
        await clearResetKillSwitch(db, runId);
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        console.error(
          `FAILED TO CLEAR THE KILL SWITCH on ${signal}: ${message} — ` +
            "delete it by hand; see docs/ops/reset-user-data-runbook.md",
        );
      }
      // An interrupted run must not leave the schedule off. There is no
      // Phase 4 on this path to report a job left paused, so every failure
      // has to carry its own recovery command here.
      const resumed = await resumeJobs(schedulerApi, pausedJobs);
      for (const failure of resumed.failed) {
        console.error(
          `LEFT PAUSED on ${signal}: ${failure.name} (${failure.message}) — ` +
            gcloudResumeCommand(failure.name),
        );
      }
      process.exit(130);
    })();
  };
  if (!dryRun) {
    await recordRunOutOfBand(projectId, runId, args, jobsToPause);

    // Registered BEFORE the first pause, not after it. Everything between the
    // first job going off and the `try` below is outside `finally`, so a
    // signal — or a throw — in that window would otherwise leave the whole
    // schedule switched off with nothing on screen saying so.
    process.on("SIGINT", onSignal);
    process.on("SIGTERM", onSignal);

    // Paused BEFORE the kill switch and released after it, so the outer thing
    // acquired is the outer thing released. Recorded per job as it goes: the
    // returned list arrives only once every job has been tried, and an
    // interrupt in the middle would find `pausedJobs` empty while jobs were
    // already off.
    const paused = await pauseJobs(schedulerApi, jobsToPause, (name) =>
      pausedJobs.push(name),
    );
    if (paused.failed.length > 0) {
      console.error("REFUSED: could not pause every Cloud Scheduler job.");
      for (const failure of paused.failed) {
        // The command is printed for a FAILED pause too. A request that timed
        // out may still have been applied, and such a job is in no list this
        // run resumes from and outside Phase 4's scope.
        console.error(
          `  ${failure.name}: ${failure.message} — if this pause landed ` +
            `anyway: ${gcloudResumeCommand(failure.name)}`,
        );
      }
      // Refusing while holding the jobs down is the failure this exists to
      // prevent, so what was paused goes back before the exit.
      const rollback = await resumeJobs(schedulerApi, pausedJobs);
      for (const failure of rollback.failed) {
        console.error(
          `  LEFT PAUSED: ${failure.name} (${failure.message}) — ` +
            gcloudResumeCommand(failure.name),
        );
      }
      console.error(
        "  Nothing has been deleted. The account running this needs " +
          "cloudscheduler.jobs.pause and resume (roles/cloudscheduler.admin).",
      );
      process.exit(1);
    }
    console.log(`Cloud Scheduler: ${pausedJobs.length} job(s) paused.`);

    // Its own guard: this sits between the pause and the `try`, so a throw
    // here reaches `main().catch` and no `finally` ever runs. The jobs are
    // already off at this point.
    try {
      await setResetKillSwitch(db, runId);
    } catch (err: unknown) {
      const message = err instanceof Error ? err.message : String(err);
      console.error(`REFUSED: could not set the kill switch — ${message}`);
      const rollback = await resumeJobs(schedulerApi, pausedJobs);
      for (const failure of rollback.failed) {
        console.error(
          `  LEFT PAUSED: ${failure.name} (${failure.message}) — ` +
            gcloudResumeCommand(failure.name),
        );
      }
      console.error("  Nothing has been deleted.");
      process.exit(1);
    }
    console.log(
      `Kill switch SET (${RESET_KILL_SWITCH_PATH}, run ${runId}) - ` +
        "onUserDeleted is suppressed for this run.",
    );
    console.log();
  }

  // A dry run sets no flag, so its refresher is a no-op rather than a branch
  // inside `runPhases` — the phases should not have to know.
  //
  // The time cursor lives here rather than in the phases, so every call site
  // down the walk can be an unconditional `await` and none of them has to
  // carry a budget of its own.
  let lastRefresh = Date.now();
  const maybeRefreshKillSwitch = dryRun
    ? async () => {}
    : async () => {
        if (Date.now() - lastRefresh < KILL_SWITCH_REFRESH_INTERVAL_MS) return;
        lastRefresh = Date.now();
        try {
          await setResetKillSwitch(db, runId);
        } catch (err: unknown) {
          const message = err instanceof Error ? err.message : String(err);
          // Not fatal, and not silent: the flag still has whatever expiry it
          // was last given, so the run continues under a suppression that may
          // lapse. Phase 4 reports an expired flag as a RACED run.
          console.error(
            `Warning: could not refresh the kill switch: ${message}`,
          );
        }
      };

  let totals: PhaseTotals;
  try {
    totals = await runPhases(db, projectId, dryRun, maybeRefreshKillSwitch);
  } finally {
    // `finally`, so an exception anywhere in the three phases still lifts the
    // suppression. If this itself fails the flag survives, which is why it
    // carries an expiry and why the verification phase asks about it.
    if (!dryRun) {
      try {
        const cleared = await clearResetKillSwitch(db, runId);
        if (cleared) {
          console.log(`Kill switch CLEARED (${RESET_KILL_SWITCH_PATH}).`);
        } else {
          // The stored run id is not ours: another run set the flag after we
          // did. Deleting it would leave that run wiping with the trigger
          // live, which is the failure this module exists to prevent.
          console.error(
            `Kill switch left standing: ${RESET_KILL_SWITCH_PATH} belongs to ` +
              "another run. Do NOT delete it while that run is in progress.",
          );
        }
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        console.error(
          `FAILED TO CLEAR THE KILL SWITCH (${RESET_KILL_SWITCH_PATH}): ` +
            `${message}` +
            " onUserDeleted stays suppressed until this document is deleted " +
            `by hand or its expiry passes (${RESET_KILL_SWITCH_TTL_MINUTES} ` +
            "minutes from when it was set).",
        );
      }

      // Its own try, beside the kill switch's rather than inside it: a failure
      // to clear the flag must not skip the resume, and a failure to resume
      // must not hide the flag's outcome. Phase 4 re-reads both, so this is
      // the attempt and not the measurement.
      try {
        const resumed = await resumeJobs(schedulerApi, pausedJobs);
        console.log(`Cloud Scheduler: ${resumed.done.length} job(s) resumed.`);
        for (const failure of resumed.failed) {
          console.error(
            `FAILED TO RESUME ${failure.name}: ${failure.message} — ` +
              gcloudResumeCommand(failure.name),
          );
        }
      } catch (err: unknown) {
        const message = err instanceof Error ? err.message : String(err);
        console.error(
          `FAILED TO RESUME the Cloud Scheduler jobs: ${message} — they stay ` +
            "paused until somebody resumes them; see " +
            "docs/ops/reset-user-data-runbook.md",
        );
      }
      console.log();
    }
  }

  // --- Phase 4: Verification and summary ---
  const totalDocs = totals.results.reduce((sum, r) => sum + r.docs, 0);
  const totalSubDocs = totals.results.reduce(
    (sum, r) => sum + Object.values(r.subs).reduce((s, v) => s + v, 0),
    0,
  );

  console.log("=".repeat(60));
  console.log(dryRun ? "  DRY RUN SUMMARY" : "  CLEANUP FINISHED");
  console.log("=".repeat(60));
  console.log(
    `  Auth users ${dryRun ? "to delete" : "deleted"}: ${totals.authUsers}`,
  );
  console.log(
    `  Firestore docs ${dryRun ? "to delete" : "deleted"}: ${totalDocs} parent + ${totalSubDocs} subcollection`,
  );
  console.log(
    `  Storage files ${dryRun ? "to delete" : "deleted"}: ${totals.storageFiles}`,
  );
  console.log("  Preserved: " + COLLECTIONS_TO_KEEP.join(", "));
  // `analytics` is on that list and is not untouched: `pruneAnalytics` deletes
  // every subcollection under it that is not a measurement series. Saying so
  // beside the list, because a name in a "preserved" line reads as whole.
  console.log(
    "  Preserved with exceptions: analytics — its measurement series are " +
      "kept, its per-person rows are deleted",
  );
  // The register, printed beside the list with teeth. A collection that is
  // neither deleted nor protected is the shape this ticket was filed about, so
  // a summary that names only the protected ones reproduces the silence one
  // step over — it reads as a complete account of what survived, and is not.
  console.log(
    "  Left alone (decided, not protected): " +
      Object.keys(COLLECTIONS_DELIBERATELY_UNTOUCHED).join(", "),
  );
  console.log();

  // BUT-2043: what the DATABASE holds that no list decides. The three lines
  // above report what the LISTS say, which is the answer to a different
  // question — and BUT-2040 is what the difference costs: a spelling left by a
  // rename, named by no list and no longer by any code, found only because a
  // person read a dry run's output closely. Report only; nothing below changes
  // what this run deleted.
  console.log("Unknown collections (report only, nothing was skipped)");
  try {
    const rootCollections = await db.listCollections();
    const lines = formatUnknownCollections(
      findUnknownCollections({
        topLevelInDb: rootCollections.map((c) => c.id),
        subCountsByTarget: totals.results,
      }),
    );
    for (const line of lines) console.log(line);
  } catch (err) {
    // A failed report must not change the run's verdict: it deleted what it
    // deleted either way, and swallowing the error silently would leave a
    // reader believing the "none" case was measured.
    console.log(
      `  REPORT FAILED (${err instanceof Error ? err.message : String(err)}) ` +
        "— this run made no statement about unknown collections.",
    );
  }
  console.log();

  if (dryRun) {
    // Not "clean" and not "indeterminate": a dry run deleted nothing, so
    // there is no state for a verdict to be about.
    console.log("  Dry run — no verification pass, and no verdict.");
    return;
  }

  console.log("Phase 4: verification (counts only, deletes nothing)");
  const { verdict, lines } = await verifyReset(db, totals, runId, {
    api: schedulerApi,
    projectId,
    pausedJobs,
  });
  for (const line of lines) console.log(line);
  if (lines.length === 0) console.log("  nothing left to report");
  console.log();

  console.log(`  VERDICT: ${verdict.toUpperCase()}  (run ${runId})`);
  if (verdict !== "clean") {
    console.log(
      "  A second pass can show that residue EXISTS. Nothing here can show " +
        "it is finished: onUserDeleted is a gen1 trigger with no bounded " +
        "delivery time and no retry, so an event may still arrive — or may " +
        "have been dropped.",
    );
  }
  process.exitCode = EXIT_CODE_BY_VERDICT[verdict];
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
