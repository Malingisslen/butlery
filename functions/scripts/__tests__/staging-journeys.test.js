/**
 * BUT-2424: tests for the staging journeys. Plain Node + node:assert, run by
 * `npm run test:script-staging-journeys`. No network: Firestore and Auth are
 * in-memory fakes, and the backend functions are stand-ins that either do their
 * job or fail in one named way.
 */
const assert = require("assert");
const { spawnSync } = require("child_process");
const path = require("path");
const journeys = require("../staging-journeys.js");

const results = [];
async function test(name, fn) {
  try { await fn(); results.push({ name, ok: true }); } catch (err) { results.push({ name, ok: false, err }); }
}

function makeEnv() {
  const docs = new Map();
  const users = new Map();
  let n = 0;
  const ref = (p) => ({
    get: async () => ({ exists: docs.has(p) }),
    set: async (v) => { docs.set(p, v); },
    delete: async () => { docs.delete(p); },
    collection: (c) => ({ doc: (id) => ref(`${p}/${c}/${id}`), _path: `${p}/${c}` }),
    _path: p,
  });
  const db = {
    collection: (c) => ({ doc: (id) => ref(`${c}/${id}`), _path: c }),
    recursiveDelete: async (r) => { for (const k of [...docs.keys()]) if (k.startsWith(r._path)) docs.delete(k); },
  };
  const auth = {
    createUser: async ({ email }) => { const uid = `uid${++n}`; users.set(uid, { uid, email, customClaims: {} }); return { uid }; },
    getUser: async (uid) => {
      if (!users.has(uid)) { const e = new Error("gone"); e.code = "auth/user-not-found"; throw e; }
      return users.get(uid);
    },
    deleteUser: async (uid) => { users.delete(uid); },
  };
  return { db, auth, docs, users };
}

const goodDeletion = (env) => ({
  requestsCollection: "account_deletion_requests",
  claim: "deletionScheduledFor",
  schedule: async ({ db, auth }, uid) => {
    const at = 123;
    await db.collection("account_deletion_requests").doc(uid).set({ at });
    (await auth.getUser(uid)).customClaims.deletionScheduledFor = at;
    return { scheduledFor: at };
  },
  cancel: async ({ db, auth }, uid) => {
    await db.collection("account_deletion_requests").doc(uid).delete();
    delete (await auth.getUser(uid)).customClaims.deletionScheduledFor;
    return { cancelled: true };
  },
});
const goodErasure = {
  erase: async ({ db, auth }, uid) => {
    await db.recursiveDelete(db.collection("users").doc(uid));
    await auth.deleteUser(uid);
    return { success: true, failedCollections: [], errors: [] };
  },
};
const run = (env, over = {}) =>
  journeys.runJourneys({ db: env.db, auth: env.auth, storage: {}, runId: "r1", injectFailure: false,
    deletion: goodDeletion(env), erasure: goodErasure, ...over });

(async () => {
  await test("refuses any project but staging before contacting anything", () => {
    for (const args of [["--project", "butlery-prod"], []]) {
      const r = spawnSync(process.execPath, [path.resolve(__dirname, "../staging-journeys.js"), ...args],
        { encoding: "utf8", env: { PATH: process.env.PATH } });
      assert.notStrictEqual(r.status, 0);
      assert.match(r.stderr, /REFUSED/);
    }
  });

  await test("refuses when an emulator host is set", () => {
    const r = spawnSync(process.execPath, [path.resolve(__dirname, "../staging-journeys.js"), "--project", "butlery-app-staging"],
      { encoding: "utf8", env: { PATH: process.env.PATH, FIRESTORE_EMULATOR_HOST: "localhost:8080" } });
    assert.notStrictEqual(r.status, 0);
    assert.match(r.stderr, /REFUSED/);
  });

  await test("all green, and nothing is left behind", async () => {
    const env = makeEnv();
    const out = await run(env);
    assert.strictEqual(out.length, 2);
    assert.ok(out.every((r) => r.ok), JSON.stringify(out));
    assert.strictEqual(env.users.size, 0);
    assert.strictEqual(env.docs.size, 0);
  });

  await test("an erasure that leaves the profile behind is red and named", async () => {
    const env = makeEnv();
    const out = await run(env, { erasure: { erase: async ({ auth }, uid) => { await auth.deleteUser(uid); return { success: true }; } } });
    const r = out.find((x) => x.name === "erasure");
    assert.strictEqual(r.ok, false);
    assert.match(r.detail, /profile document still exists/);
    assert.match(r.detail, /recipe document still exists/);
    assert.strictEqual(env.docs.size, 0, "cleanup removes what the failed journey left");
  });

  await test("an erasure that keeps the Auth user is red", async () => {
    const env = makeEnv();
    const out = await run(env, { erasure: { erase: async ({ db }, uid) => {
      await db.recursiveDelete(db.collection("users").doc(uid)); return { success: true }; } } });
    assert.match(out.find((x) => x.name === "erasure").detail, /Auth user still exists/);
  });

  await test("a reported failure from the erasure is red", async () => {
    const env = makeEnv();
    const out = await run(env, { erasure: { erase: async () => ({ success: false, failedCollections: ["blocks"], errors: ["x"] }) } });
    assert.match(out.find((x) => x.name === "erasure").detail, /blocks/);
  });

  await test("a cancel that leaves the claim is red", async () => {
    const env = makeEnv();
    const d = goodDeletion(env);
    d.cancel = async ({ db }, uid) => { await db.collection("account_deletion_requests").doc(uid).delete(); return { cancelled: true }; };
    const out = await run(env, { deletion: d });
    assert.match(out.find((x) => x.name === "deletion-grace").detail, /claim left after cancel/);
  });

  await test("a journey that throws is red and its account is still removed", async () => {
    const env = makeEnv();
    const d = goodDeletion(env);
    d.schedule = async () => { throw new Error("boom"); };
    const out = await run(env, { deletion: d });
    assert.match(out.find((x) => x.name === "deletion-grace").detail, /boom/);
    assert.strictEqual(env.users.size, 0);
  });

  await test("--inject-failure ends red even when everything else is green", async () => {
    const out = await run(makeEnv(), { injectFailure: true });
    assert.ok(out.some((r) => !r.ok));
  });

  await test("synthetic accounts use a reserved .invalid address", () => {
    assert.match(journeys.syntheticEmail("abc"), /^e2e-abc@staging-e2e\.invalid$/);
  });

  const failed = results.filter((r) => !r.ok);
  for (const r of results) { console.log(`${r.ok ? "PASS" : "FAIL"} ${r.name}`); if (!r.ok) console.log(r.err); }
  console.log(`${results.length - failed.length}/${results.length} passed`);
  process.exit(failed.length ? 1 : 0);
})();
