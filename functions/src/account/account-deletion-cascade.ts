/**
 * BUT-788: Firestore cascade for server-side account deletion.
 *
 * Runs under Admin SDK from the `requestAccountDeletion` callable. Owns the
 * user's own-data deletion across ~25 collections; cross-user cleanup
 * (friendships, friend counts, group memberships, anonymizations) is owned
 * by the existing `onUserDeleted` v1 auth trigger which fires automatically
 * AFTER `admin.auth().deleteUser(uid)` — see request-account-deletion.ts.
 *
 * **Tier ordering** (mirrors the prior client cascade in
 * `lib/services/account/account_deletion/`):
 *
 *   Tier 1 (parallel): own-content + own-data-on-shared-surfaces.
 *     Recipes, menus, shopping lists, personal tags, cook-snaps, activity
 *     events, weekly menus, pantry, messages, shared content, comments &
 *     ratings, pings, reports, notifications & FCM tokens.
 *   Tier 2 (parallel after T1): subcollections under `users/{uid}` that
 *     Firestore won't cascade when the root doc is deleted.
 *   Tier 3 (final): the `users/{uid}` root document itself.
 *
 * Each step returns `true` on success, `false` on caught failure. A failed
 * step is recorded in `failedCollections` of the orchestrator result and
 * does NOT abort the cascade — partial cleanup beats total failure for
 * GDPR Article 17. The audit log records `gdprCompliant: false` whenever
 * `failedCollections` is non-empty.
 *
 * Idempotency: every step uses Firestore deletes / `arrayRemove` / `set`
 * with merge, or a per-document transaction that re-reads before it writes
 * — all safe to re-run if the caller retries after a partial failure. The post-cascade probe (`probeResidualData`) confirms the
 * highest-risk collections are empty after the run.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../shared/batch-update";
import { Collections } from "../shared/collections";

export interface DeletionResult {
  deletedCollections: string[];
  failedCollections: string[];
  errors: string[];
}

export type Step = () => Promise<boolean>;

/**
 * Run one cascade step, recording its outcome on `result`. Never throws —
 * a step exception is logged and rolled into `failedCollections`.
 */
export async function runStep(
  name: string,
  result: DeletionResult,
  step: Step,
): Promise<void> {
  try {
    const ok = await step();
    if (ok) {
      result.deletedCollections.push(name);
    } else {
      result.failedCollections.push(name);
    }
  } catch (err) {
    result.failedCollections.push(name);
    result.errors.push(`${name}: ${err instanceof Error ? err.message : String(err)}`);
    logger.error(`[deletion-cascade] step ${name} failed`, { err });
  }
}

/**
 * GDPR canary — query the highest-risk collections AFTER the cascade.
 * Any non-zero count means a delete path silently dropped data. The probe
 * is the safety net, never the cascade itself: errors are logged but never
 * abort the wider deletion.
 *
 * Mirrors `_probeResidualData` in the prior client implementation.
 */
