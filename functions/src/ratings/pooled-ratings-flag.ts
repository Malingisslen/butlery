/**
 * Server-side kill switch for pooled ratings ("Butlery-betyget"), decision 11.
 *
 * Reads the Remote Config flag `enable_pooled_ratings` (same key the Flutter
 * client reads via FeatureFlagService — one source of truth, no Firestore
 * mirror). Module-scope cache, 5-minute TTL; each Cloud Function isolate keeps
 * its own cache and cold starts invalidate. Same shape as
 * `shared/notification-rc-flags.ts` and `prompts-config.ts`.
 *
 * **Fail-CLOSED contract** (the opposite of the notification flags): if Remote
 * Config can't be fetched, or the flag is missing, pooled ratings are treated
 * as DISABLED. A missed read on the notification side costs a few extra pushes;
 * a missed read here would silently START writing pool events before we intend
 * the feature to be live. A kill switch you can't read must default to off.
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
    logger.warn("pooled_ratings flag fetch failed; failing closed (disabled)", {
      err,
    });
    cache = { enabled: false, fetchedAt: now() };
    return false;
  }
}
