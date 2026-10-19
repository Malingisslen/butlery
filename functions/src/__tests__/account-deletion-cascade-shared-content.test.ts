/**
 * BUT-1766 / BUT-1768: deletion cascade shared content scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-shared-content.test.ts
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
  emptyResult,
  finishSuite,
  sawResidual,
} from "./_account-deletion-cascade-test-seeds";

/**
 * BUT-1798. `removeFromSharedContent` discovered membership ONLY through a
 * `members/{uid}` subcollection doc, which is written by
 * `BaseSharedContentRepository.addMember()` and by nothing else. The three
 * direct-share managers (recipe_sharing_manager, social_menu_operations,
 * shopping_social_share_module) write the parent document only — so every
 * recipient of an ad-hoc shared recipe, menu or list has been un-erasable for
 * this collection's entire life, on documents the Art. 15 export has just
 * started returning.
 *
 * The further trap this pins: the owner is always in their own membership
 * array, so scrubbing without excluding owned docs would update every document
 * the very next step hard-deletes — wasted writes, and a NOT_FOUND poison-pill
 * on retry.
 *
 * Membership was briefly stored under two spellings, and this scenario used to
 * prove both were cleared. Retired 2026-08-03: with only test data there was
 * nothing for the second field to protect, and two copies of one fact could
 * only drift.
 */
async function scenario_adHocSharedContentMembershipIsScrubbed(): Promise<void> {
  const db = new FakeFirestore();

  // A share the deleted user received, alongside a third party who must survive.
  db.set("shared_content/three-way-recipe", {
    contentType: "recipe",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, UID, THIRD],
  });
  // A plain two-person share.
  db.set("shared_content/current-recipe", {
    contentType: "recipe",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, UID],
  });
  // Owned by the deleted user AND listing them as a recipient — the normal
  // shape, since the writer puts the sharer in their own arrays.
  db.set("shared_content/owned-by-deleted", {
    contentType: "recipe",
    sharedByUserId: UID,
    sharedToUserIds: [UID, OTHER],
  });
  // Someone else's share, no relation to the deleted user.
  db.set("shared_content/unrelated", {
    contentType: "menu",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, THIRD],
  });

  const { removeFromSharedContent } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  await removeFromSharedContent(asDb(db), UID);

  const threeWay = db.get("shared_content/three-way-recipe") as DocData;
  check(
    "an ad-hoc share the deleted user RECEIVED is reached at all",
    !(threeWay.sharedToUserIds as string[]).includes(UID),
    `left: ${JSON.stringify(threeWay.sharedToUserIds)}`,
  );
  check(
    "the other two members of that share are untouched",
    (threeWay.sharedToUserIds as string[]).length === 2,
    `left: ${JSON.stringify(threeWay.sharedToUserIds)}`,
  );

  const current = db.get("shared_content/current-recipe") as DocData;
  check(
    "the membership field is cleared on a plain two-person share",
    !(current.sharedToUserIds as string[]).includes(UID),
    `to: ${JSON.stringify(current.sharedToUserIds)}`,
  );

  check(
    "content OWNED by the deleted user is deleted outright",
    !db.has("shared_content/owned-by-deleted"),
    `still present: ${JSON.stringify(db.get("shared_content/owned-by-deleted"))}`,
  );
  // The check above passes even without the owner-skip, because the delete runs
  // last either way. THIS is the one that pins the skip: a real batch.update on
  // a doc that is about to be deleted throws NOT_FOUND and takes the whole
  // chunk down on retry, so the owned doc must never be written at all.
  check(
    "…and is never written on the way there (the NOT_FOUND poison-pill)",
    !db.updatedPaths.includes("shared_content/owned-by-deleted"),
    `wrote: ${JSON.stringify(db.updatedPaths)}`,
  );

  const unrelated = db.get("shared_content/unrelated") as DocData;
  check(
    "an unrelated share between two other people is left alone",
    (unrelated.sharedToUserIds as string[]).length === 2,
    `to: ${JSON.stringify(unrelated.sharedToUserIds)}`,
  );
}

