/**
 * BUT-1842: emulator-backed tests for the text copy a report keeps
 * (`moderation/report-evidence.ts`).
 *
 * The headline property: a copy is kept only for content the REPORTER could
 * read, from the document the report really names — a forged report must not
 * make the server preserve somebody else's private text.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/report-evidence.integration.test.ts
 */

const PROJECT_ID = "butlery-report-evidence-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import {
  captureReportEvidence,
  evidenceShouldGo,
  EVIDENCE_RETENTION_DAYS,
  MAX_EVIDENCE_TEXT_BYTES,
  REPORT_EVIDENCE,
} from "../moderation/report-evidence";

const RUN = Date.now().toString(36);
const REPORTER = `rep${RUN}`;
const OWNER = `own${RUN}`;
const NOW = new Date("2026-10-09T08:00:00Z");

let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

let seq = 0;
async function report(
  contentType: string,
  contentId: string,
  extra: Record<string, unknown> = {},
): Promise<string> {
  const id = `r${RUN}${seq++}`;
  await db.collection("reports").doc(id).set({
    reporterId: REPORTER,
    contentType,
    contentId,
    contentOwnerId: OWNER,
    reason: "abuse",
    status: "new",
    createdAt: admin.firestore.Timestamp.fromDate(NOW),
    ...extra,
  });
  return id;
}

async function evidence(id: string): Promise<admin.firestore.DocumentData | undefined> {
  return (await db.collection(REPORT_EVIDENCE).doc(id).get()).data();
}

async function recipes(): Promise<void> {
  const recipes = db.collection("users").doc(OWNER).collection("recipes");
  await recipes.doc(`shared${RUN}`).set({
    core: {
      title: "Kladdkaka",
      description: "Elak text",
      ingredients: ["2 ägg"],
      instructions: ["Rör"],
      sourceUrl: "https://example.com",
    },
    socialData: { memberPermissions: { [REPORTER]: "viewer" } },
  });
  await recipes.doc(`private${RUN}`).set({
    core: { title: "Hemligt" },
    socialData: { memberPermissions: {} },
  });

  const shared = await report("recipe", `shared${RUN}`);
  check("a recipe shared with the reporter is captured", (await captureReportEvidence(db, shared, NOW)) === "captured");
  const ev = await evidence(shared);
  check(
    "the recipe copy holds exactly the four text fields",
    JSON.stringify(ev?.text) ===
      JSON.stringify({ title: "Kladdkaka", description: "Elak text", ingredients: ["2 ägg"], instructions: ["Rör"] }),
    JSON.stringify(ev?.text),
  );
  check("the copy names no reporter", ev !== undefined && !("reporterId" in ev));
  check(
    `the copy expires ${EVIDENCE_RETENTION_DAYS} days after capture`,
    (ev?.expireAt as admin.firestore.Timestamp | undefined)?.toMillis() ===
      NOW.getTime() + EVIDENCE_RETENTION_DAYS * 86400000,
  );

  const priv = await report("recipe", `private${RUN}`);
  check(
    "a recipe NOT shared with the reporter keeps no text",
    (await captureReportEvidence(db, priv, NOW)) === "not_visible_to_reporter" &&
      (await evidence(priv))?.text === undefined,
  );

  const missing = await report("recipe", `gone${RUN}`);
  check(
    "a recipe that no longer exists records missing",
    (await captureReportEvidence(db, missing, NOW)) === "missing",
  );

  // Rerun after the author edits: the first copy wins.
  await recipes.doc(`shared${RUN}`).update({ "core.title": "Ändrad" });
  check(
    "a second delivery does not overwrite the first copy",
    (await captureReportEvidence(db, shared, NOW)) === "already_captured" &&
      (await evidence(shared))?.text?.title === "Kladdkaka",
  );
}

