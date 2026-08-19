/**
 * Server-side duplicate-content rejection for comments + chat.
 *
 * Triggers on `recipe_comments/{commentId}` and `messages/{messageId}` — the
 * latter TOP-LEVEL, which it was not until BUT-1898; see the note on
 * `guardDuplicateMessage` below. Computes a content hash and rejects (deletes)
 * the new doc if the same hash was already submitted by the same user within
 * the configured window (default: 5 min).
 *
 * The two surfaces are NOT symmetric, and the asymmetry is the decision:
 *
 *   · COMMENTS — key is `authorId:body`, global per user, no length floor, no
 *     flag. Those four settings are unchanged since 2026-05-04. The duplicate
 *     TEST underneath them did change in BUT-1898 (ordering rather than event
 *     id, and entries stamped from the document's own createTime), for both
 *     surfaces — so "unchanged" is about the surface's settings, not about the
 *     whole code path.
 *   · CHAT — key is `conversationId:authorId:body`, a 12-character floor, and a
 *     Remote Config kill switch that ships OFF. Chat is higher-velocity and its
 *     most-repeated strings ("ok", "ja") are conversation rather than spam, so
 *     the comment surface's settings would delete ordinary messages.
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
import { hashUid } from "../shared/hash-uid";
import { logSafeConversationId } from "../messaging/enforce-group-minor-membership";
import { isChatDuplicateGuardEnabled } from "./duplicate-message-flag";

// Lazy admin SDK access so this module is import-safe in unit tests that
// only exercise the pure helpers (`computeDuplicateHash`, `isDuplicate`,
// `appendAndPrune`). Calling `admin.firestore()` at module scope crashes
// when the default app hasn't been initialized.
function db(): admin.firestore.Firestore {
  return admin.firestore();
}

const DEFAULT_WINDOW_MS = 5 * 60 * 1000;
const MAX_RECENT_HASHES = 20;

/**
 * BUT-1898. Bodies shorter than this are never duplicate-checked on the CHAT
 * surface, and the check happens BEFORE the transaction opens.
 *
 * Two conditions from the same panel land on this one number. Trust & Safety
 * and Product: "ok", "ja", "nej", "?" are the most-repeated strings in a real
 * chat and the least likely to be spam, so a guard without a floor deletes
 * ordinary conversation. FinOps: a one-word reply must never open a Firestore
 * transaction.
 *
 * 12 is a judgement call. Measured `.trim().normalize("NFC").length` — the
 * same expression the check below uses, which matters because NFD counts a
 * combining mark separately ("okej då" is 7 in NFC and 8 in NFD) — on the
 * common Swedish
 * acknowledgements: "?" 1, "ok"/"ja" 2, "nej" 3, "haha" 4, "okej då" 7 — all
 * under the floor. Just above it: "ja det gör jag" and "tack så mycket" at 14,
 * which are the shortest strings a person might repeat and would rather keep.
 * There is no corpus of real chat to fit this to, so treat the number as
 * tunable rather than as a finding.
 *
 * Comments are NOT floored: the surface has run in production since 2026-05-04
 * with no floor, a duplicate one-word comment is spam rather than conversation,
 * and changing a live surface is not this ticket.
 */
const MIN_CHAT_BODY_CHARS = 12;

interface RecentHash {
  hash: string;
  at: admin.firestore.Timestamp;
  // Cloud Event id of the trigger that wrote this entry. `onDocumentCreated`
  // is at-least-once, so a redelivery must not mistake its own earlier accept
  // for somebody else's duplicate.
  //
  // This is now the FAST PATH only, not the protection (BUT-1898). It used to
  // be both, and that was the defect: the lookup is only as durable as
  // `MAX_RECENT_HASHES`, so once 20 later messages evicted the entry, a
  // redelivery found the one written by the user's legitimate resend and
  // deleted a message that had already been delivered and read. The real
  // guarantee is the ordering test in `isDuplicate`, which works with this
  // field absent.
  eventId?: string;
}

interface RecentContentDoc {
  hashes?: RecentHash[];
}

