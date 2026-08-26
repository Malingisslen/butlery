/**
 * BUT-654: pure-function tests for the duplicate-content guard.
 *
 * Covers `computeDuplicateHash`, `isDuplicate`, `appendAndPrune` and the two
 * triggers' registered paths — the pieces that don't need an emulator.
 *
 * End-to-end behaviour lives in `duplicate-message-guard.integration.test.ts`,
 * which drives the real trigger against a live emulator. The header said "the
 * rules-unit-testing suite when the trigger lands" until 2026-08-19; it has
 * landed, and it is not the rules suite.
 *
 * Note what this file CANNOT see: `CloudFunction.run(event)` feeds the handler
 * an event directly, so no emulator test can check which collection the
 * trigger is registered on. That is why the path assertions are here, against
 * `Collections.messages` rather than a copy of the string — a dead trigger and
 * a working one are indistinguishable from every other direction, which is
 * exactly how BUT-1898 lived for three months.
 *
 * Run: `npx ts-node src/__tests__/duplicate-content-guard.test.ts`
 */

process.env.GCLOUD_PROJECT = process.env.GCLOUD_PROJECT ?? "demo-test";

import {
  appendAndPrune,
  computeDuplicateHash,
  guardDuplicateComment,
  guardDuplicateMessage,
  isChatDuplicateCandidate,
  isDuplicate,
} from "../social/duplicate-content-guard";
import { Collections } from "../shared/collections";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

// Test-only Timestamp shim — admin.firestore.Timestamp is class-cheap so
// we don't import it here; the helpers only need `.toMillis()`.
function ts(ms: number): { toMillis(): number } {
  return { toMillis: () => ms };
}

