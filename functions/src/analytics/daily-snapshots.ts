/**
 * Per-day snapshot aggregates for the admin dashboard's delta/anomaly
 * features on the NON-time-series tabs (Importhälsa, Recept, Parsing,
 * Drift, Feedback). Those tabs render a single "current" number; the
 * delta-arrow + anomaly engine needs a historical daily series to diff
 * against. These five scheduled jobs each write ONE doc per UTC day so a
 * series accumulates over time.
 *
 * Structurally mirrors `compute-feature-retention.ts`:
 *   - `onSchedule` (region pinned globally to europe-west1 via
 *     `setGlobalOptions` in index.ts — these functions inherit it, same as
 *     every sibling scheduled job; do NOT pin a per-function region here),
 *     `timeZone: "UTC"`.
 *   - A `runX(deps)` test-seam function + a thin `onSchedule` wrapper that
 *     calls it and re-throws on error (so a transient failure retries).
 *   - `logger.info` start/complete with structured fields, try/catch in the
 *     wrapper.
 *   - Deterministic doc id = the UTC date string → a same-day re-run
 *     OVERWRITES (idempotent via `set()`, never `create()`).
 *
 * Schedules are staggered 05:00–05:40 UTC so they do not collide with the
 * existing 04:00 (`track-retention`) / 04:30 (`compute-feature-retention`)
 * analytics jobs that scan large collections.
 *
 *   import_health        → 05:00 UTC → analytics/import_health/daily/{date}
 *   recipes              → 05:10 UTC → analytics/recipes/daily/{date}
 *   parsing_corrections  → 05:20 UTC → analytics/parsing_corrections/daily/{date}
 *   ops                  → 05:30 UTC → analytics/ops/daily/{date}
 *   feedback             → 05:40 UTC → analytics/feedback/daily/{date}
 *
 * The `analytics/**` tree is admin-read in firestore.rules and written
 * exclusively by the Admin SDK (these functions). No client ever writes here.
 *
 * **Read budget (per run, all five combined)**: each job is a single
 * one-day range scan (or one capped collection-group scan). At beta scale
 * (≤1 user, single-digit recipes/day) these are well under a few hundred
 * reads/day total ≈ effectively free. The only one that can grow is the
 * recipe snapshot (full collection-group scan of `recipes`), which is why
 * it is hard-capped at `RECIPE_SCAN_CAP` (5000) with a warn if hit — at
 * that point switch to an incremental `core.createdAt`-windowed query
 * instead of a full scan.
 */

import { onSchedule } from "firebase-functions/v2/scheduler";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

const MS_PER_DAY = 24 * 60 * 60 * 1000;

/** Hard cap on the full collection-group `recipes` scan (snapshot #2). */
const RECIPE_SCAN_CAP = 5000;

export interface RunDeps {
  db?: admin.firestore.Firestore;
  now?: Date;
}

const getDb = () => admin.firestore();

/** Format a UTC `yyyy-mm-dd` from a millisecond timestamp. */
export function formatUtcDate(ms: number): string {
  const d = new Date(ms);
  const yyyy = d.getUTCFullYear();
  const mm = String(d.getUTCMonth() + 1).padStart(2, "0");
  const dd = String(d.getUTCDate()).padStart(2, "0");
  return `${yyyy}-${mm}-${dd}`;
}

/** Start-of-day (UTC) for a millisecond timestamp. */
export function startOfUtcDay(ms: number): number {
  const d = new Date(ms);
  return Date.UTC(
    d.getUTCFullYear(),
    d.getUTCMonth(),
    d.getUTCDate(),
    0,
    0,
    0,
    0,
  );
}

/**
 * UTC day boundaries derived from the run time. `dateStr` is the
 * deterministic doc id; `dayStart`/`dayEnd` are the `[start, end)`
 * Timestamps for `>=` / `<` range queries.
 */
interface DayWindow {
  dateStr: string;
  startMs: number;
  endMs: number;
  dayStart: admin.firestore.Timestamp;
  dayEnd: admin.firestore.Timestamp;
  computedAt: admin.firestore.Timestamp;
}

