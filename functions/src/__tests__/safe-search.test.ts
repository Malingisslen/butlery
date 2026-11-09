/**
 * BUT-818 — SafeSearch verdict and the once-per-image cache.
 *
 * Run: npx ts-node src/__tests__/safe-search.test.ts
 */

import {
  LEASE_MS,
  isExplicit,
  SafeSearchScores,
  scanKey,
  scanOnce,
  shouldScan,
  toLikelihood,
} from "../storage/safe-search";

type TestFn = () => Promise<void> | void;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}
function assertEqual(actual: unknown, expected: unknown, msg: string): void {
  if (actual !== expected) {
    throw new Error(`${msg}: expected ${String(expected)}, got ${String(actual)}`);
  }
}

const CLEAN: SafeSearchScores = { adult: "VERY_UNLIKELY", violence: "VERY_UNLIKELY", racy: "VERY_UNLIKELY" };
// Base64 of 16 bytes, with a `/` in it as Storage's md5 often has.
const MD5 = Buffer.from("00ff3f".repeat(5) + "ab", "hex").toString("base64");

test("thresholds: adult and violence stop at LIKELY, racy only at VERY_LIKELY", () => {
  assertEqual(isExplicit(CLEAN), false, "clean");
  assertEqual(isExplicit({ ...CLEAN, adult: "POSSIBLE" }), false, "adult POSSIBLE");
  assertEqual(isExplicit({ ...CLEAN, adult: "LIKELY" }), true, "adult LIKELY");
  assertEqual(isExplicit({ ...CLEAN, violence: "LIKELY" }), true, "violence LIKELY");
  assertEqual(isExplicit({ ...CLEAN, racy: "LIKELY" }), false, "racy LIKELY (food false positives)");
  assertEqual(isExplicit({ ...CLEAN, racy: "VERY_LIKELY" }), true, "racy VERY_LIKELY");
  assertEqual(isExplicit({ ...CLEAN, adult: "UNKNOWN" }), false, "UNKNOWN");
});

test("toLikelihood: names, proto numbers and junk", () => {
  assertEqual(toLikelihood("LIKELY"), "LIKELY", "name");
  assertEqual(toLikelihood(5), "VERY_LIKELY", "number");
  assertEqual(toLikelihood("nope"), "UNKNOWN", "junk string");
  assertEqual(toLikelihood(undefined), "UNKNOWN", "undefined");
});

test("shouldScan: only users/", () => {
  assertEqual(shouldScan("users/u1/recipes/a.jpg"), true, "users");
  assertEqual(shouldScan("feedback/u1/a.jpg"), false, "feedback");
  assertEqual(shouldScan("corpus/b/p.jpg"), false, "corpus");
});

const CRC = Buffer.from("0a0b0c0d", "hex").toString("base64");
const OTHER_CRC = Buffer.from("ffffffff", "hex").toString("base64");

function input(name: string, over: Partial<{ md5Hash: string | undefined; crc32c: string | undefined; size: string }> = {}) {
  return { bucketName: "b", name, md5Hash: MD5, crc32c: CRC, size: "1234", ...over };
}

test("scanKey: md5 + crc32c + size, doc-id safe; any part missing is null", () => {
  const key = scanKey(MD5, CRC, "1234");
  assertEqual(key, `${Buffer.from(MD5, "base64").toString("hex")}_0a0b0c0d_1234`, "key");
  assertEqual(key?.includes("/"), false, "no slash");
  assertEqual(scanKey(undefined, CRC, "1"), null, "no md5");
  assertEqual(scanKey(MD5, undefined, "1"), null, "no crc");
  assertEqual(scanKey(MD5, CRC, undefined), null, "no size");
  assertEqual(scanKey("abc", CRC, "1"), null, "md5 not 16 bytes");
});

