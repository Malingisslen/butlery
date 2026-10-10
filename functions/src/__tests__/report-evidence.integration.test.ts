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

import { withdrawReporterCredit } from "../moderation/menu-dish-credit";
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

  // BUT-2339: the handler takes the copy before it removes the name.
  const menu = db.collection("shared_content").doc(`hmenu${RUN}`);
  await menu.set({
    sharedByUserId: OWNER,
    contentType: "menu",
    sharedToUserIds: [REPORTER],
    menuSnapshot: { Middag: [{ id: "dish1", title: "Linsgryta", createdBy: REPORTER }] },
  });
  const notMine = await report("menu_dish", `hmenu${RUN}`, { reason: "misattribution", dishId: "dish1" });
  const notMineSnap = await db.collection("reports").doc(notMine).get();
  await onReportCreated.run({ id: `ev${notMine}`, params: { reportId: notMine }, data: notMineSnap });
  check(
    "the handler's copy records that the dish named the reporter",
    (await evidence(notMine))?.claimedCreatorIsReporter === true,
  );
  check(
    "the handler removes the reporter's name from the dish",
    !("createdBy" in (await menu.get()).data()?.menuSnapshot.Middag[0]),
  );

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

/**
 * BUT-2339: a dish in a shared menu. The copy holds the dish's text and
 * whether it named the reporter, never a third person's uid.
 */
async function menuDishes(): Promise<void> {
  const FORGER = `forger${RUN}`;
  const menus = db.collection("shared_content");
  const menuDoc = (sharedTo: string[]) => ({
    sharedByUserId: OWNER,
    contentType: "menu",
    sharedToUserIds: sharedTo,
    menuSnapshot: {
      Middag: [
        { id: "dish1", title: "Linsgryta", description: "Fel namn", createdBy: REPORTER },
        { id: "dish2", title: "Pasta", createdBy: FORGER },
      ],
      Lunch: [{ id: "dish1", title: "Linsgryta", createdBy: REPORTER }],
    },
  });
  await menus.doc(`menu${RUN}`).set(menuDoc([REPORTER]));
  await menus.doc(`members${RUN}`).set(menuDoc([]));
  await menus.doc(`members${RUN}`).collection("members").doc(REPORTER).set({ userId: REPORTER });
  await menus.doc(`closed${RUN}`).set(menuDoc([]));

  const misattr = { reason: "misattribution", dishId: "dish1" };
  const named = await report("menu_dish", `menu${RUN}`, misattr);
  check("a dish in a menu shared with the reporter is captured", (await captureReportEvidence(db, named, NOW)) === "captured");
  const ev = await evidence(named);
  check(
    "the dish copy holds the dish's title and description",
    JSON.stringify(ev?.text) === JSON.stringify({ title: "Linsgryta", description: "Fel namn" }),
    JSON.stringify(ev?.text),
  );
  check("the copy records that the dish named the reporter", ev?.claimedCreatorIsReporter === true);
  check(
    "the copy holds no third uid",
    ev !== undefined && !JSON.stringify(ev).includes(FORGER) && !("reporterId" in ev),
  );

  check("the copy holds no reporter uid", ev !== undefined && !JSON.stringify(ev).includes(REPORTER));

  const other = await report("menu_dish", `menu${RUN}`, { dishId: "dish2" });
  await captureReportEvidence(db, other, NOW);
  const otherEv = await evidence(other);
  check("a dish naming someone else records false", otherEv?.claimedCreatorIsReporter === false);
  check(
    "the copy of a dish naming a third person holds no uid of theirs",
    otherEv !== undefined && !JSON.stringify(otherEv).includes(FORGER),
  );

  // The fact covers every copy of the dish, as the withdrawal does.
  await menus.doc(`split${RUN}`).set({
    ...menuDoc([REPORTER]),
    menuSnapshot: {
      Lunch: [{ id: "dish1", title: "Linsgryta", createdBy: FORGER }],
      Middag: [{ id: "dish1", title: "Linsgryta", createdBy: REPORTER }],
    },
  });
  const split = await report("menu_dish", `split${RUN}`, misattr);
  await captureReportEvidence(db, split, NOW);
  check(
    "a dish naming the reporter in any of its copies records true",
    (await evidence(split))?.claimedCreatorIsReporter === true,
  );

  const viaMember = await report("menu_dish", `members${RUN}`, misattr);
  check(
    "a member of the share may have it copied",
    (await captureReportEvidence(db, viaMember, NOW)) === "captured",
  );

  const outsider = await report("menu_dish", `closed${RUN}`, misattr);
  check(
    "a menu the reporter cannot read keeps no text",
    (await captureReportEvidence(db, outsider, NOW)) === "not_visible_to_reporter" &&
      (await evidence(outsider))?.text === undefined,
  );

  const wrongOwner = await report("menu_dish", `menu${RUN}`, { ...misattr, contentOwnerId: FORGER });
  check(
    "a report naming someone other than the sharer is an owner mismatch",
    (await captureReportEvidence(db, wrongOwner, NOW)) === "owner_mismatch",
  );

  const noDish = await report("menu_dish", `menu${RUN}`, { ...misattr, dishId: "gone" });
  check("a dish no longer in the menu records missing", (await captureReportEvidence(db, noDish, NOW)) === "missing");

  // The withdrawal: only the reporter's own uid goes, on every copy of the dish.
  check(
    "a misattribution report removes the reporter's name from the dish",
    (await withdrawReporterCredit(db, named)) === "withdrawn",
  );
  const after = (await menus.doc(`menu${RUN}`).get()).data()?.menuSnapshot;
  check(
    "every copy of the dish loses createdBy and the other dish keeps its own",
    !("createdBy" in after.Middag[0]) && !("createdBy" in after.Lunch[0]) &&
      after.Middag[1].createdBy === FORGER && after.Middag[0].title === "Linsgryta",
    JSON.stringify(after),
  );
  const notMine = await report("menu_dish", `menu${RUN}`, { reason: "misattribution", dishId: "dish2" });
  check(
    "a dish naming someone else is left alone",
    (await withdrawReporterCredit(db, notMine)) === "not_named" &&
      (await menus.doc(`menu${RUN}`).get()).data()?.menuSnapshot.Middag[1].createdBy === FORGER,
  );
  const abuse = await report("menu_dish", `members${RUN}`, { dishId: "dish1" });
  check(
    "an ordinary report on a dish withdraws nothing",
    (await withdrawReporterCredit(db, abuse)) === "not_applicable" &&
      (await menus.doc(`members${RUN}`).get()).data()?.menuSnapshot.Middag[0].createdBy === REPORTER,
  );
  const gone = await report("menu_dish", `nomenu${RUN}`, misattr);
  check("a deleted menu withdraws nothing", (await withdrawReporterCredit(db, gone)) === "menu_gone");
}

async function main(): Promise<void> {
  await recipes();
  await messages();
  await others();
  await ordering();
  await size();
  await flatRecipe();
  await menuDishes();
  await handlers();
  lifecycle();
  console.log(`\nReport evidence: ${run - failed}/${run} passing.`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error("crashed:", err);
  process.exit(1);
});