function resolveDayWindow(deps: RunDeps): { db: admin.firestore.Firestore } & DayWindow {
  const db = deps.db ?? getDb();
  const nowMs = deps.now != null ? deps.now.getTime() : Date.now();
  const startMs = startOfUtcDay(nowMs);
  const endMs = startMs + MS_PER_DAY;
  return {
    db,
    dateStr: formatUtcDate(startMs),
    startMs,
    endMs,
    dayStart: admin.firestore.Timestamp.fromMillis(startMs),
    dayEnd: admin.firestore.Timestamp.fromMillis(endMs),
    computedAt: admin.firestore.Timestamp.fromMillis(nowMs),
  };
}

/** Increment `obj[key]` (creating it at 0 if absent). */
function bump(obj: Record<string, number>, key: string): void {
  obj[key] = (obj[key] ?? 0) + 1;
}

/** Reference to `analytics/{group}/daily/{date}` (4 segments = a doc). */
function dailyDocRef(
  db: admin.firestore.Firestore,
  group: string,
  dateStr: string,
): admin.firestore.DocumentReference {
  return db.collection("analytics").doc(group).collection("daily").doc(dateStr);
}

// ─────────────────────────────────────────────────────────────────────────
// 1. Import-health snapshot — analytics/import_health/daily/{date}
//    Reads `parse_events` for the day, aggregates per domain into
//    success / failure counts.
// ─────────────────────────────────────────────────────────────────────────

export interface ImportHealthSnapshot {
  date: string;
  byDomain: Record<string, { success: number; failure: number }>;
  totalSuccess: number;
  totalFailure: number;
  computedAt: admin.firestore.Timestamp;
}

export async function runImportHealthSnapshot(
  deps: RunDeps = {},
): Promise<ImportHealthSnapshot> {
  const { db, dateStr, dayStart, dayEnd, computedAt } = resolveDayWindow(deps);
  logger.info("import_health_snapshot_start", { date: dateStr });

  const snap = await db
    .collection("parse_events")
    .where("timestamp", ">=", dayStart)
    .where("timestamp", "<", dayEnd)
    .get();

  const byDomain: Record<string, { success: number; failure: number }> = {};
  let totalSuccess = 0;
  let totalFailure = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const domain =
      typeof data.domain === "string" && data.domain.length > 0
        ? data.domain
        : "unknown";
    const isSuccess = data.success === true;
    if (!byDomain[domain]) byDomain[domain] = { success: 0, failure: 0 };
    if (isSuccess) {
      byDomain[domain].success++;
      totalSuccess++;
    } else {
      byDomain[domain].failure++;
      totalFailure++;
    }
  }

  const result: ImportHealthSnapshot = {
    date: dateStr,
    byDomain,
    totalSuccess,
    totalFailure,
    computedAt,
  };
  await dailyDocRef(db, "import_health", dateStr).set(result);

  logger.info("import_health_snapshot_complete", {
    date: dateStr,
    events: snap.size,
    totalSuccess,
    totalFailure,
  });
  return result;
}

// ─────────────────────────────────────────────────────────────────────────
// 2. Recipe-method snapshot — analytics/recipes/daily/{date}
//    Collection-group scan of `recipes`, classified by
//    `core.sourceArtefact.type`. Captures the CURRENT total + per-method
//    breakdown (a stock level, not a per-day delta — the series lets the
//    dashboard diff day-over-day). Capped at RECIPE_SCAN_CAP.
// ─────────────────────────────────────────────────────────────────────────

export interface RecipeMethodSnapshot {
  date: string;
  total: number;
  byMethod: {
    url: number;
    photo: number;
    textPaste: number;
    social: number;
    manual: number;
  };
  computedAt: admin.firestore.Timestamp;
}

/** Map a stored `sourceArtefact.type` string to a dashboard method bucket. */
export function classifyRecipeMethod(
  artefactType: unknown,
): keyof RecipeMethodSnapshot["byMethod"] {
  switch (artefactType) {
    case "url":
      return "url";
    case "photoOcr":
      return "photo";
    case "textPaste":
      return "textPaste";
    case "youtubeTranscript":
    case "tiktokCaption":
    case "instagramCaption":
      return "social";
    default:
      // Missing / null / unknown → manually-created recipe.
      return "manual";
  }
}

