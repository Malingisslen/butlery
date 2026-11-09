/**
 * BUT-818 step 2 — emulator-backed proof of what follows a stopped image:
 * the owner's decision, the moderator's view, a granted appeal putting the
 * image back with its old URL, and the quarantine sweep.
 *
 * Vision cannot read the Storage emulator, so `annotate` is faked; every
 * other read and write goes to the real Firestore and Storage emulators
 * through the production handlers.
 *
 * Run: npx ts-node src/__tests__/image-appeal.integration.test.ts
 * Local prerequisite: firebase emulators:start --only firestore,storage --project demo-test
 */

import { requireEmulatorsOrSkip } from "./integration-gate";

const PROJECT_ID = "demo-test";
const BUCKET = `${PROJECT_ID}.appspot.com`;
const FIRESTORE_HOST = "127.0.0.1:8080";
const STORAGE_HOST = "127.0.0.1:9199";

process.env.FIRESTORE_EMULATOR_HOST = FIRESTORE_HOST;
process.env.FIREBASE_STORAGE_EMULATOR_HOST = STORAGE_HOST;
process.env.GCLOUD_PROJECT = PROJECT_ID;
process.env.FIREBASE_CONFIG = JSON.stringify({ projectId: PROJECT_ID, storageBucket: BUCKET });

import * as admin from "firebase-admin";

const RUN = Date.now().toString(36);
const OWNER = `owner-${RUN}`;
const OTHER = `other-${RUN}`;
const ADMIN = `admin-${RUN}`;
const PHOTO = `users/${OWNER}/recipes/photo-${RUN}.jpg`;
const THUMB = `users/${OWNER}/recipes/thumbnails/photo-${RUN}_thumb.jpg`;
const LATER = `users/${OWNER}/avatars/later-${RUN}.jpg`;
const OTHER_PHOTO = `users/${OTHER}/recipes/x-${RUN}.jpg`;
const TOKEN = `token-${RUN}`;
const NOW = new Date();

/** Unique per run: the verdict cache is keyed on the bytes and outlives a run. */
function jpeg(fill: number): Buffer {
  return Buffer.concat([
    Buffer.from([0xff, 0xd8, 0xff, 0xe0, 0x00, 0x10]),
    Buffer.from("JFIF\0", "ascii"),
    Buffer.alloc(64, fill),
    Buffer.from(RUN, "ascii"),
  ]);
}

