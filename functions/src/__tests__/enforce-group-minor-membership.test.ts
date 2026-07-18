/**
 * BUT-1626: unit tests for the group-conversation minor-safety gate's pure
 * decision core, `computeMinorsToRemove`.
 *
 * No emulator: the trigger's Firestore I/O is thin around this pure function,
 * which is where the safety logic lives. We assert exactly who gets removed.
 *
 * Run: npx ts-node src/__tests__/enforce-group-minor-membership.test.ts
 */

import { computeMinorsToRemove } from "../messaging/enforce-group-minor-membership";

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
  return a.length === b.length && [...a].sort().join(",") === [...b].sort().join(",");
}

console.log("computeMinorsToRemove");

// A group where a non-friend creator added a minor → the minor is removed.
check(
  "removes a minor added by a non-friend creator",
  sameSet(
    computeMinorsToRemove({
      participantIds: ["creator", "adult", "minorA"],
      creatorId: "creator",
      isMinor: { adult: false, minorA: true },
      creatorIsFriendOf: { minorA: false },
    }),
    ["minorA"],
  ),
);

// The creator IS the minor's friend → the minor stays.
check(
  "keeps a minor whose friend is the creator",
  sameSet(
    computeMinorsToRemove({
      participantIds: ["creator", "adult", "minorA"],
      creatorId: "creator",
      isMinor: { adult: false, minorA: true },
      creatorIsFriendOf: { minorA: true },
    }),
    [],
  ),
);

// Adults are never removed regardless of friendship.
check(
  "never removes an adult",
  sameSet(
    computeMinorsToRemove({
      participantIds: ["creator", "adultA", "adultB"],
      creatorId: "creator",
      isMinor: { adultA: false, adultB: false },
      creatorIsFriendOf: {},
    }),
    [],
  ),
);

// The creator, even if a minor, is never removed (they made the group).
check(
  "never removes the creator even if the creator is a minor",
  sameSet(
    computeMinorsToRemove({
      participantIds: ["minorCreator", "adult", "minorB"],
      creatorId: "minorCreator",
      isMinor: { minorCreator: true, adult: false, minorB: true },
      creatorIsFriendOf: { minorB: true },
    }),
    [],
  ),
);

// Unknown creator (legacy doc) → fail SAFE: every minor participant removed.
check(
  "removes all minors when the creator is unknown (fail-safe)",
  sameSet(
    computeMinorsToRemove({
      participantIds: ["a", "minorA", "minorB", "adult"],
      creatorId: null,
      isMinor: { a: false, minorA: true, minorB: true, adult: false },
      creatorIsFriendOf: {},
    }),
    ["minorA", "minorB"],
  ),
);

// Mixed: one friended minor kept, one non-friend minor removed.
check(
  "removes only the non-friend minor in a mixed group",
  sameSet(
    computeMinorsToRemove({
      participantIds: ["creator", "minorFriend", "minorStranger"],
      creatorId: "creator",
      isMinor: { minorFriend: true, minorStranger: true },
      creatorIsFriendOf: { minorFriend: true, minorStranger: false },
    }),
    ["minorStranger"],
  ),
);

console.log(`\n${run - failed}/${run} passed`);
if (failed > 0) process.exit(1);
