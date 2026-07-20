/**
 * BUT-1633 — emulator-backed integration test for `enforceGroupMinorMembership`.
 *
 * The sibling unit test (`enforce-group-minor-membership.test.ts`) pins only the
 * pure decision core, `computeMinorsToRemove`. This test exercises the REAL
 * exported trigger via the v2 `CloudFunction.run(event)` surface against a live
 * Firestore emulator (127.0.0.1:8080), covering the destructive-I/O branches the
 * unit test cannot reach:
 *   - the `update` branch (group stays viable ≥2): the non-friend minor is
 *     stripped from participantIds AND their participant sub-maps are cleared;
 *   - the per-user `conversation_memberships` mirror cleanup delete;
 *   - the `delete` branch (group collapses <2): the whole conversation doc is
 *     removed rather than left as a one-person shell;
 *   - the friend-of-creator KEEP path: a real friend doc prevents any removal.
 *
 * The reads it performs (users/{uid}.isMinor, users/{minor}/friends/{creator})
 * hit real emulator docs, so this proves the batched getAll wiring end to end,
 * not just the pure filter.
 *
 * Skip gate (local machines without the emulator / Java): if 8080 doesn't
 * answer, print SKIP and exit 0 — unless CI is set, where a missing emulator
 * is a hard failure (the CI lane starts it explicitly).
 *
 * Run: npx ts-node src/__tests__/enforce-group-minor-membership.integration.test.ts
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

async function run(): Promise<void> {
  console.log("BUT-1633: enforceGroupMinorMembership INTEGRATION tests (firestore emulator)");
  console.log("==========================================================================\n");

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
    enforceGroupMinorMembership,
  } = require("../messaging/enforce-group-minor-membership");

  const userRef = (uid: string) => db.collection("users").doc(uid);
  const convRef = (id: string) => db.collection("conversations").doc(id);
  const membershipRef = (uid: string, convId: string) =>
    userRef(uid).collection("conversation_memberships").doc(convId);

  /** Seed a user doc with the given minor status. */
  async function seedUser(uid: string, isMinor: boolean): Promise<void> {
    await userRef(uid).set({ isMinor });
  }

  /** Seed the directional friend doc the trigger checks: users/{minor}/friends/{creator}. */
  async function seedFriend(minorUid: string, creatorUid: string): Promise<void> {
    await userRef(minorUid).collection("friends").doc(creatorUid).set({
      createdAt: admin.firestore.Timestamp.now(),
    });
  }

  /**
   * Create a conversation doc + each participant's membership mirror, read the
   * created doc back, and fire the REAL trigger with the exact event shape
   * onDocumentCreated delivers: { params: { conversationId }, data: snapshot }.
   */
  async function createAndFire(
    convId: string,
    doc: Record<string, unknown>,
    participants: string[],
  ): Promise<void> {
    await convRef(convId).set(doc);
    await Promise.all(
      participants.map((uid) => membershipRef(uid, convId).set({ convId })),
    );
    const snap = await convRef(convId).get();
    await enforceGroupMinorMembership.run({
      params: { conversationId: convId },
      data: snap,
    });
  }

  const creator = `creator-${RUN}`;
  const adult = `adult-${RUN}`;

  // 0. PADDING BYPASS (BUT-1633 Critical regression). firestore.rules applies
  //    passesMinorDmGate only at RAW size()==2, so a tampered client pads a 1:1
  //    with one junk entry: rules see 3 and skip the DM gate. If this trigger
  //    sized itself on the SANITISED list it would see 2, return early, and the
  //    minor would be gated by NEITHER layer. This case is RED on the pre-fix
  //    code (filtered gate) and green on the raw gate.
  test("padded 1:1: a junk entry does not let a non-friend DM a minor slip the gate", async () => {
    const conv = `conv-padded-${RUN}`;
    const minor = `minor-padded-${RUN}`;
    await seedUser(minor, true);
    // No friend doc for (minor, creator) → not their friend.
    await createAndFire(
      conv,
      {
        isGroup: false, // rules saw size()==3 and skipped the DM gate
        participantIds: [creator, minor, "__x__"],
        metadata: { creatorId: creator },
      },
      [creator, minor],
    );
    const after = await convRef(conv).get();
    assert(
      !after.exists,
      "padded 1:1 must collapse below 2 and be deleted, not left containing the minor",
    );
    assert(
      !(await membershipRef(minor, conv).get()).exists,
      "the minor's membership mirror must be cleaned up",
    );
  });

  // 1. Update branch: a non-friend creator added a minor to a 3-person group.
  //    The minor is stripped; the group stays viable (creator + adult remain).
  test("update branch: strips a non-friend-added minor and clears its sub-maps", async () => {
    const conv = `conv-update-${RUN}`;
    const minor = `minor-strip-${RUN}`;
    await seedUser(adult, false);
    await seedUser(minor, true);
    // No friend doc for (minor, creator) → the creator is not their friend.
    await createAndFire(
      conv,
      {
        isGroup: true,
        participantIds: [creator, adult, minor],
        metadata: { creatorId: creator },
        participantDisplayNames: { [creator]: "C", [adult]: "A", [minor]: "M" },
        participantAvatarUrls: { [minor]: "http://x/m.png" },
        lastReadTimestamps: { [minor]: admin.firestore.Timestamp.now() },
      },
      [creator, adult, minor],
    );

    const after = (await convRef(conv).get()).data()!;
    const ids = after.participantIds as string[];
    assert(after !== undefined, "conversation must still exist (group stayed viable)");
    assert(!ids.includes(minor), `minor must be removed from participantIds, got ${JSON.stringify(ids)}`);
    assert(ids.includes(creator) && ids.includes(adult), "creator and adult must remain");
    const names = (after.participantDisplayNames ?? {}) as Record<string, unknown>;
    assert(!(minor in names), "participantDisplayNames.<minor> must be deleted");
    const avatars = (after.participantAvatarUrls ?? {}) as Record<string, unknown>;
    assert(!(minor in avatars), "participantAvatarUrls.<minor> must be deleted");
    const reads = (after.lastReadTimestamps ?? {}) as Record<string, unknown>;
    assert(!(minor in reads), "lastReadTimestamps.<minor> must be deleted");

    const mirror = await membershipRef(minor, conv).get();
    assert(!mirror.exists, "removed minor's conversation_memberships mirror must be deleted");
    const adultMirror = await membershipRef(adult, conv).get();
    assert(adultMirror.exists, "the adult's membership mirror must be left intact");
  });

  // 2. Delete branch: removing every non-friend minor collapses the group below
  //    two members → the whole conversation is deleted, not left as a shell.
  test("delete branch: collapsing below 2 members deletes the conversation", async () => {
    const conv = `conv-collapse-${RUN}`;
    const minorA = `minorA-${RUN}`;
    const minorB = `minorB-${RUN}`;
    await seedUser(minorA, true);
    await seedUser(minorB, true);
    // Creator is a friend of neither → both minors removed → only creator left.
    await createAndFire(
      conv,
      {
        isGroup: true,
        participantIds: [creator, minorA, minorB],
        metadata: { creatorId: creator },
      },
      [creator, minorA, minorB],
    );

    const after = await convRef(conv).get();
    assert(!after.exists, "conversation must be deleted when it collapses below 2 members");
    assert(!(await membershipRef(minorA, conv).get()).exists, "minorA mirror must be cleaned up");
    assert(!(await membershipRef(minorB, conv).get()).exists, "minorB mirror must be cleaned up");
  });

  // 3. Keep path: a real friend doc for (minor, creator) means the minor was
  //    added by a friend → no removal, participantIds untouched.
  test("keep path: a minor whose friend is the creator is not removed", async () => {
    const conv = `conv-keep-${RUN}`;
    const friendMinor = `minor-friend-${RUN}`;
    await seedUser(friendMinor, true);
    await seedFriend(friendMinor, creator);
    await createAndFire(
      conv,
      {
        isGroup: true,
        participantIds: [creator, adult, friendMinor],
        metadata: { creatorId: creator },
      },
      [creator, adult, friendMinor],
    );

    const after = (await convRef(conv).get()).data()!;
    const ids = after.participantIds as string[];
    assert(ids.includes(friendMinor), "a friend-added minor must be kept");
    assert(ids.length === 3, `no one should be removed, got ${JSON.stringify(ids)}`);
    assert((await membershipRef(friendMinor, conv).get()).exists, "kept minor's membership mirror stays");
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
  const cleanupConvs = [
    `conv-padded-${RUN}`,
    `conv-update-${RUN}`,
    `conv-collapse-${RUN}`,
    `conv-keep-${RUN}`,
  ];
  await Promise.all(cleanupConvs.map((c) => convRef(c).delete().catch(() => undefined)));
  const cleanupUsers = [
    `minor-padded-${RUN}`,
    creator,
    adult,
    `minor-strip-${RUN}`,
    `minorA-${RUN}`,
    `minorB-${RUN}`,
    `minor-friend-${RUN}`,
  ];
  for (const uid of cleanupUsers) {
    const friends = await userRef(uid).collection("friends").get();
    await Promise.all(friends.docs.map((d) => d.ref.delete()));
    const memberships = await userRef(uid).collection("conversation_memberships").get();
    await Promise.all(memberships.docs.map((d) => d.ref.delete()));
    await userRef(uid).delete().catch(() => undefined);
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