/**
 * BUT-1716. The membership scrub above rewrites the PARENT document. One level
 * down, `shared_content/{id}/items/{itemId}` carried the same person's uid and
 * display name on every row they added, ticked or claimed — and Firestore does
 * not delete a subcollection with its parent, so on an OWNED share those rows
 * outlived the share document itself, unreachable by any client and erasable by
 * nothing but this cascade.
 *
 * The four pairs are treated as the array-shaped twin treats them
 * (`deleteShoppingLists`): `assignedTo*` and `purchasedBy*` cleared to null with
 * their timestamp, `addedBy*` and `lastModifiedBy*` anonymized to `"deleted"`
 * because the client model reads `isCollaborative => addedByUserId != null`.
 * The two shapes must answer the same erasure question the same way, and no
 * assertion in either suite can see them drift — so this scenario mirrors that
 * one field for field.
 */
async function scenario_sharedContentItemAttributionIsScrubbed(): Promise<void> {
  const db = new FakeFirestore();

  // A list somebody else keeps, which the deleted user contributed to.
  db.set("shared_content/their-list", {
    contentType: "shopping_list",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, UID],
  });
  db.set("shared_content/their-list/items/i-added", {
    name: "Mjölk",
    addedByUserId: UID,
    addedByDisplayName: "Raderad Person",
    lastModifiedByUserId: UID,
    lastModifiedByDisplayName: "Raderad Person",
  });
  db.set("shared_content/their-list/items/i-claimed-and-ticked", {
    name: "Ägg",
    addedByUserId: OTHER,
    addedByDisplayName: "Någon Annan",
    assignedToUserId: UID,
    assignedToDisplayName: "Raderad Person",
    assignedAt: "2026-09-01T10:00:00Z",
    purchasedByUserId: UID,
    purchasedByDisplayName: "Raderad Person",
    purchasedAt: "2026-09-01T11:00:00Z",
  });
  db.set("shared_content/their-list/items/somebody-elses", {
    name: "Smör",
    addedByUserId: OTHER,
    addedByDisplayName: "Någon Annan",
  });

  // A share the deleted user OWNS, whose items go with it.
  db.set("shared_content/my-list", {
    contentType: "shopping_list",
    sharedByUserId: UID,
    sharedToUserIds: [UID, OTHER],
  });
  db.set("shared_content/my-list/items/row", {
    name: "Bröd",
    addedByUserId: UID,
  });
  db.set("shared_content/my-list/members/" + OTHER, { userId: OTHER });

  // A shared RECIPE the deleted user received: no items collection at all.
  db.set("shared_content/their-recipe", {
    contentType: "recipe",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, UID],
  });

  // A list the deleted user LEFT. `BaseSharedContentRepository.removeMember`
  // deletes the `members/{uid}` row and arrayRemoves the uid from
  // `sharedToUserIds` in one call, so neither membership handle names them —
  // while their uid and display name stay on every row they wrote. This is the
  // residual the leg exists for, and discovering parents through membership
  // (the first version of this change) walks straight past it.
  db.set("shared_content/left-list", {
    contentType: "shopping_list",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, THIRD],
  });
  db.set("shared_content/left-list/items/written-before-leaving", {
    name: "Kanel",
    addedByUserId: UID,
    addedByDisplayName: "Raderad Person",
  });

  // A `members` row for this user under a DIFFERENT collection. `members` is
  // read as a collection GROUP, so this row comes back too — and resolving its
  // parent would take the scrub somewhere it has no business being.
  db.set("chat_groups/g1/members/" + UID, { userId: UID });
  db.set("chat_groups/g1/items/not-a-shopping-row", {
    name: "should not be touched",
    addedByUserId: UID,
  });

  const { removeFromSharedContent } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  await removeFromSharedContent(asDb(db), UID);

  const added = db.get(
    "shared_content/their-list/items/i-added",
  ) as DocData;
  check(
    "an item the deleted user ADDED keeps the row but loses the person",
    added.addedByUserId === "deleted" &&
      added.addedByDisplayName === null &&
      added.lastModifiedByUserId === "deleted" &&
      added.lastModifiedByDisplayName === null,
    `left: ${JSON.stringify(added)}`,
  );
  check(
    "…and the row itself survives, with its name",
    added.name === "Mjölk",
    `left: ${JSON.stringify(added)}`,
  );

  const claimed = db.get(
    "shared_content/their-list/items/i-claimed-and-ticked",
  ) as DocData;
  check(
    "a claim and a tick are NULLED, timestamps included — not anonymized",
    claimed.assignedToUserId === null &&
      claimed.assignedToDisplayName === null &&
      claimed.assignedAt === null &&
      claimed.purchasedByUserId === null &&
      claimed.purchasedByDisplayName === null &&
      claimed.purchasedAt === null,
    `left: ${JSON.stringify(claimed)}`,
  );
  check(
    "…while the other person's authorship on that same row is untouched",
    claimed.addedByUserId === OTHER &&
      claimed.addedByDisplayName === "Någon Annan",
    `left: ${JSON.stringify(claimed)}`,
  );

  check(
    "a row nobody's deletion touches is not written at all",
    !db.updatedPaths.includes(
      "shared_content/their-list/items/somebody-elses",
    ),
    `wrote: ${JSON.stringify(db.updatedPaths)}`,
  );

  // The scrub skips parents this user owns, because the loop below deletes
  // those rows: writing one on its way out is wasted, and the skip is keyed on
  // the parent's document id.
  check(
    "a row under an OWNED share is never scrubbed on its way to deletion",
    !db.updatedPaths.includes("shared_content/my-list/items/row"),
    `wrote: ${JSON.stringify(db.updatedPaths)}`,
  );
  check(
    "items under an OWNED share are deleted with it",
    !db.has("shared_content/my-list/items/row"),
    `still present: ${JSON.stringify(db.get("shared_content/my-list/items/row"))}`,
  );
  // "Both are gone" cannot tell the fixed code from code that deletes the
  // parent first and orphans the rows. Only the ORDER can.
  const itemAt = db.deletedPaths.indexOf("shared_content/my-list/items/row");
  const parentAt = db.deletedPaths.indexOf("shared_content/my-list");
  check(
    "…and before the parent, so nothing is orphaned on the way",
    itemAt >= 0 && parentAt >= 0 && itemAt < parentAt,
    `order: ${JSON.stringify(db.deletedPaths)}`,
  );

  const left = db.get(
    "shared_content/left-list/items/written-before-leaving",
  ) as DocData;
  check(
    "a row written by somebody who LEFT the list is still reached",
    left.addedByUserId === "deleted" && left.addedByDisplayName === null,
    `left: ${JSON.stringify(left)}`,
  );

  const foreign = db.get(
    "chat_groups/g1/items/not-a-shopping-row",
  ) as DocData;
  check(
    "an items row under ANOTHER collection is out of scope",
    foreign !== undefined && foreign.addedByUserId === UID,
    `left: ${JSON.stringify(foreign)}`,
  );
  // The membership scrub three lines above the new code reads the SAME
  // collection-group snapshot and was never scoped. Unscoped, it writes an
  // empty `sharedToUserIds` onto a stranger's parent document.
  check(
    "…and the membership scrub does not write that foreign parent either",
    !db.updatedPaths.includes("chat_groups/g1"),
    `wrote: ${JSON.stringify(db.updatedPaths)}`,
  );
}

