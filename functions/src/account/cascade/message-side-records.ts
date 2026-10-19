import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { commitInChunks } from "../../shared/batch-update";
import { Collections } from "../../shared/collections";
import { logSafeConversationId } from "../../shared/log-safe-conversation-id";
import { batchDeleteAll } from "./core";

/**
 * BUT-1766: chat messages live in the TOP-LEVEL `messages` collection, keyed by
 * a `conversationId` FIELD — `firestore.rules` grants `match /messages/{id}`
 * and nothing else, and the client writes there
 * (`FirebaseMessagingRepository._messagesRef`). The
 * `conversations/{id}/messages` SUBCOLLECTION this step used to sweep has no
 * rule block, no writer and therefore no documents: every account erased since
 * BUT-788 kept its entire chat history while the cascade reported `messages`
 * deleted. A path with no `match` block is denied, not merely undocumented.
 *
 * Three legs, in this order for a reason:
 *
 *  1. **Own messages anywhere** (`senderId == uid`) are ANONYMIZED in place —
 *     identity fields replaced and the content tombstoned, the same treatment
 *     `deleteCommentsAndRatings` gives `recipe_comments`. Membership is NOT the
 *     handle: a user who left a group keeps every message they wrote in it
 *     (the BUT-1725 lesson), and `senderId` is the only field that finds those. claim-lint:ok moved unchanged, BUT-2113
 *     Anonymizing rather than deleting preserves the thread other members keep
 *     — `Message.replyToMessageId` points at ids that would otherwise dangle —
 *     while erasing the personal data (name, avatar, content, uid).
 *  2. **1:1 conversations** (≤2 participants) are deleted whole, and with them
 *     EVERY message on that `conversationId`, both directions. The read rule
 *     resolves participation through `get(conversations/$(conversationId))`, so
 *     once the conversation doc is gone no client can read those messages.
 *     Running after leg 1 also means no `update` can hit a doc
 *     this leg already deleted.
 *  3. **Group conversations** keep running for the remaining members; the user
 *     leaves AND their per-user carriers on the conversation DOCUMENT go with
 *     them. Anonymizing the message rows is not enough on its own:
 *     `ConversationDto.toFirestore` denormalises `participantDisplayNames`,
 *     `participantAvatarUrls`, `lastReadTimestamps` and `perUserSettings` as
 *     uid-keyed maps, plus a full `lastMessage` copy (sender uid, name, avatar
 *     URL and content). Every remaining member reads that document — the
 *     conversations read rule is participant-gated — and nothing renames or
 *     erases it once the account is gone, because `on-profile-updated.ts`
 *     stops firing. `participantDisplayNames` / `participantAvatarUrls` are
 *     precisely the two fields that propagator maintains, i.e. the rename CF is
 *     the inventory and this collection is on it. Shape mirrors
 *     `enforce-group-minor-membership.ts`, which already removes three of the
 *     four in one `update()`.
 */
/** The one tombstone string every message-content erasure writes. */
export const MESSAGE_TOMBSTONE = "[Borttaget meddelande]";

/**
 * Cap on one erasure's poll-vote sweep. Same contract as `MAX_ROSTER_SWEEP_ROWS`
 * and set to the same number — but NOT for the same reason, and the
 * difference is worth stating because the first version of this docstring
 * borrowed the roster's argument and was wrong (BUT-1801 review, 2026-08-17).
 *
 * The roster cap exists because a PEER can seat rows keyed on this user.
 * Here they cannot: in `firestore.rules`, every write verb under
 * `match /messages/{messageId}/poll_votes/{voterId}` requires
 * `request.auth.uid == voterId`, and `isValidVote()` additionally pins
 * `request.resource.data.voterId == voterId`. Posting a poll into a conversation
 * creates ZERO rows for anyone; a row exists only when this user votes. So the
 * count is chosen by the user themselves.
 *
 * (Cited by match pattern and function name, not line number. An earlier version
 * gave a line range that was already wrong when it was written — a rules file
 * renumbers on every edit, so a coordinate in a comment rots faster than the
 * claim it supports.)
 *
 * The cap stays anyway, for the two reasons that do survive: self-inflation
 * (nothing rate-limits how many polls one person votes in), and a tampered or
 * non-standard Admin-SDK writer, which rules never see. Above the cap the sweep
 * DECLINES rather than truncating — a
 * truncated sweep reports a clean erasure over rows it never looked at, which
 * is the one outcome Art. 17 cannot tolerate. Declining lands the step in
 * `failedCollections`, which is loud.
 */
