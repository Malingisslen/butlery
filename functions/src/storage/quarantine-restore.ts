/**
 * BUT-818 step 2: what happens to a quarantined image after its decision.
 *
 * - A granted owner appeal copies each image of the case back to where it
 *   was, with its original download token, so the URL the app stored works
 *   again. The verdict for those bytes is overridden first, so the upload
 *   trigger the copy fires lets them through.
 * - A weekly sweep deletes quarantined images once the appeal window is over
 *   (unless an appeal is still open) and files any decision the upload
 *   trigger failed to file.
 *
 * Objects are found through `quarantine/users/{uid}/` and their `reportId`
 * metadata, which only the server writes.
 */

import { randomUUID } from "crypto";
import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import type { Bucket, File } from "@google-cloud/storage";
import { QUARANTINE_PREFIX, quarantineStoragePrefix } from "../account/cascade/storage";
import { APPELLANT_ID, appealRef, canHoldAppeal, MODERATION_APPEALS } from "../moderation/appeals";
import { MODERATION_DECISIONS } from "../moderation/report-decision";
import { defaultPushDeps, Notice, pushNotices } from "../moderation/moderation-notices";
import { fileImageDecision, isCasePointer, isImageReportId } from "./image-decision";
import { overrideVerdict, scanKey } from "./safe-search";

const TOKEN_KEY = "firebaseStorageDownloadTokens";

/** Custom metadata the quarantine copy carries and the restored image must not. */
const QUARANTINE_KEYS = [
  "originalPath", "ownerUid", "reportId", "originalToken", "adult", "violence", "racy",
];

/**
 * The 183-day appeal window plus margin for an appeal filed on its last day
 * to be seen. Matches the privacy policy's "när tiden för att överklaga har
 * gått ut".
 */
export const QUARANTINE_RETENTION_DAYS = 200;

/** A window pointer is only needed while its window is open. */
const POINTER_RETENTION_MS = 24 * 60 * 60 * 1000;

const DAY_MS = 24 * 60 * 60 * 1000;

function codeOf(err: unknown): unknown {
  return (err as { code?: unknown } | null)?.code ?? null;
}

function customMetadata(file: File): Record<string, unknown> {
  return (file.metadata?.metadata ?? {}) as Record<string, unknown>;
}

export async function caseObjects(bucket: Bucket, ownerUid: string, reportId: string): Promise<File[]> {
  const [files] = await bucket.getFiles({ prefix: quarantineStoragePrefix(ownerUid) });
  return files.filter((file) => customMetadata(file).reportId === reportId);
}

export interface RestoreDeps {
  db: admin.firestore.Firestore;
  bucket: Bucket;
}

/** Set on the owner appeal by `getQuarantinedImages`: what the moderator was shown. */
export const REVIEWED_GENERATIONS = "reviewedGenerations";

/**
 * Restores the case images the moderator was shown, and only those: a case
 * can hold more images than the view returns, and an image nobody looked at
 * must not come back on someone else's verdict. The rest stay in quarantine
 * until the sweep deletes them.
 *
 * Idempotent: a retry finishes an image its earlier attempt copied (the copy
 * still carries our `reportId`), and leaves alone one the owner replaced.
 */
export async function restoreCase(
  input: { reportId: string; ownerUid: string; reviewed: ReadonlySet<string> },
  deps: RestoreDeps,
): Promise<number> {
  const files = (await caseObjects(deps.bucket, input.ownerUid, input.reportId)).filter((file) =>
    input.reviewed.has(String(file.metadata?.generation ?? "")),
  );
  let restored = 0;
  for (const file of files) {
    // The path comes from the object's own name, never from its metadata.
    const path = file.name.slice(QUARANTINE_PREFIX.length);
    const meta = file.metadata ?? {};
    const key = scanKey(meta.md5Hash, meta.crc32c, meta.size as string | number | undefined);
    if (key) await overrideVerdict(deps.db, key);
    const stored = customMetadata(file).originalToken;
    const token = typeof stored === "string" && stored.length > 0 ? stored : randomUUID();
    const dest = deps.bucket.file(path);
    let ours = false;
    try {
      await file.copy(dest, { preconditionOpts: { ifGenerationMatch: 0 } });
      ours = true;
    } catch (err) {
      if (codeOf(err) !== 412) throw err;
      // The copy inherits the quarantine metadata, so our own earlier copy
      // still names this case; an image the owner uploaded since does not.
      const [existing] = await dest.getMetadata();
      ours = (existing.metadata ?? {}).reportId === input.reportId;
    }
    if (ours) {
      await dest.setMetadata({
        metadata: {
          ...Object.fromEntries(QUARANTINE_KEYS.map((k) => [k, null])),
          [TOKEN_KEY]: token,
        },
      });
      restored++;
    }
    // One row per image, however often the event is redelivered; written
    // before the delete, which drops the image from a retry's listing.
    try {
      await deps.db.collection("audit_logs").doc(`restore_${input.reportId}_${meta.generation}`).create({
        userId: input.ownerUid,
        operation: "storage_upload_restored",
        resourceType: "storage_object",
        resourceId: path,
        granted: true,
        timestamp: admin.firestore.FieldValue.serverTimestamp(),
        metadata: { reason: "appeal_reversed", reportId: input.reportId, restored: ours },
      });
    } catch (err) {
      if (codeOf(err) !== 6) throw err; // ALREADY_EXISTS
    }
    await file.delete({ ignoreNotFound: true });
  }
  return restored;
}

