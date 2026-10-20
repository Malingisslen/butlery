/**
 * BUT-2294: the server backstop for an object that reaches Storage after its
 * owner's account was erased.
 *
 * A phone can hold queued photo uploads, and the app drops that queue once the
 * account is gone, but a racing or hand-rolled client can still finish an
 * upload after the cascade's `storage_files` step has emptied `users/{uid}/`.
 * Nothing would ever delete that object, so `moderateUpload` asks this module
 * first, on every finalize under `users/`.
 *
 * The owner is the uid in the PATH, never `metadata.uploadedBy`: the metadata
 * is client-written, and the path is what `storage.rules` binds to the
 * writer's own uid.
 *
 * Gone means either Auth no longer has the account, or the cascade's
 * `erasures_in_progress/{uid}` marker still counts (`erasureUnderway`, so a
 * marker past its window does not delete a live user's photo). Any other
 * failure answers "unknown" and the object is KEPT: a transient Auth or
 * Firestore error must never delete a living user's upload.
 */

import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { Collections } from "../shared/collections";
import { hashUid } from "../shared/hash-uid";
import { accountExists } from "../social/sync-block-mirror";
import { erasureUnderway } from "../social/hold-shares-on-block";

export const ERASED_OWNER_OPERATION = "storage_upload_after_erasure";

export type OwnerVerdict = "erased" | "erasure_underway" | "live" | "unknown";

/** The narrow slice of a Storage bucket this module uses. */
export interface DeletableBucket {
  file(name: string): {
    delete(options: { ignoreNotFound: boolean }): Promise<unknown>;
  };
}

export interface OwnerCheckDeps {
  db: admin.firestore.Firestore;
  /** Seam: the unit suite has no Auth emulator. */
  ownerExists?: (uid: string) => Promise<boolean>;
  nowMs?: number;
}

function errCode(reason: unknown): string | null {
  const code = (reason as { code?: unknown } | null)?.code;
  return code === undefined || code === null ? null : String(code);
}

/**
 * Whether the account a `users/{uid}/` object belongs to is gone.
 *
 * Auth and the marker are read together, and a definite answer from either
 * one decides: an error on the other source cannot make a definite "gone"
 * uncertain. Only when neither says gone does an error turn into "unknown".
 */
export async function pathOwnerVerdict(
  uid: string,
  deps: OwnerCheckDeps,
): Promise<OwnerVerdict> {
  const ownerExists = deps.ownerExists ?? accountExists;
  // Each read is wrapped so a synchronous throw lands in its settled result
  // instead of escaping the handler.
  const [account, marker] = await Promise.allSettled([
    (async () => ownerExists(uid))(),
    (async () =>
      deps.db.collection(Collections.erasuresInProgress).doc(uid).get())(),
  ]);

  if (account.status === "fulfilled" && !account.value) return "erased";
  if (
    marker.status === "fulfilled" &&
    erasureUnderway(marker.value, deps.nowMs)
  ) {
    return "erasure_underway";
  }
  if (account.status === "rejected" || marker.status === "rejected") {
    logger.error("[moderateUpload] owner check failed; object kept", {
      uid_hash: hashUid(uid),
      authErrCode:
        account.status === "rejected" ? errCode(account.reason) : null,
      markerErrCode:
        marker.status === "rejected" ? errCode(marker.reason) : null,
    });
    return "unknown";
  }
  return "live";
}

/**
 * Deletes [name] when its path owner is gone, and records that it did.
 * Returns true when the object was judged doomed, so the caller stops.
 */
export async function deleteIfOwnerErased(
  args: { bucketName: string; name: string; uid: string },
  deps: OwnerCheckDeps & { bucket: DeletableBucket },
): Promise<boolean> {
  const verdict = await pathOwnerVerdict(args.uid, deps);
  if (verdict !== "erased" && verdict !== "erasure_underway") return false;

  const uidHash = hashUid(args.uid);
  let deleted = true;
  try {
    await deps.bucket.file(args.name).delete({ ignoreNotFound: true });
  } catch (err) {
    deleted = false;
    logger.error("[moderateUpload] failed to delete post-erasure object", {
      uid_hash: uidHash,
      errCode: errCode(err),
    });
  }

  // The account is gone, so its raw uid in a new row would be personal data
  // the erasure can no longer reach. The row carries `hashUid` only, in a
  // `userIdHash` field as `writeComplianceAudit` does, and the uid segment of
  // the path is replaced by the same hash.
  const pathTail = args.name.split("/").slice(2).join("/");
  await deps.db.collection("audit_logs").add({
    userIdHash: uidHash,
    operation: ERASED_OWNER_OPERATION,
    resourceType: "storage_object",
    resourceId: `users/${uidHash}/${pathTail}`,
    granted: false,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    metadata: {
      bucket: args.bucketName,
      reason: verdict,
      deleted,
    },
  });

  logger.warn("[moderateUpload] deleted upload from an erased account", {
    uid_hash: uidHash,
    reason: verdict,
    deleted,
  });
  return true;
}
