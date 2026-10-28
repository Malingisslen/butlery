/**
 * BUT-2463: `deep_links` retention, unit tests for `pruneExpiredDeepLinks` and
 * the scheduled wrapper's declared timeout.
 *
 * A fake db models exactly the calls the sweep makes:
 *   collection('deep_links').where('createdAt', '<', cutoff).limit(n).get()
 *   link.ref.collection('clicks').limit(n).get()
 *   db.batch().delete(ref) / commit()
 * A `createdAt` that is not a Timestamp never matches the range, as in
 * Firestore, where a range filter only matches values of the same type.
 *
 * Run: npx ts-node src/__tests__/cleanup-deep-links.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-deep-links-retention" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  pruneExpiredDeepLinks,
  cleanupExpiredDeepLinks,
  DEEP_LINK_RETENTION_DAYS,
  MAX_EXECUTION_TIME_MS,
} = require("../cleanup/cleanup-deep-links");

type Data = Record<string, unknown>;

interface FakeRef {
  path: string;
  collection(name: string): { limit(n: number): { get(): Promise<FakeSnap> } };
}

interface FakeSnap {
  empty: boolean;
  size: number;
  docs: { ref: FakeRef; id: string; data(): Data }[];
}

class Store {
  readonly docs = new Map<string, Data>();
  readonly queries: { field: string; op: string; limit: number }[] = [];
  set(path: string, data: Data): void {
    this.docs.set(path, data);
  }
  has(path: string): boolean {
    return this.docs.has(path);
  }
  /** Stored paths exactly one collection below `prefix`. */
  childrenOf(prefix: string): string[] {
    const depth = prefix.split("/").length + 1;
    return [...this.docs.keys()]
      .filter((p) => p.startsWith(`${prefix}/`) && p.split("/").length === depth)
      .sort();
  }
}

function snapOf(store: Store, paths: string[]): FakeSnap {
  return {
    empty: paths.length === 0,
    size: paths.length,
    docs: paths.map((p) => ({
      ref: refOf(store, p),
      id: p.split("/").pop() as string,
      data: () => store.docs.get(p) as Data,
    })),
  };
}

function refOf(store: Store, path: string): FakeRef {
  return {
    path,
    collection: (name: string) => ({
      limit: (n: number) => ({
        get: async () => snapOf(store, store.childrenOf(`${path}/${name}`).slice(0, n)),
      }),
    }),
  };
}

function fakeDb(store: Store) {
  return {
    collection(name: string) {
      if (name !== "deep_links") throw new Error(`unexpected collection ${name}`);
      return {
        where(field: string, op: string, cutoff: admin.firestore.Timestamp) {
          return {
            limit(n: number) {
              return {
                async get() {
                  store.queries.push({ field, op, limit: n });
                  const matches = store.childrenOf("deep_links").filter((p) => {
                    const value = (store.docs.get(p) as Data)[field];
                    return (
                      op === "<" &&
                      value instanceof admin.firestore.Timestamp &&
                      value.toMillis() < cutoff.toMillis()
                    );
                  });
                  return snapOf(store, matches.slice(0, n));
                },
              };
            },
          };
        },
      };
    },
    batch() {
      const paths: string[] = [];
      return {
        delete(ref: FakeRef) {
          paths.push(ref.path);
        },
        async commit() {
          for (const p of paths) store.docs.delete(p);
        },
      };
    },
  };
}

let total = 0;
let failed = 0;
function record(name: string, ok: boolean, detail = ""): void {
  total++;
  if (!ok) failed++;
  console.log(`  ${ok ? "PASS" : "FAIL"}  ${name}${ok || !detail ? "" : ` — ${detail}`}`);
}

const DAY_MS = 24 * 60 * 60 * 1000;
const NOW = admin.firestore.Timestamp.fromMillis(Date.UTC(2026, 10, 1, 12));
const daysAgo = (d: number) => admin.firestore.Timestamp.fromMillis(NOW.toMillis() - d * DAY_MS);

