/**
 * BUT-2142 (decision E1): GDPR Article 15 Right of Access for the backup
 * codes of two-step verification.
 *
 * `mfa_backup_codes/{uid}` is server-only at the rules layer, so the client
 * cannot read it for the export bundle. This callable reads the caller's own
 * document under the Admin SDK and returns what the data subject can use:
 * when the set was created, how many codes it holds and how many are still
 * unused, and which algorithm protects them. It never returns a salt or a
 * hash: they tell the user nothing and would make the codes easier to guess.
 */

import { onCall, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import { BACKUP_CODES_COLLECTION } from "../account/mfa-backup-codes";

export interface MfaRecoveryDataExport {
  /** Whether the account has a set of backup codes at all. */
  hasBackupCodes: boolean;
  /** ISO-8601 time the set was created, or null. */
  createdAt: string | null;
  total: number;
  unused: number;
  algorithm: string | null;
  gdprArticle: "Article 15 - Right of Access";
}

/** Test seam: the export for [uid] from an injected Firestore. */
export async function runExportMfaRecoveryData(
  database: admin.firestore.Firestore,
  uid: string,
): Promise<MfaRecoveryDataExport> {
  const snap = await database.collection(BACKUP_CODES_COLLECTION).doc(uid).get();
  const data = snap.exists ? snap.data() : undefined;
  if (!data) {
    return {
      hasBackupCodes: false,
      createdAt: null,
      total: 0,
      unused: 0,
      algorithm: null,
      gdprArticle: "Article 15 - Right of Access",
    };
  }
  const codes = Array.isArray(data.codes) ? data.codes : [];
  const unused = codes.filter(
    (c: unknown) =>
      typeof c === "object" && c !== null && (c as { usedAt?: unknown }).usedAt == null,
  ).length;
  return {
    hasBackupCodes: true,
    createdAt:
      typeof data.createdAt === "number"
        ? new Date(data.createdAt).toISOString()
        : null,
    total: codes.length,
    unused,
    algorithm: typeof data.algorithm === "string" ? data.algorithm : null,
    gdprArticle: "Article 15 - Right of Access",
  };
}

export const exportMfaRecoveryData = onCall(
  {
    cors: ["https://butlery.app", "https://www.butlery.app"],
    enforceAppCheck: true,
  },
  async (request): Promise<MfaRecoveryDataExport> => {
    if (!request.auth) {
      throw new HttpsError("unauthenticated", "Sign-in required.");
    }
    return runExportMfaRecoveryData(admin.firestore(), request.auth.uid);
  },
);
