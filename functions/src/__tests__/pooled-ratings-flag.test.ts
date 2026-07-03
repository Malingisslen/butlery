/**
 * pooled-ratings-flag.ts — server kill-switch reader tests.
 *
 * Covers the contract the mirror relies on (and that the mirror suite, which
 * injects deps.isEnabled, never exercises):
 *   - determinate true / false from the loader;
 *   - 5-min TTL cache reuse + expiry;
 *   - INDETERMINATE (loader throws) → the reader THROWS and does NOT cache, so
 *     the retry-enabled trigger re-runs (never activates on error, never drops
 *     a live vote to an RC blip).
 *
 * Run with: npx ts-node src/__tests__/pooled-ratings-flag.test.ts
 */

import {
  isPooledRatingsEnabled,
  __resetPooledFlagCacheForTests,
  RC_CACHE_TTL_MS,
} from "../ratings/pooled-ratings-flag";

let totalRun = 0;
let totalFailed = 0;
function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) console.log(`  PASS  ${name}`);
  else {
    totalFailed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

async function determinateValues(): Promise<void> {
  __resetPooledFlagCacheForTests();
  const on = await isPooledRatingsEnabled({ loader: async () => true, now: () => 0 });
  __resetPooledFlagCacheForTests();
  const off = await isPooledRatingsEnabled({ loader: async () => false, now: () => 0 });
  record("loader true → enabled; loader false → disabled", on === true && off === false, `on=${on} off=${off}`);
}

async function cacheReuseWithinTtl(): Promise<void> {
  __resetPooledFlagCacheForTests();
  let calls = 0;
  const loader = async () => {
    calls++;
    return true;
  };
  await isPooledRatingsEnabled({ loader, now: () => 1000 });
  await isPooledRatingsEnabled({ loader, now: () => 1000 + RC_CACHE_TTL_MS - 1 });
  record("within TTL → loader called once (cache reused)", calls === 1, `calls=${calls}`);
}

async function cacheExpiresAfterTtl(): Promise<void> {
  __resetPooledFlagCacheForTests();
  let calls = 0;
  const loader = async () => {
    calls++;
    return true;
  };
  await isPooledRatingsEnabled({ loader, now: () => 1000 });
  await isPooledRatingsEnabled({ loader, now: () => 1000 + RC_CACHE_TTL_MS + 1 });
  record("after TTL → loader called again (cache expired)", calls === 2, `calls=${calls}`);
}

async function errorThrowsAndDoesNotCache(): Promise<void> {
  __resetPooledFlagCacheForTests();
  let threw = false;
  try {
    await isPooledRatingsEnabled({
      loader: async () => {
        throw new Error("RC unreachable");
      },
      now: () => 0,
    });
  } catch {
    threw = true;
  }
  // Next call with a good loader must re-read (the failure was not cached).
  const after = await isPooledRatingsEnabled({ loader: async () => true, now: () => 1 });
  record(
    "loader error → THROWS and does not cache (next call re-reads)",
    threw && after === true,
    `threw=${threw} after=${after}`
  );
}

async function runAll(): Promise<void> {
  console.log("pooled-ratings-flag.ts tests\n");
  console.log("==============================================\n");
  await determinateValues();
  await cacheReuseWithinTtl();
  await cacheExpiresAfterTtl();
  await errorThrowsAndDoesNotCache();
  console.log(
    `\n${totalRun - totalFailed}/${totalRun} passed` +
      (totalFailed ? `, ${totalFailed} failed` : "")
  );
  if (totalFailed > 0) process.exit(1);
}

runAll().catch((err) => {
  console.error(err);
  process.exit(1);
});
