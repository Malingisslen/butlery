/**
 * North Star weekly aggregation (BUT-638).
 *
 * Runs Mondays as the second task in the `weeklyReports` chain (08:00 UTC —
 * see `maintenance-dispatchers.ts`), after the user-facing activity digest;
 * it no longer owns a Cloud Scheduler job. Computes the week's North Star
 * metrics from `activity_events` and writes a single doc per ISO week.
 *
 * Metrics:
 *   - wau                  Distinct users with ≥1 event in past 7 days.
 *   - totalCooks           Events with type === "recipe_cooked" in past 7d.
 *   - cooksPerActiveUser   totalCooks / wau (0 when wau == 0).
 *   - retentionW1          % of past-week users who were also active in the
 *                          PREVIOUS week (8–14 days ago). Float 0..1.
 *   - retentionW2          ...two weeks back.
 *   - retentionW3          ...three weeks back.
 *
 * Output: `metrics/weekly_north_star/{isoWeek}` e.g. `2026-W18`.
 *
 * Idempotency: writes via `set()` (latest wins). Re-runs for the same
 * week overwrite. The `computedAt` field captures the run timestamp so
 * audit history can be reconstructed via Firestore export.
 *
 * **Spec note on schema**: spec uses `userId` and `eventType ==
 * "recipe_cooked"`. The current Firestore wire format (see
 * `lib/models/social/activity_event.dart`) actually uses `actorId` and
 * `type == "cooked"`. We accept BOTH shapes via `||` fallbacks so this
 * function works against the live data as well as any future refactor.
 * If the wire format changes, drop the fallback.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { logAnalyticsEvent } from "../shared/analytics-server";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

// Page size for streaming activity_events. The read is aggregated per page
// (distinct users + cook count) and pages are discarded, so peak memory is
// one page regardless of how many events fall in the window.
const EVENTS_PAGE_SIZE = 1000;

export interface NorthStarMetrics {
  wau: number;
  totalCooks: number;
  cooksPerActiveUser: number;
  retentionW1: number;
  retentionW2: number;
  retentionW3: number;
  computedAt: admin.firestore.Timestamp;
  weekStart: admin.firestore.Timestamp;
  weekEnd: admin.firestore.Timestamp;
  isoWeek: string;
}

/** Per-window aggregate: distinct active users and cook-event count. */
interface WindowAgg {
  users: Set<string>;
  cooks: number;
}

export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
}

/**
 * ISO 8601 week label `YYYY-Www` for a given Date. Mirrors
 * `lib/core/utils/iso_week_utils.dart`.
 */
export function isoWeekLabel(date: Date): string {
  // Convert to UTC date arithmetic to avoid local-TZ drift.
  const d = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
  // ISO weekday: Mon=1..Sun=7
  const dayNum = d.getUTCDay() || 7;
  // Roll to nearest Thursday (ISO: week 1 contains the year's first Thursday).
  d.setUTCDate(d.getUTCDate() + 4 - dayNum);
  const yearStart = new Date(Date.UTC(d.getUTCFullYear(), 0, 1));
  const weekNo = Math.ceil(((d.getTime() - yearStart.getTime()) / MS_PER_DAY + 1) / 7);
  return `${d.getUTCFullYear()}-W${String(weekNo).padStart(2, "0")}`;
}

/**
 * Aggregates activity events for the [from, to) window into distinct active
 * users and a cook-event count. Accepts both schema variants. Pages the read
 * with a createdAt cursor so the full window is never held in memory at once;
 * a `.select()` projection keeps each page's payload to the fields we use.
 *
 * `createdAt` is the range field, so ordering by it needs only the automatic
 * single-field index — no composite. It must stay in the projection because
 * the cursor reads its value from each page's last document.
 */
