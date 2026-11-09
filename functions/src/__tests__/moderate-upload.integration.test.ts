/**
 * BUT-839 — emulator-backed integration test for `moderateUpload`.
 *
 * The sibling unit test (`moderate-upload.test.ts`) covers the pure helpers
 * (`detectFormat`, `resolveUploaderUid`) but cannot prove the trigger body:
 * head-byte download, object deletion on rejection, and the `audit_logs`
 * write. This test exercises the REAL exported handler via the v2
 * `CloudFunction.run(event)` surface against live Firestore (127.0.0.1:8080)
 * and Storage (127.0.0.1:9199) emulators — no re-implemented logic.
 *
 * Note on triggers: emulators do not fire deployed trigger code unless the
 * functions emulator hosts it. Unlike
 * `request-account-deletion.integration.test.ts` (which calls a
 * deps-injected inner function), this suite drives the production handler
 * directly with a realistic event payload, Admin SDK pointed at the
 * emulators. `.run(event)` invokes the exact function body that deploys.
 *
 * Scenarios:
 *   1. Genuine JPEG bytes, declared image/jpeg → object KEPT, no audit row.
 *   2. SVG bytes spoofed as image/jpeg → object DELETED from storage, one
 *      `audit_logs` row with operation "storage_upload_rejected", granted
 *      false, reason "magic_byte_unrecognized", userId = uploader uid.
 *
 * Isolation: per-run unique object names + uid; audit assertions query by
 * the unique resourceId, so no namespace clearing is needed (the demo-test
 * namespace is shared with other suites on the same emulator).
 *
 * Skip gate (local machines without the storage emulator / Java): if either
 * emulator port doesn't answer, the suite prints SKIP and exits 0 — unless
 * CI is set, in which case a missing emulator is a hard failure (the CI lane
 * starts firestore+storage explicitly).
 *
 * Run: npx ts-node src/__tests__/moderate-upload.integration.test.ts
 * Local prerequisite: firebase emulators:start --only firestore,storage --project demo-test
 */

import { requireEmulatorsOrSkip } from "./integration-gate";

const PROJECT_ID = "demo-test";
const BUCKET = `${PROJECT_ID}.appspot.com`;
const FIRESTORE_HOST = "127.0.0.1:8080";
const STORAGE_HOST = "127.0.0.1:9199";

// MUST be set before firebase-admin / firebase-functions are imported so the
// Admin SDK routes to the emulators and the module-load `onObjectFinalized`
// declaration can resolve its default bucket without GCP credentials.
process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.FIREBASE_STORAGE_EMULATOR_HOST = STORAGE_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIREBASE_CONFIG = JSON.stringify({
  projectId: PROJECT_ID,
  storageBucket: BUCKET,
});

import * as admin from "firebase-admin";

const RUN = Date.now().toString(36);
const UPLOADER = `uploader-${RUN}`;
const GOOD_PATH = `users/${UPLOADER}/recipes/good-${RUN}.jpg`;
const EVIL_PATH = `users/${UPLOADER}/recipes/evil-${RUN}.jpg`;
const GONE_PATH = `users/${UPLOADER}/recipes/gone-${RUN}.jpg`;
const EXPLICIT_PATH = `users/${UPLOADER}/recipes/explicit-${RUN}.jpg`;
const EXPLICIT_COPY_PATH = `users/${UPLOADER}/public_recipes/r-${RUN}/explicit-${RUN}.jpg`;
const OPS_PATH = `ops/resets/run-${RUN}.json`;
const annotateCalls: string[] = [];
let explicitKey: string | null = null;
const loggedErrors: unknown[][] = [];

// Genuine JPEG head (FF D8 FF E0 + JFIF marker), padded past the 32-byte
// ranged read the CF performs.
const JPEG_BYTES = Buffer.concat([
  Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]),
  Buffer.from("JFIF\0", "ascii"),
  Buffer.alloc(64, 0),
]);

// The canonical XSS vector: SVG with embedded script, declared image/jpeg.
const SVG_BYTES = Buffer.from(
  '<svg xmlns="http://www.w3.org/2000/svg"><script>alert(1)</script></svg>',
  "utf8",
);

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}
function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

// ---------------------------------------------------------------------------
// Scenario assertions (handler is invoked once per scenario in run()).
// ---------------------------------------------------------------------------

function db() {
  return admin.firestore();
}
function bucket() {
  return admin.storage().bucket(BUCKET);
}

async function auditRowsFor(resourceId: string) {
  const snap = await db()
    .collection("audit_logs")
    .where("resourceId", "==", resourceId)
    .get();
  return snap.docs.map((d) => d.data());
}

// I1: genuine JPEG survives moderation.
test("genuine JPEG: object is kept in storage", async () => {
  const [exists] = await bucket().file(GOOD_PATH).exists();
  assert(exists, "valid JPEG must NOT be deleted by moderateUpload");
});

