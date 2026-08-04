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
  // BUT-1766/BUT-1768: more collections whose owner handle is NOT `userId`, so
  // the loop above is structurally blind to them. Each pair is exactly what the
  // matching deleter now clears, keeping the deleter a strict superset of the
  // probe:
  //   messages.senderId          — anonymized (or deleted with a 1:1 thread)
  //   realtime_menus/recipes.ownerId       — deleted, subcollections included
  //   realtime_menus/recipes.lastEditedBy  — anonymized
  //   realtime_menus/recipes.participantIds — membership dropped on docs the
  //                                           user does not own
  //   conversations.participantIds — 1:1 deleted, group departed
  // `messages` is the highest-value leg here: the collection this probe could
  // not see is the one the cascade never touched for two years. The
  // `participantIds` legs are the only map-shaped residual Firestore can
  // actually query — a uid used as a MAP KEY (`participants.<uid>`,
  // `perUserSettings.<uid>`, a `votes` map entry) is unqueryable, so those are
  // covered by the deleter and by the emulator lane, never by a count here.
  for (const [col, field, op] of [
    [Collections.messages, "senderId", "=="],
    // BUT-1788: system rows ABOUT the user, authored by "system", so the
    // senderId leg above is structurally blind to them.
    [Collections.messages, "metadata.subjectUserId", "=="],
    [Collections.realtimeMenus, "ownerId", "=="],
    [Collections.realtimeMenus, "lastEditedBy", "=="],
    [Collections.realtimeMenus, "participantIds", "array-contains"],
    [Collections.realtimeRecipes, "ownerId", "=="],
    [Collections.realtimeRecipes, "lastEditedBy", "=="],
    [Collections.realtimeRecipes, "participantIds", "array-contains"],
    [Collections.conversations, "participantIds", "array-contains"],
    // BUT-1798: shared_content membership. The scrub above is the only thing
    // that clears this, and it was blind to ad-hoc shares for the collection's
    // entire life — so this probe is what stops that ever being invisible
    // again. Single-field array-contains is served by the automatic index; no
    // composite entry needed.
    ["shared_content", "sharedToUserIds", "array-contains"],
  ] as const) {
    try {
      const snap = await db
        .collection(col)
        .where(field, op, uid)
        .count()
        .get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn("[deletion-cascade] residual owner-keyed docs", {
          uid_prefix: uid.slice(0, 6),
          collection: col,
          field,
          count,
        });
      }
    } catch (err) {
      residual += 1;
      logger.error("[deletion-cascade] residual probe failed", {
        uid_prefix: uid.slice(0, 6),
        collection: col,
        field,
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
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

  // BUT-1789: the feature-retention rows. A SUBCOLLECTION under an analytics
  // document, so neither the top-level `userId` loop at the head of this
  // function nor the `users/{uid}/...` loop above can reach it — both are
  // structurally blind to `analytics/feature_retention/users`. Same handle the
  // deleter uses, keeping the deleter a strict superset of the probe. Appended
  // rather than folded into an existing `try`, for the reason the block above
  // states: a leg sharing another leg's catch shortens every leg after it.
  try {
    const snap = await db
      .collection("analytics")
      .doc("feature_retention")
      .collection("users")
      .where("userId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual feature-retention rows", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: feature_retention",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
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

/**
 * BUT-1789: the per-user-per-day feature-retention rows written by
 * `analytics/compute-feature-retention.ts`.
 *
 * `analytics/feature_retention/users/{uid}_{yyyy-mm-dd}` is one document PER
 * ACTIVE DAY, carrying the uid in the id, in a `userId` field, and a behavioural
 * profile of that person's day (did they cook, import, share, meal-plan, shop).
 * Nothing deleted them: no cascade step, no TTL, and no accepted-deviation entry
 * saying that was on purpose — so an account erased under Article 17 left a
 * dated row for every day it was ever active, indefinitely.
 *
 * A TTL is NOT the alternative here, and the reason is worth stating so it is
 * not "simplified" into one later: these rows live in the SUBCOLLECTION
 * `analytics/feature_retention/users`, whose collectionGroup id is `users` —
 * the same id as the top-level profile collection. A TTL fieldOverride on
 * collectionGroup `users` would arm a delete policy over real user documents.
 *
 * The filter is the writer's own `userId` field rather than a documentId prefix
 * range: the writer sets it on every row (`batch.set({ userId, date, ...})`),
 * and a single-field equality needs no composite index. The id-prefix form
 * would work too but depends on the `{uid}_{date}` id convention holding
 * forever, which is a weaker handle than the field the writer is contractually
 * writing.
 *
 * The `daily/{date}` aggregates are deliberately NOT touched — integer counts,
 * no uid, no re-derivation on erasure. That residual is the accepted deviation
 * recorded for BUT-1789.
 */
export async function deleteFeatureRetentionFlags(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collection("analytics")
    .doc("feature_retention")
    .collection("users")
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

/**
 * BUT-1766: chat messages live in the TOP-LEVEL `messages` collection, keyed by
 * a `conversationId` FIELD — `firestore.rules` grants `match /messages/{id}`
 * and nothing else, and the client writes there
 * (`FirebaseMessagingRepository._messagesRef`). The
 * `conversations/{id}/messages` SUBCOLLECTION this step used to sweep has no
 * rule block, no writer and therefore no documents: every account erased since
 * BUT-788 kept its entire chat history while the cascade reported `messages`
 * deleted. A path with no `match` block is denied, not merely undocumented.
 *
 * Three legs, in this order for a reason:
 *
 *  1. **Own messages anywhere** (`senderId == uid`) are ANONYMIZED in place —
 *     identity fields replaced and the content tombstoned, the same treatment
 *     `deleteCommentsAndRatings` gives `recipe_comments`. Membership is NOT the
 *     handle: a user who left a group keeps every message they wrote in it
 *     (the BUT-1725 lesson), and `senderId` is the only field that finds those.
 *     Anonymizing rather than deleting preserves the thread other members keep
 *     — `Message.replyToMessageId` points at ids that would otherwise dangle —
 *     while erasing the personal data (name, avatar, content, uid).
 *  2. **1:1 conversations** (≤2 participants) are deleted whole, and with them
 *     EVERY message on that `conversationId`, both directions. The read rule
 *     resolves participation through `get(conversations/$(conversationId))`, so
 *     once the conversation doc is gone no client can read those messages and
 *     no later erasure can find them — leaving them would strand unreachable
 *     PII forever. Running after leg 1 also means no `update` can hit a doc
 *     this leg already deleted.
 *  3. **Group conversations** keep running for the remaining members; the user
 *     leaves AND their per-user carriers on the conversation DOCUMENT go with
 *     them. Anonymizing the message rows is not enough on its own:
 *     `ConversationDto.toFirestore` denormalises `participantDisplayNames`,
 *     `participantAvatarUrls`, `lastReadTimestamps` and `perUserSettings` as
 *     uid-keyed maps, plus a full `lastMessage` copy (sender uid, name, avatar
 *     URL and content). Every remaining member reads that document — the
 *     conversations read rule is participant-gated — and nothing renames or
 *     erases it once the account is gone, because `on-profile-updated.ts`
 *     stops firing. `participantDisplayNames` / `participantAvatarUrls` are
 *     precisely the two fields that propagator maintains, i.e. the rename CF is
 *     the inventory and this collection is on it. Shape mirrors
 *     `enforce-group-minor-membership.ts`, which already removes three of the
 *     four in one `update()`.
 */
/** The one tombstone string every message-content erasure writes. */
const MESSAGE_TOMBSTONE = "[Borttaget meddelande]";

export async function deleteMessages(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const own = await db
    .collection(Collections.messages)
    .where("senderId", "==", uid)
    .get();
  if (own.docs.length > 0) {
    await commitInChunks(
      db,
      own.docs,
      (batch, doc) => {
        batch.update(doc.ref, {
          senderId: "deleted",
          senderDisplayName: "[Raderad användare]",
          senderAvatarUrl: null,
          content: MESSAGE_TOMBSTONE,
        });
      },
      { label: "anonymizeOwnMessages", strict: false },
    );
  }

  await anonymizeSystemMessagesAboutUser(db, uid);

  const convos = await db
    .collection(Collections.conversations)
    .where("participantIds", "array-contains", uid)
    .get();

  // Bounded parallelism: 10 conversations / wave. Mirrors prior client behavior.
  const chunkSize = 10;
  for (let i = 0; i < convos.docs.length; i += chunkSize) {
    const chunk = convos.docs.slice(i, i + chunkSize);
    await Promise.all(
      chunk.map(async (convoDoc) => {
        const participants = Array.isArray(convoDoc.data().participantIds)
          ? (convoDoc.data().participantIds as string[])
          : [];
        if (participants.length <= 2) {
          const thread = await db
            .collection(Collections.messages)
            .where("conversationId", "==", convoDoc.id)
            .get();
          await batchDeleteAll(db, thread.docs);
          await convoDoc.ref.delete();
        } else {
          // Transactional re-read: the outer query snapshot can be stale by
          // the time this specific doc's write runs, and a group chat is
          // exactly where a NEW message between query and write is likely. A
          // blind update() would stamp the tombstone from the stale snapshot
          // and silently overwrite that new message's lastMessage copy back
          // to "[Raderad användare]".
          await db.runTransaction(async (tx) => {
            const fresh = await tx.get(convoDoc.ref);
            if (!fresh.exists) return;
            tx.update(convoDoc.ref, buildGroupDepartureUpdate(fresh, uid));
          });
        }
      }),
    );
  }
  return true;
}

/**
 * BUT-1788: erase the user's name from SYSTEM rows written ABOUT them.
 *
 * `leaveGroupConversation` writes "<Name> har lämnat gruppen" under
 * `senderId: "system"`. Three separate things make that row invisible to every
 * other leg of this cascade:
 *
 *  1. the `senderId == uid` query above cannot match it — the author is
 *     "system";
 *  2. `buildGroupDepartureUpdate` only tombstones `lastMessage` when the
 *     departing user is its SENDER, and here they are its subject;
 *  3. once the person has left, the `participantIds array-contains uid` query
 *     below never returns that conversation at all, so the cascade does not
 *     even visit it.
 *
 * The writer therefore stamps `metadata.subjectUserId`, which is the only
 * queryable handle on a name embedded in free text. Equality on a nested field
 * is served by the automatic single-field index — no declaration needed.
 *
 * Both copies are rewritten: the `messages` row and the denormalised
 * `conversations/{id}.lastMessage.content` that `syncConversationLastMessage`
 * made of it. The mirror goes FIRST and the handle is cleared LAST, only for
 * rows whose mirror write succeeded — see the ordering note inline. Once a row
 * is fully scrubbed its handle is gone, so `probeResidualData` reads zero and a
 * re-run is a no-op.
 */
export async function anonymizeSystemMessagesAboutUser(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<void> {
  const about = await db
    .collection(Collections.messages)
    .where("metadata.subjectUserId", "==", uid)
    .get();
  if (about.docs.length === 0) return;

  // conversationId -> the exact contents the mirror may still be holding.
  const mirrored = new Map<string, Set<string>>();
  for (const doc of about.docs) {
    const data = doc.data() ?? {};
    const convoId = typeof data.conversationId === "string"
      ? data.conversationId
      : null;
    const content = typeof data.content === "string" ? data.content : null;
    if (!convoId || !content) continue;
    const bucket = mirrored.get(convoId) ?? new Set<string>();
    bucket.add(content);
    mirrored.set(convoId, bucket);
  }

  // MIRROR FIRST. `metadata.subjectUserId` is the only handle that finds these
  // rows again, and the mirror scrub below is best-effort: its failure is
  // swallowed so one contended conversation cannot abort the erasure. Clearing
  // the handle before that write would make a swallowed failure permanent —
  // a re-run early-exits at the empty query above, `probeResidualData` (keyed
  // on the same field) reads zero and certifies a clean erasure, and the
  // deleted user's display name stays in the group preview for every remaining
  // member. Nothing heals it later: syncConversationLastMessage triggers on
  // message create/delete, never on update.
  //
  // Transactional re-read per conversation: a newer message may have replaced
  // the preview between the query and this write, and blindly stamping the
  // tombstone would erase THAT message's copy instead.
  const convoIds = [...mirrored.keys()];
  const failedConvos = new Set<string>();
  const chunkSize = 10;
  for (let i = 0; i < convoIds.length; i += chunkSize) {
    await Promise.all(
      convoIds.slice(i, i + chunkSize).map(async (convoId) => {
        const ref = db.collection(Collections.conversations).doc(convoId);
        try {
          await db.runTransaction(async (tx) => {
            const fresh = await tx.get(ref);
            if (!fresh.exists) return;
            const last = (fresh.data() ?? {}).lastMessage as
              | Record<string, unknown>
              | undefined;
            if (!last || last.senderId !== "system") return;
            if (typeof last.content !== "string") return;
            if (!mirrored.get(convoId)?.has(last.content)) return;
            tx.update(ref, { "lastMessage.content": MESSAGE_TOMBSTONE });
          });
        } catch (err) {
          failedConvos.add(convoId);
          // An Error nested in a structured-log payload serialises to `{}`, so
          // `err` recorded nothing at all. Same shape as the probe legs above.
          logger.error("[deletion-cascade] system lastMessage scrub failed", {
            conversationId: convoId,
            errCode: (err as { code?: number | string }).code ?? null,
            errName: err instanceof Error ? err.name : typeof err,
          });
        }
      }),
    );
  }

  // Handle-clearing write LAST, and skipped for any conversation whose mirror
  // scrub failed — the surviving `metadata.subjectUserId` is what lets a re-run
  // and probeResidualData find the rest. Retry semantics: a skipped row keeps
  // BOTH its handle and its original content, so the next run rebuilds the same
  // content match and scrubs the mirror it missed. A row that succeeded is gone
  // from the query entirely, so a full-success re-run is a plain no-op.
  const clearable = about.docs.filter((doc) => {
    const convoId = (doc.data() ?? {}).conversationId;
    return typeof convoId !== "string" || !failedConvos.has(convoId);
  });
  await commitInChunks(
    db,
    clearable,
    (batch, doc) => {
      batch.update(doc.ref, {
        content: MESSAGE_TOMBSTONE,
        "metadata.subjectUserId": admin.firestore.FieldValue.delete(),
      });
    },
    { label: "anonymizeSystemMessagesAboutUser", strict: false },
  );
}

/**
 * The single `update()` that removes a departing user from a SURVIVING group
 * conversation document.
 *
 * One write, not five: a group thread can be large, and the four map-key
 * deletions plus the `lastMessage` tombstone are one logical erasure — a
 * partial application would leave a name on a document the probe cannot see.
 *
 * `lastMessage` is a denormalised COPY of the last message row, so anonymizing
 * the row in `messages` does not touch it. It is rewritten to the same
 * tombstone that row gets, and only when the departing user is its sender.
 */
function buildGroupDepartureUpdate(
  convoDoc: admin.firestore.DocumentSnapshot,
  uid: string,
): Record<string, unknown> {
  const update: Record<string, unknown> = {
    participantIds: admin.firestore.FieldValue.arrayRemove(uid),
  };
  for (const map of PER_USER_CONVERSATION_MAPS) {
    update[`${map}.${uid}`] = admin.firestore.FieldValue.delete();
  }

  const last = (convoDoc.data() ?? {}).lastMessage as
    | Record<string, unknown>
    | undefined;
  if (last && last.senderId === uid) {
    update["lastMessage.senderId"] = "deleted";
    update["lastMessage.senderDisplayName"] = "[Raderad användare]";
    update["lastMessage.senderAvatarUrl"] = null;
    update["lastMessage.content"] = MESSAGE_TOMBSTONE;
  }
  return update;
}

/**
 * The uid-keyed maps `ConversationDto.toFirestore` writes onto a conversation
 * document. `perUserSettings` carries the departing user's mute/pin/archive
 * state, which is theirs and has no purpose once the account is gone —
 * `enforce-group-minor-membership.ts` does not yet clear it, and should.
 */
const PER_USER_CONVERSATION_MAPS = [
  "participantDisplayNames",
  "participantAvatarUrls",
  "lastReadTimestamps",
  "perUserSettings",
] as const;

export async function removeFromSharedContent(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const [members, engagements] = await Promise.all([
    db.collectionGroup("members").where("userId", "==", uid).get(),
    db.collectionGroup("engagements").where("userId", "==", uid).get(),
  ]);

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

  // BUT-1798 — the members-subcollection scrub above reaches ONLY content shared
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
  // The admin SDK bypasses rules, so this predicate is the only access control
  // on the read — keep it scoped to shared_content and to this exact field.
  const membershipSnap = await db
    .collection("shared_content")
    .where("sharedToUserIds", "array-contains", uid)
    .get();

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
    .collection(Collections.realtimeRecipes)
    .where("ownerId", "==", uid)
    .get();
  await deleteRealtimeDocsWithChildren(db, snap.docs);

  // BUT-1768: the same last-editor pair the menus step scrubs. Deleting only
  // the recipes the user OWNS leaves their name on every collaborative recipe
  // they last touched but do not own.
  await scrubLastEditor(db, Collections.realtimeRecipes, uid);
  await removeRealtimeParticipation(db, Collections.realtimeRecipes, uid);
  return true;
}

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
 * Strip `votes.<uid>` from every vote document under menus the user took part
 * in but does not own.
 *
 * `realtime_menus/{menuId}/votes/{voteId}` is NOT uid-keyed by document id
 * despite what the rules comment suggests: the doc id is the slot's vote id and
 * the ballot is a MAP, `votes: {userId -> optionId}`, written by
 * `FirebaseMenuVotingRepository.castVote` as `votes.$userId`. So the deleted
 * user's uid survives one level below the document the participation sweep
 * cleans, on a menu that continues to exist for its owner.
 *
 * Scoped to the menus the participation sweep just found, which is the only
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
 * `/votes/{voteId}`, and `realtime_recipes/{id}/presence/{uid}`. Both are
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
