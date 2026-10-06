/**
 * Emulator-backed integration test for BUT-2267: `joinGroupHouseholdWithDeps`
 * (the callable's core) and `reconcileGroupHousehold` (the trigger's core).
 *
 * The Admin SDK bypasses rules, so seeding is plain writes. The trigger's core
 * is called directly after each group write, which is what the deployed
 * trigger does on that event.
 *
 * Prerequisite: Firestore emulator running locally
 * (`bash .claude/hooks/ensure-firestore-emulator.sh`).
 *
 * Run: npx ts-node src/__tests__/group-household.integration.test.ts
 */

const PROJECT_ID = "butlery-group-household-integration";
const EMULATOR_HOST = "127.0.0.1:8080";

process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { joinGroupHouseholdWithDeps } = require("../family/join-group-household");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  reconcileGroupHousehold,
  onHouseholdGroupWritten,
} = require("../family/on-household-group-written");
// eslint-disable-next-line @typescript-eslint/no-require-imports
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { deleteFamilyData } = require("../account/account-deletion-cascade");
const {
  MAX_HOUSEHOLD_MEMBERS,
  householdIdForGroup,
} = require("../family/group-household");

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

const ts = () => admin.firestore.Timestamp.now();

/** An owner with a household-marked group holding [memberCount] members. */
async function seed(
  tag: string,
  memberCount: number,
  opts: { isHousehold?: boolean; soloHousehold?: boolean } = {},
) {
  const owner = `owner${tag}${RUN}`;
  const groupId = `group${tag}${RUN}`;
  const members = Array.from(
    { length: memberCount },
    (_, i) => `m${i}${tag}${RUN}`,
  );
  await groupRef(owner, groupId).set({
    name: "Fredagsmiddag",
    ownerId: owner,
    friendUserIds: [owner, ...members],
    isHousehold: opts.isHousehold ?? true,
  });
  let soloId: string | null = null;
  if (opts.soloHousehold) {
    soloId = `solo${tag}${RUN}`;
    await db.doc(`households/${soloId}`).set({
      name: "Vårt hushåll",
      members: [{ userId: owner, permission: "admin", addedAt: ts() }],
      memberUserIds: [owner],
      memberPermissions: { [owner]: "admin" },
      createdBy: owner,
      createdAt: ts(),
      updatedAt: ts(),
      schemaVersion: 1,
    });
  }
  return { owner, groupId, members, soloId, ref: { ownerId: owner, groupId } };
}

function groupRef(owner: string, groupId: string) {
  return db.doc(`users/${owner}/friend_categories/${groupId}`);
}

async function household(id: string) {
  return (await db.doc(`households/${id}`).get()).data() ?? {};
}

async function share(householdId: string, uid: string) {
  const ref = db.doc(`household_allergen_shares/${householdId}_${uid}`);
  await ref.set({
    householdId, userId: uid, trackedAllergens: ["jordnötter"],
    trackedDietary: [], includeUnknownInMenu: false, consentGranted: true,
    consentVersion: "v1", consentGrantedAt: ts(),
  });
  return ref;
}

