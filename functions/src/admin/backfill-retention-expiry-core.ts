/**
 * What the retention backfill stamps, and on which rows. Kept free of any
 * Firestore connection so the decision is testable.
 *
 * Rows written before their writer started stamping `expireAt` have no field,
 * and Firestore TTL only reaps rows that have it, so without a backfill they
 * stay forever. Each row's window is anchored at its own creation time, which
 * means a row older than the window gets an `expireAt` in the past and is
 * deleted by TTL shortly after it is stamped. That is the number Malin sees
 * before `--apply`.
 */

import { CORRECTION_RETENTION_MS } from "../events/log-parse-correction";
import { FEEDBACK_RETENTION_MS } from "../feedback/on-feedback-created";

export interface RetentionTarget {
  collection: string;
  /** The field holding the row's creation time. */
  baseField: string;
  retentionMs: number;
}

// parsing_corrections and tag_overrides_log are written by the app, whose
// window is kCorrectionRetention in correction_retention.dart; it has the same
// value as the server's CORRECTION_RETENTION_MS.
export const RETENTION_TARGETS: readonly RetentionTarget[] = [
  { collection: "parsing_corrections", baseField: "timestamp", retentionMs: CORRECTION_RETENTION_MS },
  { collection: "tag_overrides_log", baseField: "timestamp", retentionMs: CORRECTION_RETENTION_MS },
  { collection: "parse_corrections_v2", baseField: "createdAt", retentionMs: CORRECTION_RETENTION_MS },
  { collection: "feedback", baseField: "createdAt", retentionMs: FEEDBACK_RETENTION_MS },
];

/**
 * Milliseconds of a stored creation time, or null when it cannot be read.
 * feedback stores `createdAt` as an ISO string; the others store a Timestamp.
 */
export function readBaseMillis(value: unknown): number | null {
  if (value && typeof (value as { toMillis?: unknown }).toMillis === "function") {
    const ms = (value as { toMillis: () => number }).toMillis();
    return Number.isFinite(ms) ? ms : null;
  }
  if (value instanceof Date) {
    const ms = value.getTime();
    return Number.isFinite(ms) ? ms : null;
  }
  if (typeof value === "string") {
    const ms = Date.parse(value);
    return Number.isFinite(ms) ? ms : null;
  }
  return null;
}

export type StampPlan =
  | { stamp: false }
  | {
      stamp: true;
      expireAtMs: number;
      /** TTL deletes the row soon after the stamp lands. */
      alreadyExpired: boolean;
      /** No readable creation time: the window starts now instead. */
      usedFallback: boolean;
    };

/**
 * A row that already has `expireAt` is left alone, so a re-run changes
 * nothing. A row without a readable creation time gets a full window from now
 * rather than none: it is never deleted on the strength of a guessed age.
 */
export function planStamp(
  data: Record<string, unknown>,
  target: RetentionTarget,
  nowMs: number,
): StampPlan {
  if (data.expireAt !== undefined && data.expireAt !== null) return { stamp: false };
  const base = readBaseMillis(data[target.baseField]);
  const usedFallback = base === null;
  const expireAtMs = (base ?? nowMs) + target.retentionMs;
  return { stamp: true, expireAtMs, alreadyExpired: expireAtMs <= nowMs, usedFallback };
}
