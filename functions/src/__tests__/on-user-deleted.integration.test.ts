/**
 * BUT-1354 — emulator-backed integration test for the user-deletion social
 * cascade core (`cleanupUserSocialData`).
 *
 * `onUserDeleted` is a v1 auth trigger whose body delegates to
 * `cleanupUserSocialData(userId)`. The trigger itself can't be fired in a unit
 * test, so we exercise the extracted core against a REAL Firestore emulator.
 *
 * The cascade reads/writes via the module-level `db = admin.firestore()`. With
 * `FIRESTORE_EMULATOR_HOST` set BEFORE `admin.initializeApp` and the module
 * required afterwards, that `db` is emulator-bound — so no Firestore parameter
 * is needed. The Admin SDK bypasses rules → seeding is plain writes.
 *
 * This suite asserts a representative slice of the cascade (the steps that map
 * to seeded fixtures) with POSITIVE effect + SCOPE-CONTROL assertions:
 *   - reverse friendship doc in another user's friends subcollection removed;
 *     an unrelated friend's reverse doc retained.
 *   - social_requests (sent + received) involving the user deleted; an
 *     unrelated request retained.
 *   - friendsCount on the remaining friend's public_profile decremented.
 *   - feedback authored by the user deleted; another user's feedback retained.
 *   - public_profile of the deleted user deleted.
 * It also asserts the returned per-step summary counts.
 *
 * Per-run isolation: unique PROJECT_ID per suite + a per-run id suffix on every
 * seeded id.
 *
 * Prerequisite: Firestore emulator running locally
 * (`bash .claude/hooks/ensure-firestore-emulator.sh`).
 *
 * Run: npx ts-node src/__tests__/on-user-deleted.integration.test.ts
 */

import { requireEmulatorsOrSkip } from "./integration-gate";

const PROJECT_ID = "butlery-on-user-deleted-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

// eslint-disable-next-line @typescript-eslint/no-require-imports
import * as admin from "firebase-admin";

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