export async function probeResidualData(
  db: admin.firestore.Firestore,
  uid: string,
  result: DeletionResult,
): Promise<void> {
  const probes = [
    "recipes",
    "user_notifications",
    "user_fcm_tokens",
    // BUT-1450: notification analytics the cascade erases (all userId-scoped).
    "notification_history",
    "notification_batches",
    "notification_engagement",
    // BUT-1473: allergen tag-override corrections (top-level, userId-scoped).
    "tag_overrides_log",
  ] as const;
  let residual = 0;
  for (const col of probes) {
    try {
      const snap = await db
        .collection(col)
        .where("userId", "==", uid)
        .count()
        .get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn(`[deletion-cascade] residual in ${col}: ${count} docs`);
      }
    } catch (err) {
      residual += 1;
      logger.error(`[deletion-cascade] residual probe failed: ${col}`, { err });
    }
  }
  // BUT-1450: notification_delivery is scoped by senderId / targetUserId, NOT
  // userId, so it needs its own two-field probe — a userId==uid probe would
  // silently match zero (the realtime_recipes wrong-field trap).
  for (const field of ["senderId", "targetUserId"] as const) {
    try {
      const snap = await db
        .collection("notification_delivery")
        .where(field, "==", uid)
        .count()
        .get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn(
          `[deletion-cascade] residual in notification_delivery.${field}: ${count} docs`,
        );
      }
    } catch (err) {
      residual += 1;
      logger.error(
        `[deletion-cascade] residual probe failed: notification_delivery.${field}`,
        { err },
      );
    }
  }
  // Subcollections under users/{uid}. These are NOT top-level userId-scoped
  // collections, so a where("userId","==",uid) probe would silently match zero
  // (the realtime_recipes wrong-field trap). Probe each one directly.
  //
  // - canonical_rating_events (decision 12): the user's frozen pool events,
  //   erased in deleteUserSubcollections. A leaf collection — `count()` sees
  //   everything it can hold.
  const subProbes = ["canonical_rating_events"] as const;
  for (const col of subProbes) {
    try {
      const snap = await db
        .collection("users")
        .doc(uid)
        .collection(col)
        .count()
        .get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn(`[deletion-cascade] residual in ${col}: ${count} docs`);
      }
    } catch (err) {
      residual += 1;
      logger.error(`[deletion-cascade] residual probe failed: ${col}`, { err });
    }
  }

  // unified_shopping_lists (BUT-1697): the LIVE personal shopping-list path,
  // erased in deleteShoppingLists. The canary was blind to it while the cascade
  // swept only the legacy `shopping_lists` name.
  //
  // `listDocuments()`, not `count()`. The client deletes a list doc without
  // recursing into its `items` subcollection, so a residual here can be a
  // MISSING parent that still owns live item docs — a state `count()` reports as
  // zero. A probe that cannot see what the deleter must remove is a probe that
  // certifies an incomplete erasure.
  try {
    const listRefs = await db
      .collection("users")
      .doc(uid)
      .collection(Collections.unifiedShoppingLists)
      .listDocuments();
    if (listRefs.length > 0) {
      residual += listRefs.length;
      logger.warn(
        `[deletion-cascade] residual in ${Collections.unifiedShoppingLists}: ${listRefs.length} list refs (incl. missing parents that still own items)`,
      );
    }
  } catch (err) {
    residual += 1;
    logger.error(
      `[deletion-cascade] residual probe failed: ${Collections.unifiedShoppingLists}`,
      { err },
    );
  }

  // unified_shared_shopping_lists (BUT-1697 follow-up). Two distinct residual
  // classes, neither of which a plain `ownerId == uid` count could express:
  //
  //  1. the deleted uid still present as a `memberPermissions` MAP KEY — after
  //     the cascade that key is gone on every matched doc, whether the doc was
  //     scrubbed or deleted, so ANY hit here is a residual.
  //  2. a list still owned by the uid with NO other member left — an orphan no
  //     account can read. A list owned by the uid that OTHER members still
  //     share is the one justified residual (nulling `ownerId` would orphan it
  //     for them), so it must NOT count. That distinction is why this leg reads
  //     the docs instead of using `count()`.
  try {
    const keyed = await db
      .collection("unified_shared_shopping_lists")
      .where(`memberPermissions.${uid}`, "!=", null)
      .count()
      .get();
    const keyedCount = keyed.data().count ?? 0;
    if (keyedCount > 0) {
      residual += keyedCount;
      // uid_prefix, never the raw uid: Cloud Logging outlives the account, and
      // a per-user message string would destroy grouping on the one canary you
      // actually query. Same convention as request-account-deletion.ts.
      logger.warn(
        "[deletion-cascade] residual shared-list member keys",
        { uid_prefix: uid.slice(0, 6), count: keyedCount },
      );
    }

    const owned = await db
      .collection("unified_shared_shopping_lists")
      .where("ownerId", "==", uid)
      .get();
    const orphaned = owned.docs.filter((doc) => {
      const perms = (doc.data().memberPermissions ?? {}) as Record<
        string,
        unknown
      >;
      return !Object.keys(perms).some((k) => k !== uid);
    });
    if (orphaned.length > 0) {
      residual += orphaned.length;
      logger.warn(
        `[deletion-cascade] residual sole-member shared shopping lists: ${orphaned.length} docs`,
      );
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: unified_shared_shopping_lists",
      { err },
    );
  }

  // BUT-1705/BUT-1725: a removed member has no member key and owns nothing, so
  // the legs above are blind to exactly the case that leaves a name on the items
  // forever. These two count the handles the deleter now uses, and the deleter
  // clears both — keeping it a strict superset of the probe.
  //
  // Each leg carries its OWN try/catch, and they are APPENDED rather than
  // inserted: a leg dropped inside an existing `try` shortens every leg after
  // it, so one transient error on this query would silently skip the
  // sole-member-orphan scan above while the `residual += 1` masked the gap.
  for (const [field, query] of [
    [
      "contributorUserIds",
      db
        .collection("unified_shared_shopping_lists")
        .where("contributorUserIds", "array-contains", uid),
    ],
    [
      "lastActivityByUserId",
      db
        .collection("unified_shared_shopping_lists")
        .where("lastActivityByUserId", "==", uid),
    ],
  ] as const) {
    try {
      const snap = await query.count().get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn("[deletion-cascade] residual shared-list attribution", {
          uid_prefix: uid.slice(0, 6),
          field,
          count,
        });
      }
    } catch (err) {
      residual += 1;
      logger.error(
        "[deletion-cascade] residual probe failed: shared-list attribution",
        {
          uid_prefix: uid.slice(0, 6),
          field,
          errCode: (err as { code?: number | string }).code ?? null,
          errName: err instanceof Error ? err.name : typeof err,
        },
      );
    }
  }

  if (residual > 0 && !result.failedCollections.includes("residual_data_detected")) {
    result.failedCollections.push("residual_data_detected");
  }
}

