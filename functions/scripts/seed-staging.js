#!/usr/bin/env node
/**
 * Fills the STAGING project with what the app needs to run end to end: the
 * ingredient database, the tag configs, and three synthetic accounts
 * (`test+1@butlery.se` … `test+3@butlery.se`) that already carry the
 * `ageCompliant` claim `verifySignupAge` would set (BUT-451, BUT-2419).
 *
 * It targets `butlery-app-staging` and nothing else. The target check runs
 * before firebase-admin is initialized, so a refusal has opened no connection.
 * It writes only to the target and reads nothing from production: the data
 * comes from the files in this repo, through the same sync and seed scripts
 * production uses, run as child processes that pass the same project gate.
 *
 * Usage (from functions/, after `npm run build`):
 *   STAGING_TEST_PASSWORD=<password> \
 *     node scripts/seed-staging.js --project butlery-app-staging
 *
 * Re-running is safe: the sync applies only the diff, the tag configs are
 * overwritten with the same content, and an existing account gets its password
 * and claim set again rather than a second account.
 */
"use strict";

const path = require("path");
const { spawnSync } = require("child_process");
const { requireProject, STAGING_PROJECT } = require("../lib/admin/require-project");

const TEST_ACCOUNTS = ["test+1@butlery.se", "test+2@butlery.se", "test+3@butlery.se"];
const MIN_PASSWORD_LENGTH = 12;
const LIB_ADMIN_DIR = path.resolve(__dirname, "../lib/admin");

const EMULATOR_HOST_VARS = [
  "FIRESTORE_EMULATOR_HOST",
  "FIREBASE_AUTH_EMULATOR_HOST",
  "FIREBASE_STORAGE_EMULATOR_HOST",
];

function checkStagingTarget({ argv, env = process.env, readFile } = {}) {
  // An emulator host silently redirects the writes, so the run would report
  // staging as seeded while staging stays empty.
  const emulators = EMULATOR_HOST_VARS.filter((name) => env[name]);
  if (emulators.length > 0) {
    throw new Error(
      `REFUSED: ${emulators.join(", ")} is set, so the seed would reach an ` +
        "emulator, not staging. Unset it. Nothing has been initialized.",
    );
  }
  return requireProject({ argv, env, readFile, allowed: [STAGING_PROJECT] });
}

function checkPassword(env) {
  const password = env.STAGING_TEST_PASSWORD || "";
  if (password.length < MIN_PASSWORD_LENGTH) {
    throw new Error(
      `REFUSED: set STAGING_TEST_PASSWORD (at least ${MIN_PASSWORD_LENGTH} ` +
        "characters) for the synthetic accounts. Nothing has been initialized.",
    );
  }
  return password;
}

function runAdminScript(script, args) {
  const result = spawnSync(process.execPath, [path.join(LIB_ADMIN_DIR, script), ...args], {
    stdio: "inherit",
  });
  if (result.status !== 0) {
    throw new Error(`${script} exited with ${result.status ?? result.signal}`);
  }
}

/**
 * Creates each synthetic account or, when it exists, resets its password.
 * Claims are merged so a claim set by hand in staging survives a re-seed.
 */
async function seedAccounts(auth, password) {
  const outcomes = [];
  for (const email of TEST_ACCOUNTS) {
    let user;
    let created = false;
    try {
      user = await auth.getUserByEmail(email);
      user = await auth.updateUser(user.uid, { password, emailVerified: true });
    } catch (err) {
      if (!err || err.code !== "auth/user-not-found") throw err;
      user = await auth.createUser({ email, password, emailVerified: true });
      created = true;
    }
    await auth.setCustomUserClaims(user.uid, {
      ...(user.customClaims || {}),
      ageCompliant: true,
    });
    outcomes.push({ email, uid: user.uid, created });
  }
  return outcomes;
}

async function main() {
  const projectId = checkStagingTarget();
  const password = checkPassword(process.env);
  const projectArgs = ["--project", projectId];

  runAdminScript("sync-ingredients.js", [...projectArgs, "--force"]);
  runAdminScript("seed-tag-configs.js", projectArgs);

  const { initializeAdminApp } = require("../lib/admin/admin-init");
  const app = initializeAdminApp({ allowed: [STAGING_PROJECT] });
  const outcomes = await seedAccounts(app.auth(), password);
  for (const { email, created } of outcomes) {
    console.log(`  ${created ? "created" : "updated"} ${email}`);
  }
  console.log(`Seeded ${projectId}.`);
}

if (require.main === module) {
  main().catch((err) => {
    console.error(err instanceof Error ? err.message : err);
    process.exit(1);
  });
}

module.exports = { checkStagingTarget, checkPassword, seedAccounts, TEST_ACCOUNTS };
