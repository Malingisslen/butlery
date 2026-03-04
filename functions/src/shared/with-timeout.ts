/**
 * Shared timeout utility for cascade operations.
 *
 * Used by ingredient trigger functions that cascade changes to recipes.
 */

/** Default timeout for cascade operations (2 minutes). */
export const CASCADE_TIMEOUT_MS = 120000;

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
