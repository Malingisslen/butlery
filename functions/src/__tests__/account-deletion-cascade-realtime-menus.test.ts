/**
 * BUT-1766 / BUT-1768: deletion cascade realtime menus scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-realtime-menus.test.ts
 */

import {
  DocData,
  FakeFirestore,
} from "./_account-deletion-cascade-fake-firestore";
import {
  OTHER,
  UID,
  asDb,
  check,
  emptyResult,
  finishSuite,
  sawResidual,
} from "./_account-deletion-cascade-test-seeds";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  deleteRealtimeMenus,
  deleteRealtimeResources,
} = require("../account/account-deletion-cascade");

async function scenario_realtimeMenusOwnedAreDeleted(): Promise<void> {
  const db = new FakeFirestore();
  db.set("realtime_menus/mine", {
    ownerId: UID,
    userId: "not-the-owner-field",
    lastEditedBy: UID,
    lastEditedByDisplayName: "Malin",
  });
  db.set("realtime_menus/theirs", {
    ownerId: OTHER,
    lastEditedBy: OTHER,
    lastEditedByDisplayName: "Anna",
  });

  await deleteRealtimeMenus(asDb(db), UID);

  check(
    "a realtime menu the user OWNS is deleted",
    !db.has("realtime_menus/mine"),
  );
  check(
    "a realtime menu owned and edited by someone else is untouched",
    db.get("realtime_menus/theirs")?.lastEditedByDisplayName === "Anna",
  );
}

/**
 * The other half of the decision: a menu the user does not own stays (it is its
 * owner's data and the other participants are still collaborating on it), but
 * the denormalised last-editor identity pair goes — nothing renames it once the
 * account is gone, so it would otherwise sit there forever.
 */
async function scenario_realtimeMenuLastEditorIsScrubbed(): Promise<void> {
  const db = new FakeFirestore();
  db.set("realtime_menus/shared", {
    ownerId: OTHER,
    participantIds: [OTHER, UID],
    lastEditedBy: UID,
    lastEditedByDisplayName: "Malin",
    title: "Veckans middagar",
  });

  await deleteRealtimeMenus(asDb(db), UID);

  const shared = db.get("realtime_menus/shared");
  check(
    "a menu the user only EDITED is kept for its owner",
    shared !== undefined && shared.title === "Veckans middagar",
  );
  check(
    "its last-editor pair is anonymized, not nulled",
    shared?.lastEditedBy === "deleted" &&
      shared?.lastEditedByDisplayName === "[Raderad användare]",
    `got ${JSON.stringify(shared)}`,
  );
}

/**
 * BUT-2151: live menus in `realtime_resources`. Owned goes; someone else's
 * stays with the last-editor pair anonymized; the user leaves the roster in
 * BOTH fields, which the rules require to match.
 */
async function scenario_realtimeResourcesAreErased(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`realtime_resources/${UID}_m1`, {
    type: "menu",
    ownerId: UID,
    participants: { [UID]: "owner" },
    participantIds: [UID],
  });
  db.set(`realtime_resources/${OTHER}_m2`, {
    type: "menu",
    ownerId: OTHER,
    participants: { [OTHER]: "owner", [UID]: "editor" },
    participantIds: [OTHER, UID],
    lastEditedBy: UID,
    lastEditedByDisplayName: "Malin",
    menuTitle: "Veckans middagar",
  });

  await deleteRealtimeResources(asDb(db), UID);

  check(
    "a live menu the user OWNS is deleted",
    !db.has(`realtime_resources/${UID}_m1`),
  );
  const kept = db.get(`realtime_resources/${OTHER}_m2`);
  check(
    "someone else's live menu is kept for its owner",
    kept?.menuTitle === "Veckans middagar",
  );
  check(
    "its last-editor pair is anonymized",
    kept?.lastEditedBy === "deleted" &&
      kept?.lastEditedByDisplayName === "[Raderad användare]",
    `got ${JSON.stringify(kept)}`,
  );
  check(
    "the user leaves both roster fields",
    Array.isArray(kept?.participantIds) &&
      !(kept?.participantIds as string[]).includes(UID) &&
      !Object.keys((kept?.participants ?? {}) as object).includes(UID),
    `got ${JSON.stringify(kept)}`,
  );
}