/** The part of the trigger event the handler reads. */
export interface AppealEvent {
  data?: {
    before: { data(): admin.firestore.DocumentData | undefined };
    after: { data(): admin.firestore.DocumentData | undefined };
  };
}

export async function handleAppealAnswered(event: AppealEvent, deps: RestoreDeps): Promise<void> {
  const before = event.data?.before.data();
  const after = event.data?.after.data();
  if (!after || after.status !== "reversed" || before?.status === "reversed") return;
  if (after.role !== "owner" || !isImageReportId(after.reportId)) return;
  const owner = after[APPELLANT_ID];
  if (typeof owner !== "string" || owner.length === 0) return;
  const reviewed = new Set<string>(
    (Array.isArray(after[REVIEWED_GENERATIONS]) ? after[REVIEWED_GENERATIONS] : []).map(String),
  );
  let restored: number;
  try {
    restored = await restoreCase({ reportId: after.reportId, ownerUid: owner, reviewed }, deps);
  } catch (err) {
    // A Storage error repeats the object name, which carries the uid.
    logger.error("quarantine_restore_failed", {
      report_prefix: after.reportId.slice(0, 16),
      errorCode: codeOf(err),
    });
    throw new Error("quarantine_restore_failed"); // retry: true redelivers
  }
  logger.info("quarantine_restored", {
    report_prefix: after.reportId.slice(0, 16),
    restored,
    reviewed: reviewed.size,
  });
}

// retry:true — the restore is idempotent, and without a retry a transient
// Storage failure would leave a granted appeal without its image.
export const onImageAppealAnswered = onDocumentUpdated(
  { document: `${MODERATION_APPEALS}/{appealId}`, retry: true },
  (event) =>
    handleAppealAnswered(event, { db: admin.firestore(), bucket: admin.storage().bucket() }),
);

export interface SweepDeps extends RestoreDeps {
  push: (notices: Notice[]) => Promise<void>;
  now?: Date;
}

export interface SweepResult {
  examined: number;
  deleted: number;
  keptForAppeal: number;
  decisionsFiled: number;
  failed: number;
}

export async function sweepQuarantine(deps: SweepDeps): Promise<SweepResult> {
  const now = deps.now ?? new Date();
  const [files] = await deps.bucket.getFiles({ prefix: QUARANTINE_PREFIX });
  const result: SweepResult = {
    examined: files.length, deleted: 0, keptForAppeal: 0, decisionsFiled: 0, failed: 0,
  };
  const decided = new Map<string, boolean>();
  const appealOpen = new Map<string, boolean>();

  for (const file of files) {
    // One failure must not leave every later image past its deletion date.
    try {
      await sweepOne(file, now, result, decided, appealOpen, deps);
    } catch (err) {
      result.failed++;
      logger.warn("quarantine_sweep_item_failed", { errorCode: codeOf(err) });
    }
  }
  return result;
}

async function sweepOne(
  file: File,
  now: Date,
  result: SweepResult,
  decided: Map<string, boolean>,
  appealOpen: Map<string, boolean>,
  deps: SweepDeps,
): Promise<void> {
  if (isCasePointer(file)) {
    const at = Date.parse(String(file.metadata?.timeCreated ?? ""));
    if (Number.isFinite(at) && now.getTime() - at > POINTER_RETENTION_MS) {
      await file.delete({ ignoreNotFound: true });
    }
    return;
  }
  const meta = customMetadata(file);
  const reportId = isImageReportId(meta.reportId) ? meta.reportId : null;
  const created = Date.parse(String(file.metadata?.timeCreated ?? ""));
  const expired = Number.isFinite(created) && now.getTime() - created > QUARANTINE_RETENTION_DAYS * DAY_MS;

  if (expired) {
    if (reportId && canHoldAppeal(reportId, "owner")) {
      if (!appealOpen.has(reportId)) {
        const appeal = await appealRef(deps.db, reportId, "owner").get();
        appealOpen.set(reportId, appeal.get("status") === "open");
      }
      if (appealOpen.get(reportId)) {
        result.keptForAppeal++;
        return;
      }
    }
    await file.delete({ ignoreNotFound: true });
    result.deleted++;
    return;
  }

  // Owner from the path: `quarantine/users/{uid}/...`.
  const owner = file.name.split("/")[2];
  if (!reportId || !owner) return;
  if (!decided.has(reportId)) {
    const record = await deps.db.collection(MODERATION_DECISIONS).doc(reportId).get();
    decided.set(reportId, record.exists);
    if (!record.exists) {
      await fileImageDecision({ reportId, ownerUid: owner, now }, { db: deps.db, push: deps.push });
      result.decisionsFiled++;
    }
  }
}

export async function runQuarantineSweep(): Promise<void> {
  const db = admin.firestore();
  const result = await sweepQuarantine({
    db,
    bucket: admin.storage().bucket(),
    push: (notices) => pushNotices(notices, defaultPushDeps(db)),
  });
  logger.info("quarantine_sweep", { ...result });
}
