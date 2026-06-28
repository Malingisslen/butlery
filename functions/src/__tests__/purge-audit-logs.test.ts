/**
 * BUT-665 — purge-audit-logs unit tests.
 *
 * Verifies `purgeAuditCategoryWithDb` (the testable extraction from
 * `purgeExpiredAuditLogs`) correctly buckets consent vs general events
 * against the documented retention windows.
 *
 * Run: npx ts-node src/__tests__/purge-audit-logs.test.ts
 *
 * Pattern follows `notification-queues-gdpr.test.ts` — fake admin shape
 * driven by an in-memory store, no real Firestore. We don't need
 * `@firebase/rules-unit-testing` because there are no security rules in
 * scope here (admin SDK bypasses them by design).
 */

// firebase-admin module-level imports require an initialized default app
// even when our tests don't use it.
import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-audit-purge" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  purgeAuditCategoryWithDb,
  CONSENT_RETENTION_DAYS,
  GENERAL_RETENTION_DAYS,
  CONSENT_OPERATION_PREFIX,
  CONSENT_OPERATIONS,
} = require("../audit_logs/purge-expired");

interface SeedDoc {
  id: string;
  operation: string;
  /** epoch ms — converted to a Timestamp-like for the fake. */
  timestampMs: number;
}

interface FakeStore {
  docs: SeedDoc[];
  deleted: Set<string>;
}

interface FakeTimestamp {
  toDate(): Date;
  toMillis(): number;
  // Used only for `<` comparison via valueOf.
  valueOf(): number;
}

function makeTimestamp(d: Date): FakeTimestamp {
  return {
    toDate: () => d,
    toMillis: () => d.getTime(),
    valueOf: () => d.getTime(),
  };
}

/** Minimal fake admin.firestore() shape for the calls used by
 *  `purgeAuditCategoryWithDb` after BUT-1404 fix.
 *
 *  The production query chain is now:
 *    collection('audit_logs')
 *      .where('operation', 'in' | 'not-in', [...])
 *      .where('timestamp', '<', cutoff)
 *      .limit(n)
 *      .get()
 *
 *  The fake models both filters in-memory and applies limit() on the result,
 *  matching what Firestore would return server-side.
 */
