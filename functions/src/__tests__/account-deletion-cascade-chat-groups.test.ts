/**
 * BUT-1766 / BUT-1768: deletion cascade chat groups and rosters scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-chat-groups.test.ts
 */

import {
  DocData,
  FakeFirestore,
} from "./_account-deletion-cascade-fake-firestore";
import {
  OTHER,
  THIRD,
  UID,
  asDb,
  check,
  finishSuite,
  seedMessage,
} from "./_account-deletion-cascade-test-seeds";

// eslint-disable-next-line @typescript-eslint/no-require-imports
const {
  deleteMessages,
} = require("../account/account-deletion-cascade");

/** Seed one roster row the way `ConversationParticipant.toFirestore` writes it. */
function seedRosterRow(
  db: FakeFirestore,
  conversationId: string,
  uid: string,
  displayName: string,
): void {
  db.set(`conversations/${conversationId}/participants/${uid}`, {
    conversationId,
    participantId: uid,
    displayName,
    avatarUrl: `https://example.test/${uid}.jpg`,
    role: "member",
    isMuted: false,
  });
}

/**
 * BUT-1822 leg 2: the erased user's OWN roster row, in a surviving group. It
 * carries their displayName and avatarUrl, and nothing in the cascade had ever
 * touched this path — the conversation document keeps running for everyone else,
 * so there is no later erasure that could find it.
 */
async function scenario_ownRosterRowIsErasedInSurvivingGroup(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/c-group", {
    participantIds: [UID, OTHER, "third-uid"],
    participantDisplayNames: { [UID]: "Raderad", [OTHER]: "Kvar" },
  });
  seedRosterRow(db, "c-group", UID, "Raderad");
  seedRosterRow(db, "c-group", OTHER, "Kvar");

  await deleteMessages(asDb(db), UID);

  check(
    "the erased user's roster row is deleted from a surviving group",
    !db.has(`conversations/c-group/participants/${UID}`),
  );
  check(
    "another member's roster row is untouched",
    db.has(`conversations/c-group/participants/${OTHER}`),
  );
  check(
    "the surviving group document itself is kept",
    db.has("conversations/c-group"),
  );
}

/**
 * BUT-1822 leg 1, and the ordering it turns on. Deleting the conversation is the
 * write that makes `parentDoc() == null` true, and every predicate that could
 * surface a row reads through the parent — so whatever rows survive become
 * UNREADABLE forever (delete and the `lastReadAt` stamp key on the subject's
 * own uid, and no client flow uses either). The SURVIVING partner's row is
 * the one that matters: its `participantId` is not the erased uid, so leg 2's
 * collection-group sweep can never reach it either. Until BUT-1838 this was worse
 * than unreachable — a bootstrap branch re-opened those rows to any signed-in
 * user, so the partner kept LIST over the erased user's name and avatar forever.
 *
 * Asserting only "both are gone" would pass on the broken code too, since the
 * sweep would still take the erased user's own row. The ORDER is the test.
 */
async function scenario_rosterIsClearedBeforeTheParentDelete(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/direct_a_b", { participantIds: [UID, OTHER] });
  seedRosterRow(db, "direct_a_b", UID, "Raderad");
  seedRosterRow(db, "direct_a_b", OTHER, "Partner");

  await deleteMessages(asDb(db), UID);

  check(
    "the 1:1 conversation is gone",
    !db.has("conversations/direct_a_b"),
  );
  check(
    "the SURVIVING partner's roster row is gone too (no collectionGroup leg can find it)",
    !db.has(`conversations/direct_a_b/participants/${OTHER}`),
    `left: ${JSON.stringify(db.pathsUnder("conversations/direct_a_b/participants"))}`,
  );
  const parentAt = db.deletedPaths.indexOf("conversations/direct_a_b");
  const partnerAt = db.deletedPaths.indexOf(
    `conversations/direct_a_b/participants/${OTHER}`,
  );
  check(
    "the roster row is deleted BEFORE the parent document",
    partnerAt >= 0 && parentAt >= 0 && partnerAt < parentAt,
    `delete order: ${JSON.stringify(db.deletedPaths)}`,
  );
}

