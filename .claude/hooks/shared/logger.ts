/**
 * Simple logging utilities for hooks
 * Logs go to stderr (visible to user) or nowhere (quiet mode)
 */

const DEBUG = process.env.HOOK_DEBUG === '1';

export function debug(message: string, ...args: any[]): void {
  if (DEBUG) {
    console.error(`[DEBUG] ${message}`, ...args);
  }
}

export function info(message: string, ...args: any[]): void {
  console.error(`[INFO] ${message}`, ...args);
}

export function warn(message: string, ...args: any[]): void {
  console.error(`[WARN] ${message}`, ...args);
}

export function error(message: string, ...args: any[]): void {
  console.error(`[ERROR] ${message}`, ...args);
}

/**
 * Measure execution time of a function
 */
export async function measureTime<T>(
  label: string,
  fn: () => T | Promise<T>
): Promise<T> {
  const start = Date.now();
  try {
    const result = await fn();
    const duration = Date.now() - start;
    debug(`${label}: ${duration}ms`);
    return result;
  } catch (err) {
    const duration = Date.now() - start;
    debug(`${label}: ${duration}ms (failed)`);
    throw err;
  }
}
