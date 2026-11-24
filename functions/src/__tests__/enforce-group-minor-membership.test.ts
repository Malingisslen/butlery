/**
 * BUT-1626: unit tests for `isValidDocId`.
 *
 * The decision core these used to live beside moved to
 * `minor-membership-gate.test.ts` when BUT-1838 made the gate the primary
 * control and this trigger the backstop; the uid-safety cases stayed here.
 *
 * BUT-2490 adds the early return: `membershipUnchanged`, and the trigger's
 * core run against `_fake-firestore.ts` behind a proxy that counts every
 * access to the database handle, so "reads nothing" is measured.
 *
 * Run: npx ts-node src/__tests__/enforce-group-minor-membership.test.ts
 */

import { Firestore, Timestamp } from "firebase-admin/firestore";
import { getApps, initializeApp } from "firebase-admin/app";
import { isValidDocId } from "../shared/valid-doc-id";
import {
  enforceGroupMinorMembershipCore,
  membershipUnchanged,
} from "../messaging/enforce-group-minor-membership";
import { FakeFirestore } from "./_fake-firestore";

if (!getApps().length) {
  initializeApp({ projectId: "butlery-test-enforce-group-minor-membership" });
}

let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}`);
    if (detail) console.log(`        ${detail}`);
  }
}

console.log("isValidDocId (hostile participantIds — BUT-1633)");

// A uid Firestore rejects as a doc id must be DROPPED, never passed to a
// `users/${uid}` path build. A throw there aborts before any minor is removed
// (fail-OPEN on a child-safety gate) and, under retry:true, repeats forever.
for (const bad of ["", "a/b", ".", "..", "__proto__", "__id__"]) {
  check(
    `rejects the malformed uid ${JSON.stringify(bad)}`,
    !isValidDocId(bad),
  );
}

// Note "..leading" is NOT here: it contains dots, so it is field-path-unsafe
// and correctly rejected — only the bare "." and ".." are doc-id-invalid.
for (const good of ["abc123", "__x", "x__", "aB9-_"]) {
  check(
    `accepts the ordinary uid ${JSON.stringify(good)}`,
    isValidDocId(good),
  );
}

check("rejects a non-string uid", !isValidDocId(42 as unknown));

// A uid that is a legal DOCUMENT ID but an illegal FIELD-PATH segment is the
// nastier case: update() rejects it with INVALID_ARGUMENT (grpc 3, not the
// NOT_FOUND 5 we catch), which retry:true replays forever while the minor is
// never removed. A dotted uid is wrong even when it does not throw —
// `participantDisplayNames.a.b` addresses a nested map, not the key "a.b".
for (const bad of ["a.b", "..leading", "u[0]", "u]", "wild*card", "back`tick"]) {
  check(
    `rejects the field-path-unsafe uid ${JSON.stringify(bad)}`,
    !isValidDocId(bad),
  );
}

check("rejects an over-length uid (1500-byte cap)", !isValidDocId("a".repeat(1501)));
check("rejects an over-length multibyte uid", !isValidDocId("ä".repeat(800)));
check("accepts a uid at the byte cap", isValidDocId("a".repeat(1500)));

// NOTE: the raw-vs-sanitised padding bypass this file used to point at is gone
// with the trigger's move to `chat_groups` (BUT-1838): rules DO read that document's membership (the group's read gates on
// `uid in memberIds`, rename on `adminIds`), but never for a SIZE decision, and
// no client may write the list — so there is no second layer for a padded list
// to slip between.
// The equivalent guard now lives at the gate, before the write.

console.log("\nmembershipUnchanged (BUT-2490)");

const EARLIER = Timestamp.fromMillis(1_500_000_000_000);
const RULE = { id: "5-middag", weekday: 5, meal: "middag", kind: "tag", value: "taco", quick: false, paused: false };

/** A group whose members were all seated by `creator`. */
function groupData(members: string[], extra: Record<string, unknown> = {}): Record<string, unknown> {
  return {
    name: "Familjen",
    memberIds: members,
    adminIds: ["creator"],
    memberDisplayNames: Object.fromEntries(members.map((u) => [u, u])),
    memberAvatarUrls: Object.fromEntries(members.map((u) => [u, null])),
    memberAddedBy: Object.fromEntries(members.map((u) => [u, "creator"])),
    conversationId: "c1",
    createdBy: "creator",
    createdAt: EARLIER,
    updatedAt: EARLIER,
    ...extra,
  };
}

const BEFORE = groupData(["creator", "adult"]);

check(
  "a rules-only write leaves the membership unchanged",
  membershipUnchanged(BEFORE, { ...BEFORE, recurringDayRules: [RULE] }),
);
check(
  "a member added is a change",
  !membershipUnchanged(BEFORE, groupData(["creator", "adult", "minor"])),
);
check(
  "a member removed is a change",
  !membershipUnchanged(BEFORE, { ...BEFORE, memberIds: ["creator"] }),
);
check(
  "memberIds reordered is a change",
  !membershipUnchanged(BEFORE, { ...BEFORE, memberIds: ["adult", "creator"] }),
);
check(
  "memberAddedBy changed for one uid is a change",
  !membershipUnchanged(BEFORE, {
    ...BEFORE,
    memberAddedBy: { creator: "creator", adult: "adult" },
  }),
);
check(
  "a memberAddedBy entry added is a change",
  !membershipUnchanged(BEFORE, {
    ...BEFORE,
    memberAddedBy: { creator: "creator", adult: "creator", minor: "adult" },
  }),
);
check(
  "memberAddedBy with the same entries in another key order is unchanged",
  membershipUnchanged(BEFORE, {
    ...BEFORE,
    memberAddedBy: { adult: "creator", creator: "creator" },
  }),
);
check("a create (no before) is a change", !membershipUnchanged(undefined, BEFORE));

