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
    MAX_ROSTER_ROWS,
  } = require("../messaging/enforce-group-minor-membership");

  const userRef = (uid: string) => db.collection("users").doc(uid);
  const convRef = (id: string) => db.collection("conversations").doc(id);
  const membershipRef = (uid: string, convId: string) =>
    userRef(uid).collection("conversation_memberships").doc(convId);
  // The TOP-LEVEL roster row. A separate document from the membership mirror
  // above, in a separate collection, and until 2026-08-12 the trigger cleaned
  // up only the mirror. Once `conversations/{id}/participants` got a read rule,
  // a surviving row let an evicted minor keep reading the group's roster.
  const rosterRef = (uid: string, convId: string) =>
    convRef(convId).collection("participants").doc(uid);

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
    /** Roster rows to seat that are NOT in participantIds (see the collapse test). */
    extraRosterIds: string[] = [],
    /**
     * Runs AFTER the snapshot is read and BEFORE the trigger runs. The only way
     * to stage a concurrent delete: the trigger receives the snapshot the
     * create delivered, so the document must vanish between those two moments.
     */
    afterSnapshot?: () => Promise<void>,
  ): Promise<void> {
    await convRef(convId).set(doc);
    await Promise.all([
      ...participants.map((uid) => membershipRef(uid, convId).set({ convId })),
      // Seeded because production seeds it — but NOT atomically with the
      // conversation, and the difference is the whole reason the rules have a
      // bootstrap branch. `createGroupConversation` awaits the group create
      // (which lands under `users/{uid}/conversations/{id}`, because the
      // repository is user-scoped) and THEN calls `addParticipants`, which opens
      // its own batch. The TOP-LEVEL `conversations/{id}` document this trigger
      // fires on is written by neither; it materialises on the first message.
      // So in production these rows already exist by the time the parent
      // appears, which is the order staged here. A test that omitted them would
      // assert the cleanup against a collection that was empty anyway.
      ...[...participants, ...extraRosterIds].map((uid) =>
        rosterRef(uid, convId).set({ conversationId: convId, participantId: uid }),
      ),
    ]);
    const snap = await convRef(convId).get();
    if (afterSnapshot) await afterSnapshot();
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

    // The roster row is the DISCLOSURE half. Rules grant roster LIST to a
    // participant the parent NAMES, and — only while the parent is ABSENT — to
    // anyone holding a row. On THIS branch the parent survives and no longer
    // names the minor, so the rules half already denies them the read back; what
    // a surviving row leaks here is the other direction, the evicted minor's own
    // displayName and avatarUrl staying readable to the group that removed them.
    // The read-back case belongs to the COLLAPSE branch below, where the parent
    // is destroyed and rules cannot reach it. Stated separately on purpose: a
    // reader told the scoping is not load-bearing is a reader who deletes it.
    assert(
      !(await rosterRef(minor, conv).get()).exists,
      "removed minor's conversations/{id}/participants row must be deleted",
    );
    assert(
      (await rosterRef(adult, conv).get()).exists,
      "the adult's roster row must be left intact — the cleanup is scoped to the removed uids",
    );
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
      // Seeded BEFORE the trigger fires, via the same helper, so it is present
      // for the real handler rather than asserted into existence afterwards.
      ["a.b"],
    );

    const after = await convRef(conv).get();
    assert(!after.exists, "conversation must be deleted when it collapses below 2 members");
    assert(!(await membershipRef(minorA, conv).get()).exists, "minorA mirror must be cleaned up");
    assert(!(await membershipRef(minorB, conv).get()).exists, "minorB mirror must be cleaned up");

    // The collapse branch is the one rules CANNOT cover. Deleting the parent
    // makes `parentDoc() == null` true again, and rules cannot tell "destroyed"
    // from "not written yet" — so a surviving roster row would be readable, and
    // re-seatable, forever. Every row must go, including the SURVIVOR's: the
    // conversation it belonged to no longer exists.
    for (const uid of [creator, minorA, minorB]) {
      assert(
        !(await rosterRef(uid, conv).get()).exists,
        `roster row for ${uid} must be deleted when the conversation collapses`,
      );
    }
    // And the row NO UID LIST CAN NAME. The roster's writer keys off
    // `participantDisplayNames`, while every uid list in the trigger comes from
    // `participantIds` filtered by `isValidDocId` — so `a.b` is a legal document
    // id that the filter drops. Before the cleanup enumerated the collection,
    // this row survived under a deleted parent, permanently readable by whoever
    // seated it. This assertion is why the cleanup ENUMERATES the collection
    // rather than deriving a uid list; which enumeration primitive it uses is a
    // separate question, answered by the read having to be bounded.
    assert(
      !(await rosterRef("a.b", conv).get()).exists,
      "a roster row whose id is not a valid uid must ALSO be deleted on collapse",
    );
  });

  // 3. THE CALLER'S INVARIANT: never delete the conversation while roster rows
  //    may survive.
  //
  //    This is the assertion the whole change turns on, and until now nothing
  //    pinned it — measured: neutralising the gate to `(await tryClearRoster())
  //    || true`, i.e. deleting the parent even when rows survived, left the
  //    suite fully green, because every other collapse fixture has a roster that
  //    clears. The unit tests prove the HELPER returns false; they import the
  //    helper and never the handler, so they structurally cannot see whether the
  //    caller obeys it. A future reviewer would have deleted the gate and seen
  //    green.
  //
  //    Staged with an unclearable roster (one row over the cap, which is how a
  //    seeded roster presents), so the verdict is false and the trigger must
  //    take the update branch: parent standing, cut still landed.
  test("an unclearable roster leaves the shell standing, and still cuts the minors", async () => {
    const conv = `conv-shell-${RUN}`;
    const minorA = `minorA-shell-${RUN}`;
    const minorB = `minorB-shell-${RUN}`;
    await seedUser(minorA, true);
    await seedUser(minorB, true);
    // Same shape as the collapse test on purpose: BOTH minors are removed, so
    // `remaining` is [creator] and the trigger reaches the collapse branch. A
    // fixture that left two survivors would take the update branch and never
    // call `tryClearRoster` at all — the test would pass while proving nothing.
    await convRef(conv).set({
      isGroup: true,
      participantIds: [creator, minorA, minorB],
      metadata: { creatorId: creator },
    });
    for (let i = 0; i <= MAX_ROSTER_ROWS; i += 400) {
      const batch = db.batch();
      for (let j = i; j < Math.min(i + 400, MAX_ROSTER_ROWS + 1); j++) {
        batch.set(rosterRef(`seed-${j}`, conv), {
          conversationId: conv,
          participantId: `seed-${j}`,
        });
      }
      await batch.commit();
    }

    const snap = await convRef(conv).get();
    await enforceGroupMinorMembership.run({
      params: { conversationId: conv },
      data: snap,
    });

    const after = await convRef(conv).get();
    // THE assertion. Without the gate the collapse branch would have deleted
    // this document, which is what re-opens the bootstrap branch over the 501
    // rows that are still sitting there.
    assert(after.exists, "an unclearable roster must leave the parent STANDING");
    const ids = after.data()!.participantIds as string[];
    assert(
      !ids.includes(minorA) && !ids.includes(minorB),
      `the child-safety cut must still land, got ${JSON.stringify(ids)}`,
    );
    // The shell is what keeps the seeded roster denied: a live parent that no
    // longer names the minor satisfies neither disjunct of the read rule.
    assert(
      (await rosterRef(`seed-0`, conv).get()).exists,
      "tryClearRoster's refusal must delete NOTHING — a partial clear is the " +
        "worst outcome. (The trigger as a whole still clears the evicted uids' " +
        "rows below, since rosterCleared is false on this path.)",
    );
  });

  // 4. The concurrent-delete leg. Someone else deletes the conversation while
  //    the trigger runs, so `update()` throws NOT_FOUND. That is the OTHER
  //    parent-destroyed path, and the trailing per-uid cleanup only walks the
  //    REMOVED uids — so without the roster clear on this leg, the SURVIVORS'
  //    rows outlive the parent, readable and re-seatable. Had no execution
  //    coverage at all until this test.
  test("a conversation deleted mid-flight still gets its roster cleared", async () => {
    const conv = `conv-race-${RUN}`;
    const minor = `minor-race-${RUN}`;
    const other = `other-race-${RUN}`;
    await seedUser(minor, true);
    await seedUser(other, false);
    await createAndFire(
      conv,
      {
        isGroup: true,
        participantIds: [creator, adult, other, minor],
        metadata: { creatorId: creator },
      },
      [creator, adult, other, minor],
      [],
      // Delete the parent between reading the snapshot and running the trigger,
      // which is exactly what the code-5 branch exists for.
      async () => {
        await convRef(conv).delete();
      },
    );

    for (const uid of [creator, adult, other, minor]) {
      assert(
        !(await rosterRef(uid, conv).get()).exists,
        `roster row for ${uid} must be cleared when the parent vanished mid-flight`,
      );
    }
  });

  // 5. Keep path: a real friend doc for (minor, creator) means the minor was
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
    assert(
      (await rosterRef(friendMinor, conv).get()).exists,
      "kept minor's roster row stays — the cleanup must not fire on the keep path",
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
  const cleanupConvs = [
    `conv-padded-${RUN}`,
    `conv-update-${RUN}`,
    `conv-collapse-${RUN}`,
    `conv-shell-${RUN}`,
    `conv-race-${RUN}`,
    `conv-keep-${RUN}`,
  ];
  // Roster rows outlive their parent by design (no cascade), so sweep them
  // explicitly — otherwise every run leaves rows in the shared emulator
  // namespace under a deleted conversation, which is the exact state the
  // production fix exists to prevent.
  await Promise.all(
    cleanupConvs.map(async (c) => {
      const refs = await convRef(c).collection("participants").listDocuments();
      await Promise.all(refs.map((r) => r.delete().catch(() => undefined)));
      await convRef(c).delete().catch(() => undefined);
    }),
  );
  const cleanupUsers = [
    `minor-padded-${RUN}`,
    creator,
    adult,
    `minor-strip-${RUN}`,
    `minorA-${RUN}`,
    `minorB-${RUN}`,
    `minor-friend-${RUN}`,
    // The two tests added 2026-08-12. Six integration suites share the
    // `demo-test` namespace, so an unswept user doc is litter for all of them.
    `minorA-shell-${RUN}`,
    `minorB-shell-${RUN}`,
    `minor-race-${RUN}`,
    `other-race-${RUN}`,
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
