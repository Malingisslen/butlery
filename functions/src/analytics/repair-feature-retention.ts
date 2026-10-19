/**
 * One-shot repair of the `cooked` and `shared` feature-retention flags for days
 * the nightly job wrote as false because their probes threw (`cooked` lacked
 * an ascending composite on `cook_snaps`; `shared` read `shared_recipes`, which
 * nothing writes, and lacked its index too).
 *
 * For each day in `[from, to]` it re-runs those two probes, with the nightly
 * job's own queries (`featureProbeQueries`), for every user who HAS a row that
 * day, and turns a stored false into true where the probe now finds activity.
 * It never writes false, and never creates a row: a user without a row that day
 * was not scanned that day, and an erased user's rows are gone on purpose
 * (BUT-1789).
 *
 * Every `daily/{date}` aggregate from `from` on (the rollup windows reach up to
 * 27 days past the last repaired day) gets the change in `dau`, `wau7d` and
 * `wau28d` for those two flags only, computed from the rows before and after
 * the repair. The other three flags and an erased user's contribution stay as
 * stored. Row and aggregate updates go in ONE batch, so a failed run leaves
 * nothing half-applied and a re-run finds nothing left to change.
 *
 * A probe that still throws aborts the run before anything is written, and
 * reports the error code and the index spec decoded from the error's
 * `create_composite` link; never the message itself, which names the query
 * and can carry a uid.
 *
 * `apply` is refused between 05:30 and 08:00 UTC: the nightly `dailyAnalytics`
 * chain rewrites the aggregates then, and an aggregate read before its write
 * and adjusted after it would lose one of the two.
 */

import * as admin from "firebase-admin";
import {
  featureProbeQueries,
  WAU_7D,
  WAU_28D,
} from "./compute-feature-retention";

const MS_PER_DAY = 24 * 60 * 60 * 1000;
/** UTC window around the 06:00 nightly run in which `apply` is refused. */
const NIGHTLY_GUARD_START_MIN = 5 * 60 + 30;
const NIGHTLY_GUARD_END_MIN = 8 * 60;
/** Firestore's per-batch write limit. */
const MAX_BATCH_WRITES = 500;

export type RepairedFlag = "cooked" | "shared";
const REPAIRED_FLAGS: readonly RepairedFlag[] = ["cooked", "shared"];

type FlagCounts = Record<RepairedFlag, number>;

export interface RepairOptions {
  db?: admin.firestore.Firestore;
  /** First UTC day to re-probe, `yyyy-mm-dd`. */
  from: string;
  /** Last UTC day to re-probe, `yyyy-mm-dd`; must be a finished day. */
  to: string;
  apply: boolean;
  now?: Date;
}

export interface RepairReport {
  apply: boolean;
  /** Per re-probed day: rows found and false→true flips per flag. */
  days: Array<{ date: string; rows: number; flips: FlagCounts }>;
  /** Per aggregate whose counts change. */
  aggregates: Array<{
    date: string;
    dau: FlagCounts;
    wau7d: FlagCounts;
    wau28d: FlagCounts;
  }>;
  rowWrites: number;
  aggregateWrites: number;
}

/** A probe that still fails: the run stops before writing anything. */
export class RepairProbeError extends Error {
  constructor(
    readonly flag: RepairedFlag,
    readonly date: string,
    readonly code: number | string | undefined,
    readonly indexSpec: string[],
  ) {
    super(`probe ${flag} failed on ${date} (code ${String(code)})`);
  }
}

/**
 * The `create_composite` token in a FAILED_PRECONDITION message is Firestore's
 * own index definition, base64url-encoded protobuf. Its readable strings are
 * the collection group path and the field names; nothing else is kept.
 */
export function decodeCreateCompositeSpec(message: string): string[] {
  const match = /create_composite=([A-Za-z0-9_-]+)/.exec(message);
  if (match == null) return [];
  const bytes = Buffer.from(match[1], "base64url").toString("latin1");
  const runs = bytes.match(/[A-Za-z0-9_.()/-]{3,}/g) ?? [];
  return runs.map((r) => {
    const at = r.indexOf("collectionGroups/");
    return at >= 0 ? r.slice(at) : r;
  });
}

