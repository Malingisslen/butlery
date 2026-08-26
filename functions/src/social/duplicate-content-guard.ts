/**
 * Server-side duplicate-content rejection for comments + chat.
 *
 * Triggers on `recipe_comments/{commentId}` and `messages/{messageId}` — the
 * latter TOP-LEVEL, which it was not until BUT-1898; see the note on
 * `guardDuplicateMessage` below. Computes a content hash and rejects the new
 * doc if the same hash was already submitted by the same user within the
 * configured window (default: 5 min).
 *
 * The two surfaces are NOT symmetric, and the asymmetry is the decision:
 *
 *   · COMMENTS — key is `authorId:body`, global per user, no length floor, no
 *     flag, and rejection DELETES. Those five settings are unchanged since
 *     2026-05-04. The duplicate TEST underneath them did change in BUT-1898
 *     (ordering rather than event id, and entries stamped from the document's
 *     own createTime), for both surfaces — so "unchanged" is about the
 *     surface's settings, not about the whole code path.
 *   · CHAT — key is `conversationId:authorId:body`, a 12-character floor, a
 *     Remote Config kill switch that ships OFF, and rejection MARKS rather than
 *     deletes. Chat is higher-velocity and its most-repeated strings ("ok",
 *     "ja") are conversation rather than spam, so the comment surface's
 *     settings would stop ordinary messages.
 *
 * WHY CHAT MARKS AND COMMENTS DELETE (BUT-1904, ADR-0009). A deleted chat
 * message is indistinguishable, to the person who sent it, from the app losing
 * it — and the commonest reason anybody sends the same text twice is believing
 * the first send failed. So a rejected chat message is emptied and stamped
 * `duplicateBlocked` instead: the text leaves Firestore, the document stays, and
 * the sender's own client draws a localized row in its place. Keeping the
 * document is also what removes the `syncConversationLastMessage` race that
 * BUT-1898 shipped with — nothing on this path disappears any more, so no
 * trigger can be left pointing at a document that no longer exists.
 * Do NOT "simplify" the two surfaces back into one action.
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
 * chat and the least likely to be spam, so a guard without a floor stops
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

/**
 * The `type` a rejected CHAT message carries once the guard has emptied it
 * (BUT-1904). Exported so the one other trigger on this collection —
 * `syncConversationLastMessage` — spells it the same way; two string literals
 * for one wire value is how a preview starts showing blocked rows.
 *
 * The Dart side is `MessageType.duplicateBlocked`, serialized by `.name`, so
 * this string and that enum value must stay identical.
 */
export const DUPLICATE_BLOCKED_TYPE = "duplicateBlocked";

/**
 * Whether a message document is one the CHAT guard could act on at all.
 *
 * ONE definition, two callers, and that is the point: `guardDuplicateMessage`
 * uses it to decide whether to open a transaction, and
 * `syncConversationLastMessage` uses it to decide whether a CREATE is worth
 * re-reading before it projects a preview. That trigger re-reads on every
 * update it might act on regardless — an update can be edited out of candidacy
 * between the create and the mark, which is a hole it measured and closed.
 *
 * Written twice, the two would drift and the sync trigger would start
 * trusting a payload the guard is about to rewrite.
 *
 * The `type` test is what keeps the group system rows out: they carry
 * `type: "system"` and `senderId: "system"`, so without it every group in the
 * app would collide on one hash. Recipe shares, images and polls are exempt for
 * a different reason — the same share sent twice is a legitimate repeat. Do not
 * widen the type filter without thinking about the system rows again: the key
 * has a conversation component now, but those rows would still share an author.
 *
 * An ABSENT, null or empty `type` counts as text, matching the create rule,
 * which requires `senderId`, `conversationId`, `content` and `sentAt` but never
 * `type`.
 *
 * The length floor is measured after `.trim().normalize("NFC")`, the same
 * expression the hash uses — an NFD string counts a combining mark as its own
 * character, so the identical visible message would otherwise sit on different
 * sides of the floor depending on the sender's keyboard.
 */