let failed = 0;
async function step(name: string, fn: () => Promise<void>): Promise<void> {
  try {
    await fn();
    console.log(`  PASS  ${name}`);
  } catch (err) {
    failed++;
    console.log(`  FAIL  ${name}`);
    console.log(`        ${(err as Error).message}`);
  }
}
function assert(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

async function run(): Promise<void> {
  console.log("BUT-818 step 2: stopped-image decision and appeal (firestore+storage emulators)\n");
  await requireEmulatorsOrSkip(
    [
      { name: "Firestore", hostPort: FIRESTORE_HOST },
      { name: "Storage", hostPort: STORAGE_HOST },
    ],
    "firebase emulators:start --only firestore,storage --project demo-test",
  );
  if (!admin.apps.length) admin.initializeApp({ projectId: PROJECT_ID, storageBucket: BUCKET });
  /* eslint-disable @typescript-eslint/no-require-imports */
  const { handleFinalizedObject } = require("../storage/moderate-upload");
  const { casePointerPath, newImageReportId } = require("../storage/image-decision");
  const { handleAppealAnswered, sweepQuarantine } = require("../storage/quarantine-restore");
  const { handleGetQuarantinedImages } = require("../storage/quarantine-review");
  const { runSubmitAppealWithDb } = require("../moderation/submit-appeal");
  const { runAnswerAppealWithDb } = require("../moderation/answer-appeal");
  const { onReportCreated } = require("../feedback/on-report-created");
  /* eslint-enable @typescript-eslint/no-require-imports */

  const db = admin.firestore();
  const bucket = admin.storage().bucket(BUCKET);
  const annotateCalls: string[] = [];
  let laterEvent: Record<string, unknown> = {};
  let explicit = true;
  const pushed: unknown[] = [];
  const deps = {
    db,
    bucket: () => bucket,
    ownerExists: async () => true,
    now: () => NOW,
    push: async (notices: unknown[]) => {
      pushed.push(...notices);
    },
    annotate: async (uri: string) => {
      annotateCalls.push(uri);
      return explicit
        ? { adult: "VERY_LIKELY", violence: "VERY_UNLIKELY", racy: "POSSIBLE" }
        : { adult: "VERY_UNLIKELY", violence: "VERY_UNLIKELY", racy: "UNLIKELY" };
    },
  };
  const upload = async (name: string, bytes: Buffer, token: string) => {
    await bucket.file(name).save(bytes, {
      contentType: "image/jpeg",
      metadata: { metadata: { firebaseStorageDownloadTokens: token } },
    });
    const [meta] = await bucket.file(name).getMetadata();
    await handleFinalizedObject(
      {
        bucket: BUCKET,
        name,
        contentType: "image/jpeg",
        md5Hash: meta.md5Hash,
        crc32c: meta.crc32c,
        size: meta.size,
        metadata: meta.metadata,
      },
      deps,
    );
  };

  // One after the other: the Storage emulator ignores `ifGenerationMatch: 0`
  // on a save, so two images stopped at the same moment agree on one case only
  // against real Storage. The unit suite covers that race with a fake that
  // honours the precondition.
  await upload(PHOTO, jpeg(1), TOKEN);
  await upload(THUMB, jpeg(2), `${TOKEN}-thumb`);
  const [pointer] = await bucket.file(casePointerPath(OWNER, NOW)).download();
  const caseId = pointer.toString("utf8");

  await step("photo and thumbnail are one case, closed, filed by the image check", async () => {
    assert(/^safesearch_[0-9a-f]{24}$/.test(caseId), `random case id, got ${caseId}`);
    assert(!caseId.includes(OWNER), "the id carries nothing of the uid");
    const report = await db.collection("reports").doc(caseId).get();
    assert(report.exists, "case exists");
    assert(report.get("status") === "closed", `status ${report.get("status")}`);
    assert(report.get("reporterId") === null, "no reporter");
    assert(report.get("contentOwnerId") === OWNER, "owner");
    assert(report.get("contentId") === caseId, "no object path on the report");
    const [held] = await bucket.getFiles({ prefix: `quarantine/users/${OWNER}/` });
    const inCase = held.filter((f) => (f.metadata.metadata ?? {}).reportId === caseId);
    assert(inCase.length === 2, `two images in the case, got ${inCase.length}`);
  });

  await step("one decision with the automated motivation, one owner notice", async () => {
    const record = await db.collection("moderation_decisions").doc(caseId).get();
    assert(record.get("decision") === "content_removed", `decision ${record.get("decision")}`);
    assert(record.get("rule") === "explicit_image", `rule ${record.get("rule")}`);
    assert(record.get("contentType") === "image", `type ${record.get("contentType")}`);
    assert(record.get("motivation") === "removed_automated_image", `motivation ${record.get("motivation")}`);
    assert(record.get("moderatorId") === null, "no moderator");
    const notices = await db.collection("notification_history").where("userId", "==", OWNER).get();
    assert(notices.size === 1, `one inbox row, got ${notices.size}`);
    const reports = await db.collection("reports").where("contentOwnerId", "==", OWNER).get();
    assert(reports.size === 1, `one case for both images, got ${reports.size}`);
    assert(pushed.length === 1, `one push, got ${pushed.length}`);
  });

  await step("the report trigger gives no strike and pages nobody", async () => {
    const snap = await db.collection("reports").doc(caseId).get();
    await onReportCreated.run({ id: `evt-${RUN}`, params: { reportId: caseId }, data: snap });
    const strike = await db.collection("user_moderation").doc(OWNER).get();
    assert(!strike.exists, "no strike");
    const event = await db.collection("system_events").doc(`content_report_${caseId}`).get();
    assert(!event.exists, "no moderator queue entry");
  });

  await step("an image stopped after the owner appealed gets a case of its own", async () => {
    await bucket.file(LATER).save(jpeg(3), { contentType: "image/jpeg" });
    const [meta] = await bucket.file(LATER).getMetadata();
    // Filed below, after the appeal; held until then.
    laterEvent = { bucket: BUCKET, name: LATER, contentType: "image/jpeg", md5Hash: meta.md5Hash, crc32c: meta.crc32c, size: meta.size };
  });

  const appealId = `${caseId}_owner`;
  const adminRequest = { auth: { uid: ADMIN, token: { admin: true } }, data: { appealId } };
  const reviewDeps = { rateLimit: async () => undefined, db, bucket };

  await step("the moderator view refuses a non-admin", async () => {
    let code: unknown = null;
    try {
      await handleGetQuarantinedImages(
        { auth: { uid: OWNER, token: {} }, data: { appealId } }, reviewDeps,
      );
    } catch (err) {
      code = (err as { code?: unknown }).code;
    }
    assert(code === "permission-denied", `code ${code}`);
  });

  await runSubmitAppealWithDb(db, OWNER, { reportId: caseId, role: "owner", text: "Det är en korv, inget annat." });
  await handleFinalizedObject(laterEvent, deps);
  const [laterMeta] = await bucket.file(`quarantine/${LATER}`).getMetadata();
  const laterCase = String((laterMeta.metadata ?? {}).reportId);
  await step("…and that later case is not the appealed one", async () => {
    assert(laterCase !== caseId && /^safesearch_[0-9a-f]{24}$/.test(laterCase), `later case ${laterCase}`);
    const record = await db.collection("moderation_decisions").doc(laterCase).get();
    assert(record.exists, "later case has its own decision");
  });

  await step("the moderator sees both images of the case, page by page", async () => {
    const first = await handleGetQuarantinedImages(
      { ...adminRequest, data: { appealId, offset: 1 } }, reviewDeps,
    );
    assert(first.images.length === 1 && first.nextOffset === null, "a later page alone");
    const partial = await db.collection("moderation_appeals").doc(appealId).get();
    assert(partial.get("reviewedAll") !== true, "the last page alone does not count as viewing the case");
    const res = await handleGetQuarantinedImages(adminRequest, reviewDeps);
    assert(res.images.length === 2, `images ${res.images.length}`);
    assert(res.nextOffset === null && res.omitted === 0, "one page holds the case");
    const viewed = await db.collection("moderation_appeals").doc(appealId).get();
    assert(viewed.get("reviewedAll") === true, "every image seen");
    const bytes = res.images.map((i: { base64: string }) => Buffer.from(i.base64, "base64")[70]).sort();
    assert(JSON.stringify(bytes) === JSON.stringify([1, 2]), `bytes ${JSON.stringify(bytes)}`);
  });

  const UNSEEN = `users/${OWNER}/recipes/unseen-${RUN}.jpg`;
  await step("granting an image appeal the moderator has not viewed is refused", async () => {
    await runSubmitAppealWithDb(db, OWNER, { reportId: laterCase, role: "owner", text: "Min profilbild är helt vanlig." });
    let code: unknown = null;
    try {
      await runAnswerAppealWithDb(db, ADMIN, { appealId: `${laterCase}_owner`, outcome: "reversed" });
    } catch (err) {
      code = (err as { message?: unknown }).message;
    }
    assert(code === "image_not_reviewed", `refusal, got ${code}`);
    await runAnswerAppealWithDb(db, ADMIN, { appealId: `${laterCase}_owner`, outcome: "upheld" });
  });

  await step("a granted appeal puts the viewed images back with their old tokens, finishing a half-done copy", async () => {
    // Joins the case after the moderator looked: never shown, so never restored.
    await bucket.file(`quarantine/${UNSEEN}`).save(jpeg(5), {
      contentType: "image/jpeg",
      metadata: { metadata: { reportId: caseId, ownerUid: OWNER, originalToken: "unseen" } },
    });
    // An earlier delivery copied the thumbnail back and died before its token was set.
    await bucket.file(`quarantine/${THUMB}`).copy(bucket.file(THUMB));
    const before = (await db.collection("moderation_appeals").doc(appealId).get()).data();
    await runAnswerAppealWithDb(db, ADMIN, { appealId, outcome: "reversed" });
    const after = (await db.collection("moderation_appeals").doc(appealId).get()).data();
    const event = { data: { before: { data: () => before }, after: { data: () => after } } };
    await handleAppealAnswered(event, { db, bucket });
    await handleAppealAnswered(event, { db, bucket }); // redelivery is harmless
    for (const [name, token] of [[PHOTO, TOKEN], [THUMB, `${TOKEN}-thumb`]]) {
      const [meta] = await bucket.file(name).getMetadata();
      const custom = meta.metadata ?? {};
      assert(custom.firebaseStorageDownloadTokens === token, `${name} token ${custom.firebaseStorageDownloadTokens}`);
      assert(custom.reportId === undefined && custom.originalToken === undefined, "quarantine metadata cleared");
      const [held] = await bucket.file(`quarantine/${name}`).exists();
      assert(!held, `${name} left quarantine`);
    }
    const [unseenBack] = await bucket.file(UNSEEN).exists();
    const [unseenHeld] = await bucket.file(`quarantine/${UNSEEN}`).exists();
    assert(!unseenBack && unseenHeld, "the image the moderator never saw stays in quarantine");
    const audits = await db.collection("audit_logs").where("metadata.reportId", "==", caseId).get();
    assert(audits.size === 2, `one restore row per image despite the redelivery, got ${audits.size}`);
  });

  await step("the restored bytes pass the check again without a new Vision call", async () => {
    const calls = annotateCalls.length;
    const [meta] = await bucket.file(PHOTO).getMetadata();
    await handleFinalizedObject(
      { bucket: BUCKET, name: PHOTO, contentType: "image/jpeg", md5Hash: meta.md5Hash, crc32c: meta.crc32c, size: meta.size, metadata: meta.metadata },
      deps,
    );
    const [kept] = await bucket.file(PHOTO).exists();
    assert(kept, "restored photo stays");
    assert(annotateCalls.length === calls, "verdict read from the cache");
  });

  await step("the sweep keeps an expired image while its appeal is open, deletes the rest, files a missing decision", async () => {
    // A case whose decision was never filed: the sweep files it.
    const orphanCase: string = newImageReportId();
    await bucket.file(`quarantine/${OTHER_PHOTO}`).save(jpeg(4), {
      contentType: "image/jpeg",
      metadata: { metadata: { reportId: orphanCase, ownerUid: OTHER } },
    });
    const early = await sweepQuarantine({ db, bucket, push: async () => undefined, now: NOW });
    assert(early.decisionsFiled >= 1, `filed ${early.decisionsFiled}`);
    const filed = await db.collection("moderation_decisions").doc(orphanCase).get();
    assert(filed.exists && filed.get("rule") === "explicit_image", "missing decision filed");

    await runSubmitAppealWithDb(db, OTHER, { reportId: orphanCase, role: "owner", text: "Det här är en vanlig matbild." });
    const late = new Date(NOW.getTime() + 201 * 24 * 60 * 60 * 1000);
    await sweepQuarantine({ db, bucket, push: async () => undefined, now: late });
    const [open] = await bucket.file(`quarantine/${OTHER_PHOTO}`).exists();
    assert(open, "kept while the appeal is open");
    const [laterHeld] = await bucket.file(`quarantine/${LATER}`).exists();
    assert(!laterHeld, "expired image without an open appeal deleted");
    const [pointerLeft] = await bucket.file(casePointerPath(OWNER, NOW)).exists();
    assert(!pointerLeft, "window pointer deleted");

    await runAnswerAppealWithDb(db, ADMIN, { appealId: `${orphanCase}_owner`, outcome: "upheld" });
    await sweepQuarantine({ db, bucket, push: async () => undefined, now: late });
    const [gone] = await bucket.file(`quarantine/${OTHER_PHOTO}`).exists();
    assert(!gone, "deleted once the appeal is answered");
  });

  explicit = false;
  for (const name of [PHOTO, THUMB, LATER, `quarantine/${UNSEEN}`]) {
    await bucket.file(name).delete({ ignoreNotFound: true });
  }
  console.log(`\n${failed === 0 ? "all passed" : `${failed} failed`}`);
  process.exit(failed > 0 ? 1 : 0);
}

run().catch((err) => {
  console.error(err);
  process.exit(1);
});