function parseDay(day: string): number {
  if (!/^\d{4}-\d{2}-\d{2}$/.test(day)) {
    throw new Error(`not a yyyy-mm-dd day: ${day}`);
  }
  const ms = Date.parse(`${day}T00:00:00Z`);
  if (Number.isNaN(ms)) throw new Error(`not a yyyy-mm-dd day: ${day}`);
  return ms;
}

function formatDay(ms: number): string {
  return new Date(ms).toISOString().slice(0, 10);
}

function zero(): FlagCounts {
  return { cooked: 0, shared: 0 };
}

type DayRows = Map<string, Record<RepairedFlag, boolean>>;

async function readRowsForDay(
  db: admin.firestore.Firestore,
  day: string,
): Promise<DayRows> {
  const snap = await db
    .collection("analytics")
    .doc("feature_retention")
    .collection("users")
    .where("date", "==", day)
    .get();
  const rows: DayRows = new Map();
  for (const doc of snap.docs) {
    const data = doc.data();
    if (typeof data.userId !== "string") continue;
    rows.set(data.userId, {
      cooked: data.cooked === true,
      shared: data.shared === true,
    });
  }
  return rows;
}

function seenInWindow(
  rowsByDay: Map<string, DayRows>,
  userId: string,
  flag: RepairedFlag,
  endMs: number,
  days: number,
): boolean {
  for (let offset = 0; offset < days; offset++) {
    const row = rowsByDay.get(formatDay(endMs - offset * MS_PER_DAY))?.get(userId);
    if (row?.[flag] === true) return true;
  }
  return false;
}

