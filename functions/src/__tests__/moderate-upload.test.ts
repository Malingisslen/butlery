/**
 * BUT-780 — moderateUpload unit tests.
 *
 * Verifies the pure helpers from `storage/moderate-upload.ts`:
 *   - `detectFormat(head)` returns the right SupportedFormat for genuine
 *     JPEG/PNG/WebP/HEIC byte signatures, null for spoofed or unknown bytes.
 *   - `resolveUploaderUid(metadata, name)` extracts uid from metadata first,
 *     then from the path conventions used in storage.rules.
 *
 * The full CF (admin SDK download + delete + audit-log write) is exercised
 * in integration via the Storage emulator; here we lock down the byte-level
 * decisions so a future regression on detection logic gets caught in a
 * fast unit run.
 *
 * Run: npx ts-node src/__tests__/moderate-upload.test.ts
 */

// `moderate-upload.ts` declares an `onObjectFinalized` trigger at module
// load, which firebase-functions resolves eagerly and demands a bucket name
// from the runtime config. For unit tests of the pure helpers only, we
// stub FIREBASE_CONFIG before the require so module-load doesn't throw.
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: "butlery-test-moderate-upload",
  storageBucket: "butlery-test-moderate-upload.appspot.com",
});

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-moderate-upload" });
}

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { detectFormat, resolveUploaderUid } = require("../storage/moderate-upload");

interface TestCase {
  name: string;
  fn: () => void;
}
const tests: TestCase[] = [];
function test(name: string, fn: () => void): void {
  tests.push({ name, fn });
}

function assertEqual<T>(actual: T, expected: T, msg?: string): void {
  if (actual !== expected) {
    throw new Error(
      `${msg ?? "assertion"}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`
    );
  }
}

// ----- detectFormat -----

test("BUT-780: JPEG magic bytes detected", () => {
  const head = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
  assertEqual(detectFormat(head), "jpeg");
});

test("BUT-780: PNG magic bytes detected", () => {
  const head = Buffer.from([0x89, 0x50, 0x4e, 0x47, 0x0d, 0x0a, 0x1a, 0x0a]);
  assertEqual(detectFormat(head), "png");
});

test("BUT-780: WebP magic bytes (RIFF...WEBP) detected", () => {
  // bytes 0-3 = RIFF, 4-7 = size, 8-11 = WEBP
  const head = Buffer.from([
    0x52, 0x49, 0x46, 0x46, 0x00, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50,
  ]);
  assertEqual(detectFormat(head), "webp");
});

test("BUT-780: HEIC magic bytes (ftypheic) detected", () => {
  // bytes 0-3 = box size (any), 4-7 = "ftyp", 8-11 = "heic"
  const head = Buffer.from([
    0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x68, 0x65, 0x69, 0x63,
  ]);
  assertEqual(detectFormat(head), "heic");
});

test("BUT-780: HEIF brand 'mif1' also classifies as heic", () => {
  const head = Buffer.from([
    0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x6d, 0x69, 0x66, 0x31,
  ]);
  assertEqual(detectFormat(head), "heic");
});

test("BUT-780: SVG (text starting with <?xml) returns null", () => {
  // The whole point of the magic-byte gate. Even a Content-Type of
  // image/jpeg can't sneak SVG bytes past this.
  const head = Buffer.from("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n<svg ");
  assertEqual(detectFormat(head), null);
});

test("BUT-780: random binary garbage returns null", () => {
  const head = Buffer.from([0x42, 0x4d, 0x36, 0x00]); // looks like BMP — not allowed
  assertEqual(detectFormat(head), null);
});

test("BUT-780: too-short head returns null", () => {
  assertEqual(detectFormat(Buffer.from([0xff])), null);
  assertEqual(detectFormat(Buffer.from([])), null);
});

test("BUT-780: AVIF (ftypavif) returns null — not on whitelist", () => {
  const head = Buffer.from([
    0x00, 0x00, 0x00, 0x18, 0x66, 0x74, 0x79, 0x70, 0x61, 0x76, 0x69, 0x66,
  ]);
  assertEqual(detectFormat(head), null);
});

// ----- resolveUploaderUid -----

test("BUT-780: metadata.uploadedBy wins over path", () => {
  const uid = resolveUploaderUid(
    { uploadedBy: "from-metadata" },
    "users/from-path/recipes/foo.jpg"
  );
  assertEqual(uid, "from-metadata");
});

test("BUT-780: users/{uid}/... path extracts uid", () => {
  const uid = resolveUploaderUid(undefined, "users/alice/avatars/me.jpg");
  assertEqual(uid, "alice");
});

test("BUT-780: feedback/{uid}/... path extracts uid", () => {
  const uid = resolveUploaderUid(undefined, "feedback/bob/screenshot-1.png");
  assertEqual(uid, "bob");
});

test("BUT-780: shared/recipes/... without metadata returns null", () => {
  const uid = resolveUploaderUid(undefined, "shared/recipes/r1/cover.jpg");
  assertEqual(uid, null);
});

test("BUT-780: empty / unknown path returns null", () => {
  assertEqual(resolveUploaderUid(undefined, undefined), null);
  assertEqual(resolveUploaderUid(undefined, ""), null);
  assertEqual(resolveUploaderUid({}, "models/some-model.bin"), null);
});

function run(): void {
  console.log("BUT-780: moderateUpload unit tests\n");
  console.log("===================================\n");
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
