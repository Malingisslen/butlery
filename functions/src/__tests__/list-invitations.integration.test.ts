/**
 * Emulator-backed integration test for BUT-2089's two callable cores,
 * `sendListInvitationsWithDeps` and `acceptListInvitationWithDeps`.
 *
 * The Admin SDK bypasses rules, so seeding is plain writes.
 *
 * Prerequisite: Firestore emulator running locally
 * (`bash .claude/hooks/ensure-firestore-emulator.sh`).
 *
 * Run: npx ts-node src/__tests__/list-invitations.integration.test.ts
 */

const PROJECT_ID = "butlery-list-invitations-integration";
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
const { sendListInvitationsWithDeps } = require("../social/send-list-invitations");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { acceptListInvitationWithDeps } = require("../social/accept-list-invitation");

const RUN = Date.now().toString(36);
const DAY = 86400000;

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

const listPath = (id: string) => `unified_shared_shopping_lists/${id}`;

/** An owner with a shared list and [friendCount] friends. */
async function seed(tag: string, friendCount: number) {
  const owner = `owner-${tag}-${RUN}`;
  const listId = `list-${tag}-${RUN}`;
  const friends = Array.from(
    { length: friendCount },
    (_, i) => `friend${i}-${tag}-${RUN}`,
  );
  await db.doc(listPath(listId)).set({
    name: "Veckohandling",
    ownerId: owner,
    memberPermissions: { [owner]: "admin" },
    items: [],
    createdAt: admin.firestore.Timestamp.now(),
  });
  await db.doc(`public_profiles/${owner}`).set({ displayName: "Ägaren" });
  for (const f of friends) await befriend(owner, f);
  return { owner, listId, friends };
}

async function members(listId: string): Promise<Record<string, string>> {
  return (await db.doc(listPath(listId)).get()).get("memberPermissions") ?? {};
}

async function invite(owner: string, listId: string, uid: string, permission = "edit") {
  const res = await sendListInvitationsWithDeps(db, owner, listId, [uid], permission);
  return res.sent[0]?.invitationId as string | undefined;
}

