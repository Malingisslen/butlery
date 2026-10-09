/**
 * Emulator-backed integration test for BUT-2321: `handOverGroupWithDeps`, the
 * core of the `handOverGroup` callable.
 *
 * The Admin SDK bypasses rules, so seeding is plain writes. The household
 * trigger's core is called after the handover for both events the deployed
 * trigger sees: the old document's delete and the new document's create.
 *
 * Prerequisite: Firestore emulator running locally
 * (`bash .claude/hooks/ensure-firestore-emulator.sh`).
 *
 * Run: npx ts-node src/__tests__/hand-over-group.integration.test.ts
 */

const PROJECT_ID = "butlery-hand-over-group-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { handOverGroupWithDeps } = require("../groups/hand-over-group");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { reconcileGroupHousehold } = require("../family/on-household-group-written");

const RUN = Date.now().toString(36);
const eligible = { isAgeCompliant: async () => true };

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
  expected: string,
): Promise<void> {
  try {
    await fn();
    check(name, false, "expected a throw, but it resolved");
  } catch (err) {
    const e = err as { code?: string; message?: string };
    const text = `${e.code ?? ""} ${e.message ?? ""}`;
    check(name, text.includes(expected), text);
  }
}

const ts = () => admin.firestore.Timestamp.now();

function groupRef(owner: string, groupId: string) {
  return db.doc(`users/${owner}/friend_categories/${groupId}`);
}

async function data(path: string) {
  const snap = await db.doc(path).get();
  return snap.exists ? snap.data() ?? {} : null;
}

/** An owner, a group holding the owner and two members, and the new owner. */
async function seed(tag: string, extra: Record<string, unknown> = {}) {
  const owner = `owner${tag}${RUN}`;
  const next = `next${tag}${RUN}`;
  const other = `other${tag}${RUN}`;
  const groupId = `group${tag}${RUN}`;
  await groupRef(owner, groupId).set({
    name: "Fredagsmiddag",
    description: "",
    emoji: "🍲",
    ownerId: owner,
    friendUserIds: [owner, next, other],
    createdAt: ts(),
    updatedAt: ts(),
    sortOrder: 3,
    isDefault: false,
    isHousehold: false,
    ...extra,
  });
  return { owner, next, other, groupId };
}