async function messages(): Promise<void> {
  await db.collection("conversations").doc(`conv${RUN}`).set({ participantIds: [REPORTER, OWNER] });
  await db.collection("conversations").doc(`other${RUN}`).set({ participantIds: [OWNER, "third"] });
  await db.collection("messages").doc(`m1${RUN}`).set({ conversationId: `conv${RUN}`, senderId: OWNER, content: "dum" });
  await db.collection("messages").doc(`m2${RUN}`).set({ conversationId: `other${RUN}`, senderId: OWNER, content: "privat" });
  await db.collection("messages").doc(`m3${RUN}`).set({ conversationId: `conv${RUN}`, senderId: REPORTER, content: "mitt" });

  const inConv = await report("message", `m1${RUN}`);
  check(
    "a message in the reporter's own conversation is captured",
    (await captureReportEvidence(db, inConv, NOW)) === "captured" &&
      (await evidence(inConv))?.text?.content === "dum",
  );
  const outside = await report("message", `m2${RUN}`);
  check(
    "a message in a conversation the reporter is not in keeps no text",
    (await captureReportEvidence(db, outside, NOW)) === "not_visible_to_reporter" &&
      (await evidence(outside))?.text === undefined,
  );
  const wrongOwner = await report("message", `m3${RUN}`);
  check(
    "a message whose sender is not the named owner keeps no text",
    (await captureReportEvidence(db, wrongOwner, NOW)) === "owner_mismatch" &&
      (await evidence(wrongOwner))?.text === undefined,
  );
}

async function others(): Promise<void> {
  await db.collection("recipe_comments").doc(`c${RUN}`).set({
    authorId: OWNER, text: "otrevlig", recipeOwnerId: "x", sharedWithUserIds: [REPORTER],
  });
  const comment = await report("comment", `c${RUN}`);
  check(
    "a comment the reporter can read is captured",
    (await captureReportEvidence(db, comment, NOW)) === "captured" &&
      (await evidence(comment))?.text?.text === "otrevlig",
  );

  await db.collection("cook_snaps").doc(`s${RUN}`).set({ userId: OWNER, caption: "bild", visibility: "sameAsRecipe" });
  const snapNoFriend = await report("cook_snap", `s${RUN}`);
  check(
    "a matbild from someone who is not the reporter's friend keeps no text",
    (await captureReportEvidence(db, snapNoFriend, NOW)) === "not_visible_to_reporter",
  );
  await db.collection("users").doc(OWNER).collection("friends").doc(REPORTER).set({ since: 1 });
  const snap = await report("cook_snap", `s${RUN}`);
  check(
    "a friend's matbild caption is captured",
    (await captureReportEvidence(db, snap, NOW)) === "captured" &&
      (await evidence(snap))?.text?.caption === "bild",
  );

  await db.collection("users").doc(OWNER).collection("friend_categories").doc(`g${RUN}`)
    .set({ ownerId: OWNER, name: "Gänget", description: "elak", friendUserIds: [REPORTER] });
  const group = await report("group", `g${RUN}`);
  check(
    "a group the reporter belongs to is captured",
    (await captureReportEvidence(db, group, NOW)) === "captured" &&
      (await evidence(group))?.text?.name === "Gänget",
  );

  await db.collection("public_profiles").doc(OWNER).set({ displayName: "Elak", bio: "usch", email: "no" });
  const profile = await report("profile", OWNER);
  const pev = await captureReportEvidence(db, profile, NOW);
  check(
    "a profile is captured without fields outside the list",
    pev === "captured" && JSON.stringify((await evidence(profile))?.text) === JSON.stringify({ displayName: "Elak", bio: "usch" }),
  );
  const otherProfile = await report("profile", "someone-else");
  check(
    "a profile report whose id is not the owner keeps no text",
    (await captureReportEvidence(db, otherProfile, NOW)) === "owner_mismatch",
  );

  const slash = await report("comment", `a/b${RUN}`);
  check(
    "an id containing a slash is refused before any read",
    (await captureReportEvidence(db, slash, NOW)) === "invalid_ref",
  );
  const unknown = await report("rating", `x${RUN}`);
  check(
    "an unknown content type is recorded, not read",
    (await captureReportEvidence(db, unknown, NOW)) === "unsupported_type",
  );
}

async function ordering(): Promise<void> {
  const closed = await report("comment", `c${RUN}`, { status: "closed" });
  check(
    "a report already closed gets no copy",
    (await captureReportEvidence(db, closed, NOW)) === "report_closed" && (await evidence(closed)) === undefined,
  );
  const ownerless = await report("comment", `c${RUN}`, { contentOwnerId: null });
  check(
    "a report with no owner gets no copy",
    (await captureReportEvidence(db, ownerless, NOW)) === "no_owner" && (await evidence(ownerless)) === undefined,
  );
  check(
    "a report that is gone gets no copy",
    (await captureReportEvidence(db, `nope${RUN}`, NOW)) === "report_gone",
  );
}