const MAX_POLL_VOTE_SWEEP_ROWS = 2000;

/**
 * BUT-1835: the erased user's poll votes, and their authorship of polls.
 *
 * TWO distinct residues, and neither one covers the other.
 *
 * (1) THEIR VOTES. Since BUT-1832 a vote is a document at
 * `messages/{messageId}/poll_votes/{voterUid}` — the uid is the document ID and
 * is also copied into a `voterId` field, which is the only one a query can see. claim-lint:ok moved unchanged, BUT-2113
 * They live under messages this user may never have sent, in conversations
 * `deleteMessages` leaves standing (any group, and any 1:1 whose roster clear
 * declined), so nothing else in this cascade reaches them. Written against the
 * subcollection shape, NOT the inline `metadata.poll.options[].voterIds` array
 * it replaced. That array is still EMITTED — `Poll.toMap` writes it and
 * `closePoll` rewrites the whole metadata map — but nothing has written a VOTER
 * UID into it since BUT-1832: `closePoll` reads the raw snapshot rather than the
 * hydrated model, so the display tally cannot round-trip back into storage.
 *
 * Careful with the tense. That is a claim about WRITERS, not about disk. A poll
 * created by the PRE-BUT-1832 client can still hold its author's own uid there,
 * because the old message update rule (`request.auth.uid == resource.data
 * .senderId`) let exactly one person write it. On such a row the scrub rewrites
 * only `creatorId`, and both probe legs then read zero — a certified-clean
 * erasure over a raw uid. Dev-project data only, on the same reasoning that
 * closed BUT-1839 unbuilt; whether it earns a backfill is Malin's call.
 *
 * So a cascade that scrubbed the array INSTEAD of the subcollection would be
 * chasing a field no live writer fills while missing the one that carries every
 * vote made since.
 *
 * (2) THEIR AUTHORSHIP. `metadata.poll.creatorId` names the person who opened
 * the poll. `deleteMessages` anonymises `senderId` on their own messages but
 * never looks inside `metadata`, so on every surviving poll the raw uid stayed
 * in the document — including polls in groups they had left, where no other claim-lint:ok moved unchanged, BUT-2113
 * field of theirs remains. The dotted-path update rewrites that one key and
 * leaves the question, the options and everyone else's data untouched; blanking
 * `metadata` wholesale would delete a poll the remaining members still use.
 *
 * The equality filter on `metadata.poll.creatorId` needs no composite index
 * (automatic single-field indexes cover an equality on a nested map key), but
 * the collection-group sweep on `voterId` DOES need a `COLLECTION_GROUP`
 * fieldOverride — automatic single-field indexes are collection-scoped, and
 * without the override this query fails with FAILED_PRECONDITION rather than
 * matching nothing. It is declared in `firestore.indexes.json`.
 */
