/**
 * BUT-778: server-side replacement for the deprecated `ConversationAutoHealerModule`
 * client-side listener swarm. Previously, every conversation rendered into a
 * user's list spawned a per-conversation `messages` snapshot listener (~50 per
 * active user, 520k concurrent at 10k DAU) just to keep
 * `conversation.lastMessage` in sync.
 *
 * This trigger does the same job server-side, once per message write:
 * - On message create: set `conversation.lastMessage` if the new message is
 *   newer than what's stored.
 * - On message update: same, so an edit also refreshes the preview.
 * - On message delete: if the deleted message WAS the lastMessage, recompute
 *   from the remaining messages (or clear `lastMessage` if the conversation
 *   is now empty, or if the surviving message carries no resolved `sentAt`).
 * - On a message this trigger SEES carrying the blocked mark: same as a
 *   delete. The document survives (BUT-1904), and projecting it would put
 *   either an empty preview or — for a row a client stamped itself — the very
 *   text the mark exists to remove into everybody's conversation list.
 *   "Sees", not "is": the create side gates its re-read on candidacy, so a
 *   client-stamped row whose text was never a duplicate candidate can still
 *   reach `lastMessage` through a stale create-shaped invocation. Only a
 *   client can produce that — the guard marks candidates only, and reads the
 *   same payload the gate does — and the row is the sender's own, in their own
 *   conversation, so the outcome is what not stamping it would have given.
 *
 * THE RACE WITH `guardDuplicateMessage`, and how it is closed here (BUT-1904).
 * Both triggers wake on the same create with no ordering guarantee, and the
 * guard's mark wakes this one a second time — as does every read receipt and
 * every edit on the same message. Left alone, ANY of those invocations could
 * land last and project the payload it captured before the guard rewrote the
 * document. Two things prevent it:
 *
 *   1. the blocked test below reads `after.type` DIRECTLY, before and
 *      independent of any eligibility gate — the mark's own invocation arrives
 *      already carrying `duplicateBlocked`, so a gated test would never see it;
 *   2. the trigger RE-READS the message inside this transaction before
 *      projecting it. The read takes part in the transaction, so a concurrent
 *      commit by the guard aborts and retries this one rather than letting a
 *      stale payload win. Creates pay for it only when the guard could act on
 *      them; updates pay whenever they survived the cheap gate, because an
 *      update can be edited out of candidacy before it lands.
 *
 * Every invocation therefore computes from the same finished state, whichever
 * lands last. Removing either half re-opens the race on its own, and the
 * integration suite has a case per half.
 *
 * What those cases prove is ORDERING — a stale payload replayed after the mark
 * has committed. A genuinely CONCURRENT commit is not something the suite can
 * stage; the abort-and-retry behaviour it would exercise was measured by hand
 * against the emulator instead. Ordering is the interleaving that actually
 * occurred in practice.
 *
 * Idempotent. Uses a Firestore transaction so concurrent message writes for
 * the same conversation can't clobber each other into a stale state.
 *
 * Cost vs. the client healer: ~one CF invocation per message write (cheap and
 * bounded by user activity), zero per-listener Firestore charges, and works
 * even when the client is offline. Replaces ~520k concurrent listeners at
 * 10k DAU with ~N invocations where N = total messages/sec.
 */

import { onDocumentWritten } from "firebase-functions/v2/firestore";
import { logger } from "firebase-functions/logger";
import * as admin from "firebase-admin";
// BUT-1872: a DIRECT conversation id is `direct_<uidA>_<uidB>` — two raw uids.
// One helper, so every logger on a conversation path hashes it the same way.
import { logSafeConversationId } from "./enforce-group-minor-membership";
// BUT-1904: the OTHER trigger on this collection decides what counts as a
// blocked row and which creates it can rewrite. Importing both from there is
// what stops the two triggers drifting apart — see `isChatDuplicateCandidate`.
import {
  DUPLICATE_BLOCKED_TYPE,
  isChatDuplicateCandidate,
} from "../social/duplicate-content-guard";

/**
 * How many of the newest messages the recompute path scans for a previewable
 * survivor. More than one because the newest can itself be blocked (BUT-1904);
 * bounded because this is a per-invocation Firestore read on a rare path.
 */
const SURVIVOR_SCAN_LIMIT = 5;