export async function runRecipeMethodSnapshot(
  deps: RunDeps = {},
): Promise<RecipeMethodSnapshot> {
  const { db, dateStr, computedAt } = resolveDayWindow(deps);
  logger.info("recipe_method_snapshot_start", { date: dateStr });

  const snap = await db
    .collectionGroup("recipes")
    .limit(RECIPE_SCAN_CAP)
    .get();

  if (snap.size >= RECIPE_SCAN_CAP) {
    logger.warn("recipe_method_snapshot_cap_hit", {
      date: dateStr,
      cap: RECIPE_SCAN_CAP,
      // Counts are now a floor, not exact. Switch to an incremental
      // windowed query when this fires.
    });
  }

  const byMethod = {
    url: 0,
    photo: 0,
    textPaste: 0,
    social: 0,
    manual: 0,
  };
  let total = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const core = (data.core ?? {}) as Record<string, unknown>;
    const artefact = (core.sourceArtefact ?? {}) as Record<string, unknown>;
    byMethod[classifyRecipeMethod(artefact.type)]++;
    total++;
  }

  const result: RecipeMethodSnapshot = {
    date: dateStr,
    total,
    byMethod,
    computedAt,
  };
  await dailyDocRef(db, "recipes", dateStr).set(result);

  logger.info("recipe_method_snapshot_complete", {
    date: dateStr,
    total,
    byMethod,
  });
  return result;
}

// ─────────────────────────────────────────────────────────────────────────
// 3. Parsing-corrections snapshot — analytics/parsing_corrections/daily/{date}
//    Reads `parsing_corrections` for the day (has `timestamp` Timestamp +
//    `domain`), counts per domain.
// ─────────────────────────────────────────────────────────────────────────

export interface ParsingCorrectionsSnapshot {
  date: string;
  total: number;
  byDomain: Record<string, number>;
  computedAt: admin.firestore.Timestamp;
}

export async function runParsingCorrectionsSnapshot(
  deps: RunDeps = {},
): Promise<ParsingCorrectionsSnapshot> {
  const { db, dateStr, dayStart, dayEnd, computedAt } = resolveDayWindow(deps);
  logger.info("parsing_corrections_snapshot_start", { date: dateStr });

  const snap = await db
    .collection("parsing_corrections")
    .where("timestamp", ">=", dayStart)
    .where("timestamp", "<", dayEnd)
    .get();

  const byDomain: Record<string, number> = {};
  for (const doc of snap.docs) {
    const data = doc.data();
    const domain =
      typeof data.domain === "string" && data.domain.length > 0
        ? data.domain
        : "unknown";
    bump(byDomain, domain);
  }

  const result: ParsingCorrectionsSnapshot = {
    date: dateStr,
    total: snap.size,
    byDomain,
    computedAt,
  };
  await dailyDocRef(db, "parsing_corrections", dateStr).set(result);

  logger.info("parsing_corrections_snapshot_complete", {
    date: dateStr,
    total: snap.size,
  });
  return result;
}

// ─────────────────────────────────────────────────────────────────────────
// 4. Ops snapshot — analytics/ops/daily/{date}
//    Reads `system_events` for the day (has `executedAt` Timestamp, `type`,
//    and a removed-count field that is `totalDeleted` OR
//    `deletionAuditDeletedCount`). Counts events per type + sums deletions.
// ─────────────────────────────────────────────────────────────────────────

export interface OpsSnapshot {
  date: string;
  byType: Record<string, number>;
  totalEvents: number;
  totalDeleted: number;
  computedAt: admin.firestore.Timestamp;
}

export async function runOpsSnapshot(
  deps: RunDeps = {},
): Promise<OpsSnapshot> {
  const { db, dateStr, dayStart, dayEnd, computedAt } = resolveDayWindow(deps);
  logger.info("ops_snapshot_start", { date: dateStr });

  const snap = await db
    .collection("system_events")
    .where("executedAt", ">=", dayStart)
    .where("executedAt", "<", dayEnd)
    .get();

  const byType: Record<string, number> = {};
  let totalDeleted = 0;

  for (const doc of snap.docs) {
    const data = doc.data();
    const type =
      typeof data.type === "string" && data.type.length > 0
        ? data.type
        : "unknown";
    bump(byType, type);

    // Cleanup jobs report their removed-count under different field names;
    // take whichever is present (mirrors OpsEvent.fromFirestore on the
    // dashboard read side).
    const rawCount = data.totalDeleted ?? data.deletionAuditDeletedCount;
    if (typeof rawCount === "number" && Number.isFinite(rawCount)) {
      totalDeleted += rawCount;
    }
  }

  const result: OpsSnapshot = {
    date: dateStr,
    byType,
    totalEvents: snap.size,
    totalDeleted,
    computedAt,
  };
  await dailyDocRef(db, "ops", dateStr).set(result);

  logger.info("ops_snapshot_complete", {
    date: dateStr,
    totalEvents: snap.size,
    totalDeleted,
  });
  return result;
}

