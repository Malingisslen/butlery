/**
 * BUT-788 — `requestAccountDeletion` orchestrator tests.
 *
 * Covers the contract of `runAccountDeletionWithDeps`:
 *
 *   1. End-to-end shape — every cascade step name appears in the result
 *      envelope; orchestrator calls `auth.deleteUser` LAST and `storage.
 *      bucket().deleteFiles` for the user's prefix.
 *   2. Auth-delete failure — surfaces as `failedCollections: [..., "auth_
 *      deletion"]` and `success: false` without aborting the audit log.
 *   3. Audit-log shape — preserves the `deletion_audit_logs` schema the
 *      prior client implementation wrote, including the 180-day `expireAt`
 *      and `gdprCompliant` derived flag.
 *   4. SHA-256 email hash — never plaintext in the audit row.
 *
 * Per-step cascade semantics (recipes-cascade, group-menu scrub, sharedTo
 * scrub, etc.) ARE NOT covered here — those need a real Firestore emulator
 * to exercise faithfully. Filed as a follow-up.
 *
 * Run: npx ts-node src/__tests__/request-account-deletion.test.ts
 */

import * as admin from "firebase-admin";
import { createHash } from "crypto";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-acct-deletion" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { runAccountDeletionWithDeps } = require("../account/request-account-deletion");

/** Hand-rolled fake collection — every method returns an empty snapshot so
 * the cascade walks the full step list without doing real I/O. Records the
 * write to `deletion_audit_logs` so we can assert its shape. */
interface RecordedAuditRow {
  userId: string;
  emailHash: string;
  reason: string;
  deletedCollections: string[];
  failedCollections: string[];
  gdprCompliant: boolean;
  expireAt: unknown;
  deletionTimestamp: unknown;
}

interface FakeDbState {
  auditRows: RecordedAuditRow[];
}

function emptySnapshot(): {
  empty: boolean;
  size: number;
  docs: unknown[];
  data(): { count: number };
} {
  return { empty: true, size: 0, docs: [], data: () => ({ count: 0 }) };
}

function makeBatch() {
  return {
    delete(_ref: unknown) {
      // no-op
    },
    update(_ref: unknown, _data: unknown) {
      // no-op
    },
    set(_ref: unknown, _data: unknown) {
      // no-op
    },
    async commit() {
      // no-op
    },
  };
}

