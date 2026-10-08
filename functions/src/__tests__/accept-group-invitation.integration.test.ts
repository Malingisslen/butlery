/**
 * Emulator-backed integration test for the BUT-2265 `acceptGroupInvitation`
 * callable core (`acceptGroupInvitationWithDeps`).
 *
 * Runs against a REAL Firestore emulator so the transaction (member union plus
 * invitation status flip) is exercised for real. The Admin SDK bypasses rules,
 * so seeding is plain writes.
 *
 * Prerequisite: Firestore emulator running locally
 * (`bash .claude/hooks/ensure-firestore-emulator.sh`).
 *
 * Run: npx ts-node src/__tests__/accept-group-invitation.integration.test.ts
 */

const PROJECT_ID = "butlery-accept-group-integration";
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
  acceptGroupInvitationWithDeps,
  MAX_GROUP_MEMBERS,
} = require("../social/accept-group-invitation");

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
  codeIncludes: string,
): Promise<void> {
  try {
    await fn();
    check(name, false, "expected a throw, but it resolved");
  } catch (err) {
    const msg = err instanceof Error ? err.message : String(err);
    const code = (err as { code?: string }).code ?? "";
    const ok = code.includes(codeIncludes);
    check(name, ok, ok ? undefined : `wrong error: code=${code} msg=${msg}`);
  }
}

interface Scenario {
  owner: string;
  invitee: string;
  groupId: string;
  invitationId: string;
}

/** Owner, invitee (friends), a group owned by the owner, a pending invitation. */
async function seed(
  tag: string,
  overrides: {
    invitation?: Record<string, unknown>;
    group?: Record<string, unknown> | null;
    friends?: boolean;
  } = {},
): Promise<Scenario> {
  const s: Scenario = {
    owner: `owner-${tag}-${RUN}`,
    invitee: `invitee-${tag}-${RUN}`,
    groupId: `group-${tag}-${RUN}`,
    invitationId: `inv-${tag}-${RUN}`,
  };
  if (overrides.group !== null) {
    await db
      .collection("users").doc(s.owner)
      .collection("friend_categories").doc(s.groupId)
      .set({
        name: "Hemma",
        ownerId: s.owner,
        friendUserIds: [s.owner],
        isHousehold: true,
        ...(overrides.group ?? {}),
      });
  }
  if (overrides.friends !== false) {
    await db
      .collection("users").doc(s.owner)
      .collection("friends").doc(s.invitee)
      .set({ addedAt: admin.firestore.FieldValue.serverTimestamp() });
    await db
      .collection("users").doc(s.invitee)
      .collection("friends").doc(s.owner)
      .set({ addedAt: admin.firestore.FieldValue.serverTimestamp() });
  }
  await db.collection("social_requests").doc(s.invitationId).set({
    type: "groupInvitation",
    fromUserId: s.owner,
    toUserId: s.invitee,
    groupId: s.groupId,
    groupName: "Hemma",
    status: "pending",
    ...(overrides.invitation ?? {}),
  });
  return s;
}

async function members(s: Scenario): Promise<string[]> {
  const snap = await db
    .collection("users").doc(s.owner)
    .collection("friend_categories").doc(s.groupId)
    .get();
  return (snap.data()?.friendUserIds as string[] | undefined) ?? [];
}

async function invitationStatus(s: Scenario): Promise<unknown> {
  const snap = await db.collection("social_requests").doc(s.invitationId).get();
  return snap.data()?.status;
}