/**
 * BUT-2214: the menus the user took part in stay for their owners, but no
 * dish in them may name the user afterwards — by uid anywhere in it, or by
 * the display name an older whole-recipe dish carries beside the uid.
 */
function menuWithDishes(): DocData {
  return {
    middag: [
      // Flat, as the app stores a dish since BUT-2214; the user's uid also
      // sits in two nested fields the core keeps.
      {
        id: "mine-flat",
        title: "Linsgryta",
        createdBy: UID,
        heirloom: { addedByUserId: UID, writerName: "Farmor Elsa" },
        tagOverrides: { lastEditedBy: UID },
        // A map keyed by the uid, as a hand-rolled client could write.
        handRolled: { [UID]: true },
      },
      { id: "theirs", title: "Pasta", createdBy: OTHER },
      // A whole recipe, as a client before BUT-2214 stores it: names beside
      // the ids, and the owner's personal tags.
      {
        core: {
          id: "mine-whole",
          title: "Soppa",
          createdBy: UID,
          personalTagIds: ["barnens-favoriter"],
        },
        type: 2,
        socialData: {
          ownerId: UID,
          ownerDisplayName: "Malin",
          memberPermissions: { [UID]: "editor", [OTHER]: "viewer" },
        },
        realtimeData: {
          lastEditedByUserId: UID,
          lastEditedByDisplayName: "Malin",
        },
      },
    ],
  };
}

function checkDishesScrubbed(where: string, menu: DocData | undefined): void {
  const dishes = ((menu?.menuSnapshot as DocData | undefined)?.middag ??
    []) as DocData[];
  const text = JSON.stringify(dishes);
  const flat = dishes.find((d) => d.id === "mine-flat");
  const whole = dishes.find((d) => d.id === "mine-whole");
  const theirs = dishes.find((d) => d.id === "theirs");
  check(
    `${where}: no dish holds the user's uid`,
    dishes.length === 3 && !text.includes(UID),
    `got ${text}`,
  );
  check(
    `${where}: no dish holds the user's name`,
    !text.includes("Malin"),
    `got ${text}`,
  );
  check(
    `${where}: the user's dishes keep their content, "deleted" in the uid's place`,
    flat?.title === "Linsgryta" &&
      flat?.createdBy === "deleted" &&
      (flat?.heirloom as DocData | undefined)?.addedByUserId === "deleted" &&
      (flat?.heirloom as DocData | undefined)?.writerName === "Farmor Elsa" &&
      whole?.title === "Soppa" &&
      whole?.createdBy === "deleted",
    `got ${text}`,
  );
  check(
    `${where}: an older whole-recipe dish becomes a menu dish`,
    whole !== undefined &&
      !("core" in whole) &&
      !("socialData" in whole) &&
      !("realtimeData" in whole) &&
      !("type" in whole) &&
      !("personalTagIds" in whole),
    `got ${JSON.stringify(whole)}`,
  );
  check(
    `${where}: someone else's dish is left as it was`,
    JSON.stringify(theirs) ===
      JSON.stringify({ id: "theirs", title: "Pasta", createdBy: OTHER }),
    `got ${JSON.stringify(theirs)}`,
  );
}

async function scenario_menuDishCreatorIsScrubbed(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`realtime_resources/${OTHER}_m2`, {
    type: "menu",
    ownerId: OTHER,
    participants: { [OTHER]: "owner", [UID]: "editor" },
    participantIds: [OTHER, UID],
    menuSnapshot: menuWithDishes(),
  });
  db.set("realtime_menus/theirs", {
    ownerId: OTHER,
    participantIds: [OTHER, UID],
    menuSnapshot: menuWithDishes(),
  });
  // Shared without a members row (the direct-share managers) ...
  db.set("shared_content/their-menu", {
    contentType: "menu",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, UID],
    menuSnapshot: menuWithDishes(),
  });
  // ... and through `addMember`, which writes the members row AND the array:
  // the members leg removes the uid from the array before anything after it.
  db.set("shared_content/invited-menu", {
    contentType: "menu",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, UID],
    menuSnapshot: menuWithDishes(),
  });
  db.set(`shared_content/invited-menu/members/${UID}`, { userId: UID });

  await deleteRealtimeResources(asDb(db), UID);
  await deleteRealtimeMenus(asDb(db), UID);
  const { removeFromSharedContent } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  await removeFromSharedContent(asDb(db), UID);

  checkDishesScrubbed(
    "realtime_resources",
    db.get(`realtime_resources/${OTHER}_m2`),
  );
  checkDishesScrubbed("realtime_menus", db.get("realtime_menus/theirs"));
  checkDishesScrubbed(
    "shared_content, direct share",
    db.get("shared_content/their-menu"),
  );
  checkDishesScrubbed(
    "shared_content, invited",
    db.get("shared_content/invited-menu"),
  );
}

