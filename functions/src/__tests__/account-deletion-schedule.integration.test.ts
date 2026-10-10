/**
 * BUT-950 — emulator-backed tests for the deletion grace period.
 *
 * Firestore is the emulator (127.0.0.1:8080); Auth and Storage are injected
 * fakes, so the claim, the token revocation and the Auth delete are observed
 * on the fake.
 *
 * Run: npx ts-node src/__tests__/account-deletion-schedule.integration.test.ts
 * (with the Firestore emulator running).
 */

import * as http from "http";

const PROJECT_ID = "butlery-deletion-schedule-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  scheduleAccountDeletionWithDeps,
  cancelAccountDeletionWithDeps,
  runDueAccountDeletionsWithDeps,
  DELETION_GRACE_DAYS,
  DELETION_CLAIM,
  MAX_ATTEMPTS,
  RUN_BUDGET_MS,
  runDueAccountDeletions,
} = require("../account/account-deletion-schedule");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { resolveDeletionReason } = require("../account/request-account-deletion");

const RUN = Date.now().toString(36);
const NOW = Date.UTC(2026, 9, 10, 12, 0, 0);
const DAY_MS = 24 * 60 * 60 * 1000;
const REQUESTS = "account_deletion_requests";

interface FakeAuthState {
  claims: Map<string, Record<string, unknown>>;
  revoked: string[];
  deleted: string[];
  failClaimsFor?: string;
  failDeleteFor?: Set<string>;
  /** The request's `processingStartedAt` as the run saw it, keyed by uid. */
  seenLease?: Map<string, number | null>;
}

function fakeAuth(state: FakeAuthState): admin.auth.Auth {
  return {
    async getUser(uid: string) {
      // Called after the run's lease transaction and before the erasure.
      if (state.seenLease) {
        const snap = await db.doc(`${REQUESTS}/${uid}`).get();
        const lease = snap.get("processingStartedAt");
        state.seenLease.set(
          uid,
          lease instanceof admin.firestore.Timestamp ? lease.toMillis() : null,
        );
      }
      return {
        uid,
        email: `${uid}@example.com`,
        customClaims: state.claims.get(uid),
      };
    },
    async setCustomUserClaims(uid: string, claims: Record<string, unknown>) {
      if (state.failClaimsFor === uid) throw new Error("claims unavailable");
      state.claims.set(uid, claims);
    },
    async revokeRefreshTokens(uid: string) {
      state.revoked.push(uid);
    },
    async deleteUser(uid: string) {
      if (state.failDeleteFor?.has(uid)) throw new Error("auth unavailable");
      state.deleted.push(uid);
    },
  } as unknown as admin.auth.Auth;
}

function fakeStorage(): admin.storage.Storage {
  return {
    bucket() {
      return {
        async deleteFiles() {
          // Storage wipe is covered by the request-account-deletion contract test.
        },
      };
    },
  } as unknown as admin.storage.Storage;
}

function newAuthState(): FakeAuthState {
  return { claims: new Map(), revoked: [], deleted: [] };
}

function clearEmulator(): Promise<void> {
  return new Promise((resolve, reject) => {
    const [host, portStr] = EMULATOR_HOST.split(":");
    const req = http.request(
      {
        host,
        port: Number(portStr),
        path: `/emulator/v1/projects/${PROJECT_ID}/databases/(default)/documents`,
        method: "DELETE",
      },
      (res) => {
        res.resume();
        res.on("end", () => resolve());
      },
    );
    req.on("error", reject);
    req.end();
  });
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}
function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}
async function exists(path: string): Promise<boolean> {
  return (await db.doc(path).get()).exists;
}

test("schedule: records the request, sets the claim beside existing ones, signs out everywhere", async () => {
  const uid = `sched-${RUN}`;
  const auth = newAuthState();
  auth.claims.set(uid, { ageCompliant: true });

  const res = await scheduleAccountDeletionWithDeps(
    { db, auth: fakeAuth(auth) },
    uid,
    "testar",
    NOW,
  );

  const expected = NOW + DELETION_GRACE_DAYS * DAY_MS;
  assert(res.scheduledFor === expected, `scheduledFor ${res.scheduledFor} != ${expected}`);
  const snap = await db.doc(`${REQUESTS}/${uid}`).get();
  assert(snap.exists, "request document must exist");
  assert(
    snap.get("scheduledFor").toMillis() === expected,
    "stored scheduledFor must match the response",
  );
  assert(snap.get("reason") === "testar", "reason must be stored");
  const claims = auth.claims.get(uid) ?? {};
  assert(claims[DELETION_CLAIM] === expected, "claim must carry the date");
  assert(claims.ageCompliant === true, "existing claims must survive");
  assert(auth.revoked.includes(uid), "refresh tokens must be revoked");
});