async function run_(): Promise<void> {
  console.log("acceptGroupInvitation integration tests (BUT-2265)\n");

  {
    const s = await seed("happy");
    const res = await acceptGroupInvitationWithDeps(db, s.invitee, s.invitationId);
    check(
      "happy: success, not alreadyMember, names the group",
      res.success === true && res.alreadyMember === false &&
        res.ownerId === s.owner && res.groupId === s.groupId,
      JSON.stringify(res),
    );
    const after = await members(s);
    check(
      "happy: invitee added, owner kept",
      after.length === 2 && after.includes(s.owner) && after.includes(s.invitee),
      JSON.stringify(after),
    );
    check("happy: invitation accepted", (await invitationStatus(s)) === "accepted");

    const again = await acceptGroupInvitationWithDeps(db, s.invitee, s.invitationId);
    check("repeat tap: reports alreadyMember", again.alreadyMember === true);
    check("repeat tap: still two members", (await members(s)).length === 2);

    await db
      .collection("users").doc(s.owner)
      .collection("friend_categories").doc(s.groupId)
      .update({ friendUserIds: [s.owner] });
    await expectThrows(
      "refuses to re-seat a removed member with their spent invitation",
      () => acceptGroupInvitationWithDeps(db, s.invitee, s.invitationId),
      "failed-precondition",
    );
    check("removed member: stays removed", (await members(s)).length === 1);
  }

  {
    const s = await seed("selffriend", { friends: false });
    await db
      .collection("users").doc(s.invitee)
      .collection("friends").doc(s.owner)
      .set({ addedAt: admin.firestore.FieldValue.serverTimestamp() });
    await expectThrows(
      "refuses when only the invitee's own list names the inviter",
      () => acceptGroupInvitationWithDeps(db, s.invitee, s.invitationId),
      "permission-denied",
    );
  }

  {
    const s = await seed("inviterforged", { friends: false });
    await db
      .collection("users").doc(s.owner)
      .collection("friends").doc(s.invitee)
      .set({ addedAt: admin.firestore.FieldValue.serverTimestamp() });
    await expectThrows(
      "refuses when only the inviter's own list names the invitee",
      () => acceptGroupInvitationWithDeps(db, s.invitee, s.invitationId),
      "permission-denied",
    );
    check("inviter-forged: group unchanged", (await members(s)).length === 1);
  }

  {
    const s = await seed("caller");
    await expectThrows(
      "refuses a caller the invitation is not addressed to",
      () => acceptGroupInvitationWithDeps(db, `stranger-${RUN}`, s.invitationId),
      "permission-denied",
    );
    check("wrong caller: group unchanged", (await members(s)).length === 1);
  }

  {
    const s = await seed("type", { invitation: { type: "friend" } });
    await expectThrows(
      "refuses a social request that is not a group invitation",
      () => acceptGroupInvitationWithDeps(db, s.invitee, s.invitationId),
      "failed-precondition",
    );
  }

  {
    const s = await seed("declined", { invitation: { status: "declined" } });
    await expectThrows(
      "refuses an invitation that is no longer pending",
      () => acceptGroupInvitationWithDeps(db, s.invitee, s.invitationId),
      "failed-precondition",
    );
    check("not pending: group unchanged", (await members(s)).length === 1);
  }

  {
    const s = await seed("nogroup", { group: null });
    await expectThrows(
      "refuses when the group does not exist",
      () => acceptGroupInvitationWithDeps(db, s.invitee, s.invitationId),
      "not-found",
    );
  }

  {
    const s = await seed("owner", { group: { ownerId: `someone-else-${RUN}` } });
    await expectThrows(
      "refuses when the inviter does not own the group",
      () => acceptGroupInvitationWithDeps(db, s.invitee, s.invitationId),
      "failed-precondition",
    );
    check("owner mismatch: group unchanged", (await members(s)).length === 1);
  }

  {
    const s = await seed("stranger", { friends: false });
    await expectThrows(
      "refuses an invitation from someone who is not a friend",
      () => acceptGroupInvitationWithDeps(db, s.invitee, s.invitationId),
      "permission-denied",
    );
    check("not friends: group unchanged", (await members(s)).length === 1);
    check(
      "not friends: invitation still pending",
      (await invitationStatus(s)) === "pending",
    );
  }

  {
    const full = Array.from({ length: MAX_GROUP_MEMBERS }, (_, i) => `m${i}-${RUN}`);
    const s = await seed("full", { group: { friendUserIds: full } });
    await expectThrows(
      "refuses when the group is full",
      () => acceptGroupInvitationWithDeps(db, s.invitee, s.invitationId),
      "resource-exhausted",
    );
  }

  await expectThrows(
    "refuses a missing invitation",
    () => acceptGroupInvitationWithDeps(db, `nobody-${RUN}`, `ghost-${RUN}`),
    "not-found",
  );

  console.log(`\n${run - failed}/${run} passed` + (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