/**
 * Firestore does not cascade a document delete to its subcollections. Deleting
 * the parent menu bare leaves `presence/{uid}` (which carries a displayName)
 * and `votes/{voteId}` (whose `votes` map is keyed by uid) permanently
 * orphaned: unreadable by any client, unfindable by any later erasure, and
 * invisible to a residual probe that counts top-level documents.
 */
async function scenario_ownedRealtimeMenuChildrenAreDeleted(): Promise<void> {
  const db = new FakeFirestore();
  db.set("realtime_menus/mine", { ownerId: UID, participantIds: [UID, OTHER] });
  db.set("realtime_menus/mine/presence/" + UID, {
    displayName: "Malin",
    isActive: true,
  });
  db.set("realtime_menus/mine/votes/slot-1", {
    votes: { [UID]: "option-a", [OTHER]: "option-b" },
  });

  await deleteRealtimeMenus(asDb(db), UID);

  check(
    "the owned menu document is deleted",
    !db.has("realtime_menus/mine"),
  );
  check(
    "its presence subcollection goes with it",
    db.pathsUnder("realtime_menus/mine/presence").length === 0,
    `left behind: ${JSON.stringify(db.pathsUnder("realtime_menus/mine/presence"))}`,
  );
  check(
    "its votes subcollection goes with it",
    db.pathsUnder("realtime_menus/mine/votes").length === 0,
    `left behind: ${JSON.stringify(db.pathsUnder("realtime_menus/mine/votes"))}`,
  );
}

/**
 * The third residual on this surface, and the one `scrubLastEditor` cannot
 * reach: a collaborator who joined, was seen and voted but never made the final
 * edit. Their presence document, their `participants` MAP KEY (which
 * `firestore.rules` reads as live write authorization) and their ballot entry
 * all sat on someone else's menu indefinitely.
 */
async function scenario_realtimeParticipationIsRemoved(): Promise<void> {
  const db = new FakeFirestore();
  db.set("realtime_menus/theirs", {
    ownerId: OTHER,
    participantIds: [OTHER, UID],
    participants: { [OTHER]: "owner", [UID]: "editor" },
    lastEditedBy: OTHER,
    lastEditedByDisplayName: "Anna",
  });
  db.set("realtime_menus/theirs/presence/" + UID, { displayName: "Malin" });
  db.set("realtime_menus/theirs/presence/" + OTHER, { displayName: "Anna" });
  db.set("realtime_menus/theirs/votes/slot-1", {
    votes: { [UID]: "option-a", [OTHER]: "option-b" },
  });

  await deleteRealtimeMenus(asDb(db), UID);

  const menu = db.get("realtime_menus/theirs") as DocData;
  check(
    "someone else's menu still exists — it is their data",
    menu !== undefined && menu.ownerId === OTHER,
  );
  check(
    "the deleted user is removed from participantIds",
    JSON.stringify(menu.participantIds) === JSON.stringify([OTHER]),
    `got ${JSON.stringify(menu.participantIds)}`,
  );
  check(
    "their participants MAP KEY — a live write grant — is removed",
    !(UID in (menu.participants as Record<string, unknown>)),
    `got ${JSON.stringify(menu.participants)}`,
  );
  check(
    "their presence document is deleted, the other member's is not",
    !db.has(`realtime_menus/theirs/presence/${UID}`) &&
      db.has(`realtime_menus/theirs/presence/${OTHER}`),
    `left: ${JSON.stringify(db.pathsUnder("realtime_menus/theirs/presence"))}`,
  );
  const ballot = (db.get("realtime_menus/theirs/votes/slot-1") as DocData)
    .votes as Record<string, unknown>;
  check(
    "their uid is stripped from the vote map, the other vote is kept",
    !(UID in ballot) && ballot[OTHER] === "option-b",
    `got ${JSON.stringify(ballot)}`,
  );
}