async function deletesOldLinksWithClicksAndKeepsYoungOnes(): Promise<void> {
  const store = new Store();
  store.set("deep_links/old15", { createdBy: "u1", createdAt: daysAgo(15) });
  store.set("deep_links/old15/clicks/c1", { userId: "u2" });
  store.set("deep_links/old15/clicks/c2", { userId: "u3" });
  store.set("deep_links/young13", { createdBy: "u1", createdAt: daysAgo(13) });
  store.set("deep_links/young13/clicks/c1", { userId: "u2" });
  store.set("deep_links/text", { createdBy: "u1", createdAt: "2020-01-01" });

  const result = await pruneExpiredDeepLinks(fakeDb(store) as never, { now: NOW });

  record("the retention window is 14 days", DEEP_LINK_RETENTION_DAYS === 14);
  record("a 15-day-old link is deleted", !store.has("deep_links/old15"));
  record(
    "its clicks are deleted with it",
    store.childrenOf("deep_links/old15/clicks").length === 0,
    JSON.stringify(store.childrenOf("deep_links/old15/clicks")),
  );
  record(
    "a 13-day-old link and its clicks are kept",
    store.has("deep_links/young13") && store.has("deep_links/young13/clicks/c1"),
  );
  record("a link without a Timestamp createdAt is not matched", store.has("deep_links/text"));
  record(
    "the run reports one deletion and a drained queue",
    result.deleted === 1 && result.stoppedBy === "drained",
    JSON.stringify(result),
  );
  record(
    "every query is one range on createdAt",
    store.queries.length > 0 && store.queries.every((q) => q.field === "createdAt" && q.op === "<"),
    JSON.stringify(store.queries),
  );
}

async function stopsAtTheRowCap(): Promise<void> {
  const store = new Store();
  for (let i = 0; i < 1200; i++) {
    store.set(`deep_links/l${String(i).padStart(4, "0")}`, { createdAt: daysAgo(30) });
  }

  const result = await pruneExpiredDeepLinks(fakeDb(store) as never, { now: NOW, maxRows: 700 });

  record(
    "a run stops at its row cap and leaves the rest for the next run",
    result.deleted === 700 &&
      result.stoppedBy === "row_cap" &&
      store.childrenOf("deep_links").length === 500,
    `${JSON.stringify(result)}, left ${store.childrenOf("deep_links").length}`,
  );
  record(
    "no page reads past the cap",
    store.queries.every((q) => q.limit <= 500) && store.queries[1]?.limit === 200,
    JSON.stringify(store.queries),
  );
}

async function stopsAtTheDeadline(): Promise<void> {
  const store = new Store();
  for (let i = 0; i < 1200; i++) {
    store.set(`deep_links/l${String(i).padStart(4, "0")}`, { createdAt: daysAgo(30) });
  }
  // Each read of the clock advances it a minute, so the 2-minute budget runs
  // out after two pages.
  let t = 0;
  const clock = () => (t += 60_000);

  const result = await pruneExpiredDeepLinks(fakeDb(store) as never, {
    now: NOW,
    maxExecutionMs: 2 * 60_000,
    clock,
  });

  record(
    "a run stops at its deadline with work left",
    result.stoppedBy === "deadline" &&
      result.deleted === 1000 &&
      store.childrenOf("deep_links").length === 1200 - result.deleted,
    JSON.stringify(result),
  );
}

async function timeoutSecondsIsDeclared(): Promise<void> {
  const endpoint = (
    cleanupExpiredDeepLinks as {
      __endpoint?: { timeoutSeconds?: unknown; region?: unknown };
    }
  ).__endpoint;
  const declared = endpoint?.timeoutSeconds;
  record(
    "cleanupExpiredDeepLinks declares timeoutSeconds 540, and the self-budget fits inside it",
    declared === 540 && typeof declared === "number" && MAX_EXECUTION_TIME_MS < declared * 1000,
    `timeoutSeconds=${String(declared)}`,
  );
}

async function runAll(): Promise<void> {
  console.log("deep_links retention tests (BUT-2463)\n");
  await deletesOldLinksWithClicksAndKeepsYoungOnes();
  await stopsAtTheRowCap();
  await stopsAtTheDeadline();
  await timeoutSecondsIsDeclared();
  console.log(`\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

runAll().catch((err) => {
  console.error(err);
  process.exit(1);
});
