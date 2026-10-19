/**
 * BUT-2415: every share the app makes lives in `shared_content`. The old
 * per-type collections have no rules block and no writer, so a function that
 * reads one gets nothing and throws nothing.
 *
 * 1. No production code under functions/src names an old share collection,
 *    except the reset tool, which lists legacy names so a reset clears them.
 * 2. The metadata cleanup's collection-group queries on `timestamp` have their
 *    COLLECTION_GROUP index; without it the weekly run throws. Its own time
 *    guard fires before the function's timeout does.
 *
 * Run with: npx ts-node src/__tests__/dead-share-collections.test.ts
 */

import * as fs from "fs";
import * as path from "path";
// eslint-disable-next-line @typescript-eslint/no-require-imports
const cleanup = require("../cleanup/cleanup-shared-content-metadata");

const SRC = path.join(__dirname, "..");
const INDEXES_PATH = path.join(SRC, "..", "..", "firestore.indexes.json");
const DEAD = ["shared_recipes", "shared_menus", "shared_shopping_lists"];
const ALLOWED = new Set([path.join("admin", "reset-collection-lists.ts")]);

let failed = 0;
let total = 0;
function record(name: string, ok: boolean, detail = ""): void {
  total++;
  if (!ok) failed++;
  console.log(`  ${ok ? "PASS" : "FAIL"}  ${name}${ok || !detail ? "" : ` — ${detail}`}`);
}

function productionFiles(dir: string): string[] {
  const out: string[] = [];
  for (const entry of fs.readdirSync(dir, { withFileTypes: true })) {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== "__tests__") out.push(...productionFiles(full));
    } else if (entry.name.endsWith(".ts")) {
      out.push(full);
    }
  }
  return out;
}

function noReaderOfADeadCollection(): void {
  const hits: string[] = [];
  for (const file of productionFiles(SRC)) {
    const rel = path.relative(SRC, file);
    if (ALLOWED.has(rel)) continue;
    // Comments may name a dead collection to say why it is not read.
    const text = fs
      .readFileSync(file, "utf8")
      .replace(/\/\*[\s\S]*?\*\//g, "")
      .replace(/(^|[^:])\/\/.*$/gm, (_m, keep: string) => keep);
    for (const name of DEAD) {
      if (new RegExp(`["'\`]${name}["'\`/]`).test(text)) hits.push(`${rel}: ${name}`);
    }
  }
  record(
    "no function names shared_recipes, shared_menus or shared_shopping_lists",
    hits.length === 0,
    hits.join("; "),
  );
}

function cleanupHasItsCollectionGroupIndex(): void {
  const overrides = JSON.parse(fs.readFileSync(INDEXES_PATH, "utf8"))
    .fieldOverrides as Array<{
    collectionGroup: string;
    fieldPath: string;
    indexes: Array<{ order?: string; queryScope: string }>;
  }>;
  for (const group of ["views", "engagements", "dismissals"]) {
    const ok = overrides.some(
      (o) =>
        o.collectionGroup === group &&
        o.fieldPath === "timestamp" &&
        o.indexes.some(
          (i) => i.queryScope === "COLLECTION_GROUP" && i.order === "ASCENDING",
        ),
    );
    record(`${group}.timestamp has an ascending COLLECTION_GROUP index`, ok);
  }
}

function cleanupStopsBeforeItsTimeout(): void {
  const timeoutSeconds = cleanup.cleanupSharedContentMetadata.__endpoint?.timeoutSeconds;
  record(
    "the cleanup's time guard is shorter than its function timeout",
    typeof timeoutSeconds === "number" &&
      timeoutSeconds * 1000 > cleanup.MAX_EXECUTION_TIME_MS,
    `timeoutSeconds=${String(timeoutSeconds)}`,
  );
}

noReaderOfADeadCollection();
cleanupHasItsCollectionGroupIndex();
cleanupStopsBeforeItsTimeout();
console.log(`\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : ""));
if (failed > 0) process.exit(1);