type Doc = Record<string, unknown>;
interface FakeOpts {
  failGet?: boolean;
  failSet?: boolean;
  /** Runs before each read, to simulate another caller's writes. */
  beforeGet?: (store: Map<string, Doc>, id: string) => void;
}

function fakeDb(store: Map<string, Doc>, reads: string[], opts: FakeOpts = {}) {
  return {
    collection(name: string) {
      if (name !== "safe_search_scans") throw new Error(`unexpected collection ${name}`);
      return {
        doc(id: string) {
          return {
            async get() {
              reads.push(id);
              opts.beforeGet?.(store, id);
              if (opts.failGet) throw Object.assign(new Error("unavailable"), { code: 14 });
              const data = store.get(id);
              return { exists: data !== undefined, get: (f: string) => data?.[f], updateTime: "t" };
            },
            async create(data: Doc) {
              if (store.has(id)) throw Object.assign(new Error("exists"), { code: 6 });
              store.set(id, data);
            },
            async update(data: Doc) {
              store.set(id, { ...store.get(id), ...data });
            },
            async set(data: Doc) {
              if (opts.failSet) throw Object.assign(new Error("unavailable"), { code: 14 });
              store.set(id, data);
            },
            async delete() {
              store.delete(id);
            },
          };
        },
      };
    },
  } as never;
}

const noSleep = async () => undefined;

test("scanOnce: Vision is asked once per image, the server's copy is served from the cache", async () => {
  const store = new Map<string, Doc>();
  const calls: string[] = [];
  const deps = {
    db: fakeDb(store, []),
    sleep: noSleep,
    annotate: async (uri: string) => {
      calls.push(uri);
      return { ...CLEAN, adult: "VERY_LIKELY" as const };
    },
  };
  const first = await scanOnce(input("users/u/recipes/a.jpg"), deps);
  const second = await scanOnce(input("users/u/public_recipes/r/a.jpg"), deps);
  assertEqual(calls.length, 1, "Vision calls");
  assertEqual(calls[0], "gs://b/users/u/recipes/a.jpg", "gs uri");
  assertEqual(first?.cached, false, "first not cached");
  assertEqual(second?.cached, true, "second cached");
  assertEqual(second?.explicit, true, "cached verdict still explicit");
});

test("scanOnce: an appeal override lets the same explicit bytes through without a new call", async () => {
  const store = new Map<string, Doc>();
  const calls: string[] = [];
  const deps = {
    db: fakeDb(store, []),
    sleep: noSleep,
    annotate: async (uri: string) => {
      calls.push(uri);
      return { ...CLEAN, adult: "VERY_LIKELY" as const };
    },
  };
  await scanOnce(input("users/u/recipes/a.jpg"), deps);
  const key = scanKey(MD5, CRC, "1234") as string;
  // What overrideVerdict merges in, applied the way a merge-set would.
  store.set(key, { ...store.get(key), explicit: false, overriddenBy: "appeal" });
  const after = await scanOnce(input("users/u/recipes/a.jpg"), deps);
  assertEqual(calls.length, 1, "no second Vision call");
  assertEqual(after?.explicit, false, "overridden verdict lets the image stand");
  assertEqual(after?.scores.adult, "VERY_LIKELY", "scores kept for measuring false positives");
});

test("scanOnce: an md5 collision with a different crc32c is scanned on its own", async () => {
  const store = new Map<string, Doc>();
  let calls = 0;
  const deps = {
    db: fakeDb(store, []),
    sleep: noSleep,
    annotate: async () => {
      calls++;
      return calls === 1 ? CLEAN : { ...CLEAN, adult: "VERY_LIKELY" as const };
    },
  };
  await scanOnce(input("users/u/harmless.jpg"), deps);
  const evil = await scanOnce(input("users/u/evil.jpg", { crc32c: OTHER_CRC }), deps);
  assertEqual(calls, 2, "both scanned");
  assertEqual(evil?.explicit, true, "the colliding image is judged on its own");
});

