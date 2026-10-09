/**
 * Detect Lapsed Users (BUT-688 win-back A/B variant resolution).
 *
 * Runs in the `dailyAnalytics` chain (06:00 UTC — see
 * `scheduled/maintenance-dispatchers.ts`); it no longer owns a Cloud
 * Scheduler job. Deliberately ahead of the reporting tasks because it is the
 * one task in that chain that reaches a user. Identifies users inactive
 * for 7, 14, or 30 days and writes win-back notifications. Push copy
 * is resolved per-user via Remote Config + a deterministic
 * SHA-256(uid:thresholdType) bucket — see `./winback-variant.ts`.
 *
 * Firestore writes:
 *   /analytics/lapsed_users/events/{uid}_{type}_{lastActiveAt ms} — lapsed user event
 *   /users/{userId}/notifications/winback_{type}_{lastActiveAt ms} — win-back notification
 *   /users/{userId}                              — merge: lastWinBack* fields
 *   /_internal/lapsed_users_cursor               — per-threshold resume point
 *
 * The `lastWinBack*` fields on the user doc are the bridge to the FA
 * dashboard: the client reads them at session start and forwards the
 * variant to FA via `ExperimentAssignment.setExperimentAssignment`
 * (BUT-657). The server cannot set FA user properties directly.
 *
 * Bridge-field gating (BUT-1428): `lastWinBack*` normally overwrites on
 * every threshold trigger — a user can legitimately progress mild →
 * moderate → strong through the dormancy stages. BUT while an EARLIER
 * send is still un-attributed and inside its 7-day attribution window the
 * overwrite is SKIPPED: clobbering it would let the client's single-
 * attribution latch credit the conversion to the later variant and bias
 * the A/B toward whichever stage fired last. The client CLEARS these
 * fields on attribution, so their presence + freshness means "earlier
 * send not yet attributed". A stale prior send (past the window) is safe
 * to overwrite. The user still receives this notification either way;
 * only the attribution bridge is preserved.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { sendPushToUserRespectingPreferences } from "../shared/preference-aware-push";
import { evaluateSendGate } from "../shared/notification-gate";
import { recordNotificationSendEvent } from "../shared/notification-send-events";
import { resolveWinbackVariant, fetchWinbackCopy } from "./winback-variant";
import {
  resolveContextualWinbackCopy,
  type ContextualCopy,
} from "./winback-context";
import {
  processLapsedPage,
  type LapsedThreshold,
  type PageResult,
} from "./lapsed-users-page";

const getDb = () => admin.firestore();

const MS_PER_HOUR = 60 * 60 * 1000;
const MS_PER_DAY = 24 * MS_PER_HOUR;

/** BUT-1567: on the very first run (no stored cursor) we don't want to sweep
 *  every dormant user who ever crossed a threshold in one giant backfill.
 *  Default the cursor to one scheduling interval back so the first run
 *  behaves like a normal daily run; every subsequent run reads the real
 *  stored cursor. */
const DEFAULT_CURSOR_LOOKBACK_MS = MS_PER_DAY;

/** BUT-1567: the cursor doc holding `lastRunAt` — the parent of the
 *  lapsed-user events subcollection (a Firestore doc can carry fields AND
 *  own subcollections). */
const CURSOR_DOC = { collection: "analytics", doc: "lapsed_users" } as const;

/**
 * BUT-1671: where each threshold's window resumes, one `lastActiveAt`
 * Timestamp per threshold type. A timestamp and never a uid: a full page is
 * extended with every user sharing its last `lastActiveAt`, so the next page
 * can start strictly after it. Kept off `analytics/lapsed_users`, whose
 * fields the reset prune limits to `lastRunAt`.
 */
export const THRESHOLD_CURSOR_DOC = "_internal/lapsed_users_cursor";

/** Users per page, before the tie group at the page's last `lastActiveAt` joins it. */
const PAGE_SIZE = 100;

/**
 * BUT-1671: wall clock one run pages for, split evenly across the thresholds
 * (an earlier threshold that drains early leaves its time to the next). A
 * threshold stops between pages once its share is spent and the next run
 * continues from its cursor, so a backlog drains over several days instead of
 * growing one unbounded read. Must stay below this task's budget in the daily
 * chain, which is asserted in `maintenance-dispatchers.test.ts`.
 */
export const LAPSED_RUN_BUDGET_MS = 20_000;

const THRESHOLDS: LapsedThreshold[] = [
  { days: 7, type: "win_back_mild" },
  { days: 14, type: "win_back_moderate" },
  { days: 30, type: "win_back_strong" },
];

