/**
 * BUT-1898 — emulator-backed integration test for `guardDuplicateMessage`.
 *
 * The sibling unit test pins the pure helpers. This one drives the REAL
 * exported trigger via the v2 `CloudFunction.run(event)` surface against a live
 * Firestore emulator, with realistic snapshots read back from the emulator —
 * exactly the handler body that deploys, transaction and delete included.
 *
 * It exists because every OTHER check in this change passes identically whether
 * or not the trigger fires. The guard was registered on a path nothing writes
 * to for three months and read as an active control the whole time; a suite
 * that cannot tell a firing guard from a dormant one would have let that stand.
 *
 * Scenarios:
 *   D1. Flag OFF               -> nothing is deleted, even for a true duplicate.
 *   D2. Flag ON, true duplicate in ONE conversation -> the second is stopped.
 *   D3. Same text, TWO conversations -> both survive. The false positive that
 *       made this ticket need a stakeholder panel.
 *   D4. Short body             -> never evaluated, so never deleted.
 *   D5. `type: "system"`       -> skipped. Reachable for the first time now
 *       that the trigger points at a path something writes to.
 *   D6. No `conversationId`    -> skipped rather than falling back to the
 *       author-only key, which would fail to the unsafe side.
 *   D7. The SAME event delivered twice -> the message survives.
 *       `onDocumentCreated` is at-least-once, so this is not hypothetical.
 *   D9. The stored entry carries the DOCUMENT's createTime, not the trigger's
 *       run time. The invariant D2 only catches by accident of clock skew.
 *   D8. The same event redelivered AFTER the rolling window has been flushed
 *       -> the message still survives. This is the one the eventId-based guard
 *       could not do: once its own bookkeeping was evicted by 20 later
 *       messages, a redelivery matched the entry written by the user's
 *       legitimate resend and deleted a message already delivered and read.
 *
 * Isolation: per-run unique ids; every doc is deleted in cleanup, and so is the
 * rolling hash document the guard writes under `users/{uid}`.
 *
 * Run: npx ts-node src/__tests__/duplicate-message-guard.integration.test.ts
 * Local prerequisite: bash .claude/hooks/ensure-firestore-emulator.sh
 */

import { requireEmulatorsOrSkip } from "./integration-gate";

const PROJECT_ID = "demo-test";
const FIRESTORE_HOST = "127.0.0.1:8080";

// MUST be set before firebase-admin / firebase-functions are imported.
process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;

// eslint-disable-next-line @typescript-eslint/no-require-imports
import * as admin from "firebase-admin";
import * as fs from "fs/promises";

const RUN = Date.now().toString(36);
const SENDER = `dup-sender-${RUN}`;
const CONV_A = `conv-a-${RUN}`;
const CONV_B = `conv-b-${RUN}`;

// Above MIN_CHAT_BODY_CHARS (12). Deliberately a sentence somebody would
// plausibly re-send, not lorem — the guard's whole risk is eating real speech.
const LONG_BODY = "Jag kommer klockan sju ikvall";
const SHORT_BODY = "ok";

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}
function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

const writtenMessageIds: string[] = [];

