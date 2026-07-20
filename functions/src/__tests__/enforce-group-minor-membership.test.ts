/**
 * BUT-1626: unit tests for the group-conversation minor-safety gate's pure
 * decision core, `computeMinorsToRemove`.
 *
 * No emulator: the trigger's Firestore I/O is thin around this pure function,
 * which is where the safety logic lives. We assert exactly who gets removed.
 *
 * Run: npx ts-node src/__tests__/enforce-group-minor-membership.test.ts
 */

import {
  computeMinorsToRemove,
  isValidDocId,
} from "../messaging/enforce-group-minor-membership";

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

// The gate must still protect the minor when a HOSTILE entry sits beside them.
// The fixture deliberately contains a uid the filter rejects ("__x__") — an
// earlier version of this test used only well-formed uids and so passed
// identically with the filter deleted, proving nothing.
check(
  "a malformed uid alongside a minor does not stop the removal",
  sameSet(
    computeMinorsToRemove({
      participantIds: ["creator", "minorA", "__x__", "adult"].filter(isValidDocId),
      creatorId: "creator",
      isMinor: { minorA: true, adult: false },
      creatorIsFriendOf: { minorA: false },
    }),
    ["minorA"],
  ),
);

// NOTE: the padding-bypass Critical (raw-vs-sanitised group gate) is NOT
// testable from this suite. The gate lives in the onDocumentCreated handler,
// which this file never imports — it only exercises the pure decision core. A
// unit "test" here could only assert facts about its own fixture. It is pinned
// by the emulator case "padded 1:1 ..." in
// enforce-group-minor-membership.integration.test.ts instead.

console.log(`\n${run - failed}/${run} passed`);
if (failed > 0) process.exit(1);
