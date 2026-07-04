/**
 * BUT-1468: emulator integration test for alias learning's safety gates.
 *
 * What this proves (the roadmap's explicitly demanded test — none existed):
 * 1. 3 distinct mature users correcting to a NON-allergen ingredient →
 *    auto-approved, alias written to the live ingredient doc.
 * 2. Same quorum onto an ALLERGEN-bearing ingredient → held_for_review and
 *    the ingredient doc is UNTOUCHED (the hold blocks the write, not just
 *    the label).
 * 3. An alias whose TEXT is itself a known allergen-ingredient word is held
 *    even when the target is harmless (redirect direction).
 * 4. 2 users only → stays pending.
 * 5. Immature accounts don't count toward the quorum.
 * 6. reviewLearnedAlias approve → alias lands on the ingredient + audit row;
 *    revokeLearnedAlias → alias removed + audit row.
 *
 * Run: FIRESTORE_EMULATOR_HOST=localhost:8080 \
 *   ts-node src/__tests__/analyze-corrections-alias.test.ts
 */

import * as admin from "firebase-admin";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { stripDiacritics } = require("../shared/swedish-normalize");

const EMULATOR_HOST = process.env.FIRESTORE_EMULATOR_HOST ?? "localhost:8080";
process.env.FIRESTORE_EMULATOR_HOST = EMULATOR_HOST;

if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-alias-learning" });
}
const db = admin.firestore();

// eslint-disable-next-line @typescript-eslint/no-require-imports
const { processCorrectionEvent } = require("../analytics/analyze-corrections");
// eslint-disable-next-line @typescript-eslint/no-require-imports
const { performAliasReview, performAliasRevoke } = require("../analytics/review-learned-alias");

const RUN = Date.now().toString(36);
let failed = 0;
function assert(cond: boolean, msg: string): void {
  if (cond) {
    console.log(`  PASS  ${msg}`);
  } else {
    failed++;
    console.log(`  FAIL  ${msg}`);
  }
}

const MATURE = admin.firestore.Timestamp.fromMillis(Date.now() - 2 * 60 * 60 * 1000);
const FRESH = admin.firestore.Timestamp.now();

async function seedUser(uid: string, createdAt: admin.firestore.Timestamp): Promise<void> {
  await db.collection("users").doc(uid).set({ createdAt });
}

async function seedIngredient(
  id: string,
  swedish: string,
  properties: string[]
): Promise<void> {
  await db.collection("ingredients").doc(id).set({
    id,
    swedish,
    english: swedish,
    group: "other",
    properties,
    aliasesSv: [],
    aliasesEn: [],
    searchTerms: [],
    // Diacritics-stripped lookup form the sync stamps (BUT-1468 gate).
    normalizedNames: [stripDiacritics(swedish.toLowerCase().trim())],
    status: "validated",
  });
}

function correction(userId: string, originalName: string, correctedName: string): Record<string, unknown> {
  return {
    userId,
    domain: `test-${RUN}.se`,
    successfulTier: "RuleBased",
    ingredientCorrections: [
      { nameChanged: true, originalName, correctedName },
    ],
  };
}

/**
 * Look up a candidate by its (originalName, targetIngredientId) mapping —
 * the doc is keyed by both, so this is how the admin UI would find it too.
 * Returns the doc id + data, or undefined.
 */
async function findCandidate(
  original: string,
  ingredientId: string
): Promise<{ id: string; data: Record<string, unknown> } | undefined> {
  const snap = await db
    .collection("analytics").doc("ingredients").collection("learned_aliases")
    .where("originalName", "==", original.toLowerCase().trim())
    .where("ingredientId", "==", ingredientId)
    .limit(1)
    .get();
  if (snap.empty) return undefined;
  return { id: snap.docs[0].id, data: snap.docs[0].data() };
}

async function learnedAliases(ingredientId: string): Promise<string[]> {
  const snap = await db.collection("ingredients").doc(ingredientId).get();
  return (snap.data()?.learnedAliasesSv as string[]) ?? [];
}

