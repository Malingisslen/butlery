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
const {
  runExportAuditLogsWithDb,
  MAX_REMOVED_FROM_GROUPS,
} = require("../exports/audit-logs");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { ADMIN_REMOVAL_AUDIT_OPERATION } = require("../groups/remove-chat-group-member");

interface SeedDoc {
  id: string;
  userId: string;
  timestampMs: number;
  operation: string;
  resourceType: string;
  resourceId?: string;
  granted: boolean;
  metadata?: Record<string, unknown>;
  /** Stored as-is instead of a Timestamp, as a client could write it. */
  rawTimestamp?: unknown;
}

interface FakeStore {
  docs: SeedDoc[];
}

type FakeTimestamp = admin.firestore.Timestamp;

// A real Timestamp: the removal section drops any row whose timestamp is not
// one, so a look-alike would make every removal fixture vanish.
function ts(ms: number): FakeTimestamp {
  return admin.firestore.Timestamp.fromMillis(ms);
}

function resolvePath(d: SeedDoc, field: string): unknown {
  const parts = field.split(".");
  let cur: unknown = d;
  for (const p of parts) {
    if (cur === null || typeof cur !== "object") return undefined;
    cur = (cur as Record<string, unknown>)[p];
  }
  return cur;
}

// Applies EVERY equality filter, dotted paths included, so a query on
// `metadata.targetUid` + `operation` is measured rather than answered empty.
function makeFakeDb(
  store: FakeStore,
  opts: { failOn?: string } = {}
): admin.firestore.Firestore {
  function buildQuery(filter: {
    equals: Array<[string, unknown]>;
    descByTs?: boolean;
    before?: number;
    limit?: number;
    select?: string[];
  }) {
    return {
      where(field: string, op: string, value: unknown) {
        if (op !== "==") throw new Error(`fake supports == only, got ${op}`);
        return buildQuery({ ...filter, equals: [...filter.equals, [field, value]] });
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
      select(...fields: string[]) {
        return buildQuery({ ...filter, select: fields });
      },
      async get() {
        if (opts.failOn && filter.equals.some(([f]) => f === opts.failOn)) {
          throw Object.assign(new Error("boom audit_logs/x for uid"), {
            code: "failed-precondition",
          });
        }
        let rows = store.docs.filter((d) =>
          filter.equals.every(([f, v]) => resolvePath(d, f) === v)
        );
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
              const full: Record<string, unknown> = {
                userId: d.userId,
                operation: d.operation,
                resourceType: d.resourceType,
                resourceId: d.resourceId,
                granted: d.granted,
                timestamp:
                  "rawTimestamp" in d ? d.rawTimestamp : ts(d.timestampMs),
                metadata: d.metadata,
              };
              if (!filter.select) return full;
              return Object.fromEntries(
                filter.select.map((f) => [f, full[f]])
              );
            },
          })),
        };
      },
    };
  }

  return {
    collection(_name: string) {
      return buildQuery({ equals: [] });
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

// BUT-1805 — the removed member's side. The fixture is the exact shape
// `stageAdminRemovalAudit` writes.
function removalRow(id: string, admin: string, target: string, ms: number): SeedDoc {
  return {
    id,
    userId: admin,
    timestampMs: ms,
    operation: ADMIN_REMOVAL_AUDIT_OPERATION,
    resourceType: "chat_groups",
    resourceId: `group-${id}`,
    granted: true,
    metadata: { actor: admin, targetUid: target, conversationId: `conv-${id}` },
  };
}

test("BUT-1805: removed member gets exactly {timestamp, groupId}, no admin", async () => {
  const store: FakeStore = { docs: [removalRow("rm1", "adminUid", "bob", 5000)] };
  const result = await runExportAuditLogsWithDb(makeFakeDb(store), "bob", {});
  const section = result.removedFromGroups;
  if (!section || !("rows" in section)) throw new Error("section missing");
  if (section.rows.length !== 1) throw new Error(`expected 1 row, got ${section.rows.length}`);
  const keys = Object.keys(section.rows[0]).sort().join(",");
  if (keys !== "groupId,timestamp") throw new Error(`keys were ${keys}`);
  if (section.rows[0].groupId !== "group-rm1") throw new Error("groupId wrong");
  const wire = JSON.stringify(section);
  for (const leak of ["adminUid", "conv-rm1"]) {
    if (wire.includes(leak)) throw new Error(`section leaks ${leak}: ${wire}`);
  }
  if (result.count !== 0) throw new Error("a removal must not appear among bob's actor rows");
});

test("BUT-1805: other operations naming the uid, and the admin's own removals, stay out", async () => {
  const store: FakeStore = {
    docs: [
      { ...removalRow("x1", "someone", "bob", 1000), operation: "account_deletion_share_scrub" },
      removalRow("x2", "bob", "carol", 2000),
    ],
  };
  const result = await runExportAuditLogsWithDb(makeFakeDb(store), "bob", {});
  const section = result.removedFromGroups;
  if (!section || !("rows" in section)) throw new Error("section missing");
  if (section.rows.length !== 0) throw new Error(`expected 0 rows, got ${JSON.stringify(section)}`);
  if (section.truncated !== false) throw new Error("truncated should be false");
  if (result.count !== 1 || result.rows[0].id !== "x2")
    throw new Error("the admin's removal stays on the actor side");
});

test("BUT-1805: a later page carries no removedFromGroups", async () => {
  const store: FakeStore = { docs: [removalRow("rm1", "adminUid", "bob", 5000)] };
  const result = await runExportAuditLogsWithDb(makeFakeDb(store), "bob", {
    before: new Date(10000).toISOString(),
  });
  if ("removedFromGroups" in result) throw new Error("section repeated on a later page");
});

test("BUT-1805: cap is exact and truncated is measured", async () => {
  const atCap = Array.from({ length: MAX_REMOVED_FROM_GROUPS }, (_, i) =>
    removalRow(`c${i}`, "adminUid", "bob", 1000 + i)
  );
  const at = await runExportAuditLogsWithDb(makeFakeDb({ docs: atCap }), "bob", {});
  if (!at.removedFromGroups || !("rows" in at.removedFromGroups)) throw new Error("missing");
  if (at.removedFromGroups.rows.length !== MAX_REMOVED_FROM_GROUPS || at.removedFromGroups.truncated)
    throw new Error("at the cap: all rows, not truncated");
  if (at.removedFromGroups.rows[0].timestamp < at.removedFromGroups.rows[1].timestamp)
    throw new Error("rows should be newest first");

  const over = [...atCap, removalRow("extra", "adminUid", "bob", 999)];
  const o = await runExportAuditLogsWithDb(makeFakeDb({ docs: over }), "bob", {});
  if (!o.removedFromGroups || !("rows" in o.removedFromGroups)) throw new Error("missing");
  if (o.removedFromGroups.rows.length !== MAX_REMOVED_FROM_GROUPS || !o.removedFromGroups.truncated)
    throw new Error("over the cap: capped and truncated");
});

test("BUT-1805: rows a client could have planted are dropped", async () => {
  const store: FakeStore = {
    docs: [
      { ...removalRow("p1", "stranger", "bob", 1000), rawTimestamp: "you were removed" },
      { ...removalRow("p2", "stranger", "bob", 2000), resourceType: "recipe" },
      { ...removalRow("p3", "stranger", "bob", 3000), resourceId: "see admin/x for details" },
      removalRow("real", "adminUid", "bob", 4000),
    ],
  };
  const result = await runExportAuditLogsWithDb(makeFakeDb(store), "bob", {});
  const section = result.removedFromGroups;
  if (!section || !("rows" in section)) throw new Error("section missing");
  const wire = JSON.stringify(section.rows);
  if (section.rows.length !== 2) throw new Error(`expected 2 rows, got ${wire}`);
  if (wire.includes("you were removed")) throw new Error("string timestamp passed through");
  if (wire.includes("see admin/x")) throw new Error("free-text group id passed through");
  if (section.rows[1].groupId !== null) throw new Error("invalid group id should be null");
});

test("BUT-1805: a failed removal query keeps the actor rows", async () => {
  const store: FakeStore = {
    docs: [
      { id: "a", userId: "bob", timestampMs: 1000, operation: "read", resourceType: "r", granted: true },
      removalRow("rm1", "adminUid", "bob", 5000),
    ],
  };
  const result = await runExportAuditLogsWithDb(
    makeFakeDb(store, { failOn: "metadata.targetUid" }),
    "bob",
    {}
  );
  if (result.count !== 1) throw new Error("actor rows lost");
  const section = result.removedFromGroups;
  if (!section || !("error_code" in section) || section.error_code !== "removed-from-groups-failed")
    throw new Error(`expected error_code, got ${JSON.stringify(section)}`);
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
