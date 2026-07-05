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
import {
  IngredientRow,
  buildSyncReport,
  buildUpdatePayload,
  calculateDiff,
  deriveLearnedAliasesAtRisk,
  SyncReport,
  VALID_GROUP_PREFIXES,
  VALID_PROPERTIES,
} from "./sync-ingredients-core";

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

interface ValidationResult {
  valid: boolean;
  errors: string[];
  warnings: string[];
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
  const malformed: number[] = [];

  for (let i = 1; i < lines.length; i++) {
    const values = parseCsvLine(lines[i]);
    if (values.length !== headers.length) {
      malformed.push(i);
      console.log(
        `   ❌ Malformed row ${i}: ${values.length} vs ${headers.length} columns`
      );
      continue;
    }

    const row: Record<string, string> = {};
    headers.forEach((h, j) => {
      row[h] = values[j];
    });
    results.push(row as IngredientRow);
  }

  // FAIL CLOSED on malformed rows. A skipped row silently falls out of
  // csvData and lands in toRemove — i.e. a mangled quoted cell (typically a
  // multi-line note; this parser splits on \n before quote handling) would
  // soft-delete a live ingredient and, 30 days later, erase its allergen
  // verdicts. Abort and make the operator fix the Sheet cell instead.
  if (malformed.length > 0) {
    console.log(
      `\n❌ ${malformed.length} malformed CSV row(s) (lines ${malformed.join(", ")}).` +
      "\n   A skipped row would be treated as removed and soft-deleted in production." +
      "\n   Fix the Sheet cells (usually a line break inside a quoted cell) and re-export."
    );
    process.exit(1);
  }

  return results;
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

  // Generic 'seafood' without a detail property triggers the conservative
  // skaldjur CONTAINS verdict client-side (allergen safety net, 2026-07-02).
  // Legit only for non-crustacean/non-mollusc marine animals (jellyfish,
  // sea urchin, sea cucumber) — warn so mislabeled fish/shellfish get fixed.
  if (
    properties.includes("seafood") &&
    !properties.some((p) => ["fish", "crustacean", "mollusc"].includes(p))
  ) {
    warnings.push(
      "Generic 'seafood' without fish/crustacean/mollusc detail — " +
      "the specific allergen (fisk/kräftdjur/blötdjur) cannot be detected " +
      "and the row falls back to the conservative skaldjur CONTAINS net; " +
      "add the detail property unless genuinely neither (e.g. jellyfish/sea urchin)"
    );
  }

  // Validate status
  const validStatuses = ["validated", "pending", "deleted"];
  if (row.status && !validStatuses.includes(row.status)) {
    warnings.push(`Unusual status: "${row.status}" (expected: ${validStatuses.join(", ")})`);
  }

