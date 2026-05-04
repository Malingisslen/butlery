/**
 * BUT-654: pure-function tests for the duplicate-content guard.
 *
 * Covers `computeDuplicateHash`, `isDuplicate`, and `appendAndPrune` —
 * the pieces of the trigger that don't need an emulator. End-to-end
 * Firestore behavior is exercised by the rules-unit-testing suite when
 * the trigger lands on an emulator.
 *
 * Run: `npx ts-node src/__tests__/duplicate-content-guard.test.ts`
 */

import {
  appendAndPrune,
  computeDuplicateHash,
  isDuplicate,
} from "../social/duplicate-content-guard";
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
      assertEqual(isDuplicate("abc", recent, now, 5 * 60 * 1000), true,
        "1s ago < 5min window → duplicate");
    },
  },
  {
    name: "isDuplicate false outside window",
    fn: () => {
      const now = 1_000_000;
      const recent = [{ hash: "abc", at: ts(now - 6 * 60 * 1000) }] as any;
      assertEqual(isDuplicate("abc", recent, now, 5 * 60 * 1000), false,
        "6min ago > 5min window → not duplicate");
    },
  },
  {
    name: "isDuplicate false when hash differs",
    fn: () => {
      const now = 1_000_000;
      const recent = [{ hash: "xyz", at: ts(now - 1000) }] as any;
      assertEqual(isDuplicate("abc", recent, now, 5 * 60 * 1000), false,
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
    name: "isDuplicate skips entries written by the same eventId (retry guard)",
    fn: () => {
      const now = 1_000_000;
      const recent = [
        { hash: "abc", at: ts(now - 1000), eventId: "evt-1" },
      ] as any;
      // Same event retrying: the entry is its own write — must NOT be
      // classified as a duplicate, otherwise the trigger deletes the
      // legitimate doc on retry.
      assertEqual(
        isDuplicate("abc", recent, now, 5 * 60 * 1000, "evt-1"),
        false,
        "self-retry is not a duplicate",
      );
      // Different event with same hash within window: still a duplicate.
      assertEqual(
        isDuplicate("abc", recent, now, 5 * 60 * 1000, "evt-2"),
        true,
        "different event, same hash within window → duplicate",
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
];

void runTests("BUT-654 duplicate-content-guard helpers", cases);
