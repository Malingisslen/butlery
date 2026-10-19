/**
 * BUT-1766 / BUT-1768: deletion cascade comments and ratings scenarios, split out of
 * `account-deletion-cascade.test.ts` (BUT-2113). Shared fakes and seeds are
 * `_account-deletion-cascade-fake-firestore.ts` and `_account-deletion-cascade-test-seeds.ts`.
 *
 * Run with: npx ts-node src/__tests__/account-deletion-cascade-comments-ratings.test.ts
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
  probeAfter,
  sawResidual,
} from "./_account-deletion-cascade-test-seeds";

/**
 * BUT-2072: a rating on the erased user's recipe loses `recipeOwnerId` and
 * keeps everything else. The rater's row is theirs; only the owner's uid goes.
 */
async function scenario_ratingOwnerStampIsRemoved(): Promise<void> {
  const {
    scrubRatingRecipeOwner,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("recipe_ratings/onMine", {
    userId: OTHER,
    recipeId: "r1",
    recipeOwnerId: UID,
    rating: 4,
    review: "gott",
  });
  db.set("recipe_ratings/onTheirs", {
    userId: OTHER,
    recipeId: "r2",
    recipeOwnerId: THIRD,
    rating: 3,
  });
  db.set("recipe_ratings/legacy", { userId: OTHER, recipeId: "r3", rating: 5 });

  const ok = await scrubRatingRecipeOwner(asDb(db), UID);

  const mine = db.get("recipe_ratings/onMine");
  check("the scrub reports success", ok === true);
  check(
    "the owner stamp is REMOVED, not nulled",
    mine !== undefined && !("recipeOwnerId" in mine),
    JSON.stringify(mine),
  );
  check(
    "the rating, review and rater survive",
    mine?.rating === 4 && mine?.review === "gott" && mine?.userId === OTHER,
    JSON.stringify(mine),
  );
  check(
    "a rating naming another owner is untouched",
    db.get("recipe_ratings/onTheirs")?.recipeOwnerId === THIRD,
  );
  check(
    "a pre-BUT-2057 rating without the field is not written to",
    !db.updatedPaths.includes("recipe_ratings/legacy"),
    JSON.stringify(db.updatedPaths),
  );
}

/**
 * BUT-2072: the user's rating of their OWN
 * recipe matches both `deleteCommentsAndRatings` and the scrub; run in that
 * order, the scrub never stages a write on the row the delete removed — which
 * in real Firestore would reject its whole chunk with NOT_FOUND.
 */
async function scenario_selfRatingIsDeletedNotScrubbed(): Promise<void> {
  const {
    deleteCommentsAndRatings,
    scrubRatingRecipeOwner,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("recipe_ratings/self", {
    userId: UID,
    recipeId: "r1",
    recipeOwnerId: UID,
    rating: 5,
  });

  await deleteCommentsAndRatings(asDb(db), UID);
  const ok = await scrubRatingRecipeOwner(asDb(db), UID);

  check("the self-rating is deleted", !db.has("recipe_ratings/self"));
  check(
    "the scrub staged no write on the deleted row",
    !db.updatedPaths.includes("recipe_ratings/self"),
    JSON.stringify(db.updatedPaths),
  );
  check("the scrub reports success", ok === true);
}

/** BUT-2072: over the cap the scrub declines and writes nothing. */
async function scenario_implausibleRatingOwnerCountDeclines(): Promise<void> {
  const {
    scrubRatingRecipeOwner,
    MAX_RATING_OWNER_SWEEP_ROWS,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  // `<=` seeds exactly one row past the cap the `.limit(MAX + 1)` read can see.
  for (let i = 0; i <= MAX_RATING_OWNER_SWEEP_ROWS; i++) {
    db.set(`recipe_ratings/r-${i}`, {
      userId: `peer-${i}`,
      recipeOwnerId: UID,
      rating: 1,
    });
  }

  const ok = await scrubRatingRecipeOwner(asDb(db), UID);

  check("the step reports itself INCOMPLETE", ok === false);
  check(
    "nothing was written rather than a truncated sweep",
    db.updatedPaths.length === 0,
    `updated: ${db.updatedPaths.length}`,
  );
}

/** BUT-2072: exactly at the cap the scrub still runs. */
async function scenario_ratingOwnerScrubRunsAtTheCap(): Promise<void> {
  const {
    scrubRatingRecipeOwner,
    MAX_RATING_OWNER_SWEEP_ROWS,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  for (let i = 0; i < MAX_RATING_OWNER_SWEEP_ROWS; i++) {
    db.set(`recipe_ratings/r-${i}`, {
      userId: `peer-${i}`,
      recipeOwnerId: UID,
      rating: 1,
    });
  }

  const ok = await scrubRatingRecipeOwner(asDb(db), UID);

  check("a sweep of exactly the cap reports success", ok === true);
  check(
    "no row at the cap still carries the stamp",
    db
      .idsIn("recipe_ratings")
      .every((id) => !("recipeOwnerId" in (db.get(`recipe_ratings/${id}`) ?? {}))) &&
      db.idsIn("recipe_ratings").length === MAX_RATING_OWNER_SWEEP_ROWS,
  );
}

/** BUT-2072: a failed chunk fails the step rather than being swallowed. */
async function scenario_failedRatingOwnerChunkFailsTheStep(): Promise<void> {
  const {
    scrubRatingRecipeOwner,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("recipe_ratings/x", { userId: OTHER, recipeOwnerId: UID, rating: 2 });
  db.batchFailures.set("recipe_ratings/x", 13);

  const ok = await scrubRatingRecipeOwner(asDb(db), UID);

  check("a rejected chunk makes the step report failure", ok === false);
  check(
    "the stamp is still there for the probe to find",
    db.get("recipe_ratings/x")?.recipeOwnerId === UID,
  );
}

/**
 * BUT-2072: the probe sees an owner stamp left behind. The row's `userId` is
 * someone else, so only a leg keyed on `recipeOwnerId` can see it — a
 * `recipe_ratings` entry in the `userId`-filtered `probes` list would not.
 */
async function scenario_probeSeesLeftoverRatingOwnerStamp(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");

  const dirty = new FakeFirestore();
  dirty.set("recipe_ratings/x", { userId: OTHER, recipeOwnerId: UID, rating: 2 });
  const dirtyResult = emptyResult();
  await probeResidualData(asDb(dirty), UID, dirtyResult);
  check(
    "a surviving owner stamp is reported as residual",
    sawResidual(dirtyResult),
    `failed: ${JSON.stringify(dirtyResult.failedCollections)}`,
  );

  const clean = new FakeFirestore();
  clean.set("recipe_ratings/x", { userId: OTHER, recipeOwnerId: THIRD, rating: 2 });
  const cleanResult = emptyResult();
  await probeResidualData(asDb(clean), UID, cleanResult);
  check(
    "a stamp naming someone else does not make the probe fire",
    !sawResidual(cleanResult),
    `failed: ${JSON.stringify(cleanResult.failedCollections)}`,
  );
}

/**
 * BUT-2112: comments on the erased user's recipes lose `recipeOwnerId`, and the
 * comment itself stays.
 */
async function scenario_commentOwnerStampIsRemoved(): Promise<void> {
  const {
    scrubCommentRecipeOwner,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("recipe_comments/onMine", {
    authorId: OTHER,
    recipeOwnerId: UID,
    sharedWithUserIds: [THIRD],
    text: "gott",
  });
  db.set("recipe_comments/onTheirs", {
    authorId: OTHER,
    recipeOwnerId: THIRD,
    sharedWithUserIds: [],
    text: "ok",
  });
  db.set("recipe_comments/legacy", { authorId: OTHER, text: "gammal" });

  const ok = await scrubCommentRecipeOwner(asDb(db), UID);

  const mine = db.get("recipe_comments/onMine");
  check("the comment owner scrub reports success", ok === true);
  check(
    "the owner stamp is REMOVED from the comment, not nulled",
    mine !== undefined && !("recipeOwnerId" in mine),
    JSON.stringify(mine),
  );
  check(
    "the comment text, author and share list survive",
    mine?.text === "gott" &&
      mine?.authorId === OTHER &&
      JSON.stringify(mine?.sharedWithUserIds) === JSON.stringify([THIRD]),
    JSON.stringify(mine),
  );
  check(
    "a comment naming another owner is untouched",
    db.get("recipe_comments/onTheirs")?.recipeOwnerId === THIRD,
  );
  check(
    "a pre-BUT-458 comment without the field is not written to",
    !db.updatedPaths.includes("recipe_comments/legacy"),
    JSON.stringify(db.updatedPaths),
  );
}

/**
 * BUT-2112: the share list loses only the erased uid. The field stays, and so
 * does every other recipient's read access.
 */
async function scenario_commentShareListLosesOnlyTheErasedUid(): Promise<void> {
  const {
    scrubCommentSharedWith,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("recipe_comments/shared", {
    authorId: OTHER,
    recipeOwnerId: OTHER,
    sharedWithUserIds: [UID, THIRD],
    text: "x",
  });
  db.set("recipe_comments/soloShare", {
    authorId: OTHER,
    sharedWithUserIds: [UID],
    text: "y",
  });
  db.set("recipe_comments/notShared", {
    authorId: OTHER,
    sharedWithUserIds: [THIRD],
    text: "z",
  });

  const ok = await scrubCommentSharedWith(asDb(db), UID);

  check("the share-list scrub reports success", ok === true);
  check(
    "the erased uid leaves the list and the other recipient stays",
    JSON.stringify(db.get("recipe_comments/shared")?.sharedWithUserIds) ===
      JSON.stringify([THIRD]),
    JSON.stringify(db.get("recipe_comments/shared")),
  );
  const solo = db.get("recipe_comments/soloShare");
  check(
    "a list holding only the erased uid is left EMPTY, not removed",
    solo !== undefined &&
      Array.isArray(solo.sharedWithUserIds) &&
      (solo.sharedWithUserIds as unknown[]).length === 0,
    JSON.stringify(solo),
  );
  check(
    "a comment not shared with the erased uid is not written to",
    !db.updatedPaths.includes("recipe_comments/notShared"),
    JSON.stringify(db.updatedPaths),
  );
}

/**
 * BUT-2112: the erased user's like goes, and its comment's counter drops by
 * one. A like on a comment that is already gone is deleted with no write to
 * the missing parent; a counter already at 0 is not taken below it; a
 * `likes` row that is not under `recipe_comments` is not this sweep's.
 */
async function scenario_commentLikesAreDeleted(): Promise<void> {
  const {
    deleteCommentLikes,
  } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("recipe_comments/c1", { authorId: OTHER, likesCount: 3 });
  db.set(`recipe_comments/c1/likes/${UID}`, { userId: UID });
  db.set(`recipe_comments/c1/likes/${THIRD}`, { userId: THIRD });
  db.set(`recipe_comments/gone/likes/${UID}`, { userId: UID });
  db.set("recipe_comments/c0", { authorId: OTHER, likesCount: 0 });
  db.set(`recipe_comments/c0/likes/${UID}`, { userId: UID });
  db.set(`cook_snaps/s1/likes/${UID}`, { userId: UID });

  const ok = await deleteCommentLikes(asDb(db), UID);

  check("the comment-like sweep reports success", ok === true);
  check(
    "the erased user's like is deleted",
    !db.has(`recipe_comments/c1/likes/${UID}`),
  );
  check(
    "another person's like on the same comment stays",
    db.has(`recipe_comments/c1/likes/${THIRD}`),
  );
  check(
    "the comment's likesCount drops by one",
    db.get("recipe_comments/c1")?.likesCount === 2,
    JSON.stringify(db.get("recipe_comments/c1")),
  );
  check(
    "a like under a deleted comment is deleted",
    !db.has(`recipe_comments/gone/likes/${UID}`),
  );
  check(
    "no write is staged on the missing parent",
    !db.updatedPaths.includes("recipe_comments/gone"),
    JSON.stringify(db.updatedPaths),
  );
  check(
    "a counter already at 0 is not taken below it",
    db.get("recipe_comments/c0")?.likesCount === 0 &&
      !db.updatedPaths.includes("recipe_comments/c0"),
    JSON.stringify(db.get("recipe_comments/c0")),
  );
  check(
    "a likes row outside recipe_comments is not this sweep's",
    db.has(`cook_snaps/s1/likes/${UID}`),
  );
}

/** BUT-2112: over the cap each of the three steps declines and writes nothing. */
async function scenario_implausibleCommentSweepsDecline(): Promise<void> {
  const {
    scrubCommentRecipeOwner,
    scrubCommentSharedWith,
    deleteCommentLikes,
    MAX_COMMENT_OWNER_SWEEP_ROWS,
    MAX_COMMENT_SHARE_SWEEP_ROWS,
    MAX_COMMENT_LIKE_SWEEP_ROWS,
  } = require("../account/account-deletion-cascade");

  const owner = new FakeFirestore();
  for (let i = 0; i <= MAX_COMMENT_OWNER_SWEEP_ROWS; i++) {
    owner.set(`recipe_comments/o-${i}`, { authorId: `p-${i}`, recipeOwnerId: UID });
  }
  const ownerOk = await scrubCommentRecipeOwner(asDb(owner), UID);
  check(
    "the owner scrub declines above its cap and writes nothing",
    ownerOk === false && owner.updatedPaths.length === 0,
  );

  const share = new FakeFirestore();
  for (let i = 0; i <= MAX_COMMENT_SHARE_SWEEP_ROWS; i++) {
    share.set(`recipe_comments/s-${i}`, { authorId: `p-${i}`, sharedWithUserIds: [UID] });
  }
  const shareOk = await scrubCommentSharedWith(asDb(share), UID);
  check(
    "the share-list scrub declines above its cap and writes nothing",
    shareOk === false && share.updatedPaths.length === 0,
  );

  const likes = new FakeFirestore();
  for (let i = 0; i <= MAX_COMMENT_LIKE_SWEEP_ROWS; i++) {
    likes.set(`recipe_comments/l-${i}/likes/${UID}`, { userId: UID });
  }
  const likesOk = await deleteCommentLikes(asDb(likes), UID);
  check(
    "the like sweep declines above its cap and deletes nothing",
    likesOk === false && likes.deletedPaths.length === 0,
  );
}

/** BUT-2112: exactly at the cap each step still runs. */
async function scenario_commentSweepsRunAtTheCap(): Promise<void> {
  const {
    scrubCommentRecipeOwner,
    scrubCommentSharedWith,
    deleteCommentLikes,
    MAX_COMMENT_OWNER_SWEEP_ROWS,
    MAX_COMMENT_SHARE_SWEEP_ROWS,
    MAX_COMMENT_LIKE_SWEEP_ROWS,
  } = require("../account/account-deletion-cascade");

  const owner = new FakeFirestore();
  for (let i = 0; i < MAX_COMMENT_OWNER_SWEEP_ROWS; i++) {
    owner.set(`recipe_comments/o-${i}`, { authorId: `p-${i}`, recipeOwnerId: UID });
  }
  check(
    "the owner scrub runs at exactly its cap",
    (await scrubCommentRecipeOwner(asDb(owner), UID)) === true &&
      owner.updatedPaths.length === MAX_COMMENT_OWNER_SWEEP_ROWS,
  );

  const share = new FakeFirestore();
  for (let i = 0; i < MAX_COMMENT_SHARE_SWEEP_ROWS; i++) {
    share.set(`recipe_comments/s-${i}`, { authorId: `p-${i}`, sharedWithUserIds: [UID] });
  }
  check(
    "the share-list scrub runs at exactly its cap",
    (await scrubCommentSharedWith(asDb(share), UID)) === true &&
      share.updatedPaths.length === MAX_COMMENT_SHARE_SWEEP_ROWS,
  );

  const likes = new FakeFirestore();
  // Parents with distinct counts across more than one read group of the
  // decrement pass, so a row mapped to the wrong parent shows.
  for (let i = 0; i < MAX_COMMENT_LIKE_SWEEP_ROWS; i++) {
    likes.set(`recipe_comments/l-${i}`, { authorId: OTHER, likesCount: i + 1 });
    likes.set(`recipe_comments/l-${i}/likes/${UID}`, { userId: UID });
  }
  check(
    "the like sweep runs at exactly its cap",
    (await deleteCommentLikes(asDb(likes), UID)) === true &&
      likes.deletedPaths.length === MAX_COMMENT_LIKE_SWEEP_ROWS,
  );
  const wrong: string[] = [];
  for (let i = 0; i < MAX_COMMENT_LIKE_SWEEP_ROWS; i++) {
    if (likes.get(`recipe_comments/l-${i}`)?.likesCount !== i) wrong.push(`l-${i}`);
  }
  check(
    "every parent loses exactly its own like",
    wrong.length === 0,
    `wrong: ${wrong.slice(0, 5).join(", ")} (${wrong.length})`,
  );
}

/**
 * BUT-2112: failure posture. A rejected chunk fails the two scrubs and the
 * like deletes; the decrement pass is logged and does not fail the step,
 * because the like rows are already gone.
 */
async function scenario_commentSweepFailures(): Promise<void> {
  const {
    scrubCommentRecipeOwner,
    scrubCommentSharedWith,
    deleteCommentLikes,
  } = require("../account/account-deletion-cascade");

  const owner = new FakeFirestore();
  owner.set("recipe_comments/x", { authorId: OTHER, recipeOwnerId: UID });
  owner.batchFailures.set("recipe_comments/x", 13);
  check(
    "a rejected owner-scrub chunk fails the step",
    (await scrubCommentRecipeOwner(asDb(owner), UID)) === false,
  );

  const share = new FakeFirestore();
  share.set("recipe_comments/x", { authorId: OTHER, sharedWithUserIds: [UID] });
  share.batchFailures.set("recipe_comments/x", 13);
  check(
    "a rejected share-list chunk fails the step",
    (await scrubCommentSharedWith(asDb(share), UID)) === false,
  );

  const deleteFails = new FakeFirestore();
  deleteFails.set("recipe_comments/c", { authorId: OTHER, likesCount: 1 });
  deleteFails.set(`recipe_comments/c/likes/${UID}`, { userId: UID });
  deleteFails.batchFailures.set(`recipe_comments/c/likes/${UID}`, 13);
  check(
    "a rejected like-delete chunk fails the step",
    (await deleteCommentLikes(asDb(deleteFails), UID)) === false,
  );
  check(
    "…and the counter is not decremented for a like still standing",
    deleteFails.get("recipe_comments/c")?.likesCount === 1,
  );

  const decrementFails = new FakeFirestore();
  decrementFails.set("recipe_comments/c", { authorId: OTHER, likesCount: 1 });
  decrementFails.set(`recipe_comments/c/likes/${UID}`, { userId: UID });
  decrementFails.batchFailures.set("recipe_comments/c", 13);
  check(
    "a rejected decrement chunk does NOT fail the step",
    (await deleteCommentLikes(asDb(decrementFails), UID)) === true,
  );
  check(
    "…because the like row itself is gone",
    !decrementFails.has(`recipe_comments/c/likes/${UID}`),
  );
}

/**
 * Stages a row deleted between the scrub's query and its commit: the first
 * batch that updates `path` deletes it and rejects with NOT_FOUND, applying
 * nothing, as a real atomic batch does. Every later batch that updates a
 * missing row is rejected the same way, so retrying the stale snapshot fails
 * where re-reading succeeds. Returns the commit attempts.
 */
function deleteDuringFirstCommit(store: FakeFirestore, path: string): {
  commits: number;
} {
  const seen = { commits: 0 };
  let raced = false;
  const db = store as unknown as Record<string, unknown>;
  const realBatch = db.batch as () => Record<string, unknown>;
  db.batch = () => {
    const b = realBatch.call(store);
    const refs: { path: string; delete: () => Promise<void> }[] = [];
    const paths: string[] = [];
    const realUpdate = b.update as (
      ref: { path: string; delete: () => Promise<void> },
      ...rest: unknown[]
    ) => void;
    b.update = (
      ref: { path: string; delete: () => Promise<void> },
      ...rest: unknown[]
    ) => {
      refs.push(ref);
      paths.push(ref.path);
      realUpdate.call(b, ref, ...rest);
    };
    const realCommit = b.commit as () => Promise<void>;
    b.commit = async () => {
      seen.commits++;
      const target = raced ? undefined : refs.find((r) => r.path === path);
      if (target !== undefined) {
        raced = true;
        await target.delete();
        throw Object.assign(new Error(`no document to update: ${path}`), {
          code: 5,
        });
      }
      const missing = paths.find((p) => !store.has(p));
      if (missing !== undefined) {
        throw Object.assign(new Error(`no document to update: ${missing}`), {
          code: 5,
        });
      }
      return realCommit.call(b);
    };
    return b;
  };
  return seen;
}

/**
 * BUT-2338: a comment or rating deleted mid-scrub (its recipe deleted by
 * `onRecipeDeleted`, or its author deleting it) costs one re-read, not the
 * step: the second query no longer returns it and the rest are scrubbed.
 */
async function scenario_scrubsSurviveARowDeletedMidCommit(): Promise<void> {
  const {
    scrubCommentSharedWith,
    scrubCommentReactions,
    scrubRatingRecipeOwner,
  } = require("../account/account-deletion-cascade");

  const share = new FakeFirestore();
  share.set("recipe_comments/gone", { authorId: OTHER, sharedWithUserIds: [UID] });
  share.set("recipe_comments/kept", {
    authorId: OTHER,
    sharedWithUserIds: [UID, THIRD],
  });
  const shareRace = deleteDuringFirstCommit(share, "recipe_comments/gone");
  check(
    "a comment deleted mid-scrub does not fail the share-list scrub",
    (await scrubCommentSharedWith(asDb(share), UID)) === true,
  );
  check(
    "…the other comment is scrubbed on the second pass",
    JSON.stringify(share.get("recipe_comments/kept")?.sharedWithUserIds) ===
      JSON.stringify([THIRD]),
    JSON.stringify(share.get("recipe_comments/kept")),
  );
  check(
    "…after exactly one retry",
    shareRace.commits === 2,
    `commits: ${shareRace.commits}`,
  );

  const reactions = new FakeFirestore();
  reactions.set("recipe_comments/gone", {
    authorId: OTHER,
    reactions: { heart: [UID] },
  });
  reactions.set("recipe_comments/kept", {
    authorId: OTHER,
    reactions: { heart: [UID, THIRD] },
  });
  deleteDuringFirstCommit(reactions, "recipe_comments/gone");
  check(
    "a comment deleted mid-scrub does not fail the reactions scrub",
    (await scrubCommentReactions(asDb(reactions), UID)) === true,
  );
  check(
    "…the other comment loses the erased uid's reaction",
    JSON.stringify(
      (reactions.get("recipe_comments/kept")?.reactions as DocData)?.heart,
    ) === JSON.stringify([THIRD]),
    JSON.stringify(reactions.get("recipe_comments/kept")),
  );

  const rating = new FakeFirestore();
  rating.set("recipe_ratings/gone", { userId: OTHER, recipeOwnerId: UID, rating: 1 });
  rating.set("recipe_ratings/kept", { userId: THIRD, recipeOwnerId: UID, rating: 2 });
  deleteDuringFirstCommit(rating, "recipe_ratings/gone");
  check(
    "a rating deleted mid-scrub does not fail the rating owner scrub",
    (await scrubRatingRecipeOwner(asDb(rating), UID)) === true,
  );
  check(
    "…the other rating loses the owner stamp",
    !("recipeOwnerId" in (rating.get("recipe_ratings/kept") ?? {})),
    JSON.stringify(rating.get("recipe_ratings/kept")),
  );
}

/**
 * BUT-2344: the same race on the three sibling scrubs. A share deleted by its
 * owner (or by `onRecipeDeleted`) and a recipe deleted by its owner cost one
 * re-read, and the rows still standing are scrubbed.
 */
async function scenario_siblingScrubsSurviveARowDeletedMidCommit(): Promise<void> {
  const {
    scrubBlockHeldShares,
    removeFromSharedContent,
    scrubRecipeMemberPermissions,
  } = require("../account/account-deletion-cascade");

  const held = new FakeFirestore();
  held.set("shared_content/gone", {
    sharedByUserId: OTHER,
    blockHeldUserIds: [UID],
    blockHeld: { [UID]: { member: null } },
  });
  held.set("shared_content/kept", {
    sharedByUserId: OTHER,
    blockHeldUserIds: [UID, THIRD],
    blockHeld: { [UID]: { member: null }, [THIRD]: { member: null } },
  });
  const heldRace = deleteDuringFirstCommit(held, "shared_content/gone");
  check(
    "a share deleted mid-scrub does not fail the held-share scrub",
    (await scrubBlockHeldShares(asDb(held), UID)) === true,
  );
  check(
    "…the other share loses the erased uid from its held list",
    JSON.stringify(held.get("shared_content/kept")?.blockHeldUserIds) ===
      JSON.stringify([THIRD]),
    JSON.stringify(held.get("shared_content/kept")),
  );
  check(
    "…and the entry that would restore them",
    !(UID in ((held.get("shared_content/kept")?.blockHeld ?? {}) as DocData)),
    JSON.stringify(held.get("shared_content/kept")),
  );
  check(
    "…after exactly one retry",
    heldRace.commits === 2,
    `commits: ${heldRace.commits}`,
  );

  const ownedHeld = new FakeFirestore();
  ownedHeld.set("shared_content/mineGone", {
    sharedByUserId: UID,
    blockHeldUserIds: [THIRD],
    blockHeld: { [THIRD]: { member: null } },
  });
  ownedHeld.set("shared_content/mineKept", {
    sharedByUserId: UID,
    blockHeldUserIds: [OTHER],
    blockHeld: { [OTHER]: { member: null } },
  });
  ownedHeld.set("shared_content/mineHoldsNobody", {
    sharedByUserId: UID,
    blockHeldUserIds: [],
  });
  deleteDuringFirstCommit(ownedHeld, "shared_content/mineGone");
  check(
    "an own share deleted mid-scrub does not fail the owned half",
    (await scrubBlockHeldShares(asDb(ownedHeld), UID)) === true,
  );
  const mineKept = ownedHeld.get("shared_content/mineKept");
  check(
    "…the other own share keeps nothing held",
    mineKept !== undefined &&
      !("blockHeld" in mineKept) &&
      !("blockHeldUserIds" in mineKept),
    JSON.stringify(mineKept),
  );
  check(
    "…and an own share holding nobody is not written on either pass",
    !ownedHeld.updatedPaths.includes("shared_content/mineHoldsNobody"),
    JSON.stringify(ownedHeld.updatedPaths),
  );

  const items = new FakeFirestore();
  for (const id of ["gone", "kept"]) {
    items.set(`shared_content/${id}`, {
      contentType: "shopping_list",
      sharedByUserId: OTHER,
      sharedToUserIds: [OTHER],
    });
  }
  items.set("shared_content/gone/items/row", {
    name: "Mjölk",
    addedByUserId: UID,
    addedByDisplayName: "Raderad Person",
  });
  items.set("shared_content/kept/items/row", {
    name: "Bröd",
    addedByUserId: UID,
    addedByDisplayName: "Raderad Person",
  });
  const itemRace = deleteDuringFirstCommit(
    items,
    "shared_content/gone/items/row",
  );
  check(
    "an item deleted mid-scrub does not fail the shared_content step",
    (await removeFromSharedContent(asDb(items), UID)) === true,
  );
  const keptItem = items.get("shared_content/kept/items/row");
  check(
    "…the other item is anonymized on the second pass",
    keptItem?.addedByUserId === "deleted" &&
      keptItem?.addedByDisplayName === null,
    JSON.stringify(keptItem),
  );
  check(
    "…after exactly one retry",
    itemRace.commits === 2,
    `commits: ${itemRace.commits}`,
  );

  const recipes = new FakeFirestore();
  recipes.set(`users/${OTHER}/recipes/gone`, {
    socialData: { ownerId: OTHER, memberPermissions: { [OTHER]: 2, [UID]: 0 } },
  });
  recipes.set(`users/${THIRD}/recipes/kept`, {
    socialData: {
      ownerId: THIRD,
      memberPermissions: { [THIRD]: 2, [UID]: 1 },
      grants: { [UID]: ["direct"] },
    },
  });
  recipes.set(`users/${UID}/recipes/own`, {
    socialData: { ownerId: UID, memberPermissions: { [UID]: 2, [OTHER]: 0 } },
  });
  const recipeRace = deleteDuringFirstCommit(
    recipes,
    `users/${OTHER}/recipes/gone`,
  );
  check(
    "a recipe deleted mid-scrub does not fail the recipe member scrub",
    (await scrubRecipeMemberPermissions(asDb(recipes), UID)) === true,
  );
  const kept = recipes.get(`users/${THIRD}/recipes/kept`)?.socialData as
    | { memberPermissions?: DocData; grants?: DocData }
    | undefined;
  check(
    "…the other recipe loses the erased uid from both maps",
    kept !== undefined &&
      !(UID in (kept.memberPermissions ?? {})) &&
      !(UID in (kept.grants ?? {})) &&
      kept.memberPermissions?.[THIRD] === 2,
    JSON.stringify(kept),
  );
  check(
    "…the erased user's own recipe is not written on either pass",
    !recipes.updatedPaths.includes(`users/${UID}/recipes/own`),
    JSON.stringify(recipes.updatedPaths),
  );
  check(
    "…after exactly one retry",
    recipeRace.commits === 2,
    `commits: ${recipeRace.commits}`,
  );

  const stuck = new FakeFirestore();
  stuck.set(`users/${OTHER}/recipes/x`, {
    socialData: { ownerId: OTHER, memberPermissions: { [UID]: 0 } },
  });
  stuck.batchFailures.set(`users/${OTHER}/recipes/x`, 5);
  check(
    "a NOT_FOUND on both passes fails the recipe member scrub",
    (await scrubRecipeMemberPermissions(asDb(stuck), UID)) === false,
  );
}

/**
 * BUT-2338: the retry is one re-read on NOT_FOUND and nothing more. A
 * NOT_FOUND that comes back on the second pass fails the step, and any other
 * code fails it without a retry.
 */
async function scenario_scrubRetryIsBounded(): Promise<void> {
  const {
    scrubCommentSharedWith,
    scrubRatingRecipeOwner,
  } = require("../account/account-deletion-cascade");

  const stuck = new FakeFirestore();
  stuck.set("recipe_comments/x", { authorId: OTHER, sharedWithUserIds: [UID] });
  stuck.batchFailures.set("recipe_comments/x", 5);
  check(
    "a NOT_FOUND on both passes fails the share-list scrub",
    (await scrubCommentSharedWith(asDb(stuck), UID)) === false,
  );

  const stuckRating = new FakeFirestore();
  stuckRating.set("recipe_ratings/x", { userId: OTHER, recipeOwnerId: UID });
  stuckRating.batchFailures.set("recipe_ratings/x", 5);
  check(
    "a NOT_FOUND on both passes fails the rating owner scrub",
    (await scrubRatingRecipeOwner(asDb(stuckRating), UID)) === false,
  );

  const internal = new FakeFirestore();
  internal.set("recipe_comments/x", { authorId: OTHER, sharedWithUserIds: [UID] });
  internal.batchFailures.set("recipe_comments/x", 13);
  let reads = 0;
  const db = internal as unknown as Record<string, unknown>;
  const realCollection = db.collection as (name: string) => Record<string, unknown>;
  db.collection = (name: string) => {
    const coll = realCollection.call(internal, name);
    const realWhere = coll.where as (...a: unknown[]) => Record<string, unknown>;
    coll.where = (...a: unknown[]) => {
      const q = realWhere.apply(coll, a);
      const realLimit = q.limit as (n: number) => Record<string, unknown>;
      q.limit = (n: number) => {
        const lq = realLimit.call(q, n);
        const realGet = lq.get as () => Promise<unknown>;
        lq.get = () => {
          reads++;
          return realGet.call(lq);
        };
        return lq;
      };
      return q;
    };
    return coll;
  };
  check(
    "any other code fails the scrub",
    (await scrubCommentSharedWith(asDb(internal), UID)) === false,
  );
  check("…without a second read", reads === 1, `reads: ${reads}`);
}

/**
 * BUT-2112: each of the three probe legs fires on its own residue and stays
 * quiet on a neighbour's. Every dirty store holds nothing else of the user's,
 * so only the leg under test can fire.
 */
async function scenario_probeSeesLeftoverCommentTraces(): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");
  const run = async (db: FakeFirestore) => {
    const r = emptyResult();
    await probeResidualData(asDb(db), UID, r);
    return sawResidual(r);
  };

  const owner = new FakeFirestore();
  owner.set("recipe_comments/x", { authorId: OTHER, recipeOwnerId: UID });
  check("a surviving comment owner stamp is residual", await run(owner));

  const share = new FakeFirestore();
  share.set("recipe_comments/x", { authorId: OTHER, sharedWithUserIds: [UID] });
  check("a surviving share-list entry is residual", await run(share));

  const like = new FakeFirestore();
  like.set(`recipe_comments/x/likes/${UID}`, { userId: UID });
  check("a surviving comment like is residual", await run(like));

  const clean = new FakeFirestore();
  clean.set("recipe_comments/x", {
    authorId: OTHER,
    recipeOwnerId: THIRD,
    sharedWithUserIds: [THIRD],
  });
  clean.set(`recipe_comments/x/likes/${THIRD}`, { userId: THIRD });
  clean.set(`cook_snaps/s/likes/${UID}`, { userId: UID });
  check(
    "other people's comment traces, and a likes row outside recipe_comments, do not fire",
    !(await run(clean)),
  );
}

/**
 * BUT-2115: the erased uid leaves every reaction list it is in, on any key,
 * and every other reactor stays.
 */
async function scenario_commentReactionsLoseOnlyTheErasedUid(): Promise<void> {
  const { scrubCommentReactions } = require("../account/account-deletion-cascade");
  const db = new FakeFirestore();
  db.set("recipe_comments/c1", {
    authorId: OTHER,
    text: "gott",
    reactions: { heart: [UID, THIRD], thinking: [UID], fire: [THIRD] },
  });
  db.set("recipe_comments/c2", {
    authorId: OTHER,
    reactions: { yum: [OTHER, UID] },
  });
  db.set("recipe_comments/c3", {
    authorId: OTHER,
    reactions: { heart: [THIRD] },
  });
  db.set("recipe_comments/c4", { authorId: OTHER });

  const ok = await scrubCommentReactions(asDb(db), UID);

  check("the reaction scrub reports success", ok === true);
  check(
    "the erased uid leaves each list and the other reactors stay",
    JSON.stringify(db.get("recipe_comments/c1")?.reactions) ===
      JSON.stringify({ heart: [THIRD], thinking: [], fire: [THIRD] }) &&
      JSON.stringify(db.get("recipe_comments/c2")?.reactions) ===
        JSON.stringify({ yum: [OTHER] }),
    JSON.stringify([db.get("recipe_comments/c1"), db.get("recipe_comments/c2")]),
  );
  check(
    "the comment text and author survive",
    db.get("recipe_comments/c1")?.text === "gott" &&
      db.get("recipe_comments/c1")?.authorId === OTHER,
  );
  check(
    "comments without the erased uid are not written to",
    !db.updatedPaths.includes("recipe_comments/c3") &&
      !db.updatedPaths.includes("recipe_comments/c4"),
    JSON.stringify(db.updatedPaths),
  );

  const residual = emptyResult();
  await probeAfter(db, residual);
  check(
    "after the scrub the probe reads zero",
    !sawResidual(residual),
    `failed: ${JSON.stringify(residual.failedCollections)}`,
  );
}

/**
 * BUT-2115: over the cap on one key that key declines and writes nothing, the
 * other keys are still swept, and the step fails.
 */
async function scenario_implausibleReactionSweepDeclines(): Promise<void> {
  const {
    scrubCommentReactions,
    MAX_COMMENT_REACTION_SWEEP_ROWS,
  } = require("../account/account-deletion-cascade");

  const over = new FakeFirestore();
  for (let i = 0; i <= MAX_COMMENT_REACTION_SWEEP_ROWS; i++) {
    over.set(`recipe_comments/h-${i}`, { authorId: `p-${i}`, reactions: { heart: [UID] } });
  }
  over.set("recipe_comments/f", { authorId: OTHER, reactions: { fire: [UID, THIRD] } });
  const overOk = await scrubCommentReactions(asDb(over), UID);
  check("the reaction scrub fails the step when one key is over its cap", overOk === false);
  check(
    "the over-cap key is not written to",
    !over.updatedPaths.some((p) => p.startsWith("recipe_comments/h-")),
  );
  check(
    "the other keys are still swept",
    JSON.stringify(over.get("recipe_comments/f")?.reactions) ===
      JSON.stringify({ fire: [THIRD] }),
    JSON.stringify(over.get("recipe_comments/f")),
  );

  const atCap = new FakeFirestore();
  for (let i = 0; i < MAX_COMMENT_REACTION_SWEEP_ROWS; i++) {
    atCap.set(`recipe_comments/h-${i}`, { authorId: `p-${i}`, reactions: { heart: [UID] } });
  }
  check(
    "the reaction scrub runs at exactly its cap",
    (await scrubCommentReactions(asDb(atCap), UID)) === true &&
      atCap.updatedPaths.length === MAX_COMMENT_REACTION_SWEEP_ROWS,
  );

  const fails = new FakeFirestore();
  fails.set("recipe_comments/x", { authorId: OTHER, reactions: { yum: [UID] } });
  fails.batchFailures.set("recipe_comments/x", 13);
  check(
    "a rejected reaction-scrub chunk fails the step",
    (await scrubCommentReactions(asDb(fails), UID)) === false,
  );
}

/**
 * BUT-2115: each reaction key's probe leg fires on its own residue, and
 * another person's reaction does not fire it.
 */
async function scenario_probeSeesLeftoverReactions(): Promise<void> {
  const { COMMENT_REACTION_KEYS } = require("../account/account-deletion-cascade");
  const quiet: string[] = [];
  for (const key of COMMENT_REACTION_KEYS as readonly string[]) {
    const db = new FakeFirestore();
    db.set("recipe_comments/x", { authorId: OTHER, reactions: { [key]: [THIRD, UID] } });
    const r = emptyResult();
    await probeAfter(db, r);
    if (!sawResidual(r)) quiet.push(key);
  }
  check(
    "a surviving reaction on every key is residual",
    quiet.length === 0,
    `keys the probe missed: ${quiet.join(", ")}`,
  );

  const clean = new FakeFirestore();
  clean.set("recipe_comments/x", { authorId: OTHER, reactions: { heart: [THIRD] } });
  const r = emptyResult();
  await probeAfter(clean, r);
  check("another person's reaction does not fire the probe", !sawResidual(r));
}

async function main(): Promise<void> {
  await scenario_ratingOwnerStampIsRemoved();
  await scenario_selfRatingIsDeletedNotScrubbed();
  await scenario_implausibleRatingOwnerCountDeclines();
  await scenario_ratingOwnerScrubRunsAtTheCap();
  await scenario_failedRatingOwnerChunkFailsTheStep();
  await scenario_probeSeesLeftoverRatingOwnerStamp();
  await scenario_commentOwnerStampIsRemoved();
  await scenario_commentShareListLosesOnlyTheErasedUid();
  await scenario_commentLikesAreDeleted();
  await scenario_implausibleCommentSweepsDecline();
  await scenario_commentSweepsRunAtTheCap();
  await scenario_commentSweepFailures();
  await scenario_scrubsSurviveARowDeletedMidCommit();
  await scenario_scrubRetryIsBounded();
  await scenario_siblingScrubsSurviveARowDeletedMidCommit();
  await scenario_probeSeesLeftoverCommentTraces();
  await scenario_commentReactionsLoseOnlyTheErasedUid();
  await scenario_implausibleReactionSweepDeclines();
  await scenario_probeSeesLeftoverReactions();

  finishSuite("BUT-1766/BUT-1768 deletion cascade comments and ratings");
}

main().catch((err) => {
  console.error("Test runner crashed:", err);
  process.exit(1);
});