test("scanOnce: an arrival during another call waits for its verdict instead of paying again", async () => {
  const store = new Map<string, Doc>();
  const key = scanKey(MD5, CRC, "1234") as string;
  store.set(key, { leaseAt: Date.now() });
  let reads = 0;
  let calls = 0;
  const result = await scanOnce(input("users/u/public_recipes/r/a.jpg"), {
    db: fakeDb(store, [], {
      beforeGet: (s, id) => {
        // The other caller finishes before the third read.
        if (++reads === 3) s.set(id, { ...CLEAN, adult: "LIKELY", explicit: true });
      },
    }),
    sleep: noSleep,
    annotate: async () => {
      calls++;
      return CLEAN;
    },
  });
  assertEqual(calls, 0, "no second Vision call");
  assertEqual(result?.explicit, true, "the other caller's verdict");
});

test("scanOnce: a stale claim (crashed run) is taken over and scanned", async () => {
  const store = new Map<string, Doc>();
  const key = scanKey(MD5, CRC, "1234") as string;
  store.set(key, { leaseAt: Date.now() - LEASE_MS - 1 });
  let calls = 0;
  await scanOnce(input("users/u/a.jpg"), {
    db: fakeDb(store, []),
    sleep: noSleep,
    annotate: async () => {
      calls++;
      return CLEAN;
    },
  });
  assertEqual(calls, 1, "scanned");
  assertEqual(store.get(key)?.explicit, false, "verdict stored");
});

test("scanOnce: a failed Vision call caches nothing, releases the claim and returns null", async () => {
  const store = new Map<string, Doc>();
  const result = await scanOnce(input("users/u/a.jpg"), {
    db: fakeDb(store, []),
    sleep: noSleep,
    annotate: async () => {
      throw Object.assign(new Error("quota"), { code: 8 });
    },
  });
  assertEqual(result, null, "null on failure");
  assertEqual(store.size, 0, "nothing cached, claim released");
});

test("scanOnce: a caller that never held the claim leaves it in place when Vision fails", async () => {
  const store = new Map<string, Doc>();
  const key = scanKey(MD5, CRC, "1234") as string;
  store.set(key, { leaseAt: Date.now() });
  await scanOnce(input("users/u/a.jpg"), {
    db: fakeDb(store, []),
    sleep: noSleep,
    annotate: async () => {
      throw new Error("quota");
    },
  });
  assertEqual(typeof store.get(key)?.leaseAt, "number", "the other caller's claim survives");
});

test("scanOnce: cache failures never decide the verdict", async () => {
  const explicitScores = { ...CLEAN, violence: "VERY_LIKELY" as const };
  const readFails = await scanOnce(input("users/u/a.jpg"), {
    db: fakeDb(new Map(), [], { failGet: true }),
    sleep: noSleep,
    annotate: async () => explicitScores,
  });
  assertEqual(readFails?.explicit, true, "read failure still scans");
  const writeFails = await scanOnce(input("users/u/a.jpg"), {
    db: fakeDb(new Map(), [], { failSet: true }),
    sleep: noSleep,
    annotate: async () => explicitScores,
  });
  assertEqual(writeFails?.explicit, true, "write failure still returns the verdict");
});

test("scanOnce: no checksums still scans, without touching the cache", async () => {
  const reads: string[] = [];
  let calls = 0;
  const result = await scanOnce(input("users/u/a.jpg", { md5Hash: undefined }), {
    db: fakeDb(new Map(), reads),
    sleep: noSleep,
    annotate: async () => {
      calls++;
      return CLEAN;
    },
  });
  assertEqual(calls, 1, "scanned");
  assertEqual(reads.length, 0, "no cache read");
  assertEqual(result?.explicit, false, "clean");
});

async function run(): Promise<void> {
  console.log("BUT-818: SafeSearch unit tests\n");
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(err);
    }
  }
  console.log(`\n${tests.length - failed}/${tests.length} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