async function run_(): Promise<void> {
  console.log("list invitations integration tests (BUT-2089)\n");

  {
    const s = await seed("happy", 2);
    const res = await sendListInvitationsWithDeps(
      db, s.owner, s.listId, s.friends, "view",
    );
    check("send: both friends invited", res.sent.length === 2, JSON.stringify(res));
    const row = (await db.doc(`social_requests/${res.sent[0].invitationId}`).get()).data() ?? {};
    check(
      "send: row carries the app's fields",
      row.type === "listInvitation" && row.listId === s.listId &&
        row.listName === "Veckohandling" && row.permission === "view" &&
        row.fromUserName === "Ägaren" && row.status === "pending" &&
        row.expiresAt.toMillis() - row.sentAt.toMillis() === 7 * DAY,
      JSON.stringify(row),
    );
    check("send: nobody seated yet",
      Object.keys(await members(s.listId)).length === 1);

    const again = await sendListInvitationsWithDeps(
      db, s.owner, s.listId, s.friends, "edit",
    );
    check("send again: all already_invited",
      again.sent.length === 0 &&
        again.skipped.every((x: { reason: string }) => x.reason === "already_invited"),
      JSON.stringify(again));

    const acc = await acceptListInvitationWithDeps(
      db, s.friends[0], res.sent[0].invitationId,
    );
    check("accept: success, not already a member",
      acc.success === true && acc.alreadyMember === false && acc.listId === s.listId);
    check("accept: seated with the invited level",
      (await members(s.listId))[s.friends[0]] === "view");
    check("accept: row marked accepted",
      (await db.doc(`social_requests/${res.sent[0].invitationId}`).get())
        .get("status") === "accepted");

    const twice = await acceptListInvitationWithDeps(
      db, s.friends[0], res.sent[0].invitationId,
    );
    check("accept twice: success as already a member", twice.alreadyMember === true);

    await expectThrows(
      "accept: someone else cannot take the invitation",
      () => acceptListInvitationWithDeps(db, s.friends[0], res.sent[1].invitationId),
      "failed-precondition",
    );
    check("accept by the wrong person seated nobody",
      !(s.friends[1] in (await members(s.listId))));
  }

  {
    const s = await seed("mixed", 3);
    const member = `member-${RUN}`;
    await befriend(s.owner, member);
    await db.doc(listPath(s.listId)).update({ [`memberPermissions.${member}`]: "edit" });
    const oneSided = `onesided-${RUN}`;
    await db.doc(`users/${s.owner}/friends/${oneSided}`).set({ addedAt: 1 });
    const [plain, blocker, blocked] = s.friends;
    await db.doc(`blocks/${blocker}_${s.owner}`).set({ at: 1 });
    await db.doc(`blocks/${s.owner}_${blocked}`).set({ at: 1 });

    const res = await sendListInvitationsWithDeps(
      db, s.owner, s.listId, [plain, blocker, blocked, member, oneSided, s.owner], "edit",
    );
    const reason = (u: string) =>
      res.skipped.find((x: { userId: string }) => x.userId === u)?.reason;
    check("mixed: only the plain friend is sent",
      res.sent.length === 1 && res.sent[0].userId === plain, JSON.stringify(res));
    check("mixed: invitee's block is unavailable", reason(blocker) === "unavailable");
    check("mixed: inviter's block is unavailable", reason(blocked) === "unavailable");
    check("mixed: member skipped", reason(member) === "already_member");
    check("mixed: one-sided friend skipped", reason(oneSided) === "not_friends");
    check("mixed: self skipped", reason(s.owner) === "self");
  }

  {
    // Decline memory: 30 days per inviter, list and invitee.
    const s = await seed("declined", 2);
    const [recent, old] = s.friends;
    const recentAt = admin.firestore.Timestamp.fromMillis(Date.now() - 2 * DAY);
    const oldAt = admin.firestore.Timestamp.fromMillis(Date.now() - 31 * DAY);
    for (const [uid, at] of [[recent, recentAt], [old, oldAt]] as const) {
      await db.collection("social_requests").add({
        type: "listInvitation", fromUserId: s.owner, toUserId: uid,
        listId: s.listId, status: "rejected", sentAt: at, respondedAt: at,
      });
    }
    const res = await sendListInvitationsWithDeps(
      db, s.owner, s.listId, s.friends, "edit",
    );
    check("declined 2 days ago: unavailable",
      res.skipped.some((x: { userId: string; reason: string }) =>
        x.userId === recent && x.reason === "unavailable"), JSON.stringify(res));
    check("declined 31 days ago: invited again",
      res.sent.length === 1 && res.sent[0].userId === old);
  }

  {
    // An expired but still-pending invitation does not block a fresh one, and
    // cannot itself be accepted.
    const s = await seed("expired", 1);
    const past = admin.firestore.Timestamp.fromMillis(Date.now() - DAY);
    const stale = await db.collection("social_requests").add({
      type: "listInvitation", fromUserId: s.owner, toUserId: s.friends[0],
      listId: s.listId, permission: "edit", status: "pending",
      sentAt: past, expiresAt: past,
    });
    await expectThrows(
      "accept: an expired invitation is refused",
      () => acceptListInvitationWithDeps(db, s.friends[0], stale.id),
      "failed-precondition",
    );
    const res = await sendListInvitationsWithDeps(
      db, s.owner, s.listId, s.friends, "edit",
    );
    check("expired pending invitation: a new one is sent", res.sent.length === 1);
  }

  {
    // The inviter loses the right to invite before the accept.
    const s = await seed("demoted", 1);
    const adminUid = `admin-${RUN}`;
    await befriend(adminUid, s.friends[0]);
    await db.doc(listPath(s.listId)).update({ [`memberPermissions.${adminUid}`]: "admin" });
    const id = await invite(adminUid, s.listId, s.friends[0]);
    check("an admin can invite", typeof id === "string");
    await db.doc(listPath(s.listId)).update({ [`memberPermissions.${adminUid}`]: "edit" });
    await expectThrows(
      "accept: refused once the inviter is no longer an admin",
      () => acceptListInvitationWithDeps(db, s.friends[0], id),
      "failed-precondition",
    );
    check("demoted inviter: nobody seated",
      !(s.friends[0] in (await members(s.listId))));
    await expectThrows(
      "send: an edit member cannot invite",
      () => sendListInvitationsWithDeps(db, adminUid, s.listId, s.friends, "edit"),
      "permission-denied",
    );
  }

  {
    // Friendship or block changes between send and accept.
    const s = await seed("changed", 2);
    const [unfriended, blocks] = s.friends;
    const idA = await invite(s.owner, s.listId, unfriended);
    const idB = await invite(s.owner, s.listId, blocks);
    await db.doc(`users/${s.owner}/friends/${unfriended}`).delete();
    await db.doc(`blocks/${s.owner}_${blocks}`).set({ at: 1 });
    await expectThrows(
      "accept: refused after the friendship ended",
      () => acceptListInvitationWithDeps(db, unfriended, idA),
      "failed-precondition",
    );
    await expectThrows(
      "accept: refused after the inviter blocked the invitee",
      () => acceptListInvitationWithDeps(db, blocks, idB),
      "failed-precondition",
    );
  }

  {
    // The invitee's own side of the friendship and of a block, so each half of
    // accept's two-sided checks is staged on its own.
    const s = await seed("inviteeside", 2);
    const [unfriends, blocker] = s.friends;
    const idA = await invite(s.owner, s.listId, unfriends);
    const idB = await invite(s.owner, s.listId, blocker);
    await db.doc(`users/${unfriends}/friends/${s.owner}`).delete();
    await db.doc(`blocks/${blocker}_${s.owner}`).set({ at: 1 });
    await expectThrows(
      "accept: refused after the invitee ended the friendship",
      () => acceptListInvitationWithDeps(db, unfriends, idA),
      "failed-precondition",
    );
    await expectThrows(
      "accept: refused after the invitee blocked the inviter",
      () => acceptListInvitationWithDeps(db, blocker, idB),
      "failed-precondition",
    );
    const seated = await members(s.listId);
    check("invitee-side refusals seated nobody",
      !(unfriends in seated) && !(blocker in seated));
  }

  {
    // Decline memory edges: a decline with no time counts as recent, and a
    // decline given to someone else does not stop this inviter.
    const s = await seed("declineedge", 2);
    const [noTime, otherInviter] = s.friends;
    await db.collection("social_requests").add({
      type: "listInvitation", fromUserId: s.owner, toUserId: noTime,
      listId: s.listId, status: "rejected",
    });
    await db.collection("social_requests").add({
      type: "listInvitation", fromUserId: `someone-else-${RUN}`,
      toUserId: otherInviter, listId: s.listId, status: "rejected",
      respondedAt: admin.firestore.Timestamp.now(),
    });
    const res = await sendListInvitationsWithDeps(
      db, s.owner, s.listId, s.friends, "edit",
    );
    check("decline without a time: unavailable",
      res.skipped.some((x: { userId: string; reason: string }) =>
        x.userId === noTime && x.reason === "unavailable"), JSON.stringify(res));
    check("another inviter's decline: invited",
      res.sent.length === 1 && res.sent[0].userId === otherInviter);
  }

  {
    // A row the invitee flipped to `accepted` with the client status write
    // seats nobody, and a row a client could not have made is refused too.
    const s = await seed("flipped", 1);
    const id = await invite(s.owner, s.listId, s.friends[0]);
    await db.doc(`social_requests/${id}`).update({ status: "accepted" });
    await expectThrows(
      "accept: a pre-flipped row is refused",
      () => acceptListInvitationWithDeps(db, s.friends[0], id),
      "failed-precondition",
    );
    check("pre-flipped row: nobody seated",
      !(s.friends[0] in (await members(s.listId))));

    const forged = await db.collection("social_requests").add({
      type: "listInvitation", fromUserId: s.owner, toUserId: s.friends[0],
      listId: s.listId, permission: "admin", status: "pending",
      sentAt: admin.firestore.Timestamp.now(),
      expiresAt: admin.firestore.Timestamp.fromMillis(Date.now() + DAY),
    });
    await acceptListInvitationWithDeps(db, s.friends[0], forged.id);
    check("a row naming `admin` seats at `view`",
      (await members(s.listId))[s.friends[0]] === "view");
  }

  {
    // The 200-member bound, at both ends.
    const s = await seed("full", 1);
    const id = await invite(s.owner, s.listId, s.friends[0]);
    const roster: Record<string, string> = { [s.owner]: "admin" };
    for (let i = 0; i < 199; i++) roster[`seat-${i}`] = "view";
    await db.doc(listPath(s.listId)).update({ memberPermissions: roster });
    await expectThrows(
      "accept: refused on a full list",
      () => acceptListInvitationWithDeps(db, s.friends[0], id),
      "failed-precondition",
    );
    await expectThrows(
      "send: refused on a full list",
      () => sendListInvitationsWithDeps(db, s.owner, s.listId, s.friends, "edit"),
      "resource-exhausted",
    );
  }

  {
    const s = await seed("ghost", 1);
    await expectThrows(
      "send: a missing list gets the same answer as a foreign one",
      () => sendListInvitationsWithDeps(db, s.owner, `ghost-${RUN}`, s.friends, "edit"),
      "permission-denied",
    );
    const id = await invite(s.owner, s.listId, s.friends[0]);
    await db.doc(listPath(s.listId)).delete();
    await expectThrows(
      "accept: refused once the list is deleted",
      () => acceptListInvitationWithDeps(db, s.friends[0], id),
      "failed-precondition",
    );
    await expectThrows(
      "accept: a missing invitation is refused",
      () => acceptListInvitationWithDeps(db, s.friends[0], `none-${RUN}`),
      "failed-precondition",
    );
  }

  console.log(`\n${run - failed}/${run} passed` +
    (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
