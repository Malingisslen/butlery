/**
 * BUT-1633, rewritten for BUT-1838 — emulator-backed integration test for the
 * minor-membership BACKSTOP.
 *
 * The trigger changed shape completely, so the fixtures had to. It now fires on
 * `onDocumentWritten("chat_groups/{groupId}")` rather than on the CREATE of
 * `conversations/{id}`, judges each member against `memberAddedBy[uid]` — whoever
 * actually seated THEM — rather than against one creator, and evicts through
 * `stageMemberRemoval`, which writes the group, the conversation and the roster
 * row from one value.
 *
 * What it still exists to prove is unchanged: the destructive-I/O branches the
 * unit suites cannot reach. The reads hit real emulator documents
 * (`users/{uid}.isMinor`, `users/{minor}/friends/{adder}`), so this covers the
 * batched `getAll` wiring end to end, not just the pure filter.
 *
 * **Cases deliberately NOT carried over**, each because the behaviour it pinned
 * no longer exists in this file:
 *  - *"padded 1:1: a junk entry does not let a non-friend DM a minor slip the
 *    gate"*. That case existed because `firestore.rules` applied
 *    `passesMinorDmGate` at RAW `participantIds.size() == 2`, so the trigger had
 *    to size itself on the raw list or a padded conversation fell between two
 *    layers. No rule reads `chat_groups.memberIds` at all — membership is
 *    server-written — so there is no second layer to stay in step with, and the
 *    trigger now judges the sanitised list. The equivalent protection moved to
 *    the gate, BEFORE the write (`minor-membership-gate.test.ts`).
 *  - *"delete branch: collapsing below 2 members deletes the conversation"* and
 *    *"an unclearable roster leaves the shell standing"*. This trigger no longer
 *    owns a conversation's lifecycle: it cuts membership and nothing else. The
 *    collapse-and-delete decision, and the `tryClearRoster` verdict that gates
 *    it, moved to `removeChatGroupMember` and are pinned there
 *    (`chat-group-callables.test.ts`), including the case where the verdict is
 *    FALSE and both documents must survive. `tryClearRoster`'s own read/delete
 *    failure paths stay in `enforce-group-minor-membership.test.ts`.
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
  console.log("BUT-1838: enforceGroupMinorMembership INTEGRATION tests (firestore emulator)");
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
    MAX_GROUP_PARTICIPANTS,
  } = require("../messaging/enforce-group-minor-membership");

  const userRef = (uid: string) => db.collection("users").doc(uid);
  const groupRef = (id: string) => db.collection("chat_groups").doc(id);
  const convRef = (id: string) => db.collection("conversations").doc(id);
  const membershipRef = (uid: string, convId: string) =>
    userRef(uid).collection("conversation_memberships").doc(convId);
  // The TOP-LEVEL roster row: a separate document from the membership mirror
  // above, in a separate collection, and the one that carries a display name and
  // an avatar. An evicted member whose row survives keeps both readable by the
  // group that removed them.
  const rosterRef = (uid: string, convId: string) =>
    convRef(convId).collection("participants").doc(uid);

  const seededGroups: string[] = [];
  const seededUsers = new Set<string>();

  async function seedUser(uid: string, isMinor: boolean): Promise<void> {
    seededUsers.add(uid);
    await userRef(uid).set({ isMinor });
  }

  /** The directional friend edge the gate checks: users/{minor}/friends/{adder}. */
  async function seedFriend(minorUid: string, adderUid: string): Promise<void> {
    seededUsers.add(minorUid);
    await userRef(minorUid).collection("friends").doc(adderUid).set({
      createdAt: admin.firestore.Timestamp.now(),
    });
  }

  /**
   * Seeds the three documents a real group is made of — written the way
   * `stageGroupCreation` writes them, from one timestamp — plus each member's
   * roster row and conversation-membership mirror.
   */
  async function seedGroup(
    groupId: string,
    members: string[],
    addedBy: Record<string, string>,
    overrides: Record<string, unknown> = {},
  ): Promise<string> {
    seededGroups.push(groupId);
    const convId = groupId;
    const now = admin.firestore.Timestamp.now();
    const perUid = <T>(value: T): Record<string, T> =>
      Object.fromEntries(members.map((uid) => [uid, value]));

    await groupRef(groupId).set({
      name: "Familjen",
      memberIds: members,
      adminIds: [members[0]],
      memberDisplayNames: Object.fromEntries(members.map((u) => [u, u.slice(0, 8)])),
      memberAvatarUrls: perUid<string | null>(null),
      memberAddedBy: addedBy,
      conversationId: convId,
      createdBy: members[0],
      createdAt: now,
      updatedAt: now,
      ...overrides,
    });
    await convRef(convId).set({
      participantIds: members,
      participantDisplayNames: Object.fromEntries(
        members.map((u) => [u, u.slice(0, 8)]),
      ),
      participantAvatarUrls: perUid("http://x/a.png"),
      lastReadTimestamps: perUid(now),
      perUserSettings: {},
      memberSince: perUid(now),
      groupId,
      isGroup: true,
      title: "Familjen",
      createdAt: now,
      updatedAt: now,
    });
    await Promise.all(
      members.flatMap((uid) => [
        membershipRef(uid, convId).set({ convId }),
        rosterRef(uid, convId).set({
          conversationId: convId,
          participantId: uid,
          displayName: uid.slice(0, 8),
          joinedAt: now,
        }),
      ]),
    );
    return convId;
  }

  /**
   * Fires the REAL trigger with the event shape onDocumentWritten delivers:
   * `{ params: { groupId }, data: { before, after } }`. `afterSnapshot` runs
   * between reading the snapshot and running the handler — the only way to stage
   * a document that vanishes mid-flight.
   */
  async function fire(
    groupId: string,
    afterSnapshot?: () => Promise<void>,
  ): Promise<void> {
    const snap = await groupRef(groupId).get();
    if (afterSnapshot) await afterSnapshot();
    await enforceGroupMinorMembership.run({
      params: { groupId },
      data: { before: snap, after: snap },
    });
  }

  const creator = `creator-${RUN}`;
  const adult = `adult-${RUN}`;

  // 1. The update branch: a minor seated by someone who is not their friend is
  //    stripped from all three copies of the membership.
  test("strips a non-friend-added minor from the group, the conversation and the roster", async () => {
    const gid = `grp-update-${RUN}`;
    const minor = `minor-strip-${RUN}`;
    await seedUser(creator, false);
    await seedUser(adult, false);
    await seedUser(minor, true);
    // No friend doc for (minor, creator) → the adder is not their friend.
    const conv = await seedGroup(gid, [creator, adult, minor], {
      [creator]: creator,
      [adult]: creator,
      [minor]: creator,
    });

    await fire(gid);

    const group = (await groupRef(gid).get()).data()!;
    const memberIds = group.memberIds as string[];
    assert(
      !memberIds.includes(minor),
      `minor must be removed from memberIds, got ${JSON.stringify(memberIds)}`,
    );
    assert(
      memberIds.includes(creator) && memberIds.includes(adult),
      "creator and adult must remain",
    );
    for (const map of ["memberDisplayNames", "memberAvatarUrls", "memberAddedBy"]) {
      const m = (group[map] ?? {}) as Record<string, unknown>;
      assert(!(minor in m), `chat_groups.${map}.<minor> must be deleted`);
    }

    const convo = (await convRef(conv).get()).data()!;
    const ids = convo.participantIds as string[];
    assert(!ids.includes(minor), "minor must lose conversation membership too");
    for (const map of [
      "participantDisplayNames",
      "participantAvatarUrls",
      "lastReadTimestamps",
      "perUserSettings",
      "memberSince",
    ]) {
      const m = (convo[map] ?? {}) as Record<string, unknown>;
      assert(!(minor in m), `conversations.${map}.<minor> must be deleted`);
    }
    // The history cut-off is the one that must not linger: a stale `memberSince`
    // would silently pin an old cut-off if the person were ever re-added.
    const names = convo.participantDisplayNames as Record<string, unknown>;
    assert(adult in names, "the adult's entries must survive the dot-path deletes");

    assert(
      !(await rosterRef(minor, conv).get()).exists,
      "the evicted minor's roster row must be deleted — it carries their name and avatar",
    );
    assert(
      (await rosterRef(adult, conv).get()).exists,
      "the adult's roster row must be left intact — the cut is scoped to the removed uids",
    );
    assert(
      !(await membershipRef(minor, conv).get()).exists,
      "the evicted minor's conversation_memberships mirror must be cleaned up",
    );
    assert(
      (await membershipRef(adult, conv).get()).exists,
      "the adult's membership mirror must be left intact",
    );
  });

  // 2. THE CASE THE OLD TRIGGER COULD NOT EXPRESS, and the reason BUT-1838
  //    exists. Two minors in one group seated by two different people: the one
  //    whose own adder is their friend stays, the one added later by a stranger
  //    goes. A trigger keyed on a single creator had to give both the same
  //    answer, which is why anyone added after creation was checked by nobody.
  test("judges each minor against whoever actually seated them", async () => {
    const gid = `grp-per-member-${RUN}`;
    const otherAdmin = `admin2-${RUN}`;
    const minorOk = `minor-ok-${RUN}`;
    const minorLater = `minor-later-${RUN}`;
    await seedUser(creator, false);
    await seedUser(otherAdmin, false);
    await seedUser(minorOk, true);
    await seedUser(minorLater, true);
    // minorOk is a friend of the creator, who added them.
    await seedFriend(minorOk, creator);
    // minorLater is a friend of the CREATOR too — but otherAdmin added them,
    // and it is the adder the gate has to ask about. Without the per-member
    // lookup this fixture would keep them.
    await seedFriend(minorLater, creator);

    const conv = await seedGroup(gid, [creator, otherAdmin, minorOk, minorLater], {
      [creator]: creator,
      [otherAdmin]: creator,
      [minorOk]: creator,
      [minorLater]: otherAdmin,
    });

    await fire(gid);

    const memberIds = (await groupRef(gid).get()).data()!.memberIds as string[];
    assert(
      memberIds.includes(minorOk),
      `a minor added by their own friend must stay, got ${JSON.stringify(memberIds)}`,
    );
    assert(
      !memberIds.includes(minorLater),
      `a minor added by a non-friend must go, got ${JSON.stringify(memberIds)}`,
    );
    assert(
      (await rosterRef(minorOk, conv).get()).exists &&
        !(await rosterRef(minorLater, conv).get()).exists,
      "roster rows must follow the same per-member verdict",
    );
  });

  // 3. Keep path: a real friend doc means no removal at all, and no write.
  test("a minor whose adder is their friend is not removed", async () => {
    const gid = `grp-keep-${RUN}`;
    const friendMinor = `minor-friend-${RUN}`;
    await seedUser(creator, false);
    await seedUser(adult, false);
    await seedUser(friendMinor, true);
    await seedFriend(friendMinor, creator);
    const conv = await seedGroup(gid, [creator, adult, friendMinor], {
      [creator]: creator,
      [adult]: creator,
      [friendMinor]: creator,
    });

    await fire(gid);

    const memberIds = (await groupRef(gid).get()).data()!.memberIds as string[];
    assert(memberIds.includes(friendMinor), "a friend-added minor must be kept");
    assert(memberIds.length === 3, `no one should be removed, got ${JSON.stringify(memberIds)}`);
    assert(
      (await rosterRef(friendMinor, conv).get()).exists,
      "kept minor's roster row stays — the cleanup must not fire on the keep path",
    );
    assert(
      (await membershipRef(friendMinor, conv).get()).exists,
      "kept minor's membership mirror stays",
    );
  });

  // 4. CONVERGENCE. The eviction write re-fires this same trigger, so the second
  //    pass must find nothing to do. Without that property a `retry:true`
  //    trigger that always writes is an infinite, billed loop.
  test("re-firing on the post-eviction state removes nothing", async () => {
    const gid = `grp-converge-${RUN}`;
    const minor = `minor-converge-${RUN}`;
    await seedUser(creator, false);
    await seedUser(adult, false);
    await seedUser(minor, true);
    await seedGroup(gid, [creator, adult, minor], {
      [creator]: creator,
      [adult]: creator,
      [minor]: creator,
    });

    await fire(gid);
    const afterFirst = (await groupRef(gid).get()).data()!;
    await fire(gid);
    const afterSecond = (await groupRef(gid).get()).data()!;

    assert(
      !(afterFirst.memberIds as string[]).includes(minor),
      "the first pass must remove the minor",
    );
    assert(
      JSON.stringify(afterSecond.memberIds) === JSON.stringify(afterFirst.memberIds),
      "the second pass must change nothing",
    );
    assert(
      (afterSecond.updatedAt as admin.firestore.Timestamp).isEqual(
        afterFirst.updatedAt as admin.firestore.Timestamp,
      ),
      "the second pass must not even stamp updatedAt — it wrote nothing",
    );
  });

  // 5. An implausible membership refuses the read fan-out rather than paying an
  //    unbounded, retry-replayed read bill. Only reachable if something wrote
  //    the document without asking the callables — which is the case this
  //    trigger exists for, so the refusal is deliberately LOUD and inert rather
  //    than a partial check.
  test("an implausibly large group refuses the fan-out and writes nothing", async () => {
    const gid = `grp-huge-${RUN}`;
    const minor = `minor-huge-${RUN}`;
    await seedUser(minor, true);
    const filler = Array.from(
      { length: MAX_GROUP_PARTICIPANTS },
      (_, i) => `filler-${i}-${RUN}`,
    );
    // Written directly rather than through `seedGroup`: no user documents, no
    // roster rows and no mirrors for the filler uids, because the guard must
    // return BEFORE any read. A fixture that needed them seeded would be
    // measuring the reads instead of the refusal — and would litter the shared
    // demo-test namespace with 100 unswept users.
    seededGroups.push(gid);
    await groupRef(gid).set({
      name: "Seeded",
      memberIds: [...filler, minor],
      adminIds: [filler[0]],
      memberAddedBy: { [minor]: filler[0] },
      conversationId: gid,
      createdBy: filler[0],
    });

    await fire(gid);

    const memberIds = (await groupRef(gid).get()).data()!.memberIds as string[];
    assert(
      memberIds.length === MAX_GROUP_PARTICIPANTS + 1 && memberIds.includes(minor),
      `the fan-out must be refused, not partially applied, got ${memberIds.length} members`,
    );
  });

  // 6. The group is deleted between the event and the write. `tx.get` finds
  //    nothing, so the eviction is a no-op rather than a resurrection — a
  //    `tx.update` on a missing document would otherwise recreate nothing but
  //    throw, and under retry:true that throw repeats forever.
  test("a group deleted mid-flight is a no-op, not a resurrection", async () => {
    const gid = `grp-gone-${RUN}`;
    const minor = `minor-gone-${RUN}`;
    await seedUser(creator, false);
    await seedUser(adult, false);
    await seedUser(minor, true);
    await seedGroup(gid, [creator, adult, minor], {
      [creator]: creator,
      [adult]: creator,
      [minor]: creator,
    });

    await fire(gid, async () => {
      await groupRef(gid).delete();
    });

    assert(
      !(await groupRef(gid).get()).exists,
      "the deleted group must not be recreated by the eviction write",
    );
  });

  // 7. The conversation is deleted mid-flight, so the transaction's update
  //    against it throws NOT_FOUND (grpc 5). That is DETERMINISTIC: rethrowing
  //    it would hand a retry:true trigger an error to loop on forever, re-billing
  //    the read fan-out each time. The handler must swallow exactly that code and
  //    still finish its best-effort mirror cleanup.
  test("a conversation deleted mid-flight does not become a retry loop", async () => {
    const gid = `grp-race-${RUN}`;
    const minor = `minor-race-${RUN}`;
    await seedUser(creator, false);
    await seedUser(adult, false);
    await seedUser(minor, true);
    const conv = await seedGroup(gid, [creator, adult, minor], {
      [creator]: creator,
      [adult]: creator,
      [minor]: creator,
    });

    let threw = "";
    try {
      await fire(gid, async () => {
        await convRef(conv).delete();
      });
    } catch (e) {
      threw = (e as Error).message;
    }
    assert(threw === "", `the handler must not rethrow NOT_FOUND, got ${threw}`);
    assert(
      !(await membershipRef(minor, conv).get()).exists,
      "the best-effort mirror cleanup must still run after the swallowed code-5",
    );
  });

  // 8. A group with members and no usable conversation id: nothing to cut access
  //    to and no path to build. It must refuse loudly rather than splice a junk
  //    id into a document path.
  test("a group with no usable conversationId writes nothing", async () => {
    const gid = `grp-noconv-${RUN}`;
    const minor = `minor-noconv-${RUN}`;
    await seedUser(creator, false);
    await seedUser(adult, false);
    await seedUser(minor, true);
    await seedGroup(
      gid,
      [creator, adult, minor],
      { [creator]: creator, [adult]: creator, [minor]: creator },
      { conversationId: "a/b" },
    );

    await fire(gid);

    const memberIds = (await groupRef(gid).get()).data()!.memberIds as string[];
    assert(
      memberIds.includes(minor),
      "with no conversation to cut, the group is left untouched rather than half-written",
    );
  });

  // 9. The group document itself is gone by the time the trigger runs — the
  //    delete half of onDocumentWritten. Nothing left to protect.
  test("a deleted group snapshot is ignored", async () => {
    const gid = `grp-deleted-${RUN}`;
    const snap = await groupRef(gid).get(); // never written
    await enforceGroupMinorMembership.run({
      params: { groupId: gid },
      data: { before: snap, after: snap },
    });
    assert(!(await groupRef(gid).get()).exists, "nothing is created for a missing group");
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

  // Cleanup the shared demo-test namespace. Roster rows outlive their parent by
  // design (no cascade), so sweep them explicitly — otherwise every run leaves
  // rows under a deleted conversation, which is the exact state the production
  // code exists to prevent.
  await Promise.all(
    seededGroups.map(async (gid) => {
      const rows = await convRef(gid).collection("participants").listDocuments();
      await Promise.all(rows.map((r) => r.delete().catch(() => undefined)));
      await convRef(gid).delete().catch(() => undefined);
      await groupRef(gid).delete().catch(() => undefined);
    }),
  );
  for (const uid of seededUsers) {
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