export async function deletePollVotes(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<boolean> {
  let complete = true;

  const votes = await db
    .collectionGroup(Collections.pollVotes)
    .where("voterId", "==", uid)
    .limit(MAX_POLL_VOTE_SWEEP_ROWS + 1)
    .get();

  if (votes.size > MAX_POLL_VOTE_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible poll-vote count; not sweeping",
      { uid_prefix: uid.slice(0, 6), rows: votes.size },
    );
    complete = false;
  } else {
    await batchDeleteAll(db, votes.docs);
  }

  // Runs even when the vote sweep declined: the two residues are independent,
  // and half an erasure beats none as long as the step still REPORTS itself
  // incomplete, which `complete` does.
  // CAPPED, exactly like the vote sweep. An earlier version of this call was
  // uncapped, justified as "self-bounded — only this user authors this user's
  // polls". That is false, and `anonymizeSystemMessagesAboutUser` in this file
  // already says so: the `messages`
  // create rule pins required fields but carries NO `hasOnly`, so `metadata` is
  // unconstrained and any participant can plant
  // `metadata.poll.creatorId: <victimUid>` on a message in their own DM. The row
  // count is chosen by other people — the one argument that does NOT hold for
  // `poll_votes` and DOES hold here. Do not "simplify" the two to match.
  const authored = await db
    .collection(Collections.messages)
    .where("metadata.poll.creatorId", "==", uid)
    .limit(MAX_POLL_VOTE_SWEEP_ROWS + 1)
    .get();

  if (authored.size > MAX_POLL_VOTE_SWEEP_ROWS) {
    logger.error(
      "[deletion-cascade] implausible poll-authorship count; not scrubbing",
      { uid_prefix: uid.slice(0, 6), rows: authored.size },
    );
    return false;
  }

  // Per document, NOT one batch. A `WriteBatch` is atomic, so a single message
  // deleted underneath us by a SIBLING step — `deleteChatGroupMemberships`
  // deletes an emptied group's whole thread, and it runs in the same
  // `Promise.all` as this one — takes NOT_FOUND and kills the entire ≤500-doc
  // chunk with it. `commitInChunks(strict:false)` then swallows that, and the
  // step still returns success: up to 500 messages keep the raw uid in
  // `metadata.poll.creatorId` while the audit says the erasure was clean.
  //
  // NOT_FOUND (grpc code 5) is therefore tolerated per document and ONLY here:
  // the message is gone, which is the outcome this scrub wanted. Every other
  // error marks the step incomplete, so a real failure still reaches
  // `failedCollections` — and BUT-1801's residual probe on this same field is
  // the independent check that the two never disagree silently.
  //
  // In waves, not one fan-out. The set is capped above but still up to 2000
  // documents, and the file's own convention for a per-document pass is a
  // bounded slice at a time (`deleteMessages`, `scrubLastEditor`) rather than
  // 2000 simultaneous write RPCs.
  const SCRUB_WAVE = 10;
  const hardFailures: PromiseRejectedResult[] = [];
  for (let i = 0; i < authored.docs.length; i += SCRUB_WAVE) {
    const wave = await Promise.allSettled(
      authored.docs
        .slice(i, i + SCRUB_WAVE)
        .map((doc) => doc.ref.update({ "metadata.poll.creatorId": "deleted" })),
    );
    hardFailures.push(
      ...wave.filter(
        (r): r is PromiseRejectedResult =>
          r.status === "rejected" &&
          (r.reason as { code?: number } | undefined)?.code !== 5,
      ),
    );
  }
  if (hardFailures.length > 0) {
    complete = false;
    logger.error("[deletion-cascade] poll-creator scrub failed", {
      uid_prefix: uid.slice(0, 6),
      failed: hardFailures.length,
      total: authored.docs.length,
      errCodes: hardFailures.map(
        (r) => (r.reason as { code?: number } | undefined)?.code ?? null,
      ),
    });
  }

  return complete;
}

/**
 * BUT-1788: erase the user's name from SYSTEM rows written ABOUT them.
 *
 * `removeChatGroupMember` writes "<Name> har lämnat gruppen" under
 * `senderId: "system"` (through `groups/group-system-message.ts`; until BUT-1838
 * this was `leaveGroupConversation`). Three separate things make that row invisible to every
 * other leg of this cascade:
 *
 *  1. the `senderId == uid` query cannot match it — the author is
 *     "system";
 *  2. `buildGroupDepartureUpdate` only tombstones `lastMessage` when the
 *     departing user is its SENDER, and here they are its subject;
 *  3. once the person has left, the `participantIds array-contains uid` query
 *     never returns that conversation at all, so the cascade does not
 *     even visit it.
 *
 * The writer therefore stamps `metadata.subjectUserId`, which is the only claim-lint:ok moved unchanged, BUT-2113
 * queryable handle on a name embedded in free text. Equality on a nested field
 * is served by the automatic single-field index — no declaration needed.
 *
 * Both copies are rewritten: the `messages` row and the denormalised
 * `conversations/{id}.lastMessage.content` that `syncConversationLastMessage`
 * made of it. The mirror goes FIRST and the handle is cleared LAST, only for
 * rows whose mirror write succeeded — see the ordering note inline. Once a row
 * is fully scrubbed its handle is gone, so `probeResidualData` reads zero and a
 * re-run is a no-op.
 */