function makeFakeDb(state: FakeDbState): admin.firestore.Firestore {
  function makeCollection(name: string): unknown {
    const query: {
      get(): Promise<ReturnType<typeof emptySnapshot>>;
      where(): typeof query;
      limit(): typeof query;
      orderBy(): typeof query;
      startAt(): typeof query;
      endAt(): typeof query;
      count(): { get(): Promise<{ data(): { count: number } }> };
      listDocuments(): Promise<unknown[]>;
      doc(id: string): unknown;
      add(data: RecordedAuditRow): Promise<{ id: string }>;
    } = {
      async get() {
        return emptySnapshot();
      },
      where() {
        return query;
      },
      // BUT-1838/BUT-1801 gave the capped sweeps a `.limit(CAP + 1)` so they can
      // DECLINE an implausible row count instead of truncating one. Without this
      // method the `chat_groups` and `messages` steps threw
      // `…where(...).limit is not a function`, and the orchestration test read
      // that as two failed GDPR erasure steps — a cascade failure that has
      // nothing to do with orchestration, exactly as the `listDocuments` note
      // below describes. Returning `query` keeps the chain resolving to `get()`
      // — the real Admin SDK's `Query.limit()` is chainable, so this models it
      // honestly rather than papering over a production defect.
      //
      // Be clear about what this buys: the fake holds nothing, so both steps now
      // sweep an EMPTY result and neither the cap branch nor the delete branch
      // is taken. All this suite proves is that the orchestrator invokes them
      // and neither throws — which is its job. Their real behaviour, including
      // the decline above the cap, is proven in
      // `account-deletion-cascade.test.ts`
      // (`scenario_implausibleChatGroupCountDeclines`,
      // `scenario_implausiblePollVoteCountDeclines`), not here.
      limit() {
        return query;
      },
      // BUT-1390 added a documentId() range chain to the subcollection
      // cascade (orderBy(documentId()).startAt(...).endAt(...)); the fake
      // must return itself for each so the chain resolves to `get()`.
      orderBy() {
        return query;
      },
      startAt() {
        return query;
      },
      endAt() {
        return query;
      },
      count() {
        return {
          async get() {
            return { data: () => ({ count: 0 }) };
          },
        };
      },
      // BUT-1697: the shopping-list sweep and its residual probe use
      // `listDocuments()`, not `get()` — only that call can see a MISSING
      // parent document that still owns an `items` subcollection. This fake
      // holds nothing, so an empty list is the honest answer; the point is that
      // the method EXISTS, otherwise the step throws and the orchestration test
      // reports a cascade failure that has nothing to do with orchestration.
      async listDocuments(): Promise<unknown[]> {
        return [];
      },
      doc(_id: string): unknown {
        return makeDoc(name);
      },
      async add(data: RecordedAuditRow) {
        if (name === "deletion_audit_logs") {
          state.auditRows.push(data);
        }
        return { id: `synthetic-${state.auditRows.length}` };
      },
    };
    return query;
  }

  function makeDoc(_collectionName: string): unknown {
    const docApi = {
      async get() {
        return emptySnapshot();
      },
      async delete() {
        // no-op
      },
      collection(sub: string) {
        return makeCollection(sub);
      },
      // BUT-1957: `probeResidualData` now ENUMERATES the `users/{uid}`
      // subcollections instead of naming them. That enumeration's catch fails
      // CLOSED, so a fake without this method makes every run report
      // `residual_data_detected` — this suite read it as a failed GDPR step and
      // the orchestration test went red for a reason that has nothing to do
      // with orchestration, the same shape as the `listDocuments` and `limit`
      // notes above.
      //
      // Empty is the honest answer here (this fake holds nothing), and it means
      // this suite proves only that the call EXISTS. What the enumeration
      // actually reports, and that its two exclusions are load-bearing, is
      // proven against the in-memory store in `account-deletion-cascade.test.ts`.
      async listCollections(): Promise<unknown[]> {
        return [];
      },
    };
    return docApi;
  }

  return {
    collection(name: string) {
      return makeCollection(name);
    },
    collectionGroup(_name: string) {
      // Always empty — cascade steps just walk past.
      //
      // BUT-1822: `limit()` and `count()` are here for the same reason
      // `listDocuments()` is above — the roster sweep reads `.limit(MAX + 1)`
      // and its residual probe reads `.count()`, and a missing method makes the
      // step throw, which this suite would report as an ORCHESTRATION failure
      // that has nothing to do with orchestration.
      const query = {
        get: async () => emptySnapshot(),
        where() {
          return query;
        },
        limit() {
          return query;
        },
        count() {
          return {
            async get() {
              return { data: () => ({ count: 0 }) };
            },
          };
        },
      };
      return query;
    },
    batch() {
      return makeBatch();
    },
    // BUT-1697: the shared shopping-list scrub runs one transaction per list.
    // Both shared queries return empty here, so the loop never spins — but a
    // fake missing the method turns any future seeded fixture into a TypeError
    // that reads as an orchestration failure rather than a fixture gap.
    async runTransaction<T>(
      fn: (tx: unknown) => Promise<T>,
    ): Promise<T> {
      return fn({
        async get() {
          return { exists: false, data: () => undefined };
        },
        update() {},
        delete() {},
      });
    },
  } as unknown as admin.firestore.Firestore;
}

interface FakeAuthCalls {
  deleteUserUid: string | null;
  throwOnDelete: boolean;
}

function makeFakeAuth(calls: FakeAuthCalls): admin.auth.Auth {
  return {
    async deleteUser(uid: string) {
      calls.deleteUserUid = uid;
      if (calls.throwOnDelete) {
        throw new Error("auth/user-not-found");
      }
    },
  } as unknown as admin.auth.Auth;
}

