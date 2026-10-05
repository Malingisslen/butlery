#!/usr/bin/env node
/**
 * Fills the LOCAL emulator suite with what the app needs to run end to end:
 * the ingredient database and the tag configs. Run book: docs/ops/local-emulator.md.
 *
 * Refuses to run unless every client it creates is pointed at an emulator and the
 * project id is a `demo-` project, which has no production counterpart.
 *
 * Usage (scripts/emulator/start.sh does this for you):
 *   FIRESTORE_EMULATOR_HOST=localhost:8080 FIREBASE_AUTH_EMULATOR_HOST=localhost:9099 \
 *   GCLOUD_PROJECT=demo-butlery node functions/scripts/seed-emulator.js
 */
"use strict";

const fs = require("fs");
const path = require("path");
const admin = require("firebase-admin");

const projectId = process.env.GCLOUD_PROJECT || "";
const missing = ["FIRESTORE_EMULATOR_HOST", "FIREBASE_AUTH_EMULATOR_HOST"].filter(
  (name) => !process.env[name],
);
if (missing.length > 0 || !projectId.startsWith("demo-")) {
  console.error(
    `Refusing to seed: need ${missing.join(", ") || "nothing missing"} set and a demo- ` +
      `project id (got "${projectId}").`,
  );
  process.exit(1);
}

const repoRoot = path.resolve(__dirname, "../..");
const ingredientsFile = path.join(repoRoot, "scripts/crf/data/firebase_ingredients.json");
const tagConfigDir = path.join(repoRoot, "scripts/output/tagConfigs");
const TAG_CONFIGS = ["allergens", "dietary", "cuisines", "properties", "display"];

admin.initializeApp({ projectId });
const db = admin.firestore();

async function seedIngredients() {
  const ingredients = JSON.parse(fs.readFileSync(ingredientsFile, "utf8"));
  const now = admin.firestore.FieldValue.serverTimestamp();
  for (let i = 0; i < ingredients.length; i += 450) {
    const batch = db.batch();
    for (const ingredient of ingredients.slice(i, i + 450)) {
      batch.set(db.collection("ingredients").doc(ingredient.id), {
        ...ingredient,
        updatedAt: now,
      });
    }
    await batch.commit();
  }
  return ingredients.length;
}

async function seedTagConfigs() {
  const batch = db.batch();
  for (const name of TAG_CONFIGS) {
    const data = JSON.parse(fs.readFileSync(path.join(tagConfigDir, `${name}.json`), "utf8"));
    batch.set(db.collection("tag_configs").doc(name), data);
  }
  await batch.commit();
}

(async () => {
  const count = await seedIngredients();
  await seedTagConfigs();
  console.log(`Seeded ${count} ingredients and ${TAG_CONFIGS.length} tag configs into ${projectId}.`);
})().catch((error) => {
  console.error(error);
  process.exit(1);
});