async function run_(): Promise<void> {
  console.log("group household integration tests (BUT-2267)\n");

  {
    const s = await seed("join", 2, { soloHousehold: true });
    const res = await joinGroupHouseholdWithDeps(db, s.members[0], s.ref);
    check("join: reuses the owner's unlinked household",
      res.householdId === s.soloId && res.alreadyMember === false,
      JSON.stringify(res));
    const h = await household(s.soloId!);
    check("join: member added as view, owner kept as admin",
      JSON.stringify(h.memberUserIds) ===
        JSON.stringify([s.owner, s.members[0]]) &&
        h.memberPermissions[s.members[0]] === "view" &&
        h.memberPermissions[s.owner] === "admin" &&
        h.members.length === 2 && h.members[1].userId === s.members[0] &&
        h.members[1].permission === "view",
      JSON.stringify(h));
    check("join: household linked to the group",
      h.sourceGroupId === s.groupId && h.sourceGroupOwnerId === s.owner &&
        h.createdBy === s.owner);

    const again = await joinGroupHouseholdWithDeps(db, s.members[0], s.ref);
    check("join again: same household, alreadyMember",
      again.householdId === s.soloId && again.alreadyMember === true);
    check("join again: no duplicate member",
      (await household(s.soloId!)).memberUserIds.length === 2);

    const second = await joinGroupHouseholdWithDeps(db, s.members[1], s.ref);
    check("second member joins the same linked household",
      second.householdId === s.soloId &&
        (await household(s.soloId!)).memberUserIds.length === 3);
  }

  {
    const s = await seed("fresh", 1);
    const res = await joinGroupHouseholdWithDeps(db, s.members[0], s.ref);
    const h = await household(res.householdId);
    check("join with no owner household: creates one owned by the owner",
      h.createdBy === s.owner && h.memberPermissions?.[s.owner] === "admin" &&
        h.memberPermissions?.[s.members[0]] === "view" &&
        h.sourceGroupId === s.groupId && !res.householdId.includes("_"),
      JSON.stringify(h));
  }

  {
    const s = await seed("refuse", 1, { soloHousehold: true });
    const stranger = `stranger${RUN}`;
    await expectThrows("non-member refused",
      () => joinGroupHouseholdWithDeps(db, stranger, s.ref),
      "permission-denied");
    await expectThrows("missing group refused with the same answer",
      () => joinGroupHouseholdWithDeps(db, s.members[0],
        { ownerId: s.owner, groupId: `ghost${RUN}` }),
      "permission-denied");
    await expectThrows("owner cannot join their own group",
      () => joinGroupHouseholdWithDeps(db, s.owner, s.ref),
      "invalid-argument");
    // A group doc under the owner's path naming someone else as owner.
    await groupRef(s.owner, `borrowed${RUN}`).set({
      ownerId: stranger, friendUserIds: [s.members[0]], isHousehold: true,
    });
    await expectThrows("group whose ownerId is not the path owner refused",
      () => joinGroupHouseholdWithDeps(db, s.members[0],
        { ownerId: s.owner, groupId: `borrowed${RUN}` }),
      "permission-denied");
    check("refused joins wrote nothing",
      (await household(s.soloId!)).memberUserIds.length === 1);
  }

  {
    const s = await seed("unmarked", 1, {
      isHousehold: false, soloHousehold: true,
    });
    await expectThrows("unmarked group refused",
      () => joinGroupHouseholdWithDeps(db, s.members[0], s.ref),
      "failed-precondition");
    check("unmarked refusal wrote nothing",
      (await household(s.soloId!)).memberUserIds.length === 1);
  }

  {
    // Which of the owner's households a first join may take over: only one
    // the owner created, administers and has not linked to another group.
    const s = await seed("pick", 1);
    const base = {
      name: "x", createdAt: ts(), updatedAt: ts(), schemaVersion: 1,
    };
    const otherAdmin = `otheradmin${RUN}`;
    await db.doc(`households/pickA${RUN}`).set({
      ...base, createdBy: otherAdmin,
      members: [], memberUserIds: [otherAdmin, s.owner],
      memberPermissions: { [otherAdmin]: "admin", [s.owner]: "admin" },
    });
    await db.doc(`households/pickB${RUN}`).set({
      ...base, createdBy: s.owner,
      members: [], memberUserIds: [s.owner],
      memberPermissions: { [s.owner]: "admin" },
      sourceGroupOwnerId: s.owner, sourceGroupId: `othergroup${RUN}`,
    });
    // Created by the owner but no longer administered by them.
    await db.doc(`households/pickC${RUN}`).set({
      ...base, createdBy: s.owner,
      members: [], memberUserIds: [otherAdmin, s.owner],
      memberPermissions: { [otherAdmin]: "admin", [s.owner]: "view" },
    });
    const res = await joinGroupHouseholdWithDeps(db, s.members[0], s.ref);
    check("join: never takes over a household someone else created, one the " +
      "owner does not administer, or one linked to another group",
    res.householdId === householdIdForGroup(s.ref),
    res.householdId);
  }

  {
    // The deterministic id taken by a document that is not this group's
    // household: refused rather than written into.
    const s = await seed("squat", 1);
    const squatter = `squatter${RUN}`;
    await db.doc(`households/${householdIdForGroup(s.ref)}`).set({
      name: "x", members: [], memberUserIds: [squatter],
      memberPermissions: { [squatter]: "admin" }, createdBy: squatter,
      createdAt: ts(), updatedAt: ts(),
    });
    await expectThrows("join: a squatted household id is refused",
      () => joinGroupHouseholdWithDeps(db, s.members[0], s.ref),
      "failed-precondition");
    check("join: the squatted document is untouched",
      JSON.stringify(
        (await household(householdIdForGroup(s.ref))).memberUserIds) ===
        JSON.stringify([squatter]));

    // The owner's own document at that id, linked to a DIFFERENT group, is
    // not this group's household either.
    const o = await seed("squat2", 1);
    await db.doc(`households/${householdIdForGroup(o.ref)}`).set({
      name: "x", members: [], memberUserIds: [o.owner],
      memberPermissions: { [o.owner]: "admin" }, createdBy: o.owner,
      createdAt: ts(), updatedAt: ts(),
      sourceGroupOwnerId: o.owner, sourceGroupId: `elsewhere${RUN}`,
    });
    await expectThrows("join: the id holding another group's household is " +
      "refused",
    () => joinGroupHouseholdWithDeps(db, o.members[0], o.ref),
    "failed-precondition");
  }

  {
    // A household someone else created that names this group must not be
    // joined into: the link only counts when the group's owner created it.
    const s = await seed("forged", 1);
    const forger = `forger${RUN}`;
    await db.doc(`households/forged${RUN}`).set({
      name: "x", members: [], memberUserIds: [forger],
      memberPermissions: { [forger]: "admin" }, createdBy: forger,
      createdAt: ts(), updatedAt: ts(),
      sourceGroupOwnerId: s.owner, sourceGroupId: s.groupId,
    });
    const res = await joinGroupHouseholdWithDeps(db, s.members[0], s.ref);
    check("forged link ignored by join", res.householdId !== `forged${RUN}` &&
      !(await household(`forged${RUN}`)).memberUserIds.includes(s.members[0]));
    await groupRef(s.owner, s.groupId).update({ friendUserIds: [s.owner] });
    await reconcileGroupHousehold(db, s.ref);
    check("forged link ignored by the trigger",
      (await household(`forged${RUN}`)).memberUserIds.includes(forger));
  }

  {
    const s = await seed("cap", MAX_HOUSEHOLD_MEMBERS, { soloHousehold: true });
    for (let i = 0; i < MAX_HOUSEHOLD_MEMBERS - 1; i++) {
      await joinGroupHouseholdWithDeps(db, s.members[i], s.ref);
    }
    check("cap: household filled to the cap",
      (await household(s.soloId!)).memberUserIds.length === MAX_HOUSEHOLD_MEMBERS);
    await expectThrows("cap: one more join refused",
      () => joinGroupHouseholdWithDeps(
        db, s.members[MAX_HOUSEHOLD_MEMBERS - 1], s.ref),
      "resource-exhausted");
  }

  {
    // The trigger: removal from the group.
    const s = await seed("remove", 2, { soloHousehold: true });
    await joinGroupHouseholdWithDeps(db, s.members[0], s.ref);
    await joinGroupHouseholdWithDeps(db, s.members[1], s.ref);
    const gone = await share(s.soloId!, s.members[0]);
    const kept = await share(s.soloId!, s.members[1]);
    const ownerShare = await share(s.soloId!, s.owner);

    await groupRef(s.owner, s.groupId)
      .update({ friendUserIds: [s.owner, s.members[1]] });
    const res = await reconcileGroupHousehold(db, s.ref);
    const h = await household(s.soloId!);
    check("removal: departed member out of the household",
      JSON.stringify(h.memberUserIds) ===
        JSON.stringify([s.owner, s.members[1]]) &&
        !(s.members[0] in h.memberPermissions) &&
        h.members.every((m: { userId: string }) => m.userId !== s.members[0]),
      JSON.stringify(h));
    check("removal: departed member's share deleted",
      !(await gone.get()).exists && res.removed.length === 1);
    check("removal: remaining member's share untouched",
      (await kept.get()).exists);
    check("removal: owner's share untouched", (await ownerShare.get()).exists);
    check("removal: link kept while the group is a household",
      h.sourceGroupId === s.groupId);

    const quiet = await reconcileGroupHousehold(db, s.ref);
    check("reconcile with nothing to do removes nothing",
      quiet.removed.length === 0 && quiet.unlinked === false);
  }

  {
    // The trigger: un-marking the group.
    const s = await seed("unmark", 2, { soloHousehold: true });
    await joinGroupHouseholdWithDeps(db, s.members[0], s.ref);
    await joinGroupHouseholdWithDeps(db, s.members[1], s.ref);
    const a = await share(s.soloId!, s.members[0]);
    const b = await share(s.soloId!, s.members[1]);
    const ownerShare = await share(s.soloId!, s.owner);

    await groupRef(s.owner, s.groupId).update({ isHousehold: false });
    const res = await reconcileGroupHousehold(db, s.ref);
    const h = await household(s.soloId!);
    check("un-mark: every non-owner removed, owner stays admin",
      JSON.stringify(h.memberUserIds) === JSON.stringify([s.owner]) &&
        h.memberPermissions[s.owner] === "admin" &&
        Object.keys(h.memberPermissions).length === 1 &&
        h.members.length === 1,
      JSON.stringify(h));
    check("un-mark: their shares deleted",
      !(await a.get()).exists && !(await b.get()).exists);
    check("un-mark: owner's share untouched", (await ownerShare.get()).exists);
    check("un-mark: link dropped",
      !("sourceGroupId" in h) && !("sourceGroupOwnerId" in h) &&
        res.unlinked === true);
  }

  {
    // The trigger: the group deleted.
    const s = await seed("delete", 1, { soloHousehold: true });
    await joinGroupHouseholdWithDeps(db, s.members[0], s.ref);
    const a = await share(s.soloId!, s.members[0]);
    await groupRef(s.owner, s.groupId).delete();
    await reconcileGroupHousehold(db, s.ref);
    const h = await household(s.soloId!);
    check("group deleted: member removed and share deleted",
      JSON.stringify(h.memberUserIds) === JSON.stringify([s.owner]) &&
        !(await a.get()).exists,
      JSON.stringify(h));
  }

  {
    // The deployed trigger's wrapper: which writes reach the reconcile.
    const fire = async (
      s: { owner: string; groupId: string },
      before: Record<string, unknown> | undefined,
      after: Record<string, unknown> | undefined,
    ) => onHouseholdGroupWritten.run({
      params: { ownerId: s.owner, groupId: s.groupId },
      data: {
        before: { data: () => before },
        after: { data: () => after },
      },
    });

    const s = await seed("wrapper", 2, { soloHousehold: true });
    await joinGroupHouseholdWithDeps(db, s.members[0], s.ref);
    await joinGroupHouseholdWithDeps(db, s.members[1], s.ref);

    // A write to a group that neither was nor is a household is skipped
    // without a read. Staged with the group un-marked behind the trigger's
    // back, so a reconcile WOULD act if it ran.
    await groupRef(s.owner, s.groupId).update({ isHousehold: false });
    await fire(s, { isHousehold: false }, { isHousehold: false });
    check("wrapper: a non-household write does not reconcile",
      (await household(s.soloId!)).memberUserIds.length === 3);

    // Un-marking is a write whose AFTER is not a household: the BEFORE side
    // is what brings it in.
    await fire(s, { isHousehold: true }, { isHousehold: false });
    const h = await household(s.soloId!);
    check("wrapper: un-marking reconciles",
      JSON.stringify(h.memberUserIds) === JSON.stringify([s.owner]),
      JSON.stringify(h));

    const t = await seed("wrapper2", 1, { soloHousehold: true });
    await joinGroupHouseholdWithDeps(db, t.members[0], t.ref);
    await groupRef(t.owner, t.groupId).update({ friendUserIds: [t.owner] });
    await fire(t, { isHousehold: true }, { isHousehold: true });
    check("wrapper: a member removed from a household group is reconciled",
      JSON.stringify((await household(t.soloId!)).memberUserIds) ===
        JSON.stringify([t.owner]));
  }

  {
    // The linked group's OWNER erases their account. The cascade and the
    // group-deleted trigger can run in either order; both must end with the
    // household, its diner profile and every joined member's share gone.
    const endState = async (tag: string, cascadeFirst: boolean) => {
      const s = await seed(tag, 2, { soloHousehold: true });
      await joinGroupHouseholdWithDeps(db, s.members[0], s.ref);
      await joinGroupHouseholdWithDeps(db, s.members[1], s.ref);
      const a = await share(s.soloId!, s.members[0]);
      const b = await share(s.soloId!, s.members[1]);
      const diner = db.doc(`diner_profiles/diner${tag}${RUN}`);
      await diner.set({
        householdId: s.soloId, name: "Ella", createdBy: s.owner,
      });

      let triggerAfter: { householdIds: string[]; removed: string[] } | null =
        null;
      if (cascadeFirst) {
        await deleteFamilyData(db, s.owner);
        await groupRef(s.owner, s.groupId).delete();
        triggerAfter = await reconcileGroupHousehold(db, s.ref);
      } else {
        await groupRef(s.owner, s.groupId).delete();
        await reconcileGroupHousehold(db, s.ref);
        await deleteFamilyData(db, s.owner);
      }
      return {
        household: (await db.doc(`households/${s.soloId}`).get()).exists,
        shareA: (await a.get()).exists,
        shareB: (await b.get()).exists,
        diner: (await diner.get()).exists,
        triggerAfter,
      };
    };

    const cascadeFirst = await endState("ownerdelA", true);
    const triggerFirst = await endState("ownerdelB", false);
    const gone = (e: typeof cascadeFirst) =>
      !e.household && !e.shareA && !e.shareB && !e.diner;
    check("owner erased, cascade first: household, diner and joined shares " +
      "gone", gone(cascadeFirst), JSON.stringify(cascadeFirst));
    check("owner erased, cascade first: the later trigger is a no-op",
      cascadeFirst.triggerAfter !== null &&
        cascadeFirst.triggerAfter.householdIds.length === 0 &&
        cascadeFirst.triggerAfter.removed.length === 0,
      JSON.stringify(cascadeFirst.triggerAfter));
    check("owner erased, trigger first: the same end state",
      gone(triggerFirst), JSON.stringify(triggerFirst));
  }

  console.log(`\n${run - failed}/${run} passed` +
    (failed ? `, ${failed} failed` : ""));
  if (failed > 0) process.exit(1);
}

run_().catch((err) => {
  console.error(err);
  process.exit(1);
});