/**
 * BUT-1716. The two ways this leg can leave a uid on disk while reporting a
 * clean erasure — the failure posture both commit gates called blocking.
 *
 * Neither is reachable through the `updateFailures` seam: `commitInChunks`
 * writes through a BATCH, which never goes through `makeRef`. That is why the
 * fake grew `batchFailures`, and why the guards these two cases hold were
 * unpinned when they were first written.
 */
async function scenario_sharedContentItemScrubReportsItsOwnFailure(): Promise<void> {
  // 1. The scrub's own commit fails. The rows keep the uid, so the STEP must
  //    say so: `runStep` turns false into `failedCollections` and
  //    `gdprCompliant: false`, and nothing else can contradict a clean audit
  //    row — no probe leg reaches these item rows.
  const scrubFails = new FakeFirestore();
  scrubFails.set("shared_content/their-list", {
    contentType: "shopping_list",
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER, UID],
  });
  scrubFails.set("shared_content/their-list/items/mine", {
    name: "Mjölk",
    addedByUserId: UID,
    addedByDisplayName: "Raderad Person",
  });
  scrubFails.batchFailures.set(
    "shared_content/their-list/items/mine",
    13, // INTERNAL
  );

  const { removeFromSharedContent } =
    // eslint-disable-next-line @typescript-eslint/no-require-imports
    require("../account/account-deletion-cascade");
  const scrubResult = await removeFromSharedContent(asDb(scrubFails), UID);

  check(
    "a failed item scrub reports the STEP as incomplete",
    scrubResult === false,
    `returned: ${JSON.stringify(scrubResult)}`,
  );
  const stillThere = scrubFails.get(
    "shared_content/their-list/items/mine",
  ) as DocData;
  check(
    "…and says so because the uid really is still on the row",
    stillThere.addedByUserId === UID,
    `left: ${JSON.stringify(stillThere)}`,
  );

  // 2. An OWNED share whose children cannot be deleted. The parent must STAY.
  const childFails = new FakeFirestore();
  childFails.set("shared_content/my-list", {
    contentType: "shopping_list",
    sharedByUserId: UID,
    sharedToUserIds: [UID, OTHER],
  });
  childFails.set("shared_content/my-list/items/row", {
    name: "Bröd",
    addedByUserId: UID,
  });
  childFails.batchFailures.set("shared_content/my-list/items/row", 13);

  const childResult = await removeFromSharedContent(asDb(childFails), UID);

  check(
    "an owned share whose items could not be deleted KEEPS its parent",
    childFails.has("shared_content/my-list"),
    `deleted: ${JSON.stringify(childFails.deletedPaths)}`,
  );
  check(
    "…so the surviving rows are still reachable through it",
    childFails.has("shared_content/my-list/items/row"),
    `store: ${JSON.stringify(childFails.deletedPaths)}`,
  );
  check(
    "…and that erasure reports itself incomplete too",
    childResult === false,
    `returned: ${JSON.stringify(childResult)}`,
  );
}

