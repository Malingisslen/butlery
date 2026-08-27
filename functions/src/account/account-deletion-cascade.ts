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
// Deliberate cross-domain import (BUT-1822). `tryClearRoster` lives in a
// minor-safety TRIGGER module, but it is the one roster clearer: bounded,
// never-throwing, and it answers the exact question this cascade must ask before
// it deletes a conversation. A second implementation here would be a second
// contract to keep in sync on a GDPR path. Extraction into a neutral module is
// tracked separately; until then, that function's docstring names this caller.
import {
  logSafeConversationId,
  tryClearRoster,
} from "../messaging/enforce-group-minor-membership";
// BUT-1838: the single writer of chat-group membership. Imported rather than
// re-implemented for the same reason as `tryClearRoster` above — a second
// spelling of "remove this member" on a GDPR path is a contract to keep in sync,
// and this one touches three documents.
import { stageMemberRemoval } from "../groups/chat-group-writes";

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
    result.errors.push(
      `${name}: ${err instanceof Error ? err.message : String(err)}`,
    );
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
  // `recipes` is NOT in this list, and must never be added back. These probes are
  // top-level collections filtered by a `userId` FIELD; recipes live in the
  // subcollection `users/{uid}/recipes` and are probed separately below. Reading
  // them here counted a collection with no documents, so the probe returned zero
  // on every deletion — an all-clear that was true by accident and would have
  // stayed true if `deleteRecipes` ever stopped working. Exactly the failure the
  // comment further down calls "the realtime_recipes wrong-field trap" (BUT-1801).
  const probes = [
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
  // BUT-1801: recipes are a SUBCOLLECTION, so they need a path-scoped probe
  // rather than a userId-field filter. Counted directly under the user document:
  // no index is required for a bare `count()`, and it makes no assumption about
  // recipe documents carrying a top-level `userId` field (they are not known to).
  // A `collectionGroup("recipes").where("userId","==",uid)` probe would need both
  // — a COLLECTION_GROUP index this repo does not declare for that field, and the
  // field itself — and would fail the same silent way the top-level read did.
  try {
    const snap = await db
      .collection("users")
      .doc(uid)
      .collection("recipes")
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn(`[deletion-cascade] residual in recipes: ${count} docs`);
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: recipes", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  // BUT-1801: poll VOTES. `deletePollVotes` deletes through `batchDeleteAll` →
  // `commitInChunks(strict:false)`, which catches a whole failed chunk and still
  // lets the step report success; only the CAP can falsify it. So a single
  // failed commit can leave up to 500 rows whose DOCUMENT ID is the erased uid,
  // with the step reporting a clean erasure. This leg is the only thing that
  // contradicts it. Uncapped and separate for the same reason as the roster leg
  // below: `count()` is cheap, and it must stay loud exactly when the deleter
  // DECLINED. It also fails CLOSED while the collection-group index builds —
  // FAILED_PRECONDITION lands in the catch as a false alarm, never a false
  // all-clear.
  try {
    const snap = await db
      .collectionGroup(Collections.pollVotes)
      .where("voterId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual poll votes", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: poll_votes", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
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
  // The conversation ROSTER rows (`conversations/{id}/participants/{uid}`) are on
  // the same inventory but cannot be probed from this loop at all — they need a
  // collection-group query, so their leg is appended at the end of this function.
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
    // BUT-1838: chat-group membership. Every other leg in this file is paired
    // with a probe, and a leg without one is exactly how an erasure becomes
    // silently incomplete — so this line ships in the same edit as its deleter.
    [Collections.chatGroups, "memberIds", "array-contains"],
    // BUT-1856: two more owner handles on the same document that the membership
    // leg above is structurally blind to. `departedUserIds` holds people who are
    // no longer in `memberIds` by definition; `sourceCategoryOwnerId` names the
    // owner of the social group a meal-vote chat was built from, and survives
    // them leaving it. Each ships with its deleter, per the rule this list
    // states above.
    [Collections.chatGroups, "departedUserIds", "array-contains"],
    [Collections.chatGroups, "sourceCategoryOwnerId", "=="],
    // BUT-1798: shared_content membership. The scrub above is the only thing
    // that clears this, and it was blind to ad-hoc shares for the collection's
    // entire life — so this probe is what stops that ever being invisible
    // again. Single-field array-contains is served by the automatic index; no
    // composite entry needed.
    ["shared_content", "sharedToUserIds", "array-contains"],
    // BUT-1801: poll AUTHORSHIP. `deletePollVotes` rewrites this field to
    // "deleted" and REPORTS ON ITSELF — it decides its own `complete` flag. This
    // row is the independent check on that self-report, which is the whole point
    // of a probe: it also sees a document written or re-written after the scrub
    // passed over it, which the scrub by construction cannot. The
    // `metadata.subjectUserId` entry earlier in this same list proves a nested
    // equality filter needs no declared index.
    [Collections.messages, "metadata.poll.creatorId", "=="],
  ] as const) {
    try {
      const snap = await db.collection(col).where(field, op, uid).count().get();
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
      logger.warn("[deletion-cascade] residual shared-list member keys", {
        uid_prefix: uid.slice(0, 6),
        count: keyedCount,
      });
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

  // BUT-1800: probed on the same handle the deleter uses, and over the SAME
  // list, so the deleter stays a strict superset of the probe. Each
  // parent gets its OWN `try` for the reason the blocks above state — a leg
  // sharing another leg's catch shortens every leg after it, and here that
  // would let a failure on `retention` hide whatever `lapsed_users` holds.
  for (const parent of RETENTION_ANALYTICS_PARENTS) {
    try {
      const snap = await db
        .collection("analytics")
        .doc(parent)
        .collection("events")
        .where("userId", "==", uid)
        .count()
        .get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn("[deletion-cascade] residual analytics rows", {
          uid_prefix: uid.slice(0, 6),
          parent,
          count,
        });
      }
    } catch (err) {
      residual += 1;
      logger.error("[deletion-cascade] residual probe failed: analytics", {
        uid_prefix: uid.slice(0, 6),
        parent,
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }

  // BUT-1822: the conversation roster rows. A SUBCOLLECTION, so neither the
  // top-level loops at the head of this function nor the `users/{uid}/...` loop
  // can express it — only a collection-group query can, and the loops above are
  // all `db.collection(...)`. Same handle `deleteOwnRosterRows` uses, keeping the
  // deleter a strict superset of the probe. Appended rather than folded into an
  // existing `try`, for the reason the blocks above state.
  //
  // Uncapped on purpose, unlike the deleter: `count()` is cheap, and this is the
  // leg that must stay loud when the deleter DECLINES an implausible row count.
  // It also fails CLOSED while the collection-group index is still building —
  // FAILED_PRECONDITION lands in the catch as `residual += 1`, a false alarm
  // rather than a false all-clear. Do not "simplify" that into a silent swallow.
  try {
    const snap = await db
      .collectionGroup(Collections.participants)
      .where("participantId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual conversation roster rows", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: conversation participants",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }

  if (
    residual > 0 &&
    !result.failedCollections.includes("residual_data_detected")
  ) {
    result.failedCollections.push("residual_data_detected");
  }
}

/** Batch-delete every doc, chunked at `BATCH_LIMIT` (500) ops/batch. */
async function batchDeleteAll(
  db: admin.firestore.Firestore,
  docs: admin.firestore.QueryDocumentSnapshot[],
): Promise<void> {
  if (docs.length === 0) return;
  await commitInChunks(db, docs, (batch, doc) => batch.delete(doc.ref), {
    label: "batchDeleteAll",
    strict: false,
  });
}

// ─── Tier 1: own content ──────────────────────────────────────────────────

// The SUBCOLLECTION read is what erases a real user's recipes: `users/{uid}/recipes`
// is the only shape any production writer uses. Every `FirestoreCollections.recipes`
// site in `lib/` that BUILDS A PATH is user-scoped — the repository's
// `collectionName` under `UserScopedFirebaseRepository`,
// `firestore_repository.userRecipesCollection`, `family_rating_service` and
// `rating_statistics`. The remaining site, `recipe_stats_repository`, is a
// `collectionGroup` READ and builds no path at all. (Stated as a property rather
// than a tally: an earlier version said "all three sites", which was wrong when
// written and would have gone stale by addition anyway.)
//
// The top-level read beside it finds nothing IN PRODUCTION — no client can write
// that collection, since the only rule reaching it is an admin-only, read-only
// collection-group catch-all — so it returns an empty snapshot on every real
// deletion.
//
// BUT-1801 removed it as dead weight and that was WRONG, twice over. It is
// exercised: `request-account-deletion.integration.test.ts` plants a top-level
// `recipes` doc through the Admin SDK and asserts the cascade deletes it, and
// that suite runs in CI. And an Admin-SDK writer needs no rule, so "no client
// can write it" was never the same claim as "nothing can be there". Erasure is
// the wrong place to trade defence-in-depth for one saved query.
//
// What BUT-1801 genuinely fixed is one layer down: the same top-level path had
// been copied into `probeResidualData`, where an empty result is
// indistinguishable from a clean one — a permanent all-clear that never looked
// at a recipe. The probe now counts the subcollection. Deleter stays a superset
// of the probe, which is the invariant that matters.
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

/**
 * The `analytics/{parent}/events` collections this cascade sweeps. ONE list:
 * the deleter and `probeResidualData`'s matching leg both read it, and a probe
 * that ranges over fewer parents than its deleter certifies a bad erasure clean.
 */
export const RETENTION_ANALYTICS_PARENTS = ["retention", "lapsed_users"] as const;

/**
 * BUT-1800: uid-bearing analytics rows under `analytics/retention` and
 * `analytics/lapsed_users`, which BUT-1789 left behind.
 *
 * `analytics/retention/events/{uid}_dN` (`analytics/track-retention.ts`) and
 * `analytics/lapsed_users/events/{autoId}` (`analytics/detect-lapsed-users.ts`)
 * both carry the uid in a `userId` field, so Art. 17 reaches them exactly as it
 * reached the feature-retention rows.
 *
 * Shaped on `deleteFeatureRetentionFlags`.
 *
 * The filter is the writer's own `userId` field on both. `lapsed_users` has no
 * choice: its ids are auto-generated, so there is no id form to range over. A
 * single-field equality needs no composite index.
 *
 * Neither parent has an aggregate sibling to preserve.
 *
 * The per-parent catch below covers the QUERY only. `batchDeleteAll` commits
 * non-strict, so a failed chunk is still swallowed and this function can return
 * true with rows left behind — which is why the matching leg in
 * `probeResidualData` is the load-bearing half, not this one.
 */
export async function deleteRetentionAnalytics(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const failed: string[] = [];
  for (const parent of RETENTION_ANALYTICS_PARENTS) {
    // Per-parent, for the reason the probe leg states: sharing one catch lets a
    // failure on the first parent skip the second, and the caller cannot tell
    // "swept both" from "threw before reaching the second".
    try {
      const snap = await db
        .collection("analytics")
        .doc(parent)
        .collection("events")
        .where("userId", "==", uid)
        .get();
      await batchDeleteAll(db, snap.docs);
    } catch (err) {
      failed.push(parent);
      logger.error("[deletion-cascade] analytics sweep failed", {
        uid_prefix: uid.slice(0, 6),
        parent,
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  if (failed.length > 0) {
    throw new Error(`analytics erasure incomplete: ${failed.join(", ")}`);
  }
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
  const snap = await db.collection("users").doc(uid).collection("pantry").get();
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
  // Per-conversation failures are COLLECTED, not thrown. A rejection inside
  // `Promise.all` abandons every conversation left in the run — including the
  // roster sweep below, which is the leg added to catch exactly this kind of
  // leftover. Same shape `deleteShoppingLists` already uses. `complete` tracks
  // the erasures that finished but did not finish CLEANLY (a conversation left
  // standing, a declined sweep): those must not be reported as a done erasure.
  const conversationFailures: string[] = [];
  let complete = true;
  for (let i = 0; i < convos.docs.length; i += chunkSize) {
    const chunk = convos.docs.slice(i, i + chunkSize);
    await Promise.all(
      chunk.map(async (convoDoc) => {
        try {
          const participants = Array.isArray(convoDoc.data().participantIds)
            ? (convoDoc.data().participantIds as string[])
            : [];
          // BUT-1838: a conversation owned by a chat group is handled ENTIRELY
          // by `deleteChatGroupMemberships`, which removes the uid from the
          // group AND the conversation in one transaction. Touching it here too
          // would be a second writer of membership — the drift this repo has
          // been burned by more than once — and, because the two legs run in
          // parallel, a race as well: this branch would strip the conversation
          // while `chat_groups.memberIds` still named the erased user.
          if (typeof convoDoc.data().groupId === "string") {
            return;
          }
          if (participants.length <= 2) {
            // BUT-1822: THE ROSTER FIRST, and the parent delete gated on it.
            // Deleting the conversation is the write that makes `parentDoc() ==
            // null` true. Every predicate that could surface a row reads through
            // the parent, so every surviving row becomes UNREADABLE forever —
            // including the SURVIVING partner's, whose `participantId` is not
            // this uid, so the collection-group sweep below can never reach it
            // either. (Not unreachable: delete and the `lastReadAt` update
            // branch key on `participantId == request.auth.uid` alone, so the
            // subject keeps those two — and no client flow uses either.) Until
            // BUT-1838 this was worse: a bootstrap branch re-opened those rows
            // to any signed-in user, which for a 1:1 disclosed the erased user's
            // name and avatar to their former partner forever. The branch is
            // gone; an unreadable roster is still a one-way door, so the
            // ordering below is unchanged.
            //
            // No try/catch around this call, on purpose: `tryClearRoster` reports
            // rather than throws, and a catch here could only turn its `false`
            // back into the delete it exists to prevent.
            //
            // The thread delete runs BEFORE it, not between it and the parent
            // delete: while the parent lives it still names both participants, so
            // anything between the clear and the delete is a window in which a
            // fresh roster row could be written and then orphaned. Nothing writes
            // one for a 1:1 today; the ordering costs nothing and shrinks the
            // window to a single round trip.
            const thread = await db
              .collection(Collections.messages)
              .where("conversationId", "==", convoDoc.id)
              .get();
            await batchDeleteAll(db, thread.docs);
            const rosterClear = await tryClearRoster(db, convoDoc.id);
            if (rosterClear) {
              await convoDoc.ref.delete();
            } else {
              // The parent must stand — see above. But leaving it untouched would
              // keep the erased user's name and avatar in
              // `participantDisplayNames` / `participantAvatarUrls` forever, which
              // is the Art. 17 defect this step exists to fix. So the document
              // gets the same departure update a surviving GROUP gets: the maps
              // lose their uid keys and `participantIds` loses the entry.
              //
              // This is the first code path that can leave a `direct_`
              // conversation standing with fewer than two participants —
              // no client can leave a direct chat — the departure callable takes a
              // `groupId`, so a direct conversation cannot be addressed at all — so
              // no client has rendered that state before (it degrades: every
              // "other participant" lookup in `conversation.dart` carries an
              // `orElse`). For a DIRECT conversation the seeded-roster route is
              // not reachable at all, and post-BUT-1838 for a STRONGER reason
              // than this comment used to give. Only the two attested
              // participants may write rows, and `directIdBinds` pins
              // `participantIds` to exactly two, with the update rule denying any
              // diff that touches it — so a direct conversation's roster holds at
              // most TWO client-written rows, ever, and two rows can never reach
              // the refusal cap. For a `direct_` id this branch therefore means a
              // transient roster read or delete failure. It is NOT direct-only,
              // though: the gate is `participants.length <= 2` on any conversation
              // without a `groupId`, and a LEGACY non-direct one can genuinely hit
              // the cap through rows seeded before BUT-1838 (the old bootstrap
              // branch excluded `direct_` explicitly, so those rows are exactly
              // the non-direct population). Do not read a `gdprCompliant: false`
              // here as necessarily an outage.
              //
              // The step reports INCOMPLETE afterwards. A `direct_` id is
              // literally `direct_<erasedUid>_<survivorUid>`, so a conversation
              // left standing retains the erased user's identifier in its own
              // document id, where no field-keyed probe can ever see it. Erasure
              // is not done; the audit row must not say it is.
              //
              // The id is HASHED in the log for the same reason: this line would
              // otherwise carry both uids into a sink that outlives the account.
              complete = false;
              logger.warn(
                "[deletion-cascade] roster not clear; conversation left standing",
                {
                  uid_prefix: uid.slice(0, 6),
                  conversationId: logSafeConversationId(convoDoc.id),
                },
              );
              await db.runTransaction(async (tx) => {
                const fresh = await tx.get(convoDoc.ref);
                if (!fresh.exists) return;
                tx.update(convoDoc.ref, buildGroupDepartureUpdate(fresh, uid));
              });
            }
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
        } catch (e) {
          // Classified, never named: a Firestore error embeds the full document
          // path, which on this path is a conversation id — for a 1:1, two raw
          // uids.
          conversationFailures.push(
            String((e as { code?: number | string } | null)?.code ?? "unknown"),
          );
        }
      }),
    );
  }

  const swept = await deleteOwnRosterRows(db, uid);

  // BUT-1835. Called from inside this step, not registered as its own, for the
  // reason spelled out on `deleteOwnRosterRows`: Tier 1 steps run in PARALLEL,
  // and both this and the conversation loop above write to `messages`. Running
  // it sequentially after the loop removes THIS step's own race with itself.
  //
  // It does NOT remove every race, and the previous version of this comment
  // claimed it did ("sequential-after is the only deterministic order").
  // `request-account-deletion.ts` puts `chat_groups` and `messages` in the same
  // `Promise.all`, and `deleteChatGroupMemberships` deletes an emptied group's
  // whole thread — so a message this step is about to update can vanish under
  // it from a SIBLING step. That is why the creator scrub below tolerates
  // NOT_FOUND per document instead of relying on ordering, and why BUT-1801
  // added a residual probe on `metadata.poll.creatorId`: ordering is not a
  // control, and a swallowed chunk failure here is silent by construction.
  const pollVotesCleared = await deletePollVotes(db, uid);

  if (conversationFailures.length > 0) {
    logger.error("[deletion-cascade] conversations failed to erase", {
      uid_prefix: uid.slice(0, 6),
      failedCount: conversationFailures.length,
      errCodes: conversationFailures,
    });
    return false;
  }
  return complete && swept && pollVotesCleared;
}

/**
 * Upper bound on roster rows one account deletion will sweep.
 *
 * Generous — a real user in 200 conversations holds 200 rows — and it is a
 * plausibility bound, not a correctness one. Without a bound, somebody else
 * chooses how large a read-and-delete bill this step pays for a chosen victim's
 * erasure (BUT-1830).
 *
 * THE BOUND STAYS. BUT-1838 closed the hole this was written against — the
 * UNATTESTED bootstrap branch, which let anyone who guessed a conversation id
 * seat rows under a parent that did not exist — and the bound is still load-
 * bearing, for three reasons:
 *   1. rows seeded BEFORE that shipped are still on disk; the backfill was
 *      closed unbuilt (BUT-1839);
 *   2. a tampered or non-standard Admin-SDK writer never passes through rules;
 *   3. an ATTESTED client write is bounded but LIVE. `attestedWriter()` needs
 *      the parent to name the writer AND the subject, and a direct conversation
 *      `direct_A_B` names both — so A may write B's row. A may also create that
 *      conversation: two adults need no friendship (`passesMinorDmGate` only
 *      fires when the other party is a minor), and the 10-second
 *      `rateLimitWrite('conversations', 10)` does NOT cap the rate: it reads
 *      `users/{uid}/rate_limits/conversations`, a bucket nothing in `lib/` ever
 *      writes, so `!exists(limitsPath)` is permanently true — and the bucket is
 *      self-written, so a tampered client would omit the stamp anyway. Against a
 *      CHOSEN victim this yields at most two rows per distinct peer account —
 *      `directIdBinds` accepts both orderings, so A may create `direct_A_V`
 *      and `direct_V_A`, each holding one such row — so it is unbounded only
 *      against your OWN uid.
 * The write rule constrains a row's id SHAPE not at all: attestation requires
 * only that the id appear in `participantIds`, which is never shape-validated.
 *
 * Over the bound the sweep DECLINES rather than truncating, and reports it, so
 * `deleteMessages` returns false and the step lands in `failedCollections`. That
 * decline, and the uncapped `count()` probe that raises the alarm, are FROZEN:
 * they are the Art. 17 completeness signal, and they do not depend on which of
 * the three sources above is the live one. Do not relax either to truncation on
 * the argument that the bootstrap hole is closed.
 * Truncating would be loud too — the probe below is an uncapped `count()`, so
 * either way `residual_data_detected` fires and the audit row says
 * `gdprCompliant: false`. Declining is chosen because it is strictly less
 * erasure for the same alarm.
 *
 * The cost of declining, stated: rows planted by routes 1 or 2 — or by a user
 * inflating their OWN count, at whatever rate a client can issue creates, since
 * nothing caps it (above) — block the sweep of
 * that user's LEGITIMATE roster rows,
 * and nothing retries automatically — the auth user is gone by then, so recovery
 * is a human running `admin/reset-user-data.ts`. The alarm is what makes that
 * recoverable rather than silent.
 */
const MAX_ROSTER_SWEEP_ROWS = 2000;

/**
 * BUT-1822: the erased user's OWN roster rows, wherever they are.
 *
 * `conversations/{id}/participants/{uid}` carries their `displayName` and
 * `avatarUrl`, and nothing in this cascade has ever touched it. The gap became a
 * disclosure the day that path got its first `match` block — before it, writes
 * were default-denied, so no row existed to leak.
 *
 * Runs AFTER the conversation loop, and inside this step rather than as its own
 * `runStep`: Tier 1 steps run in parallel, so a separate step would interleave
 * two deleters over the same rows, while the loop's 1:1 branch already clears
 * whole rosters. Sequential-after is the only deterministic order.
 *
 * It also sweeps rows orphaned by the other conversation deleters — the client's
 * own "delete conversation"; the eviction trigger's collapse branch, a LEGACY
 * source since BUT-1838 removed it; and `removeChatGroupMember.deleteEmptyGroup`,
 * which clears the roster first and so orphans nothing — whenever a row belongs
 * to the user being erased. Rows belonging to anyone else under a deleted parent are BUT-1825.
 */
async function deleteOwnRosterRows(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const snap = await db
    .collectionGroup(Collections.participants)
    .where("participantId", "==", uid)
    .limit(MAX_ROSTER_SWEEP_ROWS + 1)
    .get();

  if (snap.size > MAX_ROSTER_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible roster-row count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: snap.size },
    );
    return false;
  }
  await batchDeleteAll(db, snap.docs);
  return true;
}

/**
 * Cap on one erasure's poll-vote sweep. Same contract as `MAX_ROSTER_SWEEP_ROWS`
 * above and set to the same number — but NOT for the same reason, and the
 * difference is worth stating because the first version of this docstring
 * borrowed the roster's argument and was wrong (BUT-1801 review, 2026-08-17).
 *
 * The roster cap exists because a PEER can seat rows keyed on this user.
 * Here they cannot: in `firestore.rules`, every write verb under
 * `match /messages/{messageId}/poll_votes/{voterId}` requires
 * `request.auth.uid == voterId`, and `isValidVote()` additionally pins
 * `request.resource.data.voterId == voterId`. Posting a poll into a conversation
 * creates ZERO rows for anyone; a row exists only when this user votes. So the
 * count is chosen by the user themselves.
 *
 * (Cited by match pattern and function name, not line number. An earlier version
 * gave a line range that was already wrong when it was written — a rules file
 * renumbers on every edit, so a coordinate in a comment rots faster than the
 * claim it supports.)
 *
 * The cap stays anyway, for the two reasons that do survive: self-inflation
 * (nothing rate-limits how many polls one person votes in), and a tampered or
 * non-standard Admin-SDK writer, which rules never see. Above the cap the sweep
 * DECLINES rather than truncating — a
 * truncated sweep reports a clean erasure over rows it never looked at, which
 * is the one outcome Art. 17 cannot tolerate. Declining lands the step in
 * `failedCollections`, which is loud.
 */
const MAX_POLL_VOTE_SWEEP_ROWS = 2000;

/**
 * BUT-1835: the erased user's poll votes, and their authorship of polls.
 *
 * TWO distinct residues, and neither one covers the other.
 *
 * (1) THEIR VOTES. Since BUT-1832 a vote is a document at
 * `messages/{messageId}/poll_votes/{voterUid}` — the uid is the document ID and
 * is also copied into a `voterId` field, which is the only one a query can see.
 * They live under messages this user may never have sent, in conversations
 * `deleteMessages` leaves standing (any group, and any 1:1 whose roster clear
 * declined), so nothing else in this cascade reaches them. Written against the
 * subcollection shape, NOT the inline `metadata.poll.options[].voterIds` array
 * it replaced. That array is still EMITTED — `Poll.toMap` writes it and
 * `closePoll` rewrites the whole metadata map — but nothing has written a VOTER
 * UID into it since BUT-1832: `closePoll` reads the raw snapshot rather than the
 * hydrated model, so the display tally cannot round-trip back into storage.
 *
 * Careful with the tense. That is a claim about WRITERS, not about disk. A poll
 * created by the PRE-BUT-1832 client can still hold its author's own uid there,
 * because the old message update rule (`request.auth.uid == resource.data
 * .senderId`) let exactly one person write it. On such a row the scrub rewrites
 * only `creatorId`, and both probe legs then read zero — a certified-clean
 * erasure over a raw uid. Dev-project data only, on the same reasoning that
 * closed BUT-1839 unbuilt; whether it earns a backfill is Malin's call.
 *
 * So a cascade that scrubbed the array INSTEAD of the subcollection would be
 * chasing a field no live writer fills while missing the one that carries every
 * vote made since.
 *
 * (2) THEIR AUTHORSHIP. `metadata.poll.creatorId` names the person who opened
 * the poll. `deleteMessages` anonymises `senderId` on their own messages but
 * never looks inside `metadata`, so on every surviving poll the raw uid stayed
 * in the document — including polls in groups they had left, where no other
 * field of theirs remains. The dotted-path update rewrites that one key and
 * leaves the question, the options and everyone else's data untouched; blanking
 * `metadata` wholesale would delete a poll the remaining members still use.
 *
 * The equality filter on `metadata.poll.creatorId` needs no composite index
 * (automatic single-field indexes cover an equality on a nested map key), but
 * the collection-group sweep on `voterId` DOES need a `COLLECTION_GROUP`
 * fieldOverride — automatic single-field indexes are collection-scoped, and
 * without the override this query fails with FAILED_PRECONDITION rather than
 * matching nothing. It is declared in `firestore.indexes.json`.
 */
export async function deletePollVotes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  let complete = true;

  const votes = await db
    .collectionGroup(Collections.pollVotes)
    .where("voterId", "==", uid)
    .limit(MAX_POLL_VOTE_SWEEP_ROWS + 1)
    .get();

  if (votes.size > MAX_POLL_VOTE_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible poll-vote count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: votes.size },
    );
    complete = false;
  } else {
    await batchDeleteAll(db, votes.docs);
  }

  // Runs even when the vote sweep declined: the two residues are independent,
  // and half an erasure beats none as long as the step still REPORTS itself
  // incomplete, which `complete` does.
  // CAPPED, exactly like the vote sweep. An earlier version of this call was
  // uncapped, justified as "self-bounded — only this user authors this user's
  // polls". That is false, and `anonymizeSystemMessagesAboutUser` in this file
  // already says so: the `messages`
  // create rule pins required fields but carries NO `hasOnly`, so `metadata` is
  // unconstrained and any participant can plant
  // `metadata.poll.creatorId: <victimUid>` on a message in their own DM. The row
  // count is chosen by other people — the one argument that does NOT hold for
  // `poll_votes` and DOES hold here. Do not "simplify" the two to match.
  const authored = await db
    .collection(Collections.messages)
    .where("metadata.poll.creatorId", "==", uid)
    .limit(MAX_POLL_VOTE_SWEEP_ROWS + 1)
    .get();

  if (authored.size > MAX_POLL_VOTE_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible poll-authorship count; not scrubbing",
      { uid_prefix: uid.slice(0, 6), rows: authored.size },
    );
    return false;
  }

  // Per document, NOT one batch. A `WriteBatch` is atomic, so a single message
  // deleted underneath us by a SIBLING step — `deleteChatGroupMemberships`
  // deletes an emptied group's whole thread, and it runs in the same
  // `Promise.all` as this one — takes NOT_FOUND and kills the entire ≤500-doc
  // chunk with it. `commitInChunks(strict:false)` then swallows that, and the
  // step still returns success: up to 500 messages keep the raw uid in
  // `metadata.poll.creatorId` while the audit says the erasure was clean.
  //
  // NOT_FOUND (grpc code 5) is therefore tolerated per document and ONLY here:
  // the message is gone, which is the outcome this scrub wanted. Every other
  // error marks the step incomplete, so a real failure still reaches
  // `failedCollections` — and BUT-1801's residual probe on this same field is
  // the independent check that the two never disagree silently.
  //
  // In waves, not one fan-out. The set is capped above but still up to 2000
  // documents, and the file's own convention for a per-document pass is a
  // bounded slice at a time (`deleteMessages`, `scrubLastEditor`) rather than
  // 2000 simultaneous write RPCs.
  const SCRUB_WAVE = 10;
  const hardFailures: PromiseRejectedResult[] = [];
  for (let i = 0; i < authored.docs.length; i += SCRUB_WAVE) {
    const wave = await Promise.allSettled(
      authored.docs
        .slice(i, i + SCRUB_WAVE)
        .map((doc) => doc.ref.update({ "metadata.poll.creatorId": "deleted" })),
    );
    hardFailures.push(
      ...wave.filter(
        (r): r is PromiseRejectedResult =>
          r.status === "rejected" &&
          (r.reason as { code?: number } | undefined)?.code !== 5,
      ),
    );
  }
  if (hardFailures.length > 0) {
    complete = false;
    logger.error("[deletion-cascade] poll-creator scrub failed", {
      uid_prefix: uid.slice(0, 6),
      failed: hardFailures.length,
      total: authored.docs.length,
      errCodes: hardFailures.map(
        (r) => (r.reason as { code?: number } | undefined)?.code ?? null,
      ),
    });
  }

  return complete;
}

/**
 * BUT-1788: erase the user's name from SYSTEM rows written ABOUT them.
 *
 * `removeChatGroupMember` writes "<Name> har lämnat gruppen" under
 * `senderId: "system"` (through `groups/group-system-message.ts`; until BUT-1838
 * this was `leaveGroupConversation`). Three separate things make that row invisible to every
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
    const convoId =
      typeof data.conversationId === "string" ? data.conversationId : null;
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
              Record<string, unknown> | undefined;
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
            // Hashed for `direct_` ids like every other site on this path. This
            // one was judged group-only in 2026-08-01 because what was then the
            // sole writer of `metadata.subjectUserId` — `leave-group-conversation.ts`,
            // deleted by BUT-1838 and replaced by `groups/group-system-message.ts`,
            // whose call sites are all group callables — refuses direct chats. That reasoning was already wrong: the
            // `messages` create rule carries no `hasOnly`, so a sender can plant
            // that field on a message in their own DM and steer this line onto a
            // two-uid id.
            conversationId: logSafeConversationId(convoId),
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
    Record<string, unknown> | undefined;
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
 * state, which is theirs and has no purpose once the account is gone. Since
 * BUT-1838 the group path clears it too — `stageMemberRemoval` deletes every
 * key in the SEPARATE list of the same name in `groups/chat-group-writes.ts`,
 * which additionally carries `memberSince`. Two declarations, not one import:
 * a key added to either must be added to the other by hand.
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
      db.collection("notification_engagement").where("userId", "==", uid).get(),
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

/**
 * BUT-1838: erase the user's chat-group membership.
 *
 * **Why this is its own leg and not part of `deleteMessages`.** A group's
 * membership lives on `chat_groups/{id}.memberIds` and is MIRRORED onto the
 * conversation; one writer owns both (`groups/chat-group-writes.ts`). Letting
 * the conversation leg strip its half would leave the group still naming the
 * erased user — two copies of one fact, disagreeing, which is the failure
 * BUT-1798 already cost this project once. `deleteMessages` therefore skips any
 * conversation carrying a `groupId`, and this leg does the whole removal
 * through the shared writer.
 *
 * Three things happen per group, in this order:
 *
 *  1. **`createdBy` is re-homed** to a surviving admin (or member) when the
 *     erased user created a group that lives on. Same move `deleteFamilyData`
 *     already makes for households: without it a raw uid sits on a document
 *     other people keep reading, forever, which Art. 17 does not permit and no
 *     field-keyed probe would flag as "residual" once the membership is gone.
 *  2. **The membership goes**, through `stageMemberRemoval` — the same
 *     transaction that clears `memberIds`, `adminIds`, both display maps,
 *     `memberAddedBy`, the conversation's `participantIds`, all five uid-keyed
 *     conversation maps (including `memberSince`) and the roster row.
 *  3. **An emptied group is taken down**, roster FIRST. Deleting a conversation
 *     is what makes `parentDoc()` null in `firestore.rules`; with the bootstrap
 *     branch gone that no longer re-opens a write path, but orphaned roster rows
 *     still carry names and avatars, so the parent delete stays gated on
 *     `tryClearRoster` reporting success. A group left standing reports the step
 *     INCOMPLETE rather than quietly passing.
 *
 * Capped like every other sweep here. Above the cap it DECLINES rather than
 * truncating: a partial pass that reported success would certify an erasure it
 * did not perform.
 *
 * A separate sweep handles what the membership query cannot reach at all — a
 * departure tombstone (the uid is in it precisely because it left `memberIds`)
 * and the meal-vote pointer's owner uid (they can leave the chat and keep
 * owning the social group). See `clearUnreachableChatGroupResiduals`, run
 * BEFORE the loop below so this function's own cap cannot take it down
 * (BUT-1856).
 */
export const MAX_CHAT_GROUPS_PER_USER = 200;

export async function deleteChatGroupMemberships(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  // FIRST, so the membership sweep declining below cannot take the two
  // independent residual legs down with it — they answer different queries and
  // a cap reached by one says nothing about the others.
  const residualsCleared = await clearUnreachableChatGroupResiduals(db, uid);

  const snap = await db
    .collection(Collections.chatGroups)
    .where("memberIds", "array-contains", uid)
    .limit(MAX_CHAT_GROUPS_PER_USER + 1)
    .get();

  if (snap.size > MAX_CHAT_GROUPS_PER_USER) {
    logger.error(
      "[deletion-cascade] implausible chat-group count; declining the sweep",
      { uid_prefix: uid.slice(0, 6), groups: snap.size },
    );
    return false;
  }

  let complete = true;
  const removedAt = admin.firestore.Timestamp.now();

  for (const groupDoc of snap.docs) {
    try {
      const data = groupDoc.data();
      const conversationId =
        typeof data.conversationId === "string" ? data.conversationId : null;
      if (!conversationId) {
        // A group with members and no conversation is a shape no code path
        // produces. Loud, and not counted as done.
        complete = false;
        logger.error("[deletion-cascade] chat group has no conversationId", {
          uid_prefix: uid.slice(0, 6),
          groupId: groupDoc.id,
        });
        continue;
      }

      const memberIds: string[] = Array.isArray(data.memberIds)
        ? (data.memberIds as string[])
        : [];
      const adminIds: string[] = Array.isArray(data.adminIds)
        ? (data.adminIds as string[])
        : [];
      const survivors = memberIds.filter((u) => u !== uid);

      await db.runTransaction(async (tx) => {
        const fresh = await tx.get(groupDoc.ref);
        if (!fresh.exists) return;
        stageMemberRemoval(tx, {
          db,
          groupId: groupDoc.id,
          conversationId,
          uid,
          removedAt,
        });
        if (survivors.length > 0 && data.createdBy === uid) {
          // Prefer a surviving ADMIN so the group keeps someone who can act on
          // it; fall back to any survivor rather than leaving a raw uid behind.
          const survivingAdmin = adminIds.find(
            (a) => a !== uid && survivors.includes(a),
          );
          tx.update(groupDoc.ref, {
            createdBy: survivingAdmin ?? survivors[0],
          });
        }
      });

      if (survivors.length === 0) {
        const cleared = await tryClearRoster(db, conversationId);
        if (!cleared) {
          complete = false;
          logger.warn(
            "[deletion-cascade] roster not clear; empty group left standing",
            {
              uid_prefix: uid.slice(0, 6),
              conversationId: logSafeConversationId(conversationId),
            },
          );
          continue;
        }
        const thread = await db
          .collection(Collections.messages)
          .where("conversationId", "==", conversationId)
          .get();
        await batchDeleteAll(db, thread.docs);
        await db.collection(Collections.conversations).doc(conversationId).delete();
        await groupDoc.ref.delete();
      }

      await db
        .collection(Collections.users)
        .doc(uid)
        .collection("conversation_memberships")
        .doc(conversationId)
        .delete()
        .catch(() => {
          // Cosmetic mirror; the membership cut above is the erasure. Never
          // named in the log — the id would carry the conversation.
        });
    } catch (e) {
      complete = false;
      logger.error("[deletion-cascade] chat-group removal failed", {
        uid_prefix: uid.slice(0, 6),
        errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
        errName: (e as Error | null)?.name,
      });
    }
  }

  return complete && residualsCleared;
}

/**
 * BUT-1856: raw uids on `chat_groups` the sweep above cannot reach.
 *
 * Not an exhaustive list of that document's residuals — `createdBy` is re-homed
 * only for groups the erased user is still a MEMBER of, and `memberAddedBy`
 * VALUES survive for everyone they seated. Both predate this change and are
 * forward-only work; do not read the two legs below as covering the document.
 *
 * `departedUserIds` records who left a chat group or was removed from it, so
 * the meal-vote category sync cannot seat them again — a uid is in it precisely
 * because it is NOT in `memberIds`. `sourceCategoryOwnerId` names the owner of
 * the social group a meal-vote chat was built from, and outlives their
 * membership: they can leave the chat and still own the category. The sweep
 * above finds groups by `memberIds array-contains`, so it is structurally blind
 * to both, and each would otherwise sit forever on a document the surviving
 * members read — the same residual class `createdBy` is re-homed for.
 *
 * Dropping the pointer breaks nothing: the category itself goes in this same
 * cascade, so it is already dangling, and the group simply stops being any
 * category's chat.
 *
 * Capped and DECLINING per leg, like every other sweep here: a partial pass
 * that reported success would certify an erasure it did not perform.
 */
async function clearUnreachableChatGroupResiduals(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const legs = [
    {
      field: "departedUserIds",
      op: "array-contains" as const,
      patch: { departedUserIds: admin.firestore.FieldValue.arrayRemove(uid) },
    },
    {
      field: "sourceCategoryOwnerId",
      op: "==" as const,
      patch: {
        sourceCategoryId: admin.firestore.FieldValue.delete(),
        sourceCategoryOwnerId: admin.firestore.FieldValue.delete(),
      },
    },
  ];

  let complete = true;
  for (const leg of legs) {
    const snap = await db
      .collection(Collections.chatGroups)
      .where(leg.field, leg.op, uid)
      .limit(MAX_CHAT_GROUPS_PER_USER + 1)
      .get();

    if (snap.size > MAX_CHAT_GROUPS_PER_USER) {
      logger.error(
        "[deletion-cascade] implausible chat-group residual count; declining",
        { uid_prefix: uid.slice(0, 6), field: leg.field, groups: snap.size },
      );
      complete = false;
      continue;
    }

    for (const groupDoc of snap.docs) {
      try {
        await groupDoc.ref.update(leg.patch);
      } catch (e) {
        complete = false;
        logger.error("[deletion-cascade] chat-group residual removal failed", {
          uid_prefix: uid.slice(0, 6),
          field: leg.field,
          errCode: (e as { code?: number | string } | null)?.code ?? "unknown",
          errName: (e as Error | null)?.name,
        });
      }
    }
  }
  return complete;
}