/** Test seams. Production passes nothing; tests inject everything. */
export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
  /** Override variant resolution (e.g. force a specific variant in tests). */
  resolveVariant?: (uid: string, thresholdType: string) => string;
  /** Override RC copy fetch (e.g. simulate RC failure). */
  fetchCopy?: (
    thresholdType: string,
    variant: string,
  ) => Promise<{ title: string; body: string }>;
  /** Override contextual-copy resolution (BUT-934). */
  resolveContext?: (
    userId: string,
    userData: admin.firestore.DocumentData,
  ) => Promise<ContextualCopy | null>;
  /** Override the preference-aware push (test the orchestration in isolation). */
  sendPush?: typeof sendPushToUserRespectingPreferences;
  /** Override the gate decision (test paths that proceed/drop without RC). */
  gate?: typeof evaluateSendGate;
  /** Override send-event recording. */
  recordEvent?: typeof recordNotificationSendEvent;
  /** Paging budget and its clock, so the deferral branch is testable. */
  runBudgetMs?: number;
  clock?: () => number;
  pageSize?: number;
}

export interface RunResult {
  totalDetected: number;
  pushSuccess: number;
  pushSkippedOptOut: number;
  pushSkippedQuietHours: number;
}

/**
 * Test-seam entrypoint, and the production entrypoint: the `dailyAnalytics`
 * dispatcher calls it with no overrides. Mirrors the shape of
 * `runTrackRetention` in `track-retention.ts`.
 */
