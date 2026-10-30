/**
 * BUT-2419: tests for the staging seed's target check and its account seeding.
 *
 * Plain Node + node:assert, run by `npm run test:script-seed-staging`, which
 * run-ci-unit-tests.js discovers. Needs `npm run build` first: the seed loads
 * the compiled project gate from lib/.
 *
 * The refusals are also run against the real script in a child process with
 * every credential variable cleared, so they prove the script stops before
 * firebase-admin is initialized, not only that the check function throws.
 * Those runs also set GCLOUD_PROJECT to a project nothing may target: should
 * the seed's own check ever stop refusing, the sync and seed scripts it starts
 * refuse on that mismatch instead of reaching a real project from a test.
 */

const assert = require("assert");
const path = require("path");
const { spawnSync } = require("child_process");
const {
  checkStagingTarget,
  checkPassword,
  seedAccounts,
  TEST_ACCOUNTS,
} = require("../seed-staging.js");

const SCRIPT = path.resolve(__dirname, "../seed-staging.js");
const STAGING = "butlery-app-staging";

const results = [];
async function test(name, fn) {
  try {
    await fn();
    results.push({ name, ok: true });
  } catch (err) {
    results.push({ name, ok: false, err });
  }
}

function keyFiles(files) {
  return (p) => {
    if (!(p in files)) throw new Error(`ENOENT: ${p}`);
    return files[p];
  };
}

function runScript(args, extraEnv = {}) {
  const env = { ...process.env, ...extraEnv };
  for (const name of [
    "GOOGLE_APPLICATION_CREDENTIALS",
    "GOOGLE_CLOUD_PROJECT",
    "GCLOUD_PROJECT",
    "FIREBASE_CONFIG",
  ]) {
    if (!(name in extraEnv)) delete env[name];
  }
  return spawnSync(process.execPath, [SCRIPT, ...args], { env, encoding: "utf8" });
}

function fakeAuth(existing) {
  const users = new Map(existing.map((u) => [u.email, { ...u }]));
  const calls = [];
  let next = 0;
  return {
    calls,
    users,
    async getUserByEmail(email) {
      const user = users.get(email);
      if (!user) {
        const err = new Error("not found");
        err.code = "auth/user-not-found";
        throw err;
      }
      return { ...user };
    },
    async updateUser(uid, props) {
      calls.push(["updateUser", uid, props]);
      const user = [...users.values()].find((u) => u.uid === uid);
      Object.assign(user, props);
      return { ...user };
    },
    async createUser(props) {
      const user = { uid: `new-${next++}`, customClaims: undefined, ...props };
      calls.push(["createUser", props.email]);
      users.set(props.email, user);
      return { ...user };
    },
    async setCustomUserClaims(uid, claims) {
      calls.push(["setCustomUserClaims", uid, claims]);
      const user = [...users.values()].find((u) => u.uid === uid);
      user.customClaims = claims;
    },
  };
}