interface MessageWireFields {
  conversationId?: string;
  senderId?: string;
  content?: string;
  type?: string;
  status?: string;
  sentAt?: admin.firestore.Timestamp;
}

/**
 * Returns true when `candidate` should replace `current` as the conversation's
 * lastMessage. Newer `sentAt` wins; ties (same timestamp) prefer the candidate
 * — message edits land with the same `sentAt` and need to overwrite the
 * stored snapshot to refresh the preview text.
 *
 * `current.sentAt` is typed as a Timestamp but is read back off a stored
 * document, so it can be anything a past write left there. Measured
 * 2026-08-19: a stored STRING is truthy, so the old `!current?.sentAt` test
 * let it through to `current.sentAt.toMillis()` and threw — which froze that
 * conversation's preview permanently, since every later message write hit the
 * same line. An unusable stored stamp is now always replaceable, so a real
 * message heals the document instead of dying on it.
 *
 * That heal is TYPE-SCOPED and stops there — do not read the sentence above as
 * "a real message always heals the preview". A stored stamp that IS a Timestamp
 * but sits far in the future is never replaced, because the comparison below is
 * `>=`. `conversations.lastMessage` is a denormalised copy of `sentAt` that the
 * conversations update rule does not name, so a participant can plant exactly
 * that state directly, without going near the messages create rule and its
 * BUT-1903 bound. Raised by the firestore-rules-tester gate; its own ticket.
 * The client's own next send does clear it: `MessageMutationModule` merge-sets
 * `lastMessage` with no comparison at all, and `MessageDto.toMap` emits `sentAt`
 * unconditionally, so the poisoned stamp is overwritten. (A merge is DEEP, so
 * only the keys that map emits are replaced — `sentAt` always is, which is what
 * makes this hold.) The freeze therefore lasts until the next message in that
 * conversation rather than forever — indefinite in a quiet one.
 */
export function shouldReplaceLastMessage(
  current: { sentAt?: admin.firestore.Timestamp } | null | undefined,
  candidateSentAt: admin.firestore.Timestamp
): boolean {
  if (!(current?.sentAt instanceof admin.firestore.Timestamp)) return true;
  return candidateSentAt.toMillis() >= current.sentAt.toMillis();
}

/**
 * Build the embedded `lastMessage` map written to the conversation doc.
 * Mirrors the shape `MessageDto.fromMap` reads on the client.
 *
 * Call it only with a resolved `sentAt` (BUT-1853): the client substitutes
 * `clock.now()` for a missing one, which defeats the group history cut-off.
 * The `?? null` below is a type fallback, not a licence to skip that check.
 */
function projectLastMessage(messageId: string, data: MessageWireFields) {
  return {
    id: messageId,
    conversationId: data.conversationId ?? null,
    senderId: data.senderId ?? null,
    content: data.content ?? "",
    type: data.type ?? "text",
    status: data.status ?? "sent",
    sentAt: data.sentAt ?? null,
  };
}

