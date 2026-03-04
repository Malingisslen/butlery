/**
 * Exports ingredient corrections from Firestore to JSON for CRF retraining.
 *
 * Reads parsing_corrections collection, extracts ingredient corrections with
 * correctedLine data, deduplicates by originalLine, and outputs JSON.
 *
 * Prerequisites:
 *   1. Login: firebase login
 *
 * Usage:
 *   cd functions
 *   npx ts-node src/admin/export-corrections.ts [--output path/to/output.json]
 *
 * Default output: ../scripts/crf/data/corrections.json
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

import { initializeAdminApp } from "./admin-init";

initializeAdminApp();

const db = admin.firestore();

interface ExportedCorrection {
  originalLine: string;
  correctedLine: string;
  type: string;
  quantityChanged: boolean;
  unitChanged: boolean;
  nameChanged: boolean;
  originalName?: string;
  correctedName?: string;
  domain?: string;
  successfulTier?: string;
}

async function main(): Promise<void> {
  // Parse --output flag
  const args = process.argv.slice(2);
  const outputIdx = args.indexOf("--output");
  const outputPath =
    outputIdx >= 0 && args[outputIdx + 1]
      ? path.resolve(args[outputIdx + 1])
      : path.resolve(__dirname, "../../..", "scripts/crf/data/corrections.json");

  console.error("Fetching parsing corrections from Firestore...");

  const snapshot = await db.collection("parsing_corrections").get();
  console.error(`Found ${snapshot.size} correction documents`);

  const corrections: ExportedCorrection[] = [];
  const seen = new Set<string>();

  let skippedNoLine = 0;
  let skippedReordered = 0;
  let skippedDuplicate = 0;
  let totalIngredientCorrections = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const domain = data.domain as string | undefined;
    const successfulTier = data.successfulTier as string | undefined;
    const ingredientCorrections =
      (data.ingredientCorrections as Array<Record<string, unknown>>) || [];

    for (const ic of ingredientCorrections) {
      totalIngredientCorrections++;

      // Skip reordered — no training value
      if (ic.type === "reordered") {
        skippedReordered++;
        continue;
      }

      const correctedLine = ic.correctedLine as string | undefined;
      if (!correctedLine) {
        skippedNoLine++;
        continue;
      }

      // Deduplicate by correctedLine (the training target)
      const key = correctedLine.toLowerCase().trim();
      if (seen.has(key)) {
        skippedDuplicate++;
        continue;
      }
      seen.add(key);

      corrections.push({
        originalLine: (ic.originalLine as string) || correctedLine,
        correctedLine,
        type: ic.type as string,
        quantityChanged: (ic.quantityChanged as boolean) || false,
        unitChanged: (ic.unitChanged as boolean) || false,
        nameChanged: (ic.nameChanged as boolean) || false,
        ...(ic.originalName ? { originalName: ic.originalName as string } : {}),
        ...(ic.correctedName
          ? { correctedName: ic.correctedName as string }
          : {}),
        ...(domain ? { domain } : {}),
        ...(successfulTier ? { successfulTier } : {}),
      });
    }
  }

  // Sort for deterministic output
  corrections.sort((a, b) =>
    a.correctedLine.localeCompare(b.correctedLine, "sv")
  );

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(corrections, null, 2) + "\n");

  console.error(`\nExport summary:`);
  console.error(`  Total correction docs: ${snapshot.size}`);
  console.error(
    `  Total ingredient corrections: ${totalIngredientCorrections}`
  );
  console.error(`  Exported: ${corrections.length}`);
  console.error(`  Skipped (reordered): ${skippedReordered}`);
  console.error(`  Skipped (no correctedLine): ${skippedNoLine}`);
  console.error(`  Skipped (duplicate): ${skippedDuplicate}`);

  // Type breakdown
  const typeCounts = new Map<string, number>();
  for (const c of corrections) {
    typeCounts.set(c.type, (typeCounts.get(c.type) || 0) + 1);
  }
  console.error(`  By type:`);
  for (const [type, count] of [...typeCounts.entries()].sort()) {
    console.error(`    ${type}: ${count}`);
  }

  console.error(`\nWritten to: ${outputPath}`);
}

main().catch((e) => {
  console.error("Error:", e);
  process.exit(1);
});
