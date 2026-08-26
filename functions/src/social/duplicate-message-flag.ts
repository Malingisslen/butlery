/**
 * Server-side kill switch for the CHAT half of the duplicate-content guard
 * (BUT-1898). Remote Config key `enable_chat_duplicate_guard`.
 *
 * An ABSENT parameter reads as false, so this ships OFF with no console step.
 *
 * Same shape as `ratings/pooled-ratings-flag.ts` — module-scope cache with a
 * 5-minute TTL, one cache per isolate, cold starts invalidate — and the
 * OPPOSITE failure contract, which is the whole reason this is a separate file
 * rather than a reuse of that one:
 *
 *   · RC readable, flag literal "true"  -> true. Reject duplicates.
 *   · RC readable, flag absent/anything -> false. Feature off.
 *   · RC UNREACHABLE                    -> false, logged, NOT cached.
 *
 * Pooled ratings THROWS on an unreachable template, because there the
 * indeterminate state must not silently drop a user's vote and the caller
 * retries. Here the action on "enabled" is to empty and mark a message somebody
 * just sent (BUT-1904; it was `tx.delete()` until then), so not-acting is the
 * safe direction: the worst case is that one duplicate survives an RC blip,
 * which is exactly what happens today anyway.
 * Throwing instead would hand the trigger an error that `onDocumentCreated`
 * without `retry` simply drops — the same outcome plus a spurious alert.
 *
 * The error path deliberately does NOT cache. A transient failure must not pin
 * the guard off for the rest of the isolate's life, and must not pin it on.
 *
 * ROLLOUT CONSTRAINT, inherited from the pooled-ratings flag and just as real
 * here: this reads only the parameter's `defaultValue`. It does NOT evaluate RC
 * conditions or percentage rollouts. Roll it as a plain on/off value — a
 * conditional rollout would be invisible to the server.
 *
 * KNOWN DUPLICATION, counted rather than estimated. Grepping
 * `admin.remoteConfig()` across `functions/src` finds exactly FOUR callers:
 * `shared/notification-rc-flags.ts` (fails open), `ratings/pooled-ratings-flag.ts`
 * (throws), `analytics/winback-variant.ts`, and this one.
 *
 * An earlier draft of this comment said five and named `prompts-config.ts`. That
 * is wrong twice over: it lives at `llm/prompts-config.ts`, and its own header
 * says "Remote-Config-STYLE prompt loading FROM FIRESTORE" — it reads
 * `system/prompts` and never touches RC. `winback-variant.ts` also returns copy
 * rather than a boolean and carries an in-flight promise this file does not.
 *
 * So the shareable set is three, not five, and only two of those three are
 * boolean flags whose sole difference is the failure contract. A
 * `shared/rc-boolean-flag.ts` taking `onError: 'open' | 'closed' | 'throw'` is
 * still the right shape for those two plus this one; it is just a smaller job
 * than the first draft implied. Not done here — it would refactor the ratings
 * kill switch inside a ticket about a chat trigger. Filed separately.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";

/** RC key. Server-only — no Flutter client reads this one. */
export const CHAT_DUPLICATE_GUARD_FLAG = "enable_chat_duplicate_guard";
export const RC_CACHE_TTL_MS = 5 * 60 * 1000;

interface FlagCache {
  enabled: boolean;
  fetchedAt: number;
}

let cache: FlagCache | null = null;

/** Test-only reset between cases. */
export function __resetChatGuardFlagCacheForTests(): void {
  cache = null;
}

/**
 * Test-only: seed the cache so a test can drive the trigger with the flag on
 * or off without reaching Remote Config. Seeds the SAME cache the real path
 * reads, so a test cannot accidentally exercise a different code path than
 * production does.
 */
export function __setChatGuardFlagForTests(
  enabled: boolean,
  fetchedAt: number = Date.now(),
): void {
  // `fetchedAt` is injectable because the reader honours a `now` seam: seeding
  // with a real clock while reading with a fake one makes the entry
  // permanently fresh, so such a test could never exercise expiry.
  cache = { enabled, fetchedAt };
}

export interface ChatGuardFlagDeps {
  /** Test seam — production resolves the RC template. */
  loader?: () => Promise<boolean>;
  /** Test seam for now-time (ms). */
  now?: () => number;
  ttlMs?: number;
}

async function defaultLoader(): Promise<boolean> {
  const template = await admin.remoteConfig().getTemplate();
  const param = template.parameters?.[CHAT_DUPLICATE_GUARD_FLAG] as
    | { defaultValue?: { value?: string } }
    | undefined;
  const raw = param?.defaultValue?.value;
  // Strict: only the literal string "true" enables.
  return typeof raw === "string" && raw.toLowerCase() === "true";
}

/**
 * Whether the chat duplicate guard may act on a duplicate. False when the flag is missing,
 * not the literal "true", or Remote Config cannot be reached.
 */
export async function isChatDuplicateGuardEnabled(
  deps: ChatGuardFlagDeps = {}
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
    logger.warn(
      "[duplicate-content-guard] Remote Config unreachable; " +
        "leaving the chat guard OFF for this invocation",
      err
    );
    return false;
  }
}