test("schedule: asking again inside the window keeps the first date", async () => {
  const uid = `again-${RUN}`;
  const auth = newAuthState();
  const first = await scheduleAccountDeletionWithDeps(
    { db, auth: fakeAuth(auth) },
    uid,
    "a",
    NOW,
  );
  const second = await scheduleAccountDeletionWithDeps(
    { db, auth: fakeAuth(auth) },
    uid,
    "b",
    NOW + 3 * DAY_MS,
  );
  assert(second.scheduledFor === first.scheduledFor, "date must not move");
  assert(
    (await db.doc(`${REQUESTS}/${uid}`).get()).get("reason") === "a",
    "the first request must stand",
  );
});

test("schedule: a failed claim withdraws the request and throws", async () => {
  const uid = `noclaim-${RUN}`;
  const auth = newAuthState();
  auth.failClaimsFor = uid;
  let threw = false;
  try {
    await scheduleAccountDeletionWithDeps({ db, auth: fakeAuth(auth) }, uid, "x", NOW);
  } catch {
    threw = true;
  }
  assert(threw, "schedule must throw when the claim cannot be set");
  assert(!(await exists(`${REQUESTS}/${uid}`)), "request must be withdrawn");
  assert(!auth.revoked.includes(uid), "nobody is signed out for a withdrawn request");
});

test("schedule: a failed claim on a repeat keeps the first request", async () => {
  const uid = `repeat-noclaim-${RUN}`;
  const auth = newAuthState();
  await scheduleAccountDeletionWithDeps({ db, auth: fakeAuth(auth) }, uid, "a", NOW);
  auth.failClaimsFor = uid;
  let threw = false;
  try {
    await scheduleAccountDeletionWithDeps({ db, auth: fakeAuth(auth) }, uid, "b", NOW);
  } catch {
    threw = true;
  }
  assert(threw, "the repeat must report the claim failure");
  assert(
    await exists(`${REQUESTS}/${uid}`),
    "the first request, whose claim is set, must stay",
  );
});

test("cancel: removes the request and the claim, keeps other claims", async () => {
  const uid = `cancel-${RUN}`;
  const auth = newAuthState();
  auth.claims.set(uid, { ageCompliant: true });
  await scheduleAccountDeletionWithDeps({ db, auth: fakeAuth(auth) }, uid, "x", NOW);

  const res = await cancelAccountDeletionWithDeps({ db, auth: fakeAuth(auth) }, uid);

  assert(res.cancelled === true, "cancel must report it removed a request");
  assert(!(await exists(`${REQUESTS}/${uid}`)), "request must be gone");
  const claims = auth.claims.get(uid) ?? {};
  assert(!(DELETION_CLAIM in claims), "claim must be gone");
  assert(claims.ageCompliant === true, "other claims must survive");
});

test("cancel: with no request it reports nothing cancelled", async () => {
  const uid = `nocancel-${RUN}`;
  const res = await cancelAccountDeletionWithDeps(
    { db, auth: fakeAuth(newAuthState()) },
    uid,
  );
  assert(res.cancelled === false, "nothing to cancel");
});

test("cancel: refused once the erasure has started", async () => {
  const uid = `started-${RUN}`;
  await db.doc(`${REQUESTS}/${uid}`).set({
    requestedAt: admin.firestore.Timestamp.fromMillis(NOW - 8 * DAY_MS),
    scheduledFor: admin.firestore.Timestamp.fromMillis(NOW - DAY_MS),
    reason: "x",
    processingStartedAt: admin.firestore.Timestamp.fromMillis(NOW),
  });
  let code: unknown = null;
  try {
    await cancelAccountDeletionWithDeps({ db, auth: fakeAuth(newAuthState()) }, uid);
  } catch (err) {
    code = (err as { details?: { code?: string } }).details?.code;
  }
  assert(code === "deletion-in-progress", `expected deletion-in-progress, got ${String(code)}`);
  assert(await exists(`${REQUESTS}/${uid}`), "the started request must stay");
});

