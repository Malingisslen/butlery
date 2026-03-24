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
  // New sustainability and metadata fields (Sprint 1)
  season_availability: string;
  price_category: string;
  carbon_footprint_category: string;
  notes_sv: string;
  notes_en: string;
  typical_storage: string;
  typical_unit: string;
  avg_price_sek: string;
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
  // New sustainability and metadata fields (Sprint 1)
  seasonAvailability?: string[];
  priceCategory?: string;
  carbonFootprintCategory?: string;
  notesSv?: string;
  notesEn?: string;
  typicalStorage?: string;
  typicalUnit?: string;
  avgPriceSek?: number;
}

interface Diff {
  toAdd: string[];
  toUpdate: string[];
  toRemove: string[];
  newData: Map<string, IngredientDoc>;
  unchanged: number;
}

interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
}

// Valid properties from Butlery_Ingredients_PROPERTIES.csv
const VALID_PROPERTIES = new Set([
  // Diet base
  "animal-product", "dairy", "egg", "meat", "plant-based", "seafood", "vegan-friendly",
  // Meat detail
  "beef", "fish", "game", "lamb", "pork", "poultry", "shellfish",
  // Allergens
  "contains-gluten", "contains-lactose", "peanut", "sesame", "soy", "tree-nut",
  "crustacean", "mollusc", "celery", "mustard", "lupin", "sulfites",
  // Special diet
  "contains-alcohol", "high-mercury", "nightshade",
  // Practical
  "needs-cooking", "processed", "is-spicy", "doesnt-freeze-well",
]);

// Valid group prefixes from Butlery_Ingredients_GROUPS.csv
const VALID_GROUP_PREFIXES = [
  "protein", "vegetable", "fruit", "grain", "fat", "other", "spice",
];

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

/**
 * CRIT-6: Converts CSV row to Firestore document with validation.
 * Throws if required fields are missing or empty, preventing corrupt documents.
 */
