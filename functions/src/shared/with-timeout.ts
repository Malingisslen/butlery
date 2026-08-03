/**
 * Shared timeout utility for cascade operations.
 *
 * Used by ingredient trigger functions that cascade changes to recipes.
 */

/**
 * Wall clock the cascade triggers give themselves, in ms.
 *
 * MUST stay below the `timeoutSeconds` those triggers declare, or this guard is
 * dead code: the platform kills the instance first, which produces no error log,
 * a partially applied cascade and no resume (`batchUpdateQueryPaginated`
 * restarts at page 1 on every invocation). At 120_000 against the v2 event
 * default of 60s it was exactly that — inert, and invisible only because the
 * queries matched zero documents.
 *
 * Paired with `CASCADE_TIMEOUT_SECONDS` below: raise them together.
 */
export const CASCADE_TIMEOUT_MS = 500000;

/**
 * `timeoutSeconds` the cascade triggers must declare. 540s is the v2 event
 * maximum; the guard above fires ~40s earlier so the failure surfaces as a
 * logged error the platform can hand back for a retry, rather than a silent
 * kill that produces no error at all.
 *
 * "Retryable" is only true because the triggers ALSO declare `retry: true`:
 * v2 event triggers do not retry by default, so without it the `throw` after
 * this guard is logged and dropped (same note as `functions/src/index.ts`).
 * Keep the two settings together — dropping either one turns a partial cascade
 * into a permanent one.
 */
export const CASCADE_TIMEOUT_SECONDS = 540;

/**
 * How long a cascade event may keep being retried before it is abandoned.
 *
 * `retry: true` re-delivers a failing event for up to 7 DAYS. A cascade that
 * fails deterministically (a poisoned ingredient name, a missing index) would
 * otherwise re-write the same pages for a week at 500 writes a page. One hour
 * covers every transient cause worth retrying — contention, a cold index, a
 * platform kill — and stops there.
 */
export const CASCADE_MAX_EVENT_AGE_MS = 60 * 60 * 1000;

/**
 * True when this delivery is a retry of an event too old to be worth retrying.
 *
 * An unparseable/absent `event.time` returns false: never abandon work because
 * a timestamp could not be read.
 */
export function isCascadeEventExpired(
  eventTime: string | undefined,
  maxAgeMs: number = CASCADE_MAX_EVENT_AGE_MS,
): boolean {
  if (!eventTime) return false;
  const emitted = Date.parse(eventTime);
  if (Number.isNaN(emitted)) return false;
  return Date.now() - emitted > maxAgeMs;
}

/** Wraps an async operation with a timeout. */
export async function withTimeout<T>(
  operation: Promise<T>,
  timeoutMs: number,
  operationName: string,
): Promise<T> {
  let timeoutId: NodeJS.Timeout;

  const timeoutPromise = new Promise<never>((_, reject) => {
    timeoutId = setTimeout(() => {
      reject(new Error(`${operationName} timed out after ${timeoutMs}ms`));
    }, timeoutMs);
  });

  try {
    return await Promise.race([operation, timeoutPromise]);
  } finally {
    clearTimeout(timeoutId!);
  }
}