(async () => {
  await test("target check: only butlery-app-staging passes", () => {
    assert.strictEqual(checkStagingTarget({ argv: ["--project", STAGING], env: {} }), STAGING);
    assert.strictEqual(checkStagingTarget({ argv: [`--project=${STAGING}`], env: {} }), STAGING);
  });

  await test("target check: an emulator host is refused", () => {
    for (const name of [
      "FIRESTORE_EMULATOR_HOST",
      "FIREBASE_AUTH_EMULATOR_HOST",
      "FIREBASE_STORAGE_EMULATOR_HOST",
    ]) {
      assert.throws(
        () => checkStagingTarget({ argv: ["--project", STAGING], env: { [name]: "localhost:1" } }),
        new RegExp(name),
      );
    }
  });

  await test("target check: missing, empty, production and demo- are refused", () => {
    for (const argv of [
      [],
      ["--project"],
      ["--project", ""],
      ["--project", "butlery-prod"],
      ["--project", "demo-butlery"],
      ["--project", "butlery-app-staging-2"],
    ]) {
      assert.throws(
        () => checkStagingTarget({ argv, env: {} }),
        /^Error: REFUSED: /,
        `argv ${JSON.stringify(argv)}`,
      );
    }
  });

  await test("target check: an environment or key naming production is refused", () => {
    const argv = ["--project", STAGING];
    assert.throws(
      () => checkStagingTarget({ argv, env: { GCLOUD_PROJECT: "butlery-prod" } }),
      /GCLOUD_PROJECT/,
    );
    assert.throws(
      () => checkStagingTarget({ argv, env: { GOOGLE_CLOUD_PROJECT: "butlery-prod" } }),
      /GOOGLE_CLOUD_PROJECT/,
    );
    const readFile = keyFiles({
      "prod.json": JSON.stringify({ type: "service_account", project_id: "butlery-prod" }),
      "staging.json": JSON.stringify({ type: "service_account", project_id: STAGING }),
    });
    assert.throws(
      () =>
        checkStagingTarget({
          argv,
          env: { GOOGLE_APPLICATION_CREDENTIALS: "prod.json" },
          readFile,
        }),
      /key for "butlery-prod"/,
    );
    assert.strictEqual(
      checkStagingTarget({
        argv,
        env: { GOOGLE_APPLICATION_CREDENTIALS: "staging.json" },
        readFile,
      }),
      STAGING,
    );
  });

  await test("the script refuses before initializing anything", () => {
    for (const [args, reason] of [
      [[], /REFUSED: pass the target explicitly/],
      [["--project", "butlery-prod"], /REFUSED: "butlery-prod" is not a project/],
      [["--project", "demo-butlery"], /REFUSED: "demo-butlery" is not a project/],
      [["--project", ""], /REFUSED: --project was given without a project id/],
    ]) {
      const run = runScript(args, {
        GCLOUD_PROJECT: "tripwire-not-a-target",
        STAGING_TEST_PASSWORD: "long-enough-password",
      });
      assert.strictEqual(run.status, 1, `exit for ${JSON.stringify(args)}: ${run.stderr}`);
      assert.match(run.stderr, reason);
      assert.doesNotMatch(run.stdout + run.stderr, /Target project|Ingredient Sync|Tag Config/);
    }
  });

  await test("the script refuses staging when GCLOUD_PROJECT names production", () => {
    const run = runScript(["--project", STAGING], {
      GCLOUD_PROJECT: "butlery-prod",
      STAGING_TEST_PASSWORD: "long-enough-password",
    });
    assert.strictEqual(run.status, 1);
    assert.match(run.stderr, /REFUSED: GCLOUD_PROJECT/);
  });

  await test("a missing or short password is refused", () => {
    assert.throws(() => checkPassword({}), /STAGING_TEST_PASSWORD/);
    assert.throws(() => checkPassword({ STAGING_TEST_PASSWORD: "short" }), /STAGING_TEST_PASSWORD/);
    assert.strictEqual(
      checkPassword({ STAGING_TEST_PASSWORD: "long-enough-password" }),
      "long-enough-password",
    );
  });

  await test("accounts: the three synthetic addresses, each ageCompliant", async () => {
    assert.deepStrictEqual(TEST_ACCOUNTS, [
      "test+1@butlery.se",
      "test+2@butlery.se",
      "test+3@butlery.se",
    ]);
    const auth = fakeAuth([]);
    const outcomes = await seedAccounts(auth, "long-enough-password");
    assert.deepStrictEqual(
      outcomes.map((o) => [o.email, o.created]),
      TEST_ACCOUNTS.map((e) => [e, true]),
    );
    for (const email of TEST_ACCOUNTS) {
      const user = auth.users.get(email);
      assert.strictEqual(user.customClaims.ageCompliant, true, email);
      assert.strictEqual(user.password, "long-enough-password");
      assert.strictEqual(user.emailVerified, true);
    }
  });

  await test("accounts: a re-run updates instead of duplicating, keeping other claims", async () => {
    const auth = fakeAuth([
      { uid: "u1", email: "test+1@butlery.se", customClaims: { admin: true } },
    ]);
    const outcomes = await seedAccounts(auth, "another-long-password");
    assert.strictEqual(outcomes[0].created, false);
    assert.strictEqual(outcomes[0].uid, "u1");
    assert.deepStrictEqual(auth.users.get("test+1@butlery.se").customClaims, {
      admin: true,
      ageCompliant: true,
    });
    assert.strictEqual(
      auth.calls.filter((c) => c[0] === "createUser").length,
      TEST_ACCOUNTS.length - 1,
    );
  });

  await test("accounts: an Auth error other than not-found is not swallowed", async () => {
    const auth = fakeAuth([]);
    auth.getUserByEmail = async () => {
      const err = new Error("quota");
      err.code = "auth/quota-exceeded";
      throw err;
    };
    await assert.rejects(() => seedAccounts(auth, "long-enough-password"), /quota/);
    assert.strictEqual(auth.calls.length, 0);
  });

  const failed = results.filter((r) => !r.ok);
  for (const r of results) {
    console.log(`${r.ok ? "PASS" : "FAIL"} ${r.name}`);
    if (!r.ok) console.log(r.err);
  }
  console.log(`${results.length - failed.length}/${results.length} passed`);
  process.exit(failed.length ? 1 : 0);
})();
