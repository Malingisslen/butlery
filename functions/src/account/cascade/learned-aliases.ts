import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { hashUid } from "../../shared/hash-uid";

/** Firestore path of the alias candidates `processCorrectionEvent` votes on. */
export function learnedAliasesCollection(
  db: admin.firestore.Firestore,
): admin.firestore.CollectionReference {
  return db.collection("analytics").doc("ingredients").collection("learned_aliases");
}

// A candidate nobody has decided on is only the text its voters typed, so with
// no voter left there is nothing to keep. A decided one (approved, rejected,
// revoked) is kept without voters: approved backs the alias on the ingredient
// and the admin's revoke, rejected and revoked stop the same wrong spelling
// being approved again (Malin, 2026-10-31).
const UNDECIDED = new Set(["pending", "held_for_review"]);

const PAGE = 200;
const CONCURRENCY = 20;

/**
 * Removes [uid] from every alias candidate it voted on, and deletes an
 * undecided candidate whose last voter that was.
 *
 * One transaction per document, so a vote landing between the query and the
 * write is read before the delete decides: the candidate then has a voter
 * again and is kept.
 *
 * Returns false when a document still names [uid] afterwards; a re-run picks up
 * what is left, since every cleaned document drops out of the query.
 */
export async function cleanUserFromLearnedAliases(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  const col = learnedAliasesCollection(db);
  let removed = 0;
  let deleted = 0;
  let failed = 0;
  let previous: Set<string> | null = null;
  for (;;) {
    const snap = await col.where("userIds", "array-contains", uid).limit(PAGE).get();
    if (snap.empty) break;
    const paths = new Set(snap.docs.map((d) => d.ref.path));
    const prior: Set<string> | null = previous;
    // A page whose every write failed comes back unchanged; stop instead of
    // re-reading it until the caller times out.
    if (prior !== null && [...paths].every((p) => prior.has(p))) {
      logger.error("[learned-aliases] page did not shrink; stopping", {
        uid_hash: hashUid(uid),
        rows: snap.size,
      });
      return false;
    }
    previous = paths;
    for (let i = 0; i < snap.docs.length; i += CONCURRENCY) {
      const outcomes = await Promise.all(
        snap.docs.slice(i, i + CONCURRENCY).map((d) => cleanOne(db, d.ref, uid)),
      );
      for (const o of outcomes) {
        if (o === "deleted") deleted++;
        else if (o === "removed") removed++;
        else if (o === "failed") failed++;
      }
    }
    if (snap.size < PAGE) break;
  }
  logger.info(
    `GDPR: user ${hashUid(uid)} removed from ${removed} learned alias documents, ${deleted} deleted, ${failed} failed`,
  );
  // Asked of the store rather than of `failed`: a document that failed on one
  // page and was cleaned on the next is not left behind.
  const rest = await col.where("userIds", "array-contains", uid).limit(1).get();
  return rest.empty;
}

async function cleanOne(
  db: admin.firestore.Firestore,
  ref: admin.firestore.DocumentReference,
  uid: string,
): Promise<"deleted" | "removed" | "skipped" | "failed"> {
  try {
    return await db.runTransaction(async (tx) => {
      const snap = await tx.get(ref);
      if (!snap.exists) return "skipped";
      const raw = snap.get("userIds");
      const ids = Array.isArray(raw) ? raw : [];
      if (!ids.includes(uid)) return "skipped";
      const remaining = ids.filter((id) => id !== uid);
      if (remaining.length === 0 && UNDECIDED.has(snap.get("status") as string)) {
        tx.delete(ref);
        return "deleted";
      }
      tx.update(ref, {
        userIds: admin.firestore.FieldValue.arrayRemove(uid),
        count: admin.firestore.FieldValue.increment(-1),
      });
      return "removed";
    });
  } catch (err) {
    logger.error("[learned-aliases] cleanup of one document failed", {
      uid_hash: hashUid(uid),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
    return "failed";
  }
}
