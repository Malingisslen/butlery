/**
 * BUT-818: Vision SafeSearch on uploaded images, paid per call — so each
 * distinct image is sent at most once.
 *
 * The verdict is cached under the object's content checksums, so the server's
 * copy of a recipe photo into `public_recipes/` and the same photo uploaded
 * again read the cache. A failed call caches nothing, so the image is
 * scanned the next time those bytes arrive.
 */

import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";

/** Server-only; firestore.rules' default deny keeps clients out. */
export const SAFE_SEARCH_SCANS = "safe_search_scans";

const LIKELIHOODS = [
  "UNKNOWN",
  "VERY_UNLIKELY",
  "UNLIKELY",
  "POSSIBLE",
  "LIKELY",
  "VERY_LIKELY",
] as const;
export type Likelihood = typeof LIKELIHOODS[number];

export interface SafeSearchScores {
  adult: Likelihood;
  violence: Likelihood;
  racy: Likelihood;
}

/** Takes a `gs://` URI so the image bytes never pass through the function. */
export type SafeSearchAnnotate = (gcsUri: string) => Promise<SafeSearchScores>;

/**
 * The client returns enum names, but a raw proto number is accepted too so a
 * change in the client's enum encoding cannot read as "UNKNOWN" everywhere.
 */
export function toLikelihood(value: unknown): Likelihood {
  if (typeof value === "number") return LIKELIHOODS[value] ?? "UNKNOWN";
  if (typeof value === "string" && (LIKELIHOODS as readonly string[]).includes(value)) {
    return value as Likelihood;
  }
  return "UNKNOWN";
}

function atLeast(value: Likelihood, floor: Likelihood): boolean {
  return LIKELIHOODS.indexOf(value) >= LIKELIHOODS.indexOf(floor);
}

/**
 * Racy needs VERY_LIKELY because Vision's racy class is broad enough to flag
 * ordinary food photos (sausages, meat, fruit) at LIKELY.
 */
export function isExplicit(scores: SafeSearchScores): boolean {
  return (
    atLeast(scores.adult, "LIKELY") ||
    atLeast(scores.violence, "LIKELY") ||
    atLeast(scores.racy, "VERY_LIKELY")
  );
}

/**
 * Only `users/` holds images other people can be shown. `feedback/` is seen
 * by the admin alone and `corpus/` is written by the admin, so scanning them
 * would be paid for with nothing to protect.
 */
export function shouldScan(name: string): boolean {
  return name.startsWith("users/");
}

/**
 * md5 alone collides on demand, so a harmless image could pre-seed a clean
 * verdict for an explicit one with the same md5. crc32c is linear, so the two
 * halves of an md5 collision differ in it too, and size closes the rest. A
 * server-side copy keeps all three. Hex because base64 holds `/`.
 */
export function scanKey(
  md5Base64: string | undefined,
  crc32cBase64: string | undefined,
  size: string | number | undefined
): string | null {
  if (!md5Base64 || !crc32cBase64 || size === undefined || size === "") return null;
  const md5 = Buffer.from(md5Base64, "base64").toString("hex");
  const crc = Buffer.from(crc32cBase64, "base64").toString("hex");
  if (md5.length !== 32 || crc.length !== 8) return null;
  return `${md5}_${crc}_${size}`;
}

export interface ScanInput {
  bucketName: string;
  name: string;
  md5Hash: string | undefined;
  crc32c: string | undefined;
  size: string | number | undefined;
}

export interface ScanResult {
  scores: SafeSearchScores;
  explicit: boolean;
  cached: boolean;
}

export interface ScanDeps {
  db: admin.firestore.Firestore;
  annotate: SafeSearchAnnotate;
  /** Seam: the unit suite does not wait out real seconds. */
  sleep?: (ms: number) => Promise<void>;
}

/**
 * A claim on a key while its Vision call runs, so the public copy that
 * syncPublicRecipe makes seconds after the upload waits for the verdict
 * instead of paying for its own call. A claim older than this is a crashed
 * run and is taken over.
 */
export const LEASE_MS = 60_000;
const POLL_MS = 2_000;
const POLLS = 10;

function codeOf(err: unknown): unknown {
  return (err as { code?: unknown } | null)?.code ?? null;
}

/**
 * Set on a verdict when the moderator granted the owner's appeal, so the
 * restored bytes are let through instead of being quarantined again.
 */
export const APPEAL_OVERRIDE = "appeal";

function verdictOf(snap: { exists: boolean; get(field: string): unknown }): ScanResult | null {
  if (!snap.exists || snap.get("explicit") === undefined) return null;
  const scores: SafeSearchScores = {
    adult: toLikelihood(snap.get("adult")),
    violence: toLikelihood(snap.get("violence")),
    racy: toLikelihood(snap.get("racy")),
  };
  const overridden = snap.get("overriddenBy") === APPEAL_OVERRIDE;
  return { scores, explicit: !overridden && isExplicit(scores), cached: true };
}