  // Validate price format: parseFloat would silently truncate junk like
  // "12 kr" to 12 or "ca 15" to NaN — require a plain number (comma or dot).
  const priceRaw = row.avg_price_sek?.trim();
  if (priceRaw && !/^\d+([.,]\d+)?$/.test(priceRaw)) {
    errors.push(`Invalid avg_price_sek: "${priceRaw}" (expected a plain number, e.g. 12.50 or 12,50)`);
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

    if (result.warnings.length > 0) {
      // Count unconditionally so the summary's "N warnings" hint appears on
      // default runs — previously gated on --verbose, which silently hid
      // safety-relevant warnings (e.g. the seafood-detail check).
      warningCount += result.warnings.length;
      if (verbose) {
        console.log(`\n   ⚠️  ${row.id || "(no id)"} - ${row.swedish || "(no name)"}:`);
        result.warnings.forEach((w) => console.log(`      • ${w}`));
      }
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

/**
 * Writes the per-sync diff report JSON (BUT-1467) for line-by-line review —
 * a Sheet edit must never reach production allergen verdicts invisibly.
 * Written on every run (incl. dry-runs), BEFORE the confirmation prompt, so
 * the operator reviews it before approving.
 */
function writeReportFile(report: SyncReport, options: Options): string | null {
  // No-change runs leave no file — repeated dry-runs while iterating on the
  // Sheet must not pile up all-zero JSON files in the repo.
  const { added, updated, removed } = report.counts;
  if (added === 0 && updated === 0 && removed === 0) {
    return null;
  }
  const reportsDir = path.resolve(__dirname, "../../../docs/tagging/data/sync-reports");
  fs.mkdirSync(reportsDir, { recursive: true });
  const stamp = report.generatedAt.replace(/[:.]/g, "-");
  const suffix = options.dryRun ? "-dryrun" : "";
  const reportPath = path.join(reportsDir, `sync-${stamp}${suffix}.json`);
  fs.writeFileSync(reportPath, JSON.stringify(report, null, 2));
  return reportPath;
}

/**
 * system_events row for the admin ops log. Called only AFTER the final batch
 * commit — the audit trail must never claim a sync that was declined at the
 * prompt or died mid-batch.
 */
async function logSyncEvent(
  report: SyncReport,
  reportPath: string,
  aliasesAtRiskCount: number
): Promise<void> {
  await db.collection("system_events").add({
    type: "ingredient_sync",
    added: report.counts.added,
    updated: report.counts.updated,
    removed: report.counts.removed,
    unchanged: report.counts.unchanged,
    allergenPropertyRemovals: report.allergenPropertyRemovals.length,
    learnedAliasesAtRisk: aliasesAtRiskCount,
    resurrections: report.resurrections.length,
    healed: report.healed.length,
    reportFile: path.basename(reportPath),
    executedAt: admin.firestore.FieldValue.serverTimestamp(),
  });
}

function printReportHighlights(
  report: SyncReport,
  reportPath: string | null,
  aliasesAtRisk: Array<{ id: string; aliases: string[] }>
): void {
  console.log(`\n📄 Diff report: ${reportPath ?? "(no changes — not written)"}`);
  if (report.allergenPropertyRemovals.length > 0) {
    console.log(
      `   🚨 ALLERGEN PROPERTY REMOVALS (${report.allergenPropertyRemovals.length}) — review before trusting verdicts:`
    );
    report.allergenPropertyRemovals.forEach((r) =>
      console.log(`      - ${r.id}: removes ${r.removedProperties.join(", ")}`)
    );
  }
  if (aliasesAtRisk.length > 0) {
    console.log(
      `   ⚠️  Learned aliases at risk (removal or Sheet-side delete) (${aliasesAtRisk.length}):`
    );
    aliasesAtRisk.forEach((r) =>
      console.log(`      - ${r.id}: ${r.aliases.join(", ")}`)
    );
  }
  if (report.resurrections.length > 0) {
    console.log(
      `   ♻️  Resurrected soft-deleted rows (${report.resurrections.length}): ${report.resurrections.join(", ")} (deletedAt/expireAt cleared)`
    );
  }
  if (report.healed.length > 0) {
    console.log(
      `   🩹 Lifecycle repairs (${report.healed.length}): ${report.healed.join(", ")} (stale TTL state fixed)`
    );
  }
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
  const diff = calculateDiff(csvIngredients, currentData);

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

  // Diff report — always produced, so every sync (and dry-run) leaves an
  // auditable trail of what a Sheet edit is about to do to allergen data.
  const report = buildSyncReport(diff, currentData, { dryRun: options.dryRun });
  const aliasesAtRisk = deriveLearnedAliasesAtRisk(report, currentData);
  const reportPath = writeReportFile(report, options);
  printReportHighlights(report, reportPath, aliasesAtRisk);

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

  // Add new ingredients. toAdd ids are by construction absent from
  // currentData (calculateDiff), so `set` here can never clobber an existing
  // doc's learnedAliasesSv — existing docs always go through update() below.
  for (const id of diff.toAdd) {
    batch.set(db.collection("ingredients").doc(id), diff.newData.get(id)!);
    batchCount++;
    if (batchCount >= maxBatchSize) {
      await commitBatch();
    }
  }

  // Update existing ingredients. update() patches only the listed fields, so
  // learnedAliasesSv survives untouched. buildUpdatePayload adds the
  // lifecycle repairs (TTL clears on revive, TTL stamps on Sheet-side
  // soft-delete) and explicit deletes for blanked optional cells.
  for (const id of diff.toUpdate) {
    const payload = buildUpdatePayload(currentData.get(id)!, diff.newData.get(id)!);
    batch.update(
      db.collection("ingredients").doc(id),
      payload as unknown as admin.firestore.UpdateData<admin.firestore.DocumentData>
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

  // Ops-log row only after everything committed (audit must not over-claim).
  await logSyncEvent(report, reportPath ?? "(none)", aliasesAtRisk.length);

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
