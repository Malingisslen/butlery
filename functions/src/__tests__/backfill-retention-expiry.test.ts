/**
 * The retention backfill's per-row decision: which rows get `expireAt`, from
 * which creation time, and which of them TTL deletes as soon as they are
 * stamped (the count Malin approves before `--apply`).
 *
 * Run with: npx ts-node src/__tests__/backfill-retention-expiry.test.ts
 */

import * as assert from "assert";
import * as admin from "firebase-admin";
import {
  planStamp,
  readBaseMillis,
  RETENTION_TARGETS,
  RetentionTarget,
} from "../admin/backfill-retention-expiry-core";

const DAY = 24 * 60 * 60 * 1000;
const NOW = Date.UTC(2026, 9, 31);

let failed = 0;
function test(name: string, fn: () => void): void {
  try {
    fn();
    console.log(`  PASS  ${name}`);
  } catch (err) {
    failed++;
    console.log(`  FAIL  ${name}\n        ${String(err)}`);
  }
}

function target(collection: string): RetentionTarget {
  const t = RETENTION_TARGETS.find((x) => x.collection === collection);
  assert.ok(t, `no target for ${collection}`);
  return t;
}

test("targets cover the four collections with a 365-day window", () => {
  assert.deepStrictEqual(
    RETENTION_TARGETS.map((t) => [t.collection, t.baseField, t.retentionMs / DAY]),
    [
      ["parsing_corrections", "timestamp", 365],
      ["tag_overrides_log", "timestamp", 365],
      ["parse_corrections_v2", "createdAt", 365],
      ["feedback", "createdAt", 365],
    ],
  );
});

test("a row that already has expireAt is not touched", () => {
  const plan = planStamp(
    { timestamp: admin.firestore.Timestamp.fromMillis(NOW), expireAt: admin.firestore.Timestamp.fromMillis(NOW) },
    target("parsing_corrections"),
    NOW,
  );
  assert.deepStrictEqual(plan, { stamp: false });
});

test("a Timestamp creation time anchors the window", () => {
  const created = NOW - 10 * DAY;
  const plan = planStamp(
    { timestamp: admin.firestore.Timestamp.fromMillis(created) },
    target("tag_overrides_log"),
    NOW,
  );
  assert.deepStrictEqual(plan, {
    stamp: true,
    expireAtMs: created + 365 * DAY,
    alreadyExpired: false,
    usedFallback: false,
  });
});

test("feedback's ISO-string createdAt anchors the window", () => {
  const plan = planStamp({ createdAt: "2025-01-01T00:00:00.000Z" }, target("feedback"), NOW);
  assert.ok(plan.stamp);
  assert.strictEqual(plan.expireAtMs, Date.UTC(2025, 0, 1) + 365 * DAY);
});

test("a row older than its window is counted as deleted on stamping", () => {
  const plan = planStamp(
    { createdAt: admin.firestore.Timestamp.fromMillis(NOW - 400 * DAY) },
    target("parse_corrections_v2"),
    NOW,
  );
  assert.ok(plan.stamp && plan.alreadyExpired);
});

test("a row exactly one window old counts as expired", () => {
  const plan = planStamp(
    { timestamp: admin.firestore.Timestamp.fromMillis(NOW - 365 * DAY) },
    target("parsing_corrections"),
    NOW,
  );
  assert.ok(plan.stamp && plan.alreadyExpired);
});

test("a row without a readable creation time gets a full window from now", () => {
  for (const data of [{}, { timestamp: "not a date" }, { timestamp: 42 }]) {
    const plan = planStamp(data, target("parsing_corrections"), NOW);
    assert.deepStrictEqual(plan, {
      stamp: true,
      expireAtMs: NOW + 365 * DAY,
      alreadyExpired: false,
      usedFallback: true,
    });
  }
});

test("readBaseMillis reads Timestamp, Date and ISO string, and nothing else", () => {
  assert.strictEqual(readBaseMillis(admin.firestore.Timestamp.fromMillis(NOW)), NOW);
  assert.strictEqual(readBaseMillis(new Date(NOW)), NOW);
  assert.strictEqual(readBaseMillis(new Date(NOW).toISOString()), NOW);
  assert.strictEqual(readBaseMillis(null), null);
  assert.strictEqual(readBaseMillis(new Date(NaN)), null);
});

if (failed > 0) {
  console.log(`\n${failed} test(s) failed`);
  process.exit(1);
}
console.log("\nAll backfill-retention-expiry tests passed");