/**
 * BUT-1971: the three group-weekly-menu legs of the residual probe.
 *
 * The deleter finds a group plan through three handles — the queryable roster,
 * the document-level `lastModifiedBy`, and the ACL key
 * `memberPermissions.<uid>` — because the Art. 15 export discovers on the last
 * of those and erasure may never be narrower than export. The probe carries the
 * same three, and they are the only thing that contradicts a scrub which claim-lint:ok moved unchanged, BUT-2113
 * reported success over a failed chunk (`commitInChunks` runs `strict: false`).
 *
 * Nothing observed them. The integration lane asserts `failedCollections` is
 * EMPTY, so deleting any one leg makes the probe blind and the assertion
 * happier, not redder. Each case below seeds a document reachable by exactly
 * ONE handle, so removing that leg leaves its case green-expected-red.
 *
 * The ACL leg is queried with a `FieldPath`, which the fake resolves via
 * `.segments`; teaching it to is what makes that case measure the leg rather
 * than the stub. Each of the three legs was mutation-probed with a compiling
 * mutant and its own case reddened alone.
 *
 * The clean control is weaker here, and that is
 * worth knowing rather than assuming: a fake that mis-resolves a `FieldPath`
 * matches nothing instead of throwing, so it produces a silent zero, and only
 * the DIRTY ACL case can see that. Measured — the control stays green under
 * that mutant. It still earns its place: a
 * method the probe needs but the fake lacks lands in a per-leg catch and counts
 * as residual, which would make every dirty half pass for the wrong reason.
 */
async function scenario_probeSeesLeftoverGroupMenuPlans(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const result = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });

  // All three handles are clean while the uid is still on the per-dish
  // provenance and in the trail, so the probe reads CLEAN over data that is
  // present. The two rows are projections, not what `toFirestore` writes: the
  // probe reads neither field, and only their presence matters here.
  const clean = new FakeFirestore();
  clean.set("group_weekly_menu_plans/g1_2026-W30", {
    participantUserIds: [OTHER],
    memberPermissions: { [OTHER]: "admin" },
    lastModifiedBy: OTHER,
    entries: [{ id: "e1", proposedBy: UID, votedInBy: [UID, OTHER] }],
    editTrail: [{ actorId: UID, subjectId: OTHER, entryId: "e1" }],
  });
  const cleanResult = result();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "a group menu plan clean on all three handles probes CLEAN — even with the " +
      "uid still on the dishes and in the trail, which no handle can reach",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  // Each case is spelled out whole rather than spread over a shared base: a
  // spread that overwrites an earlier key is a TS2783 error, and silencing it
  // by reordering is how a case ends up seeding a handle it did not mean to.
  for (const [label, doc] of [
    [
      "the roster",
      {
        participantUserIds: [OTHER, UID],
        memberPermissions: { [OTHER]: "admin" },
        lastModifiedBy: OTHER,
      },
    ],
    [
      "the last writer",
      {
        participantUserIds: [OTHER],
        memberPermissions: { [OTHER]: "admin" },
        lastModifiedBy: UID,
      },
    ],
    [
      "the permission key",
      {
        participantUserIds: [OTHER],
        memberPermissions: { [OTHER]: "admin", [UID]: "edit" },
        lastModifiedBy: OTHER,
      },
    ],
  ] as const) {
    const dirty = new FakeFirestore();
    dirty.set("group_weekly_menu_plans/g1_2026-W30", doc);
    const dirtyResult = result();
    await probeResidualData(asDb(dirty), UID, dirtyResult);
    check(
      `a group menu plan still naming the user in ${label} is reported as residual`,
      dirtyResult.failedCollections.includes("residual_data_detected"),
      `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
    );
  }
}

/**
 * BUT-2151: the `realtime_resources` legs of the residual probe.
 */
async function scenario_probeSeesLeftoverRealtimeResources(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const result = () => ({
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  });

  const clean = new FakeFirestore();
  clean.set(`realtime_resources/${OTHER}_m`, {
    ownerId: OTHER,
    participantIds: [OTHER],
    lastEditedBy: OTHER,
  });
  const cleanResult = result();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "a live menu clean on all three handles probes CLEAN",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  for (const [label, doc] of [
    [
      "the owner field",
      { ownerId: UID, participantIds: [OTHER], lastEditedBy: OTHER },
    ],
    [
      "the last editor",
      { ownerId: OTHER, participantIds: [OTHER], lastEditedBy: UID },
    ],
    [
      "the roster",
      { ownerId: OTHER, participantIds: [OTHER, UID], lastEditedBy: OTHER },
    ],
  ] as const) {
    const dirty = new FakeFirestore();
    dirty.set(`realtime_resources/${OTHER}_m`, doc);
    const dirtyResult = result();
    await probeResidualData(asDb(dirty), UID, dirtyResult);
    check(
      `a live menu still naming the user in ${label} is reported as residual`,
      dirtyResult.failedCollections.includes("residual_data_detected"),
      `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
    );
  }
}