function csvToFirestore(row: IngredientRow): IngredientDoc {
  const parseList = (str: string, separator: string): string[] =>
    str
      .split(separator)
      .map((s) => s.trim())
      .filter((s) => s.length > 0);

  // CRIT-6: Validate required fields BEFORE conversion
  const id = row.id?.trim();
  const swedish = row.swedish?.trim();
  const english = row.english?.trim();
  const group = row.group?.trim();

  if (!id) {
    throw new Error(`CRIT-6: Row missing required 'id' field (swedish: ${swedish || "unknown"})`);
  }
  if (!swedish) {
    throw new Error(`CRIT-6: Row ${id} missing required 'swedish' field`);
  }

  // Parse new fields (Sprint 1)
  const seasonAvailability = parseList(row.season_availability || "", ";");
  const priceCategory = row.price_category?.trim() || undefined;
  const carbonFootprintCategory = row.carbon_footprint_category?.trim() || undefined;
  const notesSv = row.notes_sv?.trim() || undefined;
  const notesEn = row.notes_en?.trim() || undefined;
  const typicalStorage = row.typical_storage?.trim() || undefined;
  const typicalUnit = row.typical_unit?.trim() || undefined;
  const avgPriceSekStr = row.avg_price_sek?.trim();
  const avgPriceSek = avgPriceSekStr ? parseFloat(avgPriceSekStr) : undefined;

  const doc: IngredientDoc = {
    id,
    swedish,
    english: english || swedish, // Fallback to Swedish name if English missing
    group: group || "other", // Fallback to "other" category
    properties: parseList(row.properties || "", ","),
    aliasesSv: parseList(row.aliases_sv || "", ";"),
    aliasesEn: parseList(row.aliases_en || "", ";"),
    searchTerms: parseList(row.search_terms || "", ";"),
    status: row.status?.trim() || "validated",
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Only add new fields if they have values (sparse storage)
  if (seasonAvailability.length > 0) doc.seasonAvailability = seasonAvailability;
  if (priceCategory) doc.priceCategory = priceCategory;
  if (carbonFootprintCategory) doc.carbonFootprintCategory = carbonFootprintCategory;
  if (notesSv) doc.notesSv = notesSv;
  if (notesEn) doc.notesEn = notesEn;
  if (typicalStorage) doc.typicalStorage = typicalStorage;
  if (typicalUnit) doc.typicalUnit = typicalUnit;
  if (avgPriceSek !== undefined && !isNaN(avgPriceSek)) doc.avgPriceSek = avgPriceSek;

  return doc;
}

/**
 * Validates a single ingredient row for semantic correctness.
 * Checks group hierarchy and property validity.
 */
function validateIngredient(row: IngredientRow): ValidationResult {
  const errors: string[] = [];
  const warnings: string[] = [];

  // Validate required fields
  if (!row.id || row.id.trim() === "") {
    errors.push("Missing required field: id");
  }
  if (!row.swedish || row.swedish.trim() === "") {
    errors.push("Missing required field: swedish");
  }

  // Validate group hierarchy
  const group = row.group || "";
  if (group) {
    const hasValidPrefix = VALID_GROUP_PREFIXES.some((prefix) =>
      group === prefix || group.startsWith(prefix + "/")
    );
    if (!hasValidPrefix) {
      errors.push(`Invalid group: "${group}" (must start with: ${VALID_GROUP_PREFIXES.join(", ")})`);
    }
  } else {
    warnings.push("Missing group - ingredient will be uncategorized");
  }

  // Validate properties
  const properties = (row.properties || "")
    .split(",")
    .map((p) => p.trim())
    .filter((p) => p.length > 0);

  for (const prop of properties) {
    if (!VALID_PROPERTIES.has(prop)) {
      errors.push(`Unknown property: "${prop}"`);
    }
  }

  // Validate status
  const validStatuses = ["validated", "pending", "deleted"];
  if (row.status && !validStatuses.includes(row.status)) {
    warnings.push(`Unusual status: "${row.status}" (expected: ${validStatuses.join(", ")})`);
  }

  return {
    valid: errors.length === 0,
    errors,
    warnings,
  };
}

/**
 * Validates all ingredients and returns aggregated results.
 * Fails fast if any critical errors are found.
 *
 * HIGH-4: Includes duplicate ID detection to prevent silent data overwrites.
 */
function validateAllIngredients(
  rows: IngredientRow[],
  verbose: boolean
): { valid: boolean; errorCount: number; warningCount: number } {
  let errorCount = 0;
  let warningCount = 0;

  console.log("\n🔍 Validating ingredients...");

  // HIGH-4: Detect duplicate IDs before processing
  const seenIds = new Map<string, number>(); // id -> first occurrence line number
  const duplicates: { id: string; lines: number[] }[] = [];

  for (let i = 0; i < rows.length; i++) {
    const id = rows[i].id?.trim();
    if (!id) continue;

    if (seenIds.has(id)) {
      // Find or create duplicate entry
      let dupEntry = duplicates.find((d) => d.id === id);
      if (!dupEntry) {
        dupEntry = { id, lines: [seenIds.get(id)! + 2] }; // +2 for header row and 0-indexing
        duplicates.push(dupEntry);
      }
      dupEntry.lines.push(i + 2); // +2 for header row and 0-indexing
    } else {
      seenIds.set(id, i);
    }
  }

  if (duplicates.length > 0) {
    console.log("\n   ❌ Duplicate IDs detected (HIGH-4: data integrity risk):");
    for (const dup of duplicates) {
      console.log(`      • "${dup.id}" appears on CSV lines: ${dup.lines.join(", ")}`);
      errorCount++;
    }
    console.log("\n   ⚠️  Duplicates would cause silent data overwrites. Fix CSV before proceeding.");
    return { valid: false, errorCount, warningCount };
  }

  for (const row of rows) {
    const result = validateIngredient(row);

    if (result.errors.length > 0) {
      errorCount += result.errors.length;
      console.log(`\n   ❌ ${row.id || "(no id)"} - ${row.swedish || "(no name)"}:`);
      result.errors.forEach((e) => console.log(`      • ${e}`));
    }

    if (result.warnings.length > 0 && verbose) {
      warningCount += result.warnings.length;
      console.log(`\n   ⚠️  ${row.id || "(no id)"} - ${row.swedish || "(no name)"}:`);
      result.warnings.forEach((w) => console.log(`      • ${w}`));
    }
  }

  if (errorCount === 0) {
    console.log(`   ✅ All ${rows.length} ingredients passed validation`);
    if (warningCount > 0) {
      console.log(`   ⚠️  ${warningCount} warnings (use --verbose to see)`);
    }
  } else {
    console.log(`\n   ❌ Validation failed: ${errorCount} errors, ${warningCount} warnings`);
  }

  return { valid: errorCount === 0, errorCount, warningCount };
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
  // Compare string fields
  const stringFieldsToCompare = [
    "swedish", "english", "group", "status",
    // New fields (Sprint 1)
    "priceCategory", "carbonFootprintCategory", "notesSv", "notesEn",
    "typicalStorage", "typicalUnit",
  ];
  for (const field of stringFieldsToCompare) {
    if (String(current[field] || "") !== String(newData[field as keyof IngredientDoc] || "")) {
      return true;
    }
  }

  // Compare numeric fields
  const currentAvgPrice = current.avgPriceSek as number | undefined;
  const newAvgPrice = newData.avgPriceSek;
  if (currentAvgPrice !== newAvgPrice) {
    return true;
  }

  // Compare list fields
  const currentProps = (current.properties as string[]) || [];
  if (!listEquals(currentProps, newData.properties)) {
    return true;
  }

  const currentAliases = (current.aliasesSv as string[]) || [];
  if (!listEquals(currentAliases, newData.aliasesSv)) {
    return true;
  }

  // Compare seasonAvailability (Sprint 1)
  const currentSeasons = (current.seasonAvailability as string[]) || [];
  const newSeasons = newData.seasonAvailability || [];
  if (!listEquals(currentSeasons, newSeasons)) {
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

  // Validate all ingredients before any changes
  const validation = validateAllIngredients(csvIngredients, options.verbose);
  if (!validation.valid) {
    console.log("\n❌ Cannot proceed - validation errors must be fixed first.");
    console.log("   Fix the errors in the CSV file and try again.");
    process.exit(1);
  }

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
      expireAt: admin.firestore.Timestamp.fromDate(
        new Date(Date.now() + 30 * 24 * 60 * 60 * 1000)
      ),
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
