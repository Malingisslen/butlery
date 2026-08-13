/**
 * BUT-1838: unit tests for the minor-membership gate's pure decision core.
 *
 * Moved here from `enforce-group-minor-membership.test.ts` when BUT-1838 made
 * this the PRIMARY control rather than an after-the-fact backstop. The six
 * original cases are carried over unchanged in substance — same fixtures, same
 * expectations — so a regression in the policy still reddens exactly what it
 * used to. What is new is the per-member inviter: the old core could only ask
 * "was this group's creator your friend", which is why anyone added after
 * creation went unchecked.
 *
 * No emulator: the callables' Firestore I/O is thin around this pure function,
 * which is where the safety logic lives. We assert exactly who is refused.
 *
 * Run: npx ts-node src/__tests__/minor-membership-gate.test.ts
 */

import { computeBlockedMembers } from "../groups/minor-membership-gate";
import { isValidDocId } from "../shared/valid-doc-id";

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

function sameSet(a: string[], b: string[]): boolean {
  return (
    a.length === b.length && [...a].sort().join(",") === [...b].sort().join(",")
  );
}

/** The common case: one person is doing the inviting for the whole batch. */
const by = (uid: string) => () => uid;

console.log("computeBlockedMembers — one inviter (the callable case)");

check(
  "blocks a minor invited by a non-friend",
  sameSet(
    computeBlockedMembers({
      candidates: ["creator", "adult", "minorA"],
      inviterOf: by("creator"),
      isMinor: { adult: false, minorA: true },
      inviterIsFriendOf: { minorA: false },
    }),
    ["minorA"],
  ),
);

check(
  "admits a minor whose friend is the inviter",
  sameSet(
    computeBlockedMembers({
      candidates: ["creator", "adult", "minorA"],
      inviterOf: by("creator"),
      isMinor: { adult: false, minorA: true },
      inviterIsFriendOf: { minorA: true },
    }),
    [],
  ),
);

check(
  "never blocks an adult",
  sameSet(
    computeBlockedMembers({
      candidates: ["creator", "adultA", "adultB"],
      inviterOf: by("creator"),
      isMinor: { adultA: false, adultB: false },
      inviterIsFriendOf: {},
    }),
    [],
  ),
);

check(
  "never blocks the inviter, even when the inviter is a minor",
  sameSet(
    computeBlockedMembers({
      candidates: ["minorCreator", "adult", "minorB"],
      inviterOf: by("minorCreator"),
      isMinor: { minorCreator: true, adult: false, minorB: true },
      inviterIsFriendOf: { minorB: true },
    }),
    [],
  ),
);

check(
  "blocks every minor when the inviter is unknown (fail-safe)",
  sameSet(
    computeBlockedMembers({
      candidates: ["a", "minorA", "minorB", "adult"],
      inviterOf: () => null,
      isMinor: { a: false, minorA: true, minorB: true, adult: false },
      inviterIsFriendOf: {},
    }),
    ["minorA", "minorB"],
  ),
);

check(
  "blocks only the non-friend minor in a mixed batch",
  sameSet(
    computeBlockedMembers({
      candidates: ["creator", "minorFriend", "minorStranger"],
      inviterOf: by("creator"),
      isMinor: { minorFriend: true, minorStranger: true },
      inviterIsFriendOf: { minorFriend: true, minorStranger: false },
    }),
    ["minorStranger"],
  ),
);

// The fixture deliberately contains a uid the filter rejects ("__x__"): an
// earlier version of this case used only well-formed uids and so passed
// identically with the filter deleted, proving nothing.
check(
  "a malformed uid alongside a minor does not stop the refusal",
  sameSet(
    computeBlockedMembers({
      candidates: ["creator", "minorA", "__x__", "adult"].filter(isValidDocId),
      inviterOf: by("creator"),
      isMinor: { minorA: true, adult: false },
      inviterIsFriendOf: { minorA: false },
    }),
    ["minorA"],
  ),
);

console.log("computeBlockedMembers — per-member inviter (the backstop case)");

// THE CASE THE OLD CORE COULD NOT EXPRESS, and the reason BUT-1838 exists.
// Two minors in one group, seated by two different people: the creator's own
// friend stays, and the one an unrelated admin added later does not. A core
// keyed on a single creator would have had to give both the same answer.
const addedBy: Record<string, string> = {
  creator: "creator",
  minorFriendOfCreator: "creator",
  minorAddedLater: "otherAdmin",
  otherAdmin: "creator",
};
check(
  "judges each minor against whoever actually seated them",
  sameSet(
    computeBlockedMembers({
      candidates: [
        "creator",
        "otherAdmin",
        "minorFriendOfCreator",
        "minorAddedLater",
      ],
      inviterOf: (uid) => addedBy[uid] ?? null,
      isMinor: {
        creator: false,
        otherAdmin: false,
        minorFriendOfCreator: true,
        minorAddedLater: true,
      },
      // Each minor's entry is about THEIR OWN adder: the first is a friend of
      // the creator, the second is not a friend of otherAdmin.
      inviterIsFriendOf: {
        minorFriendOfCreator: true,
        minorAddedLater: false,
      },
    }),
    ["minorAddedLater"],
  ),
);

// A member whose recorded adder is missing is the legacy/tampered shape, and it
// must fail SAFE for that member alone — not for the whole group.
check(
  "an unrecorded adder fails safe for that member only",
  sameSet(
    computeBlockedMembers({
      candidates: ["creator", "minorKnown", "minorOrphan"],
      inviterOf: (uid) =>
        uid === "minorOrphan" ? null : "creator",
      isMinor: { minorKnown: true, minorOrphan: true },
      inviterIsFriendOf: { minorKnown: true },
    }),
    ["minorOrphan"],
  ),
);

console.log("");
console.log(`${run - failed}/${run} checks passed`);
if (failed > 0) process.exit(1);