export function isChatDuplicateCandidate(data: {
  type?: string;
  content?: string;
  conversationId?: string;
}): boolean {
  // Truthiness, not an `!== undefined` test. A stored `null` or `""` counts
  // as text — the shape the trigger has always guarded, and an `!== undefined`
  // test silently flipped both to SKIPPED when this moved into a shared
  // predicate. Measured by the cloud-functions gate on this change.
  if (data.type && data.type !== "text") return false;
  if (!data.content) return false;
  if (!data.conversationId) return false;
  return data.content.trim().normalize("NFC").length >= MIN_CHAT_BODY_CHARS;
}

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
 * window collides and the second is rejected — an ordinary chat pattern, not
 * spam. Chat passes the conversation id; comments pass nothing and keep the
 * global key they have run on in production since 2026-05-04.
 */
export function computeDuplicateHash(
  authorId: string,
  body: string,
  scope?: string,
): string {
  // NFC before casefolding. Two clients can send the same visible Swedish word
  // as different byte sequences — å is ONE code point in NFC and two in NFD,
  // so "då" is two and three
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
      //
      // STRICT `<`, and it must stay strict — but NOT for the reason an
      // earlier draft of this comment gave. That draft said a `<=` flip would
      // delete a message on redelivery, because the first delivery's entry is
      // stamped exactly at the bound. Measured: it would not. The `selfWrite`
      // fast path in `evaluateAndRecord` matches that entry on `eventId`
      // FIRST and returns `retry-noop`, and that is the only case in which an
      // entry can sit exactly on the bound for the same event. A fast path
      // upstream had made the boundary unreachable, so the stated failure was
      // not the one a flip would produce.
      //
      // What `<=` would actually do is REJECT one of two DIFFERENT messages
      // with the same hash created in the same millisecond — the inverse.
      // (Rejection is a delete on the comment surface and a mark on the chat
      // surface since BUT-1904; this comparator is shared and does not care.)
      // One, not both: a rejected document returns before `appendAndPrune`,
      // so it never writes its own entry and cannot condemn its twin back.
      //
      // The strictness still matters, for the reason `RecentHash.eventId`
      // already states: this test is specified to hold ON ITS OWN, with that
      // field absent. Do not lean on the fast path to make the comparator
      // safe. `duplicate-content-guard.test.ts` has a fixture sitting exactly
      // on the boundary for this, and it is the only thing anywhere that
      // tells `<` from `<=` — measured: the flipped comparator passes the
      // whole of `duplicate-message-guard.integration.test.ts` (9/9) and
      // every other case in the unit suite.
      //
      // The residual, unchanged: those same-millisecond twins both survive,
      // because the stamp is truncated to milliseconds ON BOTH SIDES of the
      // comparison — by this code, not by Firestore. `createTime` itself
      // carries sub-millisecond precision, so `.toMillis()` in
      // `selfCreatedAtMs` and `Timestamp.fromMillis` on the entry are where it
      // dies. Said precisely because "createTime is ms-truncated" would send a
      // fixer looking for precision that is already there.
      //
      // Measured 2026-08-19, eight writes against the emulator: every
      // `createTime.nanoseconds` was divisible by 1000 and every one carried a
      // non-zero sub-millisecond remainder (e.g. 33354000 = 33ms + 354µs). So
      // the sub-ms precision is MEASURED; that Firestore stores commit stamps
      // at microsecond granularity in PRODUCTION is inferred from its
      // documented Timestamp precision, not measured here.
      //
      // It fails toward not-rejecting. Two routes close it, and neither is a
      // comparator flip:
      //
      //   · store `createTime` itself instead of `Timestamp.fromMillis` — the
      //     precision dies in the WRITE, not in the compare, so touching only
      //     the comparator buys nothing;
      //   · or tiebreak at equal stamps on `eventId`, which is already on
      //     the entry.
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
  /**
   * What rejection DOES. `delete` destroys the document; `mark` empties it and
   * stamps `DUPLICATE_BLOCKED_TYPE`, leaving the row in place so the sender's
   * client can draw a reason where the message sat. See the file header for why
   * the two surfaces differ (BUT-1904).
   */
  rejectAction: "delete" | "mark";
}): Promise<"accepted" | "rejected" | "retry-noop" | "gone"> {
  const {
    authorId,
    body,
    docRef,
    surface,
    windowMs,
    eventId,
    selfCreatedAtMs,
    scope,
    rejectAction,
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
    // reject the user's legitimate doc on retry.
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
      if (rejectAction === "delete") {
        // Reject: delete the just-created doc so it never reaches readers.
        tx.delete(docRef);
      } else {
        // Reject by MARKING (BUT-1904). The text is what must not reach the
        // other participants, so `content` is emptied here rather than in any
        // client: the row that survives carries no message, and the sentence
        // the sender reads is drawn from their own app's ARB.
        //
        // `tx.update`, never `tx.set(..., {merge: true})`: a sender who deletes
        // the message between the create and this trigger must not have it
        // written back, and a merge-set would RESURRECT it. That property comes
        // from the VERB, not from the read below — measured: `tx.update` on a
        // missing document throws NOT_FOUND and the document stays absent. An
        // earlier version of this comment credited the read for it.
        //
        // What the READ buys is the difference between a clean no-op and a
        // burnt transaction attempt plus a spurious `logger.error` on an
        // ordinary user action. Inside the branch because the accept path must
        // not pay for it; Firestore only requires that every read precede every
        // write, and no write has happened yet.
        const live = await tx.get(docRef);
        if (!live.exists) {
          logger.debug(
            `[duplicate-content-guard] ${surface} ${docRef.id} vanished ` +
              `before it could be marked (event=${eventId})`,
          );
          return "gone" as const;
        }
        tx.update(docRef, {
          type: DUPLICATE_BLOCKED_TYPE,
          content: "",
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
      }
      // BUT-1822 / accepted-deviations: a `direct_` conversation id is two
      // raw uids, and this line only started carrying one when BUT-1898
      // repointed the chat trigger. The author uid is hashed for the same
      // reason — both are stable handles that still correlate across lines.
      logger.info(
        `[duplicate-content-guard] Rejected (${rejectAction}) ${surface} from ` +
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
        // Unchanged since 2026-05-04. BUT-1904 changed the CHAT action only.
        rejectAction: "delete",
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
 * REJECTION MARKS, IT DOES NOT DELETE (BUT-1904, ADR-0009). The message is
 * emptied and stamped `DUPLICATE_BLOCKED_TYPE`; the sender's own client draws a
 * localized row where it sat, and no other participant is shown anything. The
 * file header carries the reasoning.
 *
 * RACE WITH `syncConversationLastMessage`. That trigger is `onDocumentWritten`
 * on the same collection, so it wakes on this create, on our mark, and on every
 * read receipt and edit that follows — with no ordering guarantee between those
 * invocations, each holding its own captured payload. Two things stop it
 * landing wrong: a marked message still EXISTS, so no preview can point at a
 * destroyed document; and that trigger re-reads inside its transaction before
 * projecting, so a payload we are in the middle of rewriting cannot win a race
 * against the invocation that sees the finished state. Both halves live over
 * there — see its own header, which is also where the two measured holes in
 * earlier versions of this fix are recorded. Do not reintroduce a delete on
 * this path without reading that trigger first.
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
    if (!senderId || !content) return;

    // The conversation id is the duplicate key's scope. A message without one
    // is SKIPPED rather than falling back to the author-only key: the create
    // rule guarantees the field for client writes, but Admin-SDK writers
    // bypass rules, and a silent fallback lands on exactly the global key
    // BUT-1898 exists to remove — it would fail to the unsafe side. Warned
    // separately from the candidate test below, which returns false for the
    // same input but cannot say why.
    if (!conversationId) {
      logger.warn(
        "[duplicate-content-guard] Message has no conversationId; skipping",
        { messageId: event.params.messageId },
      );
      return;
    }

    // Type filter and length floor, both BEFORE any Firestore work — the
    // floor is the panel's false-positive condition and FinOps's cost
    // condition in one: short acknowledgements are the most-repeated and
    // least-spammy strings in a real chat, and a one-word reply must never
    // open a transaction. `isChatDuplicateCandidate` holds the reasoning and
    // is shared with `syncConversationLastMessage` (BUT-1904).
    if (!isChatDuplicateCandidate({ type, content, conversationId })) return;

    // The kill switch. Ships OFF. BUT-1904 landed the sender-visible signal
    // that it was waiting on, so the condition holding it off is met — but
    // turning it on is an explicit decision, not an implication of that.
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
        rejectAction: "mark",
      });
    } catch (err) {
      logger.error("[duplicate-content-guard] Message evaluation failed", err);
    }
  },
);