/** The fake behind a proxy that counts every property read on the handle. */
function counting(fake: FakeFirestore): { db: Firestore; touches: () => number } {
  let touches = 0;
  const proxy = new Proxy(fake, {
    get(target, prop) {
      touches++;
      const value = Reflect.get(target, prop, target);
      return typeof value === "function" ? value.bind(target) : value;
    },
  });
  return { db: proxy as unknown as Firestore, touches: () => touches };
}

/** The stored group and conversation, with a minor no friend of the adder. */
function seed(fake: FakeFirestore, members: string[], extra: Record<string, unknown> = {}): void {
  fake.seed("chat_groups/g1", groupData(members, extra));
  fake.seed("conversations/c1", {
    participantIds: members,
    participantDisplayNames: Object.fromEntries(members.map((u) => [u, u])),
    participantAvatarUrls: Object.fromEntries(members.map((u) => [u, null])),
    memberSince: Object.fromEntries(members.map((u) => [u, EARLIER])),
    groupId: "g1",
    isGroup: true,
  });
  fake.seed("users/creator", { isMinor: false });
  fake.seed("users/adult", { isMinor: false });
  fake.seed("users/minor", { isMinor: true });
}

const WITH_MINOR = ["creator", "adult", "minor"];

async function asyncCases(): Promise<void> {
  console.log("\nenforceGroupMinorMembershipCore (BUT-2490)");

  {
    // The group holds a minor the full check WOULD evict, so a run that took
    // it would also change the store; both are asserted.
    const fake = new FakeFirestore();
    seed(fake, WITH_MINOR, { recurringDayRules: [RULE] });
    const { db, touches } = counting(fake);
    const before = groupData(WITH_MINOR);
    const after = fake.read("chat_groups/g1") ?? {};
    await enforceGroupMinorMembershipCore({ db, before, after, groupId: "g1" });
    check("a rules-only write does not touch the database", touches() === 0, `touches: ${touches()}`);
    check("a rules-only write writes nothing", fake.writes.length === 0);
  }

  {
    const fake = new FakeFirestore();
    seed(fake, WITH_MINOR);
    const { db, touches } = counting(fake);
    const before = groupData(["creator", "adult"]);
    const after = fake.read("chat_groups/g1") ?? {};
    await enforceGroupMinorMembershipCore({ db, before, after, groupId: "g1" });
    const group = fake.read("chat_groups/g1") ?? {};
    const convo = fake.read("conversations/c1") ?? {};
    check("premise: a membership write reads", touches() > 0);
    check(
      "a membership write evicts a minor no friend seated, from the group",
      JSON.stringify(group.memberIds) === JSON.stringify(["creator", "adult"]),
      JSON.stringify(group.memberIds),
    );
    check(
      "... and from the conversation",
      JSON.stringify(convo.participantIds) === JSON.stringify(["creator", "adult"]),
      JSON.stringify(convo.participantIds),
    );

    // The same event delivered again (retry): it reads the event's stale
    // `after`, which still names the minor, and must leave the membership as
    // the first run left it.
    await enforceGroupMinorMembershipCore({ db, before, after, groupId: "g1" });
    const again = fake.read("chat_groups/g1") ?? {};
    check(
      "a replayed membership event leaves the membership as it was",
      JSON.stringify(again.memberIds) === JSON.stringify(["creator", "adult"]) &&
        JSON.stringify(again.adminIds) === JSON.stringify(["creator"]),
      JSON.stringify(again.memberIds),
    );
  }

  {
    const fake = new FakeFirestore();
    seed(fake, WITH_MINOR);
    const after = fake.read("chat_groups/g1") ?? {};
    await enforceGroupMinorMembershipCore({ db: fake.db, before: undefined, after, groupId: "g1" });
    const group = fake.read("chat_groups/g1") ?? {};
    check(
      "a create evicts a minor no friend seated",
      JSON.stringify(group.memberIds) === JSON.stringify(["creator", "adult"]),
      JSON.stringify(group.memberIds),
    );
  }

  {
    const fake = new FakeFirestore();
    seed(fake, WITH_MINOR);
    fake.seed("users/minor/friends/creator", { createdAt: null });
    const after = fake.read("chat_groups/g1") ?? {};
    await enforceGroupMinorMembershipCore({
      db: fake.db,
      before: groupData(["creator", "adult"]),
      after,
      groupId: "g1",
    });
    check(
      "control: a minor seated by a friend stays",
      fake.writes.length === 0 &&
        JSON.stringify((fake.read("chat_groups/g1") ?? {}).memberIds) === JSON.stringify(WITH_MINOR),
    );
  }

  {
    const fake = new FakeFirestore();
    const { db, touches } = counting(fake);
    await enforceGroupMinorMembershipCore({
      db,
      before: groupData(WITH_MINOR),
      after: undefined,
      groupId: "g1",
    });
    check("a deleted group does not touch the database", touches() === 0);
  }
}

void asyncCases().then(
  () => {
    console.log(`\n${run - failed}/${run} passed`);
    if (failed > 0) process.exit(1);
  },
  (e) => {
    console.log(`  FAIL  crashed: ${e instanceof Error ? e.stack : String(e)}`);
    process.exit(1);
  },
);
