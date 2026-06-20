import { HttpsError } from "firebase-functions/v2/https";

/**
 * Clamp a client-supplied callable `limit` to a safe range.
 *
 * - Absent (`undefined`/`null`) → [fallback].
 * - Non-integer or non-positive → rejected with `invalid-argument` (a bad
 *   client shouldn't get silently coerced).
 * - Above [max] → capped, so an admin stats callable can never trigger an
 *   unbounded (and costly) Firestore read.
 */
export function clampLimit(
  raw: unknown,
  { fallback = 50, max = 500 }: { fallback?: number; max?: number } = {},
): number {
  if (raw === undefined || raw === null) return fallback;
  if (typeof raw !== "number" || !Number.isInteger(raw) || raw < 1) {
    throw new HttpsError(
      "invalid-argument",
      "`limit` must be a positive integer.",
    );
  }
  return Math.min(raw, max);
}