async function fetchWindowAgg(
  db: admin.firestore.Firestore,
  from: Date,
  to: Date
): Promise<WindowAgg> {
  const fromTs = admin.firestore.Timestamp.fromDate(from);
  const toTs = admin.firestore.Timestamp.fromDate(to);
  // We don't constrain by `eventType` here — wau needs every event. We
  // filter cook-only at aggregation time.
  const base = db
    .collection("activity_events")
    .where("createdAt", ">=", fromTs)
    .where("createdAt", "<", toTs)
    .select("userId", "actorId", "eventType", "type", "createdAt")
    .orderBy("createdAt");

  const users = new Set<string>();
  let cooks = 0;
  let lastDoc: admin.firestore.QueryDocumentSnapshot | undefined;

  for (;;) {
    let page = base.limit(EVENTS_PAGE_SIZE);
    if (lastDoc) {
      page = page.startAfter(lastDoc);
    }
    const snap = await page.get();
    if (snap.empty) break;

    for (const doc of snap.docs) {
      const d = doc.data();
      const userId =
        (d.userId as string | undefined) ?? (d.actorId as string | undefined);
      if (!userId) continue;
      users.add(userId);
      const eventType =
        (d.eventType as string | undefined) ??
        (d.type as string | undefined) ??
        "";
      if (eventType === "recipe_cooked" || eventType === "cooked") {
        cooks++;
      }
    }

    lastDoc = snap.docs[snap.docs.length - 1];
    if (snap.size < EVENTS_PAGE_SIZE) break;
  }

  return { users, cooks };
}

/**
 * Computes retention as fraction of `currentUsers` that also appear in
 * `priorUsers`. Returns 0 when `currentUsers` is empty (no division by
 * zero, and intuitively "no one to retain" ⇒ 0).
 */
function retentionFraction(
  currentUsers: Set<string>,
  priorUsers: Set<string>
): number {
  if (currentUsers.size === 0) return 0;
  let overlap = 0;
  for (const u of currentUsers) if (priorUsers.has(u)) overlap++;
  return overlap / currentUsers.size;
}

export async function runNorthStarWeekly(deps: RunDeps = {}): Promise<NorthStarMetrics> {
  const db = deps.db ?? admin.firestore();
  const now = deps.now ?? new Date();

  // Window: past 7 days ending at `now`. We aggregate over this window
  // for wau/cooks; retention compares against priors.
  const w0End = now;
  const w0Start = new Date(now.getTime() - 7 * MS_PER_DAY);
  const w1Start = new Date(now.getTime() - 14 * MS_PER_DAY);
  const w2Start = new Date(now.getTime() - 21 * MS_PER_DAY);
  const w3Start = new Date(now.getTime() - 28 * MS_PER_DAY);

  // Aggregate all four weeks in parallel. Each call streams its window and
  // returns only the distinct-user set + cook count, never the raw events.
  const [a0, a1, a2, a3] = await Promise.all([
    fetchWindowAgg(db, w0Start, w0End),
    fetchWindowAgg(db, w1Start, w0Start),
    fetchWindowAgg(db, w2Start, w1Start),
    fetchWindowAgg(db, w3Start, w2Start),
  ]);

  const wau = a0.users.size;
  const totalCooks = a0.cooks;
  const cooksPerActiveUser = wau === 0 ? 0 : totalCooks / wau;

  const retentionW1 = retentionFraction(a0.users, a1.users);
  const retentionW2 = retentionFraction(a0.users, a2.users);
  const retentionW3 = retentionFraction(a0.users, a3.users);

  const isoWeek = isoWeekLabel(w0End);

  const metrics: NorthStarMetrics = {
    wau,
    totalCooks,
    cooksPerActiveUser,
    retentionW1,
    retentionW2,
    retentionW3,
    computedAt: admin.firestore.Timestamp.fromDate(now),
    weekStart: admin.firestore.Timestamp.fromDate(w0Start),
    weekEnd: admin.firestore.Timestamp.fromDate(w0End),
    isoWeek,
  };

  // Idempotent write — overwrite-on-rerun.
  await db
    .collection("metrics")
    .doc("weekly_north_star")
    .collection("snapshots")
    .doc(isoWeek)
    .set(metrics);

  logAnalyticsEvent("north_star_snapshot", {
    isoWeek,
    wau,
    totalCooks,
    cooksPerActiveUser,
    retentionW1,
    retentionW2,
    retentionW3,
  });

  logger.info("north_star_weekly_complete", {
    isoWeek,
    wau,
    totalCooks,
    cooksPerActiveUser,
  });

  return metrics;
}
