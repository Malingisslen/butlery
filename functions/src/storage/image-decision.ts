/**
 * BUT-818 step 2: the decision the owner gets when SafeSearch stops their
 * image (DSA Art. 17: a statement of reasons, that it was automated, and a
 * way to appeal).
 *
 * The decision is an ordinary `reports` case, created already closed, so the
 * existing decision record, inbox row, "Beslut om mitt innehåll" listing and
 * appeal flow carry it unchanged.
 *
 * One upload can stop several objects at once (a recipe photo, its
 * thumbnail, the server's public copy), so every image stopped for the same
 * owner inside one window shares a case: the owner gets one decision and one
 * appeal for the upload. The case id is random, because it becomes the id of
 * the decision record, which is kept after an erasure and must not be
 * derivable from the uid. The window's case is found through a pointer object
 * under the owner's own quarantine prefix, which the account erasure deletes
 * with the rest of it.
 *
 * The report never holds an object path either: a path carries the uid, and
 * the erasure's anonymiser clears only `contentOwnerId`. The quarantined
 * object names its case in its metadata instead.
 */

import { randomBytes } from "crypto";
import * as admin from "firebase-admin";
import type { Bucket } from "@google-cloud/storage";
import { recordDecision } from "../moderation/report-decision";
import { isAutomatedImageReport, REPORTS, SAFE_SEARCH_SOURCE } from "../moderation/report-status";
import { AUTOMATED_IMAGE_MOTIVATION } from "../moderation/motivation";
import { appealRef } from "../moderation/appeals";
import { Notice } from "../moderation/moderation-notices";
import { quarantineStoragePrefix } from "../account/cascade/storage";

export const EXPLICIT_IMAGE_REASON = "explicit_image";
export const IMAGE_CONTENT_TYPE = "image";

/** Long enough to hold a photo, its thumbnail and its public copy. */
export const GROUP_WINDOW_MS = 10 * 60 * 1000;

/** The folder of window pointers inside an owner's quarantine prefix. */
export const CASE_POINTER_DIR = ".cases/";

const REPORT_ID_PATTERN = /^safesearch_[0-9a-f]{24}$/;

export function isImageReportId(value: unknown): value is string {
  return typeof value === "string" && REPORT_ID_PATTERN.test(value);
}

export function newImageReportId(): string {
  return `safesearch_${randomBytes(12).toString("hex")}`;
}

export function casePointerPath(ownerUid: string, now: Date): string {
  return `${quarantineStoragePrefix(ownerUid)}${CASE_POINTER_DIR}${Math.floor(now.getTime() / GROUP_WINDOW_MS)}`;
}

const POINTER_PATTERN = /^quarantine\/users\/[^/]+\/\.cases\/[^/]+$/;

/**
 * Decided on metadata, not the name alone: a client can upload to
 * `users/{uid}/.cases/x.jpg`, and every quarantined image carries the
 * server-written `reportId` that a pointer never has.
 */
export function isCasePointer(file: {
  name: string;
  metadata?: { metadata?: Record<string, unknown> | null };
}): boolean {
  return POINTER_PATTERN.test(file.name) && file.metadata?.metadata?.reportId === undefined;
}

function isOwnCase(data: admin.firestore.DocumentData | undefined, ownerUid: string): boolean {
  return isAutomatedImageReport(data) && data?.contentOwnerId === ownerUid;
}

/**
 * The case this image joins. The pointer is created with a generation
 * precondition, so images stopped at the same moment agree on one case.
 * A later image gets a case of its own once the owner has appealed the
 * window's case: a granted appeal must not restore an image nobody judged.
 */
export async function chooseReportId(
  db: admin.firestore.Firestore,
  bucket: Bucket,
  ownerUid: string,
  now: Date,
): Promise<string> {
  const pointer = bucket.file(casePointerPath(ownerUid, now));
  const fresh = newImageReportId();
  let existing = await readPointer(pointer);
  if (existing === null) {
    try {
      await pointer.save(fresh, {
        contentType: "text/plain",
        resumable: false,
        preconditionOpts: { ifGenerationMatch: 0 },
      });
      return fresh;
    } catch (err) {
      if ((err as { code?: unknown })?.code !== 412) throw err;
    }
    existing = await readPointer(pointer);
  }
  if (!isImageReportId(existing)) return fresh;
  const appeal = await appealRef(db, existing, "owner").get();
  return appeal.exists ? fresh : existing;
}

async function readPointer(pointer: ReturnType<Bucket["file"]>): Promise<string | null> {
  try {
    const [bytes] = await pointer.download();
    return bytes.toString("utf8");
  } catch (err) {
    if ((err as { code?: unknown })?.code === 404) return null;
    throw err;
  }
}

export interface ImageDecisionDeps {
  db: admin.firestore.Firestore;
  push: (notices: Notice[]) => Promise<void>;
}

/**
 * Creates the closed case if it is missing, then records the decision.
 * Both steps are idempotent, so a second image joining the case, or a
 * redelivery, records nothing new and pushes nothing.
 */
export async function fileImageDecision(
  input: { reportId: string; ownerUid: string; now: Date },
  deps: ImageDecisionDeps,
): Promise<"recorded" | "already_recorded"> {
  const { reportId, ownerUid, now } = input;
  const ref = deps.db.collection(REPORTS).doc(reportId);
  const report = {
    reporterId: null,
    contentOwnerId: ownerUid,
    contentType: IMAGE_CONTENT_TYPE,
    // The case itself: an object path would carry the uid (see header).
    contentId: reportId,
    reason: EXPLICIT_IMAGE_REASON,
    source: SAFE_SEARCH_SOURCE,
    status: "closed",
    moderatorAction: "content_removed",
    motivation: AUTOMATED_IMAGE_MOTIVATION,
    createdAt: admin.firestore.Timestamp.fromDate(now),
  };
  try {
    await ref.create(report);
  } catch (err) {
    if ((err as { code?: unknown })?.code !== 6) throw err; // ALREADY_EXISTS
    const existing = await ref.get();
    // Ids are random, but a decision recorded on a document someone else
    // wrote would tell its author about this image.
    if (!isOwnCase(existing.data(), ownerUid)) throw new Error("image case id taken");
  }
  const { outcome, notices } = await recordDecision(deps.db, {
    reportId,
    report,
    decidedAt: now,
    authType: "system",
    authId: undefined,
  });
  await deps.push(notices);
  return outcome;
}
