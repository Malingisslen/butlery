/**
 * Server-side duplicate-content rejection for comments + chat.
 *
 * Triggers on `recipe_comments/{commentId}` and
 * `conversations/{cid}/messages/{messageId}`. Computes a content hash from
 * `${authorId}:${trimmed-lowercased-body}` and rejects (deletes) the new
 * doc if the same hash was already submitted by the same user within the
 * configured window (default: 5 min).
 *
 * Why server-side and not Firestore rules: rules cannot efficiently
 * inspect time-windowed lists. The trigger writes a small per-user
 * `recentContentHashes` doc whose entries carry timestamps; on every new
 * doc the trigger reads, evaluates, and prunes expired hashes.
 *
 * Failure mode: if the trigger errors, the original doc is left in place
 * (open by default rather than fail closed). The trigger is best-effort
 * spam reduction, not a security gate — content moderation reports
 * (BP1, on-report-created) remain the authoritative complaint channel.
 */

import { onDocumentCreated } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
import * as crypto from "crypto";

// Lazy admin SDK access so this module is import-safe in unit tests that
// only exercise the pure helpers (`computeDuplicateHash`, `isDuplicate`,
// `appendAndPrune`). Calling `admin.firestore()` at module scope crashes
// when the default app hasn't been initialized.
function db(): admin.firestore.Firestore {
  return admin.firestore();
}

const DEFAULT_WINDOW_MS = 5 * 60 * 1000;
const MAX_RECENT_HASHES = 20;

interface RecentHash {
  hash: string;
  at: admin.firestore.Timestamp;
  // Cloud Event id of the trigger that wrote this entry. `onDocumentCreated`
  // is at-least-once, so retries of the same event would otherwise hit
  // their own previously-stored hash and silently delete the user's
  // legitimate doc. Storing the eventId lets the duplicate path detect
  // "this is my own retry" and no-op.
  eventId?: string;
}

interface RecentContentDoc {
  hashes?: RecentHash[];
}

/**
 * Compute the duplicate-detection hash. Truncated SHA-1 keeps the doc
 * small (16 hex chars ≈ 64 bits) — collision probability is negligible
 * within a 20-entry rolling window per user.
 */
export function computeDuplicateHash(authorId: string, body: string): string {
  const normalized = body.trim().toLowerCase();
  return crypto
    .createHash("sha1")
    .update(`${authorId}:${normalized}`)
    .digest("hex")
    .slice(0, 16);
}

/**
 * Determine whether a hash collides with a recent entry. The `eventId`
 * argument is the at-least-once Cloud Event id of the current trigger
 * invocation; entries written by THIS event are filtered out so a retry
 * doesn't see its own previous accept and reclassify the doc as a
 * duplicate (which would silently delete the user's legitimate content).
 *
 * Pure, exported for unit tests.
 */
export function isDuplicate(
  hash: string,
  recent: RecentHash[],
  nowMs: number,
  windowMs: number,
  eventId?: string,
): boolean {
  return recent.some(
    (e) =>
      e.hash === hash &&
      nowMs - e.at.toMillis() < windowMs &&
      // Self-retry guard: skip entries written by this same event.
      (!eventId || e.eventId !== eventId),
  );
}

/**
 * Prune expired entries and append the new one, capped at MAX_RECENT_HASHES.
 * Pure, exported for unit tests.
 */
export function appendAndPrune(
  hash: string,
  recent: RecentHash[],
  now: admin.firestore.Timestamp,
  windowMs: number,
  eventId?: string,
): RecentHash[] {
  const nowMs = now.toMillis();
  const fresh = recent.filter((e) => nowMs - e.at.toMillis() < windowMs);
  fresh.push({ hash, at: now, ...(eventId ? { eventId } : {}) });
  // Keep only the most recent N to bound document size.
  return fresh.slice(-MAX_RECENT_HASHES);
}

async function evaluateAndRecord(args: {
  authorId: string;
  body: string;
  docRef: admin.firestore.DocumentReference;
  surface: "comment" | "chat";
  windowMs: number;
  eventId: string;
}): Promise<"accepted" | "rejected" | "retry-noop"> {
  const { authorId, body, docRef, surface, windowMs, eventId } = args;
  if (!authorId || !body || !body.trim()) return "accepted";

  const hash = computeDuplicateHash(authorId, body);
  const firestore = db();
  const userRecentRef = firestore
    .collection("users")
    .doc(authorId)
    .collection("recentContentHashes")
    .doc("rolling");

  return await firestore.runTransaction(async (tx) => {
    const snap = await tx.get(userRecentRef);
    const data = (snap.data() ?? {}) as RecentContentDoc;
    const recent = (data.hashes ?? []).filter(
      (e): e is RecentHash =>
        !!e && typeof e.hash === "string" && e.at instanceof admin.firestore.Timestamp,
    );

    // Self-retry detection: if THIS exact event already wrote the hash on
    // a previous at-least-once delivery, treat as a no-op so we don't
    // delete the user's legitimate doc on retry.
    const selfWrite = recent.find(
      (e) => e.eventId === eventId && e.hash === hash,
    );
    if (selfWrite) {
      logger.debug(
        `[duplicate-content-guard] Skipping retry of event ${eventId} ` +
          `(${surface}, ${docRef.path})`,
      );
      return "retry-noop" as const;
    }

    const now = admin.firestore.Timestamp.now();
    if (isDuplicate(hash, recent, now.toMillis(), windowMs, eventId)) {
      // Reject: delete the just-created doc so it never reaches readers.
      tx.delete(docRef);
      logger.info(
        `[duplicate-content-guard] Rejected ${surface} from ${authorId} ` +
          `(hash=${hash}, path=${docRef.path}, event=${eventId})`,
      );
      return "rejected" as const;
    }

    const nextHashes = appendAndPrune(hash, recent, now, windowMs, eventId);
    tx.set(userRecentRef, { hashes: nextHashes }, { merge: true });
    return "accepted" as const;
  });
}

/**
 * Trigger for new recipe comments. Field shape mirrors
 * `lib/models/recipe_comment.dart` (`authorId`, `text`).
 */
export const guardDuplicateComment = onDocumentCreated(
  "recipe_comments/{commentId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const authorId = data.authorId as string | undefined;
    const text = data.text as string | undefined;
    if (!authorId || !text) return;

    try {
      await evaluateAndRecord({
        authorId,
        body: text,
        docRef: event.data!.ref,
        surface: "comment",
        windowMs: DEFAULT_WINDOW_MS,
        eventId: event.id,
      });
    } catch (err) {
      // Open-by-default: leave the comment intact if the guard errors.
      logger.error("[duplicate-content-guard] Comment evaluation failed", err);
    }
  },
);

/**
 * Trigger for new chat messages. Field shape mirrors
 * `lib/repositories/firebase/dtos/message_dto.dart` (`senderId`, `content`).
 */
export const guardDuplicateMessage = onDocumentCreated(
  "conversations/{conversationId}/messages/{messageId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const senderId = data.senderId as string | undefined;
    const content = data.content as string | undefined;
    const type = data.type as string | undefined;
    // Only text messages are subject to dup detection — recipe shares,
    // images, polls etc. are exempt because the same recipe-share is a
    // legitimate repeat send.
    if (type && type !== "text") return;
    if (!senderId || !content) return;

    try {
      await evaluateAndRecord({
        authorId: senderId,
        body: content,
        docRef: event.data!.ref,
        surface: "chat",
        windowMs: DEFAULT_WINDOW_MS,
        eventId: event.id,
      });
    } catch (err) {
      logger.error("[duplicate-content-guard] Message evaluation failed", err);
    }
  },
);
