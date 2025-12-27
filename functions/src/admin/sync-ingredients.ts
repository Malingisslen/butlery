/**
 * Syncs ingredient data from CSV to Firestore.
 *
 * Prerequisites:
 *   1. Login to Firebase: firebase login
 *   2. Set project: firebase use butlery-app-1
 *   3. Set GOOGLE_APPLICATION_CREDENTIALS to service account key, OR
 *   4. Run: gcloud auth application-default login
 *
 * Usage:
 *   cd functions
 *   npm run sync-ingredients:dry-run   # Preview changes
 *   npm run sync-ingredients -- --force  # Apply changes
 *
 * Options:
 *   --dry-run    Preview changes without applying
 *   --force      Skip confirmation prompts
 *   --verbose    Show detailed logging
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";
import * as readline from "readline";

const PROJECT_ID = "butlery-app-1";

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
  });
}

const db = admin.firestore();

interface Options {
  dryRun: boolean;
  force: boolean;
  verbose: boolean;
}

interface IngredientRow {
  id: string;
  swedish: string;
  english: string;
  group: string;
  properties: string;
  aliases_sv: string;
  aliases_en: string;
  search_terms: string;
  status: string;
  [key: string]: string;
}

interface IngredientDoc {
  id: string;
  swedish: string;
  english: string;
  group: string;
  properties: string[];
  aliasesSv: string[];
  aliasesEn: string[];
  searchTerms: string[];
  status: string;
  updatedAt: admin.firestore.FieldValue;
}

interface Diff {
  toAdd: string[];
  toUpdate: string[];
  toRemove: string[];
  newData: Map<string, IngredientDoc>;
  unchanged: number;
}

function parseArgs(args: string[]): Options {
  return {
    dryRun: args.includes("--dry-run"),
    force: args.includes("--force"),
    verbose: args.includes("--verbose") || args.includes("-v"),
  };
}

function parseCsvLine(line: string): string[] {
  const result: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];

    if (char === '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === "," && !inQuotes) {
      result.push(current.trim());
      current = "";
    } else {
      current += char;
    }
  }

  result.push(current.trim());
  return result;
}

function loadCsv(filePath: string): IngredientRow[] {
  const content = fs.readFileSync(filePath, "utf-8");
  const lines = content.split("\n").filter((l) => l.trim());

  if (lines.length === 0) return [];

  const headers = parseCsvLine(lines[0]);
  const results: IngredientRow[] = [];

  for (let i = 1; i < lines.length; i++) {
    const values = parseCsvLine(lines[i]);
    if (values.length !== headers.length) {
      console.log(
        `   ⚠️ Skipping malformed row ${i}: ${values.length} vs ${headers.length} columns`
      );
      continue;
    }

    const row: Record<string, string> = {};
    headers.forEach((h, j) => {
      row[h] = values[j];
    });
    results.push(row as IngredientRow);
  }

  return results;
}

function csvToFirestore(row: IngredientRow): IngredientDoc {
  const parseList = (str: string, separator: string): string[] =>
    str
      .split(separator)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);

  return {
    id: row.id || "",
    swedish: row.swedish || "",
    english: row.english || "",
    group: row.group || "",
    properties: parseList(row.properties || "", ","),
    aliasesSv: parseList(row.aliases_sv || "", ";"),
    aliasesEn: parseList(row.aliases_en || "", ";"),
    searchTerms: parseList(row.search_terms || "", ";"),
    status: row.status || "validated",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };
}

function listEquals(a: string[], b: string[]): boolean {
  if (a.length !== b.length) return false;
  const setA = new Set(a);
  const setB = new Set(b);
  return [...setA].every((x) => setB.has(x)) && [...setB].every((x) => setA.has(x));
}

function hasChanges(
  current: admin.firestore.DocumentData,
  newData: IngredientDoc
): boolean {
  const fieldsToCompare = ["swedish", "english", "group", "status"];
  for (const field of fieldsToCompare) {
    if (String(current[field] || "") !== String(newData[field as keyof IngredientDoc] || "")) {
      return true;
    }
  }

  const currentProps = (current.properties as string[]) || [];
  if (!listEquals(currentProps, newData.properties)) {
    return true;
  }

  const currentAliases = (current.aliasesSv as string[]) || [];
  if (!listEquals(currentAliases, newData.aliasesSv)) {
    return true;
  }

  return false;
}

async function calculateDiff(
  csvData: IngredientRow[],
  currentData: Map<string, admin.firestore.DocumentData>
): Promise<Diff> {
  const toAdd: string[] = [];
  const toUpdate: string[] = [];
  const toRemove: string[] = [];
  const newData = new Map<string, IngredientDoc>();
  let unchanged = 0;

  for (const row of csvData) {
    const id = row.id;
    if (!id) continue;

    const firestoreData = csvToFirestore(row);
    newData.set(id, firestoreData);

    if (!currentData.has(id)) {
      toAdd.push(id);
    } else {
      if (hasChanges(currentData.get(id)!, firestoreData)) {
        toUpdate.push(id);
      } else {
        unchanged++;
      }
    }
  }

  for (const [id, data] of currentData) {
    if (!newData.has(id) && data.status !== "deleted") {
      toRemove.push(id);
    }
  }

  return { toAdd, toUpdate, toRemove, newData, unchanged };
}

async function askConfirmation(question: string): Promise<boolean> {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  });

  return new Promise((resolve) => {
    rl.question(question, (answer) => {
      rl.close();
      resolve(answer.toLowerCase() === "y" || answer.toLowerCase() === "yes");
    });
  });
}

async function main(): Promise<void> {
  const options = parseArgs(process.argv.slice(2));

  console.log("🔄 Ingredient Sync Tool (Node.js)");
  console.log("=".repeat(50));

  // Load CSV files
  console.log("\n📂 Loading CSV files...");
  const csvPath = path.resolve(
    __dirname,
    "../../../docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv"
  );

  if (!fs.existsSync(csvPath)) {
    console.log(`❌ Error: CSV not found at ${csvPath}`);
    process.exit(1);
  }

  const csvIngredients = loadCsv(csvPath);
  console.log(`   Loaded ${csvIngredients.length} ingredients from CSV`);

  // Load current Firestore data
  console.log("\n📥 Loading current Firestore data...");
  const snapshot = await db.collection("ingredients").get();
  const currentData = new Map<string, admin.firestore.DocumentData>();
  snapshot.docs.forEach((doc) => {
    currentData.set(doc.id, doc.data());
  });
  console.log(`   Found ${currentData.size} ingredients in Firestore`);

  // Calculate diff
  console.log("\n🔍 Calculating changes...");
  const diff = await calculateDiff(csvIngredients, currentData);

  // Show summary
  console.log("\n📊 Change Summary:");
  console.log(`   ➕ Adding: ${diff.toAdd.length}`);
  console.log(`   ✏️  Updating: ${diff.toUpdate.length}`);
  console.log(`   ➖ Removing: ${diff.toRemove.length}`);
  console.log(`   ✅ Unchanged: ${diff.unchanged}`);

  if (options.verbose) {
    if (diff.toAdd.length > 0) {
      console.log("\n   New ingredients:");
      diff.toAdd.slice(0, 10).forEach((id) => console.log(`     - ${id}`));
      if (diff.toAdd.length > 10) {
        console.log(`     ... and ${diff.toAdd.length - 10} more`);
      }
    }

    if (diff.toUpdate.length > 0) {
      console.log("\n   Updated ingredients:");
      diff.toUpdate.slice(0, 10).forEach((id) => console.log(`     - ${id}`));
      if (diff.toUpdate.length > 10) {
        console.log(`     ... and ${diff.toUpdate.length - 10} more`);
      }
    }
  }

  // Exit if no changes
  if (
    diff.toAdd.length === 0 &&
    diff.toUpdate.length === 0 &&
    diff.toRemove.length === 0
  ) {
    console.log("\n✅ No changes needed. Firestore is up to date.");
    process.exit(0);
  }

  // Dry run check
  if (options.dryRun) {
    console.log("\n🔍 Dry run mode - no changes applied.");
    process.exit(0);
  }

  // Confirmation
  if (!options.force) {
    const confirmed = await askConfirmation(
      "\n⚠️  Apply these changes to Firestore? (y/N) "
    );
    if (!confirmed) {
      console.log("Cancelled.");
      process.exit(0);
    }
  }

  // Apply changes
  console.log("\n📤 Applying changes...");
  let batch = db.batch();
  let batchCount = 0;
  const maxBatchSize = 500;

  const commitBatch = async (): Promise<void> => {
    if (batchCount > 0) {
      await batch.commit();
      console.log(`   Committed batch of ${batchCount}`);
      batch = db.batch(); // Create new batch after commit
      batchCount = 0;
    }
  };

  // Add new ingredients
  for (const id of diff.toAdd) {
    const data = diff.newData.get(id)!;
    batch.set(db.collection("ingredients").doc(id), data);
    batchCount++;
    if (batchCount >= maxBatchSize) {
      await commitBatch();
    }
  }

  // Update existing ingredients
  for (const id of diff.toUpdate) {
    const data = diff.newData.get(id)!;
    batch.update(
      db.collection("ingredients").doc(id),
      data as unknown as admin.firestore.UpdateData<admin.firestore.DocumentData>
    );
    batchCount++;
    if (batchCount >= maxBatchSize) {
      await commitBatch();
    }
  }

  // Soft delete removed ingredients
  for (const id of diff.toRemove) {
    batch.update(db.collection("ingredients").doc(id), {
      status: "deleted",
      deletedAt: admin.firestore.FieldValue.serverTimestamp(),
    });
    batchCount++;
    if (batchCount >= maxBatchSize) {
      await commitBatch();
    }
  }

  // Commit remaining
  await commitBatch();

  console.log("\n✅ Sync complete!");
  console.log(`   Added: ${diff.toAdd.length}`);
  console.log(`   Updated: ${diff.toUpdate.length}`);
  console.log(`   Removed: ${diff.toRemove.length}`);

  process.exit(0);
}

main().catch((error) => {
  if (error.message?.includes("Unable to detect a Project Id")) {
    console.error("\n❌ Authentication Error");
    console.error("   Firebase Admin SDK needs credentials to connect.\n");
    console.error("   To fix this, do ONE of the following:\n");
    console.error("   Option 1: Download service account key");
    console.error("     1. Go to Firebase Console → Project Settings → Service Accounts");
    console.error("     2. Click 'Generate new private key'");
    console.error("     3. Save as: functions/service-account.json");
    console.error("     4. Run: set GOOGLE_APPLICATION_CREDENTIALS=service-account.json");
    console.error("     5. Re-run this script\n");
    console.error("   Option 2: Use ADC (if you have gcloud)");
    console.error("     1. Run: gcloud auth application-default login");
    console.error("     2. Re-run this script\n");
  } else {
    console.error("Error:", error.message || error);
  }
  process.exit(1);
});
