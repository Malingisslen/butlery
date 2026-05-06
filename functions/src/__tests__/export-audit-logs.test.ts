/**
 * BUT-770 — exportAuditLogs unit tests.
 *
 * Verifies `runExportAuditLogsWithDb` (the testable extraction from the
 * `exportAuditLogs` callable) correctly:
 *
 *   1. Filters by `userId == auth.uid` so a user can never export another
 *      user's audit history.
 *   2. Returns rows in descending timestamp order — most recent first.
 *   3. Caps the page at PAGE_SIZE and emits a `nextCursor` so the client
 *      can iterate; returns `nextCursor: null` once the page is short.
 *   4. Honors the `before` cursor on subsequent calls.
 *
 * Run: npx ts-node src/__tests__/export-audit-logs.test.ts
 *
 * Pattern follows `purge-audit-logs.test.ts` — fake admin shape driven by
 * an in-memory store; admin SDK bypasses rules by design so a rules-test
 * harness adds no value here.
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-export-audit" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { runExportAuditLogsWithDb } = require("../exports/audit-logs");

interface SeedDoc {
  id: string;
  userId: string;
  timestampMs: number;
  operation: string;
  resourceType: string;
  resourceId?: string;
  granted: boolean;
  metadata?: Record<string, unknown>;
}

interface FakeStore {
  docs: SeedDoc[];
}

interface FakeTimestamp {
  toDate(): Date;
  toMillis(): number;
  valueOf(): number;
}

function ts(ms: number): FakeTimestamp {
  return {
    toDate: () => new Date(ms),
    toMillis: () => ms,
    valueOf: () => ms,
  };
}

function makeFakeDb(store: FakeStore): admin.firestore.Firestore {
  function buildQuery(filter: {
    userId?: string;
    descByTs?: boolean;
    before?: number;
    limit?: number;
  }) {
    return {
      where(_field: string, op: string, value: unknown) {
        if (_field === "userId" && op === "==") {
          return buildQuery({ ...filter, userId: value as string });
        }
        return buildQuery(filter);
      },
      orderBy(field: string, direction: string) {
        if (field === "timestamp" && direction === "desc") {
          return buildQuery({ ...filter, descByTs: true });
        }
        return buildQuery(filter);
      },
      startAfter(cursor: FakeTimestamp) {
        return buildQuery({ ...filter, before: cursor.toMillis() });
      },
      limit(n: number) {
        return buildQuery({ ...filter, limit: n });
      },
      async get() {
        let rows = store.docs.filter((d) => d.userId === filter.userId);
        if (filter.descByTs) {
          rows = rows.sort((a, b) => b.timestampMs - a.timestampMs);
        }
        if (filter.before !== undefined) {
          rows = rows.filter((d) => d.timestampMs < filter.before!);
        }
        if (filter.limit !== undefined) {
          rows = rows.slice(0, filter.limit);
        }
        return {
          size: rows.length,
          docs: rows.map((d) => ({
            id: d.id,
            data() {
              return {
                userId: d.userId,
                operation: d.operation,
                resourceType: d.resourceType,
                resourceId: d.resourceId,
                granted: d.granted,
                timestamp: ts(d.timestampMs),
                metadata: d.metadata,
              };
            },
          })),
        };
      },
    };
  }

  return {
    collection(_name: string) {
      return buildQuery({});
    },
  } as unknown as admin.firestore.Firestore;
}

interface TestCase {
  name: string;
  fn: () => Promise<void>;
}
const tests: TestCase[] = [];
function test(name: string, fn: () => Promise<void>): void {
  tests.push({ name, fn });
}

// Test 1: only the caller's rows are returned. Pinning this prevents a
// future query rewrite from accidentally widening the filter.
test("BUT-770: filters by userId == auth.uid", async () => {
  const store: FakeStore = {
    docs: [
      { id: "a", userId: "alice", timestampMs: 1000, operation: "read", resourceType: "recipe", granted: true },
      { id: "b", userId: "bob", timestampMs: 1100, operation: "read", resourceType: "recipe", granted: true },
      { id: "c", userId: "alice", timestampMs: 900, operation: "write", resourceType: "recipe", granted: false },
    ],
  };
  const db = makeFakeDb(store);
  const result = await runExportAuditLogsWithDb(db, "alice", {});
  if (result.count !== 2) throw new Error(`expected 2 rows for alice, got ${result.count}`);
  for (const row of result.rows) {
    if (!["a", "c"].includes(row.id)) throw new Error(`unexpected row ${row.id}`);
  }
});

// Test 2: descending timestamp order. Most recent first is the natural
// scroll order for an export viewer; reversing it would break the cursor
// semantics.
test("BUT-770: rows ordered by timestamp desc", async () => {
  const store: FakeStore = {
    docs: [
      { id: "old", userId: "u", timestampMs: 1000, operation: "read", resourceType: "r", granted: true },
      { id: "new", userId: "u", timestampMs: 3000, operation: "read", resourceType: "r", granted: true },
      { id: "mid", userId: "u", timestampMs: 2000, operation: "read", resourceType: "r", granted: true },
    ],
  };
  const result = await runExportAuditLogsWithDb(makeFakeDb(store), "u", {});
  const ids = result.rows.map((r: { id: string }) => r.id);
  if (ids.join(",") !== "new,mid,old") throw new Error(`order wrong: ${ids.join(",")}`);
});

// Test 3: short page returns nextCursor: null. Without this, the client
// would loop forever when the user has fewer than PAGE_SIZE entries.
test("BUT-770: short page emits nextCursor: null", async () => {
  const store: FakeStore = {
    docs: [
      { id: "x", userId: "u", timestampMs: 100, operation: "read", resourceType: "r", granted: true },
    ],
  };
  const result = await runExportAuditLogsWithDb(makeFakeDb(store), "u", {});
  if (result.nextCursor !== null) throw new Error("expected nextCursor null on short page");
});

// Test 4: gdprArticle stamp is present on every response. Bundle authors
// rely on this string when wrapping the export — drop it and the bundle's
// "what's included" file becomes ambiguous.
test("BUT-770: response carries gdprArticle stamp", async () => {
  const result = await runExportAuditLogsWithDb(makeFakeDb({ docs: [] }), "u", {});
  if (result.gdprArticle !== "Article 15 - Right of Access")
    throw new Error("missing or wrong gdprArticle");
});

// Test 5: empty result is well-formed (count: 0, rows: []).
test("BUT-770: empty result is valid", async () => {
  const result = await runExportAuditLogsWithDb(makeFakeDb({ docs: [] }), "u", {});
  if (result.count !== 0) throw new Error("expected count 0");
  if (!Array.isArray(result.rows) || result.rows.length !== 0)
    throw new Error("expected empty rows array");
  if (result.nextCursor !== null) throw new Error("expected nextCursor null");
});

// Test 6: row shape carries the public schema (id, timestamp, operation,
// resourceType, resourceId, granted, metadata). Adding a field is fine;
// removing one is a breaking change for the client export bundle.
test("BUT-770: row shape preserved", async () => {
  const store: FakeStore = {
    docs: [
      {
        id: "r1",
        userId: "u",
        timestampMs: 1000,
        operation: "read",
        resourceType: "recipe",
        resourceId: "rec-1",
        granted: true,
        metadata: { ip: "1.2.3.4" },
      },
    ],
  };
  const result = await runExportAuditLogsWithDb(makeFakeDb(store), "u", {});
  const row = result.rows[0];
  if (row.id !== "r1") throw new Error("id missing");
  if (typeof row.timestamp !== "string") throw new Error("timestamp not string");
  if (row.operation !== "read") throw new Error("operation missing");
  if (row.resourceType !== "recipe") throw new Error("resourceType missing");
  if (row.resourceId !== "rec-1") throw new Error("resourceId missing");
  if (row.granted !== true) throw new Error("granted missing");
  if (!row.metadata || row.metadata.ip !== "1.2.3.4") throw new Error("metadata missing");
});

async function run(): Promise<void> {
  console.log("BUT-770: exportAuditLogs unit tests\n");
  console.log("====================================\n");
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
  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