async function run_(): Promise<void> {
  console.log("onUserDeleted social-cascade integration tests (BUT-1354)\n");
  console.log("=============================\n");

  await requireEmulatorsOrSkip(
    [{ name: "Firestore", hostPort: EMULATOR_HOST }],
    "bash .claude/hooks/ensure-firestore-emulator.sh",
  );

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();

  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { cleanupUserSocialData } = require("../cleanup/on-user-deleted");

  // ── Subject + collaborators ──
  const victim = `victim-${RUN}`;
  const friend = `friend-${RUN}`;
  const otherUser = `other-${RUN}`;

  // 1. Friendship: victim has `friend` in their friends list; `friend` has the
  //    reverse doc pointing at victim. An unrelated friend↔other edge is the
  //    scope control.
  await db.collection("users").doc(victim)
    .collection("friends").doc(friend).set({ addedAt: Date.now() });
  await db.collection("users").doc(friend)
    .collection("friends").doc(victim).set({ addedAt: Date.now() });
  const controlReverseRef = db.collection("users").doc(friend)
    .collection("friends").doc(otherUser);
  await controlReverseRef.set({ addedAt: Date.now() });

  // friend's public_profile so the friendsCount decrement has a target.
  await db.collection("public_profiles").doc(friend).set({ friendsCount: 3 });
  // victim's own public_profile (deleted by step 7).
  await db.collection("public_profiles").doc(victim).set({ friendsCount: 1 });

  // BUT-1582: a second friend with a reverse edge but NO public_profiles doc
  // (orphaned edge / peer mid-deletion). It shares the victim's single cleanup
  // chunk with `friend`, so if the missing profile poisoned the batch commit,
  // `friend` would never be decremented either. Deliberately no public_profile.
  const friendNoProfile = `friendnp-${RUN}`;
  await db.collection("users").doc(victim)
    .collection("friends").doc(friendNoProfile).set({ addedAt: Date.now() });
  await db.collection("users").doc(friendNoProfile)
    .collection("friends").doc(victim).set({ addedAt: Date.now() });

  // 2. social_requests: one sent by victim, one received by victim, one
  //    unrelated (friend → other) as scope control.
  const sentReqRef = db.collection("social_requests").doc(`sent-${RUN}`);
  const recvReqRef = db.collection("social_requests").doc(`recv-${RUN}`);
  const controlReqRef = db.collection("social_requests").doc(`ctrl-${RUN}`);
  await sentReqRef.set({ fromUserId: victim, toUserId: otherUser, status: "pending" });
  await recvReqRef.set({ fromUserId: otherUser, toUserId: victim, status: "pending" });
  await controlReqRef.set({ fromUserId: friend, toUserId: otherUser, status: "pending" });

  // 3. feedback authored by victim; another user's feedback as scope control.
  const victimFeedbackRef = db.collection("feedback").doc(`fb-${RUN}`);
  const controlFeedbackRef = db.collection("feedback").doc(`fb-ctrl-${RUN}`);
  await victimFeedbackRef.set({ userId: victim, message: "x" });
  await controlFeedbackRef.set({ userId: otherUser, message: "y" });

  // ── Run the cascade core ──
  const res = await cleanupUserSocialData(victim);

  // ── Reverse-friendship effect ──
  check(
    "reverse friendship doc (friend→victim) removed",
    !(await db.collection("users").doc(friend)
      .collection("friends").doc(victim).get()).exists,
  );
  check(
    "unrelated reverse friendship (friend→other) retained",
    (await controlReverseRef.get()).exists,
  );

  // ── social_requests effect ──
  check("sent social_request (victim→other) deleted", !(await sentReqRef.get()).exists);
  check("received social_request (other→victim) deleted", !(await recvReqRef.get()).exists);
  check("unrelated social_request (friend→other) retained", (await controlReqRef.get()).exists);

  // ── friendsCount decrement ──
  const friendProfile = await db.collection("public_profiles").doc(friend).get();
  check(
    "friend's friendsCount decremented 3 → 2",
    (friendProfile.data()?.friendsCount as number | undefined) === 2,
    JSON.stringify(friendProfile.data()),
  );

  // ── BUT-1582: a profile-absent friend must not poison the chunk ──
  // `friend`'s 3 → 2 decrement above shares the SAME batch as friendNoProfile;
  // its success proves the missing profile did not roll back the chunk.
  check(
    "BUT-1582: reverse edge of the profile-less friend still removed",
    !(await db.collection("users").doc(friendNoProfile)
      .collection("friends").doc(victim).get()).exists,
  );
  check(
    "BUT-1582: no public_profiles doc resurrected for the profile-less friend",
    !(await db.collection("public_profiles").doc(friendNoProfile).get()).exists,
  );

  // ── public_profile of the deleted user removed ──
  check(
    "victim public_profile deleted",
    !(await db.collection("public_profiles").doc(victim).get()).exists,
  );

  // ── feedback effect ──
  check("victim feedback deleted", !(await victimFeedbackRef.get()).exists);
  check("other user's feedback retained", (await controlFeedbackRef.get()).exists);

  // ── Returned per-step summary ──
  check(
    "summary: friendsRemoved >= 1",
    typeof res.friendsRemoved === "number" && res.friendsRemoved >= 1,
    JSON.stringify(res),
  );
  check(
    "summary: socialRequestsCleaned >= 2",
    typeof res.socialRequestsCleaned === "number" && res.socialRequestsCleaned >= 2,
    JSON.stringify(res),
  );
  check(
    "summary: friendCountsUpdated >= 1",
    typeof res.friendCountsUpdated === "number" && res.friendCountsUpdated >= 1,
    JSON.stringify(res),
  );
  check(
    "summary: feedbackCleaned >= 1",
    typeof res.feedbackCleaned === "number" && res.feedbackCleaned >= 1,
    JSON.stringify(res),
  );

  // ── BUT-1506: idempotent friend-count decrement on cascade retry ──
  // The onUserDeleted trigger rethrows on any error, so Cloud Functions
  // retries the WHOLE cascade. The victim's own friends subcollection is never
  // deleted, so a retry re-reads `friend` in the friends list — but the reverse
  // friendship doc it keys off was already removed on the first run, so the
  // friend's count must NOT drop a second time. Re-run the cascade and assert
  // the count is still 2 (a regression here would show 1).
  const retryRes = await cleanupUserSocialData(victim);
  const friendProfileAfterRetry =
    await db.collection("public_profiles").doc(friend).get();
  check(
    "BUT-1506: friendsCount stays 2 after a retried cascade (no double-decrement)",
    (friendProfileAfterRetry.data()?.friendsCount as number | undefined) === 2,
    JSON.stringify(friendProfileAfterRetry.data()),
  );
  check(
    "BUT-1506: retry re-decrements nothing (friendCountsUpdated === 0)",
    retryRes.friendCountsUpdated === 0,
    JSON.stringify(retryRes),
  );

  console.log(`\n${run - failed}/${run} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