const cases: UnitCase[] = [
  {
    name: "computeDuplicateHash is deterministic for identical input",
    fn: () => {
      const a = computeDuplicateHash("user1", "Hej hej!");
      const b = computeDuplicateHash("user1", "Hej hej!");
      assertEqual(a, b, "same input must hash to same value");
    },
  },
  {
    name: "computeDuplicateHash normalizes whitespace + case",
    fn: () => {
      const a = computeDuplicateHash("user1", "Hej hej!");
      const b = computeDuplicateHash("user1", "  HEJ HEJ!  ");
      assertEqual(a, b, "whitespace + case differences should collapse");
    },
  },
  {
    name: "computeDuplicateHash differs across users for same body",
    fn: () => {
      const a = computeDuplicateHash("user1", "spam");
      const b = computeDuplicateHash("user2", "spam");
      assertEqual(a !== b, true, "different authors must hash differently");
    },
  },
  {
    name: "computeDuplicateHash differs across bodies",
    fn: () => {
      const a = computeDuplicateHash("user1", "hello");
      const b = computeDuplicateHash("user1", "hello!");
      assertEqual(a !== b, true, "different bodies must hash differently");
    },
  },
  {
    name: "isDuplicate true within window",
    fn: () => {
      const now = 1_000_000;
      const recent = [{ hash: "abc", at: ts(now - 1000) }] as any;
      assertEqual(isDuplicate("abc", recent, now, 5 * 60 * 1000, now), true,
        "1s ago < 5min window → duplicate");
    },
  },
  {
    name: "isDuplicate false outside window",
    fn: () => {
      const now = 1_000_000;
      const recent = [{ hash: "abc", at: ts(now - 6 * 60 * 1000) }] as any;
      assertEqual(isDuplicate("abc", recent, now, 5 * 60 * 1000, now), false,
        "6min ago > 5min window → not duplicate");
    },
  },
  {
    name: "isDuplicate false when hash differs",
    fn: () => {
      const now = 1_000_000;
      const recent = [{ hash: "xyz", at: ts(now - 1000) }] as any;
      assertEqual(isDuplicate("abc", recent, now, 5 * 60 * 1000, now), false,
        "different hash → not duplicate even within window");
    },
  },
  {
    name: "appendAndPrune drops expired entries before appending",
    fn: () => {
      const now = ts(1_000_000) as any;
      const recent = [
        { hash: "old", at: ts(1_000_000 - 6 * 60 * 1000) },
        { hash: "fresh", at: ts(1_000_000 - 1000) },
      ] as any;
      const next = appendAndPrune("new", recent, now, 5 * 60 * 1000);
      assertEqual(next.length, 2, "expired pruned, fresh + new kept");
      assertEqual(next[0].hash, "fresh", "fresh entry preserved");
      assertEqual(next[1].hash, "new", "new entry appended");
    },
  },
  {
    name: "appendAndPrune caps at 20 entries",
    fn: () => {
      const now = ts(1_000_000) as any;
      const recent = Array.from({ length: 25 }, (_, i) => ({
        hash: `h${i}`,
        at: ts(1_000_000 - (25 - i) * 1000),
      })) as any;
      const next = appendAndPrune("new", recent, now, 5 * 60 * 1000);
      assertEqual(next.length, 20, "list bounded at 20 entries");
      assertEqual(next[next.length - 1].hash, "new", "newest entry retained");
    },
  },
  {
    name: "isDuplicate ignores an entry recorded AFTER this document existed",
    fn: () => {
      const created = 1_000_000;
      const now = created + 2000;
      // The entry the accepted delivery of THIS event wrote. It is younger
      // than the document, so it cannot condemn it — this is what makes a
      // redelivery safe.
      const recent = [{ hash: "abc", at: ts(created + 1000) }] as any;
      assertEqual(
        isDuplicate("abc", recent, now, 5 * 60 * 1000, created),
        false,
        "an entry written after this doc was created is not evidence against it",
      );
    },
  },
  {
    name: "BUT-1898: an entry stamped EXACTLY at this document's createTime is not evidence",
    fn: () => {
      // The boundary case, and the only thing in either suite that tells `<`
      // from `<=`. Every other fixture sits clear of the bound, so a flipped
      // comparator passed all of them.
      //
      // It is the entry this document's own accepted delivery wrote: same
      // hash, stamped at the same createTime, because the stamp IS the
      // createTime. In the shipped trigger the `selfWrite` fast path catches
      // that case first on `eventId`, which is why a flip would surface as
      // same-millisecond twins being deleted rather than as a redelivery
      // deletion — measured by a reviewer, and the reason the comment at the
      // comparator was rewritten.
      //
      // This helper is nonetheless specified to hold ON ITS OWN, with
      // `eventId` absent. That is what this pins.
      const created = 1_000_000;
      const recent = [{ hash: "abc", at: ts(created) }] as any;
      assertEqual(
        isDuplicate("abc", recent, created + 1000, 5 * 60 * 1000, created),
        false,
        "an entry at exactly this document's createTime must not condemn it",
      );
      // The control, one millisecond earlier: still a duplicate, so the test
      // above is about the boundary rather than about the guard being off.
      const earlier = [{ hash: "abc", at: ts(created - 1) }] as any;
      assertEqual(
        isDuplicate("abc", earlier, created + 1000, 5 * 60 * 1000, created),
        true,
        "one millisecond earlier is still evidence",
      );
    },
  },
  {
    name: "BUT-1898: eviction cannot re-arm the retry hole",
    fn: () => {
      // The sequence the cloud-functions gate found, which the previous
      // eventId-based guard could not survive:
      //   1. E1 accepted, entry {H, eventId E1} stored.
      //   2. 20 further messages evict it.
      //   3. The user legitimately re-sends the same text — accepted,
      //      entry {H, eventId E2}.
      //   4. E1 is REDELIVERED. The old guard looked for its own eventId,
      //      found nothing, matched E2's entry and deleted a message that had
      //      already been delivered and read.
      // Here E1's own entry is gone and only the LATER one remains — and the
      // ordering test still refuses to condemn the earlier document.
      const e1Created = 1_000_000;
      const recent = [{ hash: "H", at: ts(e1Created + 30_000) }] as any;
      assertEqual(
        isDuplicate("H", recent, e1Created + 60_000, 5 * 60 * 1000, e1Created),
        false,
        "a redelivery must survive its own bookkeeping being evicted",
      );
      // The control: an entry from BEFORE the document is still a duplicate,
      // so the guard has not simply been switched off.
      const earlier = [{ hash: "H", at: ts(e1Created - 30_000) }] as any;
      assertEqual(
        isDuplicate("H", earlier, e1Created + 60_000, 5 * 60 * 1000, e1Created),
        true,
        "an entry predating this document is still a duplicate",
      );
    },
  },
  {
    name: "appendAndPrune carries eventId on stored entries",
    fn: () => {
      const now = ts(1_000_000) as any;
      const next = appendAndPrune("hash-x", [], now, 5 * 60 * 1000, "evt-9");
      assertEqual(next.length, 1, "single entry appended");
      assertEqual(next[0].eventId, "evt-9", "eventId persisted");
    },
  },
  // ---- BUT-1898: the chat surface's scoped key -------------------------
  {
    name: "BUT-1898: the same text in two conversations does NOT collide",
    fn: () => {
      // The case that would have bitten. Before the scope argument the key was
      // `authorId:body` and nothing else, so replying "Jag kommer klockan sju"
      // to two different people inside the five-minute window collided and the
      // SECOND message was deleted. Ordinary chat, not spam.
      const a = computeDuplicateHash("user1", "Jag kommer klockan sju", "conv-a");
      const b = computeDuplicateHash("user1", "Jag kommer klockan sju", "conv-b");
      if (a === b) {
        throw new Error(
          "same text in two conversations must not share a duplicate key",
        );
      }
    },
  },
  {
    name: "BUT-1898: the same text in the SAME conversation still collides",
    fn: () => {
      // The control for the test above. Without it, a scope that simply broke
      // hashing would pass the first test for the wrong reason.
      const a = computeDuplicateHash("user1", "Jag kommer klockan sju", "conv-a");
      const b = computeDuplicateHash("user1", "Jag kommer klockan sju", "conv-a");
      assertEqual(a, b, "same author, same text, same conversation → same key");
    },
  },
  {
    name: "BUT-1898: two authors in one conversation do not collide",
    fn: () => {
      // The scope narrows the key; it must not replace the author in it.
      const a = computeDuplicateHash("user1", "Vi ses på torsdag", "conv-a");
      const b = computeDuplicateHash("user2", "Vi ses på torsdag", "conv-a");
      if (a === b) {
        throw new Error("two authors must not share a duplicate key");
      }
    },
  },
  {
    name: "BUT-1898: the comment surface's global key is unchanged",
    fn: () => {
      // Comments pass no scope and have run in production since 2026-05-04.
      // Omitting the argument must produce exactly the pre-BUT-1898 value, so
      // this pins the literal rather than comparing two fresh calls — which
      // would be green for any implementation, including a broken one.
      // Taken from `git show HEAD:...` of the pre-change file, not from the
      // new one — the two were run side by side and agree.
      assertEqual(
        computeDuplicateHash("user1", "Hej hej!"),
        "4bc946f75f1011f3",
        "an unscoped hash must not have moved",
      );
    },
  },
  {
    name: "BUT-1898: NFC and NFD spellings of the same word hash alike",
    fn: () => {
      // å is ONE code point in NFC and two in NFD, so "då" is two and
      // three. Both spellings render
      // identically, and two clients can genuinely produce either. Without
      // normalisation they hash differently, which makes switching form a
      // one-line way to defeat the guard.
      const nfc = "Vi ses på torsdag";
      const nfd = nfc.normalize("NFD");
      if (nfc === nfd) {
        throw new Error("fixture is not actually two different byte sequences");
      }
      assertEqual(
        computeDuplicateHash("user1", nfd, "conv-a"),
        computeDuplicateHash("user1", nfc, "conv-a"),
        "the two normalisation forms must not be distinguishable",
      );
    },
  },
  // ---- BUT-1898: the trigger listens where the writers write --------------
  //
  // This is the test the bug needed and did not have. For three months the
  // guard was registered on `conversations/{conversationId}/messages/
  // {messageId}` while every writer used the top-level collection, and NOTHING
  // could tell: the handler body was correct, its unit tests were green, and
  // `functions:list` showed the function by name. A dead trigger and a working
  // one are indistinguishable from every direction except this one.
  //
  // The emulator suite drives the handler through `CloudFunction.run(event)`,
  // which supplies the event directly and therefore cannot see the path at
  // all. So the registration is asserted here, against the same constant the
  // writers use rather than against a copy of the string.
  {
    name: "BUT-1898: the chat trigger's path is the writers' collection",
    fn: () => {
      const pattern = (
        guardDuplicateMessage as unknown as {
          __endpoint: {
            eventTrigger: { eventFilterPathPatterns: { document: string } };
          };
        }
      ).__endpoint.eventTrigger.eventFilterPathPatterns.document;
      assertEqual(
        pattern,
        `${Collections.messages}/{messageId}`,
        "the chat guard must listen on the collection the writers write to",
      );
    },
  },
  {
    name: "BUT-1898: the comment trigger's path is unchanged",
    fn: () => {
      // The control. Without it, a change that broke path registration for
      // both surfaces could still leave the test above passing by coincidence.
      const pattern = (
        guardDuplicateComment as unknown as {
          __endpoint: {
            eventTrigger: { eventFilterPathPatterns: { document: string } };
          };
        }
      ).__endpoint.eventTrigger.eventFilterPathPatterns.document;
      assertEqual(
        pattern,
        "recipe_comments/{commentId}",
        "the comment guard's path must not have moved",
      );
    },
  },
  // BUT-1904. `isChatDuplicateCandidate` decides two different things in two
  // different files: whether the guard opens a transaction, and whether
  // `syncConversationLastMessage` re-reads a create before projecting it. Each
  // rejection reason gets its own case, because a predicate that returned false
  // for the wrong reason would still look right from either caller.
  {
    name: "BUT-1904: an ordinary long text message is a candidate",
    fn: () => {
      // The control. Without it every case below could pass because the
      // predicate answers false to everything.
      assertEqual(
        isChatDuplicateCandidate({
          type: "text",
          content: "Jag kommer klockan sju ikvall",
          conversationId: "conv-1",
        }),
        true,
        "a long text message in a conversation must be a candidate",
      );
    },
  },
  {
    name: "BUT-1904: an absent type counts as text",
    fn: () => {
      // The create rule requires senderId, conversationId, content and sentAt
      // — never `type` — so a client may legitimately omit it.
      assertEqual(
        isChatDuplicateCandidate({
          content: "Jag kommer klockan sju ikvall",
          conversationId: "conv-1",
        }),
        true,
        "a message with no type must be treated as text",
      );
    },
  },
  {
    // The type test is TRUTHINESS, not `!== undefined`, and the difference is
    // every falsy value that is not `undefined`.
    //
    // Not a new rule: the trigger has read `if (type && type !== "text")` since
    // 2026-05-04, and extracting it into a shared predicate silently changed it
    // to `!== undefined` — a regression against three months of production
    // semantics, which flipped a stored `null` or `""` from guarded to skipped.
    // Only `undefined` was pinned, and `undefined` is green under either
    // spelling, so the suite could not tell them apart. Found by the
    // testing-specialist gate; the label "unpinned new behaviour" was corrected
    // to "unpinned regression" by one `git show HEAD:` on the call site.
    name: "BUT-1904: a null, empty or non-string type counts as text",
    fn: () => {
      for (const type of [null, "", 0, false]) {
        assertEqual(
          isChatDuplicateCandidate({
            type: type as unknown as string | undefined,
            content: "Jag kommer klockan sju ikvall",
            conversationId: "conv-1",
          }),
          true,
          `a stored ${JSON.stringify(type)} type must be treated as text`,
        );
      }
    },
  },
  {
    name: "BUT-1904: a system row is not a candidate",
    fn: () => {
      assertEqual(
        isChatDuplicateCandidate({
          type: "system",
          content: "Malin har lagts till i gruppen",
          conversationId: "conv-1",
        }),
        false,
        "group system rows share one author and must never be hashed",
      );
    },
  },
  {
    name: "BUT-1904: a share card is not a candidate",
    fn: () => {
      assertEqual(
        isChatDuplicateCandidate({
          type: "recipeShare",
          content: "Kottbullar med potatismos",
          conversationId: "conv-1",
        }),
        false,
        "the same recipe share sent twice is a legitimate repeat",
      );
    },
  },
  {
    name: "BUT-1904: a message with no conversationId is not a candidate",
    fn: () => {
      assertEqual(
        isChatDuplicateCandidate({
          type: "text",
          content: "Jag kommer klockan sju ikvall",
        }),
        false,
        "without a conversation the key would fall back to the global one",
      );
    },
  },
  {
    name: "BUT-1904: the length floor is measured in NFC, on the trimmed body",
    fn: () => {
      // Under the floor of 12 once trimmed, over it if the trim were skipped —
      // which is the whole claim. (An earlier version of this comment counted
      // the characters and got it wrong; the count is not what carries it.)
      assertEqual(
        isChatDuplicateCandidate({
          type: "text",
          content: "   hej pa dig   ",
          conversationId: "conv-1",
        }),
        false,
        "the floor must be measured after trimming",
      );
      // The fixture STRADDLES the floor, and it has to. "hejsan da alla" was
      // here first: 14 in NFC and 15 in NFD, both over 12, so the predicate
      // answered true either way and this assertion held with the
      // normalisation deleted — it measured nothing. Found by the
      // testing-specialist gate.
      //
      // "hej da alla" is 11 in NFC and 12 in NFD, because the a-ring
      // decomposes into two code points. Without the normalisation the two
      // spellings of one visible string land on OPPOSITE sides of the floor,
      // which is the only shape that can fail.
      const nfc = "hej då alla";
      const nfd = nfc.normalize("NFD");
      assertEqual(
        nfc === nfd,
        false,
        "the fixture must actually differ between the two forms",
      );
      assertEqual(
        isChatDuplicateCandidate({
          type: "text",
          content: nfd,
          conversationId: "conv-1",
        }),
        isChatDuplicateCandidate({
          type: "text",
          content: nfc,
          conversationId: "conv-1",
        }),
        "NFC and NFD spellings must sit on the same side of the floor",
      );
    },
  },
  {
    name: "BUT-1904: a short acknowledgement is not a candidate",
    fn: () => {
      for (const body of ["?", "ok", "ja", "nej", "haha", "okej då"]) {
        assertEqual(
          isChatDuplicateCandidate({
            type: "text",
            content: body,
            conversationId: "conv-1",
          }),
          false,
          `"${body}" is ordinary conversation and must never be hashed`,
        );
      }
    },
  },
];

void runTests("BUT-654 duplicate-content-guard helpers", cases);
