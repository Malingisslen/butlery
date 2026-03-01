/**
 * Exports all ingredients from Firestore to JSON for static Dart codegen.
 *
 * This is the first step of the Firebase → Dart pipeline:
 *   1. This script exports Firestore → scripts/crf/data/firebase_ingredients.json
 *   2. Then run: dart run scripts/crf/generate_known_ingredients.dart
 *      to regenerate lib/constants/known_ingredients.dart
 *
 * Prerequisites:
 *   1. Login: firebase login
 *
 * Usage:
 *   cd functions
 *   npx ts-node src/admin/export-ingredients.ts
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

const PROJECT_ID = "butlery-app-1";

/**
 * Finds Firebase CLI application default credentials.
 * Firebase CLI stores these in %APPDATA%/firebase/ on Windows
 * or ~/.config/firebase/ on macOS/Linux.
 */
function findFirebaseCredentials(): string | null {
  const candidates: string[] = [];

  // Windows: %APPDATA%/firebase/
  if (process.env.APPDATA) {
    const dir = path.join(process.env.APPDATA, "firebase");
    if (fs.existsSync(dir)) {
      const files = fs.readdirSync(dir).filter((f) => f.endsWith("_application_default_credentials.json"));
      candidates.push(...files.map((f) => path.join(dir, f)));
    }
  }

  // macOS/Linux: ~/.config/firebase/
  const home = process.env.HOME || process.env.USERPROFILE || "";
  if (home) {
    const dir = path.join(home, ".config", "firebase");
    if (fs.existsSync(dir)) {
      const files = fs.readdirSync(dir).filter((f) => f.endsWith("_application_default_credentials.json"));
      candidates.push(...files.map((f) => path.join(dir, f)));
    }
  }

  return candidates[0] || null;
}

if (!admin.apps.length) {
  const credPath = findFirebaseCredentials();
  if (credPath) {
    process.env.GOOGLE_APPLICATION_CREDENTIALS = credPath;
    console.error(`Using credentials: ${credPath}`);
  }
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });
}

const db = admin.firestore();

interface ExportedIngredient {
  id: string;
  swedish: string;
  group: string;
  aliasesSv: string[];
  isCompoundName: boolean;
  properties: string[];
}

async function main(): Promise<void> {
  console.error("Fetching ingredients from Firestore...");

  const snapshot = await db.collection("ingredients").get();
  console.error(`Found ${snapshot.size} ingredients`);

  const ingredients: ExportedIngredient[] = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    ingredients.push({
      id: doc.id,
      swedish: (data.swedish || "").toLowerCase().trim(),
      group: data.group || "",
      aliasesSv: (data.aliasesSv || []).map((a: string) =>
        a.toLowerCase().trim()
      ),
      isCompoundName: data.isCompoundName === true,
      properties: data.properties || [],
    });
  }

  // Sort for deterministic output
  ingredients.sort((a, b) => a.swedish.localeCompare(b.swedish, "sv"));

  const outputPath = path.resolve(
    __dirname,
    "../../..",
    "scripts/crf/data/firebase_ingredients.json"
  );

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(ingredients, null, 2) + "\n");

  console.error(`Exported ${ingredients.length} ingredients to ${outputPath}`);
  console.error(
    `  Compound names: ${ingredients.filter((i) => i.isCompoundName).length}`
  );
  console.error(
    `  With aliases: ${ingredients.filter((i) => i.aliasesSv.length > 0).length}`
  );

  // Print group distribution
  const groups = new Map<string, number>();
  for (const i of ingredients) {
    const top = i.group.split("/")[0] || "unknown";
    groups.set(top, (groups.get(top) || 0) + 1);
  }
  console.error("  Groups:");
  for (const [group, count] of [...groups.entries()].sort()) {
    console.error(`    ${group}: ${count}`);
  }
}

main().catch((e) => {
  console.error("Error:", e);
  process.exit(1);
});
