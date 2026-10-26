/**
 * BUT-2452: rules for `signup_allowlist/{email}` — admin-only, create or
 * delete, never edit, and a create carries exactly the three fields with a
 * server time, the caller's own uid and an expiry at most 30 days out.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/signup-allowlist-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
// The client-SDK sentinel; the rules emulator does not recognise admin's.
import { Timestamp, serverTimestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-rules-signup-allowlist";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");
const ADMIN_UID = "admin-uid";
const USER_UID = "user-a";
const DAY_MS = 24 * 60 * 60 * 1000;

let env: RulesTestEnvironment;
let seq = 0;
const nextEmail = () => `invitee${seq++}@example.com`;

function invite(over: Record<string, unknown> = {}, uid = ADMIN_UID): Record<string, unknown> {
  return {
    invitedAt: serverTimestamp(),
    invitedBy: uid,
    expireAt: Timestamp.fromDate(new Date(Date.now() + 30 * DAY_MS)),
    ...over,
  };
}

const adminDb = () => env.authenticatedContext(ADMIN_UID).firestore();
const userDb = () => env.authenticatedContext(USER_UID).firestore();
const anonDb = () => env.unauthenticatedContext().firestore();

async function seed(email: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`signup_allowlist/${email}`).set({
      invitedAt: Timestamp.now(),
      invitedBy: ADMIN_UID,
      expireAt: Timestamp.fromDate(new Date(Date.now() + DAY_MS)),
    });
  });
}

const tests: Array<{ name: string; fn: () => Promise<void> }> = [];
const test = (name: string, fn: () => Promise<void>) => tests.push({ name, fn });

test("ALLOW: admin creates a well-formed invite", async () => {
  await assertSucceeds(adminDb().doc(`signup_allowlist/${nextEmail()}`).set(invite()));
});

test("ALLOW: admin creates with a plus-address", async () => {
  await assertSucceeds(adminDb().doc("signup_allowlist/anna+test@example.com").set(invite()));
});

test("ALLOW: admin lists and reads", async () => {
  const email = nextEmail();
  await seed(email);
  await assertSucceeds(adminDb().collection("signup_allowlist").get());
  await assertSucceeds(adminDb().doc(`signup_allowlist/${email}`).get());
});

test("ALLOW: admin deletes", async () => {
  const email = nextEmail();
  await seed(email);
  await assertSucceeds(adminDb().doc(`signup_allowlist/${email}`).delete());
});

test("DENY: admin update", async () => {
  const email = nextEmail();
  await seed(email);
  await assertFails(adminDb().doc(`signup_allowlist/${email}`).update({
    expireAt: Timestamp.fromDate(new Date(Date.now() + 2 * DAY_MS)),
  }));
});

test("DENY: non-admin create, read, list, delete", async () => {
  const email = nextEmail();
  await seed(email);
  await assertFails(userDb().doc(`signup_allowlist/${nextEmail()}`).set(invite({}, USER_UID)));
  await assertFails(userDb().doc(`signup_allowlist/${email}`).get());
  await assertFails(userDb().collection("signup_allowlist").get());
  await assertFails(userDb().doc(`signup_allowlist/${email}`).delete());
});

test("DENY: anonymous create, read, list, delete", async () => {
  const email = nextEmail();
  await seed(email);
  await assertFails(anonDb().doc(`signup_allowlist/${nextEmail()}`).set(invite()));
  await assertFails(anonDb().doc(`signup_allowlist/${email}`).get());
  await assertFails(anonDb().collection("signup_allowlist").get());
  await assertFails(anonDb().doc(`signup_allowlist/${email}`).delete());
});

test("DENY: extra key", async () => {
  await assertFails(adminDb().doc(`signup_allowlist/${nextEmail()}`).set(invite({ name: "Anna" })));
});

test("DENY: missing key", async () => {
  const data = invite();
  delete data.expireAt;
  await assertFails(adminDb().doc(`signup_allowlist/${nextEmail()}`).set(data));
});

test("DENY: upper-case id", async () => {
  await assertFails(adminDb().doc("signup_allowlist/Anna@example.com").set(invite()));
});

test("DENY: id with whitespace", async () => {
  await assertFails(adminDb().doc("signup_allowlist/ anna@example.com").set(invite()));
  await assertFails(adminDb().doc("signup_allowlist/an na@example.com").set(invite()));
  await assertFails(adminDb().doc("signup_allowlist/an\tna@example.com").set(invite()));
});

test("ALLOW: an id of exactly 254 characters", async () => {
  await assertSucceeds(adminDb().doc(`signup_allowlist/${"a".repeat(242)}@example.com`).set(invite()));
});

test("DENY: an id of 255 characters", async () => {
  await assertFails(adminDb().doc(`signup_allowlist/${"a".repeat(243)}@example.com`).set(invite()));
});

test("DENY: id that is not an address", async () => {
  await assertFails(adminDb().doc("signup_allowlist/anna.example.com").set(invite()));
});

test("DENY: id whose domain has no dot", async () => {
  await assertFails(adminDb().doc("signup_allowlist/anna@example").set(invite()));
});

test("DENY: id with two @", async () => {
  await assertFails(adminDb().doc("signup_allowlist/anna@b@example.com").set(invite()));
});

test("DENY: forged invitedBy", async () => {
  await assertFails(adminDb().doc(`signup_allowlist/${nextEmail()}`).set(invite({ invitedBy: USER_UID })));
});

test("DENY: client-clock invitedAt", async () => {
  await assertFails(adminDb().doc(`signup_allowlist/${nextEmail()}`).set(invite({ invitedAt: Timestamp.now() })));
});

test("DENY: past expireAt", async () => {
  await assertFails(adminDb().doc(`signup_allowlist/${nextEmail()}`).set(
    invite({ expireAt: Timestamp.fromDate(new Date(Date.now() - 60_000)) })));
});

test("DENY: expireAt beyond 30 days", async () => {
  await assertFails(adminDb().doc(`signup_allowlist/${nextEmail()}`).set(
    invite({ expireAt: Timestamp.fromDate(new Date(Date.now() + 31 * DAY_MS)) })));
});

test("DENY: non-timestamp expireAt", async () => {
  await assertFails(adminDb().doc(`signup_allowlist/${nextEmail()}`).set(
    invite({ expireAt: Date.now() + DAY_MS })));
});

test("DENY: client write to system/config (the kill switch)", async () => {
  await assertFails(adminDb().doc("system/config").set({ signupAllowlistEnabled: false }));
  await assertFails(userDb().doc("system/config").set({ signupAllowlistEnabled: false }));
});

async function run(): Promise<void> {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync(RULES_PATH, "utf8"), host: "127.0.0.1", port: 8080 },
  });
  await env.clearFirestore();
  await env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`admins/${ADMIN_UID}`).set({ addedAt: new Date() });
  });

  console.log("BUT-2452: signup_allowlist rules\n");
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
  await env.cleanup();
  console.log(`\n${tests.length - failed}/${tests.length} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