test("cancel: refused after an incomplete run put the request back", async () => {
  const uid = `partial-${RUN}`;
  await db.doc(`${REQUESTS}/${uid}`).set({
    requestedAt: admin.firestore.Timestamp.fromMillis(NOW - 8 * DAY_MS),
    scheduledFor: admin.firestore.Timestamp.fromMillis(NOW - DAY_MS),
    reason: "x",
    attempts: 1,
  });
  let code: unknown = null;
  try {
    await cancelAccountDeletionWithDeps({ db, auth: fakeAuth(newAuthState()) }, uid);
  } catch (err) {
    code = (err as { details?: { code?: string } }).details?.code;
  }
  assert(code === "deletion-in-progress", `expected deletion-in-progress, got ${String(code)}`);
  assert(await exists(`${REQUESTS}/${uid}`), "the put-back request must stay");
});

test("runDue: the run budget ends before the function timeout", async () => {
  const timeoutSeconds = runDueAccountDeletions.__endpoint?.timeoutSeconds;
  assert(typeof timeoutSeconds === "number", `timeoutSeconds must be set, got ${String(timeoutSeconds)}`);
  assert(
    RUN_BUDGET_MS < timeoutSeconds * 1000,
    `budget ${RUN_BUDGET_MS} ms must be below the ${timeoutSeconds} s timeout`,
  );
});

test("runDue: erases due and stale-leased accounts, leaves pending and freshly leased ones", async () => {
  await clearEmulator();
  const due = `due-${RUN}`;
  const stale = `stale-${RUN}`;
  const pending = `pending-${RUN}`;
  const leased = `leased-${RUN}`;
  const ts = admin.firestore.Timestamp.fromMillis;
  await db.doc(`${REQUESTS}/${due}`).set({
    requestedAt: ts(NOW - 8 * DAY_MS),
    scheduledFor: ts(NOW - DAY_MS),
    reason: "orsak",
  });
  await db.doc(`${REQUESTS}/${stale}`).set({
    requestedAt: ts(NOW - 8 * DAY_MS),
    scheduledFor: ts(NOW - DAY_MS),
    reason: "orsak",
    processingStartedAt: ts(NOW - 60 * 60 * 1000),
  });
  await db.doc(`${REQUESTS}/${pending}`).set({
    requestedAt: ts(NOW),
    scheduledFor: ts(NOW + DAY_MS),
    reason: "orsak",
  });
  await db.doc(`${REQUESTS}/${leased}`).set({
    requestedAt: ts(NOW - 8 * DAY_MS),
    scheduledFor: ts(NOW - DAY_MS),
    reason: "orsak",
    processingStartedAt: ts(NOW - 60 * 1000),
  });
  for (const uid of [due, stale, pending, leased]) {
    await db.doc(`users/${uid}`).set({ displayName: uid });
  }

  const auth = newAuthState();
  auth.seenLease = new Map();
  const summary = await runDueAccountDeletionsWithDeps(
    { db, auth: fakeAuth(auth), storage: fakeStorage() },
    NOW,
  );

  for (const uid of [due, stale]) {
    assert(
      auth.seenLease.get(uid) === NOW,
      `${uid} must be leased at NOW before the erasure runs, saw ${auth.seenLease.get(uid)}`,
    );
  }
  assert(
    summary.erased === 2 && summary.skipped === 1 && summary.failed === 0,
    `unexpected summary ${JSON.stringify(summary)}`,
  );
  for (const uid of [due, stale]) {
    assert(auth.deleted.includes(uid), `${uid} must be deleted in Auth`);
    assert(!(await exists(`users/${uid}`)), `${uid} profile must be erased`);
    assert(!(await exists(`${REQUESTS}/${uid}`)), `${uid} request must be erased`);
  }
  for (const uid of [pending, leased]) {
    assert(!auth.deleted.includes(uid), `${uid} must not be deleted`);
    assert(await exists(`users/${uid}`), `${uid} profile must stay`);
    assert(await exists(`${REQUESTS}/${uid}`), `${uid} request must stay`);
  }
  const audit = await db
    .collection("deletion_audit_logs")
    .where("reason", "==", "orsak")
    .get();
  assert(audit.size === 2, `expected two audit rows with the stored reason, got ${audit.size}`);
});

