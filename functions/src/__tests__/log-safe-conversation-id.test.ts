/**
 * BUT-1872: the cross-language parity contract for `logSafeConversationId`.
 *
 * Lives beside the code it watches (`../shared/log-safe-conversation-id`)
 * rather than inside a suite about something else: the TS half is a pinned
 * literal holding a two-language promise, and a suite split or rename could
 * carry it off silently (BUT-2128).
 *
 * Run: npx ts-node src/__tests__/log-safe-conversation-id.test.ts
 */

import { logSafeConversationId } from "../shared/log-safe-conversation-id";

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

console.log("logSafeConversationId — cross-language parity (BUT-1872)");

// The Dart client masks the same ids through
// `LogSanitizer.maskConversationId` (lib/core/utils/log_sanitizer.dart), so
// ONE conversation reads the same in a Crashlytics report and in a Cloud
// Logging line. Neither compiler can see the other language, so the literal
// has to be pinned on BOTH sides, or one direction of drift never reddens.
//
// The identical literal lives in
// `test/unit/core/utils/log_sanitizer_test.dart`. IF THIS FAILS, one of the
// two sides drifted: fix the drift, do NOT re-baseline the literal.
{
  const directId = "direct_aBcDeFgHiJkLmNoPqRsT_zYxWvUtSrQpOnMlKjIhG";
  const masked = logSafeConversationId(directId);
  check(
    "a direct id hashes to the value the Dart side also pins",
    masked === "direct_#12fc49f947ab",
    `got ${masked}`,
  );
  // A 20-char Firestore auto-id, the shape `createChatGroup` actually mints —
  // not the uuid this fixture used to carry.
  const groupId = "kPq7Rw2LmNc4Xy9Zt1Bv";
  check(
    "a group id passes through untouched",
    logSafeConversationId(groupId) === groupId,
  );
}

console.log(`\n${run - failed}/${run} passed`);
if (failed > 0) process.exit(1);
