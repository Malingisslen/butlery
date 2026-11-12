/**
 * BUT-818 step 2: the moderator sees the stopped images of a case before
 * answering the owner's appeal. Admin only.
 *
 * The bytes are returned rather than a signed URL: a signed URL needs the
 * service account to hold signBlob, and would keep working for whoever it
 * reached until it expired. Clients still have no Storage rule that reaches
 * `quarantine/`.
 *
 * Region: inherits europe-west1 via `setGlobalOptions` in index.ts.
 */

import { onCall, CallableRequest, HttpsError } from "firebase-functions/v2/https";
import * as admin from "firebase-admin";
import type { Bucket } from "@google-cloud/storage";
import { enforceRateLimit } from "../middleware/rate_limiter";
import { requireAdmin } from "../shared/require-admin";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";
import { APPELLANT_ID, isSafeDocId, MODERATION_APPEALS } from "../moderation/appeals";
import { isImageReportId } from "./image-decision";
import { caseObjects, REVIEWED_GENERATIONS } from "./quarantine-restore";

export const RATE_LIMIT_KEY = "getQuarantinedImages";

/** A case groups one upload: a photo, its thumbnail and its public copy. */
export const MAX_IMAGES = 8;
/** Base64 grows 4/3, so the budget counts encoded bytes. */
export const MAX_ENCODED_BYTES = 9_000_000;

export interface QuarantinedImage {
  contentType: string;
  base64: string;
}

export interface QuarantinedImagesResponse {
  images: QuarantinedImage[];
  /** Images on this page too large to send at all; they are never restored. */
  omitted: number;
  /** Where the next page starts, or null once every image has been sent. */
  nextOffset: number | null;
}

export interface QuarantineReviewDeps {
  rateLimit: (uid: string, operation: string) => Promise<void>;
  db: admin.firestore.Firestore;
  bucket: Bucket;
}

/** Set once every image of the case has been sent; `answerAppeal` requires it to grant. */
export const REVIEWED_ALL = "reviewedAll";

export function parseRequest(data: unknown): { appealId: string; offset: number } {
  const raw = (data ?? {}) as Record<string, unknown>;
  if (!isSafeDocId(raw.appealId) || !raw.appealId.endsWith("_owner")) {
    throw new HttpsError("invalid-argument", "invalid_appeal_id");
  }
  const offset = raw.offset ?? 0;
  if (typeof offset !== "number" || !Number.isInteger(offset) || offset < 0 || offset > 10_000) {
    throw new HttpsError("invalid-argument", "invalid_offset");
  }
  return { appealId: raw.appealId, offset };
}

export async function handleGetQuarantinedImages(
  request: CallableRequest<unknown>,
  deps: QuarantineReviewDeps,
): Promise<QuarantinedImagesResponse> {
  requireAdmin(request);
  const { appealId, offset } = parseRequest(request.data);
  await deps.rateLimit(request.auth!.uid, RATE_LIMIT_KEY);

  const appeal = await deps.db.collection(MODERATION_APPEALS).doc(appealId).get();
  const reportId = appeal.get("reportId");
  const owner = appeal.get(APPELLANT_ID);
  if (!appeal.exists || !isImageReportId(reportId) || typeof owner !== "string" || !owner) {
    throw new HttpsError("not-found", "no_image_appeal");
  }

  try {
    // Listed in name order, so pages are stable between calls.
    const files = await caseObjects(deps.bucket, owner, reportId);
    const images: QuarantinedImage[] = [];
    const shown: string[] = [];
    let omitted = 0;
    let encoded = 0;
    let index = offset;
    for (; index < files.length; index++) {
      const file = files[index];
      const cost = Math.ceil(Number(file.metadata?.size ?? 0) / 3) * 4;
      if (cost > MAX_ENCODED_BYTES) {
        omitted++;
        continue;
      }
      if (images.length >= MAX_IMAGES || encoded + cost > MAX_ENCODED_BYTES) break;
      const [bytes] = await file.download();
      encoded += cost;
      images.push({
        contentType: String(file.metadata?.contentType ?? "image/jpeg"),
        base64: bytes.toString("base64"),
      });
      shown.push(String(file.metadata?.generation ?? ""));
    }
    const nextOffset = index < files.length ? index : null;
    // A granted appeal restores only these: an image the moderator was never
    // shown must not come back on this verdict. Generations, not names, since
    // names carry the uid.
    const update: Record<string, unknown> = {};
    if (shown.length > 0) update[REVIEWED_GENERATIONS] = admin.firestore.FieldValue.arrayUnion(...shown);
    // Every image the view can send has now been sent, on this call or an
    // earlier one: jumping to the last page does not count as seeing the rest.
    const prior = appeal.get(REVIEWED_GENERATIONS);
    const seen = new Set<string>([...(Array.isArray(prior) ? prior.map(String) : []), ...shown]);
    const viewable = files.filter((f) => Math.ceil(Number(f.metadata?.size ?? 0) / 3) * 4 <= MAX_ENCODED_BYTES);
    // Non-empty: a case of only oversize images has nothing a grant could restore.
    if (viewable.length > 0 && viewable.every((f) => seen.has(String(f.metadata?.generation ?? "")))) {
      update[REVIEWED_ALL] = true;
    }
    if (Object.keys(update).length > 0) await appeal.ref.update(update);
    return { images, omitted, nextOffset };
  } catch (err) {
    // A Storage error repeats the object name, which carries the uid.
    throw new HttpsError("internal", "quarantine_read_failed", {
      code: String((err as { code?: unknown })?.code ?? ""),
    });
  }
}

export const getQuarantinedImages = onCall(
  {
    timeoutSeconds: 30,
    memory: "512MiB",
    cors: WEB_CALLABLE_ORIGINS,
    enforceAppCheck: true,
  },
  (request) =>
    handleGetQuarantinedImages(request, {
      rateLimit: (uid, operation) => enforceRateLimit(uid, operation),
      db: admin.firestore(),
      bucket: admin.storage().bucket(),
    }),
);
