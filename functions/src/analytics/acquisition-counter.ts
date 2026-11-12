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

// Kill switch: false makes the deployed trigger count nothing.
export const ACQUISITION_COUNTER_ENABLED = true;

/** Bumped when the day document's shape changes. */
export const ACQUISITION_SCHEMA_VERSION = 2;

/**
 * Who the tally can count, stored on every day document so a reader cannot
 * take it for an install or sign-up count.
 *
 * V1 (days before [SCOPE_V2_FROM]): signed-in users with analytics consent
 * who opened a UTM link.
 * V2: non-guest accounts created at most [NEW_USER_WINDOW_MS] before their
 * row was written, with analytics consent, whose channel the app learned
 * from a link or from Google Play.
 */
export const ACQUISITION_SCOPE_V1 = "consented-signed-in-utm";
export const ACQUISITION_SCOPE = "consented-new-account-channel";

/**
 * First UTC day written under V2. A day document is written with
 * `merge: true`, so one scope per day keeps earlier counts from being
 * relabelled by the switch.
 */
export const SCOPE_V2_FROM = "2026-11-14";

/** A row counts only if its account is at most this much older than the row. */
export const NEW_USER_WINDOW_MS = 7 * 24 * 60 * 60 * 1000;

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
  "google-play",
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
  | "guest"
  | "not_new_user"
  | "source_gone";

export interface AcquisitionCountEvent {
  uid: string;
  /** The event's own time, used only when the row has no `firstSeenAt` Timestamp. */
  eventTime: string;
}

/** The part of the Admin Auth user record the counter reads. */
export interface AuthAccount {
  providerData: readonly unknown[];
  metadata: { creationTime?: string };
}

export interface AcquisitionCountDeps {
  db: admin.firestore.Firestore;
  /** Returns null when the account no longer exists. */
  getAccount: (uid: string) => Promise<AuthAccount | null>;
}

/** Test seam — the trigger body with Firestore injected. */
export async function countAcquisition(
  event: AcquisitionCountEvent,
  deps: AcquisitionCountDeps,
): Promise<AcquisitionCountOutcome> {
  const { db } = deps;
  // A guest is an account with no sign-in provider. Any client can mint one
  // per +1, so a guest never counts, and an account that is not new is not a
  // new user for the channel.
  const account = await deps.getAccount(event.uid);
  if (account == null) {
    logger.info("acquisition_counter", { outcome: "source_gone" });
    return "source_gone";
  }
  if (account.providerData.length === 0) {
    logger.info("acquisition_counter", { outcome: "guest" });
    return "guest";
  }
  const createdMs = Date.parse(account.metadata.creationTime ?? "");
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
    const rowMs = Number.isFinite(ms) ? ms : Date.now();
    const date = formatUtcDate(rowMs);
    const v2 = date >= SCOPE_V2_FROM;
    if (v2 && !(Number.isFinite(createdMs) && rowMs - createdMs <= NEW_USER_WINDOW_MS)) {
      return "not_new_user";
    }

    const { source: src, medium } = normaliseAttribution(source.data());
    tx.set(
      // A literal group, so the reset's writer scan can name the series.
      dailyDocRef(db, "acquisition", date),
      {
        date,
        v: v2 ? ACQUISITION_SCHEMA_VERSION : 1,
        scope: v2 ? ACQUISITION_SCOPE : ACQUISITION_SCOPE_V1,
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
      { db: admin.firestore(), getAccount: (uid) => accountLookup(uid) },
    );
  },
);

let accountLookup: (uid: string) => Promise<AuthAccount | null> = getAuthAccount;

/** Test seam for the deployed handler, which has no Auth emulator behind it. */
export function setAccountLookupForTest(
  lookup: ((uid: string) => Promise<AuthAccount | null>) | null,
): void {
  accountLookup = lookup ?? getAuthAccount;
}

/** Exported with the Auth object as a parameter so a test can drive each error code. */
export async function getAuthAccountWith(
  auth: { getUser: (uid: string) => Promise<AuthAccount> },
  uid: string,
): Promise<AuthAccount | null> {
  try {
    return await auth.getUser(uid);
  } catch (e) {
    const code = (e as { code?: string }).code;
    if (code === "auth/user-not-found" || code === "auth/invalid-uid") return null;
    throw e;
  }
}

function getAuthAccount(uid: string): Promise<AuthAccount | null> {
  return getAuthAccountWith(admin.auth(), uid);
}

/**
 * How many accounts have said yes to analytics, written to today's day
 * document so a reader of the tally can see what it is a share of. Only the
 * number is stored. It is a `count()` aggregation, so it bills about one read
 * per thousand matching index entries and never reads a uid.
 */
export async function runAcquisitionEligibleSnapshot(
  deps: { db?: admin.firestore.Firestore; now?: Date } = {},
): Promise<number> {
  const db = deps.db ?? admin.firestore();
  const date = formatUtcDate((deps.now ?? new Date()).getTime());
  const agg = await db
    .collectionGroup("consent")
    .where("purposes.analytics", "==", true)
    .count()
    .get();
  const analyticsConsented = agg.data().count;
  await dailyDocRef(db, "acquisition", date).set(
    { date, eligible: { analyticsConsented } },
    { merge: true },
  );
  logger.info("acquisition_eligible_snapshot", { date });
  return analyticsConsented;
}
