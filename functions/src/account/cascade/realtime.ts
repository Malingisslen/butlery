import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";
import { Collections } from "../../shared/collections";
import { batchDeleteAll } from "./core";
import { scrubDishCreator } from "./dish-creator";

/**
 * BUT-1768: `realtime_menus` was in no tier at all — a collaborative menu the
 * user owns survived an Article 17 erasure intact, readable by every
 * participant, and no residual probe looked at it.
 *
 * `ownerId` is the owner field, NOT `userId`. That is the BUT-1396 trap this
 * step is written to avoid: the model writes `ownerId`, the `realtime_menus`
 * rule gates read/update/delete on it, and `on-profile-updated.ts` renames on
 * it — a `where("userId", "==", uid)` filter is syntactically perfect, throws
 * nothing and matches zero documents forever.
 *
 * Menus the user does NOT own are the other half (see [scrubLastEditor] and
 * [removeRealtimeParticipation]).
 */
export async function deleteRealtimeMenus(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const owned = await db
    .collection(Collections.realtimeMenus)
    .where("ownerId", "==", uid)
    .get();
  await deleteRealtimeDocsWithChildren(db, owned.docs);

  await scrubLastEditor(db, Collections.realtimeMenus, uid);
  const stillJoined = await removeRealtimeParticipation(
    db,
    Collections.realtimeMenus,
    uid,
  );
  await removeVoteEntries(db, stillJoined, uid);
  return true;
}

/**
 * BUT-2151: live menus (`realtime_resources`). Owned documents go, the
 * last-editor pair is anonymized on
 * the rest, and the user leaves every roster they were in. The roster leg
 * removes the uid from `participantIds` and `participants` together, which is
 * the pair the rules require to stay in step.
 */
export async function deleteRealtimeResources(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const votesCleared = await deleteLiveMenuVotes(db, uid);

  const owned = await db
    .collection(Collections.realtimeResources)
    .where("ownerId", "==", uid)
    .get();
  await deleteRealtimeDocsWithChildren(db, owned.docs);

  await scrubLastEditor(db, Collections.realtimeResources, uid);
  await removeRealtimeParticipation(db, Collections.realtimeResources, uid);
  return votesCleared;
}

export const MAX_LIVE_MENU_VOTE_SWEEP_ROWS = 2000;

/**
 * BUT-2118: the person's own ballot documents,
 * `realtime_resources/{menuId}/votes/{uid}`, on every live menu, including
 * menus they have LEFT. That last case is why this is a collection-group
 * query on `userId` and not a walk over the menus the roster sweep finds: a
 * leaver is no longer in `participantIds`, and their document stays until its
 * TTL. Owned menus lose all their ballots through
 * [deleteRealtimeDocsWithChildren]; this leg may delete the owner's own
 * document there too, which is harmless.
 *
 * Filtered on the parent collection, because the collection id `votes` is
 * shared with the legacy `realtime_menus/{id}/votes` documents; the legacy
 * uid-in-a-map residue stays with [removeVoteEntries].
 *
 * A failed chunk makes the step report failure rather than a clean one, and
 * the menu legs after it still run. Capped like the poll-vote sweep; the leg
 * in `probeResidualData` reads the same rows.
 */
export async function deleteLiveMenuVotes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const ballots = await liveMenuBallotRows(db, uid);
  if (ballots === null) {
    logger.error(
      "[deletion-cascade] implausible live-menu ballot count; not sweeping",
      { uid_prefix: uid.slice(0, 6) },
    );
    return false;
  }
  try {
    await commitInChunks(
      db,
      ballots,
      (batch, doc) => batch.delete(doc.ref),
      { label: "deleteLiveMenuVotes", strict: true },
    );
  } catch (err) {
    logger.error("[deletion-cascade] live-menu ballot sweep failed", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return false;
  }
  return true;
}

/** True for `realtime_resources/{id}`, and for nothing nested deeper. */
function isLiveMenuParent(ref: admin.firestore.DocumentReference): boolean {
  return (
    ref.parent.id === Collections.realtimeResources && ref.parent.parent === null
  );
}

/**
 * The erased user's ballot documents, found by collection group and kept only
 * under a top-level `realtime_resources` document. `null` when the read
 * exceeds the cap.
 */
