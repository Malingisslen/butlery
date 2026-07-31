/**
 * Propagate displayName/avatarUrl changes across denormalized copies.
 *
 * Triggered when a public_profiles/{userId} document is updated.
 * Updates denormalized copies in messages, conversations, recipe_comments,
 * friends subcollections, shared content members, realtime resources,
 * shared recipes, shopping lists (list level AND item level), and group
 * invitations.
 *
 * Safety: the genuinely-unbounded fan-out collections (messages, conversations,
 * recipe_comments, the `members` collection group, shared_recipes, realtime
 * resources, shared shopping lists) are paged with a per-collection documentId
 * cursor via `batchUpdateQueryPaginated` — the full result set is never held in
 * memory at once, so a prolific user can't OOM or blow the 540s timeout.
 * Collections bounded by the acting user's own subcollection (friends, personal
 * shopping lists) or their own pending outbox (group_invitations) do not need
 * the cursor for safety; the personal shopping lists keep it only because they
 * reuse the dual-field writer.
 * Steps run in parallel via Promise.all; each catches independently so one
 * failing collection can't abort the rest.
 */

import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";
import {
  batchUpdateQuery,
  batchUpdateQueryPaginated,
  batchUpdateRefs,
} from "../shared/batch-update";
import { Collections } from "../shared/collections";

const getDb = () => admin.firestore();

export const onProfileUpdated = onDocumentUpdated(
  { document: `${Collections.publicProfiles}/{userId}`, timeoutSeconds: 540 },
  async (event) => {
    const userId = event.params.userId;
    const before = event.data!.before.data();
    const after = event.data!.after.data();

    await propagateProfileUpdate(
      getDb(),
      userId,
      before.displayName as string | undefined,
      after.displayName as string | undefined,
      before.avatarUrl as string | undefined,
      after.avatarUrl as string | undefined
    );
  }
);

/**
 * DI core (testable without the trigger wrapper): fan the name/avatar change
 * out to every denormalized copy. Returns the total number of docs updated.
 * A no-op change (neither name nor avatar differs) writes nothing and reads
 * nothing.
 */
