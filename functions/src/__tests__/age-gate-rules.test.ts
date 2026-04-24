/**
 * Firestore rules tests for the GDPR Art 8 age gate.
 *
 * Rules contract under test (users/{uid}/settings/{settingId}):
 *   - On CREATE of the `preferences` doc, birthYear must be a valid int
 *     in [1900, currentYear-13]. Absence rejects the write.
 *   - On UPDATE, birthYear may be absent (backfill / legacy flow) OR a
 *     valid int in the same range. Invalid values reject the write.
 *   - Other settings docs (if any appear later) are unaffected.
 *
 * Prerequisite: Firestore emulator must be running locally
 *   (`firebase emulators:start --only firestore`).
 *
 * Run with: npx ts-node src/__tests__/age-gate-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";

const PROJECT_ID = "butlery-age-gate-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");

const USER_UID = "user-a";
const OTHER_UID = "user-b";

let env: RulesTestEnvironment;

async function setup(): Promise<void> {
  const rules = fs.readFileSync(RULES_PATH, "utf8");
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules, host: "127.0.0.1", port: 8080 },
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

// Test 1: create preferences doc without birthYear -> rejected.
test(
  "create preferences requires birthYear",
  async () => {
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${USER_UID}/settings/preferences`)
        .set({
          notificationsEnabled: true,
          hasCompletedOnboarding: true,
        })
    );
  }
);

// Test 2: create preferences doc with valid birthYear -> allowed.
test(
  "create preferences with birthYear=currentYear-20 is allowed",
  async () => {
    const ctx = env.authenticatedContext(USER_UID);
    const year = new Date().getFullYear() - 20;
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${USER_UID}/settings/preferences`)
        .set({
          notificationsEnabled: true,
          hasCompletedOnboarding: true,
          birthYear: year,
        })
    );
  }
);

// Test 3: create preferences with birthYear=currentYear (age 0) -> rejected.
test(
  "create preferences with birthYear=currentYear (age 0) is rejected",
  async () => {
    const ctx = env.authenticatedContext(USER_UID);
    const year = new Date().getFullYear();
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${USER_UID}/settings/preferences`)
        .set({
          notificationsEnabled: true,
          birthYear: year,
        })
    );
  }
);

// Test 4: update existing preferences without birthYear is allowed (legacy backfill).
test(
  "update preferences without birthYear is allowed for backfilled users",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${USER_UID}/settings/preferences`)
        .set({
          notificationsEnabled: true,
          hasCompletedOnboarding: false,
          // intentionally no birthYear — simulates a pre-gate user
        });
    });
    const ctx = env.authenticatedContext(USER_UID);
    // Fire a normal settings flip (toggle notifications) — should NOT be
    // blocked by the birthYear validator.
    await assertSucceeds(
      ctx
        .firestore()
        .doc(`users/${USER_UID}/settings/preferences`)
        .set({ notificationsEnabled: false }, { merge: true })
    );
  }
);

// Test 5: update with invalid birthYear -> rejected.
test(
  "update with invalid birthYear (too young) is rejected",
  async () => {
    await env.withSecurityRulesDisabled(async (admin) => {
      await admin
        .firestore()
        .doc(`users/${USER_UID}/settings/preferences`)
        .set({ notificationsEnabled: true });
    });
    const ctx = env.authenticatedContext(USER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${USER_UID}/settings/preferences`)
        .set({ birthYear: new Date().getFullYear() }, { merge: true })
    );
  }
);

// Test 6: other users cannot write your preferences regardless of birthYear.
test(
  "cross-user writes to another user's preferences are rejected",
  async () => {
    const ctx = env.authenticatedContext(OTHER_UID);
    await assertFails(
      ctx
        .firestore()
        .doc(`users/${USER_UID}/settings/preferences`)
        .set({
          notificationsEnabled: true,
          birthYear: new Date().getFullYear() - 30,
        })
    );
  }
);

async function run(): Promise<void> {
  console.log("Age-gate rules tests\n");
  console.log("=============================\n");
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
