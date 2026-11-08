/**
 * Rules tests for kokboksprovet: the cookbook photos in Storage (`corpus/`)
 * and the books, pages and run summaries in Firestore (`corpus_books`,
 * `corpus_pages`, `corpus_runs`).
 *
 * The material is copyright (decision 2026-11-07 in
 * docs/architecture/ACCEPTED_DEVIATIONS.md). Contract: an admin may list,
 * read, upload and delete photos and may read the Firestore documents; a
 * signed-out client, an ordinary user and a user acting inside their own
 * folder are denied everywhere, and no client writes the Firestore documents.
 *
 * Storage knows an admin by the `admin` custom claim and Firestore by an
 * `admins/{uid}` document, so the admin here has both, and the claim-only and
 * document-only cases are tested separately.
 *
 * Prerequisite: Firestore and Storage emulators running
 * (`firebase emulators:start --only firestore,storage --project demo-test`).
 *
 * Run with: npx ts-node src/__tests__/corpus-rules.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import {
  initializeTestEnvironment,
  RulesTestEnvironment,
  assertFails,
  assertSucceeds,
} from "@firebase/rules-unit-testing";
import {
  ref,
  uploadBytes,
  getBytes,
  listAll,
  deleteObject,
  updateMetadata,
} from "firebase/storage";

const PROJECT_ID = "butlery-rules-corpus";
const FIRESTORE_RULES = path.resolve(__dirname, "../../../firestore.rules");
const STORAGE_RULES = path.resolve(__dirname, "../../../storage.rules");

const ADMIN_UID = "corpus-admin";
const CLAIM_ONLY_UID = "corpus-claim-only";
const DOC_ONLY_UID = "corpus-doc-only";
const USER_UID = "corpus-user";

const BOOK = "book-0001";
const PHOTO = `corpus/${BOOK}/p0001.jpg`;
const JPEG = new Uint8Array([0xff, 0xd8, 0xff, 0xd9]);
const JPEG_META = { contentType: "image/jpeg" };

let env: RulesTestEnvironment;

type TestFn = () => Promise<void>;
const tests: { name: string; fn: TestFn }[] = [];
function test(name: string, fn: TestFn): void {
  tests.push({ name, fn });
}

function admin() {
  return env.authenticatedContext(ADMIN_UID, { admin: true });
}
function user() {
  return env.authenticatedContext(USER_UID);
}

async function seedPhoto(objectPath: string): Promise<void> {
  await env.withSecurityRulesDisabled(async (ctx) => {
    await uploadBytes(ref(ctx.storage(), objectPath), JPEG, JPEG_META);
  });
}

async function setup(): Promise<void> {
  env = await initializeTestEnvironment({
    projectId: PROJECT_ID,
    firestore: {
      rules: fs.readFileSync(FIRESTORE_RULES, "utf8"),
      host: "127.0.0.1",
      port: 8080,
    },
    storage: {
      rules: fs.readFileSync(STORAGE_RULES, "utf8"),
      host: "127.0.0.1",
      port: 9199,
    },
  });
  await env.clearFirestore();
  await env.clearStorage();
  await env.withSecurityRulesDisabled(async (ctx) => {
    const db = ctx.firestore();
    await db.doc(`admins/${ADMIN_UID}`).set({ addedAt: new Date() });
    await db.doc(`admins/${DOC_ONLY_UID}`).set({ addedAt: new Date() });
    await db.doc(`corpus_books/${BOOK}`).set({ holdout: false });
    await db.doc("corpus_pages/page-1").set({ bookId: BOOK, text: "x" });
    await db.doc("corpus_runs/run-1").set({ pages: 1 });
  });
}

// ---------------------------------------------------------------------------
// Storage: corpus/
// ---------------------------------------------------------------------------

test("storage: admin uploads a JPEG page photo", async () => {
  await assertSucceeds(uploadBytes(ref(admin().storage(), PHOTO), JPEG, JPEG_META));
});

test("storage: admin uploads a HEIC page photo", async () => {
  await assertSucceeds(
    uploadBytes(ref(admin().storage(), `corpus/${BOOK}/p0002.heic`), JPEG, {
      contentType: "image/heic",
    })
  );
});

test("storage: admin reads, lists and deletes a page photo", async () => {
  await seedPhoto(`corpus/${BOOK}/p0003.jpg`);
  const s = admin().storage();
  await assertSucceeds(getBytes(ref(s, `corpus/${BOOK}/p0003.jpg`)));
  await assertSucceeds(listAll(ref(s, `corpus/${BOOK}`)));
  await assertSucceeds(deleteObject(ref(s, `corpus/${BOOK}/p0003.jpg`)));
});

test("storage: signed-out client cannot read, list, upload or delete", async () => {
  await seedPhoto(PHOTO);
  const s = env.unauthenticatedContext().storage();
  await assertFails(getBytes(ref(s, PHOTO)));
  await assertFails(listAll(ref(s, `corpus/${BOOK}`)));
  await assertFails(uploadBytes(ref(s, `corpus/${BOOK}/p0009.jpg`), JPEG, JPEG_META));
  await assertFails(deleteObject(ref(s, PHOTO)));
});

test("storage: ordinary user cannot read, list, upload or delete", async () => {
  await seedPhoto(PHOTO);
  const s = user().storage();
  await assertFails(getBytes(ref(s, PHOTO)));
  await assertFails(listAll(ref(s, "corpus")));
  await assertFails(uploadBytes(ref(s, `corpus/${BOOK}/p0009.jpg`), JPEG, JPEG_META));
  await assertFails(deleteObject(ref(s, PHOTO)));
});

test("storage: a user's own folder does not reach corpus/", async () => {
  // The owner wildcard is users/{uid}/**; a bookId equal to the uid must not
  // turn the corpus folder into the user's own.
  const s = env.authenticatedContext(BOOK).storage();
  await seedPhoto(PHOTO);
  await assertFails(getBytes(ref(s, PHOTO)));
  await assertFails(uploadBytes(ref(s, `corpus/${BOOK}/p0010.jpg`), JPEG, JPEG_META));
});

test("storage: an admin document without the claim is not enough", async () => {
  await seedPhoto(PHOTO);
  const s = env.authenticatedContext(DOC_ONLY_UID).storage();
  await assertFails(getBytes(ref(s, PHOTO)));
});

test("storage: admin cannot upload a non-photo type", async () => {
  const s = admin().storage();
  for (const contentType of ["image/png", "image/svg+xml", "application/pdf", "text/plain"]) {
    await assertFails(
      uploadBytes(ref(s, `corpus/${BOOK}/p0011.jpg`), JPEG, { contentType })
    );
  }
});

test("storage: admin cannot upload 15 MB or more", async () => {
  const big = new Uint8Array(15 * 1024 * 1024);
  big.set(JPEG);
  await assertFails(
    uploadBytes(ref(admin().storage(), `corpus/${BOOK}/p0012.jpg`), big, JPEG_META)
  );
});

test("storage: admin cannot upload outside corpus/{bookId}/{file}", async () => {
  const s = admin().storage();
  for (const p of [
    "corpus/p0013.jpg",
    `corpus/${BOOK}/sub/p0013.jpg`,
    "corpus/Kokboken/p0013.jpg",
    `corpus/${BOOK}/p0013.png`,
    `corpus/${BOOK}/..p0013.jpg`,
  ]) {
    await assertFails(uploadBytes(ref(s, p), JPEG, JPEG_META));
  }
});

test("storage: admin uploads HEIF and .jpeg page photos", async () => {
  const s = admin().storage();
  await assertSucceeds(
    uploadBytes(ref(s, `corpus/${BOOK}/p0014.heif`), JPEG, { contentType: "image/heif" })
  );
  await assertSucceeds(uploadBytes(ref(s, `corpus/${BOOK}/p0015.jpeg`), JPEG, JPEG_META));
});

test("storage: book id over 64 and file name over 100 characters are refused", async () => {
  const s = admin().storage();
  await assertFails(uploadBytes(ref(s, `corpus/${"b".repeat(65)}/p0016.jpg`), JPEG, JPEG_META));
  await assertFails(uploadBytes(ref(s, `corpus/${BOOK}/${"p".repeat(101)}.jpg`), JPEG, JPEG_META));
});

// The emulator grades an overwriting upload as `create`; only a metadata
// change reaches the `update` limb.
test("storage: admin may change a photo's metadata, not to a non-photo type", async () => {
  await seedPhoto(PHOTO);
  const s = admin().storage();
  await assertSucceeds(updateMetadata(ref(s, PHOTO), { customMetadata: { reviewed: "1" } }));
  await assertFails(updateMetadata(ref(s, PHOTO), { contentType: "image/png" }));
});

test("storage: ordinary user cannot change a photo's metadata", async () => {
  await seedPhoto(PHOTO);
  await assertFails(
    updateMetadata(ref(user().storage(), PHOTO), { customMetadata: { reviewed: "1" } })
  );
});

// ---------------------------------------------------------------------------
// Firestore: corpus_books, corpus_pages, corpus_runs
// ---------------------------------------------------------------------------

const DOCS = [`corpus_books/${BOOK}`, "corpus_pages/page-1", "corpus_runs/run-1"];

test("firestore: admin reads every corpus collection", async () => {
  const db = admin().firestore();
  for (const p of DOCS) {
    await assertSucceeds(db.doc(p).get());
    await assertSucceeds(db.collection(p.split("/")[0]).get());
  }
});

test("firestore: admin cannot create, update or delete corpus documents", async () => {
  const db = admin().firestore();
  for (const p of DOCS) {
    const col = p.split("/")[0];
    await assertFails(db.doc(`${col}/new-doc`).set({ a: 1 }));
    await assertFails(db.doc(p).update({ a: 2 }));
    await assertFails(db.doc(p).delete());
  }
});

test("firestore: signed-out client and ordinary user are denied", async () => {
  for (const ctx of [env.unauthenticatedContext(), user()]) {
    const db = ctx.firestore();
    for (const p of DOCS) {
      const col = p.split("/")[0];
      await assertFails(db.doc(p).get());
      await assertFails(db.collection(col).get());
      await assertFails(db.doc(`${col}/new-doc`).set({ a: 1 }));
    }
  }
});

test("firestore: the admin claim without an admin document is not enough", async () => {
  const db = env.authenticatedContext(CLAIM_ONLY_UID, { admin: true }).firestore();
  for (const p of DOCS) await assertFails(db.doc(p).get());
});

async function run(): Promise<void> {
  console.log("Corpus (kokboksprovet) rules tests\n");
  await setup();
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
  await env.cleanup();
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
