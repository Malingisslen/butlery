/**
 * BUT-1386 — `verifySignupAge` DI-core tests.
 *
 * Exercises the contract of `runVerifySignupAgeWithDeps(deps, uid, birthYear)`
 * and the `enforceIpAuditCap(db, ip)` FinOps guard against hand-rolled fake
 * `admin` surfaces (mirrors `request-account-deletion.test.ts` — no emulator,
 * no real Firebase). Each case asserts side effects on injected fakes.
 *
 * Behaviour covered:
 *   1. ≥15 admitted — compliant:true, ageCompliant claim set (existing claims
 *      preserved), birthYear merged into BOTH user paths, exactly ONE
 *      `consent_age_verification` audit row with hashed uid + decade, no raw
 *      birthYear in the row.
 *   2. Idempotent retry — pre-set ageCompliant claim short-circuits: no second
 *      birthYear write, no second audit row.
 *   3. <15 rejected — compliant:false, auth.deleteUser called, ONE
 *      `age_verification_rejected` row with NO uid / userIdHash / birthYear,
 *      and NO claim set.
 *   4. <15 + deleteUser throws — function rethrows (never returns compliant).
 *   5. enforceIpAuditCap — under cap increments; at/over cap throws
 *      resource-exhausted; a transaction error fails closed (throws).
 *
 * Run: npx ts-node src/__tests__/verify-signup-age.test.ts
 */

import * as admin from "firebase-admin";
import { createHash } from "crypto";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-verify-signup-age" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  runVerifySignupAgeWithDeps,
  enforceIpAuditCap,
  MIN_AGE_YEARS,
} = require("../account/verify-signup-age");

/** SHA-256 12-char hex prefix — must match `shared/hash-uid.ts`. */
function expectedHashUid(uid: string): string {
  return createHash("sha256").update(uid).digest("hex").substring(0, 12);
}

interface AuditRow {
  operation: string;
  userIdHash?: string;
  isAgeCompliant?: boolean;
  birthDecade?: string;
  birthYear?: number;
  reason?: string;
  basis?: string;
  timestamp?: unknown;
  [key: string]: unknown;
}

interface MergeWrite {
  path: string;
  data: Record<string, unknown>;
  merge: boolean;
}

interface FakeDbState {
  auditRows: AuditRow[];
  setWrites: MergeWrite[];
}

/** Minimal Firestore fake recording `add` to audit_logs and `doc().set()`
 *  merge writes — enough to assert the function's documented side effects. */
function makeFakeDb(state: FakeDbState): admin.firestore.Firestore {
  function makeDocRef(path: string): unknown {
    return {
      async set(data: Record<string, unknown>, opts?: { merge?: boolean }) {
        state.setWrites.push({ path, data, merge: opts?.merge === true });
      },
    };
  }
  return {
    collection(name: string) {
      return {
        async add(data: AuditRow) {
          if (name === "audit_logs") state.auditRows.push(data);
          return { id: `synthetic-${state.auditRows.length}` };
        },
      };
    },
    doc(path: string) {
      return makeDocRef(path);
    },
  } as unknown as admin.firestore.Firestore;
}

interface FakeAuthState {
  /** Claims returned by getUser — simulates an already-verified retry. */
  existingClaims: Record<string, unknown> | undefined;
  /** Captured argument of setCustomUserClaims, null until called. */
  setClaimsArg: Record<string, unknown> | null;
  setClaimsCallCount: number;
  deleteUserUid: string | null;
  deleteUserCallCount: number;
  throwOnDelete: boolean;
}

function makeFakeAuth(state: FakeAuthState): admin.auth.Auth {
  return {
    async getUser(_uid: string) {
      return { customClaims: state.existingClaims };
    },
    async setCustomUserClaims(_uid: string, claims: Record<string, unknown>) {
      state.setClaimsCallCount++;
      state.setClaimsArg = claims;
    },
    async deleteUser(uid: string) {
      state.deleteUserCallCount++;
      state.deleteUserUid = uid;
      if (state.throwOnDelete) {
        throw new Error("auth/user-not-found");
      }
    },
  } as unknown as admin.auth.Auth;
}

function freshAuthState(
  existingClaims?: Record<string, unknown>,
): FakeAuthState {
  return {
    existingClaims,
    setClaimsArg: null,
    setClaimsCallCount: 0,
    deleteUserUid: null,
    deleteUserCallCount: 0,
    throwOnDelete: false,
  };
}

interface TestCase {
  name: string;
  fn: () => Promise<void>;
}

const tests: TestCase[] = [];
function test(name: string, fn: () => Promise<void>): void {
  tests.push({ name, fn });
}

function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

const CURRENT_YEAR = new Date().getFullYear();

/**
 * Case 1 — an adult (and exactly-15) caller is admitted: the claim is set
 * with existing claims preserved, birthYear is merged into both read paths,
 * and exactly one consent-category audit row records the derived facts only.
 */
