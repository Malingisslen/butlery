/**
 * Condition C5 (drift guard): the pooled-ratings word-lists exist as native
 * consts in BOTH the TS server authority (functions/src/ratings/canonical-pool-key.ts)
 * and the Dart hint. This suite pins the TS copies IN ORDER to the shared
 * source of truth test/fixtures/pool_key_wordlists.json; the Dart twin
 * (test/unit/services/rating/canonical_pool_key_wordlist_parity_test.dart) pins
 * the Dart copies to the SAME file. A word added to one language but not the
 * JSON — or to the JSON but not both languages — fails one of the two suites in
 * CI, before it can route the client pool badge to a different pool than the
 * server aggregates into (the silent wrong-rating bug C5 prevents).
 *
 * Order matters, not just membership: INGREDIENT_UNITS / APPROXIMATE_WORDS are
 * joined into a regex alternation, so the two languages must agree on order.
 *
 * Run with: npm run test:parity:poolkey-wordlists  (auto-run by `npm test`).
 */

import * as fs from "fs";
import * as path from "path";
import {
  INGREDIENT_UNITS,
  TITLE_STOP_WORDS,
  APPROXIMATE_WORDS,
  DISH_QUALIFIERS,
  GENERIC_ANCHORS,
} from "../ratings/canonical-pool-key";

interface WordLists {
  ingredientUnits: string[];
  titleStopWords: string[];
  approximateWords: string[];
  dishQualifiers: string[];
  genericAnchors: string[];
}

function run(): void {
  console.log("Pool-key word-list parity (condition C5)\n");

  const fixturePath = path.join(
    __dirname,
    "..",
    "..",
    "..",
    "test",
    "fixtures",
    "pool_key_wordlists.json"
  );

  if (!fs.existsSync(fixturePath)) {
    console.error(`ERROR: fixture not found at ${fixturePath}`);
    process.exit(1);
  }

  const shared: WordLists = JSON.parse(fs.readFileSync(fixturePath, "utf-8"));

  // TS consts as ordered arrays (Sets iterate in insertion order).
  const actual: WordLists = {
    ingredientUnits: [...INGREDIENT_UNITS],
    titleStopWords: Array.from(TITLE_STOP_WORDS),
    approximateWords: [...APPROXIMATE_WORDS],
    dishQualifiers: Array.from(DISH_QUALIFIERS),
    genericAnchors: Array.from(GENERIC_ANCHORS),
  };

  const failures: string[] = [];
  let passed = 0;

  // Completeness: pin the SET of lists in the JSON, not only their contents, so
  // editing the JSON's key set (adding/removing/renaming a list there) can't
  // pass silently and a per-list check below can't be quietly dropped. LIMIT: it
  // compares the JSON against `actual`'s hardcoded key set — it does NOT see a
  // sixth list added to the algorithm code but never registered here or in the
  // JSON. That residual is backstopped by the C4 end-to-end parity fixture plus
  // review. `_`-prefixed keys (e.g. _comment) are metadata.
  const expectedKeys = Object.keys(actual).sort();
  const jsonKeys = Object.keys(shared)
    .filter((k) => !k.startsWith("_"))
    .sort();
  if (
    expectedKeys.length !== jsonKeys.length ||
    !expectedKeys.every((k, i) => k === jsonKeys[i])
  ) {
    failures.push(
      `  completeness: the JSON's lists ${JSON.stringify(jsonKeys)} do not ` +
        `match the pinned set ${JSON.stringify(expectedKeys)}`
    );
  }

  (Object.keys(actual) as (keyof WordLists)[]).forEach((key) => {
    const a = actual[key];
    const b = shared[key];
    if (!b) {
      failures.push(`  ${key}: missing from the shared JSON`);
      return;
    }
    const equal = a.length === b.length && a.every((w, i) => w === b[i]);
    if (equal) {
      passed++;
    } else {
      failures.push(
        `  ${key}: TS const does not match the shared JSON (in order)\n` +
          `      TS  : ${JSON.stringify(a)}\n` +
          `      JSON: ${JSON.stringify(b)}`
      );
    }
  });

  console.log(`Results: ${passed}/${Object.keys(actual).length} lists match\n`);

  if (failures.length > 0) {
    console.error("FAILURES (TS word-list does not match the shared JSON):");
    failures.forEach((f) => console.error(f));
    console.error(
      "\nCRITICAL: TS word-lists drifted from the source of truth. Reconcile " +
        "functions/src/ratings/canonical-pool-key.ts, the Dart twins, and " +
        "test/fixtures/pool_key_wordlists.json so all three agree.\n"
    );
    process.exit(1);
  }

  console.log("All pool-key word-lists match the shared JSON — no drift.\n");
}

run();