/** Batch-delete every doc, chunked at `BATCH_LIMIT` (500) ops/batch. */
async function batchDeleteAll(
  db: admin.firestore.Firestore,
  docs: admin.firestore.QueryDocumentSnapshot[],
): Promise<void> {
  if (docs.length === 0) return;
  await commitInChunks(
    db,
    docs,
    (batch, doc) => batch.delete(doc.ref),
    { label: "batchDeleteAll", strict: false },
  );
}

// ─── Tier 1: own content ──────────────────────────────────────────────────

export async function deleteRecipes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const [sub, top] = await Promise.all([
    db.collection("users").doc(uid).collection("recipes").get(),
    db.collection("recipes").where("userId", "==", uid).get(),
  ]);
  await batchDeleteAll(db, [...sub.docs, ...top.docs]);
  return true;
}

export async function deleteMenus(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // Subcollection menus under users/{uid}
  const sub = await db.collection("users").doc(uid).collection("menus").get();
  await batchDeleteAll(db, sub.docs);

  // BUT-746: top-level shared menus owned by uid.
  const owned = await db
    .collection("menus")
    .where("sharedByUserId", "==", uid)
    .get();
  await batchDeleteAll(db, owned.docs);

  // BUT-747: scrub uid from sharedToUserIds on inbound menus.
  const inbound = await db
    .collection("menus")
    .where("sharedToUserIds", "array-contains", uid)
    .get();
  if (inbound.docs.length > 0) {
    await commitInChunks(
      db,
      inbound.docs,
      (batch, doc) => {
        batch.update(doc.ref, {
          sharedToUserIds: admin.firestore.FieldValue.arrayRemove(uid),
        });
      },
      { label: "scrubInboundMenus", strict: false },
    );
  }
  return true;
}

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
  await commitInChunks(
    db,
    items.docs,
    (batch, doc) => batch.delete(doc.ref),
    { label: "deletePersonalListItems", strict: true },
  );
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
  // `gdprCompliant: false` and running `admin/reset-user-data.ts`.
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
        .collection("unified_shared_shopping_lists")
        .where(`memberPermissions.${uid}`, "!=", null)
        .get(),
      db
        .collection("unified_shared_shopping_lists")
        .where("ownerId", "==", uid)
        .get(),
      db
        .collection("unified_shared_shopping_lists")
        .where("contributorUserIds", "array-contains", uid)
        .get(),
      db
        .collection("unified_shared_shopping_lists")
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

      // The raw uid also survives as the MAP KEY this query matched on, and
      // firestore.rules:1620-1626 still reads it as write authorization for an
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
    // human reads before running `admin/reset-user-data.ts`.
    throw new Error(
      `shopping-list erasure incomplete: ${failedItems} list(s) kept their ` +
        `items, ${failedShared.length} shared list(s) unscrubbed`,
    );
  }
  return true;
}