export async function propagateProfileUpdate(
  db: admin.firestore.Firestore,
  userId: string,
  oldName: string | undefined,
  newName: string | undefined,
  oldAvatar: string | undefined,
  newAvatar: string | undefined
): Promise<number> {
  const nameChanged = oldName !== newName;
  const avatarChanged = oldAvatar !== newAvatar;

  if (!nameChanged && !avatarChanged) {
    return 0;
  }

  const userHash = hashUid(userId);
  logger.info(
    `Profile updated for ${userHash}: name=${nameChanged}, avatar=${avatarChanged}`
  );

  const messageUpdates: Record<string, unknown> = {};
  if (nameChanged) messageUpdates["senderDisplayName"] = newName;
  if (avatarChanged) messageUpdates["senderAvatarUrl"] = newAvatar;

  const memberUpdates: Record<string, unknown> = {};
  if (nameChanged) memberUpdates["displayName"] = newName;
  if (avatarChanged) memberUpdates["avatarUrl"] = newAvatar;

  const commentUpdates: Record<string, unknown> = {};
  if (nameChanged) commentUpdates["authorDisplayName"] = newName;
  if (avatarChanged) commentUpdates["authorAvatarUrl"] = newAvatar;

  // The conversation denorm keys are `<map>.<userId>`; userId is constant for
  // the whole invocation, so the update map is identical across every matched
  // doc — no per-doc callback needed, which lets it use the paged writer.
  const conversationUpdates: Record<string, unknown> = {};
  if (nameChanged) conversationUpdates[`participantDisplayNames.${userId}`] = newName;
  if (avatarChanged) conversationUpdates[`participantAvatarUrls.${userId}`] = newAvatar;

  const steps: Array<Promise<number>> = [
    batchUpdateQueryPaginated(
      db.collection(Collections.messages).where("senderId", "==", userId),
      messageUpdates,
      db
    ).catch((e) => { logger.error(`Failed to update messages for ${userHash}`, e); return 0; }),

    batchUpdateQueryPaginated(
      db.collection(Collections.conversations).where("participantIds", "array-contains", userId),
      conversationUpdates,
      db
    ).catch((e) => { logger.error(`Failed to update conversations for ${userHash}`, e); return 0; }),

    batchUpdateQueryPaginated(
      db.collection(Collections.recipeComments).where("authorId", "==", userId),
      commentUpdates,
      db
    ).catch((e) => { logger.error(`Failed to update recipe_comments for ${userHash}`, e); return 0; }),

    batchUpdateQueryPaginated(
      db.collectionGroup("members").where("userId", "==", userId),
      memberUpdates,
      db
    ).catch((e) => { logger.error(`Failed to update members for ${userHash}`, e); return 0; }),
  ];

  if (nameChanged) {
    // Friends subcollection — bounded by the acting user's OWN friend count
    // (their friends/ subcollection), so a single read + chunked ref writes
    // stays memory-safe without a cursor.
    steps.push(
      (async () => {
        const friendsSnapshot = await db.collection(Collections.users).doc(userId).collection("friends").get();
        if (friendsSnapshot.empty) return 0;
        return batchUpdateRefs(
          friendsSnapshot.docs.map((friendDoc) =>
            db.collection(Collections.users).doc(friendDoc.id).collection("friends").doc(userId)
          ),
          () => ({ displayNameLower: newName?.toLowerCase() }),
          db
        );
      })().catch((e) => { logger.error(`Failed to update friends for ${userHash}`, e); return 0; })
    );

    // Realtime resources — owner + last-editor denorm names.
    for (const col of [Collections.realtimeRecipes, Collections.realtimeMenus]) {
      steps.push(
        paginatedDualUpdate(db, db.collection(col), userId,
          { queryField: "ownerId", updateField: "ownerDisplayName" },
          { queryField: "lastEditedBy", updateField: "lastEditedByDisplayName" },
          newName)
          .catch((e) => { logger.error(`Failed to update ${col} for ${userHash}`, e); return 0; })
      );
    }

    steps.push(
      batchUpdateQueryPaginated(
        db.collection(Collections.sharedRecipes).where("socialData.ownerId", "==", userId),
        { "socialData.ownerDisplayName": newName },
        db
      ).catch((e) => { logger.error(`Failed to update shared_recipes for ${userHash}`, e); return 0; })
    );

    // Shared shopping lists — owner + last-activity denorm names. A real
    // top-level collection with unbounded fan-out (the user can be a member of
    // any number of other people's lists), so both legs stay paged.
    steps.push(
      paginatedDualUpdate(db, db.collection(Collections.unifiedSharedShoppingLists), userId,
        { queryField: "ownerId", updateField: "ownerDisplayName" },
        { queryField: "lastActivityByUserId", updateField: "lastActivityByDisplayName" },
        newName)
        .catch((e) => { logger.error(`Failed to update ${Collections.unifiedSharedShoppingLists} for ${userHash}`, e); return 0; })
    );

    // Personal shopping lists — BUT-1724: these are a SUBCOLLECTION of the
    // acting user (`users/{uid}/unified_shopping_lists`, see
    // `FirebaseShoppingRepository.collectionName` and the `firestore.rules`
    // match under `users/{userId}`). There is no top-level collection of that
    // name, so the top-level query this leg used to run matched zero documents
    // forever while still billing two reads per rename. Bounded by the user's
    // own list count, but kept on the same dual-field paged writer as the
    // shared leg: `lastActivityByUserId` may name SOMEONE ELSE on a list copied
    // out of a collaborative one, and that person's stamp must not be
    // overwritten with this user's new name.
    steps.push(
      paginatedDualUpdate(
        db,
        db.collection(Collections.users).doc(userId).collection(Collections.unifiedShoppingLists),
        userId,
        { queryField: "ownerId", updateField: "ownerDisplayName" },
        { queryField: "lastActivityByUserId", updateField: "lastActivityByDisplayName" },
        newName)
        .catch((e) => { logger.error(`Failed to update personal ${Collections.unifiedShoppingLists} for ${userHash}`, e); return 0; })
    );

    // BUT-1770: ITEM-level attribution. The inventory is
    // `UnifiedShoppingItem.toFirestore()`, not the ticket text: it persists
    // FOUR denormalised name/id pairs — `addedBy*`, `lastModifiedBy*`,
    // `assignedTo*` and `purchasedBy*` — and `account-deletion-cascade.ts`
    // scrubs all four. Nothing propagated a rename down to any of them, so a
    // household kept reading the old name on every row while the list header
    // already showed the new one.
    //
    // `assignedToDisplayName` is the one that is actually ON SCREEN: it is the
    // BUT-238 "Tar jag" claim chip (`collaborative_shopping_items.dart`,
    // `_AssigneeBadge` + the "Annas del" section heading). A version of this
    // leg that covered only `addedBy*`/`lastModifiedBy*` propagated the two
    // pairs with no UI reader at all and left the visible one stale — i.e. it
    // did not change what anyone sees. `purchasedByDisplayName` additionally
    // ships in the Art. 15 bundle (`shared_shopping_list_export.dart`), so its
    // staleness is an accuracy problem on a downloadable artifact too.
    //
    // TWO storage shapes, and a fix that covers one leaves the other stale:
    //
    //   * a SUBCOLLECTION — `users/{uid}/unified_shopping_lists/{listId}/items`
    //     (the path `firestore.rules` grants and the deletion cascade sweeps)
    //     and `shared_content/{contentId}/items`. A collection-group query
    //     reaches both wherever they are nested; it needs the declared
    //     COLLECTION_GROUP field overrides in `firestore.indexes.json`, since
    //     Firestore's automatic single-field indexes are collection-scoped.
    //
    //   * an EMBEDDED ARRAY on the shared list document — `firestore.rules`
    //     says it outright ("items are embedded in the list doc"). No query can
    //     filter on a field inside an array element and no update can patch one
    //     in place, so that leg reads the document and rewrites the array.
    for (const pair of ITEM_ATTRIBUTION_PAIRS) {
      steps.push(
        batchUpdateQueryPaginated(
          db.collectionGroup("items").where(pair.queryField, "==", userId),
          { [pair.updateField]: newName },
          db
        ).catch((e) => { logger.error(`Failed to update ${pair.updateField} on items for ${userHash}`, e); return 0; })
      );
    }

    steps.push(
      renameEmbeddedShoppingItems(db, userId, newName)
        .catch((e) => { logger.error(`Failed to update embedded shopping items for ${userHash}`, e); return 0; })
    );

    // Group invitations — bounded by the acting user's OWN pending outbox
    // (fromUserId == userId, status == pending). Bounded and, being a
    // two-equality filter, kept on the plain reader so no orderBy(__name__) +
    // composite-index requirement is introduced.
    steps.push(
      batchUpdateQuery(
        db.collection(Collections.groupInvitations)
          .where("fromUserId", "==", userId)
          .where("status", "==", "pending"),
        { fromUserName: newName },
        db
      ).catch((e) => { logger.error(`Failed to update group_invitations for ${userHash}`, e); return 0; })
    );
  }

  const results = await Promise.all(steps);
  const totalUpdated = results.reduce((sum, n) => sum + n, 0);

  logger.info(
    `Profile propagation complete for ${userHash}: ${totalUpdated} documents updated`
  );

  return totalUpdated;
}