export async function liveMenuBallotRows(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<admin.firestore.QueryDocumentSnapshot[] | null> {
  const snap = await db
    .collectionGroup(Collections.liveMenuVotes)
    .where("userId", "==", uid)
    .limit(MAX_LIVE_MENU_VOTE_SWEEP_ROWS + 1)
    .get();
  if (snap.size > MAX_LIVE_MENU_VOTE_SWEEP_ROWS) return null;
  return snap.docs.filter((doc) => {
    const parent = doc.ref.parent.parent;
    return parent !== null && isLiveMenuParent(parent);
  });
}

/**
 * Strip `votes.<uid>` from every vote document under menus the user took part
 * in but does not own.
 *
 * `realtime_menus/{menuId}/votes/{voteId}` is NOT uid-keyed by document id
 * despite what the rules comment suggests: the doc id is the slot's vote id and
 * the ballot is a MAP, `votes: {userId -> optionId}`. So the deleted
 * user's uid survives one level below the document the participation sweep
 * cleans, on a menu that continues to exist for its owner.
 *
 * Scoped to the menus the participation sweep just found, which is the only claim-lint:ok moved unchanged, BUT-2113
 * bounded handle there is: a map KEY cannot be queried, so a menu the user
 * voted in and later LEFT is out of reach here (the same class as messages in
 * a left conversation) and would need a full `collectionGroup("votes")` scan.
 * Recorded rather than silently skipped.
 */
async function removeVoteEntries(
  db: admin.firestore.Firestore,
  menus: admin.firestore.QueryDocumentSnapshot[],
  uid: string,
): Promise<void> {
  for (const menu of menus) {
    const votes = await menu.ref.collection("votes").get();
    const carrying = votes.docs.filter((v) => {
      const ballot = v.data().votes;
      return (
        !!ballot && typeof ballot === "object" && uid in (ballot as object)
      );
    });
    if (carrying.length === 0) continue;
    await commitInChunks(
      db,
      carrying,
      (batch, voteDoc) => {
        batch.update(voteDoc.ref, {
          [`votes.${uid}`]: admin.firestore.FieldValue.delete(),
        });
      },
      { label: "removeVoteEntries", strict: false },
    );
  }
}

/**
 * The rule-blessed child collections of a realtime document.
 *
 * `firestore.rules` declares `realtime_menus/{id}/presence/{userId}` and
 * `/votes/{voteId}`. Both are
 * uid-keyed and both carry personal data: a presence doc holds
 * `{displayName, isActive, lastSeen}`, and a vote document's `votes` map is
 * keyed `userId -> optionId`.
 */
const REALTIME_CHILD_COLLECTIONS = ["presence", "votes"] as const;

/**
 * Delete realtime parent documents AND their child subcollections.
 *
 * Firestore never cascades: `batch.delete(parentRef)` leaves every document
 * under `parent/presence` and `parent/votes` in place, orphaned. An orphan here
 * is the worst possible residual — unreadable by any client (both child rules
 * resolve participation through the parent, which no longer exists), unfindable
 * by any later erasure, and invisible to `probeResidualData`, which counts
 * TOP-LEVEL documents only. The cascade would push `realtime_menus` into
 * `deletedCollections` and the audit row would certify `gdprCompliant: true`
 * over a document still holding the deleted user's uid.
 *
 * Children first and STRICT, parent best-effort: if the child sweep cannot
 * complete, the parent must stay so a retry can still find the children through
 * it. The reverse order is precisely how an orphan is created.
 */
async function deleteRealtimeDocsWithChildren(
  db: admin.firestore.Firestore,
  docs: admin.firestore.QueryDocumentSnapshot[],
): Promise<void> {
  if (docs.length === 0) return;
  for (const doc of docs) {
    for (const child of REALTIME_CHILD_COLLECTIONS) {
      const kids = await doc.ref.collection(child).get();
      if (kids.docs.length === 0) continue;
      await commitInChunks(
        db,
        kids.docs,
        (batch, kid) => batch.delete(kid.ref),
        { label: `deleteRealtimeChildren:${child}`, strict: true },
      );
    }
  }
  await batchDeleteAll(db, docs);
}

/**
 * Drop the deleted user from realtime documents they PARTICIPATE in but do not
 * own — the third residual on this surface, and the one nothing covered.
 *
 * `scrubLastEditor` only reaches documents where they happened to be the last
 * editor. A collaborator who joined, was seen, voted and never made the final
 * edit left three things behind on someone else's document, all of them visible
 * to the remaining collaborators: the `presence/{uid}` child document (which
 * carries a `displayName`), the `participants` MAP KEY, and their
 * `participantIds` entry. The map key is also live authorization —
 * `firestore.rules` grants update to `request.auth.uid in
 * resource.data.participantIds` — so leaving it is a dangling grant for an
 * account that no longer exists.
 *
 * Owned documents are excluded: the sibling leg has already deleted them, and
 * an update against a deleted document throws NOT_FOUND.
 *
 * Returns the non-owned documents it cleaned, so a caller can reach one level
 * further down (see [removeVoteEntries]).
 */
async function removeRealtimeParticipation(
  db: admin.firestore.Firestore,
  collection: string,
  uid: string,
): Promise<admin.firestore.QueryDocumentSnapshot[]> {
  const joined = await db
    .collection(collection)
    .where("participantIds", "array-contains", uid)
    .get();
  const notOwned = joined.docs.filter((doc) => doc.data().ownerId !== uid);
  if (notOwned.length === 0) return notOwned;

  // BUT-2214: before the roster write below.
  await scrubDishCreator(db, notOwned, uid, collection);

  for (const doc of notOwned) {
    const presence = doc.ref.collection("presence").doc(uid);
    try {
      await presence.delete();
    } catch (err) {
      logger.warn("[deletion-cascade] realtime presence delete failed", {
        uid_prefix: uid.slice(0, 6),
        path: presence.path,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }

  await commitInChunks(
    db,
    notOwned,
    (batch, doc) => {
      batch.update(doc.ref, {
        participantIds: admin.firestore.FieldValue.arrayRemove(uid),
        [`participants.${uid}`]: admin.firestore.FieldValue.delete(),
      });
    },
    { label: `removeRealtimeParticipation:${collection}`, strict: false },
  );
  return notOwned;
}

/**
 * Anonymize the `lastEditedBy` / `lastEditedByDisplayName` pair on realtime
 * documents in [collection] that the deleted user last edited but does NOT own.
 *
 * The decision this encodes: the document itself stays. It belongs to its
 * owner, and the other participants are still collaborating on it — deleting
 * someone else's menu because a departing member touched it last would be
 * erasure of THEIR data, not of the deleted user's. What must go is the
 * identity pair, which `on-profile-updated.ts` maintains as a denormalised copy
 * of the user's profile name: without this it survives on a document other
 * people keep open indefinitely, and the rename propagator that used to keep it
 * current stops running the moment the account is gone.
 *
 * Anonymized rather than nulled, mirroring `deleteCommentsAndRatings` and the
 * shared-shopping-list item scrub: the fields are non-nullable in the client
 * model (`RealtimeResource`), so a null would fail the `as String` cast on read
 * for every remaining participant.
 *
 * Owned documents are excluded because the sibling leg has already deleted
 * them; a scrub of a deleted document throws NOT_FOUND.
 */
async function scrubLastEditor(
  db: admin.firestore.Firestore,
  collection: string,
  uid: string,
): Promise<void> {
  const edited = await db
    .collection(collection)
    .where("lastEditedBy", "==", uid)
    .get();
  const notOwned = edited.docs.filter((doc) => doc.data().ownerId !== uid);
  if (notOwned.length === 0) return;

  // Per-doc transaction, not a blind batch.update() from the query snapshot:
  // this is a REALTIME collection, so a different collaborator editing the
  // same doc between the query and the write is the expected case, not the
  // edge case. Re-checking lastEditedBy inside the transaction means a fresh
  // edit wins and is never reverted back to "deleted"; a stale write would
  // silently stamp someone else's just-made edit with the departed user's
  // tombstone. Best-effort per doc, mirroring the swallowed commitInChunks
  // failures this replaces.
  const chunkSize = 10;
  for (let i = 0; i < notOwned.length; i += chunkSize) {
    const chunk = notOwned.slice(i, i + chunkSize);
    await Promise.all(
      chunk.map(async (doc) => {
        try {
          await db.runTransaction(async (tx) => {
            const fresh = await tx.get(doc.ref);
            if (!fresh.exists) return;
            if (fresh.data()?.lastEditedBy !== uid) return;
            tx.update(doc.ref, {
              lastEditedBy: "deleted",
              lastEditedByDisplayName: "[Raderad användare]",
            });
          });
        } catch (err) {
          logger.warn(`scrubLastEditor:${collection}: doc write failed`, {
            uid_prefix: uid.slice(0, 6),
            docId: doc.id,
            errName: err instanceof Error ? err.name : typeof err,
          });
        }
      }),
    );
  }
}