export async function deletePersonalTags(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("personal_tags")
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deletePersonalTagGroups(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("personal_tag_groups")
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteTagOverridesLog(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // BUT-1473: top-level, userId-keyed allergen tag-override corrections
  // (linked PII: userId, recipeId, tag, direction, triggeringIngredients).
  // No TTL, so GDPR Art. 17 needs an explicit cascade delete — analogous to
  // the other top-level userId-scoped own-data collections above.
  const snap = await db
    .collection("tag_overrides_log")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteCookSnaps(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("cook_snaps")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteActivityEvents(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("activity_events")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteWeeklyMenuPlans(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const owned = await db
    .collection("weekly_menu_plans")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, owned.docs);

  // Scrub uid from group plans. If a plan ends up empty, delete it.
  const groupPlans = await db
    .collection("group_weekly_menu_plans")
    .where("participantUserIds", "array-contains", uid)
    .get();
  if (groupPlans.docs.length > 0) {
    await commitInChunks(
      db,
      groupPlans.docs,
      (batch, doc) => {
        const data = doc.data();
        const participantsRaw = data.participants;
        const participants = Array.isArray(participantsRaw)
          ? participantsRaw
              .filter((m) => m && typeof m === "object")
              .map((m) => ({ ...(m as Record<string, unknown>) }))
              .filter((m) => m.userId !== uid)
          : [];
        const userIdsRaw = data.participantUserIds;
        const userIds = Array.isArray(userIdsRaw)
          ? (userIdsRaw as unknown[]).filter((id) => id !== uid)
          : [];
        if (userIds.length === 0) {
          batch.delete(doc.ref);
        } else {
          batch.update(doc.ref, {
            participants,
            participantUserIds: userIds,
            [`memberPermissions.${uid}`]: admin.firestore.FieldValue.delete(),
          });
        }
      },
      { label: "scrubGroupWeeklyMenuPlans", strict: false },
    );
  }
  return true;
}

export async function deletePantryItems(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("pantry")
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

/**
 * BUT family Phase 5 item 15 — family-rating data, with the §5b edge cases.
 *
 * A household is shared, so deletion is not a blanket wipe:
 *  - **Last member leaves** (no one remains after the user departs): delete the
 *    whole household — its diner profiles, ALL family ratings, and the household
 *    doc. Nothing is left orphaned.
 *  - **Other members remain:** remove the departing user from the household
 *    membership, delete only THEIR own verdicts (`memberId == uid`), **re-home**
 *    any diner profiles they created to a remaining member (never orphan a
 *    child profile — §5b), reassign `createdBy` if it was theirs, and scrub the
 *    proxy attribution (`enteredByUid`) on verdicts they entered for others so
 *    no rating points at a deleted user.
 *
 * The guardian-consent record on a re-homed profile is left historical (it
 * attests who actually consented). Parent-vs-parent custody disputes are out of
 * scope (§5b Condition 8 — Butlery is not the arbiter).
 *
 * Idempotent: re-running deletes the same own-verdicts, re-applies the same
 * membership scrub (arrayRemove/field delete), and re-homes already-re-homed
 * profiles to the same remaining member.
 */
export async function deleteFamilyData(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const households = await db
    .collection("households")
    .where("memberUserIds", "array-contains", uid)
    .get();

  for (const hhDoc of households.docs) {
    const data = hhDoc.data();
    const hid = hhDoc.id;
    const memberUserIds = Array.isArray(data.memberUserIds)
      ? (data.memberUserIds as unknown[]).filter((id) => typeof id === "string")
      : [];
    const remaining = (memberUserIds as string[]).filter((id) => id !== uid);

    if (remaining.length === 0) {
      // Sole member → tear the whole household down. Delete children with
      // strict:true so a failed chunk THROWS (→ family_data marked failed →
      // household doc NOT deleted → uid stays in memberUserIds → the retry
      // re-matches and re-attempts). Losing the household handle would strand
      // unreachable child PII, so here failing loudly beats partial cleanup.
      const [diners, allRatings] = await Promise.all([
        db.collection("diner_profiles").where("householdId", "==", hid).get(),
        db.collection("family_ratings").where("householdId", "==", hid).get(),
      ]);
      const childDocs = [...diners.docs, ...allRatings.docs];
      if (childDocs.length > 0) {
        await commitInChunks(
          db,
          childDocs,
          (batch, doc) => batch.delete(doc.ref),
          { label: "deleteFamilyHousehold", strict: true },
        );
      }
      await hhDoc.ref.delete();
      continue;
    }

    // Others remain. RETRY-SAFETY ORDERING: every child mutation below is keyed
    // on householdId + field equality (independent of uid's array membership),
    // so it re-runs cleanly on retry — AS LONG AS the household membership scrub
    // (which removes uid from the re-entry query) is the LAST mutation. Do not
    // reorder the household update above the child cleanup.

    // 1. Delete only the departing user's own verdicts.
    const ownRatings = await db
      .collection("family_ratings")
      .where("householdId", "==", hid)
      .where("memberId", "==", uid)
      .get();
    await batchDeleteAll(db, ownRatings.docs);

    // 2. Re-home diner profiles the departing user created (never orphan — §5b).
    const myDiners = await db
      .collection("diner_profiles")
      .where("householdId", "==", hid)
      .where("createdBy", "==", uid)
      .get();
    if (myDiners.docs.length > 0) {
      await commitInChunks(
        db,
        myDiners.docs,
        (batch, doc) => batch.update(doc.ref, { createdBy: remaining[0] }),
        { label: "rehomeDinerProfiles", strict: false },
      );
    }

    // 3. Scrub proxy attribution on verdicts they entered FOR OTHER members so
    // no rating is left pointing at a deleted user (own verdicts already gone).
    const enteredByMe = await db
      .collection("family_ratings")
      .where("householdId", "==", hid)
      .where("enteredByUid", "==", uid)
      .get();
    const proxyForOthers = enteredByMe.docs.filter(
      (d) => d.data().memberId !== uid,
    );
    if (proxyForOthers.length > 0) {
      await commitInChunks(
        db,
        proxyForOthers,
        (batch, doc) => batch.update(doc.ref, { enteredByUid: "deleted" }),
        { label: "scrubProxyAttribution", strict: false },
      );
    }

    // 4. LAST: remove them from the household; re-point createdBy if theirs.
    // This is the only mutation that changes the re-entry query, so it runs
    // after all child cleanup — a transient failure above leaves uid in
    // memberUserIds and the retry re-discovers everything.
    const members = Array.isArray(data.members)
      ? (data.members as unknown[])
          .filter((m) => m && typeof m === "object")
          .map((m) => ({ ...(m as Record<string, unknown>) }))
          .filter((m) => m.userId !== uid)
      : [];
    const newCreatedBy = data.createdBy === uid ? remaining[0] : data.createdBy;
    await hhDoc.ref.update({
      members,
      memberUserIds: admin.firestore.FieldValue.arrayRemove(uid),
      [`memberPermissions.${uid}`]: admin.firestore.FieldValue.delete(),
      createdBy: newCreatedBy,
    });
  }
  return true;
}

// ─── Tier 1: social-self (own writes on cross-user surfaces) ─────────────

export async function deleteMessages(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const convos = await db
    .collection("conversations")
    .where("participantIds", "array-contains", uid)
    .get();

  // Bounded parallelism: 10 conversations / wave. Mirrors prior client behavior.
  const chunkSize = 10;
  for (let i = 0; i < convos.docs.length; i += chunkSize) {
    const chunk = convos.docs.slice(i, i + chunkSize);
    await Promise.all(
      chunk.map(async (convoDoc) => {
        const messages = await convoDoc.ref.collection("messages").get();
        await batchDeleteAll(db, messages.docs);
        const participants = Array.isArray(convoDoc.data().participantIds)
          ? (convoDoc.data().participantIds as string[])
          : [];
        if (participants.length <= 2) {
          await convoDoc.ref.delete();
        } else {
          await convoDoc.ref.update({
            participantIds: admin.firestore.FieldValue.arrayRemove(uid),
          });
        }
      }),
    );
  }
  return true;
}

export async function removeFromSharedContent(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const [members, engagements] = await Promise.all([
    db.collectionGroup("members").where("userId", "==", uid).get(),
    db.collectionGroup("engagements").where("userId", "==", uid).get(),
  ]);

  // Scrub sharedToUserIds on each parent shared_content doc.
  if (members.docs.length > 0) {
    await commitInChunks(
      db,
      members.docs,
      (batch, doc) => {
        const parentRef = doc.ref.parent.parent;
        if (parentRef) {
          batch.update(parentRef, {
            sharedToUserIds: admin.firestore.FieldValue.arrayRemove(uid),
          });
        }
      },
      { label: "scrubSharedToUserIds", strict: false },
    );
  }
  await batchDeleteAll(db, members.docs);
  await batchDeleteAll(db, engagements.docs);

  // Delete shared_content owned by uid (members subcollection first).
  const owned = await db
    .collection("shared_content")
    .where("sharedByUserId", "==", uid)
    .get();
  for (const doc of owned.docs) {
    const childMembers = await doc.ref.collection("members").get();
    await batchDeleteAll(db, childMembers.docs);
  }
  await batchDeleteAll(db, owned.docs);
  return true;
}

export async function deleteCommentsAndRatings(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // recipe_comments: anonymize to preserve thread structure.
  const recipeComments = await db
    .collection("recipe_comments")
    .where("authorId", "==", uid)
    .get();
  if (recipeComments.docs.length > 0) {
    await commitInChunks(
      db,
      recipeComments.docs,
      (batch, doc) => {
        batch.update(doc.ref, {
          authorId: "deleted",
          authorDisplayName: "[Raderad användare]",
          authorAvatarUrl: null,
          isDeleted: true,
          text: "[Borttagen kommentar]",
        });
      },
      { label: "anonymizeRecipeComments", strict: false },
    );
  }

  // Hard-delete ratings + collectionGroup comments/ratings.
  const [recipeRatings, cgComments, cgRatings] = await Promise.all([
    db.collection("recipe_ratings").where("userId", "==", uid).get(),
    db.collectionGroup("comments").where("commentedBy", "==", uid).get(),
    db.collectionGroup("ratings").where("ratedBy", "==", uid).get(),
  ]);
  await batchDeleteAll(db, [
    ...recipeRatings.docs,
    ...cgComments.docs,
    ...cgRatings.docs,
  ]);
  return true;
}

export async function deletePingsByUser(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collectionGroup("pings")
    .where("fromUserId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteUserReports(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("reports")
    .where("reporterId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

// ─── Tier 1: profile-side own data ───────────────────────────────────────

export async function deleteFcmTokens(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("user_fcm_tokens")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteNotificationPreferences(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // Doc id is the user id per FirebaseNotificationsRepository convention.
  await db.collection("user_notification_preferences").doc(uid).delete();
  return true;
}

export async function deleteNotifications(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("user_notifications")
    .where("userId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteNotificationAnalytics(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const [history, batches, engagement, deliverySender, deliveryTarget] =
    await Promise.all([
      db.collection("notification_history").where("userId", "==", uid).get(),
      db.collection("notification_batches").where("userId", "==", uid).get(),
      db
        .collection("notification_engagement")
        .where("userId", "==", uid)
        .get(),
      db.collection("notification_delivery").where("senderId", "==", uid).get(),
      db
        .collection("notification_delivery")
        .where("targetUserId", "==", uid)
        .get(),
    ]);
  await batchDeleteAll(db, [
    ...history.docs,
    ...batches.docs,
    ...engagement.docs,
    ...deliverySender.docs,
    ...deliveryTarget.docs,
  ]);
  return true;
}

export async function deleteRealtimeRecipes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // BUT-1396 follow-up: the owner field on `realtime_recipes` is `ownerId`
  // (the model writes it, the Firestore rule gates read/delete on it). The
  // prior `userId` filter matched zero docs, so a deleted user's collaborative
  // recipes were exported (Art. 15) but never erased (Art. 17). Filter on
  // `ownerId` so deletion mirrors the export.
  const snap = await db
    .collection("realtime_recipes")
    .where("ownerId", "==", uid)
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

// ─── Tier 2: user subcollections ─────────────────────────────────────────

export async function deleteUserPreferences(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  await db
    .collection("users")
    .doc(uid)
    .collection("settings")
    .doc("preferences")
    .delete();
  return true;
}

export async function deleteConsentRecords(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("users")
    .doc(uid)
    .collection("consent")
    .get();
  await batchDeleteAll(db, snap.docs);
  return true;
}

export async function deleteUserSubcollections(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const userDoc = db.collection("users").doc(uid);
  // `notificationCounters` + `recentContentHashes` are intentionally NOT
  // included — `onUserDeleted` (cleanupContentGuardSubcollections) owns
  // those and runs automatically after `admin.auth().deleteUser(uid)`.
  const subs = [
    "conversation_memberships",
    "user_shared_menus",
    "user_shared_shopping_lists",
    "friend_categories",
    "friends",
    "category_preferences",
    "list_category_orders",
    "report_throttle",
    // Pooled ratings (decision 12): the user's frozen pool events. Each delete
    // fires the Stage-B trigger (onPooledRatingEventWritten), which recomputes
    // the affected pool's canonical_recipe_stats — so erasing the rater also
    // shrinks the public averages they contributed to, with no explicit
    // recompute call (the established trigger separation).
    "canonical_rating_events",
  ];
  for (const name of subs) {
    const snap = await userDoc.collection(name).get();
    await batchDeleteAll(db, snap.docs);
  }

  // BUT-1390: rate-limit buckets live at the TOP-LEVEL `system_rate_limits`
  // collection (doc id `${uid}_${operation}`), not a user subcollection — the
  // former `users/{uid}/rate_limits` entry above deleted nothing. Erase them
  // explicitly for GDPR completeness via a documentId prefix range:
  //   startAt(`${uid}_`) .. endAt(`${uid}_`)
  // The upper bound's trailing  is a high-codepoint sentinel that is
  // INVISIBLE in most editors/diff viewers — it is load-bearing: WITHOUT it the
  // range collapses to the single (nonexistent) id `${uid}_` and erases nothing.
  // Do not "tidy" it away. The `_` separator additionally prevents matching a
  // different user whose uid is a prefix of this one. No field filter/index needed.
  const rlSnap = await db
    .collection("system_rate_limits")
    .orderBy(admin.firestore.FieldPath.documentId())
    .startAt(`${uid}_`)
    .endAt(`${uid}_`)
    .get();
  await batchDeleteAll(db, rlSnap.docs);

  return true;
}

// ─── Tier 3: user root doc ───────────────────────────────────────────────

export async function deleteUserProfile(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  await db.collection("users").doc(uid).delete();
  return true;
}