/**
 * BUT-1903's measuring instrument, and the ONLY reason it exists.
 *
 * The create rule now refuses a `sentAt` more than an hour ahead of the server.
 * That hour is a chosen ceiling, not a measured skew figure — there is no field
 * data, because the app has no users. This line collects the data that lets a
 * follow-up ticket replace the guess with a number.
 *
 * REMOVAL IS NOT A JUDGEMENT CALL: delete this function and its call site in the
 * SAME change that tightens the bound. Left in place it is a per-message log
 * line billed forever for a question already answered.
 *
 * What it can and cannot see. A message the rule DENIES is never written, so
 * this post-write trigger cannot observe the denied population at all — it
 * measures the ALLOWED distribution, which is what decides whether an hour is
 * too tight or too loose. The denied side is covered by the client's own
 * breadcrumb (`MessageSendErrorMapper`). Do not cite this log alone.
 *
 * CREATE ONLY. The trigger is `onDocumentWritten` and an edit keeps the
 * original `sentAt`, so an ungated line would re-log the same delta on every
 * edit and bias the distribution it exists to measure.
 *
 * Bucket label only — no uid, no conversation id, no message id. A `direct_`
 * conversation id is two raw uids (accepted-deviations, BUT-1822), and a
 * distribution needs none of them.
 *
 * Reading the output: `createTime` is assigned at COMMIT, strictly after the
 * `request.time` the rule compares against, so a rule-admitted message cannot
 * produce a delta above the hour. `ahead_gt_1h` should therefore be EMPTY, and
 * a sample in it means a rules-BYPASSING create — an Admin-SDK writer that is
 * not a system row, a one-shot backfill script being the realistic one; a
 * MANAGED Firestore import fires no triggers at all and so cannot produce a
 * sample either way. Never a device that beat the rule.
 *
 * That claim was narrower than a first draft said, and applying the system-row
 * gate below is what narrowed it: the gate excludes the only Admin-SDK creator
 * of `messages` rows this repo has, and a row predating BUT-1903 can never be
 * sampled at all, because this fires at CREATE and an existing document is
 * never re-created.
 *
 * The `min <= 60` boundary in `clockSkewBucket` is load-bearing for that claim,
 * not merely a bucketing choice — and the reason is narrower than it looks.
 * Because `createTime` is assigned strictly AFTER `request.time`, a bound-
 * admitted message's delta is at most 60 minutes and usually just under; it
 * reaches exactly 60 only when the two stamps truncate to the same millisecond,
 * which they can, since `toMillis()` drops nanoseconds. That case is the whole
 * coupling: flipping the comparison to `< 60` would file it under
 * `ahead_gt_1h` and make the paragraph above false.
 */
function clockSkewBucket(deltaMs: number): string {
  const min = deltaMs / 60000;
  if (min < -60) return "behind_gt_1h";
  if (min < -5) return "behind_5m_1h";
  if (min < -1) return "behind_1m_5m";
  if (min <= 1) return "within_1m";
  if (min <= 5) return "ahead_1m_5m";
  if (min <= 60) return "ahead_5m_1h";
  return "ahead_gt_1h";
}

function logClockSkewOnCreate(
  event: { data?: { after?: { createTime?: admin.firestore.Timestamp } } },
  before: MessageWireFields | undefined,
  after: MessageWireFields | undefined
): void {
  if (before || !after) return;
  // Admin-SDK system rows must not be sampled. `writeGroupSystemMessage`
  // (groups/group-system-message.ts) writes into this same collection with
  // `sentAt: serverTimestamp()`, resolved server-side at commit, so its delta
  // is ~0 BY CONSTRUCTION and always lands in the middle bucket — one row per
  // group create, per member added, and per leave OR admin removal (both go
  // through the same `memberLeft` event). BUT-1903 wants the spread of DEVICE
  // clocks; an unknown fraction of guaranteed-zero server rows would pull the
  // histogram toward "no skew" and make the hour look more generous than it is.
  //
  // Discriminated on `senderId` ALONE, deliberately. The messages create rule
  // pins `request.auth.uid == senderId` but places no constraint on `type`, so
  // a `type === "system"` test would be client-forgeable — a hand-rolled client
  // could opt itself out of the histogram. Every row `writeGroupSystemMessage`
  // produces carries the senderId, so nothing is lost by dropping the type half.
  if (after.senderId === "system") return;
  if (!(after.sentAt instanceof admin.firestore.Timestamp)) return;
  // Mirrors `selfCreatedAtMs` in social/duplicate-content-guard.ts — the
  // sibling trigger on this same collection reads the snapshot's own
  // server-assigned createTime exactly this way.
  const serverMs = event.data?.after?.createTime?.toMillis();
  if (serverMs === undefined) return;
  logger.info("[syncConversationLastMessage] clock skew sample (BUT-1903)", {
    bucket: clockSkewBucket(after.sentAt.toMillis() - serverMs),
  });
}

