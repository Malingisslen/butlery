/**
 * BUT-688: Win-back push copy variants via Remote Config.
 *
 * Why: previously the win-back push copy was hardcoded in
 * `detect-lapsed-users.ts`. Operators couldn't A/B test phrasings or
 * roll back a regressed string without a Cloud Functions redeploy
 * (≈15 minutes). With this module, copy lives in Firebase Remote
 * Config under deterministic keys per (thresholdType, variant) and
 * each running CF instance picks up new values within the cache TTL.
 *
 * Bucket assignment is deterministic: `SHA-256(uid:thresholdType) mod
 * variants.length`. The same user lands in the same bucket every run,
 * which means open-rate analytics can attribute later opens to the
 * correct variant without any session-side state. Server cannot set
 * Firebase Analytics user properties, so the bridge to the FA dashboard
 * is the user-doc fields written by the caller (`lastWinBackVariant`,
 * `lastWinBackBucket`, `lastWinBackChannel`, `lastWinBackSentAt`),
 * which the client reads at session start and forwards to FA via
 * `ExperimentAssignment.setExperimentAssignment` (BUT-657).
 *
 * Resilience contract:
 *  - RC fetch failure / template missing param → return the compiled-in
 *    BASELINE_COPY (the same Swedish strings the function shipped with).
 *    This guarantees zero regression on RC outages.
 *  - The cache lives in module scope (per-instance). Cold starts
 *    naturally invalidate. TTL = 10 min — RC propagation latency is
 *    minutes, and this CF runs once a day, so most invocations are
 *    cold-start anyway. The TTL only matters if multiple thresholds
 *    in the same run share the cached template (they do — all 3
 *    thresholds run inside the same `runDetectLapsedUsers` call).
 */

import { createHash } from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";

/** Baseline Swedish copy. Mirrors what was previously hardcoded inline. */
export const BASELINE_COPY: Record<
  string,
  { title: string; body: string }
> = {
  win_back_mild: {
    title: "Butlery",
    body: "Vi saknar dig! Kolla in vad som är nytt",
  },
  win_back_moderate: {
    title: "Butlery",
    body: "Dina recept väntar på dig",
  },
  win_back_strong: {
    title: "Butlery",
    body: "Det var länge sedan! Kom tillbaka",
  },
};

/** Default variant set. Two for now; A1 spec calls for 2-3. */
export const DEFAULT_VARIANTS = ["baseline", "curiosity"] as const;

/** TTL for the per-instance Remote Config template cache. */
export const RC_CACHE_TTL_MS = 10 * 60 * 1000;

/**
 * Deterministic bucket assignment.
 *
 * SHA-256 of `${uid}:${thresholdType}` interpreted as a big-endian
 * uint, mod `variants.length`. Independent across thresholds — a user
 * may end up in `baseline` for mild and `curiosity` for moderate. That
 * keeps thresholds testable as separate experiments.
 *
 * Pure: no Firestore, no clock. Unit-testable.
 */
export function resolveWinbackVariant(
  uid: string,
  thresholdType: string,
  variants: readonly string[] = DEFAULT_VARIANTS,
): string {
  if (variants.length === 0) {
    throw new Error("resolveWinbackVariant: variants must be non-empty");
  }
  const hash = createHash("sha256")
    .update(`${uid}:${thresholdType}`)
    .digest();
  // Use the first 6 bytes (48 bits) to avoid bigint while still giving
  // a uniform distribution far larger than any plausible variants.length.
  let n = 0;
  for (let i = 0; i < 6; i++) {
    n = n * 256 + hash[i];
  }
  return variants[n % variants.length];
}

/** Test seam: returns the resolved RC parameter map, or null on failure. */
export type RcTemplateLoader = () => Promise<
  Record<string, string> | null
>;

export interface FetchWinbackCopyDeps {
  /** Test seam for RC template fetch. Production resolves to admin.remoteConfig(). */
  loader?: RcTemplateLoader;
  /** Clock seam for TTL math. */
  now?: () => number;
  /** Override TTL for tests. */
  ttlMs?: number;
}

interface CacheEntry {
  params: Record<string, string>;
  fetchedAt: number;
  /** True iff we successfully read from RC; false if we cached a null. */
  fromRemote: boolean;
}

let cache: CacheEntry | null = null;
let inflight: Promise<CacheEntry> | null = null;

/** Test-only: clear the module-scope cache between cases. */
export function __resetWinbackCacheForTests(): void {
  cache = null;
  inflight = null;
}

/**
 * Default loader: pulls the active Remote Config template via the
 * Admin SDK and projects it down to a `{paramKey: defaultValue}` map.
 *
 * Returns null on any error — the caller treats that as "use baseline".
 */
async function defaultRcLoader(): Promise<Record<string, string> | null> {
  try {
    const template = await admin.remoteConfig().getTemplate();
    const out: Record<string, string> = {};
    for (const [key, param] of Object.entries(template.parameters ?? {})) {
      const def = param.defaultValue;
      if (def && "value" in def && typeof def.value === "string") {
        out[key] = def.value;
      }
    }
    return out;
  } catch (err) {
    logger.warn("[winback-variant] Remote Config fetch failed", { err });
    return null;
  }
}

async function getCachedTemplate(
  deps: FetchWinbackCopyDeps,
): Promise<CacheEntry> {
  const now = deps.now ?? Date.now;
  const ttl = deps.ttlMs ?? RC_CACHE_TTL_MS;
  const loader = deps.loader ?? defaultRcLoader;

  if (cache && now() - cache.fetchedAt < ttl) {
    return cache;
  }

  if (inflight) {
    return inflight;
  }

  inflight = (async () => {
    const raw = await loader();
    const entry: CacheEntry =
      raw == null
        ? { params: {}, fetchedAt: now(), fromRemote: false }
        : { params: raw, fetchedAt: now(), fromRemote: true };
    cache = entry;
    return entry;
  })();

  try {
    return await inflight;
  } finally {
    inflight = null;
  }
}

/**
 * Resolve the (title, body) copy for a given (thresholdType, variant).
 *
 * Failure modes ALL return baseline:
 *  - RC fetch error
 *  - parameter missing
 *  - parameter present but empty
 *
 * RC parameter naming convention:
 *   winback_<thresholdType>_<variant>_title
 *   winback_<thresholdType>_<variant>_body
 */
export async function fetchWinbackCopy(
  thresholdType: string,
  variant: string,
  deps: FetchWinbackCopyDeps = {},
): Promise<{ title: string; body: string }> {
  const baseline = BASELINE_COPY[thresholdType] ?? BASELINE_COPY.win_back_mild;

  const entry = await getCachedTemplate(deps);
  if (!entry.fromRemote) {
    return baseline;
  }

  const titleKey = `winback_${thresholdType}_${variant}_title`;
  const bodyKey = `winback_${thresholdType}_${variant}_body`;
  const title = entry.params[titleKey];
  const body = entry.params[bodyKey];

  // Partial overlay would mismatch the variant attribution downstream
  // (title from RC, body from baseline → analytics says variant=curiosity
  // but copy is half-baseline). All-or-nothing, same rationale as the
  // BUT-621 prompts validator.
  if (
    typeof title !== "string" ||
    title.trim().length === 0 ||
    typeof body !== "string" ||
    body.trim().length === 0
  ) {
    logger.warn("[winback-variant] RC param missing/empty, using baseline", {
      thresholdType,
      variant,
      titleKey,
      bodyKey,
      titlePresent: typeof title === "string",
      bodyPresent: typeof body === "string",
    });
    return baseline;
  }

  return { title, body };
}