async function run_(): Promise<void> {
  console.log("hand over group integration tests (BUT-2321)\n");

  {
    const s = await seed("move");
    const chatId = `chat${s.groupId}`;
    await db.doc(`chat_groups/${chatId}`).set({
      memberIds: [s.owner, s.next, s.other],
      adminIds: [s.owner],
      createdBy: s.owner,
      conversationId: `conv${s.groupId}`,
      sourceCategoryId: s.groupId,
      sourceCategoryOwnerId: s.owner,
    });
    const invite = db.collection("social_requests").doc();
    await invite.set({
      type: "groupInvitation", fromUserId: s.owner, toUserId: `x${RUN}`,
      status: "pending", groupId: s.groupId,
    });
    const closed = db.collection("reports").doc();
    await closed.set({
      contentType: "group", contentId: s.groupId, contentOwnerId: s.owner,
      status: "closed",
    });

    await handOverGroupWithDeps(
      db, s.owner, { groupId: s.groupId, newOwnerId: s.next }, eligible);

    const moved = await data(`users/${s.next}/friend_categories/${s.groupId}`);
    check("handover: group now stored under the new owner, same id",
      moved?.ownerId === s.next && moved?.name === "Fredagsmiddag" &&
        moved?.emoji === "🍲" && moved?.isDefault === false,
      JSON.stringify(moved));
    check("handover: old owner left, no uid of theirs in the group",
      JSON.stringify(moved?.friendUserIds) === JSON.stringify([s.next, s.other]),
      JSON.stringify(moved?.friendUserIds));
    check("handover: old document deleted",
      (await data(`users/${s.owner}/friend_categories/${s.groupId}`)) === null);

    const chat = await data(`chat_groups/${chatId}`);
    check("handover: chat points at the new owner, who is its admin",
      chat?.sourceCategoryOwnerId === s.next && chat?.createdBy === s.next &&
        JSON.stringify(chat?.adminIds) === JSON.stringify([s.next]),
      JSON.stringify(chat));
    check("handover: the old owner's pending invitation is cancelled",
      (await invite.get()).get("status") === "cancelled");

    const handedOverRows = async () => (await db.collection("messages")
      .where("conversationId", "==", `conv${s.groupId}`).get()).docs
      .map((d) => d.data())
      .filter((m) => m.metadata?.systemEvent === "owner_handed_over");
    const rows = await handedOverRows();
    check("handover: one chat line tells the group who owns it now",
      rows.length === 1 && rows[0].metadata?.subjectUserId === s.next &&
        typeof rows[0].content === "string" && rows[0].content.includes("äger nu gruppen"),
      JSON.stringify(rows));

    await expectThrows("handover again: the old owner is refused",
      () => handOverGroupWithDeps(
        db, s.owner, { groupId: s.groupId, newOwnerId: s.next }, eligible),
      "permission-denied");
    await expectThrows("after the move, a member who is not the owner is refused",
      () => handOverGroupWithDeps(
        db, s.other, { groupId: s.groupId, newOwnerId: s.next }, eligible),
      "permission-denied");
    check("handover again: nothing changed, still one chat line",
      (await data(`users/${s.next}/friend_categories/${s.groupId}`))?.ownerId === s.next &&
        (await handedOverRows()).length === 1);
  }

  {
    const s = await seed("adminfallback");
    const chatId = `chat${s.groupId}`;
    await db.doc(`chat_groups/${chatId}`).set({
      memberIds: [s.owner, s.other],
      adminIds: [s.owner],
      createdBy: s.owner,
      sourceCategoryId: s.groupId,
      sourceCategoryOwnerId: s.owner,
    });
    await handOverGroupWithDeps(
      db, s.owner, { groupId: s.groupId, newOwnerId: s.next }, eligible);
    const chat = await data(`chat_groups/${chatId}`);
    check("chat without the new owner keeps its admin list and is re-pointed",
      chat?.sourceCategoryOwnerId === s.next &&
        JSON.stringify(chat?.adminIds) === JSON.stringify([s.owner]),
      JSON.stringify(chat));
  }

  {
    const s = await seed("refuse");
    const stranger = `stranger${RUN}`;
    await expectThrows("a member who is not the owner is refused",
      () => handOverGroupWithDeps(
        db, s.other, { groupId: s.groupId, newOwnerId: s.next }, eligible),
      "permission-denied");
    await expectThrows("a new owner outside the group is refused",
      () => handOverGroupWithDeps(
        db, s.owner, { groupId: s.groupId, newOwnerId: stranger }, eligible),
      "permission-denied");
    await expectThrows("handing over to oneself is refused",
      () => handOverGroupWithDeps(
        db, s.owner, { groupId: s.groupId, newOwnerId: s.owner }, eligible),
      "invalid-argument");
    await expectThrows("a new owner without the age check is refused",
      () => handOverGroupWithDeps(
        db, s.owner, { groupId: s.groupId, newOwnerId: s.next },
        { isAgeCompliant: async () => false }),
      "new-owner-not-eligible");
    check("refusals leave the group where it was",
      (await data(`users/${s.owner}/friend_categories/${s.groupId}`))?.ownerId === s.owner &&
        (await data(`users/${s.next}/friend_categories/${s.groupId}`)) === null);
  }

  {
    const s = await seed("mismatch");
    await groupRef(s.owner, s.groupId).update({ ownerId: s.next });
    await expectThrows("a group whose field and path disagree is refused",
      () => handOverGroupWithDeps(
        db, s.owner, { groupId: s.groupId, newOwnerId: s.next }, eligible),
      "permission-denied");
  }

  {
    const s = await seed("default", { isDefault: true });
    await expectThrows("the default group is refused",
      () => handOverGroupWithDeps(
        db, s.owner, { groupId: s.groupId, newOwnerId: s.next }, eligible),
      "default-group");
  }

  {
    const s = await seed("taken");
    await groupRef(s.next, s.groupId).set({ ownerId: s.next, name: "Annan" });
    await expectThrows("an id the new owner already uses is refused",
      () => handOverGroupWithDeps(
        db, s.owner, { groupId: s.groupId, newOwnerId: s.next }, eligible),
      "id-taken");
    check("the new owner's own group is untouched",
      (await data(`users/${s.next}/friend_categories/${s.groupId}`))?.name === "Annan");
  }

  {
    const s = await seed("report");
    await db.collection("reports").doc().set({
      contentType: "group", contentId: s.groupId, contentOwnerId: s.owner,
      status: "in_review",
    });
    await expectThrows("a group with an open report is refused",
      () => handOverGroupWithDeps(
        db, s.owner, { groupId: s.groupId, newOwnerId: s.next }, eligible),
      "open-report");
  }

  {
    const s = await seed("house", { isHousehold: true });
    const householdId = `house${s.groupId}`;
    const share = (uid: string) =>
      db.doc(`household_allergen_shares/${householdId}_${uid}`);
    await db.doc(`households/${householdId}`).set({
      name: "Vårt hushåll",
      members: [
        { userId: s.owner, permission: "admin" },
        { userId: s.next, permission: "view" },
        { userId: s.other, permission: "view" },
      ],
      memberUserIds: [s.owner, s.next, s.other],
      memberPermissions: { [s.owner]: "admin", [s.next]: "view", [s.other]: "view" },
      createdBy: s.owner,
      sourceGroupOwnerId: s.owner,
      sourceGroupId: s.groupId,
    });
    for (const uid of [s.owner, s.next, s.other]) {
      await share(uid).set({ householdId, userId: uid, trackedAllergens: ["nötter"] });
    }

    await handOverGroupWithDeps(
      db, s.owner, { groupId: s.groupId, newOwnerId: s.next }, eligible);
    const h = await data(`households/${householdId}`);
    check("household follows: new owner is its admin and its link",
      h?.createdBy === s.next && h?.sourceGroupOwnerId === s.next &&
        h?.memberPermissions?.[s.next] === "admin" &&
        h?.members?.find((m: { userId: string }) => m.userId === s.next)
          ?.permission === "admin",
      JSON.stringify(h));
    check("household follows: old owner removed, their share deleted",
      !h?.memberUserIds?.includes(s.owner) &&
        !(s.owner in (h?.memberPermissions ?? {})) &&
        !(await share(s.owner).get()).exists);
    check("household follows: the other members and their shares stay",
      h?.memberUserIds?.includes(s.other) && (await share(s.other).get()).exists &&
        (await share(s.next).get()).exists);

    const onDelete = await reconcileGroupHousehold(
      db, { ownerId: s.owner, groupId: s.groupId });
    const onCreate = await reconcileGroupHousehold(
      db, { ownerId: s.next, groupId: s.groupId });
    check("household trigger: no-op on the old document's delete",
      onDelete.householdIds.length === 0 && onDelete.removed.length === 0,
      JSON.stringify(onDelete));
    check("household trigger: removes nobody on the new document's create",
      onCreate.removed.length === 0 && !onCreate.unlinked,
      JSON.stringify(onCreate));
    check("household trigger: other member's share still there afterwards",
      (await share(s.other).get()).exists);
  }

  {
    const s = await seed("outside", { isHousehold: true });
    await db.doc(`households/house${s.groupId}`).set({
      members: [{ userId: s.owner, permission: "admin" }],
      memberUserIds: [s.owner],
      memberPermissions: { [s.owner]: "admin" },
      createdBy: s.owner,
      sourceGroupOwnerId: s.owner,
      sourceGroupId: s.groupId,
    });
    await expectThrows("a new owner who is not in the household is refused",
      () => handOverGroupWithDeps(
        db, s.owner, { groupId: s.groupId, newOwnerId: s.next }, eligible),
      "new-owner-not-in-household");
  }

  console.log(`\n${run - failed}/${run} passed` +
    (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