/**
 * When the roster cannot be proven clear, `tryClearRoster` returns false and the
 * parent must NOT be deleted — a live parent that no longer names the erased
 * user still lets the SURVIVING partner list what is left — the read rule is
 * not row-scoped and `buildGroupDepartureUpdate` only `arrayRemove`s the erased
 * uid — which is acceptable because leg 2 sweeps the erased user's own row.
 * Deleting the parent instead makes every row unreadable
 * forever (and, until BUT-1838, re-opened a bootstrap branch over them). But an untouched document keeps their name in
 * `participantDisplayNames` forever, so the departure update runs instead.
 *
 * Staged SYNTHETICALLY, via the clearer's refusal cap — the cheapest way to
 * force a false verdict. Production does NOT reach the branch that way for a
 * direct conversation: only the two attested participants may write rows, and
 * `directIdBinds` pins `participantIds` to exactly two with the update rule
 * denying any diff that touches it — so such a roster holds at most TWO
 * client-written rows, ever, which can never reach the refusal cap. For a
 * `direct_` id the real route is therefore a transient roster read or delete
 * failure; a LEGACY non-direct conversation reaches this branch too and can hit
 * the cap through rows seeded before BUT-1838.
 */
async function scenario_unclearableRosterLeavesTheParentStanding(): Promise<void> {
  const db = new FakeFirestore();
  db.set("conversations/direct_seeded", {
    participantIds: [UID, OTHER],
    participantDisplayNames: { [UID]: "Raderad", [OTHER]: "Partner" },
    participantAvatarUrls: { [UID]: "https://example.test/x.jpg" },
  });
  seedRosterRow(db, "direct_seeded", UID, "Raderad");
  seedRosterRow(db, "direct_seeded", OTHER, "Partner");
  // 500 is MAX_ROSTER_ROWS; the read is `.limit(MAX + 1)`, so 501 rows is the
  // smallest roster the clearer refuses.
  for (let i = 0; i < 499; i++) {
    seedRosterRow(db, "direct_seeded", `seeded-${i}`, `Seeded ${i}`);
  }

  const ok = await deleteMessages(asDb(db), UID);

  check(
    "an unclearable roster leaves the conversation standing",
    db.has("conversations/direct_seeded"),
  );
  check(
    "…and the step reports INCOMPLETE, so the audit cannot say gdprCompliant",
    ok === false,
    // A `direct_` id is literally `direct_<erasedUid>_<survivorUid>`: the
    // surviving document keeps the erased user's identifier in its own id,
    // where no field-keyed probe can see it. Reporting success here would
    // certify an erasure that did not happen.
    `deleteMessages returned ${ok}`,
  );
  // `?? {}` deliberately: the failure this scenario guards against is the
  // conversation being DELETED, and reading through an absent document would
  // throw a TypeError that kills the whole runner instead of reddening one
  // assertion.
  const convo = (db.get("conversations/direct_seeded") ?? {}) as DocData;
  // Mutation-proven, with one honest caveat: this single assertion passes
  // VACUOUSLY if the conversation is deleted instead (an absent document has no
  // name to find), so it is the two below — participantIds present-and-cleaned,
  // and the partner's name still there — that catch a wrongly-deleted parent.
  // Do not "simplify" them away as redundant; each of the three reddens under a
  // different mutant.
  check(
    "…but the erased user's name is stripped from it anyway",
    (convo.participantDisplayNames as DocData)?.[UID] === undefined &&
      (convo.participantAvatarUrls as DocData)?.[UID] === undefined,
    `left: ${JSON.stringify(convo.participantDisplayNames)}`,
  );
  check(
    "…and their participantIds entry is removed",
    Array.isArray(convo.participantIds) &&
      !(convo.participantIds as string[]).includes(UID),
    `participantIds: ${JSON.stringify(convo.participantIds)}`,
  );
  check(
    "the partner's name is kept — it is not theirs to erase",
    (convo.participantDisplayNames as DocData)?.[OTHER] === "Partner",
  );
}

