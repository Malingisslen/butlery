/**
 * BUT-455: Audit-log emitter for cross-user cascade-delete operations.
 *
 * GDPR Article 17 (right to erasure) requires a demonstrable trail of every
 * write that propagates a user-delete onto other users' data. The on-user-
 * deleted cascade currently mutates 7+ cross-user surfaces (friend graph,
 * social requests, group memberships, friend counts, legacy sharedWith,
 * sharedBy tombstone, reports anonymization) without recording an audit row.
 *
 * This helper batches an audit_logs entry per cross-user mutation in the
 * same write batch as the cascade itself, so the audit row is committed
 * iff the mutation commits. Shape matches the existing audit_logs schema
 * used by storage/moderate-upload.ts and triggers/ping_onCreate.ts:
 *
 *   {
 *     userId: string,        // subject (the user being deleted)
 *     operation: string,     // e.g. 'cascade_delete', 'cascade_anonymize'
 *     resourceType: string,  // collection or surface name
 *     resourceId: string,    // affected doc id (often the other user's uid)
 *     granted: boolean,      // true — cascade is system-authorized
 *     timestamp: ServerTimestamp,
 *     metadata: {
 *       actor: 'system',
 *       targetUid: string,   // the *other* user affected by the cascade
 *       reason: 'gdpr_article_17',
 *       ...extra,
 *     },
 *   }
 */

import * as admin from "firebase-admin";

export interface CascadeAuditEntry {
  /** Subject — the user whose deletion triggered the cascade. */
  subjectUserId: string;
  /** Other user (or null for own-data cleanup) affected by the cascade. */
  targetUid: string | null;
  /** What kind of cascade ran: 'cascade_delete' | 'cascade_anonymize' | 'cascade_tombstone'. */
  operation: "cascade_delete" | "cascade_anonymize" | "cascade_tombstone";
  /** Collection or surface name (e.g. 'friends', 'friend_categories', 'public_profiles'). */
  resourceType: string;
  /** Affected document id (often the target uid). */
  resourceId: string;
  /** Optional extra metadata (chunk size, sub-collection name, etc.). */
  extra?: Record<string, unknown>;
}

/**
 * Stage a cascade-audit entry into an existing write batch. The audit row
 * commits with the same batch as the cascade mutation — partial failures
 * roll back the audit too, preserving the invariant "audit row exists iff
 * the cascade write succeeded."
 *
 * @param database Firestore instance (so test seams can inject a stub)
 * @param batch Active WriteBatch — the helper appends one `set` op
 * @param entry Audit details
 */
export function stageCascadeAuditEntry(
  database: admin.firestore.Firestore,
  batch: admin.firestore.WriteBatch,
  entry: CascadeAuditEntry,
): void {
  const ref = database.collection("audit_logs").doc();
  batch.set(ref, {
    userId: entry.subjectUserId,
    operation: entry.operation,
    resourceType: entry.resourceType,
    resourceId: entry.resourceId,
    granted: true,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    metadata: {
      actor: "system",
      targetUid: entry.targetUid,
      reason: "gdpr_article_17",
      ...(entry.extra ?? {}),
    },
  });
}

/**
 * Standalone write — for cascade ops not currently using a batch (best-effort
 * cleanup paths). Returns the audit doc ref so callers can chain.
 */
export async function writeCascadeAuditEntry(
  database: admin.firestore.Firestore,
  entry: CascadeAuditEntry,
): Promise<admin.firestore.DocumentReference> {
  const ref = database.collection("audit_logs").doc();
  await ref.set({
    userId: entry.subjectUserId,
    operation: entry.operation,
    resourceType: entry.resourceType,
    resourceId: entry.resourceId,
    granted: true,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    metadata: {
      actor: "system",
      targetUid: entry.targetUid,
      reason: "gdpr_article_17",
      ...(entry.extra ?? {}),
    },
  });
  return ref;
}
