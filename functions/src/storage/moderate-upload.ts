/**
 * BUT-780: Cloud Storage `onObjectFinalized` trigger that verifies uploaded
 * objects match a known image format by magic-byte signature.
 *
 * Why magic-byte over Content-Type alone:
 * - The Storage rule already restricts `contentType` to a whitelist
 *   (image/jpeg|png|webp|heic|heif), but a malicious client can spoof
 *   Content-Type. The bytes themselves don't lie.
 * - SVG-with-embedded-script is the canonical XSS vector here; the rule
 *   layer rejects `image/svg+xml`, this CF rejects bytes that LOOK like SVG
 *   regardless of declared MIME.
 *
 * **Out of scope (deferred):** SafeSearch via Vision API. That's a paid GCP
 * call (~$0.0015/image) with billing implications and a privacy-policy
 * disclosure requirement; tracked separately. This CF is the byte-level
 * gate; a future SafeSearch CF would be a sibling trigger on the same
 * `onObjectFinalized` event.
 *
 * Behavior on mismatch:
 * - Delete the object via Admin SDK (bypasses rules).
 * - Write an `audit_logs` entry with `operation: 'storage_upload_rejected'`
 *   and the rejection reason. Subject = uploader UID (read from object
 *   metadata `uploadedBy` when present, falls back to inferring from the
 *   object name path `users/{uid}/...`).
 */

import { onObjectFinalized, StorageEvent } from "firebase-functions/v2/storage";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import type { Bucket } from "@google-cloud/storage";

// First few bytes of supported formats. Source:
// - JPEG:  FF D8 FF
// - PNG:   89 50 4E 47 0D 0A 1A 0A
// - WebP:  RIFF........WEBP  (52 49 46 46 .. 57 45 42 50 at bytes 0-3 + 8-11)
// - HEIC/HEIF: bytes 4-11 = "ftypheic" / "ftypheix" / "ftypmif1" / "ftypmsf1" / "ftyphevc" / "ftyphevx"
//
// Keep this set in sync with `storage.rules` `isValidImage()` allow-list.
const SUPPORTED = ["jpeg", "png", "webp", "heic"] as const;
type SupportedFormat = typeof SUPPORTED[number];

// Read enough to cover the longest signature we check (HEIF ftyp box at
// bytes 4-11 needs 12 bytes; round up to 32 for headroom against future
// additions like AVIF if we ever opt back in).
const HEAD_BYTES = 32;

/**
 * Returns the format detected from the magic bytes, or null when the
 * payload doesn't match any supported format. Public for unit tests.
 */
export function detectFormat(head: Buffer): SupportedFormat | null {
  if (head.length < 4) return null;

  // JPEG — FF D8 FF
  if (head[0] === 0xff && head[1] === 0xd8 && head[2] === 0xff) return "jpeg";

  // PNG — 89 50 4E 47 0D 0A 1A 0A
  if (
    head.length >= 8 &&
    head[0] === 0x89 &&
    head[1] === 0x50 &&
    head[2] === 0x4e &&
    head[3] === 0x47 &&
    head[4] === 0x0d &&
    head[5] === 0x0a &&
    head[6] === 0x1a &&
    head[7] === 0x0a
  ) {
    return "png";
  }

  // WebP — RIFF....WEBP (size in bytes 4-7, format marker at bytes 8-11)
  if (
    head.length >= 12 &&
    head.toString("ascii", 0, 4) === "RIFF" &&
    head.toString("ascii", 8, 12) === "WEBP"
  ) {
    return "webp";
  }

  // HEIC / HEIF — ftyp box at bytes 4-11. Several brand codes count as HEIC.
  if (head.length >= 12 && head.toString("ascii", 4, 8) === "ftyp") {
    const brand = head.toString("ascii", 8, 12);
    if (
      brand === "heic" ||
      brand === "heix" ||
      brand === "mif1" ||
      brand === "msf1" ||
      brand === "hevc" ||
      brand === "hevx"
    ) {
      return "heic";
    }
  }

  return null;
}

/** Map a content-type to the SupportedFormat label used by `detectFormat`. */
function contentTypeToFormat(ct: string | undefined): SupportedFormat | null {
  switch (ct) {
    case "image/jpeg":
    case "image/jpg":
      return "jpeg";
    case "image/png":
      return "png";
    case "image/webp":
      return "webp";
    case "image/heic":
    case "image/heif":
      return "heic";
    default:
      return null;
  }
}

/**
 * Infer the uploader uid from the object metadata or the object path.
 * Object path conventions in storage.rules:
 *   users/{uid}/avatars/...
 *   users/{uid}/recipes/...
 *   shared/recipes/{recipeId}/... — uploader UID is in metadata.uploadedBy
 *   feedback/{uid}/...
 */