/**
 * BUT-2169: a block holds the erased user off someone else's share. The scrub
 * removes them from the held list and drops the entry that would restore them,
 * and leaves every other held person in place.
 */
async function scenario_blockHeldShareLosesOnlyTheErasedUid(): Promise<void> {
  const { scrubBlockHeldShares } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("shared_content/held", {
    sharedByUserId: OTHER,
    sharedToUserIds: [OTHER],
    blockHeldUserIds: [UID, THIRD],
    blockHeld: {
      [UID]: { member: null, recipePermission: "view", recipeHadGrants: true },
      [THIRD]: { member: null, recipePermission: null, recipeHadGrants: false },
    },
  });
  // A share the erased user made, with someone else held on it: an unblock
  // would rewrite that person's member row naming the erased user as adder.
  db.set("shared_content/mine", {
    sharedByUserId: UID,
    sharedToUserIds: [UID],
    blockHeldUserIds: [THIRD],
    blockHeld: { [THIRD]: { member: { userId: THIRD, addedBy: UID } } },
  });

  const ok = await scrubBlockHeldShares(asDb(db), UID);

  const row = db.get("shared_content/held");
  check("the held-share scrub reports success", ok === true);
  check(
    "the erased uid leaves the held list and the other held person stays",
    JSON.stringify(row?.blockHeldUserIds) === JSON.stringify([THIRD]),
    JSON.stringify(row),
  );
  const held = (row?.blockHeld ?? {}) as Record<string, unknown>;
  check("the entry that would restore them is gone", !(UID in held), JSON.stringify(held));
  check("the other held person's entry stays", THIRD in held, JSON.stringify(held));
  const mine = db.get("shared_content/mine");
  check(
    "a share the erased user made keeps nothing held for a release to restore",
    mine !== undefined && !("blockHeld" in mine) && !("blockHeldUserIds" in mine),
    JSON.stringify(mine),
  );

  const probe = require("../account/account-deletion-cascade").probeResidualData;
  const residue = new FakeFirestore();
  residue.set("shared_content/x", { sharedByUserId: OTHER, blockHeldUserIds: [UID] });
  const r = emptyResult();
  await probe(asDb(residue), UID, r);
  check("a surviving held entry is residual", sawResidual(r));
}

async function main(): Promise<void> {
  await scenario_adHocSharedContentMembershipIsScrubbed();
  await scenario_sharedContentItemAttributionIsScrubbed();
  await scenario_sharedContentItemScrubReportsItsOwnFailure();
  await scenario_blockHeldShareLosesOnlyTheErasedUid();

  finishSuite("BUT-1766/BUT-1768 deletion cascade shared content");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
