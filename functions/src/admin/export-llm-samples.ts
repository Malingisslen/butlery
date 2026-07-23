/**
 * Exports captured paid-LLM call samples from Firestore to JSON for offline
 * mining (improving the deterministic parser and the prompts).
 *
 * BUT-1472: `llm_response_samples` (written best-effort by
 * `functions/src/llm/llm-sample-capture.ts`, BUT-1451) had no consumer, so the
 * paid-LLM calls we already pay for were reaped by the 30-day Firestore TTL
 * before anyone could mine them. This script is that consumer — it mirrors the
 * `export-corrections.ts` pattern: read the collection, project the
 * mining-useful fields, deterministically sort, and write JSON.
 *
 * Privacy posture: everything persisted in `llm_response_samples` is already
 * scrubbed at write time (`scrubbedInput` scrubbed upstream, `scrubbedOutput`
 * re-scrubbed by the capture writer) and `authUidHash` is a one-way hash, never
 * a raw uid — so this export inherits that scrub and stores no new PII surface.
 *
 * Prerequisites:
 *   1. Login: firebase login
 *
 * Usage:
 *   cd functions
 *   npx ts-node src/admin/export-llm-samples.ts [--mode extract] [--output path/to/output.json]
 *
 * --mode narrows to a single call type ('extract' | 'enhance' | 'spoken' |
 *        'ingredientLines' | 'ocr'); omitted exports every mode.
 *
 * Default output: ../scripts/llm-samples/data/llm_response_samples.json
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

import { initializeAdminApp } from "./admin-init";

initializeAdminApp();

const db = admin.firestore();

interface ExportedSample {
  id: string;
  mode: string;
  inputKind: string;
  scrubbedInput: string | null;
  scrubbedInputLength: number | null;
  scrubbedOutput: string | null;
  outputLength: number | null;
  promptVersion: string | null;
  promptSource: string | null;
  experimentBucket: number | null;
  promptVariant: string | null;
  domain: string | null;
  authUidHash: string | null;
  modelId: string | null;
  promptTokenCount: number | null;
  candidatesTokenCount: number | null;
  createdAt: string | null;
}

/** Firestore Timestamp → ISO string; null when absent or unrecognised. */
function toIso(value: unknown): string | null {
  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }
  return null;
}

/** Coalesce a possibly-undefined Firestore field to null (JSON-friendly). */
function orNull<T>(v: T | undefined): T | null {
  return v === undefined ? null : v;
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);

  const outputIdx = args.indexOf("--output");
  const outputPath =
    outputIdx >= 0 && args[outputIdx + 1]
      ? path.resolve(args[outputIdx + 1])
      : path.resolve(
          __dirname,
          "../../..",
          "scripts/llm-samples/data/llm_response_samples.json"
        );

  const modeIdx = args.indexOf("--mode");
  const modeFilter =
    modeIdx >= 0 && args[modeIdx + 1] ? args[modeIdx + 1] : undefined;

  console.error(
    modeFilter
      ? `Fetching llm_response_samples (mode == ${modeFilter}) from Firestore...`
      : "Fetching llm_response_samples from Firestore..."
  );

  // Equality-only filter — no composite index needed (auto single-field index).
  const query = modeFilter
    ? db.collection("llm_response_samples").where("mode", "==", modeFilter)
    : db.collection("llm_response_samples");
  const snapshot = await query.get();
  console.error(`Found ${snapshot.size} sample documents`);

  const samples: ExportedSample[] = [];

  for (const doc of snapshot.docs) {
    const data = doc.data();
    samples.push({
      id: doc.id,
      mode: (data.mode as string | undefined) ?? "",
      inputKind: (data.inputKind as string | undefined) ?? "",
      scrubbedInput: orNull(data.scrubbedInput as string | undefined),
      scrubbedInputLength: orNull(
        data.scrubbedInputLength as number | undefined
      ),
      scrubbedOutput: orNull(data.scrubbedOutput as string | undefined),
      outputLength: orNull(data.outputLength as number | undefined),
      promptVersion: orNull(data.promptVersion as string | undefined),
      promptSource: orNull(data.promptSource as string | undefined),
      experimentBucket: orNull(data.experimentBucket as number | undefined),
      promptVariant: orNull(data.promptVariant as string | undefined),
      domain: orNull(data.domain as string | undefined),
      authUidHash: orNull(data.authUidHash as string | undefined),
      modelId: orNull(data.modelId as string | undefined),
      promptTokenCount: orNull(data.promptTokenCount as number | undefined),
      candidatesTokenCount: orNull(
        data.candidatesTokenCount as number | undefined
      ),
      createdAt: toIso(data.createdAt),
    });
  }

  // Sort oldest-first for deterministic output (null createdAt sorts last).
  samples.sort((a, b) => {
    if (a.createdAt === b.createdAt) return a.id.localeCompare(b.id);
    if (a.createdAt === null) return 1;
    if (b.createdAt === null) return -1;
    return a.createdAt.localeCompare(b.createdAt);
  });

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, JSON.stringify(samples, null, 2) + "\n");

  const byMode = new Map<string, number>();
  for (const s of samples) {
    byMode.set(s.mode || "unknown", (byMode.get(s.mode || "unknown") || 0) + 1);
  }

  console.error(`\nExport summary:`);
  console.error(`  Sample docs: ${snapshot.size}`);
  console.error(`  Exported: ${samples.length}`);
  console.error("  By mode:");
  for (const [mode, count] of [...byMode.entries()].sort()) {
    console.error(`    ${mode}: ${count}`);
  }

  console.error(`\nWritten to: ${outputPath}`);
}

main().catch((e) => {
  console.error("Error:", e);
  process.exit(1);
});