/**
 * Compute the duplicate-detection hash. Truncated SHA-1 keeps the doc
 * small (16 hex chars ≈ 64 bits) — collision probability is negligible
 * within a 20-entry rolling window per user.
 *
 * `scope` (BUT-1898) narrows the key beyond the author. Without it the key is
 * global per user, so the same text sent to two DIFFERENT people within the
 * window collides and the second is deleted — an ordinary chat pattern, not
 * spam. Chat passes the conversation id; comments pass nothing and keep the
 * global key they have run on in production since 2026-05-04.
 */
export function computeDuplicateHash(
  authorId: string,
  body: string,
  scope?: string,
): string {
  // NFC before casefolding. Two clients can send the same visible Swedish word
  // as different byte sequences — "då" is one code point in NFC and two in NFD
  // — and without this they hash differently, so switching normalisation form
  // is a one-line evasion. Measured: the two forms have different `.length`
  // too, which means NFD text also sits differently against the chat surface's
  // 12-character floor.
  const normalized = body.trim().normalize("NFC").toLowerCase();
  const keyed = scope ? `${scope}:${authorId}` : authorId;
  return crypto
    .createHash("sha1")
    .update(`${keyed}:${normalized}`)
    .digest("hex")
    .slice(0, 16);
}

/**
 * Determine whether a hash collides with a recent entry.
 *
 * `selfCreatedAtMs` is the CANDIDATE DOCUMENT's own server-assigned
 * `createTime`, and it is what makes this at-least-once-safe: only an entry
 * recorded BEFORE the document existed can condemn it. A redelivery re-derives
 * the identical bound, so the entry written by an earlier accept of the same
 * event — or by any LATER message — can never classify it as a duplicate.
 *
 * The invariant this rests on lives in `appendAndPrune`'s CALLER: an entry is
 * stamped with its own creating document's `createTime`, not with the time the
 * trigger ran. Both sides of the comparison then come from Firestore's clock.
 * `duplicate-message-guard.integration.test.ts` case D9 pins that stamping
 * directly, because it is the one property everything else here assumes. NOT
 * the unit suite of this file's own name — that one hands these helpers their
 * timestamps by hand and never reaches the caller, so it cannot see the
 * stamping at all. An earlier draft of this sentence named it anyway, which
 * would have told a future reader the invariant was still guarded after D9 was
 * moved or deleted.
 *
 * Pure, exported for unit tests.
 */
export function isDuplicate(
  hash: string,
  recent: RecentHash[],
  nowMs: number,
  windowMs: number,
  selfCreatedAtMs: number,
): boolean {
  return recent.some(
    (e) =>
      e.hash === hash &&
      nowMs - e.at.toMillis() < windowMs &&
      // Only an entry recorded BEFORE this document existed can condemn it.
      //
      // This replaced an `eventId !== self` filter (BUT-1898). That version
      // was only as durable as the 20-entry cap: once the accepted delivery's
      // own entry was evicted by 20 later messages, an at-least-once
      // REDELIVERY of that same event found the entry written by the user's
      // legitimate resend, called it a duplicate, and deleted a message that
      // had already been delivered and read. The very failure the eventId was
      // introduced to prevent, re-armed by eviction.
      //
      // An ordering test cannot be evicted into being wrong: every redelivery
      // re-derives the same bound from the document's own server-assigned
      // creation time, so an entry written by a LATER message can never
      // condemn an earlier one.
      e.at.toMillis() < selfCreatedAtMs,
  );
}

/**
 * Prune expired entries and append the new one, capped at MAX_RECENT_HASHES.
 * Pure, exported for unit tests.
 */
export function appendAndPrune(
  hash: string,
  recent: RecentHash[],
  /**
   * The stamp the new entry carries, and the origin for pruning. Named `now`
   * until BUT-1898; the only production caller passes the creating DOCUMENT's
   * `createTime`, not the time the trigger ran, so pruning is relative to the
   * document. That is deliberate — see `isDuplicate`.
   */
  stampedAt: admin.firestore.Timestamp,
  windowMs: number,
  eventId?: string,
): RecentHash[] {
  const nowMs = stampedAt.toMillis();
  const fresh = recent.filter((e) => nowMs - e.at.toMillis() < windowMs);
  fresh.push({ hash, at: stampedAt, ...(eventId ? { eventId } : {}) });
  // Keep only the most recent N to bound document size.
  return fresh.slice(-MAX_RECENT_HASHES);
}

