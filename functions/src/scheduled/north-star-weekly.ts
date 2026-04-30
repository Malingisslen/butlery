/**
 * North Star weekly aggregation (BUT-638).
 *
 * Runs Mondays at 06:00 UTC. Computes the week's product North Star
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

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { logAnalyticsEvent } from "../shared/analytics-server";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

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

interface ActivityEventLite {
  userId: string;
  eventType: string;
  timestampMs: number;
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
 * Fetches activity events for the [from, to) window and normalizes to
 * the lite shape. Accepts both schema variants.
 */
async function fetchEvents(
  db: admin.firestore.Firestore,
  from: Date,
  to: Date
): Promise<ActivityEventLite[]> {
  const fromTs = admin.firestore.Timestamp.fromDate(from);
  const toTs = admin.firestore.Timestamp.fromDate(to);
  // We don't constrain by `eventType` here — wau needs every event. We
  // filter cook-only at aggregation time.
  const snap = await db
    .collection("activity_events")
    .where("createdAt", ">=", fromTs)
    .where("createdAt", "<", toTs)
    .get();

  const out: ActivityEventLite[] = [];
  for (const doc of snap.docs) {
    const d = doc.data();
    const userId = (d.userId as string | undefined) ?? (d.actorId as string | undefined);
    const eventType =
      (d.eventType as string | undefined) ?? (d.type as string | undefined) ?? "";
    const ts = d.createdAt as admin.firestore.Timestamp | undefined;
    if (!userId || !ts) continue;
    out.push({ userId, eventType, timestampMs: ts.toMillis() });
  }
  return out;
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

  // Fetch all four weeks in parallel.
  const [w0, w1, w2, w3] = await Promise.all([
    fetchEvents(db, w0Start, w0End),
    fetchEvents(db, w1Start, w0Start),
    fetchEvents(db, w2Start, w1Start),
    fetchEvents(db, w3Start, w2Start),
  ]);

  const usersW0 = new Set(w0.map((e) => e.userId));
  const usersW1 = new Set(w1.map((e) => e.userId));
  const usersW2 = new Set(w2.map((e) => e.userId));
  const usersW3 = new Set(w3.map((e) => e.userId));

  const wau = usersW0.size;
  const totalCooks = w0.filter(
    (e) => e.eventType === "recipe_cooked" || e.eventType === "cooked"
  ).length;
  const cooksPerActiveUser = wau === 0 ? 0 : totalCooks / wau;

  const retentionW1 = retentionFraction(usersW0, usersW1);
  const retentionW2 = retentionFraction(usersW0, usersW2);
  const retentionW3 = retentionFraction(usersW0, usersW3);

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

export const northStarWeekly = onSchedule(
  { schedule: "0 6 * * 1", timeZone: "UTC" },
  async () => {
    await runNorthStarWeekly();
  }
);
