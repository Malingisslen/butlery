/**
 * BUT-1604 — deletion_audit_logs TTL purge unit tests.
 *
 * Verifies `purgeExpiredDeletionAuditLogs` (the testable extraction from the
 * `cleanupOldAuditLogs` scheduler CF) actually DELETES docs whose `expireAt`
 * TTL is in the past and KEEPS docs whose TTL is still in the future. The
 * delete side of this GDPR Art. 5 reap was previously untested.
 *
 * Run: npx ts-node src/__tests__/cleanup-audit-logs.test.ts
 *
 * Pattern follows `purge-audit-logs.test.ts` — a fake admin.firestore() shape
 * driven by an in-memory store, no real emulator. The admin SDK bypasses
 * security rules by design, so there are none in scope here.
 */

// firebase-admin module-level imports require an initialized default app even
// when the fake db is what actually runs.
import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-deletion-audit-purge" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  purgeExpiredDeletionAuditLogs,
} = require("../cleanup/cleanup-audit-logs");

interface SeedDoc {
  id: string;
  /** epoch ms — the doc's expireAt TTL. */
  expireAtMs: number;
}

interface FakeStore {
  docs: SeedDoc[];
  deleted: Set<string>;
}

interface FakeTimestamp {
  toMillis(): number;
  valueOf(): number;
}

function makeTimestamp(ms: number): FakeTimestamp {
  return { toMillis: () => ms, valueOf: () => ms };
}

/**
 * Minimal fake db modelling exactly the call chain the helper + batchDeleteDocs
 * exercise:
 *   collection('deletion_audit_logs')
 *     .where('expireAt', '<', now).limit(n).get()
 *   db.batch().delete(ref) / commit()
 */
function makeFakeDb(store: FakeStore) {
  function makeQuery(predicates: { cutoffMs?: number; limitN?: number }) {
    return {
      where(field: string, op: string, value: FakeTimestamp) {
        if (field === "expireAt" && op === "<") {
          return makeQuery({ ...predicates, cutoffMs: value.toMillis() });
        }
        throw new Error(`makeFakeDb: unexpected where(${field}, ${op})`);
      },
      limit(n: number) {
        return makeQuery({ ...predicates, limitN: n });
      },
      async get() {
        let matches = store.docs;
        if (predicates.cutoffMs !== undefined) {
          const cutoff = predicates.cutoffMs;
          matches = matches.filter((d) => d.expireAtMs < cutoff);
        }
        if (predicates.limitN !== undefined) {
          matches = matches.slice(0, predicates.limitN);
        }
        return {
          empty: matches.length === 0,
          docs: matches.map((m) => ({
            ref: {
              delete: async () => {
                store.deleted.add(m.id);
              },
            },
          })),
        };
      },
    };
  }

  return {
    collection(name: string) {
      if (name !== "deletion_audit_logs") {
        throw new Error(`unexpected collection access: ${name}`);
      }
      return makeQuery({});
    },
    batch() {
      const ops: Array<() => Promise<void>> = [];
      return {
        delete(ref: { delete: () => Promise<void> }) {
          ops.push(() => ref.delete());
        },
        async commit() {
          for (const op of ops) await op();
        },
      };
    },
  };
}

let totalRun = 0;
let totalFailed = 0;

function record(name: string, ok: boolean, detail?: string): void {
  totalRun++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    totalFailed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

const DAY_MS = 24 * 60 * 60 * 1000;
const NOW_MS = Date.UTC(2027, 0, 15);
const now = makeTimestamp(NOW_MS);

async function deletesExpiredKeepsFuture(): Promise<void> {
  const store: FakeStore = {
    docs: [
      // Expired an hour ago → must be deleted.
      { id: "expired-recent", expireAtMs: NOW_MS - 60 * 60 * 1000 },
      // Expired 200 days ago → must be deleted.
      { id: "expired-old", expireAtMs: NOW_MS - 200 * DAY_MS },
      // TTL still 30 days out → must be KEPT.
      { id: "future", expireAtMs: NOW_MS + 30 * DAY_MS },
    ],
    deleted: new Set(),
  };
  const count = await purgeExpiredDeletionAuditLogs(
    makeFakeDb(store) as never,
    now as never
  );
  const ok =
    count === 2 &&
    store.deleted.has("expired-recent") &&
    store.deleted.has("expired-old") &&
    !store.deleted.has("future");
  record(
    "deletes docs past their expireAt TTL, keeps docs whose TTL is still in the future",
    ok,
    `count=${count} deleted=[${[...store.deleted].join(", ")}]`
  );
}

async function emptyCollectionNoop(): Promise<void> {
  const store: FakeStore = { docs: [], deleted: new Set() };
  const count = await purgeExpiredDeletionAuditLogs(
    makeFakeDb(store) as never,
    now as never
  );
  record(
    "empty deletion_audit_logs → no-op, returns 0",
    count === 0 && store.deleted.size === 0,
    `count=${count}`
  );
}

async function allFutureNoop(): Promise<void> {
  const store: FakeStore = {
    docs: [
      { id: "f1", expireAtMs: NOW_MS + DAY_MS },
      { id: "f2", expireAtMs: NOW_MS + 90 * DAY_MS },
    ],
    deleted: new Set(),
  };
  const count = await purgeExpiredDeletionAuditLogs(
    makeFakeDb(store) as never,
    now as never
  );
  record(
    "all TTLs in the future → nothing deleted, returns 0",
    count === 0 && store.deleted.size === 0,
    `count=${count} deleted=[${[...store.deleted].join(", ")}]`
  );
}

async function batchDeleteAcrossManyDocs(): Promise<void> {
  // 600 expired docs > the 500-op batch limit — proves batchDeleteDocs commits
  // across multiple batches and deletes every expired doc.
  const store: FakeStore = {
    docs: Array.from({ length: 600 }, (_, i) => ({
      id: `e-${i}`,
      expireAtMs: NOW_MS - (i + 1) * 60 * 1000,
    })),
    deleted: new Set(),
  };
  const count = await purgeExpiredDeletionAuditLogs(
    makeFakeDb(store) as never,
    now as never
  );
  record(
    "reap spanning >500 docs deletes all expired entries across batches",
    count === 600 && store.deleted.size === 600,
    `count=${count} deleted=${store.deleted.size}`
  );
}

async function runAll(): Promise<void> {
  console.log("BUT-1604: deletion_audit_logs TTL purge tests\n");
  console.log("==========================================\n");
  await deletesExpiredKeepsFuture();
  await emptyCollectionNoop();
  await allFutureNoop();
  await batchDeleteAcrossManyDocs();

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
