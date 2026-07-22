/**
 * Exports ingredient corrections from Firestore to JSON for CRF retraining.
 *
 * Reads the `parse_corrections_v2` collection (per-field, server-side
 * PII-scrubbed by logParseCorrection), keeps only the `ingredients` field
 * corrections, splits each scrubbed `toValue` block back into individual
 * ingredient lines, deduplicates, and outputs JSON.
 *
 * BUT-1471: source switched from `parsing_corrections` (the legacy
 * aggregate-per-recipe schema, whose lines were never PII-scrubbed) to
 * `parse_corrections_v2`. The v2 collection is the append-only, per-field
 * log where the server already ran `scrubPii()` on both values and dropped
 * PII-heavy diffs — so the training targets exported here inherit that
 * scrub for free instead of shipping raw user text into the model.
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
  domain?: string;
  successfulTier?: string;
}

/** Split a scrubbed ingredients-field value into trimmed, non-empty lines. */
function splitLines(value: unknown): string[] {
  if (typeof value !== "string") return [];
  return value
    .split("\n")
    .map((line) => line.trim())
    .filter((line) => line.length > 0);
}

async function main(): Promise<void> {
  // Parse --output flag
  const args = process.argv.slice(2);
  const outputIdx = args.indexOf("--output");
  const outputPath =
    outputIdx >= 0 && args[outputIdx + 1]
      ? path.resolve(args[outputIdx + 1])
      : path.resolve(__dirname, "../../..", "scripts/crf/data/corrections.json");

  console.error("Fetching parse_corrections_v2 from Firestore...");

  const snapshot = await db
    .collection("parse_corrections_v2")
    .where("correctedField", "==", "ingredients")
    .get();
  console.error(`Found ${snapshot.size} ingredient correction documents`);

  const corrections: ExportedCorrection[] = [];
  const seen = new Set<string>();

  let skippedNoLine = 0;
  let skippedDuplicate = 0;
  let totalLines = 0;

  for (const doc of snapshot.docs) {
    const data = doc.data();
    const domain = data.domain as string | undefined;
    const sourceTier = data.sourceTier as string | undefined;

    const correctedLines = splitLines(data.toValue);
    if (correctedLines.length === 0) {
      skippedNoLine++;
      continue;
    }

    for (const correctedLine of correctedLines) {
      totalLines++;

      // Deduplicate by correctedLine (the training target)
      const key = correctedLine.toLowerCase();
      if (seen.has(key)) {
        skippedDuplicate++;
        continue;
      }
      seen.add(key);

      corrections.push({
        // The per-field diff has no reliable line-to-line pairing between
        // fromValue and toValue (edits add/remove lines), and downstream
        // (export_corrections.dart) only trains on correctedLine — so we do
        // not fabricate an originalLine mapping.
        originalLine: correctedLine,
        correctedLine,
        type: "ingredients",
        ...(domain ? { domain } : {}),
        ...(sourceTier ? { successfulTier: sourceTier } : {}),
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
  console.error(`  Ingredient correction docs: ${snapshot.size}`);
  console.error(`  Total lines seen: ${totalLines}`);
  console.error(`  Exported: ${corrections.length}`);
  console.error(`  Skipped (no scrubbed lines): ${skippedNoLine}`);
  console.error(`  Skipped (duplicate): ${skippedDuplicate}`);

  console.error(`\nWritten to: ${outputPath}`);
}

main().catch((e) => {
  console.error("Error:", e);
  process.exit(1);
});
