/**
 * BUT-1626: unit tests for `isValidDocId`.
 *
 * The decision core these used to live beside moved to
 * `minor-membership-gate.test.ts` when BUT-1838 made the gate the primary
 * control and this trigger the backstop; the uid-safety cases stayed here.
 *
 * No emulator: these are the paths the emulator cannot reach — a uid the
 * backend would reject.
 *
 * Run: npx ts-node src/__tests__/enforce-group-minor-membership.test.ts
 */

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

console.log(`\n${run - failed}/${run} passed`);
if (failed > 0) process.exit(1);
