/**
 * Reset User Data — Clean Slate Script
 *
 * Wipes the collections named in `COLLECTIONS_TO_DELETE` below from Firebase
 * (Auth + Firestore + Storage), preserving config/seed data (site_configs,
 * tag_configs, ingredients, etc.).
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
 */
async function verifyReset(
  db: admin.firestore.Firestore,
  totals: PhaseTotals,
  runId: string,
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
  console.log("Preserved collections (will NOT be touched):");
  for (const col of COLLECTIONS_TO_KEEP) {
    const snapshot = await db.collection(col).limit(1).get();
    const status = snapshot.empty ? "empty" : "has data";
    console.log(`  ${col}: ${status}`);
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
  // Both live-run steps sit ABOVE the `try` rather than in a branch beside it,
  // so exactly one call reaches the phases. A second call in a dry-run branch
  // would stand textually before the set, which makes "the flag is set before
  // anything runs" unreadable from the source — and source is all a test has
  // here, since `main()` takes no injectable store.
  if (!dryRun) {
    await recordRunOutOfBand(projectId, runId, args);
    await setResetKillSwitch(db, runId);
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
    console.error(`\nReceived ${signal} — clearing the kill switch.`);
    void clearResetKillSwitch(db, runId)
      .catch((err: unknown) => {
        const message = err instanceof Error ? err.message : String(err);
        console.error(
          `FAILED TO CLEAR THE KILL SWITCH on ${signal}: ${message} — ` +
            "delete it by hand; see docs/ops/reset-user-data-runbook.md",
        );
      })
      .finally(() => process.exit(130));
  };
  if (!dryRun) {
    process.on("SIGINT", onSignal);
    process.on("SIGTERM", onSignal);
  }

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
  console.log();

  if (dryRun) {
    // Not "clean" and not "indeterminate": a dry run deleted nothing, so
    // there is no state for a verdict to be about.
    console.log("  Dry run — no verification pass, and no verdict.");
    return;
  }

  console.log("Phase 4: verification (counts only, deletes nothing)");
  const { verdict, lines } = await verifyReset(db, totals, runId);
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
