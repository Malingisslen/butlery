/**
 * BUT-2316: tests for the age-claim backfill.
 *
 * Plain Node + node:assert, run by `npm run test:script-age-claim-backfill`,
 * which run-ci-unit-tests.js discovers.
 */

const assert = require("assert");
const { classify, runBackfill, hashUid } = require("../backfill-age-claim.js");

const results = [];
async function test(name, fn) {
  try {
    await fn();
    results.push({ name, ok: true });
  } catch (err) {
    results.push({ name, ok: false, err });
  }
}

// Auth is stateful so a second run sees the claims the first one set.
function fakeDeps(users, docs, { failAuditOnce = false } = {}) {
  const store = Object.fromEntries(
    users.map((u) => [u.uid, { ...(u.customClaims || {}) }]),
  );
  const claims = {};
  const writes = [];
  let auditFailsLeft = failAuditOnce ? 1 : 0;
  const db = {
    doc: (path) => ({
      path,
      set: async (data, opts) => writes.push({ path, data, opts }),
    }),
    collection: (name) => ({
      doc: (id) => ({
        set: async (data, opts) => {
          if (name === "audit_logs" && auditFailsLeft > 0) {
            auditFailsLeft--;
            throw Object.assign(new Error("unavailable"), { code: "unavailable" });
          }
          writes.push({ path: `${name}/${id}`, data, opts });
        },
      }),
    }),
    getAll: async (...refs) =>
      refs.map((r) => ({
        exists: r.path in docs,
        get: (field) => (docs[r.path] || {})[field],
      })),
  };
  const asUser = (uid) => ({ uid, customClaims: { ...store[uid] } });
  const auth = {
    listUsers: async (max, token) => {
      const start = token ? Number(token) : 0;
      const slice = users.slice(start, start + 2).map((u) => asUser(u.uid));
      const next = start + 2 < users.length ? String(start + 2) : undefined;
      return { users: slice, pageToken: next };
    },
    getUser: async (uid) => asUser(uid),
    setCustomUserClaims: async (uid, c) => {
      store[uid] = { ...c };
      claims[uid] = c;
    },
  };
  return { deps: { auth, db, serverTimestamp: () => "ts" }, claims, writes };
}

(async () => {
  await test("classify: adult year in one place is granted", () => {
    assert.deepStrictEqual(classify(1980, undefined, 2026), {
      outcome: "grant",
      birthYear: 1980,
    });
    assert.deepStrictEqual(classify(undefined, "1980", 2026), {
      outcome: "grant",
      birthYear: 1980,
    });
  });

  await test("classify: 18 exactly is granted, 17 is a minor, 14 is under 15", () => {
    assert.strictEqual(classify(2008, null, 2026).outcome, "grant");
    assert.strictEqual(classify(2009, null, 2026).outcome, "minor");
    assert.strictEqual(classify(2011, null, 2026).outcome, "minor");
    assert.strictEqual(classify(2012, null, 2026).outcome, "under15");
  });

  await test("classify: missing, disagreeing and malformed years are not granted", () => {
    assert.strictEqual(classify(undefined, null, 2026).outcome, "noStoredYear");
    assert.strictEqual(classify(1980, 1981, 2026).outcome, "conflictingYears");
    assert.strictEqual(classify(1980, 1980, 2026).outcome, "grant");
    assert.strictEqual(classify("abc", undefined, 2026).outcome, "invalidYear");
    assert.strictEqual(classify(1850, undefined, 2026).outcome, "invalidYear");
    assert.strictEqual(classify(1980.5, undefined, 2026).outcome, "invalidYear");
  });

  const users = [
    { uid: "adult", customClaims: { admin: true } },
    { uid: "done", customClaims: { ageCompliant: true } },
    { uid: "teen" },
    { uid: "none" },
    { uid: "clash" },
    { uid: "child" },
  ];
  const docs = {
    "users/adult": { birthYear: 1980 },
    "users/done": { birthYear: 1970 },
    "users/child": { birthYear: 2015 },
    "users/teen/settings/preferences": { birthYear: 2010 },
    "users/clash": { birthYear: 1980 },
    "users/clash/settings/preferences": { birthYear: 1990 },
  };

  await test("dry run counts every outcome and writes nothing", async () => {
    const { deps, claims, writes } = fakeDeps(users, docs);
    const counts = await runBackfill(deps, { apply: false, currentYear: 2026 });
    assert.strictEqual(counts.total, 6);
    assert.strictEqual(counts.under15, 1);
    assert.strictEqual(counts.alreadyCompliant, 1);
    assert.strictEqual(counts.grant, 1);
    assert.strictEqual(counts.minor, 1);
    assert.strictEqual(counts.noStoredYear, 1);
    assert.strictEqual(counts.conflictingYears, 1);
    assert.deepStrictEqual(claims, {});
    assert.deepStrictEqual(writes, []);
  });

  await test("apply grants only the adult, keeps its other claims, and writes the artifacts", async () => {
    const { deps, claims, writes } = fakeDeps(users, docs);
    const counts = await runBackfill(deps, { apply: true, currentYear: 2026 });
    assert.strictEqual(counts.grant, 1);
    assert.deepStrictEqual(Object.keys(claims), ["adult"]);
    assert.deepStrictEqual(claims.adult, { admin: true, ageCompliant: true });
    assert.ok(!writes.some((w) => w.path.includes("done")));
    const paths = writes.map((w) => w.path).sort();
    assert.deepStrictEqual(paths, [
      `audit_logs/consent_age_verification_${hashUid("adult")}`,
      "users/adult",
      "users/adult/settings/preferences",
    ]);
    const audit = writes.find((w) => w.path.startsWith("audit_logs/"));
    assert.strictEqual(audit.data.source, "backfill_stored_birth_year");
    assert.strictEqual(audit.data.birthDecade, "1980s");
    for (const w of writes) assert.deepStrictEqual(w.opts, { merge: true });
  });

  await test("a failed grant is counted, not thrown", async () => {
    const { deps } = fakeDeps(users, docs);
    deps.auth.setCustomUserClaims = async () => {
      throw new Error("boom");
    };
    const counts = await runBackfill(deps, { apply: true, currentYear: 2026 });
    assert.strictEqual(counts.failed, 1);
    assert.strictEqual(counts.grant, 0);
  });

  await test("a run that stops before the claim is redone in full by the next run", async () => {
    const { deps, claims, writes } = fakeDeps(users, docs, { failAuditOnce: true });
    const first = await runBackfill(deps, { apply: true, currentYear: 2026 });
    assert.strictEqual(first.failed, 1);
    assert.deepStrictEqual(claims, {});
    const second = await runBackfill(deps, { apply: true, currentYear: 2026 });
    assert.strictEqual(second.grant, 1);
    assert.strictEqual(second.failed, 0);
    assert.ok(writes.some((w) => w.path.startsWith("audit_logs/")));
    assert.deepStrictEqual(claims.adult, { admin: true, ageCompliant: true });
  });

  await test("hashUid matches functions/src/shared/hash-uid.ts", () => {
    assert.strictEqual(hashUid("abc"), "ba7816bf8f01");
  });

  const failed = results.filter((r) => !r.ok);
  for (const r of results) {
    console.log(`${r.ok ? "PASS" : "FAIL"} ${r.name}`);
    if (!r.ok) console.log(r.err);
  }
  console.log(`${results.length - failed.length}/${results.length} passed`);
  process.exit(failed.length ? 1 : 0);
})();
