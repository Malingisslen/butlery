/**
 * Weekly import tier distribution (BUT-2243).
 *
 * Runs Mondays in the `weeklyReports` chain (`maintenance-dispatchers.ts`).
 * Reads `parse_events` for the last full ISO week and the week before it,
 * both inside that collection's 30-day TTL, so a missed run never leaves the
 * comparison without a baseline. Per channel it measures:
 *   - structuredShare: of the imports that produced a recipe, the share won
 *     by the page's own structured data (`SchemaOrg` or `SiteConfig`);
 *   - aiShare: the share that used AI;
 *   - failureShare: the share that failed;
 *   - meanCostUsd: mean estimated AI cost.
 *
 * It writes `analytics/import_tiers/weekly/{isoWeek}` with those aggregates
 * and the design goals beside them, and raises one `system_events` row plus
 * the `import_tier_distribution_shift` log line (a log-based alert policy in
 * `setup-gcp-alerts.sh`) when a share moves sharply or the mean cost passes
 * the design ceiling.
 *
 * It does NOT measure why a share moved: the CI import gate does that. And
 * `usedLlm` and `estimatedCostUsd` are client-supplied, so the cost here is a
 * trend signal; the server ledger (`llm_cost_ledger.ts`) is the real cost.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { isoWeekLabel } from "../scheduled/north-star-weekly";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** Rows read per week. A week above it is stored as truncated. */
export const WEEK_ROW_CAP = 20_000;

/** Both weeks need at least this many events in a channel before it is judged. */
export const MIN_EVENTS = 20;
/** A share must move at least this much (0..1) to alarm. */
export const MIN_SHARE_MOVE = 0.15;
/** ...and clear this two-proportion |z|, so a small week's noise stays quiet. */
export const MIN_ABS_Z = 3;
/** The design's ceiling: 5 öre, as US dollars. */
export const COST_ALARM_USD = 0.005;

/** Stored beside the measured values; the design document's targets. */
export const DESIGN_GOALS = {
  aiCallsPerImport: 0,
  costPerImportSek: 0.02,
};

const STRUCTURED_TIERS = ["SchemaOrg", "SiteConfig"];

/** A share's numerator and denominator; null fields are kept out of `n`. */
export interface Ratio {
  hits: number;
  n: number;
}

export interface ChannelStats {
  events: number;
  structured: Ratio;
  ai: Ratio;
  failure: Ratio;
  /** Events whose `estimatedCostUsd` is a number, and their total. */
  costN: number;
  costSumUsd: number;
}

export interface WeekStats {
  isoWeek: string;
  truncated: boolean;
  byChannel: Record<string, ChannelStats>;
}

export type ShareName = "structured" | "ai" | "failure";

export interface Shift {
  channel: string;
  kind: ShareName | "cost";
  previous: number | null;
  current: number;
  z: number | null;
}

export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
  /** Test seam for WEEK_ROW_CAP. */
  rowCap?: number;
}

/** Monday 00:00 UTC of the ISO week containing `date`. */
export function isoWeekStart(date: Date): Date {
  const d = new Date(
    Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate())
  );
  const dayNum = d.getUTCDay() || 7;
  return new Date(d.getTime() - (dayNum - 1) * MS_PER_DAY);
}

function emptyChannel(): ChannelStats {
  return {
    events: 0,
    structured: { hits: 0, n: 0 },
    ai: { hits: 0, n: 0 },
    failure: { hits: 0, n: 0 },
    costN: 0,
    costSumUsd: 0,
  };
}

/** Folds one event's fields into its channel's counts. */
export function addEvent(
  byChannel: Record<string, ChannelStats>,
  data: admin.firestore.DocumentData
): void {
  const channel =
    typeof data.channel === "string" && data.channel.length > 0
      ? data.channel
      : "unknown";
  const s = (byChannel[channel] ??= emptyChannel());
  s.events++;

  const outcome = typeof data.outcome === "string" ? data.outcome : null;
  if (outcome !== null) {
    s.failure.n++;
    if (outcome === "failure") s.failure.hits++;
  }
  if (outcome === "recipe") {
    s.structured.n++;
    if (STRUCTURED_TIERS.includes(data.successfulTier)) s.structured.hits++;
  }
  if (typeof data.usedLlm === "boolean") {
    s.ai.n++;
    if (data.usedLlm) s.ai.hits++;
  }
  if (typeof data.estimatedCostUsd === "number" && Number.isFinite(data.estimatedCostUsd)) {
    s.costN++;
    s.costSumUsd += data.estimatedCostUsd;
  }
}

async function readWeek(
  db: admin.firestore.Firestore,
  start: Date,
  cap: number
): Promise<WeekStats> {
  const end = new Date(start.getTime() + 7 * MS_PER_DAY);
  // `userId`, `url` and `domain` are never fetched: nothing here is per person
  // or per site.
  const snap = await db
    .collection("parse_events")
    .where("timestamp", ">=", admin.firestore.Timestamp.fromDate(start))
    .where("timestamp", "<", admin.firestore.Timestamp.fromDate(end))
    .select("channel", "outcome", "successfulTier", "usedLlm", "estimatedCostUsd", "timestamp")
    .limit(cap + 1)
    .get();

  const byChannel: Record<string, ChannelStats> = {};
  const docs = snap.docs.slice(0, cap);
  for (const doc of docs) addEvent(byChannel, doc.data());
  return {
    isoWeek: isoWeekLabel(start),
    truncated: snap.size > cap,
    byChannel,
  };
}