export async function repairFeatureRetentionFlags(
  options: RepairOptions,
): Promise<RepairReport> {
  const db = options.db ?? admin.firestore();
  const fromMs = parseDay(options.from);
  const toMs = parseDay(options.to);
  const nowMs = (options.now ?? new Date()).getTime();
  const todayMs = parseDay(formatDay(nowMs));
  if (fromMs > toMs) throw new Error("from is after to");
  if (toMs >= todayMs) throw new Error("to must be a finished UTC day");
  const minuteOfDay = Math.floor((nowMs - todayMs) / 60000);
  if (
    options.apply &&
    minuteOfDay >= NIGHTLY_GUARD_START_MIN &&
    minuteOfDay < NIGHTLY_GUARD_END_MIN
  ) {
    throw new Error("apply is refused 05:30-08:00 UTC, around the nightly run");
  }

  // Aggregates from `from` on: each one's rollup windows may cover a repaired day.
  const aggregateSnap = await db
    .collection("analytics")
    .doc("feature_retention")
    .collection("daily")
    .where("date", ">=", options.from)
    .get();
  const aggregates = aggregateSnap.docs
    .map((doc) => ({ ref: doc.ref, data: doc.data() }))
    .filter((a) => typeof a.data.date === "string")
    .sort((a, b) => (a.data.date as string).localeCompare(b.data.date as string));
  const lastMs = Math.max(
    toMs,
    ...aggregates.map((a) => parseDay(a.data.date as string)),
  );

  const before = new Map<string, DayRows>();
  for (
    let ms = fromMs - (WAU_28D - 1) * MS_PER_DAY;
    ms <= lastMs;
    ms += MS_PER_DAY
  ) {
    before.set(formatDay(ms), await readRowsForDay(db, formatDay(ms)));
  }

  const after = new Map<string, DayRows>();
  for (const [day, rows] of before) {
    after.set(day, new Map([...rows].map(([uid, r]) => [uid, { ...r }])));
  }

  const report: RepairReport = {
    apply: options.apply,
    days: [],
    aggregates: [],
    rowWrites: 0,
    aggregateWrites: 0,
  };
  const rowUpdates: Array<{ userId: string; day: string; flags: RepairedFlag[] }> = [];

  for (let ms = fromMs; ms <= toMs; ms += MS_PER_DAY) {
    const day = formatDay(ms);
    const rows = after.get(day) ?? new Map();
    const flips = zero();
    const dayStart = admin.firestore.Timestamp.fromMillis(ms);
    const dayEnd = admin.firestore.Timestamp.fromMillis(ms + MS_PER_DAY);
    for (const [userId, row] of rows) {
      const missing = REPAIRED_FLAGS.filter((f) => !row[f]);
      if (missing.length === 0) continue;
      const queries = featureProbeQueries(db, userId, dayStart, dayEnd);
      const flipped: RepairedFlag[] = [];
      for (const flag of missing) {
        let size: number;
        try {
          size = (await queries[flag].get()).size;
        } catch (err) {
          const e = err as { code?: number | string; message?: string };
          throw new RepairProbeError(
            flag,
            day,
            e.code,
            decodeCreateCompositeSpec(String(e.message ?? "")),
          );
        }
        if (size > 0) {
          row[flag] = true;
          flips[flag]++;
          flipped.push(flag);
        }
      }
      if (flipped.length > 0) rowUpdates.push({ userId, day, flags: flipped });
    }
    report.days.push({ date: day, rows: rows.size, flips });
  }

  const aggregateUpdates: Array<{
    ref: FirebaseFirestore.DocumentReference;
    fields: Record<string, number>;
  }> = [];
  for (const aggregate of aggregates) {
    const day = aggregate.data.date as string;
    const dayMs = parseDay(day);
    const users = [...(after.get(day)?.keys() ?? [])];
    const dau = zero();
    const wau7d = zero();
    const wau28d = zero();
    for (const userId of users) {
      for (const flag of REPAIRED_FLAGS) {
        if (
          after.get(day)?.get(userId)?.[flag] === true &&
          before.get(day)?.get(userId)?.[flag] !== true
        ) {
          dau[flag]++;
        }
        if (
          seenInWindow(after, userId, flag, dayMs, WAU_7D) &&
          !seenInWindow(before, userId, flag, dayMs, WAU_7D)
        ) {
          wau7d[flag]++;
        }
        if (
          seenInWindow(after, userId, flag, dayMs, WAU_28D) &&
          !seenInWindow(before, userId, flag, dayMs, WAU_28D)
        ) {
          wau28d[flag]++;
        }
      }
    }
    const fields: Record<string, number> = {};
    const groups = { dau, wau7d, wau28d } as const;
    for (const [group, delta] of Object.entries(groups)) {
      const stored = (aggregate.data[group] ?? {}) as Record<string, unknown>;
      for (const flag of REPAIRED_FLAGS) {
        if (delta[flag] === 0) continue;
        const base = typeof stored[flag] === "number" ? (stored[flag] as number) : 0;
        fields[`${group}.${flag}`] = base + delta[flag];
      }
    }
    if (Object.keys(fields).length === 0) continue;
    report.aggregates.push({ date: day, dau, wau7d, wau28d });
    aggregateUpdates.push({ ref: aggregate.ref, fields });
  }

  const writes = rowUpdates.length + aggregateUpdates.length;
  if (writes > MAX_BATCH_WRITES) {
    throw new Error(
      `${writes} writes exceed one batch (${MAX_BATCH_WRITES}); narrow the range`,
    );
  }
  if (!options.apply || writes === 0) return report;

  const batch = db.batch();
  for (const update of rowUpdates) {
    const patch: Record<string, boolean> = {};
    for (const flag of update.flags) patch[flag] = true;
    // `update`, not `set`: a row erased since the read fails the batch rather
    // than coming back.
    batch.update(
      db
        .collection("analytics")
        .doc("feature_retention")
        .collection("users")
        .doc(`${update.userId}_${update.day}`),
      patch,
    );
  }
  const repairedAt = admin.firestore.Timestamp.fromMillis(nowMs);
  for (const update of aggregateUpdates) {
    batch.update(update.ref, { ...update.fields, repairedAt });
  }
  try {
    await batch.commit();
  } catch (err) {
    // The SDK's message names the failing document, whose id carries a uid.
    const code = (err as { code?: number | string }).code;
    throw new Error(
      `repair batch failed (code ${String(code)}); nothing was written, re-run`,
    );
  }
  report.rowWrites = rowUpdates.length;
  report.aggregateWrites = aggregateUpdates.length;
  return report;
}
