/**
 * BUT-1478: parse_events retention (`expireAt` TTL field).
 *
 * What this proves: `computeExpireAt` — the seam the logParseEvent handler
 * stamps onto every parse_events doc (and the backfill script reuses) — lands
 * exactly 30 days after the event's creation time and is a real Firestore
 * Timestamp (the TTL policy only reaps indexed Timestamp fields). parse_events
 * carries raw userId + the user's imported URL, so this window is the GDPR
 * Art. 5(1)(e) guarantee; if a refactor changes the constant or the unit math
 * (days vs hours vs ms), these cases go red.
 *
 * NOTE: the field is only inert until the Firestore TTL policy is enabled for
 * the parse_events collection group — see functions/RUNBOOK.md ("Firestore TTL
 * policies").
 *
 * Run with: npx ts-node src/__tests__/log-parse-event-expiry.test.ts
 */

import * as admin from "firebase-admin";
import { computeExpireAt } from "../events/log-parse-event";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const THIRTY_DAYS_MS = 30 * 24 * 60 * 60 * 1000;

const cases: UnitCase[] = [
  {
    name: "expireAt lands exactly 30 days after the event's now",
    fn: async () => {
      const nowMs = Date.UTC(2026, 6, 7, 12, 0, 0);
      const expireAt = computeExpireAt(nowMs);
      assertEqual(
        expireAt.toMillis(),
        nowMs + THIRTY_DAYS_MS,
        "retention window is 30 days, to the millisecond"
      );
    },
  },
  {
    name: "expireAt is a Firestore Timestamp (TTL policies ignore other types)",
    fn: async () => {
      if (!(computeExpireAt(Date.now()) instanceof admin.firestore.Timestamp)) {
        throw new Error("expireAt must be an admin.firestore.Timestamp");
      }
    },
  },
  {
    name: "window scales linearly from the given now (no hidden Date.now coupling)",
    fn: async () => {
      const a = computeExpireAt(0);
      const b = computeExpireAt(1000);
      assertEqual(a.toMillis(), THIRTY_DAYS_MS, "epoch anchor");
      assertEqual(
        b.toMillis() - a.toMillis(),
        1000,
        "pure function of the nowMs argument"
      );
    },
  },
];

runTests("BUT-1478: parse_events expireAt retention window", cases);