export function resolveUploaderUid(
  metadata: Record<string, string> | undefined,
  objectName: string | undefined
): string | null {
  if (metadata?.uploadedBy) return metadata.uploadedBy;
  if (!objectName) return null;
  const parts = objectName.split("/");
  if (parts[0] === "users" && parts.length >= 2) return parts[1] || null;
  if (parts[0] === "feedback" && parts.length >= 2) return parts[1] || null;
  return null;
}

interface RejectArgs {
  bucket: string;
  name: string;
  contentType: string | undefined;
  uploaderUid: string | null;
  reason: string;
}

async function rejectAndAudit(
  args: RejectArgs,
  bucketHandle: Bucket
): Promise<void> {
  const file = bucketHandle.file(args.name);
  try {
    await file.delete({ ignoreNotFound: true });
  } catch (err) {
    logger.error("[moderateUpload] failed to delete rejected object", {
      bucket: args.bucket,
      name: args.name,
      err,
    });
    // Continue to audit anyway — the rejection record is more important than
    // the cleanup; ops can re-run a sweep if delete fails.
  }

  // Storage rules only permit writes under uid-keyed paths, so an unresolvable
  // uid signals either rule drift or an Admin SDK upload bypassing the gate.
  // Log at error level so the alert pipeline catches a sustained spike.
  if (!args.uploaderUid) {
    logger.error("[moderateUpload] rejected upload with unresolvable uploader", {
      bucket: args.bucket,
      name: args.name,
      reason: args.reason,
    });
  }

  await admin.firestore().collection("audit_logs").add({
    userId: args.uploaderUid ?? "unknown",
    operation: "storage_upload_rejected",
    resourceType: "storage_object",
    resourceId: args.name,
    granted: false,
    timestamp: admin.firestore.FieldValue.serverTimestamp(),
    metadata: {
      bucket: args.bucket,
      contentType: args.contentType ?? null,
      reason: args.reason,
    },
  });

  logger.warn("[moderateUpload] rejected upload", {
    bucket: args.bucket,
    name: args.name,
    contentType: args.contentType,
    uploaderUid: args.uploaderUid,
    reason: args.reason,
  });
}

export const moderateUpload = onObjectFinalized(
  {
    region: "europe-west1",
    memory: "256MiB",
    timeoutSeconds: 60,
  },
  async (event: StorageEvent) => {
    const obj = event.data;
    const name = obj.name;
    if (!name) return; // pathologically empty event; nothing to act on.

    // ML models bucket prefix is read-only and only written by ops tooling
    // (signed-in admin context). Skip; nothing to validate at the byte level
    // and downloading large model files just to no-op is wasteful.
    if (name.startsWith("models/")) return;

    const bucketName = obj.bucket;
    const contentType = obj.contentType;
    const uploaderUid = resolveUploaderUid(obj.metadata, name);

    const declared = contentTypeToFormat(contentType);
    if (declared === null) {
      // The Storage rule should have rejected this at write time. If we
      // see it here, either the rule was bypassed (admin SDK upload) or
      // the rule changed without the CF being updated. Reject in both
      // cases — keep the two layers in agreement.
      await rejectAndAudit(
        {
          bucket: bucketName,
          name,
          contentType,
          uploaderUid,
          reason: "unsupported_content_type",
        },
        admin.storage().bucket(bucketName)
      );
      return;
    }

    const bucket = admin.storage().bucket(bucketName);
    let head: Buffer;
    try {
      const [downloaded] = await bucket
        .file(name)
        .download({ start: 0, end: HEAD_BYTES - 1 });
      head = downloaded;
    } catch (err) {
      logger.error("[moderateUpload] failed to read head bytes", {
        bucket: bucketName,
        name,
        err,
      });
      // Fail open — don't punish the user for a transient Admin SDK glitch.
      // The Storage rule already enforced the contentType allow-list at
      // write time, so the worst case here is a missing CF audit row.
      return;
    }

    const detected = detectFormat(head);
    if (detected === null) {
      await rejectAndAudit(
        {
          bucket: bucketName,
          name,
          contentType,
          uploaderUid,
          reason: "magic_byte_unrecognized",
        },
        bucket
      );
      return;
    }

    if (detected !== declared) {
      await rejectAndAudit(
        {
          bucket: bucketName,
          name,
          contentType,
          uploaderUid,
          reason: `magic_byte_mismatch_declared_${declared}_actual_${detected}`,
        },
        bucket
      );
      return;
    }

    // Happy path — content type matches the bytes. No further action;
    // SafeSearch (deferred) would slot in here when added.
  }
);
