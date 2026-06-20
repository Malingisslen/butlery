/**
 * Emulator-backed integration test for the pre-release-audit B1
 * `acceptFriendRequest` callable core (`acceptFriendRequestWithDeps`).
 *
 * Runs against a REAL Firestore emulator so the transaction semantics —
 * mutual friend-doc writes, request status flip, and `friendsCount`
 * increment-only-when-both-created — are exercised for real, including the
 * idempotency guarantee (re-accept does NOT double-count).
 *
 * The Admin SDK bypasses rules, so seeding is plain writes. Pointing Admin at
 * the emulator only needs `FIRESTORE_EMULATOR_HOST` set BEFORE
 * `admin.initializeApp`.
 *
 * Prerequisite: Firestore emulator running locally
 * (`bash .claude/hooks/ensure-firestore-emulator.sh`).
 *
 * Run: npx ts-node src/__tests__/accept-friend-request.integration.test.ts
 */

const PROJECT_ID = "butlery-accept-friend-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

// eslint-disable-next-line @typescript-eslint/no-require-imports
import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  acceptFriendRequestWithDeps,
} = require("../social/accept-friend-request");

// Per-run suffix so re-runs against a non-wiped emulator don't collide.
const RUN = Date.now().toString(36);

let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

async function expectThrows(
  name: string,
  fn: () => Promise<unknown>,
  codeIncludes?: string,
): Promise<void> {
  try {
    await fn();
    check(name, false, "expected a throw, but it resolved");
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    const code = (err as { code?: string }).code ?? "";
    const ok = codeIncludes ? code.includes(codeIncludes) : true;
    check(name, ok, ok ? undefined : `wrong error: code=${code} msg=${msg}`);
  }
}

async function seedRequest(
  requestId: string,
  fromUserId: string,
  toUserId: string,
  status: string,
): Promise<void> {
  await db.collection("social_requests").doc(requestId).set({
    fromUserId,
    toUserId,
    status,
    sentAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

async function seedProfile(uid: string, displayName: string): Promise<void> {
  await db.collection("public_profiles").doc(uid).set({
    displayName,
    friendsCount: 0,
  });
}

async function friendsCount(uid: string): Promise<number> {
  const snap = await db.collection("public_profiles").doc(uid).get();
  return (snap.data()?.friendsCount as number | undefined) ?? -1;
}

async function friendDocExists(ownerUid: string, friendUid: string): Promise<boolean> {
  const snap = await db
    .collection("users").doc(ownerUid)
    .collection("friends").doc(friendUid)
    .get();
  return snap.exists;
}

async function run_(): Promise<void> {
  console.log("acceptFriendRequest integration tests (pre-release audit B1)\n");
  console.log("=============================\n");

  // ── Happy path: recipient accepts a pending request ──
  {
    const from = `from-happy-${RUN}`;
    const to = `to-happy-${RUN}`;
    const reqId = `req-happy-${RUN}`;
    await seedProfile(from, "Alice");
    await seedProfile(to, "Bob");
    await seedRequest(reqId, from, to, "pending");

    const res = await acceptFriendRequestWithDeps(db, to, reqId);
    check("happy: returns success, not alreadyFriends", res.success === true && res.alreadyFriends === false,
      JSON.stringify(res));
    check("happy: from→to friend doc created", await friendDocExists(from, to));
    check("happy: to→from friend doc created", await friendDocExists(to, from));
    const reqSnap = await db.collection("social_requests").doc(reqId).get();
    check("happy: request marked accepted", reqSnap.data()?.status === "accepted");
    check("happy: from friendsCount incremented to 1", (await friendsCount(from)) === 1);
    check("happy: to friendsCount incremented to 1", (await friendsCount(to)) === 1);

    // ── Idempotency: re-accepting must NOT double-count ──
    const res2 = await acceptFriendRequestWithDeps(db, to, reqId);
    check("idempotent: reports alreadyFriends", res2.alreadyFriends === true);
    check("idempotent: from friendsCount still 1", (await friendsCount(from)) === 1);
    check("idempotent: to friendsCount still 1", (await friendsCount(to)) === 1);
  }

  // ── Only the recipient may accept ──
  {
    const from = `from-perm-${RUN}`;
    const to = `to-perm-${RUN}`;
    const reqId = `req-perm-${RUN}`;
    await seedProfile(from, "Alice");
    await seedProfile(to, "Bob");
    await seedRequest(reqId, from, to, "pending");
    // The SENDER tries to accept their own outbound request.
    await expectThrows(
      "rejects acceptance by a non-recipient (sender)",
      () => acceptFriendRequestWithDeps(db, from, reqId),
      "permission-denied",
    );
    check("non-recipient: no friend doc created", !(await friendDocExists(from, to)));
  }

  // ── Non-pending request is rejected ──
  {
    const from = `from-stale-${RUN}`;
    const to = `to-stale-${RUN}`;
    const reqId = `req-stale-${RUN}`;
    await seedProfile(from, "Alice");
    await seedProfile(to, "Bob");
    await seedRequest(reqId, from, to, "rejected");
    await expectThrows(
      "rejects a rejected/expired request",
      () => acceptFriendRequestWithDeps(db, to, reqId),
      "failed-precondition",
    );
  }

  // ── Missing request is rejected ──
  {
    await expectThrows(
      "rejects a missing request",
      () => acceptFriendRequestWithDeps(db, `nobody-${RUN}`, `ghost-${RUN}`),
      "not-found",
    );
  }

  console.log(`\n${run - failed}/${run} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
