/**
 * BUT-2046 follow-up: a legal hold over an OPEN moderation case.
 *
 * BUT-2046 shipped a named residual: a reported person could delete their
 * account and take the evidence of an open review with them. Art. 17(3)(e)
 * covers the window while the case is open, and 17(3)(b) the period once a DSA
 * Art. 17 statement-of-reasons duty is live — DSA Art. 17 sits in Section 2,
 * which Art. 19 does NOT exempt micro/small enterprises from.
 *
 * WHAT IS AND IS NOT HELD. The hold is the narrowest exception the case needs,
 * not a pause on erasure: the rest of the cascade runs untouched. Held are the
 * moderation record and its rows, and the reported person's uid on the report
 * and on its `system_events` counterpart — the two anonymizers, not one, and
 * that pair is the whole point (a report kept without its ops-log row is a
 * half-held case).
 *
 * ONE-DIRECTIONAL, DELIBERATELY. `deleteUserReports`, the reporter leg of
 * `deleteModerationSystemEvents` and `deleteReportHistoryByReporter` carry no
 * status check, so a REPORTER's erasure still empties an open case. Out of
 * scope, named rather than left to be discovered.
 *
 * WHERE THE DECISION LIVES. `erasure_holds/{uid}`, its own collection with no
 * `firestore.rules` block — the terminal `match /{document=**}` denies every
 * client, so only the Admin SDK reads it. It is deliberately NOT a field on
 * `user_moderation/{uid}`: that document's read limb is a
 * `hasOnly(['totalReports','lastReportedAt'])` allowlist, and a new field would
 * make the whole document unreadable to its own subject and fail their Art. 15
 * moderation section closed. The hold is written BEFORE `auth.deleteUser`, so
 * an erasure aborting after that write would leave a live account carrying the
 * breakage permanently.
 *
 * SCOPE IS WRITTEN ONCE; OPENNESS IS RECOMPUTED. The hold document records
 * WHICH rows are held — decided once, in the cascade, because the evidence does
 * not change after the erasure. The sweep asks each day whether any case is
 * still open, over ALL cases against the person, because that is the thing that
 * can have changed since yesterday. Deriving the scope again at sweep time
 * would give two truths at two times.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../shared/batch-update";
import { stageCascadeAuditEntry } from "../cleanup/cascade-audit-log";
import {
  deleteModerationRecord,
  deleteModerationSystemEvents,
  // The value `retainedRecord()` stamps into `resourceType`, and the value both
  // `held` predicates compare against. Imported rather than re-declared: the
  // PRODUCER is the participant that can break both consumers at once.
  USER_MODERATION,
  type RetainedRecord,
} from "../account/account-deletion-cascade";
import { Collections } from "../shared/collections";
import { anonymizeReportsByContentOwnerWithDb } from "./anonymize-reports";

const REPORTS = "reports";
const REPORT_HISTORY = "report_history";

/**
 * The outer cap, independent of anyone closing the case. A case nobody triages
 * never closes, and a hold with no cap is a permanent refusal wearing a
 * temporary one's clothes.
 *
 * Its own constant rather than `AUDIT_LOG_RETENTION_DAYS`, which is
 * module-private to `request-account-deletion.ts` and answers a different
 * question (how long an audit row is kept). Two purposes behind one number is
 * how the number gets changed for the wrong reason.
 */
export const ERASURE_HOLD_MAX_DAYS = 180;

/** The article the retention rests on, spelled once. */
const LEGAL_BASIS = "GDPR Art. 17(3)(e)";

/**
 * Cap on one sweep run. The sibling caps in this domain
 * (`MAX_REPORT_HISTORY_SWEEP_ROWS`, `MAX_SYSTEM_EVENT_SWEEP_ROWS`,
 * `MAX_ROSTER_SWEEP_ROWS`) all decline rather than truncate, and so does this.
 *
 * It is load-bearing for a second reason the siblings do not have: this sweep
 * runs FIRST in `DAILY_ANALYTICS_TASKS`, and `runTaskChain` ABORTS the chain on
 * a timeout. An unbounded sweep in first position could take all the daily
 * analytics jobs down with it, every day.
 */
export const MAX_ERASURE_HOLD_SWEEP_ROWS = 500;

/**
 * Cap on the TTL push for ONE held person. Mirrors
 * `MAX_REPORT_HISTORY_SWEEP_ROWS` in the cascade, and for its reason rather
 * than the poll cap's: anyone may report this user and no client throttle
 * bounds how many rows accumulate.
 */