/**
 * BUT-1770: rewrite the acting user's denormalized name inside the `items`
 * ARRAY embedded on every shared shopping list they have contributed to.
 *
 * `contributorUserIds` is the handle, not membership or ownership. It is the
 * append-only trail the client unions on every item write, and the rules
 * (BUT-1725) exist to keep it that way precisely so a query can find the lists
 * whose ITEMS carry a given person's name — including lists that person has
 * since left, where a membership query would find nothing while their name sat
 * on every row they ever added. The deletion cascade uses the same handle for
 * the same reason.
 *
 * One transaction per list, re-reading inside it. Both reasons are real and
 * both come from the cascade's experience with this same array: rewriting the
 * whole `items` array would silently drop a household member's concurrent tick
 * (the client moved every shared-list mutation into a transaction in BUT-1665
 * for exactly this), and a bare `update()` on a list deleted meanwhile throws
 * NOT_FOUND, which in a shared batch would take every other list down with it.
 *
 * The outer read is paged with a documentId cursor like every other unbounded
 * leg here: a user can contribute to any number of other people's lists, and
 * the whole result set must never sit in memory at once. The cursor is stable
 * because the write touches `items`, never `contributorUserIds`.
 *
 * Returns the number of list documents actually rewritten.
 */
async function renameEmbeddedShoppingItems(
  db: admin.firestore.Firestore,
  userId: string,
  newName: string | undefined
): Promise<number> {
  const ordered = db
    .collection(Collections.unifiedSharedShoppingLists)
    .where("contributorUserIds", "array-contains", userId)
    .orderBy(admin.firestore.FieldPath.documentId());

  let lastDoc: admin.firestore.QueryDocumentSnapshot | undefined;
  let updated = 0;

  for (;;) {
    let page = ordered.limit(EMBEDDED_ITEMS_PAGE_SIZE);
    if (lastDoc) {
      page = page.startAfter(lastDoc);
    }
    const snapshot = await page.get();
    if (snapshot.empty) break;

    for (const doc of snapshot.docs) {
      if (await renameItemsOnList(db, doc.ref, userId, newName)) updated++;
    }

    lastDoc = snapshot.docs[snapshot.docs.length - 1];
    if (snapshot.size < EMBEDDED_ITEMS_PAGE_SIZE) break;
  }

  return updated;
}

