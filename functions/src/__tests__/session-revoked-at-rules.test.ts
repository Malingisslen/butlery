/**
 * BUT-2481 — `users/{uid}.sessionsRevokedAt` is written only by the
 * `revokeOtherSessions` Cloud Function (Admin SDK). The owner may read it and
 * keep saving the rest of their profile, but may not create, forge or change
 * it, or clear it in place. Deleting the whole profile document and creating it
 * again does clear it; the KNOWN GAP case pins that.
 *
 * Prerequisite: Firestore emulator on 127.0.0.1:8080.
 * Run: npx ts-node src/__tests__/session-revoked-at-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import { deleteField, Timestamp } from "firebase/firestore";

const PROJECT_ID = "butlery-session-revoked-at-test";
const RULES_PATH = path.resolve(__dirname, "../../../firestore.rules");
const UID = "user-a";
const OTHER = "user-b";
const REVOKED = Timestamp.fromMillis(1_800_000_000_000);

let env: RulesTestEnvironment;
let n = 0;
const tests: { name: string; fn: () => Promise<void> }[] = [];
const test = (name: string, fn: () => Promise<void>) => tests.push({ name, fn });

// A fresh uid per case: the emulator keeps documents between cases.
const fresh = () => `${UID}-${++n}`;
const profile = (uid: string, as = uid) =>
  env.authenticatedContext(as).firestore().doc(`users/${uid}`);
const seed = (uid: string, data: Record<string, unknown>) =>
  env.withSecurityRulesDisabled(async (ctx) => {
    await ctx.firestore().doc(`users/${uid}`).set(data);
  });

test("owner can create a profile without sessionsRevokedAt", async () => {
  await assertSucceeds(profile(fresh()).set({ displayName: "Anna" }));
});
test("owner CANNOT create a profile carrying sessionsRevokedAt", async () => {
  await assertFails(profile(fresh()).set({ displayName: "Anna", sessionsRevokedAt: REVOKED }));
});
test("owner CANNOT add sessionsRevokedAt to an existing profile", async () => {
  const uid = fresh();
  await seed(uid, { displayName: "Anna" });
  await assertFails(profile(uid).update({ sessionsRevokedAt: REVOKED }));
});
test("owner CANNOT change a server-set sessionsRevokedAt", async () => {
  const uid = fresh();
  await seed(uid, { displayName: "Anna", sessionsRevokedAt: REVOKED });
  await assertFails(profile(uid).update({ sessionsRevokedAt: Timestamp.fromMillis(1) }));
});
test("owner CANNOT remove a server-set sessionsRevokedAt", async () => {
  const uid = fresh();
  await seed(uid, { displayName: "Anna", sessionsRevokedAt: REVOKED });
  await assertFails(profile(uid).update({ sessionsRevokedAt: deleteField() }));
});
test("owner can still save other profile fields while it is set, and read it", async () => {
  const uid = fresh();
  await seed(uid, { displayName: "Anna", sessionsRevokedAt: REVOKED });
  await assertSucceeds(profile(uid).update({ displayName: "Anna B" }));
  const snap = await assertSucceeds(profile(uid).get());
  if (!snap.data()?.sessionsRevokedAt) throw new Error("owner could not read it");
});
test("owner can update a profile that never had it", async () => {
  const uid = fresh();
  await seed(uid, { displayName: "Anna" });
  await assertSucceeds(profile(uid).update({ displayName: "Anna B" }));
});
test("KNOWN GAP: deleting the profile and creating it again clears it", async () => {
  // Accepted deviation (BUT-2481): the owner may delete users/{uid}, so the
  // stamp cannot be made tamper-proof there. Revisit if this turns false.
  const uid = fresh();
  await seed(uid, { displayName: "Anna", sessionsRevokedAt: REVOKED });
  await assertSucceeds(profile(uid).delete());
  await assertSucceeds(profile(uid).set({ displayName: "Anna" }));
  const snap = await assertSucceeds(profile(uid).get());
  if (snap.data()?.sessionsRevokedAt) throw new Error("stamp survived: gap closed");
});
test("a stale merge save that omits it leaves it in place", async () => {
  const uid = fresh();
  await seed(uid, { displayName: "Anna", sessionsRevokedAt: REVOKED });
  await assertSucceeds(profile(uid).set({ displayName: "Anna B" }, { merge: true }));
  const snap = await assertSucceeds(profile(uid).get());
  if (!snap.data()?.sessionsRevokedAt) throw new Error("merge save dropped the stamp");
});
test("another user cannot read it", async () => {
  const uid = fresh();
  await seed(uid, { displayName: "Anna", sessionsRevokedAt: REVOKED });
  await assertFails(profile(uid, OTHER).get());
});

async function main(): Promise<void> {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: { rules: fs.readFileSync(RULES_PATH, "utf8"), host: "127.0.0.1", port: 8080 },
  });
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (e) {
      failed++;
      console.log(`  FAIL  ${t.name}\n        ${e instanceof Error ? e.message : e}`);
    }
  }
  await env.cleanup();
  console.log(`\n${tests.length - failed}/${tests.length} passed`);
  if (failed) process.exit(1);
}
void main();