// ─────────────────────────────────────────────────────────────────────────
// 5. Feedback snapshot — analytics/feedback/daily/{date}
//    Reads `feedback` for the day. NOTE: `createdAt` is an ISO-8601 STRING,
//    not a Timestamp — range-compare as strings, which is correct because
//    ISO-8601 sorts lexicographically the same as chronologically.
// ─────────────────────────────────────────────────────────────────────────

export interface FeedbackSnapshot {
  date: string;
  total: number;
  byCategory: Record<string, number>;
  computedAt: admin.firestore.Timestamp;
}

export async function runFeedbackSnapshot(
  deps: RunDeps = {},
): Promise<FeedbackSnapshot> {
  const { db, dateStr, startMs, endMs, computedAt } = resolveDayWindow(deps);
  logger.info("feedback_snapshot_start", { date: dateStr });

  // `createdAt` is an ISO-8601 string. Build the boundary strings from the
  // same UTC day-window ms and range-compare lexicographically.
  const startIso = new Date(startMs).toISOString();
  const endIso = new Date(endMs).toISOString();

  const snap = await db
    .collection("feedback")
    .where("createdAt", ">=", startIso)
    .where("createdAt", "<", endIso)
    .get();

  const byCategory: Record<string, number> = {};
  for (const doc of snap.docs) {
    const data = doc.data();
    const category =
      typeof data.category === "string" && data.category.length > 0
        ? data.category
        : "unknown";
    bump(byCategory, category);
  }

  const result: FeedbackSnapshot = {
    date: dateStr,
    total: snap.size,
    byCategory,
    computedAt,
  };
  await dailyDocRef(db, "feedback", dateStr).set(result);

  logger.info("feedback_snapshot_complete", {
    date: dateStr,
    total: snap.size,
  });
  return result;
}

// ─────────────────────────────────────────────────────────────────────────
// Schedule wrappers — thin delegators, staggered 05:00–05:40 UTC. Each
// re-throws on error so a transient failure retries (the write is idempotent
// on the deterministic date-keyed doc, so a retry simply overwrites).
// ─────────────────────────────────────────────────────────────────────────

export const snapshotImportHealthDaily = onSchedule(
  { schedule: "0 5 * * *", timeZone: "UTC" },
  async () => {
    try {
      await runImportHealthSnapshot();
    } catch (err) {
      logger.error("import_health_snapshot_failed", { err });
      throw err;
    }
  },
);

export const snapshotRecipesDaily = onSchedule(
  { schedule: "10 5 * * *", timeZone: "UTC" },
  async () => {
    try {
      await runRecipeMethodSnapshot();
    } catch (err) {
      logger.error("recipe_method_snapshot_failed", { err });
      throw err;
    }
  },
);

export const snapshotParsingCorrectionsDaily = onSchedule(
  { schedule: "20 5 * * *", timeZone: "UTC" },
  async () => {
    try {
      await runParsingCorrectionsSnapshot();
    } catch (err) {
      logger.error("parsing_corrections_snapshot_failed", { err });
      throw err;
    }
  },
);

export const snapshotOpsDaily = onSchedule(
  { schedule: "30 5 * * *", timeZone: "UTC" },
  async () => {
    try {
      await runOpsSnapshot();
    } catch (err) {
      logger.error("ops_snapshot_failed", { err });
      throw err;
    }
  },
);

export const snapshotFeedbackDaily = onSchedule(
  { schedule: "40 5 * * *", timeZone: "UTC" },
  async () => {
    try {
      await runFeedbackSnapshot();
    } catch (err) {
      logger.error("feedback_snapshot_failed", { err });
      throw err;
    }
  },
);
