/**
 * Server-side kill switch for pooled ratings ("Butlery-betyget"), decision 11.
 *
 * Reads the Remote Config flag `enable_pooled_ratings` (same key the Flutter
 * client reads via FeatureFlagService — one source of truth, no Firestore
 * mirror). Module-scope cache, 5-minute TTL; each Cloud Function isolate keeps
 * its own cache and cold starts invalidate. Same shape as
 * `shared/notification-rc-flags.ts` and `prompts-config.ts`.
 *
 * **Never-activate-on-error contract** (the opposite of the notification flags,
 * which fail OPEN): this distinguishes DETERMINATE from INDETERMINATE state.
 *   - RC readable, flag literal "true"  → returns true.
 *   - RC readable, flag absent/not-true → returns false (feature intentionally off).
 *   - RC UNREACHABLE (fetch error)      → THROWS. The state is unknown, so the
 *     caller (the retry-enabled mirror trigger) re-runs later instead of
 *     deciding. It NEVER returns true on an error, so a fetch failure can never
 *     wrongly activate the feature; and because it throws rather than returning
 *     a determinate-looking `false`, a rating submitted while the feature is
 *     LIVE during a brief RC blip is retried (and pools once RC recovers) rather
 *     than silently and permanently dropped. (A missed read on the notification
 *     side costs a few extra pushes; here it would either wrongly start writing
 *     pool data, or — if we fail-closed-to-false — lose real user votes.)
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

/** RC key — mirrors FeatureFlags.enablePooledRatings on the Flutter side. */
export const POOLED_RATINGS_FLAG = "enable_pooled_ratings";
export const RC_CACHE_TTL_MS = 5 * 60 * 1000;

interface FlagCache {
  enabled: boolean;
  fetchedAt: number;
}

let cache: FlagCache | null = null;

/** Test-only reset between cases. */
export function __resetPooledFlagCacheForTests(): void {
  cache = null;
}

export interface PooledFlagDeps {
  /** Test seam — production resolves the RC template. Returns the raw flag value. */
  loader?: () => Promise<boolean>;
  /** Test seam for now-time (ms). */
  now?: () => number;
  ttlMs?: number;
}

async function defaultLoader(): Promise<boolean> {
  const template = await admin.remoteConfig().getTemplate();
  const param = template.parameters?.[POOLED_RATINGS_FLAG] as
    | { defaultValue?: { value?: string } }
    | undefined;
  const raw = param?.defaultValue?.value;
  // Strict: only the literal string "true" enables. Missing/anything-else = off.
  // ROLLOUT CONSTRAINT: this reads only the parameter's defaultValue — it does
  // NOT evaluate RC conditions/percentage rollouts. The Flutter client
  // (fetchAndActivate) DOES evaluate conditions, so a conditional rollout would
  // let the client show the feature while the server no-ops every write. Roll
  // this flag as a plain on/off defaultValue only; do not attach RC conditions.
  return typeof raw === "string" && raw.toLowerCase() === "true";
}

/**
 * Whether pooled ratings are enabled. Defaults to `false` when the flag is
 * missing or RC is unreachable (fail-closed).
 */
export async function isPooledRatingsEnabled(
  deps: PooledFlagDeps = {}
): Promise<boolean> {
  const loader = deps.loader ?? defaultLoader;
  const now = deps.now ?? (() => Date.now());
  const ttl = deps.ttlMs ?? RC_CACHE_TTL_MS;

  if (cache && now() - cache.fetchedAt < ttl) {
    return cache.enabled;
  }

  try {
    const enabled = await loader();
    cache = { enabled, fetchedAt: now() };
    return enabled;
  } catch (err) {
    // INDETERMINATE — do NOT cache and do NOT return a determinate-looking
    // false. Throw so the retry-enabled trigger re-runs: this never wrongly
    // activates (we never return true on error) AND never drops a live vote to
    // a momentary RC blip (a fail-closed false would look "off" and skip with
    // no retry). See the module contract above.
    logger.warn("pooled_ratings flag fetch failed; throwing so caller retries", {
      err,
    });
    throw err;
  }
}