/**
 * Marks these bytes as allowed. Scores are kept so the false positive stays
 * measurable. Written before the image is copied back, so the upload trigger
 * the copy fires reads it.
 */
export async function overrideVerdict(
  db: admin.firestore.Firestore,
  key: string,
): Promise<void> {
  await db.collection(SAFE_SEARCH_SCANS).doc(key).set(
    {
      explicit: false,
      overriddenBy: APPEAL_OVERRIDE,
      overriddenAt: admin.firestore.FieldValue.serverTimestamp(),
    },
    { merge: true },
  );
}

function leaseIsLive(snap: { exists: boolean; get(field: string): unknown }): boolean {
  const at = snap.get("leaseAt");
  return snap.exists && typeof at === "number" && Date.now() - at < LEASE_MS;
}

/** A cached verdict, or whether this caller now holds the claim. */
async function waitForVerdict(
  ref: admin.firestore.DocumentReference,
  sleep: (ms: number) => Promise<void>
): Promise<{ verdict: ScanResult | null; claimed: boolean }> {
  for (let poll = 0; poll <= POLLS; poll++) {
    const snap = await ref.get();
    const verdict = verdictOf(snap);
    if (verdict) return { verdict, claimed: false };
    if (!leaseIsLive(snap)) {
      try {
        if (snap.exists) {
          await ref.update({ leaseAt: Date.now() }, { lastUpdateTime: snap.updateTime });
        } else {
          await ref.create({ leaseAt: Date.now() });
        }
        return { verdict: null, claimed: true };
      } catch (err) {
        // Another caller claimed it between the read and this write.
        if (codeOf(err) !== 6 && codeOf(err) !== 9) throw err;
      }
    }
    if (poll < POLLS) await sleep(POLL_MS);
  }
  // The other caller never finished within the window; a second paid call
  // beats leaving the image unscanned.
  return { verdict: null, claimed: false };
}

/** Null when Vision could not be asked; the caller lets the image stand. */
export async function scanOnce(input: ScanInput, deps: ScanDeps): Promise<ScanResult | null> {
  const key = scanKey(input.md5Hash, input.crc32c, input.size);
  const ref = key ? deps.db.collection(SAFE_SEARCH_SCANS).doc(key) : null;
  const sleep = deps.sleep ?? ((ms) => new Promise<void>((resolve) => setTimeout(resolve, ms)));

  // The cache only saves money; a cache failure must never decide the verdict.
  let cacheUsable = ref !== null;
  let claimed = false;
  if (ref) {
    try {
      const waited = await waitForVerdict(ref, sleep);
      if (waited.verdict) return waited.verdict;
      claimed = waited.claimed;
    } catch (err) {
      cacheUsable = false;
      logger.warn("[safeSearch] cache read failed; scanning anyway", { errorCode: codeOf(err) });
    }
  }

  let scores: SafeSearchScores;
  try {
    scores = await deps.annotate(`gs://${input.bucketName}/${input.name}`);
  } catch (err) {
    // The object path carries the uploader's uid; log the code only.
    logger.error("[safeSearch] Vision call failed; image left unscanned", {
      bucket: input.bucketName,
      errorCode: codeOf(err),
    });
    if (ref && claimed) {
      // Release the claim so the next arrival of these bytes scans at once.
      await ref.delete().catch(() => undefined);
    }
    return null;
  }

  const explicit = isExplicit(scores);
  if (ref && cacheUsable) {
    try {
      await ref.set({
        ...scores,
        explicit,
        scannedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    } catch (err) {
      logger.warn("[safeSearch] cache write failed; verdict still applied", {
        errorCode: codeOf(err),
      });
    }
  }
  return { scores, explicit, cached: false };
}

let visionClient: import("@google-cloud/vision").ImageAnnotatorClient | null = null;

/**
 * Production annotate. The client is loaded on first use, because every
 * function in this codebase loads index.ts and only this trigger needs Vision.
 * The EU endpoint keeps the image's processing inside the EU.
 */
export const visionAnnotate: SafeSearchAnnotate = async (gcsUri) => {
  // Vision cannot fetch from the Storage emulator, so a call would only wait
  // out the credential lookup before failing.
  if (process.env.FIREBASE_STORAGE_EMULATOR_HOST) {
    throw Object.assign(new Error("Storage emulator object"), { code: "emulator" });
  }
  if (!visionClient) {
    const { ImageAnnotatorClient } = await import("@google-cloud/vision");
    visionClient = new ImageAnnotatorClient({ apiEndpoint: "eu-vision.googleapis.com" });
  }
  const [result] = await visionClient.safeSearchDetection(gcsUri);
  if (result.error?.message) {
    throw Object.assign(new Error(result.error.message), { code: result.error.code ?? null });
  }
  const annotation = result.safeSearchAnnotation;
  // Cached as clean, an empty answer would exempt these bytes for good.
  if (!annotation) throw Object.assign(new Error("no safeSearchAnnotation"), { code: null });
  return {
    adult: toLikelihood(annotation.adult),
    violence: toLikelihood(annotation.violence),
    racy: toLikelihood(annotation.racy),
  };
};