export const MAX_REPORT_HISTORY_ROWS = 2000;

/**
 * Every status that is NOT terminal. `ReportStatus` (the Dart model) has four
 * values and `closed` is the only one this treats as finished — `actioned`
 * reads as done, and is deliberately still held: a case a moderator has acted
 * on but not closed keeps its evidence until they close it. The cautious
 * direction, and it gives the close button a consequence it did not have.
 *
 * The `in` filter, rather than `!=`, is what keeps this query servable by the
 * single-field indexes: equality plus `in` with no `orderBy` needs no composite
 * index, while a literal `!=` would need one.
 */
const OPEN_REPORT_STATUSES = ["new", "in_review", "actioned"] as const;

export type { RetainedRecord };

/**
 * What the hold evaluation decided, and whether it got there cleanly.
 *
 * `ok: false` means the erasure is incomplete and must say so — but `retained`
 * is still authoritative, so the caller holds. Separating the two is the whole
 * point: a failure must not cost the ANSWER.
 */
export interface HoldOutcome {
  retained: RetainedRecord[];
  ok: boolean;
}

/**
 * Is at least one report against [uid] still open?
 *
 * The ONE implementation of the predicate. It is now the fourth place the same
 * fact is spelled — beside `ReportStatus`, `firestore.rules` and
 * `report_service.dart` — so it does not get spelled a fifth time inline.
 */
export async function hasOpenModerationCase(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection(REPORTS)
    .where("contentOwnerId", "==", uid)
    .where("status", "in", [...OPEN_REPORT_STATUSES])
    .limit(1)
    .get();
  return !snap.empty;
}

function holdUntilFrom(now: Date): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromDate(
    new Date(now.getTime() + ERASURE_HOLD_MAX_DAYS * 24 * 60 * 60 * 1000),
  );
}

/**
 * Evaluate the hold and, if it applies, record it and protect what it covers.
 *
 * Returns the records retained — empty when nothing is held, which is the
 * ordinary case and the one that must stay indistinguishable from today's
 * behaviour.
 *
 * The TTL rewrite is not housekeeping — see the inline note on the push for
 * why, and for the two branches that skip it.
 */