/**
 * The residual probe is the safety net for this whole class of gap: the deleter
 * must stay a strict superset of it. Before BUT-1822 the probe had NO
 * collection-group leg for `participants`, so it certified every erasure clean
 * over live roster rows.
 *
 * A clean store is asserted first. Without it, a stub method the probe needs but
 * does not have would land in one of its per-leg catches, count as residual, and
 * make the second half of this scenario pass for the wrong reason.
 */
async function scenario_probeSeesLeftoverRosterRows(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const clean = new FakeFirestore();
  clean.set("conversations/c-group", { participantIds: [OTHER] });
  const cleanResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  };
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "a store with nothing of the user's left probes CLEAN",
    !cleanResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );

  const dirty = new FakeFirestore();
  dirty.set("conversations/c-group", { participantIds: [OTHER] });
  seedRosterRow(dirty, "c-group", UID, "Raderad");
  const dirtyResult = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  };
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "one leftover roster row is reported as residual data",
    dirtyResult.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );
}

// ─── BUT-1838: chat-group membership ──────────────────────────────────────

/**
 * Seeds a chat group the way `groups/chat-group-writes.ts` writes one: the group
 * document, its conversation (carrying `groupId`, which is what marks the
 * conversation group-owned) and a roster row per member. Every uid-keyed
 * carrier is populated, because
 * an assertion that a key is GONE proves nothing over a key that was never there.
 */
function seedChatGroup(
  db: FakeFirestore,
  groupId: string,
  conversationId: string,
  opts: {
    members: string[];
    admins: string[];
    createdBy: string;
    addedBy?: string;
  },
): void {
  const { members, admins, createdBy } = opts;
  const addedBy = opts.addedBy ?? createdBy;
  const perUid = <T>(value: (uid: string) => T): Record<string, T> =>
    Object.fromEntries(members.map((uid) => [uid, value(uid)]));

  db.set(`chat_groups/${groupId}`, {
    name: "Familjen",
    memberIds: [...members],
    adminIds: [...admins],
    memberDisplayNames: perUid((uid) => (uid === UID ? "Raderad" : `Namn ${uid}`)),
    memberAvatarUrls: perUid((uid) => `https://example.test/${uid}.jpg`),
    memberAddedBy: perUid(() => addedBy),
    conversationId,
    createdBy,
    createdAt: "t0",
    updatedAt: "t0",
  });
  db.set(`conversations/${conversationId}`, {
    participantIds: [...members],
    participantDisplayNames: perUid((uid) =>
      uid === UID ? "Raderad" : `Namn ${uid}`,
    ),
    participantAvatarUrls: perUid((uid) => `https://example.test/${uid}.jpg`),
    lastReadTimestamps: perUid(() => "t0"),
    perUserSettings: perUid(() => ({ isMuted: false })),
    memberSince: perUid(() => "t0"),
    groupId,
    isGroup: true,
    title: "Familjen",
  });
  for (const uid of members) {
    seedRosterRow(db, conversationId, uid, uid === UID ? "Raderad" : `Namn ${uid}`);
  }
}

/** The five uid-keyed maps a conversation document carries. */
const CONVERSATION_UID_MAPS = [
  "participantDisplayNames",
  "participantAvatarUrls",
  "lastReadTimestamps",
  "perUserSettings",
  "memberSince",
] as const;

/**
 * BUT-1838, the surviving-group case. "Who is in this group" lives in three
 * places (group, conversation, roster row) precisely because three readers need
 * it and none can read the others — so an erasure that clears one and not the
 * others leaves copies that disagree, which is the BUT-1798 failure in a new
 * collection. All three go through the one writer, `stageMemberRemoval`.
 *
 * `memberSince` is the newest of the five conversation maps and the easiest to
 * forget: it is the history cut-off `firestore.rules` reads, and a stale entry
 * would silently pin an old cut-off if the uid were ever reused.
 */