test("≥15 admitted: claim set (preserving existing), dual birthYear merge, one consent audit row", async () => {
  for (const birthYear of [CURRENT_YEAR - MIN_AGE_YEARS, 1990]) {
    const dbState: FakeDbState = { auditRows: [], setWrites: [] };
    const authState = freshAuthState({ premium: true }); // pre-existing claim
    const uid = "uid-adult";

    const result = await runVerifySignupAgeWithDeps(
      { db: makeFakeDb(dbState), auth: makeFakeAuth(authState) },
      uid,
      birthYear,
    );

    assert(result.compliant === true, `expected compliant:true for birthYear ${birthYear}`);

    // Claim set exactly once, preserving the pre-existing `premium` claim.
    assert(authState.setClaimsCallCount === 1, "setCustomUserClaims should be called once");
    assert(authState.setClaimsArg?.ageCompliant === true, "ageCompliant must be true in claims");
    assert(authState.setClaimsArg?.premium === true, "existing claims must be preserved (spread)");
    assert(authState.deleteUserCallCount === 0, "admitted user must NOT be deleted");

    // birthYear merged into BOTH user paths.
    const merges = dbState.setWrites.filter((w) => w.merge && w.data.birthYear === birthYear);
    const paths = merges.map((w) => w.path);
    assert(paths.includes(`users/${uid}`), `users/${uid} birthYear merge missing`);
    assert(
      paths.includes(`users/${uid}/settings/preferences`),
      "settings/preferences birthYear merge missing",
    );
    assert(merges.every((w) => w.merge === true), "birthYear writes must use { merge: true }");

    // Exactly one consent audit row, derived-facts-only.
    assert(dbState.auditRows.length === 1, `expected 1 audit row, got ${dbState.auditRows.length}`);
    const row = dbState.auditRows[0];
    assert(
      row.operation === "consent_age_verification",
      "operation must be consent_age_verification (drives 730-day retention)",
    );
    assert(row.isAgeCompliant === true, "isAgeCompliant must be true");
    assert(typeof row.birthDecade === "string", "birthDecade must be a string");
    assert(row.userIdHash === expectedHashUid(uid), "userIdHash must be the hashed uid");
    assert(
      !("birthYear" in row),
      "audit row must NOT carry a raw birthYear (data minimisation)",
    );
  }
});

/**
 * Case 2 — a retry whose token already carries ageCompliant:true is a no-op
 * success: no claim re-write, no second birthYear write, no second audit row.
 */
test("idempotent retry: pre-set ageCompliant claim → no birthYear write, no audit row", async () => {
  const dbState: FakeDbState = { auditRows: [], setWrites: [] };
  const authState = freshAuthState({ ageCompliant: true });

  const result = await runVerifySignupAgeWithDeps(
    { db: makeFakeDb(dbState), auth: makeFakeAuth(authState) },
    "uid-retry",
    1990,
  );

  assert(result.compliant === true, "retry of a compliant user must still return compliant:true");
  assert(authState.setClaimsCallCount === 0, "must NOT re-set claims on idempotent retry");
  assert(dbState.setWrites.length === 0, "must NOT re-write birthYear on idempotent retry");
  assert(dbState.auditRows.length === 0, "must NOT add a second audit row on idempotent retry");
  assert(authState.deleteUserCallCount === 0, "must NOT delete a compliant user");
});

/**
 * Case 3 — a minor is rejected: account deleted, no claim set, and the
 * rejection audit row is deliberately non-identifying (no uid / userIdHash /
 * birthYear — Legal: never link an identity to being under 15).
 */
test("<15 rejected: deleteUser called, no claim, non-identifying rejection audit row", async () => {
  const dbState: FakeDbState = { auditRows: [], setWrites: [] };
  const authState = freshAuthState(undefined);
  const uid = "uid-minor";

  const result = await runVerifySignupAgeWithDeps(
    { db: makeFakeDb(dbState), auth: makeFakeAuth(authState) },
    uid,
    CURRENT_YEAR - (MIN_AGE_YEARS - 1), // 14 years old
  );

  assert(result.compliant === false, "under-15 must return compliant:false");
  assert(authState.deleteUserCallCount === 1, "under-15 must trigger auth.deleteUser");
  assert(authState.deleteUserUid === uid, "deleteUser must target the caller's uid");
  assert(authState.setClaimsCallCount === 0, "rejected minor must NOT get any custom claim");
  assert(dbState.setWrites.length === 0, "rejected minor must NOT have birthYear written anywhere");

  assert(dbState.auditRows.length === 1, `expected 1 rejection row, got ${dbState.auditRows.length}`);
  const row = dbState.auditRows[0];
  assert(
    row.operation === "age_verification_rejected",
    "operation must be age_verification_rejected",
  );
  // The whole point: the row must not be linkable to a person.
  assert(!("userIdHash" in row), "rejection row must NOT carry userIdHash");
  assert(!("uid" in row), "rejection row must NOT carry uid");
  assert(!("birthYear" in row), "rejection row must NOT carry birthYear");
  assert(!("birthDecade" in row), "rejection row must NOT carry birthDecade");
});

