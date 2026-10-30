/**
 * BUT-2452: `firestoreAllowlistDeps` against the Firestore emulator — the
 * switch read, expiry, and the transactional single-use consume.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/signup-allowlist.integration.test.ts
 */

const PROJECT_ID = "butlery-signup-allowlist-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import {
  INVITE_COLLECTION,
  firestoreAllowlistDeps,
  runSignupAllowlistWithDeps,
} from "../account/signup-allowlist";

const RUN = Date.now().toString(36);
let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

const deps = firestoreAllowlistDeps(db);
const ts = admin.firestore.Timestamp;

async function invite(email: string, expireInMs: number): Promise<void> {
  await db.collection(INVITE_COLLECTION).doc(email).set({
    invitedAt: ts.now(),
    invitedBy: "admin-uid",
    expireAt: ts.fromMillis(Date.now() + expireInMs),
  });
}

async function exists(email: string): Promise<boolean> {
  return (await db.collection(INVITE_COLLECTION).doc(email).get()).exists;
}

async function main(): Promise<void> {
  console.log("BUT-2452: signup allowlist emulator tests\n");

  await db.collection("system").doc("config").delete();
  check("missing system/config keeps the gate on", (await deps.gateEnabled()) === true);
  await db.collection("system").doc("config").set({ signupAllowlistEnabled: "false" });
  check("string 'false' keeps the gate on", (await deps.gateEnabled()) === true);
  await db.collection("system").doc("config").set({ signupAllowlistEnabled: false });
  check("exact false turns the gate off", (await deps.gateEnabled()) === false);
  await db.collection("system").doc("config").delete();

  const a = `a${RUN}@example.com`;
  await invite(a, 60_000);
  check("valid invite, consume=false → valid and kept",
    (await deps.checkInvite(a, false)) === "valid" && (await exists(a)));
  check("valid invite, consume=true → valid and deleted",
    (await deps.checkInvite(a, true)) === "valid" && !(await exists(a)));
  check("consumed invite → missing", (await deps.checkInvite(a, true)) === "missing");

  const b = `b${RUN}@example.com`;
  await invite(b, -1000);
  check("expired invite → expired and not deleted",
    (await deps.checkInvite(b, true)) === "expired" && (await exists(b)));

  // Two Google sign-ups racing for one invite: the transaction lets one pass.
  const c = `c${RUN}@example.com`;
  await invite(c, 60_000);
  const results = await Promise.allSettled([
    runSignupAllowlistWithDeps(deps, { uid: "r1", email: c, emailVerified: true }),
    runSignupAllowlistWithDeps(deps, { uid: "r2", email: c, emailVerified: true }),
  ]);
  const allowed = results.filter((r) => r.status === "fulfilled").length;
  check("two concurrent sign-ups for one invite → exactly one allowed", allowed === 1,
    `allowed=${allowed}`);
  const loser = results.find((r): r is PromiseRejectedResult => r.status === "rejected");
  check("the loser is refused as not invited",
    String(loser?.reason?.message).includes("SIGNUP_NOT_INVITED"),
    `reason=${loser?.reason?.message}`);
  check("the raced invite is gone", !(await exists(c)));

  console.log(`\n${run - failed}/${run} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

main().then(() => process.exit(0)).catch((err) => {
  console.error(err);
  process.exit(1);
});