async function scenario_chatGroupMembershipIsErasedEverywhere(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  seedChatGroup(db, "g-keep", "cg-keep", {
    members: [UID, OTHER, THIRD],
    admins: [UID, OTHER],
    createdBy: OTHER,
  });

  const ok = await deleteChatGroupMemberships(asDb(db), UID);
  check("a surviving group reports the step complete", ok === true, `returned ${ok}`);

  const group = (db.get("chat_groups/g-keep") ?? {}) as DocData;
  check(
    "the uid leaves chat_groups.memberIds",
    Array.isArray(group.memberIds) && !(group.memberIds as string[]).includes(UID),
    `memberIds: ${JSON.stringify(group.memberIds)}`,
  );
  check(
    "…and adminIds, so nobody administers a group they are not in",
    Array.isArray(group.adminIds) &&
      !(group.adminIds as string[]).includes(UID) &&
      (group.adminIds as string[]).includes(OTHER),
    `adminIds: ${JSON.stringify(group.adminIds)}`,
  );
  check(
    "…and both group display maps and memberAddedBy",
    (group.memberDisplayNames as DocData)?.[UID] === undefined &&
      (group.memberAvatarUrls as DocData)?.[UID] === undefined &&
      (group.memberAddedBy as DocData)?.[UID] === undefined,
    `left: ${JSON.stringify(group.memberDisplayNames)} / ${JSON.stringify(group.memberAddedBy)}`,
  );
  check(
    "the other members' group entries survive the dot-path deletes",
    (group.memberDisplayNames as DocData)?.[OTHER] !== undefined &&
      (group.memberAddedBy as DocData)?.[THIRD] !== undefined,
    `left: ${JSON.stringify(group.memberDisplayNames)}`,
  );

  const convo = (db.get("conversations/cg-keep") ?? {}) as DocData;
  check(
    "the uid leaves the conversation's participantIds",
    Array.isArray(convo.participantIds) &&
      !(convo.participantIds as string[]).includes(UID),
    `participantIds: ${JSON.stringify(convo.participantIds)}`,
  );
  const stillKeyed = CONVERSATION_UID_MAPS.filter(
    (map) => (convo[map] as DocData)?.[UID] !== undefined,
  );
  check(
    "…and every one of the FIVE uid-keyed conversation maps, memberSince included",
    stillKeyed.length === 0,
    `still keyed by the erased uid: ${JSON.stringify(stillKeyed)}`,
  );
  check(
    "another member keeps all five",
    CONVERSATION_UID_MAPS.every((map) => (convo[map] as DocData)?.[OTHER] !== undefined),
    `partner maps: ${JSON.stringify(CONVERSATION_UID_MAPS.map((m) => (convo[m] as DocData)?.[OTHER]))}`,
  );

  check(
    "the roster row goes with them",
    !db.has(`conversations/cg-keep/participants/${UID}`),
  );
  check(
    "another member's roster row is untouched",
    db.has(`conversations/cg-keep/participants/${OTHER}`),
  );
  check(
    "the group and its conversation keep running for everyone else",
    db.has("chat_groups/g-keep") && db.has("conversations/cg-keep"),
  );
}

/**
 * `createdBy` is not membership, so `stageMemberRemoval` does not touch it — and
 * a group the erased user created can outlive them by years. Left alone it is a
 * raw uid on a document other people keep reading, which Art. 17 does not permit
 * and which no field-keyed probe would ever flag once the membership is gone.
 * Same re-homing `deleteFamilyData` already does for households.
 *
 * Three groups, because the rule has three outcomes and a single fixture would
 * pass under two different implementations: prefer a surviving ADMIN (not merely
 * the first survivor), fall back to any survivor when no admin survives, and
 * leave someone else's `createdBy` alone.
 */
async function scenario_createdByIsReHomedWhenTheCreatorIsErased(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  // OTHER sorts first among the survivors but is NOT an admin, so "first
  // survivor" and "surviving admin" give different answers here. That is the
  // discriminator: with a fixture where they agree, the preference is unpinned.
  seedChatGroup(db, "g-admin", "cg-admin", {
    members: [UID, OTHER, THIRD],
    admins: [UID, THIRD],
    createdBy: UID,
  });
  seedChatGroup(db, "g-no-admin", "cg-no-admin", {
    members: [UID, OTHER],
    admins: [UID],
    createdBy: UID,
  });
  seedChatGroup(db, "g-not-mine", "cg-not-mine", {
    members: [UID, OTHER],
    admins: [OTHER],
    createdBy: OTHER,
  });

  await deleteChatGroupMemberships(asDb(db), UID);

  check(
    "createdBy is re-homed to a surviving ADMIN, not merely the first survivor",
    (db.get("chat_groups/g-admin") as DocData)?.createdBy === THIRD,
    `createdBy: ${String((db.get("chat_groups/g-admin") as DocData)?.createdBy)}`,
  );
  check(
    "…falling back to any survivor when no admin survives",
    (db.get("chat_groups/g-no-admin") as DocData)?.createdBy === OTHER,
    `createdBy: ${String((db.get("chat_groups/g-no-admin") as DocData)?.createdBy)}`,
  );
  check(
    "…and someone else's createdBy is left alone",
    (db.get("chat_groups/g-not-mine") as DocData)?.createdBy === OTHER,
    `createdBy: ${String((db.get("chat_groups/g-not-mine") as DocData)?.createdBy)}`,
  );
}