test("runDue: an incomplete erasure puts the request back for the next run", async () => {
  await clearEmulator();
  const uid = `retry-${RUN}`;
  const ts = admin.firestore.Timestamp.fromMillis;
  await db.doc(`${REQUESTS}/${uid}`).set({
    requestedAt: ts(NOW - 8 * DAY_MS),
    scheduledFor: ts(NOW - DAY_MS),
    reason: "orsak",
  });
  await db.doc(`users/${uid}`).set({ displayName: uid });

  const auth = newAuthState();
  auth.failDeleteFor = new Set([uid]);
  const deps = { db, auth: fakeAuth(auth), storage: fakeStorage() };
  const first = await runDueAccountDeletionsWithDeps(deps, NOW);

  assert(first.failed === 1, `first run must report the failure: ${JSON.stringify(first)}`);
  const back = await db.doc(`${REQUESTS}/${uid}`).get();
  assert(back.exists, "the request must be put back");
  assert(back.get("attempts") === 1, `attempts must be 1, got ${back.get("attempts")}`);
  assert(back.get("processingStartedAt") === undefined, "the request must not stay leased");
  assert(back.get("reason") === "orsak", "the reason must survive the retry");

  auth.failDeleteFor = undefined;
  const second = await runDueAccountDeletionsWithDeps(deps, NOW + 60 * 60 * 1000);
  assert(second.erased === 1, `second run must erase: ${JSON.stringify(second)}`);
  assert(auth.deleted.includes(uid), "Auth account must be deleted on the retry");
  assert(!(await exists(`${REQUESTS}/${uid}`)), "request must be gone after the retry");
});

test("runDue: the last allowed attempt gives up instead of looping", async () => {
  await clearEmulator();
  const uid = `giveup-${RUN}`;
  const ts = admin.firestore.Timestamp.fromMillis;
  await db.doc(`${REQUESTS}/${uid}`).set({
    requestedAt: ts(NOW - 8 * DAY_MS),
    scheduledFor: ts(NOW - DAY_MS),
    reason: "orsak",
    attempts: MAX_ATTEMPTS - 1,
  });
  const auth = newAuthState();
  auth.failDeleteFor = new Set([uid]);
  const summary = await runDueAccountDeletionsWithDeps(
    { db, auth: fakeAuth(auth), storage: fakeStorage() },
    NOW,
  );
  assert(summary.failed === 1, `must report the failure: ${JSON.stringify(summary)}`);
  assert(!(await exists(`${REQUESTS}/${uid}`)), "a spent request must not come back");
});

test("resolveDeletionReason: a given reason wins, else the stored one, else the default", async () => {
  const uid = `reason-${RUN}`;
  assert(
    (await resolveDeletionReason(db, uid, "")) === "user_request",
    "no request and no reason gives the default",
  );
  await db.doc(`${REQUESTS}/${uid}`).set({ reason: "sparad" });
  assert(
    (await resolveDeletionReason(db, uid, "")) === "sparad",
    "an empty reason uses the stored one",
  );
  assert(
    (await resolveDeletionReason(db, uid, undefined)) === "sparad",
    "a missing reason uses the stored one",
  );
  assert(
    (await resolveDeletionReason(db, uid, "ny")) === "ny",
    "a given reason wins over the stored one",
  );
});

test("runDue: at most five accounts per run, the rest wait for the next", async () => {
  await clearEmulator();
  const ts = admin.firestore.Timestamp.fromMillis;
  const uids = Array.from({ length: 6 }, (_, i) => `batch${i}-${RUN}`);
  for (const [i, uid] of uids.entries()) {
    await db.doc(`${REQUESTS}/${uid}`).set({
      requestedAt: ts(NOW - 8 * DAY_MS),
      scheduledFor: ts(NOW - DAY_MS - i * 1000),
      reason: "orsak",
    });
  }
  const summary = await runDueAccountDeletionsWithDeps(
    { db, auth: fakeAuth(newAuthState()), storage: fakeStorage() },
    NOW,
  );
  assert(summary.erased === 5, `expected 5 erased, got ${JSON.stringify(summary)}`);
  const left = await db.collection(REQUESTS).get();
  assert(
    left.size === 1 && left.docs[0].id === uids[0],
    `the latest-due request must wait, left: ${left.docs.map((d) => d.id)}`,
  );
});

async function run(): Promise<void> {
  console.log("BUT-950: account deletion grace period (emulator)");
  await clearEmulator();
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
  await clearEmulator();
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
