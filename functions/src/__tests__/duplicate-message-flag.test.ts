/**
 * duplicate-message-flag.ts — the chat duplicate guard's kill switch (BUT-1898).
 *
 * The integration suite seeds the cache directly, so `defaultLoader` and the
 * `catch` were the two branches nothing executed. That is exactly where this
 * file's contract lives, and the contract is the OPPOSITE of its sibling's:
 *
 *   - determinate true / false from the loader;
 *   - 5-min TTL cache reuse + expiry;
 *   - INDETERMINATE (loader throws) -> returns FALSE and does NOT cache.
 *
 * Why that matters enough to test: `ratings/pooled-ratings-flag.ts` THROWS in
 * the same situation, and the file itself proposes collapsing the two into one
 * shared helper. That refactor would harmonise this contract to `throw` and
 * every other suite would stay green — a chat guard that deletes people's
 * messages would start acting on an indeterminate answer. This is the test that
 * goes red instead.
 *
 * Run with: npx ts-node src/__tests__/duplicate-message-flag.test.ts
 */

import {
  isChatDuplicateGuardEnabled,
  __resetChatGuardFlagCacheForTests,
  RC_CACHE_TTL_MS,
} from "../social/duplicate-message-flag";

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

async function main(): Promise<void> {
  console.log("BUT-1898: chat duplicate guard kill switch\n");

  // Determinate true.
  {
    __resetChatGuardFlagCacheForTests();
    const enabled = await isChatDuplicateGuardEnabled({
      loader: async () => true,
    });
    record("a literal true enables the guard", enabled === true, `got ${enabled}`);
  }

  // Determinate false — the state this ships in.
  {
    __resetChatGuardFlagCacheForTests();
    const enabled = await isChatDuplicateGuardEnabled({
      loader: async () => false,
    });
    record("anything else leaves it off", enabled === false, `got ${enabled}`);
  }

  // Cache reuse inside the TTL: one loader call, not two.
  {
    __resetChatGuardFlagCacheForTests();
    let calls = 0;
    const loader = async () => {
      calls++;
      return true;
    };
    let t = 1_000_000;
    await isChatDuplicateGuardEnabled({ loader, now: () => t });
    t += RC_CACHE_TTL_MS - 1;
    const second = await isChatDuplicateGuardEnabled({ loader, now: () => t });
    record(
      "a second read inside the TTL is served from cache",
      calls === 1 && second === true,
      `calls=${calls} second=${second}`,
    );
  }

  // Cache expiry: past the TTL it asks again, and a flipped answer is honoured.
  {
    __resetChatGuardFlagCacheForTests();
    let calls = 0;
    const loader = async () => {
      calls++;
      return calls === 1;
    };
    let t = 1_000_000;
    const first = await isChatDuplicateGuardEnabled({ loader, now: () => t });
    t += RC_CACHE_TTL_MS + 1;
    const second = await isChatDuplicateGuardEnabled({ loader, now: () => t });
    record(
      "past the TTL it re-reads and honours a flipped answer",
      calls === 2 && first === true && second === false,
      `calls=${calls} first=${first} second=${second}`,
    );
  }

  // THE CONTRACT. An unreachable Remote Config must resolve to "do not delete".
  {
    __resetChatGuardFlagCacheForTests();
    const enabled = await isChatDuplicateGuardEnabled({
      loader: async () => {
        throw new Error("RC unreachable");
      },
    });
    record(
      "an unreachable Remote Config returns false rather than throwing",
      enabled === false,
      `got ${enabled}`,
    );
  }

  // ...and must NOT be cached, or one blip pins the guard off for the rest of
  // the isolate's life. Second call succeeds and must be honoured immediately.
  {
    __resetChatGuardFlagCacheForTests();
    let calls = 0;
    const loader = async () => {
      calls++;
      if (calls === 1) throw new Error("RC unreachable");
      return true;
    };
    const t = 1_000_000;
    const first = await isChatDuplicateGuardEnabled({ loader, now: () => t });
    // Same instant: if the failure had been cached, this would return the
    // cached false without calling the loader again.
    const second = await isChatDuplicateGuardEnabled({ loader, now: () => t });
    record(
      "a failure is not cached, so recovery is immediate",
      calls === 2 && first === false && second === true,
      `calls=${calls} first=${first} second=${second}`,
    );
  }

  console.log(`\n${totalRun - totalFailed}/${totalRun} passed`);
  if (totalFailed > 0) process.exit(1);
}

void main();