/**
 * The erased user was the LAST member: the group has nobody left, so it goes —
 * and the order is the test, not the end state.
 *
 * Deleting the conversation is the write that makes `parentDoc() == null` true in
 * firestore.rules. With the bootstrap branch gone that no longer re-opens a write
 * path, but the rows would still be orphaned under a parent nobody can produce,
 * carrying names and avatars, which is exactly the residual BUT-1825 exists for.
 * So: roster FIRST, then the thread, then the conversation, then the group.
 *
 * The stale `ghost` row is what makes the ordering observable at all — the erased
 * user's own row goes inside the removal transaction, so a fixture with only that
 * row would leave `tryClearRoster` nothing to delete and nothing to order against.
 * It is also the realistic shape: a row whose owner left without it being cleared.
 */
async function scenario_emptiedChatGroupIsTakenDownRosterFirst(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  seedChatGroup(db, "g-solo", "cg-solo", {
    members: [UID],
    admins: [UID],
    createdBy: UID,
  });
  seedRosterRow(db, "cg-solo", "ghost-uid", "Spöke");
  seedMessage(db, "gm1", "cg-solo", UID);
  seedMessage(db, "gm2", "cg-solo", OTHER);

  const ok = await deleteChatGroupMemberships(asDb(db), UID);
  check("an emptied group reports the step complete", ok === true, `returned ${ok}`);

  check("the group document is deleted", !db.has("chat_groups/g-solo"));
  check("the conversation is deleted", !db.has("conversations/cg-solo"));
  check(
    "the whole thread goes with it, both directions",
    db.idsIn("messages").length === 0,
    `left: ${JSON.stringify(db.idsIn("messages"))}`,
  );
  check(
    "no roster row outlives the parent",
    db.pathsUnder("conversations/cg-solo/participants").length === 0,
    `left: ${JSON.stringify(db.pathsUnder("conversations/cg-solo/participants"))}`,
  );

  const at = (path: string) => db.deletedPaths.indexOf(path);
  const rosterAt = at("conversations/cg-solo/participants/ghost-uid");
  const threadAt = at("messages/gm1");
  const convoAt = at("conversations/cg-solo");
  const groupAt = at("chat_groups/g-solo");
  check(
    "order: roster, then thread, then conversation, then group",
    rosterAt >= 0 &&
      threadAt >= 0 &&
      convoAt >= 0 &&
      groupAt >= 0 &&
      rosterAt < threadAt &&
      threadAt < convoAt &&
      convoAt < groupAt,
    `delete order: ${JSON.stringify(db.deletedPaths)}`,
  );
}

/**
 * The gate. When the roster cannot be proven clear the parent must NOT be
 * deleted — an empty group whose documents linger is untidy, whereas an
 * unreachable set of rows carrying people's names is a disclosure — and the step
 * must report INCOMPLETE rather than certifying an erasure it did not finish.
 *
 * Staged SYNTHETICALLY, via the clearer's refusal cap, which is the cheapest way
 * to force a false verdict. Production reaches it through a transient roster read
 * or delete failure; nothing writes 501 rows to a group conversation.
 */