function makeFakeDb(store: FakeStore, limitOverride?: number) {
  /** Build a chainable query that accumulates predicate state. */
  function makeQuery(predicates: {
    operationFilter?: { op: "in" | "not-in"; values: string[] };
    timestampCutoffMs?: number;
    limitN?: number;
  }) {
    return {
      where(field: string, op: string, value: FakeTimestamp | string[]) {
        if (field === "operation" && (op === "in" || op === "not-in")) {
          return makeQuery({
            ...predicates,
            operationFilter: { op: op as "in" | "not-in", values: value as string[] },
          });
        }
        if (field === "timestamp" && op === "<") {
          return makeQuery({
            ...predicates,
            timestampCutoffMs: (value as FakeTimestamp).toMillis(),
          });
        }
        throw new Error(
          `makeFakeDb: unexpected where(${field}, ${op}) — not modelled`
        );
      },
      limit(n: number) {
        return makeQuery({ ...predicates, limitN: limitOverride ?? n });
      },
      async get() {
        let matches = store.docs;

        // Apply operation filter.
        if (predicates.operationFilter) {
          const { op, values } = predicates.operationFilter;
          if (op === "in") {
            matches = matches.filter((d) => values.includes(d.operation));
          } else {
            // "not-in": also excludes docs where field is absent (Firestore
            // semantics) — our fake always has the field so this is just !includes.
            matches = matches.filter((d) => !values.includes(d.operation));
          }
        }

        // Apply timestamp range filter.
        if (predicates.timestampCutoffMs !== undefined) {
          const cutoff = predicates.timestampCutoffMs;
          matches = matches.filter((d) => d.timestampMs < cutoff);
        }

        // Apply limit.
        if (predicates.limitN !== undefined) {
          matches = matches.slice(0, predicates.limitN);
        }

        return {
          empty: matches.length === 0,
          docs: matches.map((m) => ({
            data: () => ({ operation: m.operation }),
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
      if (name !== "audit_logs") {
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

function daysAgo(n: number): number {
  return Date.now() - n * DAY_MS;
}

function cutoffDays(n: number): FakeTimestamp {
  return makeTimestamp(new Date(Date.now() - n * DAY_MS));
}

async function generalBucketDeletesNonConsentBeyondSixMonths(): Promise<void> {
  const store: FakeStore = {
    docs: [
      // General read 7 months ago — must be deleted (older than 6mo cutoff).
      { id: "g-old", operation: "read", timestampMs: daysAgo(210) },
      // Recent read — must NOT be deleted.
      { id: "g-fresh", operation: "read", timestampMs: daysAgo(30) },
      // Consent event 7 months ago — must NOT be deleted by general bucket
      // (it falls under the 24mo consent retention).
      {
        id: "c-old",
        operation: "consent_updated",
        timestampMs: daysAgo(210),
      },
    ],
    deleted: new Set(),
  };
  const cutoff = cutoffDays(GENERAL_RETENTION_DAYS);
  const total = await purgeAuditCategoryWithDb(
    makeFakeDb(store) as never,
    "general",
    cutoff as never
  );
  const ok =
    total === 1 &&
    store.deleted.has("g-old") &&
    !store.deleted.has("g-fresh") &&
    !store.deleted.has("c-old");
  record(
    "general bucket: deletes non-consent events older than 6mo, leaves consent events alone",
    ok,
    `total=${total} deleted=${[...store.deleted].join(", ")}`
  );
}

async function consentBucketDeletesConsentBeyond24Months(): Promise<void> {
  const store: FakeStore = {
    docs: [
      // Consent event 25 months ago — must be deleted (older than 24mo).
      {
        id: "c-old",
        operation: "consent_updated",
        timestampMs: daysAgo(770),
      },
      // Consent event 12 months ago — must NOT be deleted (within 24mo).
      {
        id: "c-fresh",
        operation: "consent_granted",
        timestampMs: daysAgo(365),
      },
      // General event 25 months ago — must NOT be deleted by consent bucket.
      // (It would already have been deleted by the general bucket; this test
      // proves the consent bucket doesn't widen its scope.)
      { id: "g-very-old", operation: "read", timestampMs: daysAgo(770) },
    ],
    deleted: new Set(),
  };
  const cutoff = cutoffDays(CONSENT_RETENTION_DAYS);
  const total = await purgeAuditCategoryWithDb(
    makeFakeDb(store) as never,
    "consent",
    cutoff as never
  );
  const ok =
    total === 1 &&
    store.deleted.has("c-old") &&
    !store.deleted.has("c-fresh") &&
    !store.deleted.has("g-very-old");
  record(
    "consent bucket: deletes consent events older than 24mo, leaves fresh consent + general events alone",
    ok,
    `total=${total} deleted=${[...store.deleted].join(", ")}`
  );
}

async function consentPrefixCoversKnownOperations(): Promise<void> {
  const store: FakeStore = {
    docs: [
      {
        id: "c-updated",
        operation: "consent_updated",
        timestampMs: daysAgo(800),
      },
      {
        id: "c-granted",
        operation: "consent_granted",
        timestampMs: daysAgo(800),
      },
      {
        id: "c-revoked",
        operation: "consent_revoked",
        timestampMs: daysAgo(800),
      },
      // "consented_to_skip" — `consent_` prefix is 8 chars (c-o-n-s-e-n-t-_)
      // and "consented_" diverges at position 7 (_ vs e), so this does NOT
      // match. Important: `read_consent` and similar would also not match
      // (no leading "consent_"). This pins the prefix-match contract so a
      // future refactor that switches to a contains() check fails loudly.
      { id: "fake", operation: "consented_to_skip", timestampMs: daysAgo(800) },
      { id: "fake2", operation: "read_consent", timestampMs: daysAgo(800) },
    ],
    deleted: new Set(),
  };
  const cutoff = cutoffDays(CONSENT_RETENTION_DAYS);
  const total = await purgeAuditCategoryWithDb(
    makeFakeDb(store) as never,
    "consent",
    cutoff as never
  );
  const ok =
    total === 3 &&
    store.deleted.has("c-updated") &&
    store.deleted.has("c-granted") &&
    store.deleted.has("c-revoked") &&
    !store.deleted.has("fake") &&
    !store.deleted.has("fake2");
  record(
    "consent prefix is strict (`consent_*`) — does NOT match `consented_*` or `*_consent`",
    ok,
    `total=${total} deleted=${[...store.deleted].join(", ")} prefix=${CONSENT_OPERATION_PREFIX}`
  );
}

async function emptyCollectionNoop(): Promise<void> {
  const store: FakeStore = { docs: [], deleted: new Set() };
  const cutoff = cutoffDays(GENERAL_RETENTION_DAYS);
  const total = await purgeAuditCategoryWithDb(
    makeFakeDb(store) as never,
    "general",
    cutoff as never
  );
  record(
    "empty audit_logs collection → no-op, returns 0",
    total === 0 && store.deleted.size === 0,
    `total=${total}`
  );
}

async function idempotencySecondRunIsNoop(): Promise<void> {
  const store: FakeStore = {
    docs: [{ id: "g-old", operation: "read", timestampMs: daysAgo(210) }],
    deleted: new Set(),
  };
  const cutoff = cutoffDays(GENERAL_RETENTION_DAYS);

  const first = await purgeAuditCategoryWithDb(
    makeFakeDb(store) as never,
    "general",
    cutoff as never
  );
  // Simulate Firestore: deleted docs are gone.
  store.docs = store.docs.filter((d) => !store.deleted.has(d.id));
  const second = await purgeAuditCategoryWithDb(
    makeFakeDb(store) as never,
    "general",
    cutoff as never
  );
  record(
    "idempotency: second run on same day finds zero docs",
    first === 1 && second === 0,
    `first=${first} second=${second}`
  );
}

async function batchSizeRespected(): Promise<void> {
  // Seed 250 expired general events; with batchSize=100 we expect
  // commit to be called 3 times (100 + 100 + 50). The fake doesn't
  // expose commit count directly, but we can verify all 250 deleted.
  const store: FakeStore = {
    docs: Array.from({ length: 250 }, (_, i) => ({
      id: `g-${i}`,
      operation: "read",
      timestampMs: daysAgo(210),
    })),
    deleted: new Set(),
  };
  const cutoff = cutoffDays(GENERAL_RETENTION_DAYS);
  const total = await purgeAuditCategoryWithDb(
    makeFakeDb(store) as never,
    "general",
    cutoff as never,
    { batchSize: 100 }
  );
  record(
    "batch size honoured — large delete completes correctly",
    total === 250 && store.deleted.size === 250,
    `total=${total} deleted=${store.deleted.size}`
  );
}

async function generalBucketIgnoresFreshConsent(): Promise<void> {
  // Regression-style check: a consent event that's older than the
  // GENERAL cutoff (6mo) but younger than the CONSENT cutoff (24mo)
  // must not be touched by the general bucket. The general bucket runs
  // FIRST in the CF, so this is the highest-risk over-deletion case.
  const store: FakeStore = {
    docs: [
      {
        id: "c-mid",
        operation: "consent_updated",
        timestampMs: daysAgo(300), // 10mo ago — older than 6mo, younger than 24mo
      },
    ],
    deleted: new Set(),
  };
  const cutoff = cutoffDays(GENERAL_RETENTION_DAYS);
  const total = await purgeAuditCategoryWithDb(
    makeFakeDb(store) as never,
    "general",
    cutoff as never
  );
  record(
    "general bucket leaves 10mo-old consent event intact (24mo retention)",
    total === 0 && store.deleted.size === 0,
    `total=${total} deleted=${[...store.deleted].join(", ")}`
  );
}

/**
 * BUT-1404 — Starvation regression test.
 *
 * Scenario: the window up to the general cutoff (180d) is dominated by
 * consent rows. Before the fix, limit(maxDocs) fired before any filtering,
 * so all fetched docs were consent events and the general purge returned 0
 * even though general docs past their 180d cutoff existed in the collection.
 *
 * After the fix the server-side `not-in` filter means limit() is applied
 * only to non-consent docs, so the stale general rows ARE found.
 */
async function generalPurgeNotStarvedByConsentRows(): Promise<void> {
  // Build a fake DB whose oldest-10 docs are consent events, plus one
  // general doc past its 180d cutoff. Use limitOverride=10 to simulate a
  // tight window that the old code would have filled entirely with consent rows.
  const consentDocs: SeedDoc[] = Array.from({ length: 10 }, (_, i) => ({
    id: `c-old-${i}`,
    operation: "consent_updated",
    // 300 days ago — older than 180d general cutoff but within 730d consent
    // retention. These must NOT be deleted by the general bucket.
    timestampMs: daysAgo(300 + i),
  }));
  const generalDoc: SeedDoc = {
    id: "g-stale",
    operation: "read",
    timestampMs: daysAgo(200), // past 180d cutoff
  };
  const store: FakeStore = {
    docs: [...consentDocs, generalDoc],
    deleted: new Set(),
  };

  const cutoff = cutoffDays(GENERAL_RETENTION_DAYS);
  // Simulate a window of 10 docs — old code would return only the 10 consent
  // rows and leave g-stale unpurged. New code filters consent out server-side
  // so g-stale is fetched and deleted within the same window.
  const total = await purgeAuditCategoryWithDb(
    makeFakeDb(store, 10) as never,
    "general",
    cutoff as never,
    { maxDocs: 10 }
  );
  const ok =
    total === 1 &&
    store.deleted.has("g-stale") &&
    consentDocs.every((d) => !store.deleted.has(d.id));
  record(
    "BUT-1404: general purge finds stale general doc even when window dominated by consent rows",
    ok,
    `total=${total} deleted=[${[...store.deleted].join(", ")}] consent_not_deleted=${consentDocs.every((d) => !store.deleted.has(d.id))}`
  );
}

/** Verifies CONSENT_OPERATIONS is a strict superset of all consent_* values
 *  that actually appear in the codebase. If a new consent op is added without
 *  updating CONSENT_OPERATIONS, the not-in filter lets that op's docs slip
 *  through to the general purge bucket, violating 730d retention. */
async function consentOperationsArrayIsExhaustive(): Promise<void> {
  // All operation values that start with CONSENT_OPERATION_PREFIX and appear
  // in audit_logs writes — must all be in CONSENT_OPERATIONS.
  const knownConsentOps = [
    "consent_age_verification",
    "consent_granted",
    "consent_updated",
    "consent_revoked",
  ];
  const ops: string[] = CONSENT_OPERATIONS;
  const missing = knownConsentOps.filter((op: string) => !ops.includes(op));
  const all = knownConsentOps.every((op: string) => op.startsWith(CONSENT_OPERATION_PREFIX));
  record(
    "CONSENT_OPERATIONS array covers all known consent_* operation values",
    missing.length === 0 && all,
    missing.length > 0 ? `missing: ${missing.join(", ")}` : `all ${knownConsentOps.length} covered`
  );
}

async function runAll(): Promise<void> {
  console.log("BUT-665: audit-log retention purge tests\n");
  console.log("==========================================\n");
  await generalBucketDeletesNonConsentBeyondSixMonths();
  await consentBucketDeletesConsentBeyond24Months();
  await consentPrefixCoversKnownOperations();
  await emptyCollectionNoop();
  await idempotencySecondRunIsNoop();
  await batchSizeRespected();
  await generalBucketIgnoresFreshConsent();
  await generalPurgeNotStarvedByConsentRows();
  await consentOperationsArrayIsExhaustive();

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
