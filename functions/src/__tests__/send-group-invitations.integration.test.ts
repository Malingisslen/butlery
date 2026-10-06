/**
 * Emulator-backed integration test for the BUT-2270 `sendGroupInvitations`
 * callable core (`sendGroupInvitationsWithDeps`).
 *
 * The Admin SDK bypasses rules, so seeding is plain writes.
 *
 * Prerequisite: Firestore emulator running locally
 * (`bash .claude/hooks/ensure-firestore-emulator.sh`).
 *
 * Run: npx ts-node src/__tests__/send-group-invitations.integration.test.ts
 */

const PROJECT_ID = "butlery-send-group-invitations-integration";
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
  sendGroupInvitationsWithDeps,
} = require("../social/send-group-invitations");

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
  codeIncludes: string,
): Promise<void> {
  try {
    await fn();
    check(name, false, "expected a throw, but it resolved");
  } catch (err) {
    const code = (err as { code?: string }).code ?? "";
    check(name, code.includes(codeIncludes), `code=${code}`);
  }
}

async function befriend(a: string, b: string): Promise<void> {
  const at = admin.firestore.FieldValue.serverTimestamp();
  await db.doc(`users/${a}/friends/${b}`).set({ addedAt: at });
  await db.doc(`users/${b}/friends/${a}`).set({ addedAt: at });
}

/** An owner with a group and [friendCount] friends. */
async function seed(tag: string, friendCount: number) {
  const owner = `owner-${tag}-${RUN}`;
  const groupId = `group-${tag}-${RUN}`;
  const friends = Array.from(
    { length: friendCount },
    (_, i) => `friend${i}-${tag}-${RUN}`,
  );
  await db.doc(`users/${owner}/friend_categories/${groupId}`).set({
    name: "Hemma",
    emoji: "🏠",
    ownerId: owner,
    friendUserIds: [owner],
  });
  await db.doc(`public_profiles/${owner}`).set({ displayName: "Ägaren" });
  for (const f of friends) await befriend(owner, f);
  return { owner, groupId, friends };
}

async function pendingFor(owner: string, groupId: string) {
  const snap = await db
    .collection("social_requests")
    .where("fromUserId", "==", owner)
    .where("groupId", "==", groupId)
    .where("status", "==", "pending")
    .get();
  return snap.docs.map((d) => d.data());
}

async function run_(): Promise<void> {
  console.log("sendGroupInvitations integration tests (BUT-2270)\n");

  {
    // The bug: three friends at once, where the client path sent one.
    const s = await seed("three", 3);
    const res = await sendGroupInvitationsWithDeps(
      db, s.owner, s.groupId, s.friends, "Välkomna",
    );
    check("three friends: all three sent", res.sent.length === 3,
      JSON.stringify(res));
    const rows = await pendingFor(s.owner, s.groupId);
    check("three friends: three pending rows", rows.length === 3);
    const row = rows[0] ?? {};
    check(
      "row has the app's invitation fields",
      row.type === "groupInvitation" && row.groupName === "Hemma" &&
        row.groupEmoji === "🏠" && row.fromUserName === "Ägaren" &&
        row.message === "Välkomna" && row.sentAt instanceof
          admin.firestore.Timestamp &&
        row.expiresAt.toMillis() - row.sentAt.toMillis() === 7 * 86400000,
      JSON.stringify(row),
    );

    const again = await sendGroupInvitationsWithDeps(
      db, s.owner, s.groupId, s.friends, null,
    );
    check(
      "re-send: nothing sent, all already_invited",
      again.sent.length === 0 &&
        again.skipped.every((x: { reason: string }) =>
          x.reason === "already_invited"),
      JSON.stringify(again),
    );
    check("re-send: still three rows",
      (await pendingFor(s.owner, s.groupId)).length === 3);
  }

  {
    const s = await seed("mixed", 2);
    const member = `member-${RUN}`;
    await befriend(s.owner, member);
    await db.doc(`users/${s.owner}/friend_categories/${s.groupId}`)
      .update({ friendUserIds: [s.owner, member] });
    const oneSided = `onesided-${RUN}`;
    await db.doc(`users/${s.owner}/friends/${oneSided}`)
      .set({ addedAt: 1 });
    const blocker = s.friends[1];
    await db.doc(`blocks/${blocker}_${s.owner}`).set({ at: 1 });

    const res = await sendGroupInvitationsWithDeps(
      db, s.owner, s.groupId,
      [s.friends[0], blocker, member, oneSided, s.owner], null,
    );
    const reason = (u: string) =>
      res.skipped.find((x: { userId: string }) => x.userId === u)?.reason;
    check("mixed: only the plain friend is sent",
      res.sent.length === 1 && res.sent[0].userId === s.friends[0],
      JSON.stringify(res));
    check("mixed: blocker skipped as unavailable",
      reason(blocker) === "unavailable");
    check("mixed: member skipped", reason(member) === "already_member");
    check("mixed: one-sided friend skipped",
      reason(oneSided) === "not_friends");
    check("mixed: self skipped", reason(s.owner) === "self");
  }

  {
    const s = await seed("notowner", 1);
    const stranger = `stranger-${RUN}`;
    await expectThrows(
      "refuses someone else's group",
      () => sendGroupInvitationsWithDeps(
        db, stranger, s.groupId, s.friends, null),
      "permission-denied",
    );
    await expectThrows(
      "refuses a missing group with the same answer",
      () => sendGroupInvitationsWithDeps(
        db, s.owner, `ghost-${RUN}`, s.friends, null),
      "permission-denied",
    );
    check("refused calls wrote nothing",
      (await pendingFor(s.owner, s.groupId)).length === 0);
  }

  console.log(`\n${run - failed}/${run} passed` +
    (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
