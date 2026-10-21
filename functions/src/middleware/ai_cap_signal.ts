/**
 * A log line when an AI cap is nearly used up or used up, so the morning koll
 * can tell Malin which cap to raise (tasks/ai-cap-signal-plan.md).
 *
 * The callers already hold the counter they just incremented inside a
 * transaction, so a crossing is an exact equality on that new count, without
 * any read or write of its own. Callers emit
 * after the transaction resolves, because a transaction callback can run more
 * than once.
 *
 * `tools/ai_cap_report.py` reads these lines by their message and fields, so
 * renaming either silently empties the report.
 */

import { logger } from "firebase-functions/logger";

export const AI_CAP_SIGNAL = "ai_cap_signal";

export const NEAR_FRACTION = 0.8;

export type AiCap = "global_hour" | "global_day" | "guest_day" | "user_day";

export type CapLevel = "near" | "reached";

export interface CapSignal {
  cap: AiCap;
  level: CapLevel;
  count: number;
  limit: number;
  operationType?: string;
  /** Only `user_day` carries it, to count distinct users. Never a raw uid. */
  userIdHash?: string;
}

/** Below 5 the near point rounds onto the limit itself, so only "reached" fires. */
export function capCrossing(newCount: number, limit: number): CapLevel | null {
  if (!(limit > 0)) return null;
  // A fractional limit admits up to its ceiling, so that is the last slot.
  if (newCount === Math.ceil(limit)) return "reached";
  return newCount === Math.ceil(limit * NEAR_FRACTION) ? "near" : null;
}

let sinkForTest: ((signal: CapSignal) => void) | null = null;

/** Test seam: capture signals instead of logging them. Pass null to restore. */
export function __setCapSignalSinkForTest(
  sink: ((signal: CapSignal) => void) | null
): void {
  sinkForTest = sink;
}

/** Logs a signal when `count` is a crossing of `limit`; otherwise does nothing. */
export function signalIfCrossed(
  signal: Omit<CapSignal, "level">
): void {
  const level = capCrossing(signal.count, signal.limit);
  if (!level) return;
  const full: CapSignal = { ...signal, level };
  if (sinkForTest) {
    sinkForTest(full);
    return;
  }
  logger.warn(AI_CAP_SIGNAL, full);
}