/**
 * Page size for the embedded-items rewrite. Deliberately far below the write
 * batch limit: each page costs one TRANSACTION per document, not one batched
 * op, so a large page buys nothing and just holds more list documents (items
 * included) in memory at once.
 */
const EMBEDDED_ITEMS_PAGE_SIZE = 50;

/** Returns true when the list's item array actually changed. */
async function renameItemsOnList(
  db: admin.firestore.Firestore,
  listRef: admin.firestore.DocumentReference,
  userId: string,
  newName: string | undefined
): Promise<boolean> {
  return db.runTransaction(async (tx) => {
    const snap = await tx.get(listRef);
    if (!snap.exists) return false;

    const items = snap.data()?.items;
    if (!Array.isArray(items)) return false;

    let changed = false;
    const renamed = items.map((raw) => {
      if (!raw || typeof raw !== "object") return raw;
      const item = { ...(raw as Record<string, unknown>) };
      // Only the rows this user is stamped on, and the same four pairs the
      // subcollection leg queries. A shared list carries several people's
      // names, and rewriting a row whose `addedByUserId` names someone else
      // would put THIS user's name on THEIR item — the mirror of the bug the
      // personal-list leg above guards against.
      for (const { queryField, updateField } of ITEM_ATTRIBUTION_PAIRS) {
        if (item[queryField] === userId && item[updateField] !== newName) {
          item[updateField] = newName ?? null;
          changed = true;
        }
      }
      return item;
    });

    if (!changed) return false;
    tx.update(listRef, { items: renamed });
    return true;
  });
}

interface DualFieldPair {
  queryField: string;
  updateField: string;
}

/**
 * Every denormalised name/id pair `UnifiedShoppingItem.toFirestore()` persists.
 *
 * Enumerated from the model, not from a ticket: this is the same group
 * `account-deletion-cascade.ts` scrubs, and the two lists must stay equal —
 * an erasure that clears a field a rename does not maintain is a field with
 * two different owners and no single source of truth. Both the collection-group
 * leg and the embedded-array rewrite iterate this constant, so adding a fifth
 * pair to the model means one edit here (plus its `firestore.indexes.json`
 * COLLECTION_GROUP override, which the index-assertion test pins).
 */
const ITEM_ATTRIBUTION_PAIRS: readonly DualFieldPair[] = [
  { queryField: "addedByUserId", updateField: "addedByDisplayName" },
  {
    queryField: "lastModifiedByUserId",
    updateField: "lastModifiedByDisplayName",
  },
  { queryField: "assignedToUserId", updateField: "assignedToDisplayName" },
  { queryField: "purchasedByUserId", updateField: "purchasedByDisplayName" },
];

/**
 * Update a collection that denormalizes the user's name under two independent
 * fields (e.g. owner + last-editor). Each field's query is paged separately
 * with a documentId cursor via `batchUpdateQueryPaginated`, so neither result
 * set is ever fully held in memory.
 *
 * Takes a `CollectionReference` rather than a collection NAME (BUT-1724): the
 * personal-shopping-list caller needs a user subcollection, and passing a name
 * silently produced a top-level query that matched nothing.
 *
 * Unlike the previous merge-by-doc-id approach, a doc matching BOTH queries
 * (owner == last-editor, common) is written once per pass. That is a second
 * write to a DIFFERENT field, so the resulting document state is identical;
 * the extra write is a negligible cost on the rare profile-name-change event,
 * paid to keep the read memory-bounded. The two passes touch disjoint fields
 * from the ones they filter on, so each cursor is stable.
 *
 * Returns the sum of docs updated across both passes (overlap docs counted
 * twice, matching the write count).
 */
async function paginatedDualUpdate(
  db: admin.firestore.Firestore,
  collection: admin.firestore.CollectionReference,
  userId: string,
  primary: DualFieldPair,
  secondary: DualFieldPair,
  newName: string | undefined
): Promise<number> {
  const [primaryUpdated, secondaryUpdated] = await Promise.all([
    batchUpdateQueryPaginated(
      collection.where(primary.queryField, "==", userId),
      { [primary.updateField]: newName },
      db
    ),
    batchUpdateQueryPaginated(
      collection.where(secondary.queryField, "==", userId),
      { [secondary.updateField]: newName },
      db
    ),
  ]);

  return primaryUpdated + secondaryUpdated;
}