// I2: genuine JPEG produces no audit row.
test("genuine JPEG: no audit_logs row is written", async () => {
  const rows = await auditRowsFor(GOOD_PATH);
  assert(
    rows.length === 0,
    `expected zero audit rows for accepted upload, got ${rows.length}`,
  );
});

// I3: spoofed SVG is deleted from storage.
test("SVG spoofed as image/jpeg: object is deleted from storage", async () => {
  const [exists] = await bucket().file(EVIL_PATH).exists();
  assert(!exists, "spoofed SVG must be deleted by moderateUpload");
});

// I4: spoofed SVG gets exactly one storage_upload_rejected audit row with the
// uploader uid, granted=false, and the magic-byte rejection reason.
test("SVG spoofed as image/jpeg: audit_logs row records the rejection", async () => {
  const rows = await auditRowsFor(EVIL_PATH);
  assert(rows.length === 1, `expected exactly 1 audit row, got ${rows.length}`);
  const row = rows[0];
  assert(
    row.operation === "storage_upload_rejected",
    `operation must be storage_upload_rejected, got ${row.operation}`,
  );
  assert(row.granted === false, "granted must be false");
  assert(row.userId === UPLOADER, `userId must be uploader uid, got ${row.userId}`);
  assert(
    row.resourceType === "storage_object",
    `resourceType must be storage_object, got ${row.resourceType}`,
  );
  const meta = (row.metadata ?? {}) as Record<string, unknown>;
  assert(
    meta.reason === "magic_byte_unrecognized",
    `reason must be magic_byte_unrecognized, got ${meta.reason}`,
  );
  assert(
    meta.contentType === "image/jpeg",
    `metadata.contentType must echo the spoofed declaration, got ${meta.contentType}`,
  );
});

// I5: an image the owner deleted before the trigger read it is not an error.
test("object deleted before it was read: the head read is not logged as an error, no audit row", async () => {
  // Other error lines (the owner check needs Auth, which this lane lacks) are not this scenario's.
  const headReadErrors = loggedErrors.filter(
    (args) => args[0] === "[moderateUpload] failed to read head bytes",
  );
  assert(
    headReadErrors.length === 0,
    `a 404 must not be logged at error level, got ${JSON.stringify(headReadErrors)}`,
  );
  const rows = await auditRowsFor(GONE_PATH);
  assert(rows.length === 0, `expected zero audit rows, got ${rows.length}`);
});

// I6 (BUT-818): an explicit image is moved, not just deleted — the copy is
// what an appeal would restore.
test("explicit image: original gone, quarantine copy kept with its scores", async () => {
  const [original] = await bucket().file(EXPLICIT_PATH).exists();
  assert(!original, "explicit original must be removed");
  const copy = bucket().file(`quarantine/${EXPLICIT_PATH}`);
  const [kept] = await copy.exists();
  assert(kept, "quarantine copy must exist");
  const [meta] = await copy.getMetadata();
  const custom = (meta.metadata ?? {}) as Record<string, unknown>;
  assert(custom.originalPath === EXPLICIT_PATH, `originalPath, got ${custom.originalPath}`);
  assert(custom.adult === "VERY_LIKELY", `adult score, got ${custom.adult}`);
  assert(
    custom.firebaseStorageDownloadTokens === undefined,
    "the copy must not keep the original's download token",
  );
});

test("explicit image: one storage_upload_quarantined audit row", async () => {
  const rows = await auditRowsFor(EXPLICIT_PATH);
  assert(rows.length === 1, `expected 1 audit row, got ${rows.length}`);
  assert(rows[0].operation === "storage_upload_quarantined", `operation, got ${rows[0].operation}`);
  assert(rows[0].userId === UPLOADER, `userId, got ${rows[0].userId}`);
});

// I7 (BUT-818): Vision is paid per call; the server's public copy has the same
// bytes and must be judged from the cache.
test("same bytes again (public copy): Vision called once in total, copy quarantined too", async () => {
  assert(annotateCalls.length === 1, `annotate calls, got ${JSON.stringify(annotateCalls)}`);
  const [copyLeft] = await bucket().file(EXPLICIT_COPY_PATH).exists();
  assert(!copyLeft, "public copy must be removed from the cached verdict");
  const [copyHeld] = await bucket().file(`quarantine/${EXPLICIT_COPY_PATH}`).exists();
  assert(copyHeld, "public copy must be held in quarantine");
  assert(explicitKey !== null, "scan key");
  const cached = await db().collection("safe_search_scans").doc(explicitKey as string).get();
  assert(cached.exists && cached.get("explicit") === true, "verdict cached under the checksums");
});

// I8: a server-written non-image outside the client prefixes is left alone.
test("ops/ JSON written by the server: kept, no audit row", async () => {
  const [exists] = await bucket().file(OPS_PATH).exists();
  assert(exists, "the reset record must not be deleted");
  const rows = await auditRowsFor(OPS_PATH);
  assert(rows.length === 0, `expected zero audit rows, got ${rows.length}`);
});

// ---------------------------------------------------------------------------
// Run
// ---------------------------------------------------------------------------

