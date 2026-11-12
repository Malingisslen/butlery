import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { Collections } from "../../shared/collections";

export async function probePersonalShoppingLists(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
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
  return residual;
}

export async function probeSharedShoppingLists(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // unified_shared_shopping_lists (BUT-1697 follow-up). Two distinct residual
  // classes, neither of which a plain `ownerId == uid` count could express:
  //
  //  1. the deleted uid still present as a `memberPermissions` MAP KEY — after
  //     the cascade that key is gone on every matched doc, whether the doc was
  //     scrubbed or deleted, so ANY hit here is a residual.
  //  2. a list still owned by the uid with NO other member left — an orphan no claim-lint:ok moved unchanged, BUT-2113
  //     account can read. A list owned by the uid that OTHER members still
  //     share is the one justified residual (nulling `ownerId` would orphan it
  //     for them), so it must NOT count. That distinction is why this leg reads
  //     the docs instead of using `count()`.
  try {
    const keyed = await db
      .collection(Collections.unifiedSharedShoppingLists)
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
      .collection(Collections.unifiedSharedShoppingLists)
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
  return residual;
}

export async function probeSharedListAttribution(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
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
        .collection(Collections.unifiedSharedShoppingLists)
        .where("contributorUserIds", "array-contains", uid),
    ],
    [
      "lastActivityByUserId",
      db
        .collection(Collections.unifiedSharedShoppingLists)
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
  return residual;
}
