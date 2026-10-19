import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";
import { batchDeleteAll, scrubWithOneReread } from "./core";
import { scrubDishCreator } from "./dish-creator";

export async function removeFromSharedContent(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // BUT-1798 — the members-subcollection scrub below reaches ONLY content shared
  // through BaseSharedContentRepository.addMember() (the group path). The three
  // direct-share managers — recipe_sharing_manager, social_menu_operations and
  // shopping_social_share_module — write the parent document only and have never
  // written a members/{uid} row, so every recipient of an ad-hoc shared recipe,
  // menu or list has been un-erasable since this collection existed. The Art. 15
  // export now returns exactly those rows, so the gap has to close with it.
  //
  // Single `array-contains` on the one membership field. This was a union of
  // two queries deduped by document id, because the collection carried the same
  // list under two spellings; retired 2026-08-03.
  //
  // The admin SDK bypasses rules, so this predicate is the only access control  claim-lint:ok moved unchanged from below the members leg (BUT-1798)
  // on the read — keep it scoped to shared_content and to this exact field.
  //
  // BUT-2214: read together with `members`, before either leg removes the uid
  // from `sharedToUserIds`: `addMember` writes both handles, so a query run
  // after the members leg no longer matches a document shared that way.
  const [members, engagements, membershipSnap] = await Promise.all([
    db.collectionGroup("members").where("userId", "==", uid).get(),
    db.collectionGroup("engagements").where("userId", "==", uid).get(),
    db
      .collection("shared_content")
      .where("sharedToUserIds", "array-contains", uid)
      .get(),
  ]);

  const membershipDocs = new Map<
    string,
    admin.firestore.QueryDocumentSnapshot
  >();
  for (const doc of membershipSnap.docs) {
    // Documents this user OWNS are hard-deleted a few lines below. Updating them
    // first is wasted writes, and a batch.update against an already-deleted doc
    // throws NOT_FOUND and poison-pills the whole chunk on any retry — the same
    // failure shape as BUT-1582/1583. The owner is always in their own
    // membership array, so without this skip the overlap would be total.
    if (doc.get("sharedByUserId") === uid) continue;
    membershipDocs.set(doc.id, doc);
  }

  // BUT-2214: a menu shared with the user can hold a dish of theirs. Scrubbed
  // while the user is still in `sharedToUserIds`.
  await scrubDishCreator(
    db,
    [...membershipDocs.values()],
    uid,
    "shared_content",
  );

  // Scrub membership on each parent shared_content doc. One field: this
  // collection briefly carried the same recipient list under two spellings so
  // rows predating the writer fix stayed readable. Retired 2026-08-03 — the
  // project holds only test data, so there was nothing for the second field to
  // protect and two copies of one fact could only drift.
  if (members.docs.length > 0) {
    await commitInChunks(
      db,
      members.docs,
      (batch, doc) => {
        const parentRef = doc.ref.parent.parent;
        // BUT-1716: scoped by PATH, like the item scrub below. `members` is a
        // collection GROUP read, so it returns rows under every collection that
        // has a `members` subcollection — and an unscoped update writes an empty
        // `sharedToUserIds` onto a stranger's parent, or NOT_FOUND-poisons the
        // chunk when that parent document does not exist. Raised by the
        // `cloud-functions-specialist` and `firebase-backend-security` gates
        // once the new scoping sat three lines below an unscoped copy of itself.
        if (parentRef && isSharedContentParent(parentRef)) {
          batch.update(parentRef, {
            sharedToUserIds: admin.firestore.FieldValue.arrayRemove(uid),
          });
        }
      },
      { label: "scrubSharedToUserIds", strict: false },
    );
  }
  // The DELETE stays unscoped where the UPDATE above is scoped, on the same
  // snapshot, and the asymmetry is deliberate: the update writes a stranger's
  // parent document, while a `members` row naming this user should go wherever
  // it sits.
  await batchDeleteAll(db, members.docs);

  if (membershipDocs.size > 0) {
    await commitInChunks(
      db,
      [...membershipDocs.values()],
      (batch, doc) => {
        batch.update(doc.ref, {
          sharedToUserIds: admin.firestore.FieldValue.arrayRemove(uid),
        });
      },
      { label: "scrubSharedContentMembership", strict: false },
    );
  }

  logger.info("[deletion-cascade] shared_content membership scrub", {
    scrubbed: membershipDocs.size,
  });
  await batchDeleteAll(db, engagements.docs);

  // Delete shared_content owned by uid (subcollections first). Queried BEFORE
  // the item scrub so the scrub can skip these parents: their rows are deleted
  // a few lines down, and scrubbing a row on its way out is a wasted write.
  const owned = await db
    .collection("shared_content")
    .where("sharedByUserId", "==", uid)
    .get();
  const ownedIds = new Set(owned.docs.map((doc) => doc.id));

  const itemScrub = await scrubSharedContentItemAttribution(db, uid, ownedIds);

  const orphanedParents = new Set<string>();
  for (const doc of owned.docs) {
    // BUT-1716: `items` joins `members` here. Firestore does not delete a
    // subcollection with its parent, so every item the sharer and their
    // recipients wrote — each stamped with a uid and a display name — outlived
    // the share document, unreachable by any client and unerasable by
    // anyone but this cascade.
    //
    // Children first and STRICT, parent only if they went. Ordering alone does
    // not prevent an orphan — a swallowed chunk plus an unconditional parent
    // delete does exactly what the ordering is there to stop.
    const [childMembers, childItems] = await Promise.all([
      doc.ref.collection("members").get(),
      doc.ref.collection("items").get(),
    ]);
    try {
      await commitInChunks(
        db,
        [...childMembers.docs, ...childItems.docs],
        (batch, child) => batch.delete(child.ref),
        { label: "deleteSharedContentChildren", strict: true },
      );
    } catch (err) {
      orphanedParents.add(doc.id);
      logger.error("[deletion-cascade] shared_content children not deleted", {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  await batchDeleteAll(
    db,
    owned.docs.filter((doc) => !orphanedParents.has(doc.id)),
  );

  // The step is INCOMPLETE if either half left the uid behind. `runStep` turns claim-lint:ok moved unchanged, BUT-2113
  // false into `failedCollections` and `gdprCompliant: false` — the only thing claim-lint:ok moved unchanged, BUT-2113
  // that can contradict a clean audit row, since no probe leg reaches these
  // item rows.
  return itemScrub.ok && orphanedParents.size === 0;
}

/** The four fields on an item row that name a person by uid. */
export const ITEM_UID_FIELDS = [
  "addedByUserId",
  "lastModifiedByUserId",
  "assignedToUserId",
  "purchasedByUserId",
] as const;

/**
 * A shared-list row cap: DECLINE rather than truncate, because a truncated erasure reports success
 * over rows it never touched.
 */
const MAX_SHARED_ITEM_ROWS = 2000;

/** True for `shared_content/{id}`, and for nothing nested deeper. */
export function isSharedContentParent(ref: admin.firestore.DocumentReference): boolean {
  return ref.parent.id === "shared_content" && ref.parent.parent === null;
}

/**
 * BUT-1716: erase one user's identity from the items of shared lists OTHER
 * people keep.
 *
 * Discovery is a collection-group query PER UID FIELD, not a walk of the
 * parents this user is currently a member of. Membership is the wrong handle,
 * and for the reason the array-shaped twin already carries `contributorUserIds`:
 * `BaseSharedContentRepository.removeMember` deletes the `members/{uid}` row and
 * `arrayRemove`s the uid from `sharedToUserIds` in one call, so somebody who
 * LEFT a shared list is invisible to both handles while their uid and display
 * name stay on every row they wrote. That is the residual this leg exists to
 * close, so it must not be discovered through the thing that forgets them. The
 * four `COLLECTION_GROUP` field overrides are declared in
 * `firestore.indexes.json`.
 *
 * `users/{uid}/unified_shopping_lists/{id}/items` shares the collection-group id
 * and is erased by `deleteShoppingLists`, so rows are scoped by PATH to a
 * top-level `shared_content` parent — the two paths must not fight over the same
 * rows.
 *
 * No code in `lib/` writes this path, and `firestore.rules` carries no block for
 * it. This leg is kept anyway: rows can
 * exist on disk in a project this repo is not looking at, and a cascade that
 * stops looking is how a residual becomes permanent.
 *
 * The four pairs mirror the array-path scrub in `deleteShoppingLists` field for
 * field — the two shapes must not drift: `assignedTo*` and `purchasedBy*` are
 * cleared to null with their timestamp (a claim and a tick are facts about a
 * person, and the item is still the list's), while `addedBy*` and
 * `lastModifiedBy*` are ANONYMIZED to the sentinel `"deleted"` because the
 * client model reads `isCollaborative => addedByUserId != null` and nulling it
 * would flip a shared row back to a personal one for every remaining member.
 * Display names go in every case.
 */
async function scrubSharedContentItemAttribution(
  db: admin.firestore.Firestore,
  uid: string,
  ownedParentIds: Set<string>,
): Promise<{ ok: boolean }> {
  const rows = await sharedItemRowsNaming(db, uid, ownedParentIds);
  if (rows === null) return { ok: false };
  if (rows.length === 0) return { ok: true };

  try {
    await scrubWithOneReread(
      db,
      rows,
      async () => {
        const again = await sharedItemRowsNaming(db, uid, ownedParentIds);
        if (again === null) {
          throw new Error("scrubSharedContentItems: re-read over the cap");
        }
        return again;
      },
      (batch, doc) => {
        const data = doc.data();
        const update: Record<string, unknown> = {};
        if (data.assignedToUserId === uid) {
          update.assignedToUserId = null;
          update.assignedToDisplayName = null;
          update.assignedAt = null;
        }
        if (data.purchasedByUserId === uid) {
          update.purchasedByUserId = null;
          update.purchasedByDisplayName = null;
          update.purchasedAt = null;
        }
        if (data.addedByUserId === uid) {
          update.addedByUserId = "deleted";
          update.addedByDisplayName = null;
        }
        if (data.lastModifiedByUserId === uid) {
          update.lastModifiedByUserId = "deleted";
          update.lastModifiedByDisplayName = null;
        }
        batch.update(doc.ref, update);
      },
      "scrubSharedContentItems",
    );
  } catch (err) {
    logger.error("[deletion-cascade] shared_content item scrub failed", {
      uid_prefix: uid.slice(0, 6),
      rows: rows.length,
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return { ok: false };
  }

  logger.info("[deletion-cascade] shared_content item attribution scrub", {
    uid_prefix: uid.slice(0, 6),
    items: rows.length,
  });
  return { ok: true };
}

/**
 * The `shared_content` item rows naming `uid` in any attribution field, outside
 * the shares this user owns (the caller deletes those with their share). Null,
 * logged, when a field is over its cap.
 */
async function sharedItemRowsNaming(
  db: admin.firestore.Firestore,
  uid: string,
  ownedParentIds: Set<string>,
): Promise<admin.firestore.QueryDocumentSnapshot[] | null> {
  const rows = new Map<string, admin.firestore.QueryDocumentSnapshot>();
  for (const field of ITEM_UID_FIELDS) {
    const snap = await db
      .collectionGroup("items")
      .where(field, "==", uid)
      .limit(MAX_SHARED_ITEM_ROWS + 1)
      .get();
    if (snap.size > MAX_SHARED_ITEM_ROWS) {
      logger.error("[deletion-cascade] implausible shared item count", {
        uid_prefix: uid.slice(0, 6),
        field,
        rows: snap.size,
      });
      return null;
    }
    for (const doc of snap.docs) {
      const parentRef = doc.ref.parent.parent;
      if (!parentRef || !isSharedContentParent(parentRef)) continue;
      if (ownedParentIds.has(parentRef.id)) continue;
      rows.set(doc.ref.path, doc);
    }
  }
  return [...rows.values()];
}