/**
 * BUT-2118: the erased user's live-menu ballot documents go on every menu,
 * including one they LEFT (no longer in `participantIds`), and nothing else
 * does: another participant's ballot, the legacy `realtime_menus` vote shape
 * and a `votes` document under some other parent all stay.
 */
async function scenario_liveMenuBallotsAreDeleted(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`realtime_resources/${OTHER}_joined`, {
    type: "menu",
    ownerId: OTHER,
    participants: { [OTHER]: "owner", [UID]: "viewer" },
    participantIds: [OTHER, UID],
  });
  db.set(`realtime_resources/${OTHER}_joined/votes/${UID}`, {
    userId: UID,
    ballots: { "vote-1": "opt-a" },
  });
  db.set(`realtime_resources/${OTHER}_joined/votes/${OTHER}`, {
    userId: OTHER,
    ballots: { "vote-1": "opt-b" },
  });
  db.set(`realtime_resources/${OTHER}_left`, {
    type: "menu",
    ownerId: OTHER,
    participants: { [OTHER]: "owner" },
    participantIds: [OTHER],
  });
  db.set(`realtime_resources/${OTHER}_left/votes/${UID}`, {
    userId: UID,
    proposals: { "vote-2": { id: "opt-c" } },
  });
  db.set("realtime_menus/legacy/votes/slot-1", {
    userId: UID,
    votes: { [UID]: "opt-a" },
  });
  db.set(`elsewhere/x/votes/${UID}`, { userId: UID });
  db.set(`x/y/realtime_resources/z/votes/${UID}`, { userId: UID });

  const ok = await deleteRealtimeResources(asDb(db), UID);

  check("the live-menu step reports success", ok === true);
  check(
    "the ballot on a menu the user is still in is deleted",
    db.get(`realtime_resources/${OTHER}_joined/votes/${UID}`) === undefined,
  );
  check(
    "the ballot on a menu the user LEFT is deleted",
    db.get(`realtime_resources/${OTHER}_left/votes/${UID}`) === undefined,
  );
  check(
    "another participant's ballot stays",
    db.get(`realtime_resources/${OTHER}_joined/votes/${OTHER}`) !== undefined,
  );
  check(
    "the legacy realtime_menus vote document is not this leg's",
    db.get("realtime_menus/legacy/votes/slot-1") !== undefined,
  );
  check(
    "a `votes` document under another parent collection stays",
    db.get(`elsewhere/x/votes/${UID}`) !== undefined,
  );
  check(
    "a `votes` document under a nested realtime_resources stays",
    db.get(`x/y/realtime_resources/z/votes/${UID}`) !== undefined,
  );
}

