/**
 * Remote Config flag reader for per-type notification suppression (BUT-645).
 *
 * Flag namespace: `notifications.enabled.<type>`. Default is `true`. A
 * flag set to `false` causes every sender to skip that notification type
 * with a `notification_type_disabled` analytics event. Auto-suppression
 * (`suppressLowPerformers`) flips flags to `false` when CTR drops below
 * threshold.
 *
 * **Fail-open contract**: if Remote Config can't be fetched (network
 * blip, IAM hiccup, template version skew), every type is treated as
 * ENABLED. The cost of a flaky failure is a few extra pushes; the cost
 * of failing-closed is silently muting all notifications during an RC
 * outage. Pushes are the wrong side to err on closed.
 *
 * Cache: module-scope, 5-minute TTL. Each Cloud Function isolate gets
 * its own cache; cold starts naturally invalidate. Same pattern as
 * `prompts-config.ts` (BUT-621).
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

export const RC_CACHE_TTL_MS = 5 * 60 * 1000;
export const RC_FLAG_PREFIX = "notifications.enabled.";

interface FlagsCache {
  flags: Record<string, boolean>;
  fetchedAt: number;
  /** Whether the fetch succeeded (true) or failed and we're using fail-open defaults (false). */
  source: "remote-config" | "fail-open";
}

let cache: FlagsCache | null = null;

/** Test-only reset between cases. */
export function __resetRcFlagsCacheForTests(): void {
  cache = null;
}

export interface RcFlagsDeps {
  /** Test seam — production resolves to admin.remoteConfig().getTemplate(). */
  loader?: () => Promise<Record<string, unknown>>;
  /** Test seam for now-time. */
  now?: () => number;
  ttlMs?: number;
}

async function defaultLoader(): Promise<Record<string, unknown>> {
  const template = await admin.remoteConfig().getTemplate();
  const out: Record<string, unknown> = {};
  for (const [key, param] of Object.entries(template.parameters ?? {})) {
    const def = (param as { defaultValue?: { value?: string } }).defaultValue;
    if (def?.value !== undefined) {
      out[key] = def.value;
    }
  }
  return out;
}

function parseBoolish(v: unknown): boolean {
  if (typeof v === "boolean") return v;
  if (typeof v === "string") return v.toLowerCase() !== "false";
  return true;
}

/**
 * Returns a flags map keyed by `<type>` (the prefix stripped).
 * Missing flags are NOT in the map; `isNotificationTypeEnabled` defaults
 * those to `true`.
 */
async function getFlags(deps: RcFlagsDeps = {}): Promise<FlagsCache> {
  const loader = deps.loader ?? defaultLoader;
  const now = deps.now ?? (() => Date.now());
  const ttl = deps.ttlMs ?? RC_CACHE_TTL_MS;

  if (cache && now() - cache.fetchedAt < ttl) {
    return cache;
  }

  try {
    const raw = await loader();
    const flags: Record<string, boolean> = {};
    for (const [key, value] of Object.entries(raw)) {
      if (!key.startsWith(RC_FLAG_PREFIX)) continue;
      const typeName = key.slice(RC_FLAG_PREFIX.length);
      flags[typeName] = parseBoolish(value);
    }
    cache = { flags, fetchedAt: now(), source: "remote-config" };
    return cache;
  } catch (err) {
    logger.warn("Remote Config fetch failed; failing open", { err });
    cache = { flags: {}, fetchedAt: now(), source: "fail-open" };
    return cache;
  }
}

/**
 * Returns whether a given notification type is enabled. Defaults to true
 * when the flag is missing or RC is unreachable (fail-open).
 */
export async function isNotificationTypeEnabled(
  notificationType: string,
  deps: RcFlagsDeps = {}
): Promise<boolean> {
  const { flags } = await getFlags(deps);
  if (Object.prototype.hasOwnProperty.call(flags, notificationType)) {
    return flags[notificationType];
  }
  return true;
}

/**
 * Sets a single flag's value via the Admin SDK. Used by the
 * auto-suppression scheduler. Mutates the live RC template; downstream
 * isolates pick up the change on next cache miss (≤5 min). Test seam:
 * pass `mutator` to avoid hitting the live SDK.
 */
export async function setNotificationTypeEnabled(
  notificationType: string,
  enabled: boolean,
  mutator?: (key: string, value: string) => Promise<void>
): Promise<void> {
  const key = RC_FLAG_PREFIX + notificationType;
  if (mutator) {
    await mutator(key, String(enabled));
    // Invalidate cache so the next read picks up the change in-process.
    cache = null;
    return;
  }
  const remoteConfig = admin.remoteConfig();
  const template = await remoteConfig.getTemplate();
  template.parameters = template.parameters ?? {};
  template.parameters[key] = {
    defaultValue: { value: String(enabled) },
    description: `BUT-645 auto-suppression flag for ${notificationType}`,
    valueType: "BOOLEAN",
  };
  await remoteConfig.publishTemplate(template);
  cache = null;
}
