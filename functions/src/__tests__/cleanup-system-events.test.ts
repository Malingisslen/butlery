/**
 * `system_events` retention — unit tests for `pruneRateLimitViolations`,
 * `runSystemEventsCleanup` and the scheduled wrapper's declared timeout.
 *
 * The job deletes ONE row type (`rate_limit_violation`) from a shared
 * collection whose other row types must never be deleted on a clock: the two
 * moderation shapes can sit under a legal hold, and the run receipts are what
 * the admin ops-log tab displays. Cases 1-3 are that guarantee; they are the
 * reason this file exists, not coverage.
 *
 * Case 3 is the sharp one: `cleanup_expired_social_requests` is a RECEIPT that
 * carries `timestamp` rather than `executedAt`, so a prune keyed only on age
 * would delete it. It is the counter-example that makes the type predicate
 * load-bearing rather than decorative.
 *
 * Run: npx ts-node src/__tests__/cleanup-system-events.test.ts
 *
 * Pattern follows `cleanup-audit-logs.test.ts` — a fake admin.firestore()
 * shape driven by an in-memory store, no emulator. The Admin SDK bypasses
 * security rules by design, so there are none in scope here.
 */

// firebase-admin module-level imports require an initialized default app even
// when the fake db is what actually runs.
import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-system-events-retention" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  pruneRateLimitViolations,
  runSystemEventsCleanup,
  cleanupOldSystemEvents,
  MAX_EXECUTION_TIME_MS,
} = require("../cleanup/cleanup-system-events");

interface SeedDoc {
  id: string;
  type: string;
  /** epoch ms — the row's `timestamp`. Absent on rows that carry only `executedAt`. */
  timestampMs?: number;
}

interface WrittenDoc {
  collection: string;
  data: Record<string, unknown>;
}

interface FakeStore {
  docs: SeedDoc[];
  deleted: Set<string>;
  commits: number;
  written: WrittenDoc[];
}

interface FakeTimestamp {
  toMillis(): number;
  valueOf(): number;
}

function makeTimestamp(ms: number): FakeTimestamp {
  return { toMillis: () => ms, valueOf: () => ms };
}

/**
 * Minimal fake db modelling exactly the call chain the job exercises:
 *   collection('system_events')
 *     .where('type', '==', t).where('timestamp', '<', cutoff).limit(n).get()
 *   db.batch().delete(ref) / commit()
 *   collection('system_events').add({...})
 *
 * A row with no `timestampMs` never matches the range filter — the same way
 * Firestore excludes documents missing the filtered field. That is what makes
 * case 2 (an `executedAt`-only receipt) a real test rather than a tautology.
 */