/**
 * Case 4 — if deleting the just-created minor account fails, the function must
 * rethrow so the client cannot proceed as admitted. It must never return a
 * compliant result on this path.
 */
test("<15 + deleteUser throws: function rethrows, never returns compliant", async () => {
  const dbState: FakeDbState = { auditRows: [], setWrites: [] };
  const authState = freshAuthState(undefined);
  authState.throwOnDelete = true;

  let threw = false;
  let returned: unknown = undefined;
  try {
    returned = await runVerifySignupAgeWithDeps(
      { db: makeFakeDb(dbState), auth: makeFakeAuth(authState) },
      "uid-minor-2",
      CURRENT_YEAR - (MIN_AGE_YEARS - 1),
    );
  } catch {
    threw = true;
  }

  assert(threw, "function must rethrow when auth.deleteUser fails");
  assert(
    returned === undefined,
    "function must NOT return a value (esp. not compliant) when deletion fails",
  );
  assert(authState.setClaimsCallCount === 0, "no claim should be set on the rejection path");
});

// ---- enforceIpAuditCap ----

interface FakeCapDoc {
  exists: boolean;
  count: number;
}

interface FakeCapState {
  doc: FakeCapDoc;
  /** When true, runTransaction rejects to simulate a Firestore/tx error. */
  txError: boolean;
  setCalls: number;
  lastSetData: Record<string, unknown> | null;
}

function makeFakeCapDb(state: FakeCapState): admin.firestore.Firestore {
  const ref = { __isRef: true };
  const tx = {
    async get(_ref: unknown) {
      return {
        exists: state.doc.exists,
        data: () => ({ count: state.doc.count }),
      };
    },
    set(_ref: unknown, data: Record<string, unknown>) {
      state.setCalls++;
      state.lastSetData = data;
      state.doc.count = (data.count as number) ?? state.doc.count;
      state.doc.exists = true;
    },
  };
  return {
    collection(_name: string) {
      return { doc(_id: string) { return ref; } };
    },
    async runTransaction(fn: (t: typeof tx) => Promise<void>) {
      if (state.txError) throw new Error("firestore unavailable");
      return fn(tx);
    },
  } as unknown as admin.firestore.Firestore;
}

/** Under the cap (count 0 < 5): resolves and increments the counter. */
test("enforceIpAuditCap: under cap resolves and increments", async () => {
  const state: FakeCapState = {
    doc: { exists: false, count: 0 },
    txError: false,
    setCalls: 0,
    lastSetData: null,
  };
  await enforceIpAuditCap(makeFakeCapDb(state), "1.2.3.4");
  assert(state.setCalls === 1, "under cap must write the counter");
  assert(state.lastSetData?.count === 1, "counter must increment to 1 from 0");
});

/** At the cap (count 5 >= 5): throws an HttpsError tagged resource-exhausted. */
test("enforceIpAuditCap: at/over cap throws resource-exhausted", async () => {
  for (const count of [5, 9]) {
    const state: FakeCapState = {
      doc: { exists: true, count },
      txError: false,
      setCalls: 0,
      lastSetData: null,
    };
    let code: string | undefined;
    let threw = false;
    try {
      await enforceIpAuditCap(makeFakeCapDb(state), "1.2.3.4");
    } catch (err) {
      threw = true;
      code = (err as { code?: string }).code;
    }
    assert(threw, `expected throw at count ${count}`);
    // firebase-functions HttpsError codes are prefixed "functions/".
    assert(
      code === "resource-exhausted" || code === "functions/resource-exhausted",
      `expected resource-exhausted, got code: ${code}`,
    );
    assert(state.setCalls === 0, "must NOT increment the counter when over cap");
  }
});

/** A Firestore/transaction error fails CLOSED — the cap throws, never resolves. */
test("enforceIpAuditCap: transaction error fails closed (throws, not resolve)", async () => {
  const state: FakeCapState = {
    doc: { exists: false, count: 0 },
    txError: true,
    setCalls: 0,
    lastSetData: null,
  };
  let threw = false;
  let code: string | undefined;
  try {
    await enforceIpAuditCap(makeFakeCapDb(state), "1.2.3.4");
  } catch (err) {
    threw = true;
    code = (err as { code?: string }).code;
  }
  assert(threw, "a Firestore error must make the cap throw (fail closed), not resolve");
  assert(
    code === "resource-exhausted" || code === "functions/resource-exhausted",
    `fail-closed should surface resource-exhausted, got: ${code}`,
  );
});

async function run(): Promise<void> {
  console.log("BUT-1386: verifySignupAge DI-core tests\n");
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
