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
  // AND a well-typed but FUTURE-DATED Timestamp still passes it (BUT-1903).
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