async function run(): Promise<void> {
  console.log("BUT-1898: guardDuplicateMessage INTEGRATION tests (firestore emulator)");
  console.log("=====================================================================\n");

  await requireEmulatorsOrSkip(
    [{ name: "Firestore", hostPort: FIRESTORE_HOST }],
    "bash .claude/hooks/ensure-firestore-emulator.sh",
  );

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID });
  }
  const db = admin.firestore();

  // Import AFTER initializeApp so the modules bind to the emulator app.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { guardDuplicateMessage } = require("../social/duplicate-content-guard");
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const {
    __setChatGuardFlagForTests,
    __resetChatGuardFlagCacheForTests,
  } = require("../social/duplicate-message-flag");

  const msgRef = (id: string) => db.collection("messages").doc(id);

  /**
   * Write a message and fire the REAL trigger with a real snapshot, the way
   * `onDocumentCreated` delivers it.
   */
  async function writeAndFire(
    messageId: string,
    data: Record<string, unknown>,
  ): Promise<void> {
    writtenMessageIds.push(messageId);
    await msgRef(messageId).set(data);
    const snap = await msgRef(messageId).get();
    await guardDuplicateMessage.run({
      params: { messageId },
      data: snap,
      id: `evt-${messageId}`,
    });
  }

  function body(
    conversationId: string | undefined,
    content: string,
    type = "text",
  ): Record<string, unknown> {
    return {
      ...(conversationId ? { conversationId } : {}),
      senderId: SENDER,
      content,
      type,
      status: "sent",
      sentAt: admin.firestore.Timestamp.now(),
    };
  }

  /** Re-fire the trigger for an EXISTING document under the same event id. */
  async function refire(messageId: string): Promise<void> {
    const snap = await msgRef(messageId).get();
    await guardDuplicateMessage.run({
      params: { messageId },
      data: snap,
      id: `evt-${messageId}`,
    });
  }

  async function exists(messageId: string): Promise<boolean> {
    return (await msgRef(messageId).get()).exists;
  }

  /**
   * BUT-1904 made `exists()` almost useless as a verdict on its own.
   *
   * The guard no longer deletes: it empties the message and stamps
   * `duplicateBlocked`. So a rejected message EXISTS, and every case that used
   * to prove innocence with a bare existence assertion would now pass even if
   * the guard had wrongly blocked it. These two helpers carry the assertions
   * instead — `assertIntact` says the guard did not touch this message,
   * `assertBlocked` says it did, and one is the negation of the other on the
   * fields that decide it.
   */
  async function assertIntact(
    messageId: string,
    expectedContent: string,
    why: string,
    expectedType = "text",
  ): Promise<void> {
    const snap = await msgRef(messageId).get();
    assert(snap.exists, `${why} (the document is gone entirely)`);
    const data = snap.data() ?? {};
    assert(
      data.type === expectedType,
      `${why} (type is "${data.type}", expected "${expectedType}")`,
    );
    assert(
      data.content === expectedContent,
      `${why} (content is "${data.content}", expected "${expectedContent}")`,
    );
  }

  async function assertBlocked(messageId: string, why: string): Promise<void> {
    const snap = await msgRef(messageId).get();
    assert(snap.exists, `${why} (a blocked message must NOT be deleted)`);
    const data = snap.data() ?? {};
    assert(
      data.type === "duplicateBlocked",
      `${why} (type is "${data.type}", expected "duplicateBlocked")`,
    );
    assert(
      data.content === "",
      `${why} (content is "${data.content}", expected it emptied)`,
    );
  }

  /**
   * The guard's rolling hash docs — cleared between cases so each starts cold.
   *
   * BOTH ids, and that is not defensive: the chat surface writes to `chat` and
   * the comment surface to `rolling` (BUT-1898 split them so chat volume
   * cannot flush the comment window). Clearing only `rolling` left chat state
   * leaking between cases, which is how this was found.
   */
  async function clearHashes(): Promise<void> {
    const col = db
      .collection("users")
      .doc(SENDER)
      .collection("recentContentHashes");
    await Promise.all([col.doc("chat").delete(), col.doc("rolling").delete()]);
  }

  // D1: the kill switch. This is what ships — the flag is OFF on landing, so
  // this case is the one that describes production on day one.
  //
  // It asserts INTACT rather than "still there" (BUT-1904). Since the guard
  // stopped deleting, "still there" is true of a blocked message too, so the
  // old assertion would have passed against a guard that ignored the flag
  // entirely and marked the message anyway. That is the whole failure this
  // case exists to catch.
  test("flag OFF: a true duplicate is left completely alone", async () => {
    __setChatGuardFlagForTests(false);
    await clearHashes();
    const a = `d1a-${RUN}`;
    const b = `d1b-${RUN}`;
    await writeAndFire(a, body(CONV_A, LONG_BODY));
    await writeAndFire(b, body(CONV_A, LONG_BODY));
    await assertIntact(a, LONG_BODY, "the first message must be untouched");
    await assertIntact(
      b,
      LONG_BODY,
      "with the flag off the guard must neither delete nor mark",
    );
  });

  // D2: the guard doing its job. Also the control that makes D3, D4, D5 and D6
  // attributable — without it they could all pass because the trigger never
  // fires at all, which is precisely the bug this ticket fixes.
  test("flag ON: a repeat in the SAME conversation is blocked, not deleted", async () => {
    __setChatGuardFlagForTests(true);
    await clearHashes();
    const a = `d2a-${RUN}`;
    const b = `d2b-${RUN}`;
    const sent = body(CONV_A, LONG_BODY);
    await writeAndFire(a, body(CONV_A, LONG_BODY));
    await writeAndFire(b, sent);
    await assertIntact(a, LONG_BODY, "the first message must be untouched");
    await assertBlocked(b, "the repeat must be marked");

    // The identity fields decide WHERE the row lands in the thread and whose
    // it is. `sentAt` is the one the UX claim rests on: the sender is promised
    // a row in the place the message would have been, and that place is this
    // stamp. The rules forbid changing all three, but the guard writes through
    // the Admin SDK, which bypasses rules — so nothing but this test is
    // watching them. Mutation-probed: re-stamping `sentAt` in the mark reddens
    // this case and nothing else.
    const marked = (await msgRef(b).get()).data() ?? {};
    assert(
      marked.senderId === SENDER,
      `senderId must be untouched, got "${marked.senderId}"`,
    );
    assert(
      marked.conversationId === CONV_A,
      `conversationId must be untouched, got "${marked.conversationId}"`,
    );
    const sentAt = sent.sentAt as admin.firestore.Timestamp;
    assert(
      (marked.sentAt as admin.firestore.Timestamp).isEqual(sentAt),
      "sentAt must be untouched — it is the row's position in the thread",
    );
  });

  // D3: the false positive the panel formed around. Before the scoped key this
  // deleted the second message — the same text to two different people inside
  // five minutes, which is ordinary chat rather than spam.
  test("flag ON: the same text in TWO conversations leaves both standing", async () => {
    __setChatGuardFlagForTests(true);
    await clearHashes();
    const a = `d3a-${RUN}`;
    const b = `d3b-${RUN}`;
    await writeAndFire(a, body(CONV_A, LONG_BODY));
    await writeAndFire(b, body(CONV_B, LONG_BODY));
    await assertIntact(
      a,
      LONG_BODY,
      "the first conversation's message must be untouched",
    );
    await assertIntact(
      b,
      LONG_BODY,
      "a different conversation must not collide with the first",
    );
  });

  // D4: the length floor. "ok" twice in one thread is the single most common
  // thing a person does in chat, and it must never be treated as spam.
  test("flag ON: a short body is never evaluated", async () => {
    __setChatGuardFlagForTests(true);
    await clearHashes();
    const a = `d4a-${RUN}`;
    const b = `d4b-${RUN}`;
    await writeAndFire(a, body(CONV_A, SHORT_BODY));
    await writeAndFire(b, body(CONV_A, SHORT_BODY));
    await assertIntact(a, SHORT_BODY, "the first short message must be untouched");
    await assertIntact(b, SHORT_BODY, "a repeated short message must be untouched");
  });

  // D5: system rows. `writeGroupSystemMessage` writes senderId "system" for
  // EVERY group in the app, so if the type filter ever widened they would all
  // share one author — the conversation scope saves them, but only because it
  // exists. Unreachable before this ticket; pinned now that it is not.
  test("flag ON: a system message is skipped", async () => {
    __setChatGuardFlagForTests(true);
    await clearHashes();
    const a = `d5a-${RUN}`;
    const b = `d5b-${RUN}`;
    const systemRow = "Anna har lagts till i gruppen";
    await writeAndFire(a, body(CONV_A, systemRow, "system"));
    await writeAndFire(b, body(CONV_A, systemRow, "system"));
    await assertIntact(
      a,
      systemRow,
      "the first system row must be untouched",
      "system",
    );
    await assertIntact(
      b,
      systemRow,
      "a repeated system row must be untouched",
      "system",
    );
  });

  // D6: no conversationId. The create rule guarantees the field for client
  // writes, but the Admin SDK bypasses rules. Skipping is the safe answer;
  // falling back to the author-only key would silently restore the very
  // collision D3 exists to prevent.
  test("flag ON: a message with no conversationId is skipped", async () => {
    __setChatGuardFlagForTests(true);
    await clearHashes();
    const a = `d6a-${RUN}`;
    const b = `d6b-${RUN}`;
    await writeAndFire(a, body(undefined, LONG_BODY));
    await writeAndFire(b, body(undefined, LONG_BODY));
    await assertIntact(a, LONG_BODY, "the first must be untouched");
    await assertIntact(
      b,
      LONG_BODY,
      "without a conversation id the guard must skip, not fall back",
    );
  });

  // D7: at-least-once redelivery, the simple case. The entry the first
  // delivery wrote is still in the window, and it is younger than the
  // document, so it cannot condemn it.
  test("flag ON: the same event delivered twice leaves the message standing", async () => {
    __setChatGuardFlagForTests(true);
    await clearHashes();
    const a = `d7a-${RUN}`;
    await writeAndFire(a, body(CONV_A, LONG_BODY));
    await assertIntact(a, LONG_BODY, "precondition: the message was accepted");
    await refire(a);
    await assertIntact(
      a,
      LONG_BODY,
      "a redelivery must not block the message it accepted",
    );
  });

  // D8: the same redelivery AFTER the rolling window has been flushed. This is
  // the sequence the eventId-based guard could not survive, and the reason the
  // duplicate test is now an ordering test against the document's own
  // server-assigned createTime rather than a lookup of its own event id.
  test("flag ON: a redelivery survives its own bookkeeping being evicted", async () => {
    __setChatGuardFlagForTests(true);
    await clearHashes();
    const victim = `d8-victim-${RUN}`;
    await writeAndFire(victim, body(CONV_A, LONG_BODY));
    await assertIntact(
      victim,
      LONG_BODY,
      "precondition: the message was accepted",
    );

    // 20 further qualifying messages evict the victim's own entry (the cap is
    // MAX_RECENT_HASHES = 20). Distinct bodies, so none of them is a duplicate.
    for (let i = 0; i < 20; i++) {
      await writeAndFire(
        `d8-filler-${i}-${RUN}`,
        body(CONV_A, `Fyllnadsmeddelande nummer ${i} som ar tillrackligt langt`),
      );
    }

    // The user re-sends the same text. Legitimate: five minutes have not
    // passed in wall-clock terms here, but the victim's entry is gone, so the
    // guard sees no earlier match and accepts it.
    const resend = `d8-resend-${RUN}`;
    await writeAndFire(resend, body(CONV_A, LONG_BODY));

    // Now the ORIGINAL event is redelivered. Under the old guard this deleted
    // the victim: its own entry was evicted, and the resend's entry looked
    // like somebody else's duplicate.
    await refire(victim);
    await assertIntact(
      victim,
      LONG_BODY,
      "the original message must survive a redelivery after eviction",
    );
  });

  // D9: the invariant everything else rests on, pinned directly.
  //
  // The stored entry must be stamped with the DOCUMENT's own `createTime`, not
  // with the time the trigger ran. D2 catches a regression here only by luck:
  // it went red on this machine because the emulator's clock happened to sit
  // ~5ms from the process's, and that gap was measured jittering in BOTH
  // directions and crossing zero. On a host where the two agree to the
  // millisecond, a mixed-clock regression passes D2 and ships.
  //
  // This case has no such dependency — it compares the stored value against
  // the document's own createTime, so it is exact on any machine.
  test("the stored entry is stamped from the document's createTime", async () => {
    __setChatGuardFlagForTests(true);
    await clearHashes();
    const a = `d9a-${RUN}`;
    await writeAndFire(a, body(CONV_A, LONG_BODY));

    const created = (await msgRef(a).get()).createTime!.toMillis();
    const rolling = await db
      .collection("users")
      .doc(SENDER)
      .collection("recentContentHashes")
      .doc("chat")
      .get();
    const hashes = (rolling.data()?.hashes ?? []) as {
      at: admin.firestore.Timestamp;
    }[];
    assert(hashes.length === 1, `expected one entry, got ${hashes.length}`);
    assert(
      hashes[0].at.toMillis() === created,
      `entry must carry the document's createTime (${created}), ` +
        `got ${hashes[0].at.toMillis()}`,
    );
  });

  // D10: the sender deletes the message between the create and this trigger.
  //
  // Only reachable because the guard MARKS now (BUT-1904): a delete had nothing
  // to race with, but an update does. `tx.set(..., {merge:true})` would recreate
  // a message its author had just removed — a deleted message reappearing,
  // emptied and stamped, is worse than the duplicate ever was.
  //
  // What this case pins is the OUTCOME, not the existence check: `tx.update` on
  // a missing document throws NOT_FOUND and the guard's own catch swallows it,
  // so the document stays absent with or without that check. The check earns
  // its place by turning a burnt transaction and an error log into a clean
  // no-op — which this case deliberately does NOT claim to prove.
  test("flag ON: a message deleted before the trigger runs is not recreated", async () => {
    __setChatGuardFlagForTests(true);
    await clearHashes();
    const a = `d10a-${RUN}`;
    const b = `d10b-${RUN}`;
    await writeAndFire(a, body(CONV_A, LONG_BODY));

    // Write the duplicate, then delete it BEFORE firing — the trigger receives
    // the snapshot it would have had, and the document is already gone.
    writtenMessageIds.push(b);
    const sent = body(CONV_A, LONG_BODY);
    await msgRef(b).set(sent);
    const snap = await msgRef(b).get();
    await msgRef(b).delete();

    // Must not throw: the guard's own catch would swallow it, but the
    // transaction failing is still a retried invocation and an error log.
    await guardDuplicateMessage.run({
      params: { messageId: b },
      data: snap,
      id: `evt-${b}`,
    });

    assert(
      !(await exists(b)),
      "a message its sender deleted must not be written back",
    );
    await assertIntact(
      a,
      LONG_BODY,
      "the surviving original must be untouched by all this",
    );
  });

  // D11: `exists()` is no longer a verdict, and this is what keeps it that way.
  //
  // Every case above was rewritten to assert INTACT or BLOCKED because the
  // guard stopped deleting. Nothing stops a future case being added that
  // asserts only that the document is still there, which would read like
  // proof and prove nothing. This scans the file's own source for that
  // shape. (Spelled around rather than quoted, here and above: the literal
  // would be a hit on this file itself.)
  test("no case proves innocence with a bare exists() any more", async () => {
    const source = await fs.readFile(__filename, "utf8");

    // Matches the CALL, across line breaks, not a single line. The first
    // version anchored at the start of a line and was graded against this
    // file's own pre-change bytes by the testing-specialist gate: it caught 10
    // of the 15 sites that existed, and missed every hand-wrapped one —
    //
    //     assert(
    //       await exists(victim),
    //       "…",
    //     );
    //
    // which is what any assertion carrying an explanation looks like, and the
    // norm in this suite. A guard that refuses the terse form and permits the
    // discursive one reads as closed while being open.
    //
    // Built from concatenation so neither the pattern nor the message below
    // contains the literal sequence it hunts for, which would make this case
    // fail on itself.
    const banned = "assert(" + "await exists(";
    const matches = source.match(new RegExp("assert\\(\\s*await exists\\(", "g"));
    assert(
      matches === null,
      `a bare \`${banned}…)\` cannot tell an untouched message from a ` +
        `blocked one — use assertIntact. Found ${matches?.length ?? 0}.`,
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

  // Cleanup. The emulator keeps data across runs, so anything left here is
  // permanent — including the rolling hash doc, which is not a message.
  __resetChatGuardFlagCacheForTests();
  for (const id of writtenMessageIds) {
    await msgRef(id).delete();
  }
  await clearHashes();

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
