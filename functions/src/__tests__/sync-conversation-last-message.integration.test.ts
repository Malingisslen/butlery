/**
 * BUT-839 — emulator-backed integration test for `syncConversationLastMessage`.
 *
 * The sibling unit test (`sync-conversation-last-message.test.ts`) pins the
 * pure precedence helper only. This test exercises the REAL exported trigger
 * via the v2 `CloudFunction.run(event)` surface against a live Firestore
 * emulator (127.0.0.1:8080) — transaction, projection, and the delete-path
 * recompute query included. No re-implemented logic.
 *
 * Note on triggers: the emulator does not fire deployed `onDocumentWritten`
 * code unless the functions emulator hosts it. Unlike
 * `request-account-deletion.integration.test.ts` (which calls a
 * deps-injected inner function), this suite drives the EXPORTED v2 handler
 * via `CloudFunction.run(event)` with realistic `Change<DocumentSnapshot>`
 * payloads built from REAL emulator snapshots (read before/after each
 * write) — exercising exactly the handler body that deploys.
 *
 * Scenarios:
 *   1. Create message  → conversation.lastMessage set to it.
 *   2. Newer message   → lastMessage advances.
 *   3. Edit the latest (same sentAt) → preview text refreshes (>= precedence).
 *   4. Stale/out-of-order event for an OLD message → lastMessage unchanged.
 *   5. Delete the latest → lastMessage recomputed from the next-most-recent
 *      surviving message (transactional recompute query).
 *   6. Delete the last remaining message → lastMessage cleared to null.
 *   7. Delete when the only survivor carries no `sentAt` → lastMessage cleared
 *      rather than projected undated (BUT-1853; the client would substitute
 *      `clock.now()` and defeat the group history cut-off).
 *
 *   8. A message whose `sentAt` is a STRING is refused by BOTH the create and
 *      the delete path (BUT-1853). The create RULE used to test only that the
 *      key exists, which is how such a row could be written at all; BUT-1896
 *      closed that on 2026-08-19. These guards stay, because the rule bounds
 *      what can be written from now on and says nothing about rows already on
 *      disk. Firestore sorts strings above every timestamp, so a planted
 *      string wins `orderBy('sentAt','desc').limit(1)` outright.
 *
 *      Corrected 2026-08-19. The counting note at I8 below is the single
 *      record of which copies of this claim were wrong and how many — kept in
 *      one place on purpose, because two copies of one fact is the drift that
 *      note is about, and a count is a fact like any other.
 *
 * Isolation: per-run unique conversation + message ids; every doc this suite
 * writes is deleted in cleanup so the shared demo-test namespace stays
 * unpolluted. That includes I8's deliberately malformed row — the emulator
 * keeps data across runs, so a leftover would be permanent.
 *
 * Skip gate (local machines without the emulator / Java): if 8080 doesn't
 * answer, print SKIP and exit 0 — unless CI is set, where a missing emulator
 * is a hard failure (the CI lane starts it explicitly).
 *
 * Run: npx ts-node src/__tests__/sync-conversation-last-message.integration.test.ts
 * Local prerequisite: bash .claude/hooks/ensure-firestore-emulator.sh
 */

import { requireEmulatorsOrSkip } from "./integration-gate";

const PROJECT_ID = "demo-test";
const FIRESTORE_HOST = "127.0.0.1:8080";

// MUST be set before firebase-admin / firebase-functions are imported.
process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: PROJECT_ID });

import * as admin from "firebase-admin";

const RUN = Date.now().toString(36);
const CONV = `conv-${RUN}`;
const M1 = `msg1-${RUN}`;
const M2 = `msg2-${RUN}`;
// BUT-1853 only: a dated survivor and an undated one, seeded after the suite
// above has emptied the conversation.
const M3 = `msg3-${RUN}`;
const M4 = `msg4-${RUN}`;
// I8 (BUT-1853): the planted-string pair.
const M5 = `msg5-${RUN}`;
const M6 = `msg6-${RUN}`;

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}
function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

