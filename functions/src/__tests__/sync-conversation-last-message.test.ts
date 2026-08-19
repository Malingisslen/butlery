/**
 * BUT-778 — sync-conversation-last-message unit tests.
 *
 * The full CF (Firestore transaction + recompute-on-delete) is exercised
 * against the Firestore emulator in
 * `sync-conversation-last-message.integration.test.ts` (BUT-839,
 * `npm run test:integration:sync-conversation`); this file locks down
 * the pure decision helper `shouldReplaceLastMessage` so a future regression
 * on the create/update precedence rule is caught fast in unit runs.
 *
 * Why the helper matters: an edit lands with the SAME `sentAt` as the
 * original send, but the preview text needs to refresh. Hence the helper
 * uses `>=` rather than `>`. A regression to `>` would silently drop edits.
 *
 * Run: npx ts-node src/__tests__/sync-conversation-last-message.test.ts
 */

process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: "butlery-test-sync-last-msg",
});

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-sync-last-msg" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { shouldReplaceLastMessage } = require("../messaging/sync-conversation-last-message");

interface TestCase {
  name: string;
  fn: () => void;
}
const tests: TestCase[] = [];
function test(name: string, fn: () => void): void {
  tests.push({ name, fn });
}

function ts(ms: number): admin.firestore.Timestamp {
  return admin.firestore.Timestamp.fromMillis(ms);
}

function assertEqual<T>(actual: T, expected: T, msg?: string): void {
  if (actual !== expected) {
    throw new Error(
      `${msg ?? "assertion"}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
    );
  }
}

test("BUT-778: replaces when current is null/undefined", () => {
  assertEqual(shouldReplaceLastMessage(null, ts(1000)), true);
  assertEqual(shouldReplaceLastMessage(undefined, ts(1000)), true);
  assertEqual(shouldReplaceLastMessage({}, ts(1000)), true);
});

test("BUT-778: replaces when candidate is newer", () => {
  assertEqual(shouldReplaceLastMessage({ sentAt: ts(1000) }, ts(2000)), true);
});

test("BUT-778: replaces on equal sentAt (edit case)", () => {
  // The point: an edit lands with the same sentAt as the original send.
  // Without `>=` the preview text would never refresh.
  assertEqual(shouldReplaceLastMessage({ sentAt: ts(1000) }, ts(1000)), true);
});

test("BUT-1853: replaces a STORED sentAt that is not a Timestamp", () => {
  // `current` comes off a stored document, so its type is whatever a past
  // write left there — and until 2026-08-19 the guard was `!current?.sentAt`,
  // which a string walks straight past on its way to `.toMillis()`. That threw
  // on EVERY later message write in the affected conversation, freezing its
  // preview for good. Replaceable means a real message heals the document.
  assertEqual(
    shouldReplaceLastMessage({ sentAt: "nope" as unknown as admin.firestore.Timestamp }, ts(1000)),
    true
  );
  assertEqual(
    shouldReplaceLastMessage({ sentAt: 1000 as unknown as admin.firestore.Timestamp }, ts(1000)),
    true
  );
  // A plain object with the right shape is still not a Timestamp — the check
  // is `instanceof`, deliberately, because duck-typing is how the string got
  // this far in the first place.
  assertEqual(
    shouldReplaceLastMessage(
      { sentAt: { toMillis: () => 9_000_000 } as unknown as admin.firestore.Timestamp },
      ts(1000)
    ),
    true
  );
});

test("BUT-778: does NOT replace when candidate is older", () => {
  // Out-of-order CF firings could otherwise overwrite the latest message
  // with a stale one. The version-stamped check keeps the lastMessage
  // monotonically forward in time.
  assertEqual(shouldReplaceLastMessage({ sentAt: ts(2000) }, ts(1000)), false);
});

function run(): void {
  console.log("BUT-778: sync-conversation-last-message unit tests\n");
  console.log("===================================================\n");
  let failed = 0;
  for (const t of tests) {
    try {
      t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(err);
    }
  }
  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

run();