async function scenario_unclearableRosterLeavesTheChatGroupStanding(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  seedChatGroup(db, "g-shell", "cg-shell", {
    members: [UID],
    admins: [UID],
    createdBy: UID,
  });
  // 500 is MAX_ROSTER_ROWS and the read is `.limit(MAX + 1)`, so 501 rows is the
  // smallest roster the clearer refuses. All 501 are seeded ON TOP of the erased
  // user's own row, because that one is deleted inside the removal transaction
  // BEFORE the clearer ever reads — counting it (as the 1:1 fixture above can)
  // leaves 500 and the clearer succeeds, which is how the first version of this
  // fixture passed while proving nothing.
  for (let i = 0; i < 501; i++) {
    seedRosterRow(db, "cg-shell", `seeded-${i}`, `Seeded ${i}`);
  }

  const ok = await deleteChatGroupMemberships(asDb(db), UID);

  check(
    "an unclearable roster leaves the group standing",
    db.has("chat_groups/g-shell"),
  );
  check(
    "…and its conversation standing",
    db.has("conversations/cg-shell"),
  );
  check(
    "…and the step reports INCOMPLETE, so the audit cannot say gdprCompliant",
    ok === false,
    `deleteChatGroupMemberships returned ${ok}`,
  );
  check(
    "…while the membership cut still landed",
    Array.isArray((db.get("chat_groups/g-shell") as DocData)?.memberIds) &&
      ((db.get("chat_groups/g-shell") as DocData).memberIds as string[]).length === 0,
    `memberIds: ${JSON.stringify((db.get("chat_groups/g-shell") as DocData)?.memberIds)}`,
  );
  check(
    "…and the refusal deleted NOTHING — a partial clear is the worst outcome",
    db.has("conversations/cg-shell/participants/seeded-0"),
  );
}

/**
 * Above the cap the sweep DECLINES rather than truncating. A truncated pass that
 * reported success would certify an erasure it did not perform; declining is
 * loud, because the probe leg beside it is an uncapped `count()`.
 */
