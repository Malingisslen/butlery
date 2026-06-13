/**
 * BUT-626: Deterministic A/B prompt-experiment bucket assignment.
 *
 * Why: measuring prompt-quality deltas (parse success rate, cost, user
 * corrections) requires assigning each user to a stable bucket so that
 * analytics can compare per-bucket outcomes. `PROMPT_VERSION` already
 * flows through every analytics event; this module adds `experimentBucket`
 * alongside it.
 *
 * Bucket assignment:
 *   SHA-256(`${userId}:prompt_experiment`) mod bucketCount
 *
 * The `:prompt_experiment` salt keeps this bucket independent of the
 * winback-variant bucket (which uses `:thresholdType`), so the same user
 * can land in different buckets for different experiments. Same userId +
 * same bucketCount → same bucket on every call (no state, no Firestore).
 *
 * Variant selection:
 *   The `system/prompts` Firestore doc may optionally carry a
 *   `promptVariants` field (string[]). If present and non-empty, the user's
 *   bucket index maps to `promptVariants[bucket % variants.length]`.
 *   If absent/invalid, `variant` is undefined and the caller falls back to
 *   the existing single-version behavior (safe to ship before any experiment
 *   is configured).
 *
 * Cost: SHA-256 is ~1–5 µs on Node 22. Zero Firestore reads — the
 * `promptVariants` array is read from the already-cached `system/prompts`
 * doc. Cold-start neutral.
 */

import { createHash } from "crypto";

// Salt separates prompt-experiment bucket from other per-user SHA-256 hashes
// in this codebase (winback uses `uid:thresholdType`).
const BUCKET_SALT = "prompt_experiment";

/**
 * Assign a stable bucket index for a given userId.
 *
 * Same userId + same bucketCount → same bucket on every call.
 * Distribution across many distinct ids is statistically uniform
 * (verified: ±<5% across 10k ids for bucketCount=2).
 *
 * @param userId  A STABLE per-user key. Callers in this codebase pass
 *   `authUidHash` (the SHA-256 hash of the Auth UID), NOT the raw UID — so the
 *   key never contains PII. Whatever you pass, pass the SAME key everywhere for
 *   a given user, or that user will land in different buckets across call sites.
 * @param bucketCount  Number of buckets (default 2 for A/B). Must be ≥ 1.
 * @returns bucket index in [0, bucketCount).
 */
export function assignPromptBucket(
  userId: string,
  bucketCount: number = 2,
): number {
  if (bucketCount < 1 || !Number.isInteger(bucketCount)) {
    throw new Error(
      `assignPromptBucket: bucketCount must be a positive integer, got ${bucketCount}`,
    );
  }
  const hash = createHash("sha256")
    .update(`${userId}:${BUCKET_SALT}`)
    .digest();
  // Use first 6 bytes (48 bits) — uniform distribution far larger than any
  // plausible bucketCount, without needing bigint (safe up to 2^53).
  // Same approach as winback-variant.ts (knowledge file 2026-05-01).
  let n = 0;
  for (let i = 0; i < 6; i++) {
    n = n * 256 + hash[i];
  }
  return n % bucketCount;
}

/**
 * Result of resolving a user's prompt experiment bucket and variant.
 */
export interface PromptBucketResult {
  /**
   * Stable bucket index (0-based). Always present.
   * Suitable for logging and per-bucket analytics slicing.
   */
  bucket: number;
  /**
   * Named variant from `promptVariants`, e.g. "control" or "v2_extraction".
   * Undefined when no `promptVariants` config is present in the prompts doc
   * (= no active experiment; callers should fall back to current behavior).
   */
  variant: string | undefined;
}

/**
 * Resolve the bucket and variant for a user, given the optional
 * `promptVariants` list from the cached prompts config.
 *
 * Variant selection is all-or-nothing: if `promptVariants` is present but
 * malformed (not a non-empty string[] with ≥1 element), variant is
 * undefined. Mirrors the BUT-621 / BUT-688 partial-overlay rationale —
 * a broken config should never cause analytics to attribute a bucket to
 * a variant it didn't actually see.
 *
 * @param userId  Firebase Auth UID.
 * @param promptVariants  The `promptVariants` field from `system/prompts`,
 *   if the doc contains it. Pass undefined when the doc omits the field.
 */
export function resolvePromptBucket(
  userId: string,
  promptVariants: string[] | undefined,
): PromptBucketResult {
  const bucketCount =
    Array.isArray(promptVariants) && promptVariants.length > 0
      ? promptVariants.length
      : 2;

  const bucket = assignPromptBucket(userId, bucketCount);

  if (
    !Array.isArray(promptVariants) ||
    promptVariants.length === 0 ||
    promptVariants.some((v) => typeof v !== "string" || v.trim().length === 0)
  ) {
    // No active experiment configured — bucket is still assigned (for
    // pre-experiment baseline logging) but variant is undefined.
    return { bucket, variant: undefined };
  }

  return { bucket, variant: promptVariants[bucket] };
}
