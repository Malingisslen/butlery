import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";
import { Collections } from "../../shared/collections";

/**
 * Delete every doc in a personal shopping list's `items` subcollection.
 *
 * STRICT: a swallowed failure here strands item docs under a list reference the
 * caller is about to delete, and nothing could ever reach them again.
 */
async function deleteListItems(
  db: admin.firestore.Firestore,
  listRef: admin.firestore.DocumentReference,
): Promise<void> {
  const items = await listRef.collection("items").get();
  if (items.docs.length === 0) return;
  await commitInChunks(db, items.docs, (batch, doc) => batch.delete(doc.ref), {
    label: "deletePersonalListItems",
    strict: true,
  });
}

export async function deleteShoppingLists(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const userRef = db.collection("users").doc(uid);

  // BUT-1697: TWO personal paths, and only the second one holds live data.
  //
  // `shopping_lists` is the pre-rename name. It is swept for the sake of any
  // account that predates the rename, but nothing writes it today: the client
  // routes every personal list through `FirebaseShoppingRepository`, whose
  // `collectionName` is `FirestoreCollections.unifiedShoppingLists`, and
  // `firestore.rules` grants no `users/{uid}/shopping_lists` match at all —
  // so a client write there is default-denied and the path cannot hold data.
  // Sweeping only the legacy name left every live personal list on disk after
  // an Article 17 erasure. Do not collapse these two into one name.
  //
  // Items are a SUBCOLLECTION of each personal list
  // (`users/{uid}/unified_shopping_lists/{listId}/items/{itemId}` — see the
  // nested `items` match in firestore.rules). Deleting a Firestore document
  // never cascades to its subcollections, so the items must go FIRST, before
  // the parent reference is gone.
  // `listDocuments()`, not `get()`. A query returns only documents that EXIST,
  // and the client deletes a personal list with a plain `doc(id).delete()`
  // (`base_firebase_repository.dart`) which never recurses into `items`. Every
  // list the user deleted in-app therefore leaves a MISSING parent that still
  // owns a live `items` subcollection: invisible to `get()`, and counted as zero
  // by a `count()` probe, so an erasure would report clean with every item name
  // still on disk. `listDocuments()` is the Admin-SDK call that deliberately
  // includes references to missing documents that have subcollections.
  const personalRefs = await userRef
    .collection(Collections.unifiedShoppingLists)
    .listDocuments();
  // STRICT on the items, best-effort on the parents. Swallowing an item-chunk
  // failure would strand item docs under a list reference this function is
  // about to delete. Same reasoning as `deleteFamilyData`: losing the parent
  // handle strands unreachable PII, so failing loudly beats partial cleanup.
  //
  // Throwing makes `runStep` mark `shopping_lists` failed with the residual
  // still on disk and DISCOVERABLE — `listDocuments()` finds it again even
  // though the parent is gone. There is no automatic retry: the callable
  // deletes the auth user unconditionally (`request-account-deletion.ts`), so
  // the real remediation is a human reading `deletion_audit_logs` for
  // `gdprCompliant: false` and acting on it with the Admin SDK.
  //
  // Accumulate rather than letting the first failure escape: `deleteListItems`
  // is strict, and an unguarded loop would abort the whole step before the
  // legacy leg and the shared-list scrub below, leaving the deleted uid on
  // every co-member's list. A list whose items failed keeps its PARENT too, so
  // `listDocuments()` finds it again on a remediation run.
  const failedPersonal = new Set<string>();
  for (const listRef of personalRefs) {
    try {
      await deleteListItems(db, listRef);
    } catch (err) {
      failedPersonal.add(listRef.id);
      logger.error("[deletion-cascade] personal list items delete failed", {
        uid_prefix: uid.slice(0, 6),
        listId: listRef.id,
        // Code and name, never `err` or `err.message`: firebase-functions only
        // unwraps a POSITIONAL Error, so `{ err }` serialises to `{}` and the
        // cause disappears from the one log an operator reads before running
        // the manual remediation — and a Firestore commit message can embed the
        // full document path, i.e. the raw uid, in a log that outlives the
        // account.
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  await commitInChunks(
    db,
    personalRefs.filter((ref) => !failedPersonal.has(ref.id)),
    (batch, ref) => batch.delete(ref),
    { label: "deletePersonalLists", strict: false },
  );

  // LAST, deliberately: this leg is strict too, and the pre-rename path is
  // the one that can hold nothing (no rule grants it). Sweeping it first
  // would let an impossible failure abort the step before any live data was
  // touched.
  const legacyRefs = await userRef.collection("shopping_lists").listDocuments();
  const failedLegacy = new Set<string>();
  for (const listRef of legacyRefs) {
    try {
      await deleteListItems(db, listRef);
    } catch (err) {
      failedLegacy.add(listRef.id);
      logger.error("[deletion-cascade] legacy list items delete failed", {
        uid_prefix: uid.slice(0, 6),
        listId: listRef.id,
        // Code and name, never `err` or `err.message`: firebase-functions only
        // unwraps a POSITIONAL Error, so `{ err }` serialises to `{}` and the
        // cause disappears from the one log an operator reads before running
        // the manual remediation — and a Firestore commit message can embed the
        // full document path, i.e. the raw uid, in a log that outlives the
        // account.
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  await commitInChunks(
    db,
    legacyRefs.filter((ref) => !failedLegacy.has(ref.id)),
    (batch, ref) => batch.delete(ref),
    { label: "deleteLegacyShoppingLists", strict: false },
  );

  // Scrub the deleted user out of collaborative lists other members keep.
  //
  // Two levels, both required (BUT-1697). The item level clears the
  // assigned/purchased pairs and anonymizes the added/last-modified pairs. The
  // LIST level clears `lastActivityByUserId` + `lastActivityByDisplayName` and
  // `ownerDisplayName` — since every item tick writes the activity pair, a
  // deleted account otherwise leaves its raw uid and name on a shared document
  // indefinitely.
  //
  // The list-level pairs mirror `on-profile-updated.ts`, the canonical writer
  // of those fields. The item-level pairs deliberately go BEYOND it: that CF
  // only propagates owner + activity, while the client stamps four more
  // identity fields per item. Mirroring the propagation writer alone is not a
  // complete inventory — see the per-item block below.
  //
  // `ownerId` is deliberately NOT cleared: it is the key the Firestore rules
  // read to decide who may write the document, so nulling it would orphan the
  // list for every remaining member. Only the human-readable name goes. That
  // retention is justified only for a list OTHER members keep — see the
  // sole-member branch below, which deletes instead of scrubbing.
  // The deleter must be a SUPERSET of every residual probe leg, or the probe
  // reports data no code path can clear. `probeResidualData` flags a sole-member
  // list matched on `ownerId == uid`, and an owner may persist a
  // `memberPermissions` map without their own key (the rules place no
  // `cannotModify` guard on the owner), so a member-key query alone misses it.
  // Union all four queries and dedup by document id.
  //
  // BUT-1705/BUT-1725: membership and ownership are the WRONG handles on their
  // own, because both are things a user can stop having while their name stays
  // on the document. Leave a shared list — or get removed from one — and the
  // `memberPermissions` key goes, but every item you added still carries
  // `addedByDisplayName`, and the list may still carry `lastActivityByUserId`.
  // Erasure then reported clean over a name that stays visible to the remaining
  // members forever. `contributorUserIds` is the append-only trail the client
  // unions on every item write precisely so this query can find those lists;
  // `lastActivityByUserId` is queryable directly.
  const [keyedShared, ownedShared, contributedShared, activeShared] =
    await Promise.all([
      db
        .collection(Collections.unifiedSharedShoppingLists)
        .where(`memberPermissions.${uid}`, "!=", null)
        .get(),
      db
        .collection(Collections.unifiedSharedShoppingLists)
        .where("ownerId", "==", uid)
        .get(),
      db
        .collection(Collections.unifiedSharedShoppingLists)
        .where("contributorUserIds", "array-contains", uid)
        .get(),
      db
        .collection(Collections.unifiedSharedShoppingLists)
        .where("lastActivityByUserId", "==", uid)
        .get(),
    ]);
  const sharedRefs = new Map<string, admin.firestore.DocumentReference>();
  for (const doc of [
    ...keyedShared.docs,
    ...ownedShared.docs,
    ...contributedShared.docs,
    ...activeShared.docs,
  ]) {
    sharedRefs.set(doc.id, doc.ref);
  }

  // One transaction per list, re-reading inside it. Two reasons, both real:
  // the scrub rewrites the whole `items` array, so a member's tick landing
  // between the query and the write would be silently lost (the client moved
  // every shared-list mutation into a transaction in BUT-1665 for exactly
  // this); and a bare `update()` on a list the owner deleted meanwhile throws
  // NOT_FOUND, which would abort every REMAINING list in the loop and leave
  // their raw uids in place.
  //
  // The transaction only removes the NOT_FOUND abort. A contention ABORTED or a
  // DEADLINE_EXCEEDED still escapes, and on a live shared document contention is
  // the likelier failure — so each list is caught individually and the step
  // fails ONCE at the end. Failing per-list would strand every later list;
  // swallowing would report a clean erasure over retained uids.
  const failedShared: string[] = [];
  for (const listRef of sharedRefs.values()) {
    try {
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(listRef);
        if (!snap.exists) return;
        const data = snap.data() ?? {};
        const perms = (data.memberPermissions ?? {}) as Record<string, unknown>;
        const othersRemain = Object.keys(perms).some((k) => k !== uid);

        // A "collaborative" list the user created and never actually shared is
        // pure own data — every item name is theirs — and it is reachable:
        // `createCollaborativeList` accepts an empty `memberIds`, and
        // `UnifiedShoppingList.collaborative` always inserts the owner into
        // `memberPermissions`. Scrubbing it would leave the whole list on disk
        // readable by nobody (rules 1606-1609 need ownerId==uid or a
        // memberPermissions key), which is retention without a purpose. Delete it.
        if (data.ownerId === uid && !othersRemain) {
          tx.delete(listRef);
          return;
        }

        const update: Record<string, unknown> = {};

        const items = data.items;
        if (Array.isArray(items)) {
          let itemsChanged = false;
          const scrubbed = items.map((raw) => {
            if (!raw || typeof raw !== "object") return raw;
            const item = { ...(raw as Record<string, unknown>) };
            if (item.assignedToUserId === uid) {
              item.assignedToUserId = null;
              item.assignedToDisplayName = null;
              item.assignedAt = null;
              itemsChanged = true;
            }
            if (item.purchasedByUserId === uid) {
              item.purchasedByUserId = null;
              item.purchasedByDisplayName = null;
              item.purchasedAt = null;
              itemsChanged = true;
            }
            // BUT-1697: `addedBy*` and `lastModifiedBy*` are stamped by the
            // CLIENT (`UnifiedShoppingItem.collaborative` / `.copyWith`), so
            // mirroring only `on-profile-updated.ts` — which propagates the owner
            // + activity pairs — covers a strict subset of the identity a deleted
            // user leaves behind. Both survive on every item they added or last
            // touched, on a document the remaining members keep indefinitely.
            //
            // `addedByUserId` is ANONYMIZED rather than nulled: the model's
            // `isCollaborative => addedByUserId != null`, so nulling it would flip
            // a shared item to "personal" for everyone else. Same convention as
            // `deleteCommentsAndRatings`.
            if (item.addedByUserId === uid) {
              item.addedByUserId = "deleted";
              item.addedByDisplayName = null;
              itemsChanged = true;
            }
            if (item.lastModifiedByUserId === uid) {
              item.lastModifiedByUserId = "deleted";
              item.lastModifiedByDisplayName = null;
              itemsChanged = true;
            }
            return item;
          });
          if (itemsChanged) update.items = scrubbed;
        }

        if (data.lastActivityByUserId === uid) {
          update.lastActivityByUserId = null;
          update.lastActivityByDisplayName = null;
        }
        if (data.ownerId === uid && data.ownerDisplayName != null) {
          update.ownerDisplayName = null;
        }

        // The raw uid also survives as the MAP KEY this query matched on, and claim-lint:ok moved unchanged, BUT-2113
        // firestore.rules:1620-1626 still reads it as write authorization for an claim-lint:ok moved unchanged, BUT-2113
        // account that no longer exists. It also shows up in the UI:
        // `UnifiedShoppingList.memberCount`/`collaborators` are derived from these
        // keys, so remaining members see a ghost member forever. Two sibling steps
        // in this file already delete it (`deleteWeeklyMenuPlans`,
        // `deleteFamilyData`).
        //
        // It MUST go in the SAME per-doc write as the scrub, never a second one:
        // this key is the step's re-entry query handle, so a split write that
        // removed the key first would make a re-run skip the unscrubbed doc. As
        // one transaction, a re-run either still finds the key or finds nothing
        // left to do.
        if (Object.prototype.hasOwnProperty.call(perms, uid)) {
          update[`memberPermissions.${uid}`] =
            admin.firestore.FieldValue.delete();
        }

        // BUT-1725: the trail that FOUND this list is itself a raw uid on a
        // document other people keep, so it goes in the same write. Like the
        // member key above it doubles as this step's re-entry handle — removing
        // it in a separate write would let a re-run skip an unscrubbed doc.
        const contributors = data.contributorUserIds;
        if (Array.isArray(contributors) && contributors.includes(uid)) {
          update.contributorUserIds =
            admin.firestore.FieldValue.arrayRemove(uid);
        }

        if (Object.keys(update).length > 0) {
          tx.update(listRef, update);
        }
      });
    } catch (err) {
      failedShared.push(listRef.id);
      logger.error("[deletion-cascade] shared shopping-list scrub failed", {
        uid_prefix: uid.slice(0, 6),
        listId: listRef.id,
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  const failedItems = failedPersonal.size + failedLegacy.size;
  if (failedShared.length > 0 || failedItems > 0) {
    // One throw, AFTER every leg has run: `runStep` records the step failed and
    // the audit row lands with `gdprCompliant: false`, which is the signal a
    // human acts on.
    throw new Error(
      `shopping-list erasure incomplete: ${failedItems} list(s) kept their ` +
        `items, ${failedShared.length} shared list(s) unscrubbed`,
    );
  }
  return true;
}
