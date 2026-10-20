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
 * against the Firestore+Storage emulators in
 * `moderate-upload.integration.test.ts` (BUT-839,
 * `npm run test:integration:moderate-upload`); here we lock down the
 * byte-level decisions so a future regression on detection logic gets
 * caught in a fast unit run.
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
const {
  detectFormat,
  resolveUploaderUid,
  handleFinalizedObject,
} = require("../storage/moderate-upload");
import { hashUid } from "../shared/hash-uid";
import { ERASURE_MARKER_WINDOW_MS } from "../social/hold-shares-on-block";
import { accountExists } from "../social/sync-block-mirror";

interface TestCase {
  name: string;
  fn: () => void | Promise<void>;
}
const tests: TestCase[] = [];
function test(name: string, fn: () => void | Promise<void>): void {
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

// ----- BUT-2294: uploads that land after the owner's erasure -----

const JPEG_HEAD = Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]);
const ERASED = "erasedUid123";
const LIVE = "liveUid456";

interface Harness {
  deletes: string[];
  downloads: string[];
  audits: Record<string, unknown>[];
  ownerLookups: string[];
  markerReads: string[];
  deps: Record<string, unknown>;
}

/**
 * A fake that records every verb the handler can call and THROWS on anything
 * else, so a collection the handler was not expected to touch fails loudly.
 */
function harness(opts: {
  gone?: string[];
  authError?: string;
  markers?: Record<string, Record<string, unknown>>;
  markerError?: string;
}): Harness {
  const h: Harness = {
    deletes: [],
    downloads: [],
    audits: [],
    ownerLookups: [],
    markerReads: [],
    deps: {},
  };
  const db = {
    collection(name: string) {
      if (name === "erasures_in_progress") {
        return {
          doc(id: string) {
            return {
              async get() {
                h.markerReads.push(id);
                if (opts.markerError) {
                  throw Object.assign(new Error("marker"), {
                    code: opts.markerError,
                  });
                }
                const data = opts.markers?.[id];
                return {
                  exists: data !== undefined,
                  get: (f: string) => data?.[f],
                };
              },
            };
          },
        };
      }
      if (name === "audit_logs") {
        return {
          async add(row: Record<string, unknown>) {
            h.audits.push(row);
          },
        };
      }
      throw new Error(`unexpected collection ${name}`);
    },
  };
  const bucket = {
    file(name: string) {
      return {
        async delete() {
          h.deletes.push(name);
        },
        async download() {
          h.downloads.push(name);
          return [JPEG_HEAD];
        },
      };
    },
  };
  h.deps = {
    db,
    bucket: () => bucket,
    ownerExists: async (uid: string) => {
      h.ownerLookups.push(uid);
      if (opts.authError) {
        throw Object.assign(new Error("auth"), { code: opts.authError });
      }
      return !(opts.gone ?? []).includes(uid);
    },
  };
  return h;
}

function jpegAt(name: string, metadata?: Record<string, string>) {
  return { bucket: "b", name, contentType: "image/jpeg", metadata };
}

test("BUT-2294: object of an account Auth no longer has is deleted, audited, never downloaded", async () => {
  const h = harness({ gone: [ERASED] });
  const name = `users/${ERASED}/cook_snaps/s1/p.jpg`;
  await handleFinalizedObject(jpegAt(name), h.deps);
  assertEqual(JSON.stringify(h.deletes), JSON.stringify([name]), "deletes");
  assertEqual(h.downloads.length, 0, "a doomed object must not be read");
  assertEqual(h.audits.length, 1, "audit rows");
  const row = h.audits[0];
  assertEqual(row.operation, "storage_upload_after_erasure", "operation");
  assertEqual(row.granted, false, "granted");
  assertEqual(row.userIdHash, hashUid(ERASED), "userIdHash");
  assertEqual("userId" in row, false, "no raw userId field");
  assertEqual(
    JSON.stringify(row).includes(ERASED),
    false,
    "the erased uid appears nowhere in the row"
  );
  assertEqual(
    row.resourceId,
    `users/${hashUid(ERASED)}/cook_snaps/s1/p.jpg`,
    "resourceId"
  );
  const meta = row.metadata as Record<string, unknown>;
  assertEqual(meta.reason, "erased", "reason");
  assertEqual(meta.deleted, true, "deleted");
});

test("BUT-2294: live account with no marker keeps the object and moderation runs", async () => {
  const h = harness({});
  const name = `users/${LIVE}/recipes/r1.jpg`;
  await handleFinalizedObject(jpegAt(name), h.deps);
  assertEqual(h.deletes.length, 0, "deletes");
  assertEqual(h.audits.length, 0, "audit rows");
  assertEqual(JSON.stringify(h.downloads), JSON.stringify([name]), "downloads");
  assertEqual(JSON.stringify(h.ownerLookups), JSON.stringify([LIVE]), "lookups");
  assertEqual(JSON.stringify(h.markerReads), JSON.stringify([LIVE]), "marker reads");
});