export async function runDetectLapsedUsers(
  deps: RunDeps = {},
): Promise<RunResult> {
  const db = deps.db ?? getDb();
  const now =
    deps.now != null
      ? admin.firestore.Timestamp.fromDate(deps.now)
      : admin.firestore.Timestamp.now();
  const nowMs = now.toMillis();
  const resolveVariant = deps.resolveVariant ?? resolveWinbackVariant;
  const fetchCopy = deps.fetchCopy ?? fetchWinbackCopy;
  const resolveContext =
    deps.resolveContext ??
    ((userId: string, userData: admin.firestore.DocumentData) =>
      resolveContextualWinbackCopy(userId, userData, {
        db,
        now: nowMs,
      }));
  const sendPush =
    deps.sendPush ?? sendPushToUserRespectingPreferences;
  const gate = deps.gate ?? evaluateSendGate;
  const recordEvent = deps.recordEvent ?? recordNotificationSendEvent;

  logger.info("detect_lapsed_users_start");
  const runBudgetMs = deps.runBudgetMs ?? LAPSED_RUN_BUDGET_MS;
  const clock = deps.clock ?? Date.now;
  const pageSize = deps.pageSize ?? PAGE_SIZE;
  const startedAt = clock();
  const pageDeps = {
    db,
    now,
    resolveVariant,
    fetchCopy,
    resolveContext,
    sendPush,
    gate,
    recordEvent,
  };

  // BUT-1567: read the last-run cursor. The old predicate matched a fixed
  // ±12h band centred on each threshold, so a run that was skipped (outage,
  // schedule drift) left a permanent gap — any user whose lastActiveAt fell
  // in that day's band was never detected. We instead detect users who
  // CROSSED a threshold since the previous run, covering the whole gap and
  // catching irregular users the point-in-time band missed. First run (no
  // cursor) falls back to a bounded one-interval lookback.
  const cursorRef = db.collection(CURSOR_DOC.collection).doc(CURSOR_DOC.doc);
  const thresholdCursorRef = db.doc(THRESHOLD_CURSOR_DOC);
  const [cursorSnap, thresholdCursorSnap] = await Promise.all([
    cursorRef.get(),
    thresholdCursorRef.get(),
  ]);
  const storedCursor = cursorSnap.exists
    ? (cursorSnap.data()?.lastRunAt as admin.firestore.Timestamp | undefined)
    : undefined;
  const lastRunMs = storedCursor?.toMillis() ?? nowMs - DEFAULT_CURSOR_LOOKBACK_MS;
  const thresholdCursors = (thresholdCursorSnap.exists
    ? thresholdCursorSnap.data()
    : undefined) ?? {};

  let totalDetected = 0;
  let totalPushSuccess = 0;
  let totalPushSkippedOptOut = 0;
  let totalPushSkippedQuietHours = 0;
  let allDrained = true;

  for (const [index, threshold] of THRESHOLDS.entries()) {
    // A user has crossed the N-day inactivity threshold once their last
    // activity is older than N days: lastActiveAt <= now - N*days. To catch
    // every crosser exactly once — including those from a skipped run — pick
    // only users who were NOT yet past the threshold at the previous run:
    // window = (lastRun - N*days, now - N*days]. The upper bound is inclusive
    // (just-crossed) and the lower bound exclusive (already handled last run,
    // so no double-notify). BUT-1671: the lower bound is this threshold's own
    // cursor when one is stored, which is where its previous page ended.
    const crossedByNow = admin.firestore.Timestamp.fromMillis(
      nowMs - threshold.days * MS_PER_DAY,
    );
    // The stored Timestamp is used as read, never rebuilt from millis: the
    // bound is exclusive, and dropping its sub-millisecond part would let the
    // users at exactly that instant through a second time.
    const storedBound = thresholdCursors[threshold.type] as
      | admin.firestore.Timestamp
      | undefined;
    let lowerBound =
      typeof storedBound?.toMillis === "function"
        ? storedBound
        : admin.firestore.Timestamp.fromMillis(
            lastRunMs - threshold.days * MS_PER_DAY,
          );
    const thresholdDeadline =
      startedAt + (runBudgetMs * (index + 1)) / THRESHOLDS.length;
    const setCursor =
      (bound: admin.firestore.Timestamp) =>
      (batch: admin.firestore.WriteBatch): void => {
        batch.set(thresholdCursorRef, { [threshold.type]: bound }, { merge: true });
      };

    // Degenerate window (cursor at/after now — clock moved backwards, or a
    // duplicate same-instant run) → nothing newly crossed; skip.
    if (lowerBound.toMillis() >= crossedByNow.toMillis()) {
      logger.info("lapsed_window_empty", { days: threshold.days });
      continue;
    }

    const totals: PageResult[] = [];
    let drained = false;
    for (let pages = 0; ; pages++) {
      if (pages > 0 && clock() >= thresholdDeadline) break;
      const page = await db
        .collection("users")
        .where("lastActiveAt", ">", lowerBound)
        .where("lastActiveAt", "<=", crossedByNow)
        .orderBy("lastActiveAt")
        .limit(pageSize)
        .get();
      let docs = page.docs;
      let pageBound = crossedByNow;
      if (docs.length === pageSize) {
        // Everyone sharing the page's last timestamp joins this page, so the
        // next page can start strictly after it without a uid tie-breaker.
        pageBound = docs[docs.length - 1].data()
          .lastActiveAt as admin.firestore.Timestamp;
        const ties = await db
          .collection("users")
          .where("lastActiveAt", "==", pageBound)
          .get();
        const seen = new Set(docs.map((d) => d.id));
        docs = [...docs, ...ties.docs.filter((d) => !seen.has(d.id))];
      } else {
        drained = true;
      }

      if (docs.length === 0) {
        const batch = db.batch();
        setCursor(pageBound)(batch);
        await batch.commit();
      } else {
        totals.push(
          await processLapsedPage(pageDeps, threshold, docs, setCursor(pageBound)),
        );
      }
      lowerBound = pageBound;
      if (drained) break;
    }
    if (!drained) allDrained = false;

    const detected = sum(totals, (t) => t.detected);
    const pushSuccessCount = sum(totals, (t) => t.pushSuccess);
    const pushSkippedOptOut = sum(totals, (t) => t.pushSkippedOptOut);
    const pushSkippedQuietHours = sum(totals, (t) => t.pushSkippedQuietHours);
    totalDetected += detected;
    totalPushSuccess += pushSuccessCount;
    totalPushSkippedOptOut += pushSkippedOptOut;
    totalPushSkippedQuietHours += pushSkippedQuietHours;

    if (detected === 0) {
      logger.info("no_users_lapsed", { days: threshold.days, drained });
      continue;
    }
    logger.info("lapsed_threshold_processed", {
      days: threshold.days,
      thresholdType: threshold.type,
      detected,
      drained,
      pushDelivered: pushSuccessCount,
      pushOptedOut: pushSkippedOptOut,
      pushQuietHours: pushSkippedQuietHours,
      // Variant distribution for sanity checks. With a uniform hash and
      // 2 variants, expect ~50/50.
      variantBreakdown: mergeCounts(totals.map((t) => t.variantBreakdown)),
      // BUT-934: how many sends used each contextual signal vs generic.
      contextBreakdown: mergeCounts(totals.map((t) => t.contextBreakdown)),
    });
  }

  // BUT-1567: advance the cursor only after every threshold has drained its
  // window. If a threshold threw, or stopped on its budget, the cursor stays
  // put; the thresholds' own cursors (BUT-1671) are what keep a re-run from
  // re-covering the pages already done.
  if (allDrained) {
    await cursorRef.set({ lastRunAt: now }, { merge: true });
  }

  logger.info("detect_lapsed_users_complete", {
    totalDetected,
    allDrained,
    pushSuccess: totalPushSuccess,
    pushSkippedOptOut: totalPushSkippedOptOut,
    pushSkippedQuietHours: totalPushSkippedQuietHours,
  });

  return {
    totalDetected,
    pushSuccess: totalPushSuccess,
    pushSkippedOptOut: totalPushSkippedOptOut,
    pushSkippedQuietHours: totalPushSkippedQuietHours,
  };
}

function sum<T>(items: T[], pick: (item: T) => number): number {
  return items.reduce((acc, item) => acc + pick(item), 0);
}

function mergeCounts(
  counts: Record<string, number>[],
): Record<string, number> {
  const out: Record<string, number> = {};
  for (const c of counts) {
    for (const [key, n] of Object.entries(c)) out[key] = (out[key] ?? 0) + n;
  }
  return out;
}
