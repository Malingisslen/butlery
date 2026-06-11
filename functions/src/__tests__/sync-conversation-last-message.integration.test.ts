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
 *
 * Isolation: per-run unique conversation + message ids; docs are deleted in
 * cleanup so the shared demo-test namespace stays unpolluted.
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