async function main(): Promise<void> {
  console.log("BUT-1468: alias hold-for-review + revoke (emulator)\n");

  // Users: four mature, two fresh (immature)
  for (let i = 1; i <= 4; i++) await seedUser(`mature-${i}-${RUN}`, MATURE);
  for (let i = 1; i <= 2; i++) await seedUser(`fresh-${i}-${RUN}`, FRESH);

  // Ingredients: two harmless, one allergen-bearing, one whose NAME is an allergen word
  const plainId = `graslok-${RUN}`;
  const plain2Id = `dill-${RUN}`;
  const allergenId = `jordnotssmor-${RUN}`;
  const allergenWordId = `jordnotter-${RUN}`;
  await seedIngredient(plainId, `gräslök-${RUN}`, ["plant-based"]);
  await seedIngredient(plain2Id, `dill-${RUN}`, ["plant-based"]);
  await seedIngredient(allergenId, `jordnötssmör-${RUN}`, ["peanut", "processed"]);
  await seedIngredient(allergenWordId, `jordnötter-${RUN}`, ["peanut"]);

  // --- 1. Non-allergen target: 3 mature users → auto-approve + live write ---
  for (let i = 1; i <= 3; i++) {
    await processCorrectionEvent(db, correction(`mature-${i}-${RUN}`, `graeslok-${RUN}`, `gräslök-${RUN}`));
  }
  const approved = await findCandidate(`graeslok-${RUN}`, plainId);
  assert(approved?.data.status === "approved", "non-allergen target auto-approves at 3 mature users");
  assert(
    (await learnedAliases(plainId)).includes(`graeslok-${RUN}`),
    "approved alias written to live ingredient doc"
  );

  // --- 2. Allergen target: 3 mature users → held, ingredient untouched ---
  for (let i = 1; i <= 3; i++) {
    await processCorrectionEvent(db, correction(`mature-${i}-${RUN}`, `pb-krem-${RUN}`, `jordnötssmör-${RUN}`));
  }
  const held = await findCandidate(`pb-krem-${RUN}`, allergenId);
  assert(held?.data.status === "held_for_review", "allergen target is held for review at quorum");
  assert(held?.data.heldReason === "allergen_target", "hold reason recorded");
  assert(
    (await learnedAliases(allergenId)).length === 0,
    "held alias did NOT touch the live ingredient doc"
  );

  // --- 3. Allergen WORD (submitted WITHOUT umlauts) as alias text onto a
  //        harmless target → held. This is the HIGH-finding bypass: the
  //        client matches learned aliases diacritics-stripped, so "jordnotter"
  //        would redirect the real "jordnötter" peanut word onto gräslök and
  //        produce a false FREE. The gate must resolve the stripped form. ---
  const attackWord = `jordnotter-${RUN}`; // note: NO umlaut
  for (let i = 1; i <= 3; i++) {
    await processCorrectionEvent(db, correction(`mature-${i}-${RUN}`, attackWord, `gräslök-${RUN}`));
  }
  const heldWord = await findCandidate(attackWord, plainId);
  assert(
    heldWord?.data.status === "held_for_review" && heldWord?.data.heldReason === "allergen_alias_text",
    "diacritics-stripped allergen word is held on a harmless target (redirect bypass blocked)"
  );
  assert(
    !(await learnedAliases(plainId)).includes(attackWord),
    "redirect attempt did not reach the live ingredient doc"
  );

  // --- 4. Two users only → pending ---
  for (let i = 1; i <= 2; i++) {
    await processCorrectionEvent(db, correction(`mature-${i}-${RUN}`, `vitloek-${RUN}`, `gräslök-${RUN}`));
  }
  assert((await findCandidate(`vitloek-${RUN}`, plainId))?.data.status === "pending", "2 users stay pending");

  // --- 5. Immature accounts don't count ---
  await processCorrectionEvent(db, correction(`mature-1-${RUN}`, `sockerlag-${RUN}`, `gräslök-${RUN}`));
  await processCorrectionEvent(db, correction(`fresh-1-${RUN}`, `sockerlag-${RUN}`, `gräslök-${RUN}`));
  await processCorrectionEvent(db, correction(`fresh-2-${RUN}`, `sockerlag-${RUN}`, `gräslök-${RUN}`));
  const withFresh = await findCandidate(`sockerlag-${RUN}`, plainId);
  assert(
    withFresh?.data.status === "pending" && (withFresh?.data.userIds as string[]).length === 1,
    "immature accounts never enter the quorum (1 counted vote, still pending)"
  );

  // --- 5b. THREE users, THREE DIFFERENT targets → no consensus (xhigh fix).
  //          The quorum is per (original → target) mapping, so a word split
  //          across ingredients never forms a false consensus. ---
  await processCorrectionEvent(db, correction(`mature-1-${RUN}`, `buljong-${RUN}`, `gräslök-${RUN}`));
  await processCorrectionEvent(db, correction(`mature-2-${RUN}`, `buljong-${RUN}`, `dill-${RUN}`));
  await processCorrectionEvent(db, correction(`mature-3-${RUN}`, `buljong-${RUN}`, `jordnötssmör-${RUN}`));
  const split1 = await findCandidate(`buljong-${RUN}`, plainId);
  const split2 = await findCandidate(`buljong-${RUN}`, plain2Id);
  assert(
    split1?.data.status === "pending" && split2?.data.status === "pending",
    "3 users disagreeing on the target form no consensus (each mapping stays pending)"
  );
  assert(
    !(await learnedAliases(plainId)).includes(`buljong-${RUN}`) &&
      !(await learnedAliases(plain2Id)).includes(`buljong-${RUN}`),
    "no split-target alias reached any live ingredient doc"
  );

  // --- 6. Review approve → live write + audit; revoke → removed + audit ---
  const heldId = held!.id;
  const reviewed = await performAliasReview(db, {
    aliasDocId: heldId,
    decision: "approve",
    adminUid: `admin-${RUN}`,
  });
  assert(reviewed.status === "approved", "held alias approved by admin");
  assert(
    (await learnedAliases(allergenId)).includes(`pb-krem-${RUN}`),
    "admin approval writes the alias to the live ingredient doc"
  );

  const revoked = await performAliasRevoke(db, {
    aliasDocId: heldId,
    adminUid: `admin-${RUN}`,
  });
  assert(revoked.status === "revoked", "approved alias revoked");
  assert(
    !(await learnedAliases(allergenId)).includes(`pb-krem-${RUN}`),
    "revoke removes the alias from the live ingredient doc"
  );

  // --- 6b. Re-approve after a mistaken revoke is the undo path (xhigh fix) ---
  const reApproved = await performAliasReview(db, {
    aliasDocId: heldId,
    decision: "approve",
    adminUid: `admin-${RUN}`,
  });
  assert(reApproved.status === "approved", "revoked alias can be re-approved (undo)");
  assert(
    (await learnedAliases(allergenId)).includes(`pb-krem-${RUN}`),
    "re-approval re-adds the alias to the live ingredient doc"
  );
  // put it back to revoked for a clean audit assertion below
  await performAliasRevoke(db, { aliasDocId: heldId, adminUid: `admin-${RUN}` });

  const audits = await db
    .collection("audit_logs")
    .where("resourceId", "==", heldId)
    .get();
  const ops = audits.docs.map((d) => d.data().operation).sort();
  assert(
    JSON.stringify(ops) === JSON.stringify(["alias_approve", "alias_approve", "alias_revoke", "alias_revoke"]),
    "each approve and revoke left an audit_logs row (raw admin uid)"
  );
  assert(
    audits.docs.every((d) => d.data().userId === `admin-${RUN}`),
    "audit rows store the raw admin uid (audit_logs schema)"
  );

  // Idempotent replay
  const replay = await performAliasRevoke(db, {
    aliasDocId: heldId,
    adminUid: `admin-${RUN}`,
  });
  assert(replay.status === "revoked", "revoke replay is idempotent");

  console.log(failed === 0 ? "\nAll assertions passed" : `\n${failed} FAILED`);
  process.exit(failed === 0 ? 0 : 1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