export const syncConversationLastMessage = onDocumentWritten(
  {
    document: "messages/{messageId}",
    region: "europe-west1",
  },
  async (event) => {
    const messageId = event.params.messageId;
    const before = event.data?.before?.data() as MessageWireFields | undefined;
    const after = event.data?.after?.data() as MessageWireFields | undefined;

    logClockSkewOnCreate(event, before, after);

    const conversationId = after?.conversationId ?? before?.conversationId;
    if (!conversationId) {
      logger.warn(
        "[syncConversationLastMessage] message has no conversationId, skipping",
        { messageId }
      );
      return;
    }
    const db = admin.firestore();
    const conversationRef = db.collection("conversations").doc(conversationId);

    const isDelete = !!before && !after;

    await db.runTransaction(async (tx) => {
      const convDoc = await tx.get(conversationRef);
      if (!convDoc.exists) {
        logger.warn(
          "[syncConversationLastMessage] conversation not found, skipping",
          { messageId, conversationId: logSafeConversationId(conversationId) }
        );
        return;
      }
      const convData = convDoc.data() ?? {};
      const currentLastMessage = convData.lastMessage as
        | { id?: string; sentAt?: admin.firestore.Timestamp }
        | null
        | undefined;

      // The payload-level blocked test, FIRST and independent of everything
      // below. The mark's own invocation arrives already carrying
      // `duplicateBlocked`, which is not a duplicate-guard candidate — so a
      // test that sat behind the candidate gate would never run, and the `>=`
      // tie rule in `shouldReplaceLastMessage` would project the emptied row
      // as the preview. That was a real defect in this change's first plan,
      // caught before any code was written.
      const payloadBlocked = !isDelete && after?.type === DUPLICATE_BLOCKED_TYPE;

      // THE PRE-READ GATE. An invocation that cannot end in a write must not
      // pay for the re-read below — a receipt on anything but the newest
      // message is the common case, and it returns here for free.
      if (!isDelete && !payloadBlocked) {
        if (!(after?.sentAt instanceof admin.firestore.Timestamp)) {
          logger.warn(
            "[syncConversationLastMessage] sentAt missing or not a Timestamp; skipping",
            { messageId, conversationId: logSafeConversationId(conversationId) }
          );
          return;
        }
        // Safe to decide on the PAYLOAD's stamp, and the reason is stronger
        // than immutability alone. This skips only when the candidate stamp is
        // OLDER than the stored one — and if the preview names THIS message the
        // stored stamp was projected from it, so the comparison is `>=` and
        // never skips. The gate can therefore only skip when the preview names
        // a different message, which is exactly the condition under which every
        // branch below also returns without writing. Nothing reachable is lost.
        //
        // It does rest on two invariants that live ELSEWHERE: `sentAt` is
        // immutable under the messages update rule, and the guard's mark writes
        // only `{type, content, updatedAt}`. A future change letting any writer
        // touch `sentAt` turns this gate into a silent ordering bug, and no
        // test would catch it.
        if (!shouldReplaceLastMessage(currentLastMessage, after.sentAt)) return;
      }

      // THE RE-READ: what the document says RIGHT NOW, which is not necessarily
      // what this invocation was handed.
      //
      // NOT confined to creates, and that scope was a real defect rather than a
      // tuning choice — measured against the emulator by the
      // `cloud-functions-specialist` gate before this shipped. `messages` has a
      // SECOND update path: the receipts branch
      // (`status`/`deliveredAt`/`readAt`/`updatedAt`), which every recipient's
      // client writes seconds after every message it is online for. That
      // invocation carries a PRE-MARK payload and a non-empty `before`, so a
      // create-only re-read skipped it — and if it landed after the mark's own
      // invocation had corrected the preview, it put the blocked duplicate's
      // text back in front of every participant. Worse than the BUT-1898 race
      // it replaces: that one left a preview pointing at a missing document,
      // this one PUBLISHES the text the guard exists to withhold.
      //
      // Bounded differently on each side, and the asymmetry is deliberate.
      //
      // CREATES are gated on `isChatDuplicateCandidate`, the guard's own
      // admission test, shared so the two triggers cannot drift — a system row,
      // a share card and a short "ok" cost nothing extra.
      //
      // UPDATES are NOT, and gating them on it was a second measured defect
      // (`cloud-functions-specialist`, round 2). The guard decides candidacy
      // from the CREATE payload and marks regardless of what the document says
      // later, while the sender update branch leaves `content` and `type`
      // freely writable — so an update landing between create and mark can
      // carry a payload that is no longer a candidate, skip the re-read, and
      // land last. Measured: a sender editing their message down to "ok" put
      // the preview on a blocked, emptied row; a hand-rolled client flipping
      // `type` put the duplicate's TEXT back. Any payload still carrying that
      // text is a candidate by construction, so only a message edited OUT of
      // candidacy escaped — lower stakes than the receipt race, but the code
      // and its records assert a CLOSED race, and that is what a later editor
      // trusts.
      //
      // The pre-read gate above still runs FIRST, so an update that was never
      // going to write (a receipt on anything but the newest message) returns
      // before paying for a read. That is what keeps this affordable.
      //
      // Do NOT gate this on `isChatDuplicateGuardEnabled` to save the read
      // while the flag is off. That flag caches per isolate for five minutes,
      // so switching it ON would leave a window in which one isolate's guard
      // marks while another isolate's sync trigger still skips its re-read —
      // re-opening this exact hole at the worst possible moment.
      let current = after;
      let vanished = isDelete;
      if (
        !isDelete &&
        !payloadBlocked &&
        (!!before || isChatDuplicateCandidate(after ?? {}))
      ) {
        const live = await tx.get(db.collection("messages").doc(messageId));
        if (live.exists) {
          current = live.data() as MessageWireFields;
        } else {
          vanished = true;
        }
      }

      // A row this trigger sees carrying the blocked mark is never projected.
      // The guard's own product would show as an empty preview; a row a client
      // stamped itself still carries its text, and that is what the mark exists
      // to remove. Treated exactly like a delete: the row stays on disk, it
      // just stops being previewable.
      const isBlocked =
        payloadBlocked || (!vanished && current?.type === DUPLICATE_BLOCKED_TYPE);

      if (vanished || isBlocked) {
        // Only act when the gone-or-blocked message WAS the conversation's
        // lastMessage; otherwise the preview is unaffected.
        if (currentLastMessage?.id !== messageId) return;

        // Recompute by reading the most recent surviving message. Outside
        // the transaction would be cheaper but introduces a TOCTOU race;
        // a get() inside the txn is acceptable for these rare paths.
        //
        // SCANS A FEW ROWS, not one: the newest message can itself be blocked,
        // and a blocked row must never become the preview by being the top of
        // this query either. Five is a ceiling chosen to bound the cost of a
        // rare path, not a measurement — a sender who trips the guard five
        // times in a row leaves the conversation with no preview until their
        // next real message, which is the same outcome an empty conversation
        // already has.
        const replacement = await tx.get(
          db
            .collection("messages")
            .where("conversationId", "==", conversationId)
            .orderBy("sentAt", "desc")
            .limit(SURVIVOR_SCAN_LIMIT)
        );
        const replacementDoc = replacement.docs.find(
          (d) =>
            (d.data() as MessageWireFields).type !== DUPLICATE_BLOCKED_TYPE
        );
        if (!replacementDoc) {
          if (!replacement.empty) {
            logger.warn(
              "[syncConversationLastMessage] every scanned message is blocked; clearing lastMessage",
              {
                messageId,
                scanned: replacement.size,
                conversationId: logSafeConversationId(conversationId),
              }
            );
          }
          tx.update(conversationRef, {
            lastMessage: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }
        const replacementData = replacementDoc.data() as MessageWireFields;
        // BUT-1853, STRENGTHENED 2026-08-19. A truthiness check is NOT enough
        // here, and the gap is reachable by any participant rather than by
        // accident. Measured against the live rules on the emulator:
        //
        //   · the messages CREATE rule USED TO check only that the key
        //     `sentAt` EXISTS, never what TYPE it holds — `sentAt: "nope"`
        //     returned ALLOW. Closed by BUT-1896 on 2026-08-19;
        //   · Firestore's type ordering sorts STRINGS above every timestamp,
        //     measured `string > new ts > old ts > null`.
        //
        // So a planted string SORTS FIRST under `orderBy('sentAt','desc')`
        // and walks straight past `!data.sentAt`. Anyone in a group could make
        // their own message the permanent recomputed preview for everyone else.
        // Require a real Timestamp; anything else clears.
        //
        // The rules-side close LANDED (BUT-1896, 2026-08-19):
        // `request.resource.data.sentAt is timestamp` on the create, with
        // M10-M13 beside the older M1-M9 — string, number, missing and
        // Timestamp-shaped map. This paragraph said the opposite for a few
        // hours, because it was written in the same session that then filed
        // and built the rule.
        //
        // This guard STAYS, and not out of caution: the rule bounds what can
        // be WRITTEN from today, and says nothing about rows already on disk
        // from before it. Do not delete it because the rule exists.
        //
        // The future-dated variant is BOUNDED as of BUT-1903 — not eliminated.
        // The create rule now also caps the VALUE at `request.time + 1h`, a
        // chosen ceiling rather than a measured one, so a stamp inside that
        // hour still writes and still wins `orderBy('sentAt','desc')` until
        // real time catches up. And it does not reach rows written before it
        // either, which is the second reason this TYPE guard survives any
        // rules change.
        if (
          !(replacementData.sentAt instanceof admin.firestore.Timestamp)
        ) {
          // A projection with an unusable `sentAt` fails OPEN on the
          // client — `MessageDto.fromMap` substitutes `clock.now()` for a
          // missing stamp, which always clears `Conversation.canReadMessageAt`,
          // so a member added to a running group would see a preview of a
          // message sent before they joined. Clear instead of projecting: the
          // preview is worth less than the cut-off, and the next message write
          // restores it. (The query can return such a row because Firestore
          // orders an explicit null lowest rather than excluding it.)
          logger.warn(
            "[syncConversationLastMessage] replacement has no sentAt; clearing lastMessage",
            {
              messageId,
              replacementId: replacementDoc.id,
              conversationId: logSafeConversationId(conversationId),
            }
          );
          tx.update(conversationRef, {
            lastMessage: null,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
          return;
        }
        tx.update(conversationRef, {
          lastMessage: projectLastMessage(replacementDoc.id, replacementData),
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        });
        return;
      }

      // Create or update path.
      // The TYPE test, not a truthiness test, and the two rejected cases are
      // different animals:
      //
      //  · MISSING — a malformed write, and NOTHING catches up. This comment
      //    used to say a serverTimestamp sentinel resolves on a follow-up
      //    write; measured against the emulator 2026-08-19, that is false for
      //    every writer this trigger has. `writeGroupSystemMessage` uses the
      //    Admin SDK, whose serverTimestamp is resolved server-side at commit,
      //    so the stored value is already a real Timestamp and the document is
      //    written once; `MessageDto.toFirestore` writes a concrete
      //    `Timestamp.fromDate`. Skipping is the fail-closed choice: the
      //    preview waits for the next well-formed message, which is what test
      //    I7 pins.
      //  · WRONG TYPE — nothing catches up, ever. `sentAt: "nope"` USED TO
      //    pass the create rule, which tested only that the key exists;
      //    BUT-1896 closed that on 2026-08-19. The guard stays for the two
      //    reasons the delete branch above gives: the rule bounds what can be
      //    WRITTEN from now on and says nothing about rows already on disk.
      //    (The future-dated hole that used to be named here is BOUNDED, not
      //    closed, as of BUT-1903: the create rule caps `sentAt` at
      //    `request.time + 1h`, so a stamp inside that hour still lands here
      //    and the `>=` in `shouldReplaceLastMessage` holds the preview until
      //    real time catches up.) The string was truthy, so it reached
      //    `candidateSentAt.toMillis()` and threw; measured
      //    2026-08-19 by the integration test below. Worse, when the
      //    conversation had no lastMessage the string was PROJECTED, after
      //    which every later write in that conversation threw on the stored
      //    value. Refusing it here is what keeps that out of the document.
      //
      // Logged as one line either way: the log is for spotting a sustained
      // spike, and both shapes mean the same thing to whoever reads it —
      // messages arriving without a usable stamp.
      //
      // Reads `current`, not `after` (BUT-1904): the two differ exactly when
      // the duplicate guard rewrote the document while this invocation was in
      // flight, which is the whole race. Re-checked here rather than trusted
      // from the pre-read gate above, because this is the value that gets
      // PROJECTED — `sentAt` is immutable under the rules and untouched by the
      // guard, so the two agree in every case anyone has staged, and this
      // costs a type test rather than a read.
      if (!(current?.sentAt instanceof admin.firestore.Timestamp)) {
        logger.warn(
          "[syncConversationLastMessage] sentAt missing or not a Timestamp; skipping",
          { messageId, conversationId: logSafeConversationId(conversationId) }
        );
        return;
      }
      if (!shouldReplaceLastMessage(currentLastMessage, current.sentAt)) {
        return;
      }
      tx.update(conversationRef, {
        lastMessage: projectLastMessage(messageId, current),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    });
  }
);