export async function applyErasureHold(
  db: admin.firestore.Firestore,
  uid: string,
  now: Date = new Date(),
): Promise<HoldOutcome> {
  const holdUntil = holdUntilFrom(now);

  // FAILS CLOSED, and the guard covers EVERY step that can throw — including
  // the TTL push, which the `strict: true` below makes far likelier to. An
  // unanswerable question here must not resolve to "nothing was held": the
  // caller's `held` is what stops the cascade's moderation steps and the
  // `onUserDeleted` anonymize from destroying the evidence, so a throw escaping this function
  // would leave the hold document standing while the cascade erased the very
  // rows it claims to keep. Keeping data is recoverable; destroying it is not.
  //
  // A failure is reported through `ok`, never by throwing: `runStep` records a
  // false return in `failedCollections` just as it records a throw, and this
  // way the ANSWER survives the failure.
  try {
    if (!(await hasOpenModerationCase(db, uid))) {
      return { retained: [], ok: true };
    }
    await writeHoldDocument(db, uid, holdUntil, { provisional: false });
  } catch (err) {
    logger.error("[erasure-hold] hold undecidable; holding provisionally", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    // A provisional hold is not a guess that a case is open. It records that we
    // could not tell, and the daily sweep re-evaluates openness from scratch —
    // so a hold placed here over a closed case is lifted on the first clean
    // run. If THIS write fails too there is nothing left to fall back on, so
    // the throw escapes and the erasure reports itself incomplete.
    await writeHoldDocument(db, uid, holdUntil, { provisional: true });
    return { retained: [retainedRecord(holdUntil, true)], ok: false };
  }

  // Only now the TTL push, and STRICTLY. `report_history` rows carry a live
  // 180-day TTL counted from when the REPORT was written, while the hold runs
  // 180 days from the ERASURE — so a report filed a month before the deletion
  // would age out mid-hold and leave the sweep guarding nothing.
  //
  // Strict because `commitInChunks` defaults to swallowing a failed chunk with
  // a warn: silently unprotected rows would then die on the report's clock, and
  // the two probe legs that would have seen them are exactly the ones a hold
  // skips.
  //
  // Capped for the same reason `MAX_REPORT_HISTORY_SWEEP_ROWS` exists in the
  // cascade — the row count on this subcollection is chosen by OTHER
  // PEOPLE, since anyone may report this user and nothing throttles it. Above
  // the cap the push is SKIPPED and reported as a failure rather than
  // truncated: a partial push leaves some rows on the report's clock.
  try {
    const history = await db
      .collection(USER_MODERATION)
      .doc(uid)
      .collection(REPORT_HISTORY)
      .limit(MAX_REPORT_HISTORY_ROWS + 1)
      .get();

    if (history.size > MAX_REPORT_HISTORY_ROWS) {
      logger.error(
        "[erasure-hold] implausible report_history count; TTL not pushed",
        { uid_prefix: uid.slice(0, 6), rows: history.size },
      );
      return { retained: [retainedRecord(holdUntil, false)], ok: false };
    }

    if (!history.empty) {
      await commitInChunks(
        db,
        history.docs,
        (batch, doc) => {
          batch.update(doc.ref, { expireAt: holdUntil });
        },
        {
          label: `BUT-2046: hold TTL push for ${uid.slice(0, 6)}`,
          opsPerItem: 1,
          strict: true,
        },
      );
    }

    logger.info("[erasure-hold] hold placed", {
      uid_prefix: uid.slice(0, 6),
      heldRowCount: history.size,
    });
  } catch (err) {
    logger.error(
      "[erasure-hold] TTL push failed; hold stands, erasure incomplete",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
    return { retained: [retainedRecord(holdUntil, false)], ok: false };
  }

  return { retained: [retainedRecord(holdUntil, false)], ok: true };
}

function retainedRecord(
  holdUntil: admin.firestore.Timestamp,
  provisional: boolean,
): RetainedRecord {
  return {
    resourceType: USER_MODERATION,
    legalBasis: LEGAL_BASIS,
    holdUntil,
    provisional,
  };
}

async function writeHoldDocument(
  db: admin.firestore.Firestore,
  uid: string,
  holdUntil: admin.firestore.Timestamp,
  opts: { provisional: boolean },
): Promise<void> {
  const batch = db.batch();
  batch.set(db.collection(Collections.erasureHolds).doc(uid), {
    holdUntil,
    createdAt: admin.firestore.FieldValue.serverTimestamp(),
    legalBasis: LEGAL_BASIS,
    // Descriptive only — the sweep treats both kinds identically, because it
    // recomputes openness.
    provisional: opts.provisional,
  });
  stageCascadeAuditEntry(db, batch, {
    subjectUserId: uid,
    targetUid: null,
    operation: "cascade_retain",
    resourceType: Collections.erasureHolds,
    resourceId: uid,
    extra: { legalBasis: LEGAL_BASIS, provisional: opts.provisional },
  });
  await batch.commit();
}

/**
 * Finish the erasure a hold deferred: both anonymizers, then the moderation
 * record, then the hold document itself.
 *
 * The hold document goes LAST. If any step above it fails, the hold stands and
 * tomorrow's run tries again — the alternative, clearing the decision first,
 * would leave evidence nothing is tracking and no path able to find it.
 *
 * `deleteModerationSystemEvents` is re-run whole rather than reduced to its
 * anonymize half: its reporter leg finds nothing (the cascade already swept it)
 * and its threshold-row delete is idempotent, so running it entire keeps ONE
 * implementation of what a moderation erasure means.
 */
export async function liftErasureHold(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const eventsOk = await deleteModerationSystemEvents(db, uid);
  await anonymizeReportsByContentOwnerWithDb(db, uid);
  const recordOk = await deleteModerationRecord(db, uid);

  // The anonymize CANNOT be judged by its return value: it commits through
  // `commitInChunks` with the default `strict: false`, which swallows a failed
  // chunk with a warn, and it returns docs MATCHED rather than commits that
  // succeeded. So it is re-probed on its own discovery field instead.
  //
  // This matters more than it looks. Once the hold document is deleted, a row
  // still naming the erased uid is reachable by NOTHING: the account is gone so
  // no cascade runs, `probeResidualData` ran before the erasure and has no
  // `reports` leg, and the sweep's only handle is the document about to be
  // removed. The hold standing for another day is the recoverable outcome.
  const stillNamed = await db
    .collection(REPORTS)
    .where("contentOwnerId", "==", uid)
    .limit(1)
    .get();

  if (!eventsOk || !recordOk || !stillNamed.empty) {
    logger.error("[erasure-hold] lift incomplete; hold stands", {
      uid_prefix: uid.slice(0, 6),
      eventsOk,
      recordOk,
      reportsStillNamed: !stillNamed.empty,
    });
    return false;
  }

  const batch = db.batch();
  batch.delete(db.collection(Collections.erasureHolds).doc(uid));
  stageCascadeAuditEntry(db, batch, {
    subjectUserId: uid,
    targetUid: null,
    operation: "cascade_delete",
    resourceType: Collections.erasureHolds,
    resourceId: uid,
  });
  await batch.commit();

  logger.info("[erasure-hold] hold lifted", { uid_prefix: uid.slice(0, 6) });
  return true;
}

export interface HoldSweepResult {
  /** Holds actually looked at. Below the page size when the run deferred. */
  examined: number;
  lifted: number;
  failed: number;
  declined: boolean;
  /** True when the run stopped on its own clock with holds left to examine. */
  deferred: boolean;
}

/**
 * Wall-clock budget for one run, comfortably inside `TASK_TIMEOUT_MS` (60 s).
 *
 * The row cap bounds how many holds are READ; this bounds how long working
 * through them may take, which is the number that actually matters in FIRST
 * chain position — `runTaskChain` ABORTS the whole daily chain on a timeout,
 * and each hold costs a predicate query plus several sequential writes.
 *
 * Stopping early is safe here in a way it would not be for a destructive sweep:
 * a LIFT deferred to tomorrow keeps data one day longer, which is the direction
 * this whole build errs in anyway.
 */
const SWEEP_DEADLINE_MS = 45_000;

/**
 * The daily pass. Lifts a hold whose last case has closed, or whose outer cap
 * has passed — whichever comes first.
 *
 * Openness is recomputed here over ALL cases against the person, which is the
 * binding half of the panel's condition J: a hold must not survive because one
 * case closed while another was never looked at, nor die because the case it
 * was placed for happened to close.
 */
export async function sweepErasureHolds(
  db: admin.firestore.Firestore,
  now: Date = new Date(),
  /** Injectable so the budget branch is reachable from a test. */
  deadlineMs: number = SWEEP_DEADLINE_MS,
): Promise<HoldSweepResult> {
  const snap = await db
    .collection(Collections.erasureHolds)
    .limit(MAX_ERASURE_HOLD_SWEEP_ROWS + 1)
    .get();

  if (snap.size > MAX_ERASURE_HOLD_SWEEP_ROWS) {
    logger.error("[erasure-hold] implausible hold count; not sweeping", {
      rows: snap.size,
    });
    return {
      examined: 0,
      lifted: 0,
      failed: 0,
      declined: true,
      deferred: false,
    };
  }

  let lifted = 0;
  let failed = 0;
  let examined = 0;
  let deferred = false;
  const startedAt = Date.now();

  for (const doc of snap.docs) {
    if (Date.now() - startedAt >= deadlineMs) {
      deferred = true;
      // Counted per ITERATION, not from `lifted + failed`: the common outcome
      // is a still-open hold that `continue`s, which is neither.
      logger.warn("[erasure-hold] sweep out of budget; rest deferred a day", {
        examined,
        remaining: snap.size - examined,
      });
      break;
    }
    examined += 1;
    const uid = doc.id;

    // Per-hold isolation. Without it one unlucky uid aborts the run and every
    // hold after it in the page is never examined — the same page, in the same
    // order, tomorrow, so a single bad row could stall every other person's
    // erasure indefinitely.
    try {
      const holdUntil = doc.get("holdUntil") as
        | admin.firestore.Timestamp
        | undefined;
      const capPassed = holdUntil ? holdUntil.toDate() <= now : true;

      if (!capPassed && (await hasOpenModerationCase(db, uid))) continue;

      if (capPassed && !holdUntil) {
        // A hold with no cap is a hold nothing can end. Lift it and say so
        // rather than leave a permanent refusal in place.
        logger.error("[erasure-hold] hold has no holdUntil; lifting", {
          uid_prefix: uid.slice(0, 6),
        });
      }
      if (await liftErasureHold(db, uid)) lifted += 1;
      else failed += 1;
    } catch (err) {
      failed += 1;
      logger.error("[erasure-hold] hold sweep failed for one uid", {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }

  return { examined, lifted, failed, declined: false, deferred };
}

/**
 * Scheduled seam — the maintenance chain calls this, tests call
 * `sweepErasureHolds` with an injected Firestore and clock.
 *
 * `admin.firestore()` is resolved per call rather than at module scope: this
 * module is imported by the deletion callable, and a module-scope handle would
 * demand an initialised app at import time.
 */
export async function runSweepErasureHolds(): Promise<void> {
  const result = await sweepErasureHolds(admin.firestore());
  logger.info("[erasure-hold] sweep complete", {
    examined: result.examined,
    lifted: result.lifted,
    failed: result.failed,
    declined: result.declined,
    deferred: result.deferred,
  });
}

/**
 * BUT-2046 follow-up: the reported person's uid survives on `reports` while a
 * legal hold stands, and this is the guard that makes that true.
 *
 * It reads the cascade's DECISION out of `erasure_holds/{uid}` rather than
 * re-deriving the predicate. `onUserDeleted` runs after `auth.deleteUser`, so
 * the cascade has already decided; a second evaluation here could disagree with
 * the first, and two answers about one erasure is worse than either.
 *
 * FAILS CLOSED. This is a gen1 Auth trigger with no `failurePolicy`, so an
 * unhandled throw would cost the steps after it with nothing to retry them —
 * and treating an unreadable hold as "no hold" would destroy evidence the
 * cascade decided to keep. An unanswerable question defers to the daily sweep,
 * which re-evaluates openness anyway.
 *
 * `liftErasureHold` deliberately calls `anonymizeReportsByContentOwnerWithDb`
 * directly, NOT this: by then the hold document still exists and is the very
 * thing being released, so routing the lift through this guard would make it a
 * no-op forever.
 *
 * Graded at its real call site by `on-user-deleted.integration.test.ts`, which
 * drives `cleanupUserSocialData` for a held and an unheld subject.
 *
 * NO CI LANE RUNS THAT SUITE. `check-test-registration.js` lists it in
 * `KNOWN_UNREACHABLE` (BUT-1702), the CI unit runner excludes every
 * `test:integration:` prefix, and `test:rules:all` does not name it — so the
 * pin exists and is proven by a HAND run against a local emulator, not by
 * anything automated. The twin on `system_events` is graded in the unit lane
 * through the orchestration suite's query recorder, and that difference is the
 * whole reason to say this out loud.
 */
export async function anonymizeReportsUnlessHeldWithDb(
  database: admin.firestore.Firestore,
  userId: string
): Promise<number> {
  try {
    const onHold = (
      await database.collection(Collections.erasureHolds).doc(userId).get()
    ).exists;
    if (onHold) return 0;
  } catch (err) {
    // FAILS CLOSED — but a bare skip here would fail closed into a state
    // NOTHING can recover: with no hold document the sweep never sees this uid,
    // the account is gone so no cascade re-runs, `deleteUserReports` filters
    // `reporterId` and misses the reported-side rows, and `probeResidualData`
    // has no `reports` leg and ran before `auth.deleteUser` anyway. The uid
    // would sit on third parties' rows permanently behind one ERROR log.
    //
    // So the deferral leaves a HANDLE: a provisional hold, which the daily
    // sweep re-evaluates and lifts on its first clean run — calling this
    // anonymizer then. Same shape as `applyErasureHold`'s own fallback, and it
    // is what makes "defers to the sweep" true rather than aspirational.
    logger.error("[erasure-hold] hold read failed; deferring to the sweep", {
      uid_prefix: userId.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    try {
      await writeHoldDocument(database, userId, holdUntilFrom(new Date()), {
        provisional: true,
      });
    } catch (writeErr) {
      // Both the read AND the fallback write failed. There is no handle left,
      // and nothing above this catches — so letting the throw escape would
      // cost the cascade steps behind step 13 on a gen1 trigger with no
      // `failurePolicy`, which is the harm this whole guard exists to avoid.
      // Named residual: the uid stays on third parties' `reports` rows,
      // reachable by no cascade, probe, sweep or export.
      logger.error("[erasure-hold] no handle left; residual uid on reports", {
        uid_prefix: userId.slice(0, 6),
        errName: writeErr instanceof Error ? writeErr.name : typeof writeErr,
      });
    }
    return 0;
  }
  return anonymizeReportsByContentOwnerWithDb(database, userId);
}
