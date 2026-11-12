import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { TRIGGER_OWNED_SUBCOLLECTIONS } from "./user-subcollections";

export async function probeUserSubcollections(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // Subcollections under users/{uid}. These are NOT top-level userId-scoped
  // collections, so a where("userId","==",uid) probe would silently match zero
  // (the realtime_recipes wrong-field trap). Probe each one directly.
  //
  // ENUMERATED, not listed (BUT-1957). This was a hand-written include-list
  // naming one collection, so a subcollection nobody remembered to add was not
  // reported as residual — it was invisible, and an all-clear was returned with
  // the rows still on disk. `users/{uid}/notifications` was the second miss
  // found that way, and a list cannot stop the third. `listCollections()` asks
  // the database what is actually still there, so a subcollection introduced by
  // a future feature shows up here on its first deletion instead of never.
  //
  // The two exclusions are TRIGGER_OWNED_SUBCOLLECTIONS, hoisted to module
  // scope so guards can import it (BUT-2043).
  try {
    const remaining = await db.collection("users").doc(uid).listCollections();
    for (const ref of remaining) {
      if (TRIGGER_OWNED_SUBCOLLECTIONS.has(ref.id)) continue;
      try {
        // `count()`, not `listDocuments()`. The two answer different
        // questions: `listDocuments()` is required where a MISSING parent can
        // still own live children, which is why `unified_shopping_lists` has
        // its own leg using it. That case is covered there, so this leg
        // only needs to know whether anything is left.
        const snap = await ref.count().get();
        const count = snap.data().count ?? 0;
        if (count > 0) {
          residual += count;
          // Collection id and count only — the rows under `notifications`
          // carry the push text actually shown to the user, and this log
          // outlives the account.
          logger.warn("[deletion-cascade] residual user subcollection", {
            uid_prefix: uid.slice(0, 6),
            collection: ref.id,
            count,
          });
        }
      } catch (err) {
        residual += 1;
        logger.error("[deletion-cascade] residual probe failed: subcollection", {
          uid_prefix: uid.slice(0, 6),
          collection: ref.id,
          errCode: (err as { code?: number | string }).code ?? null,
          errName: err instanceof Error ? err.name : typeof err,
        });
      }
    }
  } catch (err) {
    // Fails CLOSED: if we cannot even ask what is left, we do not get to say
    // the erasure was complete.
    residual += 1;
    logger.error("[deletion-cascade] residual probe failed: listCollections", {
      uid_prefix: uid.slice(0, 6),
      errCode: (err as { code?: number | string }).code ?? null,
      errName: err instanceof Error ? err.name : typeof err,
    });
  }
  return residual;
}