function share(r: Ratio): number | null {
  return r.n === 0 ? null : r.hits / r.n;
}

/** Two-proportion z statistic; null when the pooled share is 0 or 1. */
export function twoProportionZ(a: Ratio, b: Ratio): number | null {
  if (a.n === 0 || b.n === 0) return null;
  const pooled = (a.hits + b.hits) / (a.n + b.n);
  const se = Math.sqrt(pooled * (1 - pooled) * (1 / a.n + 1 / b.n));
  if (se === 0) return null;
  return (b.hits / b.n - a.hits / a.n) / se;
}

/**
 * The shifts worth an alarm between `previous` and `current`. A truncated
 * current week is not judged at all; a truncated previous week turns off the
 * share comparison only.
 */
export function findShifts(previous: WeekStats, current: WeekStats): Shift[] {
  if (current.truncated) return [];
  const shifts: Shift[] = [];
  for (const [channel, cur] of Object.entries(current.byChannel)) {
    const prev = previous.byChannel[channel];
    if (prev && !previous.truncated) {
      for (const kind of ["structured", "ai", "failure"] as const) {
        const a = prev[kind];
        const b = cur[kind];
        if (a.n < MIN_EVENTS || b.n < MIN_EVENTS) continue;
        const move = Math.abs((share(b) as number) - (share(a) as number));
        const z = twoProportionZ(a, b);
        if (move >= MIN_SHARE_MOVE && z !== null && Math.abs(z) >= MIN_ABS_Z) {
          shifts.push({
            channel,
            kind,
            previous: share(a),
            current: share(b) as number,
            z,
          });
        }
      }
    }
    if (cur.costN >= MIN_EVENTS) {
      const mean = cur.costSumUsd / cur.costN;
      if (mean > COST_ALARM_USD) {
        shifts.push({
          channel,
          kind: "cost",
          previous:
            prev && prev.costN > 0 ? prev.costSumUsd / prev.costN : null,
          current: mean,
          z: null,
        });
      }
    }
  }
  return shifts;
}

function summarise(week: WeekStats) {
  const byChannel: Record<string, unknown> = {};
  for (const [channel, s] of Object.entries(week.byChannel)) {
    byChannel[channel] = {
      events: s.events,
      structuredShare: share(s.structured),
      structuredN: s.structured.n,
      aiShare: share(s.ai),
      aiN: s.ai.n,
      failureShare: share(s.failure),
      failureN: s.failure.n,
      meanCostUsd: s.costN === 0 ? null : s.costSumUsd / s.costN,
      costN: s.costN,
    };
  }
  return { isoWeek: week.isoWeek, truncated: week.truncated, byChannel };
}

export async function runImportTierWeekly(
  deps: RunDeps = {}
): Promise<{ current: WeekStats; previous: WeekStats; shifts: Shift[] }> {
  const db = deps.db ?? admin.firestore();
  const now = deps.now ?? new Date();

  const currentStart = new Date(isoWeekStart(now).getTime() - 7 * MS_PER_DAY);
  const previousStart = new Date(currentStart.getTime() - 7 * MS_PER_DAY);
  const cap = deps.rowCap ?? WEEK_ROW_CAP;
  // One week at a time, so at most one week's snapshots are held at once.
  const current = await readWeek(db, currentStart, cap);
  const previous = await readWeek(db, previousStart, cap);
  const shifts = findShifts(previous, current);

  await db
    .collection("analytics")
    .doc("import_tiers")
    .collection("weekly")
    .doc(current.isoWeek)
    .set({
      ...summarise(current),
      previous: summarise(previous),
      designGoals: DESIGN_GOALS,
      shifts,
      computedAt: admin.firestore.Timestamp.fromDate(now),
    });

  if (shifts.length > 0) {
    const at = admin.firestore.Timestamp.fromDate(now);
    // A fixed id, so a rerun of the same week leaves one row.
    await db
      .collection("system_events")
      .doc(`import_tier_shift_${current.isoWeek}`)
      .set({
        type: "import_tier_shift",
        isoWeek: current.isoWeek,
        shifts,
        timestamp: at,
        executedAt: at,
      });
    logger.warn("import_tier_distribution_shift", {
      isoWeek: current.isoWeek,
      shifts,
    });
  }

  if (current.truncated || previous.truncated) {
    logger.warn("import_tier_weekly_truncated", {
      isoWeek: current.isoWeek,
      currentTruncated: current.truncated,
      previousTruncated: previous.truncated,
      cap,
    });
  }

  logger.info("import_tier_weekly_complete", {
    isoWeek: current.isoWeek,
    truncated: current.truncated,
    channels: Object.keys(current.byChannel).length,
    shifts: shifts.length,
  });

  return { current, previous, shifts };
}