async function size(): Promise<void> {
  const row = "å".repeat(3000);
  await db.collection("users").doc(OWNER).collection("recipes").doc(`big${RUN}`).set({
    core: { title: "Stor", instructions: Array(60).fill(row) },
    socialData: { memberPermissions: { [REPORTER]: "viewer" } },
  });
  const big = await report("recipe", `big${RUN}`);
  const outcome = await captureReportEvidence(db, big, NOW);
  const ev = await evidence(big);
  const bytes = Buffer.byteLength(JSON.stringify(ev?.text ?? {}), "utf8");
  check(
    "an oversized recipe is cut to the budget and marked truncated",
    outcome === "captured" && ev?.truncated === true && bytes <= MAX_EVIDENCE_TEXT_BYTES + 4096,
    `outcome=${outcome} bytes=${bytes}`,
  );
}

function lifecycle(): void {
  const open = { status: "new", contentOwnerId: OWNER };
  const cases: Array<[string, Record<string, unknown> | undefined, Record<string, unknown> | undefined, boolean]> = [
    ["create", undefined, open, false],
    ["status moves forward", open, { ...open, status: "in_review" }, false],
    ["unrelated field changes", open, { ...open, reporterId: null }, false],
    ["case closes", open, { ...open, status: "closed" }, true],
    ["closed report written again", { ...open, status: "closed" }, { ...open, status: "closed" }, false],
    ["report deleted", open, undefined, true],
    ["owner anonymised", open, { ...open, contentOwnerId: null }, true],
  ];
  for (const [name, before, after, expected] of cases) {
    check(`lifecycle: ${name} → ${expected ? "delete" : "keep"}`, evidenceShouldGo(before, after) === expected);
  }
}

async function flatRecipe(): Promise<void> {
  await db.collection("users").doc(OWNER).collection("recipes").doc(`flat${RUN}`).set({
    title: "Gammalt", ingredients: ["mjöl"],
    socialData: { memberPermissions: { [REPORTER]: "viewer" } },
  });
  const flat = await report("recipe", `flat${RUN}`);
  await captureReportEvidence(db, flat, NOW);
  check(
    "a recipe stored without `core` is captured from the top level",
    (await evidence(flat))?.text?.title === "Gammalt",
    JSON.stringify((await evidence(flat))?.text),
  );
}

// The handlers themselves, not only the functions they call.
async function handlers(): Promise<void> {
  type Runnable = { run: (e: unknown) => Promise<unknown>; __endpoint: { eventTrigger?: { retry?: boolean } } };
  const { onReportCreated } = require("../feedback/on-report-created") as { onReportCreated: Runnable };
  const { onReportEvidenceLifecycle } =
    require("../moderation/on-report-evidence-lifecycle") as { onReportEvidenceLifecycle: Runnable };

  check(
    "the deletion trigger retries on failure",
    onReportEvidenceLifecycle.__endpoint.eventTrigger?.retry === true,
  );

  const created = await report("comment", `c${RUN}`);
  const snap = await db.collection("reports").doc(created).get();
  await onReportCreated.run({ id: `ev${created}`, params: { reportId: created }, data: snap });
  check("onReportCreated writes the copy", (await evidence(created))?.outcome === "captured");

  const write = async (id: string, change: (ref: admin.firestore.DocumentReference) => Promise<unknown>) => {
    const ref = db.collection("reports").doc(id);
    const before = await ref.get();
    await change(ref);
    const after = await ref.get();
    await onReportEvidenceLifecycle.run({ params: { reportId: id }, data: { before, after } });
  };

  await write(created, (ref) => ref.update({ status: "in_review" }));
  check("an open report's copy survives a status move", (await evidence(created)) !== undefined);

  for (const [name, change] of [
    ["closing the case", (ref: admin.firestore.DocumentReference) => ref.update({ status: "closed" })],
    ["deleting the report", (ref: admin.firestore.DocumentReference) => ref.delete()],
    ["anonymising the owner", (ref: admin.firestore.DocumentReference) => ref.update({ contentOwnerId: null })],
  ] as const) {
    const id = await report("comment", `c${RUN}`);
    await captureReportEvidence(db, id, NOW);
    await write(id, change);
    check(`${name} deletes the copy`, (await evidence(id)) === undefined);
  }
}

async function main(): Promise<void> {
  await recipes();
  await messages();
  await others();
  await ordering();
  await size();
  await flatRecipe();
  await handlers();
  lifecycle();
  console.log(`\nReport evidence: ${run - failed}/${run} passing.`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error("crashed:", err);
  process.exit(1);
});