/** BUT-2118: above the cap the sweep declines and reports itself incomplete. */
async function scenario_implausibleLiveMenuBallotCountDeclines(): Promise<void> {
  const {
    deleteLiveMenuVotes,
    MAX_LIVE_MENU_VOTE_SWEEP_ROWS,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  for (let i = 0; i <= MAX_LIVE_MENU_VOTE_SWEEP_ROWS; i++) {
    db.set(`realtime_resources/m${i}/votes/${UID}`, { userId: UID });
  }

  const ok = await deleteLiveMenuVotes(asDb(db), UID);

  check("an implausible ballot count makes the step report failure", ok === false);
  check(
    "nothing is deleted when the sweep declines",
    db.get(`realtime_resources/m0/votes/${UID}`) !== undefined,
  );

  const atCap = new FakeFirestore();
  for (let i = 0; i < MAX_LIVE_MENU_VOTE_SWEEP_ROWS; i++) {
    atCap.set(`realtime_resources/m${i}/votes/${UID}`, { userId: UID });
  }
  const atCapOk = await deleteLiveMenuVotes(asDb(atCap), UID);
  check(
    "exactly at the cap the sweep runs",
    atCapOk === true &&
      atCap.get(`realtime_resources/m0/votes/${UID}`) === undefined,
  );
}

/**
 * BUT-2118: a rejected chunk fails the step without throwing, so the menu
 * legs after it still run.
 */
async function scenario_failedLiveMenuBallotChunkFailsTheStep(): Promise<void> {
  const db = new FakeFirestore();
  db.set(`realtime_resources/m1/votes/${UID}`, { userId: UID });
  db.batchFailures.set(`realtime_resources/m1/votes/${UID}`, 13);
  db.set(`realtime_resources/m2`, {
    type: "menu",
    ownerId: OTHER,
    participants: { [OTHER]: "owner", [UID]: "viewer" },
    participantIds: [OTHER, UID],
  });

  const ok = await deleteRealtimeResources(asDb(db), UID);

  check("a rejected ballot chunk makes the step report failure", ok === false);
  check(
    "the roster leg still runs after a failed ballot sweep",
    !((db.get("realtime_resources/m2")?.participantIds as string[]) ?? []).includes(UID),
  );
  check(
    "the ballot is still there for the probe to find",
    db.get(`realtime_resources/m1/votes/${UID}`) !== undefined,
  );
}

/** BUT-2118: the probe sees a ballot document left behind. */
async function scenario_probeSeesLeftoverLiveMenuBallot(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const dirty = new FakeFirestore();
  dirty.set(`realtime_resources/m1/votes/${UID}`, { userId: UID });
  const dirtyResult = emptyResult();
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "a surviving live-menu ballot is reported as residual",
    sawResidual(dirtyResult),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );

  // Above the cap the sweep declines, so the probe must still report.
  const { MAX_LIVE_MENU_VOTE_SWEEP_ROWS } = require("../account/account-deletion-cascade");
  const overCap = new FakeFirestore();
  for (let i = 0; i <= MAX_LIVE_MENU_VOTE_SWEEP_ROWS; i++) {
    overCap.set(`realtime_resources/m${i}/votes/${UID}`, { userId: UID });
  }
  const overCapResult = emptyResult();
  await probeResidualData(asDb(overCap), UID, overCapResult);
  check(
    "a ballot count above the sweep cap is reported as residual",
    sawResidual(overCapResult),
    `failed: ${JSON.stringify(overCapResult.failedCollections)}`,
  );

  const clean = new FakeFirestore();
  clean.set(`realtime_resources/m1/votes/${OTHER}`, { userId: OTHER });
  // A `votes` document elsewhere naming the user is not the deleter's, so the
  // probe must not count it either, or the erasure could never come back clean.
  clean.set(`realtime_menus/m1/votes/${OTHER}`, { userId: UID });
  clean.set(`elsewhere/x/votes/${UID}`, { userId: UID });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "someone else's ballot, or a `votes` document under another parent, does not make the probe fire",
    !sawResidual(cleanResult),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );
}

async function main(): Promise<void> {
  await scenario_realtimeMenusOwnedAreDeleted();
  await scenario_realtimeMenuLastEditorIsScrubbed();
  await scenario_ownedRealtimeMenuChildrenAreDeleted();
  await scenario_realtimeParticipationIsRemoved();
  await scenario_realtimeResourcesAreErased();
  await scenario_menuDishCreatorIsScrubbed();
  await scenario_probeSeesLeftoverGroupMenuPlans();
  await scenario_probeSeesLeftoverRealtimeResources();
  await scenario_liveMenuBallotsAreDeleted();
  await scenario_implausibleLiveMenuBallotCountDeclines();
  await scenario_failedLiveMenuBallotChunkFailsTheStep();
  await scenario_probeSeesLeftoverLiveMenuBallot();

  finishSuite("BUT-1766/BUT-1768 deletion cascade realtime menus");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