export async function anonymizeSystemMessagesAboutUser(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<void> {
  const about = await db
    .collection(Collections.messages)
    .where("metadata.subjectUserId", "==", uid)
    .get();
  if (about.docs.length === 0) return;

  // conversationId -> the exact contents the mirror may still be holding.
  const mirrored = new Map<string, Set<string>>();
  for (const doc of about.docs) {
    const data = doc.data() ?? {};
    const convoId =
      typeof data.conversationId === "string" ? data.conversationId : null;
    const content = typeof data.content === "string" ? data.content : null;
    if (!convoId || !content) continue;
    const bucket = mirrored.get(convoId) ?? new Set<string>();
    bucket.add(content);
    mirrored.set(convoId, bucket);
  }

  // MIRROR FIRST. `metadata.subjectUserId` is the only handle that finds these claim-lint:ok moved unchanged, BUT-2113
  // rows again, and the mirror scrub below is best-effort: its failure is
  // swallowed so one contended conversation cannot abort the erasure. Clearing
  // the handle before that write would make a swallowed failure permanent —
  // a re-run early-exits at the empty query above, `probeResidualData` (keyed
  // on the same field) reads zero and certifies a clean erasure, and the
  // deleted user's display name stays in the group preview for every remaining
  // member. Nothing heals it later: syncConversationLastMessage triggers on
  // message create/delete, never on update.
  //
  // Transactional re-read per conversation: a newer message may have replaced
  // the preview between the query and this write, and blindly stamping the
  // tombstone would erase THAT message's copy instead.
  const convoIds = [...mirrored.keys()];
  const failedConvos = new Set<string>();
  const chunkSize = 10;
  for (let i = 0; i < convoIds.length; i += chunkSize) {
    await Promise.all(
      convoIds.slice(i, i + chunkSize).map(async (convoId) => {
        const ref = db.collection(Collections.conversations).doc(convoId);
        try {
          await db.runTransaction(async (tx) => {
            const fresh = await tx.get(ref);
            if (!fresh.exists) return;
            const last = (fresh.data() ?? {}).lastMessage as
              Record<string, unknown> | undefined;
            if (!last || last.senderId !== "system") return;
            if (typeof last.content !== "string") return;
            if (!mirrored.get(convoId)?.has(last.content)) return;
            tx.update(ref, { "lastMessage.content": MESSAGE_TOMBSTONE });
          });
        } catch (err) {
          failedConvos.add(convoId);
          // An Error nested in a structured-log payload serialises to `{}`, so
          // `err` recorded nothing at all. Same shape as the probe legs above.
          logger.error("[deletion-cascade] system lastMessage scrub failed", {
            // Hashed for `direct_` ids like every other site on this path. This
            // one was judged group-only in 2026-08-01 because what was then the
            // sole writer of `metadata.subjectUserId` — `leave-group-conversation.ts`,
            // deleted by BUT-1838 and replaced by `groups/group-system-message.ts`,
            // whose call sites are all group callables — refuses direct chats. That reasoning was already wrong: the
            // `messages` create rule carries no `hasOnly`, so a sender can plant
            // that field on a message in their own DM and steer this line onto a
            // two-uid id.
            conversationId: logSafeConversationId(convoId),
            errCode: (err as { code?: number | string }).code ?? null,
            errName: err instanceof Error ? err.name : typeof err,
          });
        }
      }),
    );
  }

  // Handle-clearing write LAST, and skipped for any conversation whose mirror
  // scrub failed — the surviving `metadata.subjectUserId` is what lets a re-run
  // and probeResidualData find the rest. Retry semantics: a skipped row keeps
  // BOTH its handle and its original content, so the next run rebuilds the same
  // content match and scrubs the mirror it missed. A row that succeeded is gone
  // from the query entirely, so a full-success re-run is a plain no-op.
  const clearable = about.docs.filter((doc) => {
    const convoId = (doc.data() ?? {}).conversationId;
    return typeof convoId !== "string" || !failedConvos.has(convoId);
  });
  await commitInChunks(
    db,
    clearable,
    (batch, doc) => {
      batch.update(doc.ref, {
        content: MESSAGE_TOMBSTONE,
        "metadata.subjectUserId": admin.firestore.FieldValue.delete(),
      });
    },
    { label: "anonymizeSystemMessagesAboutUser", strict: false },
  );
}
