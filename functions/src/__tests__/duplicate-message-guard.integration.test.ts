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
 *   D2. Flag ON, true duplicate in ONE conversation -> the second is deleted.
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
  test("flag OFF: a true duplicate is NOT deleted", async () => {
    __setChatGuardFlagForTests(false);
    await clearHashes();
    const a = `d1a-${RUN}`;
    const b = `d1b-${RUN}`;
    await writeAndFire(a, body(CONV_A, LONG_BODY));
    await writeAndFire(b, body(CONV_A, LONG_BODY));
    assert(await exists(a), "the first message must survive");
    assert(
      await exists(b),
      "with the flag off the guard must not delete anything",
    );
  });

  // D2: the guard doing its job. Also the control that makes D3, D4, D5 and D6
  // attributable — without it they could all pass because the trigger never
  // fires at all, which is precisely the bug this ticket fixes.
  test("flag ON: a repeat in the SAME conversation is deleted", async () => {
    __setChatGuardFlagForTests(true);
    await clearHashes();
    const a = `d2a-${RUN}`;
    const b = `d2b-${RUN}`;
    await writeAndFire(a, body(CONV_A, LONG_BODY));
    await writeAndFire(b, body(CONV_A, LONG_BODY));
    assert(await exists(a), "the first message must survive");
    assert(!(await exists(b)), "the repeat must be deleted");
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
    assert(await exists(a), "the first conversation's message must survive");
    assert(
      await exists(b),
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
    assert(await exists(a), "the first short message must survive");
    assert(await exists(b), "a repeated short message must survive");
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
    await writeAndFire(a, body(CONV_A, "Anna har lagts till i gruppen", "system"));
    await writeAndFire(b, body(CONV_A, "Anna har lagts till i gruppen", "system"));
    assert(await exists(a), "the first system row must survive");
    assert(await exists(b), "a repeated system row must survive");
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
    assert(await exists(a), "the first must survive");
    assert(
      await exists(b),
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
    assert(await exists(a), "precondition: the message was accepted");
    await refire(a);
    assert(
      await exists(a),
      "a redelivery must not delete the message it accepted",
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
    assert(await exists(victim), "precondition: the message was accepted");

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
    assert(
      await exists(victim),
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