interface FakeStorageCalls {
  deletePrefixes: string[];
}

function makeFakeStorage(calls: FakeStorageCalls): admin.storage.Storage {
  return {
    bucket() {
      return {
        async deleteFiles(opts: { prefix: string }) {
          calls.deletePrefixes.push(opts.prefix);
        },
      };
    },
  } as unknown as admin.storage.Storage;
}

interface TestCase {
  name: string;
  fn: () => Promise<void>;
}

const tests: TestCase[] = [];
function test(name: string, fn: () => Promise<void>): void {
  tests.push({ name, fn });
}

/**
 * Smoke: every cascade step name shows up in `deletedCollections`, the
 * audit log is written, and `auth.deleteUser` is called with the right uid.
 * The empty-snapshot fake means every step trivially succeeds — that's
 * fine for an orchestration contract test, but means it does NOT prove the
 * per-step Firestore behavior. See follow-up for per-step coverage.
 */
test("BUT-788: full cascade reports every step + writes audit + calls auth.deleteUser", async () => {
  const state: FakeDbState = { auditRows: [] };
  const db = makeFakeDb(state);
  const authCalls: FakeAuthCalls = { deleteUserUid: null, throwOnDelete: false };
  const auth = makeFakeAuth(authCalls);
  const storageCalls: FakeStorageCalls = { deletePrefixes: [] };
  const storage = makeFakeStorage(storageCalls);

  const result = await runAccountDeletionWithDeps(
    { db, auth, storage },
    "uid-alice",
    "alice@example.com",
    "user_request",
  );

  if (!result.success) {
    // `result.errors` and not just the collection names: a failing step here is
    // a GDPR erasure step, and "chat_groups failed" alone sends the next reader
    // to read the whole cascade rather than the one line that threw.
    throw new Error(
      `expected success, got failed: ${JSON.stringify(result.failedCollections)}`
        + ` — errors: ${JSON.stringify(result.errors)}`,
    );
  }
  if (authCalls.deleteUserUid !== "uid-alice") {
    throw new Error(`auth.deleteUser uid mismatch: ${authCalls.deleteUserUid}`);
  }
  if (!storageCalls.deletePrefixes.includes("users/uid-alice/")) {
    throw new Error(`storage prefix not deleted: ${JSON.stringify(storageCalls.deletePrefixes)}`);
  }

  // Spot-check a few expected step names — full list is in the source.
  //
  // `feature_retention` and `retention_analytics` are named because deleting
  // either registration line left every one of their own unit tests green —
  // those tests `require()` the deleter directly, so nothing else notices when
  // the cascade stops calling it (BUT-1800).
  //
  // `notification_effectiveness` is named for the same reason (BUT-1956), and
  // there is a second one: `notification_analytics` sits directly above it in
  // the tier list and reads like it already covers this, so a future edit that
  // removes the line as a duplicate would look like tidying.
  const expected = [
    "recipes",
    "menus",
    "shopping_lists",
    "personal_tags",
    "feature_retention",
    "retention_analytics",
    "notification_effectiveness",
    // BUT-1917. The same failure this list exists for: removing its tier
    // entry leaves the whole cascade suite green while the erasure stops
    // running — and the emulator lane seeds no block row, so its
    // `failedCollections` assertion stays green too.
    "blocks",
    "messages",
    "shared_content",
    "comments_ratings",
    "pings",
    "fcm_tokens",
    "notifications",
    "storage_files",
    "preferences",
    "consent_records",
    "user_subcollections",
    "profile",
  ];
  for (const step of expected) {
    if (!result.deletedCollections.includes(step)) {
      throw new Error(`expected step '${step}' in deletedCollections, got ${JSON.stringify(result.deletedCollections)}`);
    }
  }
});

/**
 * Audit-log row shape. ProfileViewModel + the GDPR export bundle read
 * `deletion_audit_logs` by field name; a silent rename would break both.
 */