async function run(): Promise<void> {
  console.log("BUT-839: moderateUpload INTEGRATION tests (firestore+storage emulators)");
  console.log("=======================================================================\n");

  await requireEmulatorsOrSkip(
    [
      { name: "Firestore", hostPort: FIRESTORE_HOST },
      { name: "Storage", hostPort: STORAGE_HOST },
    ],
    "firebase emulators:start --only firestore,storage --project demo-test",
  );

  if (!admin.apps.length) {
    admin.initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET });
  }
  // Import AFTER initializeApp so the module's admin.* calls bind to the
  // emulator-configured default app.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { moderateUpload } = require("../storage/moderate-upload");

  // Seed: upload both objects exactly as a client would (rules allow
  // image/jpeg by contentType; the spoofed SVG sails through that layer —
  // which is the entire reason moderateUpload exists).
  await bucket().file(GOOD_PATH).save(JPEG_BYTES, {
    contentType: "image/jpeg",
    metadata: { metadata: { uploadedBy: UPLOADER } },
  });
  await bucket().file(EVIL_PATH).save(SVG_BYTES, {
    contentType: "image/jpeg",
    metadata: { metadata: { uploadedBy: UPLOADER } },
  });

  // Invoke the REAL handler with realistic onObjectFinalized payloads.
  const makeEvent = (name: string) => ({
    data: {
      bucket: BUCKET,
      name,
      contentType: "image/jpeg",
      metadata: { uploadedBy: UPLOADER },
    },
  });
  await moderateUpload.run(makeEvent(GOOD_PATH));
  await moderateUpload.run(makeEvent(EVIL_PATH));

  // Never uploaded, so the ranged read answers 404 exactly as it does for an
  // image the owner deleted first.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { logger } = require("firebase-functions/logger");
  const originalError = logger.error;
  logger.error = (...args: unknown[]) => {
    loggedErrors.push(args);
  };
  try {
    await moderateUpload.run(makeEvent(GONE_PATH));
  } finally {
    logger.error = originalError;
  }

  // BUT-818: Vision cannot read the emulator, so the hit path runs through the
  // handler with a fake annotate against the real emulator bucket and db.
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { handleFinalizedObject } = require("../storage/moderate-upload");
  const explicitDeps = {
    db: db(),
    bucket: () => bucket(),
    ownerExists: async () => true,
    annotate: async (uri: string) => {
      annotateCalls.push(uri);
      return { adult: "VERY_LIKELY", violence: "VERY_UNLIKELY", racy: "POSSIBLE" };
    },
  };
  // A client upload carries a download token; the quarantine copy must not.
  await bucket().file(EXPLICIT_PATH).save(JPEG_BYTES, {
    contentType: "image/jpeg",
    metadata: { metadata: { firebaseStorageDownloadTokens: `token-${RUN}` } },
  });
  await bucket().file(EXPLICIT_PATH).copy(bucket().file(EXPLICIT_COPY_PATH));
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { scanKey } = require("../storage/safe-search");
  for (const name of [EXPLICIT_PATH, EXPLICIT_COPY_PATH]) {
    // The event carries the object's own checksums, read here as Storage stored them.
    const [meta] = await bucket().file(name).getMetadata();
    explicitKey = scanKey(meta.md5Hash, meta.crc32c, meta.size);
    await handleFinalizedObject(
      {
        bucket: BUCKET,
        name,
        contentType: "image/jpeg",
        md5Hash: meta.md5Hash,
        crc32c: meta.crc32c,
        size: meta.size,
      },
      explicitDeps,
    );
  }
  await bucket().file(OPS_PATH).save(JSON.stringify({ runId: RUN }), {
    contentType: "application/json",
  });
  await moderateUpload.run({
    data: { bucket: BUCKET, name: OPS_PATH, contentType: "application/json" },
  });

  let failed = 0;
  for (const t of tests) {
    try {
      await t.fn();
      console.log(`  PASS  ${t.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${t.name}`);
      console.log(`        ${(err as Error).message}`);
    }
  }

  // Cleanup: remove the kept object + audit rows so re-runs and sibling
  // suites on the shared demo-test namespace stay unpolluted.
  await bucket().file(GOOD_PATH).delete({ ignoreNotFound: true });
  await bucket().file(OPS_PATH).delete({ ignoreNotFound: true });
  await bucket().file(`quarantine/${EXPLICIT_PATH}`).delete({ ignoreNotFound: true });
  await bucket().file(`quarantine/${EXPLICIT_COPY_PATH}`).delete({ ignoreNotFound: true });
  if (explicitKey) await db().collection("safe_search_scans").doc(explicitKey).delete();
  const leftover = await db()
    .collection("audit_logs")
    .where("resourceId", "in", [GOOD_PATH, EVIL_PATH, EXPLICIT_PATH, EXPLICIT_COPY_PATH])
    .get();
  await Promise.all(leftover.docs.map((d) => d.ref.delete()));

  console.log(
    `\n${tests.length - failed}/${tests.length} passed` +
      (failed ? `, ${failed} failed` : ""),
  );
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
