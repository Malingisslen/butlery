/**
 * Keeps the `admin` custom claim in sync with the `admins/{uid}` collection.
 *
 * The app and Firestore rules treat the existence of an `admins/{uid}` doc as
 * the single source of truth for admin access (firestore.rules `isAdmin()`).
 * Cloud Functions callables (`requireAdmin`) and Storage rules instead read the
 * `admin` custom claim. This trigger bridges the two: creating an `admins/{uid}`
 * doc grants the claim, deleting it revokes the claim — so adding one document
 * is all it takes to make every layer agree on who is an admin.
 */

import {
  onDocumentCreated,
  onDocumentDeleted,
} from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { hashUid } from "../shared/hash-uid";

async function setAdminClaim(uid: string, isAdmin: boolean): Promise<void> {
  try {
    const user = await admin.auth().getUser(uid);
    const claims = { ...(user.customClaims ?? {}) };
    if (isAdmin) {
      claims.admin = true;
    } else {
      delete claims.admin;
    }
    await admin.auth().setCustomUserClaims(uid, claims);
    logger.info(
      `Admin claim ${isAdmin ? "granted" : "revoked"} for ${hashUid(uid)}`
    );
  } catch (err) {
    // A missing auth user (e.g. a stray admins doc) shouldn't crash the trigger.
    logger.error(
      `Failed to sync admin claim for ${hashUid(uid)}: ${String(err)}`
    );
  }
}

export const onAdminGranted = onDocumentCreated(
  "admins/{uid}",
  async (event) => {
    await setAdminClaim(event.params.uid, true);
  }
);

export const onAdminRevoked = onDocumentDeleted(
  "admins/{uid}",
  async (event) => {
    await setAdminClaim(event.params.uid, false);
  }
);