test("BUT-2294: a counting erasure marker deletes even while Auth still has the account", async () => {
  const h = harness({ markers: { [LIVE]: { startedAtMs: Date.now() - 1000 } } });
  const name = `users/${LIVE}/recipes/r1.jpg`;
  await handleFinalizedObject(jpegAt(name), h.deps);
  assertEqual(JSON.stringify(h.deletes), JSON.stringify([name]), "deletes");
  assertEqual(h.downloads.length, 0, "downloads");
  assertEqual(h.audits.length, 1, "audit rows");
  assertEqual(
    (h.audits[0].metadata as Record<string, unknown>).reason,
    "erasure_underway",
    "reason"
  );
});

test("BUT-2294: a marker past its window does not delete a live account's object", async () => {
  const h = harness({
    markers: {
      [LIVE]: { startedAtMs: Date.now() - ERASURE_MARKER_WINDOW_MS - 60_000 },
    },
  });
  await handleFinalizedObject(jpegAt(`users/${LIVE}/recipes/r1.jpg`), h.deps);
  assertEqual(h.deletes.length, 0, "deletes");
  assertEqual(h.audits.length, 0, "audit rows");
  assertEqual(h.downloads.length, 1, "downloads");
});

test("BUT-2294: an Auth error other than not-found fails OPEN (object kept)", async () => {
  const h = harness({ authError: "auth/internal-error" });
  await handleFinalizedObject(jpegAt(`users/${LIVE}/recipes/r1.jpg`), h.deps);
  assertEqual(h.deletes.length, 0, "deletes");
  assertEqual(h.audits.length, 0, "audit rows");
  assertEqual(h.downloads.length, 1, "moderation still runs");
});

test("BUT-2294: a marker read error fails OPEN for a live account", async () => {
  const h = harness({ markerError: "unavailable" });
  await handleFinalizedObject(jpegAt(`users/${LIVE}/recipes/r1.jpg`), h.deps);
  assertEqual(h.deletes.length, 0, "deletes");
  assertEqual(h.audits.length, 0, "audit rows");
  assertEqual(h.downloads.length, 1, "moderation still runs");
});

test("BUT-2294: Auth not-found still deletes when the marker read fails", async () => {
  const h = harness({ gone: [ERASED], markerError: "unavailable" });
  const name = `users/${ERASED}/recipes/r1.jpg`;
  await handleFinalizedObject(jpegAt(name), h.deps);
  assertEqual(JSON.stringify(h.deletes), JSON.stringify([name]), "deletes");
});

test("BUT-2294: the PATH owner decides, never metadata.uploadedBy", async () => {
  const h = harness({ gone: [ERASED] });
  const name = `users/${LIVE}/recipes/r1.jpg`;
  await handleFinalizedObject(jpegAt(name, { uploadedBy: ERASED }), h.deps);
  assertEqual(h.deletes.length, 0, "deletes");
  assertEqual(JSON.stringify(h.ownerLookups), JSON.stringify([LIVE]), "lookups");
});

test("BUT-2294: objects outside users/ trigger no owner lookup", async () => {
  for (const name of [
    `feedback/${ERASED}/shot.png`,
    "shared/recipes/r1/cover.jpg",
    `models/${ERASED}/m.bin`,
  ]) {
    const h = harness({ gone: [ERASED] });
    await handleFinalizedObject(
      { ...jpegAt(name), metadata: { uploadedBy: ERASED } },
      h.deps
    );
    assertEqual(h.ownerLookups.length, 0, `auth lookups for ${name}`);
    assertEqual(h.markerReads.length, 0, `marker reads for ${name}`);
    assertEqual(h.deletes.length, 0, `deletes for ${name}`);
  }
});

test("BUT-2294: through accountExists, auth/user-not-found deletes and auth/internal-error keeps", async () => {
  const notFound = harness({});
  notFound.deps.ownerExists = (uid: string) =>
    accountExists(uid, async () => {
      throw Object.assign(new Error("gone"), { code: "auth/user-not-found" });
    });
  const name = `users/${ERASED}/recipes/r1.jpg`;
  await handleFinalizedObject(jpegAt(name), notFound.deps);
  assertEqual(JSON.stringify(notFound.deletes), JSON.stringify([name]), "not-found deletes");

  const transient = harness({});
  transient.deps.ownerExists = (uid: string) =>
    accountExists(uid, async () => {
      throw Object.assign(new Error("flaky"), { code: "auth/internal-error" });
    });
  await handleFinalizedObject(jpegAt(name), transient.deps);
  assertEqual(transient.deletes.length, 0, "internal-error keeps");
  assertEqual(transient.downloads.length, 1, "internal-error still moderates");
});

async function run(): Promise<void> {
  console.log("BUT-780: moderateUpload unit tests\n");
  console.log("===================================\n");
  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
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

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