function makeFakeDb(store: FakeStore) {
  function makeQuery(predicates: {
    type?: string;
    cutoffMs?: number;
    limitN?: number;
  }) {
    return {
      where(field: string, op: string, value: FakeTimestamp | string) {
        if (field === "type" && op === "==") {
          return makeQuery({ ...predicates, type: value as string });
        }
        if (field === "timestamp" && op === "<") {
          return makeQuery({
            ...predicates,
            cutoffMs: (value as FakeTimestamp).toMillis(),
          });
        }
        throw new Error(`makeFakeDb: unexpected where(${field}, ${op})`);
      },
      limit(n: number) {
        return makeQuery({ ...predicates, limitN: n });
      },
      async add(data: Record<string, unknown>) {
        store.written.push({ collection: "system_events", data });
        return { id: `written-${store.written.length}` };
      },
      async get() {
        let matches = store.docs.filter((d) => !store.deleted.has(d.id));
        if (predicates.type !== undefined) {
          matches = matches.filter((d) => d.type === predicates.type);
        }
        if (predicates.cutoffMs !== undefined) {
          const cutoff = predicates.cutoffMs;
          matches = matches.filter(
            (d) => d.timestampMs !== undefined && d.timestampMs < cutoff
          );
        }
        if (predicates.limitN !== undefined) {
          matches = matches.slice(0, predicates.limitN);
        }
        return {
          empty: matches.length === 0,
          size: matches.length,
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
      if (name !== "system_events") {
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
          store.commits++;
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

function emptyStore(docs: SeedDoc[]): FakeStore {
  return { docs, deleted: new Set(), commits: 0, written: [] };
}

const DAY_MS = 24 * 60 * 60 * 1000;
const NOW_MS = Date.UTC(2027, 0, 15);
const now = makeTimestamp(NOW_MS);
/** Comfortably past the 90-day window. */
const ANCIENT = NOW_MS - 400 * DAY_MS;

async function prune(store: FakeStore): Promise<number> {
  return await pruneRateLimitViolations(makeFakeDb(store) as never, now as never);
}

async function keepsModerationRowsHoweverOld(): Promise<void> {
  const store = emptyStore([
    { id: "report", type: "content_report", timestampMs: ANCIENT },
    {
      id: "threshold",
      type: "moderation_threshold_reached",
      timestampMs: ANCIENT,
    },
    { id: "violation", type: "rate_limit_violation", timestampMs: ANCIENT },
  ]);
  const count = await prune(store);
  const ok =
    count === 1 &&
    store.deleted.has("violation") &&
    !store.deleted.has("report") &&
    !store.deleted.has("threshold");
  record(
    "a 400-day-old content_report and moderation_threshold_reached survive; only the violation goes",
    ok,
    `count=${count} deleted=[${[...store.deleted].join(", ")}]`
  );
}

async function keepsExecutedAtReceipt(): Promise<void> {
  // A run receipt carrying only `executedAt` — no `timestamp` field at all.
  const store = emptyStore([
    { id: "receipt", type: "ingredient_cleanup" },
    { id: "violation", type: "rate_limit_violation", timestampMs: ANCIENT },
  ]);
  const count = await prune(store);
  record(
    "an old ingredient_cleanup receipt (executedAt only, no timestamp) survives",
    count === 1 && !store.deleted.has("receipt"),
    `count=${count} deleted=[${[...store.deleted].join(", ")}]`
  );
}

async function keepsTimestampBearingReceipt(): Promise<void> {
  // The counter-example: a RECEIPT that carries `timestamp`, not `executedAt`.
  // An age-only prune would delete this. The type predicate is what saves it.
  const store = emptyStore([
    {
      id: "social-receipt",
      type: "cleanup_expired_social_requests",
      timestampMs: ANCIENT,
    },
    { id: "violation", type: "rate_limit_violation", timestampMs: ANCIENT },
  ]);
  const count = await prune(store);
  record(
    "an old cleanup_expired_social_requests receipt survives even though it carries timestamp",
    count === 1 && !store.deleted.has("social-receipt"),
    `count=${count} deleted=[${[...store.deleted].join(", ")}]`
  );
}

async function respectsTheWindow(): Promise<void> {
  const store = emptyStore([
    {
      id: "young",
      type: "rate_limit_violation",
      timestampMs: NOW_MS - 89 * DAY_MS,
    },
    {
      id: "old",
      type: "rate_limit_violation",
      timestampMs: NOW_MS - 91 * DAY_MS,
    },
  ]);
  const count = await prune(store);
  record(
    "89 days old is kept, 91 days old is deleted",
    count === 1 && store.deleted.has("old") && !store.deleted.has("young"),
    `count=${count} deleted=[${[...store.deleted].join(", ")}]`
  );
}

async function pagesBeyondOneBatch(): Promise<void> {
  // 600 > the 500-row page, so the loop must re-query and commit twice.
  const store = emptyStore(
    Array.from({ length: 600 }, (_, i) => ({
      id: `v-${i}`,
      type: "rate_limit_violation",
      timestampMs: ANCIENT - i * 1000,
    }))
  );
  const count = await prune(store);
  record(
    "600 expired rows drain across two pages and two commits",
    count === 600 && store.deleted.size === 600 && store.commits === 2,
    `count=${count} deleted=${store.deleted.size} commits=${store.commits}`
  );
}

async function emptyCollectionNoop(): Promise<void> {
  const store = emptyStore([]);
  const count = await prune(store);
  record(
    "empty system_events → returns 0 and commits nothing",
    count === 0 && store.commits === 0,
    `count=${count} commits=${store.commits}`
  );
}

async function receiptKeySetIsExact(): Promise<void> {
  // Both the admin ops-log tab and `runOpsSnapshot` key on `executedAt`, and
  // the snapshot sums `totalDeleted ?? deletionAuditDeletedCount`, so a renamed
  // field is dropped with no error anywhere.
  //
  // This drives `runSystemEventsCleanup`, which is the code that actually
  // writes the row. Re-typing the same literal here would assert the literal
  // and survive any rename in production.
  const store = emptyStore([
    { id: "old", type: "rate_limit_violation", timestampMs: ANCIENT },
  ]);
  await runSystemEventsCleanup(makeFakeDb(store) as never, now as never);

  const receipt = store.written[0]?.data ?? {};
  const keys = Object.keys(receipt).sort();
  const ok =
    store.written.length === 1 &&
    keys.length === 3 &&
    keys[0] === "executedAt" &&
    keys[1] === "totalDeleted" &&
    keys[2] === "type" &&
    receipt.type === "system_events_cleanup" &&
    receipt.totalDeleted === 1;
  record(
    "the run receipt is exactly {type, totalDeleted, executedAt} and carries the count",
    ok,
    `keys=[${keys.join(", ")}] type=${String(receipt.type)} ` +
      `totalDeleted=${String(receipt.totalDeleted)}`
  );
}

async function timeoutSecondsIsDeclared(): Promise<void> {
  // The module header claims the 8-minute self-budget "is real because of this
  // line", against two siblings whose budgets are inert for lack of it.
  // `deploy-manifest.test.ts` enumerates exports for region and maxInstances
  // only, so nothing else reddens if the option is dropped — pin it here, and
  // pin that the self-budget actually fits inside it. Both sides are READ, not
  // re-typed: raising MAX_EXECUTION_TIME_MS past the declared timeout must turn
  // this red, which re-typing the arithmetic would not do.
  const endpoint = (
    cleanupOldSystemEvents as { __endpoint?: { timeoutSeconds?: unknown } }
  ).__endpoint;
  const declared = endpoint?.timeoutSeconds;
  const ok =
    declared === 540 &&
    typeof declared === "number" &&
    MAX_EXECUTION_TIME_MS < declared * 1000;
  record(
    "cleanupOldSystemEvents declares timeoutSeconds 540, and the self-budget fits inside it",
    ok,
    `__endpoint.timeoutSeconds=${String(declared)} ` +
      `MAX_EXECUTION_TIME_MS=${String(MAX_EXECUTION_TIME_MS)}`
  );
}

async function runAll(): Promise<void> {
  console.log("system_events retention: rate_limit_violation prune tests\n");
  console.log("==========================================\n");
  await keepsModerationRowsHoweverOld();
  await keepsExecutedAtReceipt();
  await keepsTimestampBearingReceipt();
  await respectsTheWindow();
  await pagesBeyondOneBatch();
  await emptyCollectionNoop();
  await receiptKeySetIsExact();
  await timeoutSecondsIsDeclared();

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