async function scenario_implausibleChatGroupCountDeclines(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const {
    deleteChatGroupMemberships,
    MAX_CHAT_GROUPS_PER_USER,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  for (let i = 0; i <= MAX_CHAT_GROUPS_PER_USER; i++) {
    db.set(`chat_groups/g-${i}`, {
      memberIds: [UID, OTHER],
      adminIds: [OTHER],
      conversationId: `cg-${i}`,
      createdBy: OTHER,
    });
  }

  const ok = await deleteChatGroupMemberships(asDb(db), UID);

  check(
    "an implausible chat-group count declines the sweep",
    ok === false,
    `returned ${ok}`,
  );
  check(
    "…without truncating: not one group is touched",
    db.deletedPaths.length === 0 &&
      ((db.get("chat_groups/g-0") as DocData).memberIds as string[]).includes(UID),
    `deleted: ${JSON.stringify(db.deletedPaths)}`,
  );
}

/**
 * BUT-1856: the departure tombstone is a raw uid the membership sweep cannot
 * reach.
 *
 * `departedUserIds` records who left a chat group so the meal-vote category sync
 * will not seat them again. The sweep above finds groups by `memberIds
 * array-contains`, and a tombstoned uid is by definition NOT in `memberIds` — so
 * without its own leg a deleted account's uid stays on every group it ever left.
 *
 * Non-vacuous by construction: the fixture's ONLY trace of the erased user is
 * the tombstone. They are in no `memberIds` anywhere, so the first leg visits
 * nothing and every assertion here is answered by the second leg alone.
 */
async function scenario_departureTombstoneIsErased(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("chat_groups/g-left", {
    memberIds: [OTHER],
    adminIds: [OTHER],
    departedUserIds: [UID, "someone-else"],
    conversationId: "cg-left",
    createdBy: OTHER,
  });
  db.set("chat_groups/g-untouched", {
    memberIds: [OTHER],
    adminIds: [OTHER],
    departedUserIds: ["someone-else"],
    conversationId: "cg-untouched",
    createdBy: OTHER,
  });

  const ok = await deleteChatGroupMemberships(asDb(db), UID);

  const after = (db.get("chat_groups/g-left") as DocData)
    .departedUserIds as string[];
  check(
    "the erased uid is gone from departedUserIds",
    !after.includes(UID),
    `departedUserIds: ${JSON.stringify(after)}`,
  );
  check(
    "…and the other tombstones survive — this is an erasure, not a reset",
    after.includes("someone-else"),
    `departedUserIds: ${JSON.stringify(after)}`,
  );
  check("…and the step reports COMPLETE", ok === true, `returned ${ok}`);
  check(
    "…and a group that never knew this user is not rewritten",
    !db.updatedPaths.includes("chat_groups/g-untouched"),
    `updated: ${JSON.stringify(db.updatedPaths)}`,
  );
}

/**
 * BUT-1856: the residual legs answer different queries from the membership
 * sweep, so that sweep's own cap must not take them down with it.
 *
 * Staged by seeding past `MAX_CHAT_GROUPS_PER_USER` groups the user is a MEMBER
 * of — which makes the membership sweep decline — while one further group holds
 * only a tombstone. With the legs below the decline, the tombstone survived for
 * a reason that had nothing to do with tombstones.
 */
async function scenario_residualLegsSurviveTheMembershipDecline(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const {
    deleteChatGroupMemberships,
    MAX_CHAT_GROUPS_PER_USER,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  for (let i = 0; i <= MAX_CHAT_GROUPS_PER_USER; i++) {
    db.set(`chat_groups/g-${i}`, {
      memberIds: [UID, OTHER],
      adminIds: [OTHER],
      conversationId: `cg-${i}`,
      createdBy: OTHER,
    });
  }
  db.set("chat_groups/g-tomb", {
    memberIds: [OTHER],
    adminIds: [OTHER],
    departedUserIds: [UID],
    conversationId: "cg-tomb",
    createdBy: OTHER,
  });

  const ok = await deleteChatGroupMemberships(asDb(db), UID);

  const tomb = (db.get("chat_groups/g-tomb") as DocData)
    .departedUserIds as string[];
  check(
    "the tombstone is erased even though the membership sweep declined",
    !tomb.includes(UID),
    `departedUserIds: ${JSON.stringify(tomb)}`,
  );
  check(
    "…and the declining sweep still reports INCOMPLETE",
    ok === false,
    `returned ${ok}`,
  );
}

/**
 * BUT-1856: the meal-vote pointer names the social group's OWNER, on a chat that
 * outlives them.
 *
 * The chat is only torn down when nobody is left, so an owner who deletes their
 * account normally leaves `sourceCategoryOwnerId` — a raw uid — on a document the
 * surviving members keep reading. The same residual class `createdBy` is
 * re-homed for, and the membership sweep cannot reach it: the fixture's owner is
 * NOT in `memberIds`, because leaving the chat does not stop you owning the
 * social group.
 */
async function scenario_mealVotePointerOwnerIsErased(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { deleteChatGroupMemberships } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("chat_groups/g-cat", {
    memberIds: [OTHER],
    adminIds: [OTHER],
    conversationId: "cg-cat",
    createdBy: OTHER,
    sourceCategoryId: "cat-1",
    sourceCategoryOwnerId: UID,
  });

  const ok = await deleteChatGroupMemberships(asDb(db), UID);

  const after = db.get("chat_groups/g-cat") as DocData;
  check(
    "the owner uid is gone from the meal-vote pointer",
    after.sourceCategoryOwnerId === undefined,
    `sourceCategoryOwnerId: ${JSON.stringify(after.sourceCategoryOwnerId)}`,
  );
  check(
    "…and the dangling category id goes with it, not on its own",
    after.sourceCategoryId === undefined,
    `sourceCategoryId: ${JSON.stringify(after.sourceCategoryId)}`,
  );
  check(
    "…while the chat itself is left standing for its remaining members",
    db.has("chat_groups/g-cat"),
    "group kept",
  );
  check("…and the step reports COMPLETE", ok === true, `returned ${ok}`);
}

/**
 * THE EXCLUSION. A conversation carrying a `groupId` is owned entirely by
 * `deleteChatGroupMemberships`, which removes the uid from the group AND the
 * conversation in one transaction. `deleteMessages` must not touch it: doing so
 * would make it a second writer of membership — the drift this repo has been
 * burned by more than once — and, because the two legs run in parallel, a race
 * that strips the conversation while `chat_groups.memberIds` still names the
 * erased user.
 *
 * Non-vacuous by construction: the fixture is a THREE-participant conversation
 * with the uid in every carrier, so without the early return it takes the
 * group-departure branch and every assertion below flips. Mutation-proven
 * 2026-08-14 — deleting the `groupId` early return reddens exactly the two
 * conversation-document checks here and nothing else.
 *
 * What deleteMessages still legitimately does to a group conversation: it
 * tombstones the user's own MESSAGE rows (their content is theirs wherever it
 * was written), and `deleteOwnRosterRows` sweeps their roster row as a backstop.
 * Both are idempotent with the group leg, and neither writes membership.
 */
async function scenario_deleteMessagesSkipsGroupOwnedConversations(): Promise<void> {
  const db = new FakeFirestore();
  seedChatGroup(db, "g-owned", "cg-owned", {
    members: [UID, OTHER, THIRD],
    admins: [OTHER],
    createdBy: OTHER,
  });
  seedMessage(db, "own", "cg-owned", UID);

  await deleteMessages(asDb(db), UID);

  const convo = (db.get("conversations/cg-owned") ?? {}) as DocData;
  check(
    "a group-owned conversation keeps its participantIds untouched by deleteMessages",
    Array.isArray(convo.participantIds) &&
      (convo.participantIds as string[]).includes(UID),
    `participantIds: ${JSON.stringify(convo.participantIds)}`,
  );
  const untouched = CONVERSATION_UID_MAPS.every(
    (map) => (convo[map] as DocData)?.[UID] !== undefined,
  );
  check(
    "…and all five uid-keyed maps: the group leg owns this document",
    untouched,
    `maps: ${JSON.stringify(CONVERSATION_UID_MAPS.map((m) => (convo[m] as DocData)?.[UID]))}`,
  );
  check(
    "the group document is not touched by deleteMessages either",
    ((db.get("chat_groups/g-owned") as DocData).memberIds as string[]).includes(UID),
  );
  // The two things it DOES do, asserted so "skips" is not read as "ignores".
  check(
    "the user's own message in that thread is still tombstoned",
    (db.get("messages/own") as DocData)?.content === "[Borttaget meddelande]",
    `content: ${String((db.get("messages/own") as DocData)?.content)}`,
  );
}

/**
 * The probe leg that ships with the deleter. Every other leg in
 * `probeResidualData` has one, and a deleter without a probe is exactly how an
 * erasure becomes silently incomplete — so the pairing is asserted, not assumed.
 */
async function scenario_probeSeesLeftoverChatGroupMembership(): Promise<void> {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const dirty = new FakeFirestore();
  dirty.set("chat_groups/g-left", {
    memberIds: [UID, OTHER],
    conversationId: "cg-left",
    createdBy: OTHER,
  });
  const result = {
    deletedCollections: [],
    failedCollections: [] as string[],
    errors: [],
    retained: [],
  };
  await probeResidualData(asDb(dirty), UID, result);
  check(
    "a leftover chat-group membership is reported as residual data",
    result.failedCollections.includes("residual_data_detected"),
    `failed: ${JSON.stringify(result.failedCollections)}`,
  );
}

async function main(): Promise<void> {
  await scenario_ownRosterRowIsErasedInSurvivingGroup();
  await scenario_rosterIsClearedBeforeTheParentDelete();
  await scenario_unclearableRosterLeavesTheParentStanding();
  await scenario_probeSeesLeftoverRosterRows();
  await scenario_chatGroupMembershipIsErasedEverywhere();
  await scenario_createdByIsReHomedWhenTheCreatorIsErased();
  await scenario_emptiedChatGroupIsTakenDownRosterFirst();
  await scenario_unclearableRosterLeavesTheChatGroupStanding();
  await scenario_implausibleChatGroupCountDeclines();
  await scenario_departureTombstoneIsErased();
  await scenario_mealVotePointerOwnerIsErased();
  await scenario_residualLegsSurviveTheMembershipDecline();
  await scenario_deleteMessagesSkipsGroupOwnedConversations();
  await scenario_probeSeesLeftoverChatGroupMembership();

  finishSuite("BUT-1766/BUT-1768 deletion cascade chat groups and rosters");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