/**
 * The document's own creation time in ms, from Firestore's server-assigned
 * `createTime` rather than from any body field.
 *
 * Server-assigned and immutable, so every at-least-once redelivery of one
 * event derives the identical value — which is the whole property
 * `isDuplicate`'s ordering test rests on. A body field would not do: `sentAt`
 * is client-supplied on the chat surface, and the comment surface has no
 * equivalent at all.
 *
 * The fallback is `Date.now()`, which cannot be right on a redelivery. It is
 * unreachable in production (every snapshot Firestore hands a trigger carries
 * `createTime`) and exists so a malformed test double degrades to the old
 * behaviour rather than throwing on a live message.
 */
function selfCreatedAtMs(snap: {
  createTime?: { toMillis(): number };
}): number {
  return snap.createTime?.toMillis() ?? Date.now();
}

async function evaluateAndRecord(args: {
  authorId: string;
  body: string;
  docRef: admin.firestore.DocumentReference;
  surface: "comment" | "chat";
  windowMs: number;
  eventId: string;
  /**
   * The document's own server-assigned creation time, in ms. Identical across
   * every redelivery of the same event, which is what makes the duplicate test
   * retry-safe without depending on bookkeeping surviving the cap.
   */
  selfCreatedAtMs: number;
  /** BUT-1898: narrows the key beyond the author. Chat passes the
   * conversation id; comments pass nothing. */
  scope?: string;
}): Promise<"accepted" | "rejected" | "retry-noop"> {
  const {
    authorId,
    body,
    docRef,
    surface,
    windowMs,
    eventId,
    selfCreatedAtMs,
    scope,
  } = args;
  if (!authorId || !body || !body.trim()) return "accepted";

  const hash = computeDuplicateHash(authorId, body, scope);
  const firestore = db();
  // ONE ROLLING DOC PER SURFACE (BUT-1898). `MAX_RECENT_HASHES` is 20 for
  // both, so a shared document would let chat — the higher-velocity surface —
  // flush every comment hash out of the window within a few minutes and
  // silently weaken a control that has been live since 2026-05-04. No cross-
  // surface false positive was ever possible (a chat key carries a
  // conversation component, a comment key does not), so this is about
  // detection strength, not correctness. `rolling` keeps the comment
  // surface's document byte-identical to what it has always used.
  const userRecentRef = firestore
    .collection("users")
    .doc(authorId)
    .collection("recentContentHashes")
    .doc(surface === "chat" ? "chat" : "rolling");

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
    if (isDuplicate(hash, recent, now.toMillis(), windowMs, selfCreatedAtMs)) {
      // Reject: delete the just-created doc so it never reaches readers.
      tx.delete(docRef);
      // BUT-1822 / accepted-deviations: a `direct_` conversation id is two
      // raw uids, and this line only started carrying one when BUT-1898
      // repointed the chat trigger. The author uid is hashed for the same
      // reason — both are stable handles that still correlate across lines.
      logger.info(
        `[duplicate-content-guard] Rejected ${surface} from ` +
          `${hashUid(authorId)} (hash=${hash}, doc=${docRef.id}` +
          `${scope ? `, conversation=${logSafeConversationId(scope)}` : ""}` +
          `, event=${eventId})`,
      );
      return "rejected" as const;
    }

    // The entry is stamped with the DOCUMENT's creation time, not with
    // `now`. Both sides of `isDuplicate`'s ordering test then come from the
    // same clock — Firestore's.
    //
    // Measured 2026-08-19 across five writes against the emulator, the gap
    // between the server's `createTime` and this process's clock was
    // +273ms (first write, connection setup), +5, +2, -5, +2. It JITTERS IN
    // BOTH DIRECTIONS, single-digit ms once warm. Either sign breaks a
    // millisecond comparison — a server-behind sample makes "the entry I just
    // wrote predates the next message" false and the guard silently stops
    // detecting anything at all. So this is not a margin question that a
    // tolerance would fix; the two values simply have to come from one clock.
    //
    // It also reads better: the entry records when a message with this hash
    // EXISTED, not when the trigger happened to run.
    const nextHashes = appendAndPrune(
      hash,
      recent,
      admin.firestore.Timestamp.fromMillis(selfCreatedAtMs),
      windowMs,
      eventId,
    );
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
        selfCreatedAtMs: selfCreatedAtMs(event.data!),
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
 *
 * BUT-1898: this was registered on `conversations/{conversationId}/messages/
 * {messageId}` from the day it was written (2026-05-04) until 2026-08-19.
 * Every message writer in the repo uses the TOP-LEVEL `messages` collection,
 * and `firestore.rules` has no match block for that subcollection at all, so
 * nothing could ever have written there. The guard never ran once, while
 * reading as an active control.
 *
 * The same wrong-path bug had already been found and fixed once in this very
 * subsystem: BUT-1766 caught the account-deletion cascade sweeping the same
 * dead subcollection, so every account erased since BUT-788 kept its whole
 * chat history while the cascade reported success. If you are here changing a
 * trigger path, check the writers rather than the neighbouring code.
 *
 * RACE WITH `syncConversationLastMessage`, and it is narrower than it looks.
 * That trigger is `onDocumentWritten` on the same collection, so both wake on
 * this create with no ordering guarantee between them, each working from its
 * own captured payload rather than re-reading. Its DELETE branch recomputes
 * the preview, so the ordinary interleaving self-corrects. The one that sticks
 * is: our delete lands, the sync trigger processes that delete, and only THEN
 * the sync trigger's CREATE-side invocation writes `lastMessage` from its
 * stale payload — pointing at a document that no longer exists, with nothing
 * left to fire and fix it. The preview stays wrong until the next real message
 * in that conversation. Not fixed here; the flag exists partly so this can be
 * turned off if it shows up.
 */
export const guardDuplicateMessage = onDocumentCreated(
  "messages/{messageId}",
  async (event) => {
    const data = event.data?.data();
    if (!data) return;
    const senderId = data.senderId as string | undefined;
    const content = data.content as string | undefined;
    const type = data.type as string | undefined;
    const conversationId = data.conversationId as string | undefined;
    // Only text messages are subject to dup detection — recipe shares,
    // images, polls etc. are exempt because the same recipe-share is a
    // legitimate repeat send. This is also what keeps the group system rows
    // ("X har lagts till i gruppen") out: they carry `type: "system"` and
    // `senderId: "system"`, so without this line every group in the app would
    // collide on one hash. Do not widen the type filter without giving the key
    // a conversation component first — it has one now, but the system rows
    // would still share an author.
    if (type && type !== "text") return;
    if (!senderId || !content) return;

    // The conversation id is the duplicate key's scope. A message without one
    // is SKIPPED rather than falling back to the author-only key: the create
    // rule guarantees the field for client writes, but Admin-SDK writers
    // bypass rules, and a silent fallback lands on exactly the global key
    // BUT-1898 exists to remove — it would fail to the unsafe side.
    if (!conversationId) {
      logger.warn(
        "[duplicate-content-guard] Message has no conversationId; skipping",
        { messageId: event.params.messageId },
      );
      return;
    }

    // Cheapest checks first, both BEFORE any Firestore work.
    //
    // The length floor is the panel's condition and FinOps's in one: short
    // acknowledgements are the most-repeated and least-spammy strings in a
    // real chat, and a one-word reply must never open a transaction.
    // Normalised before measuring, for the same reason the hash is: an NFD
    // string counts a combining mark as its own character, so the identical
    // visible message would sit on different sides of the floor depending on
    // the sender's keyboard.
    if (content.trim().normalize("NFC").length < MIN_CHAT_BODY_CHARS) return;

    // The kill switch. Ships OFF, and per the plan it stays off until a
    // sender-visible signal exists — a deleted message currently just
    // vanishes, with nothing in the app to explain it.
    if (!(await isChatDuplicateGuardEnabled())) return;

    try {
      await evaluateAndRecord({
        authorId: senderId,
        body: content,
        docRef: event.data!.ref,
        surface: "chat",
        windowMs: DEFAULT_WINDOW_MS,
        eventId: event.id,
        selfCreatedAtMs: selfCreatedAtMs(event.data!),
        scope: conversationId,
      });
    } catch (err) {
      logger.error("[duplicate-content-guard] Message evaluation failed", err);
    }
  },
);
