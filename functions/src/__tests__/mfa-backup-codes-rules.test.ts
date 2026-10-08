/**
 * Firestore rules tests for the two server-only MFA collections (BUT-2142,
 * item 4 of what remains before the enrolment button is shown again).
 *
 * `mfa_backup_codes/{uid}` holds the hashes of an account's backup codes, and
 * `mfa_recovery_attempts/{key}` holds the lockout counters that throttle
 * recovery. A client that could read the hashes could guess
 * codes offline; a client that could write either collection could plant its
 * own codes or reset a lockout. So every client verb is denied, including the
 * owner's own document.
 *
 * Prerequisite: Firestore emulator must be running locally
 * (`firebase emulators:start --only firestore --project demo-test`).
 *
 * Run with: npx ts-node src/__tests__/mfa-backup-codes-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-rules-mfa-backup-codes";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const OWNER_UID = "owner-uid";
const OTHER_UID = "other-uid";
const ADMIN_UID = "admin-uid";
// Shaped like the app's own keys (`uid_<uid>`, `global`), which a client can
// work out without the pepper.
const ATTEMPT_KEY = `uid_${OWNER_UID}`;
const ABSENT_ATTEMPT_KEY = "global";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
  });
  await env.clearFirestore();

  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    // An admin record, so the cases below also prove that being an admin
    // opens nothing here.
    await db.doc(`admins/${ADMIN_UID}`).set({ addedAt: new Date() });
    await db.doc(`mfa_backup_codes/${OWNER_UID}`).set({
      codes: [{ hash: "scrypt-hash", salt: "salt", usedAt: null }],
      createdAt: new Date(),
    });
    await db.doc(`mfa_recovery_attempts/${ATTEMPT_KEY}`).set({
      failures: 4,
      windowStart: Date.now(),
      lockedUntil: null,
    });
  });
}

async function teardown(): Promise<void> {
  if (env) await env.cleanup();
}

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

type Who = "owner" | "other" | "admin" | "signed out";

function db(who: Who) {
  switch (who) {
    case "owner":
      return env.authenticatedContext(OWNER_UID).firestore();
    case "other":
      return env.authenticatedContext(OTHER_UID).firestore();
    case "admin":
      return env.authenticatedContext(ADMIN_UID).firestore();
    case "signed out":
      return env.unauthenticatedContext().firestore();
  }
}

const everyone: Who[] = ["owner", "other", "admin", "signed out"];

for (const who of everyone) {
  test(`mfa_backup_codes: ${who} cannot read the hashes`, async () => {
    await assertFails(db(who).doc(`mfa_backup_codes/${OWNER_UID}`).get());
  });

  test(`mfa_backup_codes: ${who} cannot list the collection`, async () => {
    await assertFails(db(who).collection("mfa_backup_codes").get());
  });

  test(`mfa_backup_codes: ${who} cannot replace the codes`, async () => {
    await assertFails(
      db(who)
        .doc(`mfa_backup_codes/${OWNER_UID}`)
        .set({ codes: [{ hash: "planted", salt: "x", usedAt: null }] })
    );
  });

  test(`mfa_backup_codes: ${who} cannot create codes for a new account`, async () => {
    await assertFails(
      db(who)
        .doc(`mfa_backup_codes/${OTHER_UID}`)
        .set({ codes: [], createdAt: new Date() })
    );
  });

  test(`mfa_backup_codes: ${who} cannot delete the codes`, async () => {
    await assertFails(db(who).doc(`mfa_backup_codes/${OWNER_UID}`).delete());
  });

  test(`mfa_recovery_attempts: ${who} cannot read a counter`, async () => {
    await assertFails(
      db(who).doc(`mfa_recovery_attempts/${ATTEMPT_KEY}`).get()
    );
  });

  test(`mfa_recovery_attempts: ${who} cannot list the counters`, async () => {
    await assertFails(db(who).collection("mfa_recovery_attempts").get());
  });

  // Create is proven on a key no fixture writes.
  test(`mfa_recovery_attempts: ${who} cannot create a counter`, async () => {
    await env.withSecurityRulesDisabled(async (ctx) => {
      const snap = await ctx
        .firestore()
        .doc(`mfa_recovery_attempts/${ABSENT_ATTEMPT_KEY}`)
        .get();
      if (snap.exists) throw new Error("premise: the counter must be absent");
    });
    await assertFails(
      db(who)
        .doc(`mfa_recovery_attempts/${ABSENT_ATTEMPT_KEY}`)
        .set({ failures: -1000, windowStart: Date.now(), lockedUntil: null })
    );
  });

  test(`mfa_recovery_attempts: ${who} cannot reset a lockout`, async () => {
    await assertFails(
      db(who)
        .doc(`mfa_recovery_attempts/${ATTEMPT_KEY}`)
        .update({ failures: 0, lockedUntil: null })
    );
  });

  test(`mfa_recovery_attempts: ${who} cannot delete a counter`, async () => {
    await assertFails(
      db(who).doc(`mfa_recovery_attempts/${ATTEMPT_KEY}`).delete()
    );
  });
}

async function run(): Promise<void> {
  console.log("mfa_backup_codes + mfa_recovery_attempts rules tests (BUT-2142)\n");
  console.log("===============================================================\n");
  await setup();
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
  await teardown();
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