async function run(): Promise<void> {
  console.log("BUT-839: syncConversationLastMessage INTEGRATION tests (firestore emulator)");
  console.log("===========================================================================\n");

  await requireEmulatorsOrSkip(
    [{ name: "Firestore", hostPort: FIRESTORE_HOST }],
    "bash .claude/hooks/ensure-firestore-emulator.sh",
  );

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();
  // Import AFTER initializeApp so the module's admin.firestore() binds to the
  // emulator-configured default app.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const {
    syncConversationLastMessage,
  } = require("../messaging/sync-conversation-last-message");

  const convRef = db.collection("conversations").doc(CONV);
  const msgRef = (id: string) => db.collection("messages").doc(id);

  /**
   * Invoke the REAL handler with a Change built from REAL snapshots —
   * the exact shape onDocumentWritten delivers (non-existent snapshots for
   * the missing side of a create/delete, just like production).
   */
  async function fireWritten(
    messageId: string,
    before: admin.firestore.DocumentSnapshot,
    after: admin.firestore.DocumentSnapshot,
  ): Promise<void> {
    await syncConversationLastMessage.run({
      params: { messageId },
      data: { before, after },
    });
  }

  /** Write a message doc and fire the trigger as a create/update event. */
  async function writeAndFire(
    messageId: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    const before = await msgRef(messageId).get();
    await msgRef(messageId).set(data);
    const after = await msgRef(messageId).get();
    await fireWritten(messageId, before, after);
  }

  /** Delete a message doc and fire the trigger as a delete event. */
  async function deleteAndFire(messageId: string): Promise<void> {
    const before = await msgRef(messageId).get();
    await msgRef(messageId).delete();
    const after = await msgRef(messageId).get();
    await fireWritten(messageId, before, after);
  }

  async function lastMessage(): Promise<Record<string, unknown> | null> {
    const snap = await convRef.get();
    return (snap.data()?.lastMessage as Record<string, unknown> | null) ?? null;
  }

  const ts = (ms: number) => admin.firestore.Timestamp.fromMillis(ms);
  const T1 = 1_700_000_000_000;
  const T2 = T1 + 60_000;

  await convRef.set({ participantIds: [`a-${RUN}`, `b-${RUN}`], lastMessage: null });

  // I1: first message becomes lastMessage.
  test("create: conversation.lastMessage is set from the new message", async () => {
    await writeAndFire(M1, {
      conversationId: CONV,
      senderId: `a-${RUN}`,
      content: "hej",
      type: "text",
      status: "sent",
      sentAt: ts(T1),
    });
    const lm = await lastMessage();
    assert(lm !== null, "lastMessage must be set after first message");
    assert(lm!.id === M1, `lastMessage.id must be ${M1}, got ${lm!.id}`);
    assert(lm!.content === "hej", `lastMessage.content must be 'hej', got ${lm!.content}`);
    assert(lm!.senderId === `a-${RUN}`, "lastMessage.senderId must mirror the message");
  });

  // I2: newer message advances lastMessage.
  test("create: newer message replaces lastMessage", async () => {
    await writeAndFire(M2, {
      conversationId: CONV,
      senderId: `b-${RUN}`,
      content: "senare",
      type: "text",
      status: "sent",
      sentAt: ts(T2),
    });
    const lm = await lastMessage();
    assert(lm!.id === M2, `lastMessage.id must advance to ${M2}, got ${lm!.id}`);
    assert(lm!.content === "senare", `lastMessage.content must be 'senare', got ${lm!.content}`);
  });

  // I3: editing the latest message (same sentAt) refreshes the preview text —
  // the >= precedence the unit test pins, proven through the real transaction.
  test("update: edit with equal sentAt refreshes the preview text", async () => {
    await writeAndFire(M2, {
      conversationId: CONV,
      senderId: `b-${RUN}`,
      content: "redigerad",
      type: "text",
      status: "sent",
      sentAt: ts(T2), // unchanged — edits keep the original sentAt
    });
    const lm = await lastMessage();
    assert(lm!.id === M2, "lastMessage.id must remain the edited message");
    assert(
      lm!.content === "redigerad",
      `edited preview must refresh to 'redigerad', got ${lm!.content}`,
    );
  });

  // I4: a stale event for an OLDER message must not regress lastMessage
  // (retry/out-of-order delivery safety).
  test("idempotency: replayed event for an older message does not regress lastMessage", async () => {
    const snap = await msgRef(M1).get();
    await fireWritten(M1, snap, snap); // replay as an update event
    const lm = await lastMessage();
    assert(lm!.id === M2, `lastMessage must stay ${M2} after stale replay, got ${lm!.id}`);
    assert(lm!.content === "redigerad", "preview text must be unchanged by stale replay");
  });

  // I5: deleting the latest recomputes from the next-most-recent survivor.
  test("delete: deleting the latest recomputes lastMessage from the survivor", async () => {
    await deleteAndFire(M2);
    const lm = await lastMessage();
    assert(lm !== null, "lastMessage must be recomputed, not cleared, while messages remain");
    assert(lm!.id === M1, `lastMessage must fall back to ${M1}, got ${lm!.id}`);
    assert(lm!.content === "hej", `recomputed preview must be 'hej', got ${lm!.content}`);
  });

  // I6: deleting the last remaining message clears lastMessage.
  test("delete: emptying the conversation clears lastMessage to null", async () => {
    await deleteAndFire(M1);
    const lm = await lastMessage();
    assert(lm === null, `lastMessage must be null for an empty conversation, got ${JSON.stringify(lm)}`);
  });

  // I7 (BUT-1853): the delete-path recompute must not project a survivor that
  // carries no `sentAt`. The client reads a missing stamp as `clock.now()`
  // (`MessageDto.fromMap`), which always clears `Conversation.canReadMessageAt`
  // — so such a projection would show a member added to a running group the
  // preview of a message sent before they joined. Clearing is the fail-closed
  // outcome. DELETING the guard turns this red (`id === M4` instead of null);
  // WEAKENING it to `!replacementData.sentAt` does NOT, because null is falsy
  // and the reverted check still clears. I8 is the test that kills the
  // truthiness mutant, and that split is why both tests exist.
  test("delete: survivor with no sentAt clears lastMessage instead of projecting it", async () => {
    // Re-seed: I6 left the conversation empty.
    await writeAndFire(M3, {
      conversationId: CONV,
      senderId: `a-${RUN}`,
      content: "daterad",
      type: "text",
      status: "sent",
      sentAt: ts(T1),
    });
    // An undated message never becomes lastMessage on its own (the create-path
    // guard), so the conversation still points at M3 here.
    await writeAndFire(M4, {
      conversationId: CONV,
      senderId: `b-${RUN}`,
      content: "odaterad",
      type: "text",
      status: "sent",
      sentAt: null,
    });
    const before = await lastMessage();
    assert(
      before!.id === M3,
      `precondition: an undated message must not take over lastMessage, got ${before!.id}`,
    );

    await deleteAndFire(M3);

    const lm = await lastMessage();
    assert(
      lm === null,
      `lastMessage must be cleared when the only survivor has no sentAt, got ${JSON.stringify(lm)}`,
    );
  });

  // I8 (BUT-1853, 2026-08-19): the case a truthiness check CANNOT catch. It is
  // why BOTH paths in the handler test the TYPE rather than the value, and
  // writing this test is what found the second half.
  //
  // Measured against the live rules on the emulator: the messages CREATE rule
  // USED TO check that `sentAt` EXISTS and never what type it holds, so
  // `sentAt: "nope"` returned ALLOW. BUT-1896 closed that on 2026-08-19. This
  // test STILL reaches the shape — it always did, through the Admin SDK, which
  // bypasses rules — so it could not have reddened when the rule changed.
  //
  // The guard stays for TWO reasons, and the second is the one that survives:
  // the rule bounds new writes and says nothing about rows already on disk,
  // AND a well-typed Timestamp up to an hour ahead still passes it — BUT-1903
  // bounded the value at `request.time + 1h` rather than removing it.
  // Do not read this as a guard that expires once the old rows age out.
  //
  // And Firestore sorts STRINGS above every timestamp
  // (`string > new ts > old ts > null`), so a planted string does not merely
  // survive the recompute query, it WINS `orderBy('sentAt','desc').limit(1)`.
  //
  // Reverting either guard turns this red, and they fail differently:
  //
  // (Counting note, and the ONLY enumeration of these five — the header points
  // here rather than repeating it. FIVE sites carried the claim WRONG, all in
  // the trigger and this suite: two in `sync-conversation-last-message.ts`,
  // this file's header, the paragraph above, and the inline note on the
  // planted write further down. `firestore.rules` and
  // `conversations-rules.test.ts` carry the same claim correctly tensed, so
  // the repo-wide count is higher; five counts only the ones that were wrong.
  // An earlier correction found three of them and said so. The count is
  // stated here rather than by pointing at the header, because a sentence
  // quoting another comment's wording breaks the moment that comment is
  // fixed — which is exactly what happened to the first version of this
  // note.)
  //  · create path back to `!after?.sentAt` — the write throws
  //    "candidateSentAt.toMillis is not a function", measured, because the
  //    string reaches the comparator; and when the conversation happens to
  //    have no lastMessage it is projected instead, after which every later
  //    write in that conversation throws on the STORED value.
  //  · delete path back to `!replacementData.sentAt` — the string is truthy,
  //    so the recompute projects it and `lm.id === M6`.
  test("a STRING sentAt is refused by both the create and the delete path", async () => {
    // I7 leaves M4 (`sentAt: null`) behind. Remove it FIRST so the planted
    // string is the only survivor of the delete below. Otherwise the
    // delete-path mutant-kill would rest on Firestore ordering a string above
    // a null — which it does, but if that ever flipped, the reverted guard's
    // truthiness test would clear on the falsy null and this test would go
    // GREEN with the mutant live.
    await msgRef(M4).delete();

    await writeAndFire(M5, {
      conversationId: CONV,
      senderId: `a-${RUN}`,
      content: "daterad",
      type: "text",
      status: "sent",
      sentAt: ts(T1),
    });
    await writeAndFire(M6, {
      conversationId: CONV,
      senderId: `b-${RUN}`,
      content: "planterad",
      type: "text",
      status: "sent",
      // Not a Timestamp. A client could write exactly this until BUT-1896;
      // this write has ALWAYS gone through the Admin SDK, which bypasses
      // rules, so the case stays reachable for the rows already on disk.
      sentAt: "nope" as unknown as FirebaseFirestore.Timestamp,
    });

    const afterPlant = await lastMessage();
    assert(
      afterPlant !== null && afterPlant.id === M5,
      `create path: the planted string must not take over the preview, got ${JSON.stringify(afterPlant)}`,
    );

    await deleteAndFire(M5);

    const lm = await lastMessage();
    assert(
      lm === null,
      `delete path: a string sentAt must clear lastMessage, not become the preview; got ${JSON.stringify(lm)}`,
    );
  });

  // ---------------------------------------------------------------------
  // BUT-1904: the duplicate guard MARKS a message instead of deleting it.
  //
  // Its own conversation, because these cases care about which message is the
  // newest survivor and the suite above leaves rows behind in CONV.
  // ---------------------------------------------------------------------

  const CONV_B = `conv-blocked-${RUN}`;
  const convBRef = db.collection("conversations").doc(CONV_B);
  const B1 = `blk1-${RUN}`;
  const B2 = `blk2-${RUN}`;
  const B3 = `blk3-${RUN}`;
  const B4 = `blk4-${RUN}`;
  // Over MIN_CHAT_BODY_CHARS, so the guard — and therefore the re-read — would
  // consider it. A shorter body would make J2 pass for the wrong reason.
  const DUP_BODY = "Jag kommer klockan sju ikvall";

  function msgBody(content: string, sentAtMs: number): Record<string, unknown> {
    return {
      conversationId: CONV_B,
      senderId: `a-${RUN}`,
      content,
      type: "text",
      status: "sent",
      sentAt: ts(sentAtMs),
    };
  }

  async function lastMessageB(): Promise<Record<string, unknown> | null> {
    const snap = await convBRef.get();
    return (snap.data()?.lastMessage as Record<string, unknown> | null) ?? null;
  }

  // Held between J1 and J2: the snapshot as it looked BEFORE the guard marked
  // it. This is precisely what an in-flight create-side invocation is holding.
  let staleCreateSnapshot: admin.firestore.DocumentSnapshot | null = null;

  // J1: the guard's own mark reaches this trigger as an UPDATE whose `after`
  // already says `duplicateBlocked`. A blocked row stores no text, so
  // projecting it would leave every participant with an empty preview.
  //
  // This is the case an eligibility gate would swallow: `duplicateBlocked` is
  // not a candidate, so a re-read gated on candidacy never runs, and the
  // payload would fall through to `shouldReplaceLastMessage`, whose `>=` tie
  // rule accepts the same `sentAt` and overwrites the preview.
  test("blocked (update): the preview falls back to the previous real message", async () => {
    await convBRef.set({
      participantIds: [`a-${RUN}`, `b-${RUN}`],
      lastMessage: null,
    });
    await writeAndFire(B1, msgBody("forsta meddelandet", T1));
    await writeAndFire(B2, msgBody(DUP_BODY, T2));
    let lm = await lastMessageB();
    assert(lm?.id === B2, `precondition: lastMessage must be ${B2}, got ${lm?.id}`);

    // Capture the pre-mark snapshot, then mark exactly as the guard does.
    staleCreateSnapshot = await msgRef(B2).get();
    const before = await msgRef(B2).get();
    await msgRef(B2).update({ type: "duplicateBlocked", content: "" });
    const after = await msgRef(B2).get();
    await fireWritten(B2, before, after);

    lm = await lastMessageB();
    assert(lm !== null, "the preview must not be cleared while a real message survives");
    assert(lm!.id === B1, `lastMessage must fall back to ${B1}, got ${lm!.id}`);
    assert(
      lm!.content === "forsta meddelandet",
      `the preview must show the previous real text, got "${lm!.content}"`,
    );
  });

  // J2: THE RACE. The create-side invocation for B2 is still in flight, holding
  // the payload from before the mark, and lands after J1 has already corrected
  // the preview. Without the transactional re-read it projects the duplicate's
  // text and the preview stays wrong until the next real message.
  //
  // Fires with a non-existent `before`, which is what makes it a CREATE — the
  // same shape `writeAndFire` builds for a first write.
  test("blocked (stale create replay): the duplicate never becomes the preview", async () => {
    assert(staleCreateSnapshot !== null, "precondition: J1 must have run first");
    const nonExistent = await msgRef(`never-written-${RUN}`).get();
    await fireWritten(B2, nonExistent, staleCreateSnapshot!);

    const lm = await lastMessageB();
    assert(lm !== null, "the preview must still be set");
    assert(
      lm!.id === B1,
      `a stale create for a blocked message must not move the preview, got ${lm!.id}`,
    );
    assert(
      lm!.content !== DUP_BODY,
      "the blocked message's text must never reach the preview",
    );
  });

  // J3: a blocked row that is not the preview leaves the preview alone.
  //
  // The fixture has to be built with care, and the first version of this case
  // could not fail. It marked an OLDER message while the preview pointed at the
  // NEWEST one — so deleting the `currentLastMessage?.id !== messageId` guard
  // still recomputed back to the same document, and the assertion passed on a
  // handler that did the work it was supposed to skip. A guard that only saves
  // WORK is invisible to a suite that asserts only the final value. Found by
  // the testing-specialist gate.
  //
  // What discriminates: point the preview at something that is NOT the newest
  // survivor, which the client itself does — `MessageMutationModule`
  // merge-sets `lastMessage` with no comparison at all. Then mark a message
  // that is neither. With the guard the preview stays where it was put;
  // without it the recompute runs and drags the preview to the newest row.
  test("blocked: a row that is not the preview leaves lastMessage alone", async () => {
    await writeAndFire(B3, msgBody("ett gammalt meddelande", T1 - 60_000));

    // B4b is newer than B3 and older than B1: not the preview, not the newest.
    const B4b = `blk4b-${RUN}`;
    await writeAndFire(B4b, msgBody(DUP_BODY, T1 - 30_000));

    // Pin the preview to the OLDEST message, the way a client merge-set does.
    // AFTER both writes: seeding it first would just be overwritten by B4b's
    // own create, which is newer than B3 and would take the preview legitimately.
    // The newest survivor is B1, so a recompute would move the preview there.
    await convBRef.update({
      lastMessage: {
        id: B3,
        conversationId: CONV_B,
        senderId: `a-${RUN}`,
        content: "ett gammalt meddelande",
        type: "text",
        status: "sent",
        sentAt: ts(T1 - 60_000),
      },
    });
    let lm = await lastMessageB();
    assert(
      lm?.id === B3,
      `precondition: the preview must still be pinned to ${B3}, got ${lm?.id}`,
    );

    const before = await msgRef(B4b).get();
    await msgRef(B4b).update({ type: "duplicateBlocked", content: "" });
    const after = await msgRef(B4b).get();
    await fireWritten(B4b, before, after);

    lm = await lastMessageB();
    assert(
      lm?.id === B3,
      `the preview must be untouched, got ${lm?.id} (a recompute would say ${B1})`,
    );
    await msgRef(B4b).delete();
  });

  // J5: THE RECEIPT RACE, and the reason the re-read is not confined to creates.
  //
  // `messages` has a second update path — the receipts branch
  // (`status`/`deliveredAt`/`readAt`/`updatedAt`) that every recipient's client
  // writes seconds after every message it is online for. That invocation
  // carries a PRE-MARK payload and a non-empty `before`, so a create-only
  // re-read skipped it entirely, and it re-projected the blocked duplicate's
  // TEXT to every participant.
  //
  // Reproduced against this emulator by the cloud-functions-specialist gate
  // before the fix; this case is that reproduction. It is strictly worse than
  // the BUT-1898 race it replaces — that one left a preview pointing at a
  // missing document, this one publishes the text the guard exists to withhold.
  test("blocked: a stale READ RECEIPT does not restore the duplicate text", async () => {
    const R1 = `rcpt1-${RUN}`;
    const R2 = `rcpt2-${RUN}`;
    const CONV_R = `conv-receipt-${RUN}`;
    const convRRef = db.collection("conversations").doc(CONV_R);
    await convRRef.set({
      participantIds: [`a-${RUN}`, `b-${RUN}`],
      lastMessage: null,
    });

    const body = (content: string, sentAtMs: number) => ({
      conversationId: CONV_R,
      senderId: `a-${RUN}`,
      content,
      type: "text",
      status: "sent",
      sentAt: ts(sentAtMs),
    });

    const fireInto = async (id: string, data: Record<string, unknown>) => {
      const before = await msgRef(id).get();
      await msgRef(id).set(data);
      const after = await msgRef(id).get();
      await syncConversationLastMessage.run({
        params: { messageId: id },
        data: { before, after },
      });
    };

    await fireInto(R1, body("forsta meddelandet", T1));
    await fireInto(R2, body(DUP_BODY, T2));

    // The recipient's client is holding this snapshot when the guard marks.
    const staleReceiptBefore = await msgRef(R2).get();

    await msgRef(R2).update({ type: "duplicateBlocked", content: "" });
    const marked = await msgRef(R2).get();
    await syncConversationLastMessage.run({
      params: { messageId: R2 },
      data: { before: staleReceiptBefore, after: marked },
    });

    let lm = (await convRRef.get()).data()?.lastMessage as
      | Record<string, unknown>
      | null;
    assert(
      lm?.id === R1,
      `precondition: the mark must have corrected the preview to ${R1}, got ${lm?.id}`,
    );

    // NOW the read receipt lands. The live document gets `status: "read"`; the
    // PAYLOAD does not — it is the snapshot the recipient's client was holding,
    // still saying `status: "sent"` and still carrying the pre-mark text. That
    // asymmetry is the point: the trigger is handed stale bytes.
    //
    // `status` takes no part in choosing the branch (`!isDelete`, `before`
    // exists, `after` not blocked, `after` a candidate), so sending an
    // "honest" post-receipt payload behaves identically — graded by the
    // testing-specialist gate. `before` exists either way, which is what a
    // create-only re-read would skip on.
    await msgRef(R2).update({ status: "read" });
    await syncConversationLastMessage.run({
      params: { messageId: R2 },
      data: { before: staleReceiptBefore, after: staleReceiptBefore },
    });

    lm = (await convRRef.get()).data()?.lastMessage as
      | Record<string, unknown>
      | null;
    assert(
      lm?.content !== DUP_BODY,
      "a stale receipt must never put the blocked message's text back in the preview",
    );
    assert(
      lm?.id === R1,
      `the preview must still be ${R1}, got ${lm?.id}`,
    );

    for (const id of [R1, R2]) await msgRef(id).delete();
    await convRRef.delete();
  });

  // J4: nothing previewable survives. The scan looks past a blocked row rather
  // than stopping at it, so this only passes when every row it finds is
  // blocked — the state a conversation reaches when its sole message is
  // stopped. Clearing is the same outcome an empty conversation already has.
  test("blocked: with no previewable survivor the preview is cleared", async () => {
    const CONV_C = `conv-allblocked-${RUN}`;
    const convCRef = db.collection("conversations").doc(CONV_C);
    await convCRef.set({
      participantIds: [`a-${RUN}`, `b-${RUN}`],
      lastMessage: null,
    });
    await msgRef(B4).set({
      conversationId: CONV_C,
      senderId: `a-${RUN}`,
      content: DUP_BODY,
      type: "text",
      status: "sent",
      sentAt: ts(T1),
    });
    const created = await msgRef(B4).get();
    const nonExistent = await msgRef(`never-written-c-${RUN}`).get();
    await fireWritten(B4, nonExistent, created);
    assert(
      (await convCRef.get()).data()?.lastMessage != null,
      "precondition: the only message must be the preview",
    );

    await msgRef(B4).update({ type: "duplicateBlocked", content: "" });
    const after = await msgRef(B4).get();
    await fireWritten(B4, created, after);

    assert(
      (await convCRef.get()).data()?.lastMessage === null,
      "with every survivor blocked the preview must be cleared, not left stale",
    );
    await convCRef.delete();
  });

  // J6: the SECOND hole in the same design, and the reason the re-read is not
  // gated on candidacy for updates.
  //
  // The guard decides candidacy from the CREATE payload and marks regardless of
  // what the document says later, while the sender update branch leaves
  // `content` and `type` freely writable. So an update landing between the
  // create and the mark can carry a payload that is NO LONGER a candidate —
  // here a message the sender edits down to "ok" — skip a candidacy-gated
  // re-read, and land last. Measured by the cloud-functions-specialist gate:
  // the preview then names a blocked, emptied row.
  //
  // Reachable from shipped UI (`ChatActionHandler` -> `editMessage`), unlike
  // the type-flipping variant, which needs a hand-rolled client.
  //
  // DO NOT DELETE J5 AS REDUNDANT because this case kills a superset of its
  // mutants. The two ride different `firestore.rules` branches: J5 rides the
  // RECEIPTS update (a recipient writing to someone else's message), J6 the
  // SENDER branch leaving `content` writable. Remove either branch and one case
  // goes unreachable while the other still holds. J5 is also the only
  // update-path fixture whose payload is still a duplicate-guard candidate,
  // which is the half creates still consult.
  test("blocked: a stale edit OUT of candidacy does not become the preview", async () => {
    const E1 = `edit1-${RUN}`;
    const E2 = `edit2-${RUN}`;
    const CONV_E = `conv-edit-${RUN}`;
    const convERef = db.collection("conversations").doc(CONV_E);
    await convERef.set({
      participantIds: [`a-${RUN}`, `b-${RUN}`],
      lastMessage: null,
    });

    const bodyE = (content: string, sentAtMs: number) => ({
      conversationId: CONV_E,
      senderId: `a-${RUN}`,
      content,
      type: "text",
      status: "sent",
      sentAt: ts(sentAtMs),
    });

    const fireInto = async (id: string, data: Record<string, unknown>) => {
      const before = await msgRef(id).get();
      await msgRef(id).set(data);
      const after = await msgRef(id).get();
      await syncConversationLastMessage.run({
        params: { messageId: id },
        data: { before, after },
      });
    };

    await fireInto(E1, bodyE("forsta meddelandet", T1));
    await fireInto(E2, bodyE(DUP_BODY, T2));

    // The sender edits their duplicate down to something under the 12-char
    // floor. This payload is NOT a duplicate-guard candidate.
    const beforeEdit = await msgRef(E2).get();
    await msgRef(E2).update({ content: "ok" });
    const editedSnap = await msgRef(E2).get();

    // The guard marks first; its own invocation corrects the preview.
    await msgRef(E2).update({ type: "duplicateBlocked", content: "" });
    const marked = await msgRef(E2).get();
    await syncConversationLastMessage.run({
      params: { messageId: E2 },
      data: { before: beforeEdit, after: marked },
    });
    let lm = (await convERef.get()).data()?.lastMessage as
      | Record<string, unknown>
      | null;
    assert(
      lm?.id === E1,
      `precondition: the mark must have corrected the preview to ${E1}, got ${lm?.id}`,
    );

    // NOW the edit's own invocation lands, holding the pre-mark "ok" payload.
    await syncConversationLastMessage.run({
      params: { messageId: E2 },
      data: { before: beforeEdit, after: editedSnap },
    });

    lm = (await convERef.get()).data()?.lastMessage as
      | Record<string, unknown>
      | null;
    assert(
      lm?.id === E1,
      `a stale non-candidate edit must not become the preview, got ${lm?.id}`,
    );

    for (const id of [E1, E2]) await msgRef(id).delete();
    await convERef.delete();
  });

  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(`        ${(err as Error).message}`);
    }
  }

  // Cleanup the shared demo-test namespace.
  await convRef.delete();
  await convBRef.delete();
  for (const id of [B1, B2, B3, B4]) {
    await msgRef(id).delete();
  }
  await msgRef(M1).delete();
  await msgRef(M2).delete();
  await msgRef(M3).delete();
  await msgRef(M4).delete();
  // I8's pair. M6 carries `sentAt: "nope"` and MUST go: the emulator keeps
  // data between runs, so leaving it behind plants a permanent malformed row
  // in the shared top-level `messages` collection.
  await msgRef(M5).delete();
  await msgRef(M6).delete();

  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : ""),
  );
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
