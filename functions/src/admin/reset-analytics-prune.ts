/**
 * What a reset deletes UNDER the kept `analytics` collection.
 *
 * `analytics` holds two different things behind one name: per-date aggregates
 * with no uid, and rows about individual people —
 * `analytics/feature_retention/users/{uid}_{date}`,
 * `analytics/retention/events/{uid}_d{N}`, `analytics/lapsed_users/events`,
 * `analytics/notifications/effectiveness` and
 * `analytics/ingredients/learned_aliases`. The collection is in
 * `COLLECTIONS_TO_KEEP`, so the recursive walk in `reset-user-data.ts` never
 * reaches it; this is what reaches the second half.
 *
 * Pure of I/O decisions and side-effect-free at import, like
 * `unknown-collections.ts` — `reset-user-data.ts` calls `main()` at module
 * scope, so anything importable from there cannot be tested without starting a
 * destructive run.
 *
 * The deep delete is INJECTED rather than reimplemented: the script's
 * `deleteDocRecursive` descends every level via `listCollections()`, and a
 * second, shallower deleter here would leave children under a deleted parent —
 * invisible to `count()`, which counts documents.
 */

import type * as admin from "firebase-admin";
import { isKeptAnalyticsSeries } from "./reset-collection-lists";

export const ANALYTICS_COLLECTION = "analytics";

/** One subcollection under `analytics/{parentId}`, and what it held. */
export interface AnalyticsSubcollection {
  /** `analytics/{parentId}/{subId}` — what the run prints and reports. */
  path: string;
  parentId: string;
  subId: string;
  /**
   * Document references, from `listDocuments()` rather than `count()`: a
   * parent deleted while its children survive is not a document, so `count()`
   * answers zero over exactly the residue this module exists to find.
   */
  docs: number;
}

export interface AnalyticsPruneResult {
  deleted: AnalyticsSubcollection[];
  kept: AnalyticsSubcollection[];
}

/** A field on an `analytics/{parentId}` document that no list accounts for. */
export interface AnalyticsParentFields {
  path: string;
  fields: string[];
}

export interface AnalyticsResidue {
  subcollections: AnalyticsSubcollection[];
  /**
   * The prune deletes subcollections, so a uid written onto a PARENT document
   * would survive it and be reported by nothing: the unknown-collections
   * report no longer walks `analytics`, and the prune's own summary counts
   * subcollection rows. This is that blind spot, measured rather than promised
   * by a comment about what the parents carry today.
   */
  parentFields: AnalyticsParentFields[];
}

/**
 * Fields a parent document under `analytics` may carry without being reported,
 * matched by field name under any parent.
 *
 * `analytics/lapsed_users.lastRunAt` is the cursor
 * `analytics/detect-lapsed-users.ts` writes so the sweep knows where it got
 * to. It holds no uid, and resetting it only makes the next run start over.
 */
export const KEPT_PARENT_FIELDS = new Set<string>(["lastRunAt"]);

type Db = admin.firestore.Firestore;
type DocRef = admin.firestore.DocumentReference;

export interface PruneOptions {
  /** The script's kill-switch cursor, threaded into the per-document loop. */
  maybeRefreshKillSwitch: () => Promise<void>;
  /**
   * `deleteDocRecursive` bound to this run. Deletes the document and every
   * subcollection beneath it at any depth, and honours the run's `dryRun`
   * itself — the same contract the script's own walk runs under. This module
   * takes no `dryRun` of its own, because a second flag that decided nothing
   * would read as a control on a destructive helper and be inert.
   *
   * One call per document, like `deleteWithSubcollections`, rather than a
   * batched sweep: a document may own subcollections and only the recursion
   * knows. `feature_retention/users` grows with accounts times days and has no
   * TTL, so on a large project this is the slow part of the prune.
   */
  deleteDocDeep: (docRef: DocRef) => Promise<void>;
}

async function walkAnalytics(
  db: Db,
  visit: {
    sub: (
      parent: DocRef,
      sub: admin.firestore.CollectionReference,
      docs: DocRef[],
    ) => Promise<void>;
    parent?: (parent: DocRef) => Promise<void>;
  },
): Promise<void> {
  // `listDocuments()` and not `get()`: `analytics/notifications` and several of
  // its siblings are parents that hold only subcollections and no fields of
  // their own, so a query over the collection returns none of them.
  const parents = await db.collection(ANALYTICS_COLLECTION).listDocuments();
  for (const parent of parents) {
    if (visit.parent) await visit.parent(parent);
    for (const sub of await parent.listCollections()) {
      await visit.sub(parent, sub, await sub.listDocuments());
    }
  }
}

/**
 * Deletes every subcollection under `analytics` that is not a kept series.
 *
 * The parent documents themselves are left standing, because deleting a parent
 * whose kept series survives would orphan that series. What they may carry
 * without being reported is `KEPT_PARENT_FIELDS`; `countAnalyticsResidue`
 * names anything else.
 */
export async function pruneAnalytics(
  db: Db,
  options: PruneOptions,
): Promise<AnalyticsPruneResult> {
  const result: AnalyticsPruneResult = { deleted: [], kept: [] };

  await walkAnalytics(db, {
    sub: async (parent, sub, docs) => {
      const entry: AnalyticsSubcollection = {
        path: `${ANALYTICS_COLLECTION}/${parent.id}/${sub.id}`,
        parentId: parent.id,
        subId: sub.id,
        docs: docs.length,
      };

      if (isKeptAnalyticsSeries(parent.id, sub.id)) {
        result.kept.push(entry);
        return;
      }

      for (const doc of docs) {
        await options.maybeRefreshKillSwitch();
        await options.deleteDocDeep(doc);
      }
      result.deleted.push(entry);
    },
  });

  return result;
}

/**
 * What a delete-fate subcollection still holds. Deletes nothing.
 *
 * Report-only, like `verifyReset` itself: a verification pass that repairs
 * while it measures reports "clean" about a state it produced.
 */
export async function countAnalyticsResidue(
  db: Db,
): Promise<AnalyticsResidue> {
  const subcollections: AnalyticsSubcollection[] = [];
  const parentFields: AnalyticsParentFields[] = [];

  await walkAnalytics(db, {
    sub: async (parent, sub, docs) => {
      if (isKeptAnalyticsSeries(parent.id, sub.id)) return;
      if (docs.length === 0) return;
      subcollections.push({
        path: `${ANALYTICS_COLLECTION}/${parent.id}/${sub.id}`,
        parentId: parent.id,
        subId: sub.id,
        docs: docs.length,
      });
    },
    parent: async (parent) => {
      const snapshot = await parent.get();
      if (!snapshot.exists) return;
      const unexpected = Object.keys(snapshot.data() ?? {}).filter(
        (field) => !KEPT_PARENT_FIELDS.has(field),
      );
      if (unexpected.length === 0) return;
      parentFields.push({
        path: `${ANALYTICS_COLLECTION}/${parent.id}`,
        fields: unexpected.sort(),
      });
    },
  });

  return { subcollections, parentFields };
}
