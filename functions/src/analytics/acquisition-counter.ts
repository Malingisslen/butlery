/**
 * BUT-1997: an anonymous per-day tally of acquisition attribution, kept when
 * the account that contributed to it is erased (the BUT-1789 split: the
 * per-user row goes, the uid-free aggregate stays).
 *
 * Counts `users/{uid}/acquisition/current` once, into
 * `analytics/acquisition/daily/{UTC date of firstSeenAt}`, and only when the
 * user's `users/{uid}/consent/current` has `purposes.analytics == true` at the
 * time the trigger runs. A user without that consent is never counted, even
 * if a client wrote the row anyway.
 *
 * The aggregate carries no uid, no hash of one, no event id and no per-user
 * time; its map keys come only from the allowlists below, so no client-chosen
 * text reaches it.
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import { dailyDocRef, formatUtcDate } from "./daily-snapshots";

// Stays false until Malin approves and the privacy-policy sentence is
// published (BUT-1997 release gate): until then a deployed trigger counts nothing.
export const ACQUISITION_COUNTER_ENABLED = false;

/** Bumped when the day document's shape changes. */
export const ACQUISITION_SCHEMA_VERSION = 1;

/**
 * Who the tally can count: signed-in users with analytics consent who opened
 * a UTM link. Stored on every day document so a reader cannot take it for an
 * install or sign-up count.
 */
export const ACQUISITION_SCOPE = "consented-signed-in-utm";

/** The bucket for anything not on an allowlist. */
export const OTHER = "other";

/** Values longer than this are never matched against an allowlist. */
export const MAX_ATTRIBUTION_LENGTH = 100;

/** `utm_source` values counted by name. Everything else counts as `other`. */
export const SOURCE_ALLOWLIST: ReadonlySet<string> = new Set([
  "instagram",
  "facebook",
  "tiktok",
  "google",
  "newsletter",
  "email",
  "friend_invite",
]);

/** `utm_medium` values counted by name. Everything else counts as `other`. */
export const MEDIUM_ALLOWLIST: ReadonlySet<string> = new Set([
  "social",
  "paid_social",
  "cpc",
  "email",
  "referral",
  "organic",
]);

export interface Bucket {
  key: string;
  /** A value was present but is not on the allowlist. */
  unmapped: boolean;
}

/**
 * Maps a raw attribution value to an allowlisted key or `other`. Never
 * throws: a missing, empty, non-string or over-long value is `other`.
 */
export function bucketFor(raw: unknown, allowlist: ReadonlySet<string>): Bucket {
  if (raw === undefined || raw === null) return { key: OTHER, unmapped: false };
  if (typeof raw !== "string") return { key: OTHER, unmapped: true };
  const value = raw.trim().toLowerCase();
  if (value.length === 0) return { key: OTHER, unmapped: false };
  if (value.length > MAX_ATTRIBUTION_LENGTH) return { key: OTHER, unmapped: true };
  return allowlist.has(value) ? { key: value, unmapped: false } : { key: OTHER, unmapped: true };
}

export function normaliseAttribution(raw: admin.firestore.DocumentData | undefined): {
  source: Bucket;
  medium: Bucket;
} {
  return {
    source: bucketFor(raw?.source, SOURCE_ALLOWLIST),
    medium: bucketFor(raw?.medium, MEDIUM_ALLOWLIST),
  };
}

export type AcquisitionCountOutcome =
  | "counted"
  | "already_counted"
  | "no_consent"
  | "source_gone";

export interface AcquisitionCountEvent {
  uid: string;
  /** The event's own time, used only when the row has no `firstSeenAt` Timestamp. */
  eventTime: string;
}

export interface AcquisitionCountDeps {
  db: admin.firestore.Firestore;
}

/** Test seam — the trigger body with Firestore injected. */
export async function countAcquisition(
  event: AcquisitionCountEvent,
  deps: AcquisitionCountDeps,
): Promise<AcquisitionCountOutcome> {
  const { db } = deps;
  const sourceRef = db.collection("users").doc(event.uid).collection("acquisition").doc("current");
  const consentRef = db.collection("users").doc(event.uid).collection("consent").doc("current");
  const inc = admin.firestore.FieldValue.increment;

  const outcome = await db.runTransaction(async (tx): Promise<AcquisitionCountOutcome> => {
    const [source, consent] = await tx.getAll(sourceRef, consentRef);
    if (!source.exists) return "source_gone";
    if (source.get("countedAt") != null) return "already_counted";
    if (!consent.exists || consent.get("purposes.analytics") !== true) return "no_consent";

    const firstSeenAt = source.get("firstSeenAt");
    const ms = firstSeenAt instanceof admin.firestore.Timestamp
      ? firstSeenAt.toMillis()
      : Date.parse(event.eventTime);
    const date = formatUtcDate(Number.isFinite(ms) ? ms : Date.now());

    const { source: src, medium } = normaliseAttribution(source.data());
    tx.set(
      // A literal group, so the reset's writer scan can name the series.
      dailyDocRef(db, "acquisition", date),
      {
        date,
        v: ACQUISITION_SCHEMA_VERSION,
        scope: ACQUISITION_SCOPE,
        total: inc(1),
        bySource: { [src.key]: inc(1) },
        byMedium: { [medium.key]: inc(1) },
        unmapped: {
          source: inc(src.unmapped ? 1 : 0),
          medium: inc(medium.unmapped ? 1 : 0),
        },
      },
      { merge: true },
    );
    tx.update(sourceRef, { countedAt: admin.firestore.FieldValue.serverTimestamp() });
    return "counted";
  });

  logger.info("acquisition_counter", { outcome });
  return outcome;
}

// retry:true — the `countedAt` stamp is written in the same transaction as
// the increment, so a redelivery after a commit finds it and counts nothing.
// Malformed attribution is bucketed as `other`, never thrown.
export const onAcquisitionCreated = onDocumentCreated(
  { document: "users/{uid}/acquisition/current", retry: true },
  async (event) => {
    if (!ACQUISITION_COUNTER_ENABLED) {
      logger.info("acquisition_counter", { outcome: "disabled" });
      return;
    }
    await countAcquisition(
      { uid: event.params.uid, eventTime: event.time },
      { db: admin.firestore() },
    );
  },
);