test("BUT-788: audit log row preserves the deletion_audit_logs schema", async () => {
  const state: FakeDbState = { auditRows: [] };
  const result = await runAccountDeletionWithDeps(
    {
      db: makeFakeDb(state),
      auth: makeFakeAuth({ deleteUserUid: null, throwOnDelete: false }),
      storage: makeFakeStorage({ deletePrefixes: [] }),
    },
    "uid-bob",
    "bob@example.com",
    "I changed my mind.",
  );

  if (state.auditRows.length !== 1) {
    throw new Error(`expected 1 audit row, got ${state.auditRows.length}`);
  }
  const row = state.auditRows[0];
  if (row.userId !== "uid-bob") throw new Error("audit userId wrong");
  const expectedHash = createHash("sha256").update("bob@example.com").digest("hex");
  if (row.emailHash !== expectedHash) {
    throw new Error("emailHash not SHA-256 of caller email (PII leak risk)");
  }
  if (row.reason !== "I changed my mind.") {
    throw new Error("reason not preserved in audit row");
  }
  if (typeof row.gdprCompliant !== "boolean") {
    throw new Error("gdprCompliant must be a boolean");
  }
  if (!Array.isArray(row.deletedCollections)) {
    throw new Error("deletedCollections must be an array");
  }
  if (result.auditLogId === null || typeof result.auditLogId !== "string") {
    throw new Error("auditLogId must be returned in the response");
  }
});

/**
 * If `auth.deleteUser` throws (e.g., user already deleted out-of-band), the
 * orchestrator records `auth_deletion` in failedCollections, marks success
 * false, but STILL writes the audit log. The audit row remains the trail
 * the GDPR officer reads if anything later needs investigation.
 */
test("BUT-788: auth.deleteUser failure → failedCollections + success=false, audit still written", async () => {
  const state: FakeDbState = { auditRows: [] };
  const authCalls: FakeAuthCalls = { deleteUserUid: null, throwOnDelete: true };
  const result = await runAccountDeletionWithDeps(
    {
      db: makeFakeDb(state),
      auth: makeFakeAuth(authCalls),
      storage: makeFakeStorage({ deletePrefixes: [] }),
    },
    "uid-charlie",
    "c@example.com",
    "user_request",
  );

  if (result.success) {
    throw new Error("expected success=false when auth.deleteUser throws");
  }
  if (!result.failedCollections.includes("auth_deletion")) {
    throw new Error("failedCollections should include 'auth_deletion'");
  }
  if (state.auditRows.length !== 1) {
    throw new Error("audit row must still be written when auth delete fails");
  }
  if (state.auditRows[0].gdprCompliant !== false) {
    throw new Error("gdprCompliant should be false when there are failedCollections");
  }
});

/**
 * The audit row's `expireAt` is 180 days from now (the prior client value).
 * The TTL sweeper relies on this to clean up retention-windowed rows.
 */
test("BUT-788: audit row carries a 180-day expireAt", async () => {
  const state: FakeDbState = { auditRows: [] };
  const beforeMs = Date.now();
  await runAccountDeletionWithDeps(
    {
      db: makeFakeDb(state),
      auth: makeFakeAuth({ deleteUserUid: null, throwOnDelete: false }),
      storage: makeFakeStorage({ deletePrefixes: [] }),
    },
    "uid-d",
    "d@example.com",
    "r",
  );
  const expireAt = state.auditRows[0].expireAt as admin.firestore.Timestamp;
  const expireMs = expireAt.toMillis();
  const expectedMs = beforeMs + 180 * 24 * 60 * 60 * 1000;
  const drift = Math.abs(expireMs - expectedMs);
  if (drift > 60_000) {
    throw new Error(`expireAt drift too large: ${drift}ms (expected ~180d)`);
  }
});

async function run(): Promise<void> {
  console.log("BUT-788: requestAccountDeletion orchestrator tests\n");
  console.log("=====================================================\n");
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(`        ${(err as Error).message}`);
    }
  }
  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : ""),
  );
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
