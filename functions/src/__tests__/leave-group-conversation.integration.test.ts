/**
 * BUT-1788 acceptance criterion 3 — emulator-backed, real Firestore I/O.
 *
 * The ticket says it verbatim: "Test runs against the emulator with real rules,
 * not a rules-free fake — the entire history of this bug is a green suite over a
 * denied write." The sibling unit test (`leave-group-conversation.test.ts`) pins
 * the authorization core and the write SHAPE against a hand-rolled db whose
 * `runTransaction` is a single-call passthrough and whose `update` only pushes
 * into an array: it never applies a write, so it cannot show that a member
 * actually leaves (criterion 1) or that an admin actually removes (criterion 2).
 *
 * This one runs `removeGroupParticipantWithDeps` against a live Firestore
 * emulator (127.0.0.1:8080), where the Admin SDK really applies `arrayRemove`,
 * really deletes the dot-path map keys, and really commits inside a transaction.
 *
 * Note on rules: this exercises the ADMIN SDK, which bypasses rules by design —
 * that is the whole point of moving the operation server-side. What it proves is
 * the half a fake cannot: that the write the client was denied does land, in the
 * shape the client and the deletion cascade expect.
 *
 * Skip gate: if 8080 does not answer, print SKIP and exit 0 — unless CI is set.
 *
 * Run: npx ts-node src/__tests__/leave-group-conversation.integration.test.ts
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

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}
function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

const UID_KEYED_MAPS = [
  "participantDisplayNames",
  "participantAvatarUrls",
  "lastReadTimestamps",
  "perUserSettings",
] as const;

async function run(): Promise<void> {
  console.log("BUT-1788: leaveGroupConversation INTEGRATION tests (firestore emulator)");
  console.log("======================================================================\n");

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
    removeGroupParticipantWithDeps,
  } = require("../messaging/leave-group-conversation") as {
    removeGroupParticipantWithDeps: (
      database: admin.firestore.Firestore,
      callerUid: string,
      conversationId: string,
      targetUid: string,
    ) => Promise<{
      success: boolean;
      removed: boolean;
      remainingParticipants: number;
    }>;
  };

  const convRef = (id: string) => db.collection("conversations").doc(id);
  const participantRef = (convId: string, uid: string) =>
    convRef(convId).collection("participants").doc(uid);
  const membershipRef = (uid: string, convId: string) =>
    db.collection("users").doc(uid).collection("conversation_memberships").doc(convId);

  const admin1 = `adm-${RUN}`;
  const member1 = `mem-${RUN}`;
  const other1 = `oth-${RUN}`;
  const stranger = `str-${RUN}`;

  const seededConvs: string[] = [];

  /** A real three-person group with all four uid-keyed maps populated. */
  async function seedGroup(convId: string): Promise<void> {
    seededConvs.push(convId);
    const now = admin.firestore.Timestamp.now();
    await convRef(convId).set({
      isGroup: true,
      participantIds: [admin1, member1, other1],
      participantDisplayNames: { [admin1]: "Ada", [member1]: "Bea", [other1]: "Cim" },
      participantAvatarUrls: { [member1]: "http://x/b.png" },
      lastReadTimestamps: { [admin1]: now, [member1]: now, [other1]: now },
      perUserSettings: { [member1]: { isMuted: true } },
      metadata: { creatorId: admin1 },
      title: "Middagsgänget",
      createdAt: now,
      updatedAt: now,
    });
    await Promise.all([
      participantRef(convId, member1).set({ userId: member1 }),
      membershipRef(member1, convId).set({ convId }),
    ]);
  }

  async function threadOf(convId: string) {
    return db.collection("messages").where("conversationId", "==", convId).get();
  }

  /** Criterion 1: a member actually leaves. */
  test("a member leaving is applied to the real document", async () => {
    const conv = `leave-self-${RUN}`;
    await seedGroup(conv);

    const res = await removeGroupParticipantWithDeps(db, member1, conv, member1);
    assert(res.removed, "removed must be true");
    assert(res.remainingParticipants === 2, `remaining should be 2, got ${res.remainingParticipants}`);

    const after = (await convRef(conv).get()).data()!;
    const ids = after.participantIds as string[];
    assert(
      !ids.includes(member1),
      `participantIds must shrink, got ${JSON.stringify(ids)}`,
    );
    assert(ids.length === 2, "the other two must remain");

    // All four uid-keyed maps — a partial application leaves a departed
    // member's name on a document they can no longer read.
    for (const map of UID_KEYED_MAPS) {
      const m = (after[map] ?? {}) as Record<string, unknown>;
      assert(!(member1 in m), `${map}.<uid> must be deleted, got ${JSON.stringify(m)}`);
    }
    // And the OTHER members' entries must survive the dot-path deletes.
    const names = after.participantDisplayNames as Record<string, unknown>;
    assert(names[admin1] === "Ada" && names[other1] === "Cim", "other members' names must survive");

    assert(!(await participantRef(conv, member1).get()).exists, "participants mirror deleted");
    assert(!(await membershipRef(member1, conv).get()).exists, "membership mirror deleted");

    const thread = await threadOf(conv);
    assert(thread.size === 1, `exactly one system message, got ${thread.size}`);
    const msg = thread.docs[0].data();
    assert(msg.senderId === "system", "system-authored row");
    assert(msg.content === "Bea har lämnat gruppen", `content was ${String(msg.content)}`);
    // The Art. 17 handle: the only queryable way the deletion cascade can find
    // a name embedded in free text under senderId "system".
    const meta = (msg.metadata ?? {}) as Record<string, unknown>;
    assert(meta.subjectUserId === member1, "metadata.subjectUserId names the departed member");
  });

  /** Criterion 2: an admin actually removes someone. */
  test("an admin removing a member is applied to the real document", async () => {
    const conv = `remove-member-${RUN}`;
    await seedGroup(conv);

    const res = await removeGroupParticipantWithDeps(db, admin1, conv, member1);
    assert(res.removed, "removed must be true");

    const ids = (await convRef(conv).get()).data()!.participantIds as string[];
    assert(!ids.includes(member1), "the removed member is gone from participantIds");
    assert(ids.includes(admin1), "the admin stays");
  });

  test("a non-admin cannot remove another member, and nothing is written", async () => {
    const conv = `deny-${RUN}`;
    await seedGroup(conv);

    let code = "";
    try {
      await removeGroupParticipantWithDeps(db, member1, conv, other1);
    } catch (e) {
      code = (e as { code?: string }).code ?? String(e);
    }
    assert(code === "permission-denied", `expected permission-denied, got ${code}`);

    const ids = (await convRef(conv).get()).data()!.participantIds as string[];
    assert(ids.length === 3, "membership untouched on denial");
    assert((await threadOf(conv)).empty, "no system message on denial");
  });

  test("a repeat leave writes no second system message", async () => {
    const conv = `idempotent-${RUN}`;
    await seedGroup(conv);

    await removeGroupParticipantWithDeps(db, member1, conv, member1);
    const res = await removeGroupParticipantWithDeps(db, member1, conv, member1);

    assert(res.success && !res.removed, "second call is a no-op success");
    const thread = await threadOf(conv);
    assert(thread.size === 1, `still exactly one system message, got ${thread.size}`);
  });

  test("a non-member learns nothing and writes nothing", async () => {
    const conv = `oracle-${RUN}`;
    await seedGroup(conv);

    const inGroup = await removeGroupParticipantWithDeps(db, stranger, conv, stranger);
    const missing = await removeGroupParticipantWithDeps(
      db,
      stranger,
      `no-such-conv-${RUN}`,
      stranger,
    );

    for (const [label, res] of [
      ["existing group", inGroup],
      ["missing conversation", missing],
    ] as const) {
      assert(res.success, `${label}: uniform success`);
      assert(!res.removed, `${label}: nothing removed`);
      assert(
        res.remainingParticipants === 0,
        `${label}: must disclose no member count, got ${res.remainingParticipants}`,
      );
    }

    const ids = (await convRef(conv).get()).data()!.participantIds as string[];
    assert(ids.length === 3, "an outsider's probe changes nothing");
    assert((await threadOf(conv)).empty, "an outsider's probe writes no message");
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
  for (const conv of seededConvs) {
    const thread = await threadOf(conv);
    await Promise.all(thread.docs.map((d) => d.ref.delete()));
    const parts = await convRef(conv).collection("participants").get();
    await Promise.all(parts.docs.map((d) => d.ref.delete()));
    await convRef(conv).delete().catch(() => undefined);
  }
  for (const uid of [admin1, member1, other1, stranger]) {
    const memberships = await db
      .collection("users")
      .doc(uid)
      .collection("conversation_memberships")
      .get();
    await Promise.all(memberships.docs.map((d) => d.ref.delete()));
    await db.collection("users").doc(uid).delete().catch(() => undefined);
  }

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
