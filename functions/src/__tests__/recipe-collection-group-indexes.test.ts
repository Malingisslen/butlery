/**
 * BUT-1781 — the COLLECTION_GROUP indexes the recipe cascades depend on.
 *
 * Recipes live ONLY at `users/{uid}/recipes/{recipeId}`. Four server-side
 * readers were querying a top-level `recipes` collection that has never
 * existed; they matched zero documents and reported "none found", which is a
 * legitimate-looking answer, so the ingredient cascades sat dead for months.
 * The fix repoints all four at `collectionGroup("recipes")`.
 *
 * That repoint is only half a fix. Firestore's AUTOMATIC single-field indexes
 * are COLLECTION-scoped; a collection-group query filtered on a field needs a
 * single-field index with COLLECTION_GROUP scope, declared as a fieldOverride
 * in `firestore.indexes.json`. Without it every ingredient edit fails with
 * FAILED_PRECONDITION — i.e. the cascade would go from silently-dead to
 * loudly-broken, on the allergen path.
 *
 * WHAT THIS SUITE PROVES: the override is DECLARED in the file that gets
 * deployed, and the querying source still filters on that exact field path at
 * collection-group scope. It does NOT prove the index is BUILT in a project —
 * that is `firebase deploy --only firestore:indexes` plus a human checking
 * `gcloud firestore indexes fields list`. A green run here is not "the cascade
 * works"; it is "a deploy would create what the cascade needs".
 *
 * THE PAIRING IS THE POINT. Either half can rot alone and nothing else notices:
 * drop the override (a `--force` deploy prunes anything absent from this file)
 * and the query 500s; rename the field on the query side and the index goes
 * inert while the query silently matches nothing again — the exact disease
 * BUT-1781 was. Both directions redden here.
 *
 * Run: `npm run test:recipe-collection-group-indexes` (from functions/).
 */

import * as fs from "fs";
import * as path from "path";

const REPO_ROOT = path.resolve(__dirname, "..", "..", "..");
const INDEXES_PATH = path.resolve(REPO_ROOT, "firestore.indexes.json");

interface FieldOverride {
  collectionGroup: string;
  fieldPath: string;
  ttl?: boolean;
  indexes?: { order?: string; arrayConfig?: string; queryScope?: string }[];
}

const results: { name: string; passed: boolean; reason?: string }[] = [];

function record(name: string, passed: boolean, reason?: string): void {
  results.push({ name, passed, reason });
}

function loadOverrides(): FieldOverride[] {
  const parsed = JSON.parse(fs.readFileSync(INDEXES_PATH, "utf8"));
  if (!Array.isArray(parsed.fieldOverrides)) {
    throw new Error("firestore.indexes.json has no `fieldOverrides` array");
  }
  return parsed.fieldOverrides as FieldOverride[];
}

function readSource(relative: string): string {
  const full = path.resolve(REPO_ROOT, relative);
  return fs.existsSync(full) ? fs.readFileSync(full, "utf8") : "";
}

/**
 * Every field path a `collectionGroup("recipes")` query filters on, and who
 * filters on it. `scope` is the index configuration that query needs:
 * `array-contains` needs `arrayConfig: CONTAINS`, an equality needs an
 * `order: ASCENDING` entry (which also serves the implicit `__name__` ordering
 * that `startAfter` pagination relies on).
 */
const REQUIRED: {
  fieldPath: string;
  arrayConfig?: string;
  order?: string;
  queriers: string[];
}[] = [
  {
    fieldPath: "core.ingredientsNormalized",
    arrayConfig: "CONTAINS",
    queriers: [
      "functions/src/ingredients/on-ingredient-soft-deleted.ts",
      "functions/src/ingredients/on-ingredient-properties-changed.ts",
    ],
  },
  {
    fieldPath: "core.tagResult.generatorVersion",
    order: "ASCENDING",
    queriers: ["functions/src/cleanup/cleanup-deleted-ingredients.ts"],
  },
  {
    fieldPath: "core.createdBy",
    order: "ASCENDING",
    queriers: ["functions/src/admin/bulk-retag.ts"],
  },
];

/**
 * The exact set, not just "each of mine is present". A count/subset check stays
 * green when an edit deletes one override and adds another; since the paths are
 * named anyway, pinning the set costs nothing and catches the swap. Adding a
 * fourth recipes-scoped override is a deliberate act — extend REQUIRED in the
 * same edit.
 */
const EXPECTED_RECIPE_FIELD_PATHS = REQUIRED.map((r) => r.fieldPath).sort();

function indexesDeclared(): void {
  const overrides = loadOverrides();
  const recipeOverrides = overrides.filter(
    (o) => o.collectionGroup === "recipes",
  );

  for (const req of REQUIRED) {
    const match = recipeOverrides.find((o) => o.fieldPath === req.fieldPath);
    const groupScoped = (match?.indexes ?? []).find(
      (i) =>
        i.queryScope === "COLLECTION_GROUP" &&
        (req.arrayConfig
          ? i.arrayConfig === req.arrayConfig
          : i.order === req.order),
    );

    record(
      `recipes/${req.fieldPath} has a COLLECTION_GROUP index (queried by ${req.queriers
        .map((q) => path.basename(q))
        .join(", ")})`,
      groupScoped !== undefined,
      match === undefined
        ? `no fieldOverride for recipes/${req.fieldPath} — automatic single-field indexes are COLLECTION-scoped only, so the collection-group query fails with FAILED_PRECONDITION on every invocation`
        : `fieldOverride exists but declares no ${
            req.arrayConfig
              ? `arrayConfig ${req.arrayConfig}`
              : `order ${req.order}`
          } entry at COLLECTION_GROUP scope: ${JSON.stringify(match.indexes)}`,
    );
  }

  const declared = recipeOverrides.map((o) => o.fieldPath).sort();
  const missing = EXPECTED_RECIPE_FIELD_PATHS.filter(
    (f) => !declared.includes(f),
  );
  const unexpected = declared.filter(
    (f) => !EXPECTED_RECIPE_FIELD_PATHS.includes(f),
  );

  record(
    `exactly these ${EXPECTED_RECIPE_FIELD_PATHS.length} recipes field paths are overridden (the --force-deploy tripwire)`,
    missing.length === 0 && unexpected.length === 0,
    [
      missing.length > 0
        ? `MISSING: ${missing.join(", ")} — a deploy would drop the index its cascade needs. That is the bug, not this test.`
        : "",
      unexpected.length > 0
        ? `NOT IN THE LIST: ${unexpected.join(", ")} — if you added an override deliberately, add it to REQUIRED in the same edit so its querier is pinned too.`
        : "",
    ]
      .filter(Boolean)
      .join(" | "),
  );
}

/**
 * The index is only worth declaring if the query still asks for that field at
 * collection-group scope.
 *
 * Anchored on the CALL shape, never on a bare `src.includes(fieldPath)` — every
 * one of these files names its field paths in prose too (the BUT-1699 TTL suite
 * proved that exact check vacuous by mutation, 5/5 green after renaming the
 * written key). `.where("core.x"` cannot be satisfied by a docstring.
 */
function queriersStillMatch(): void {
  for (const req of REQUIRED) {
    for (const querier of req.queriers) {
      const src = readSource(querier);
      const filtersField = new RegExp(
        `\\.where\\(\\s*"${req.fieldPath.replace(/\./g, "\\.")}"`,
      ).test(src);
      const groupScoped = /collectionGroup\(/.test(src);

      record(
        `${path.basename(querier)} filters on ${req.fieldPath} via a collection group`,
        src !== "" && filtersField && groupScoped,
        src === ""
          ? `source not found at ${querier} — the file moved, so the declared index may now serve nothing`
          : !filtersField
            ? `no \`.where("${req.fieldPath}"\` found — if the field was renamed, the declared index is inert and the query matches zero documents SILENTLY, which is BUT-1781 all over again`
            : "no `collectionGroup(` call — a collection-scoped read of `recipes` matches nothing; recipes live only at users/{uid}/recipes",
      );

      // The original defect, spelled as a regression guard: a top-level
      // `recipes` collection has never existed in this project.
      record(
        `${path.basename(querier)} never reads a top-level \`recipes\` collection`,
        !/\.collection\(\s*("recipes"|Collections\.recipes)\s*\)/.test(src),
        "found `.collection(\"recipes\")` — that collection does not exist; it returns zero documents and no error, which is how this cascade stayed dead for months (BUT-1781)",
      );
    }
  }
}

/**
 * BUT-1794. The cascade above matched nothing for any ingredient containing
 * å/ä/ö, because the query stripped diacritics while the Dart producer does
 * not. 8 of the 14 EU allergens have those letters in their Swedish names, so
 * this is an allergen-safety property, not a spelling nicety.
 *
 * Behavioural, not source-pattern: the helper is the thing that has to be
 * right, and these assertions go red if it is ever narrowed back to one form.
 */
function bothSpellingsAreQueried(): void {
  // eslint-disable-next-line @typescript-eslint/no-require-imports
  const { ingredientMatchVariants } = require("../shared/swedish-normalize");

  // The 8 EU allergens whose Swedish names carry å/ä/ö, plus a control.
  for (const [name, stripped] of [
    ["mjölk", "mjolk"],
    ["ägg", "agg"],
    ["nötter", "notter"],
    ["mandel", "mandel"],
  ] as const) {
    const variants: string[] = ingredientMatchVariants(name);
    record(
      `"${name}" is matched under its own spelling`,
      variants.includes(name),
      `got ${JSON.stringify(variants)}`,
    );
    record(
      `"${name}" is ALSO matched under the stripped spelling "${stripped}"`,
      variants.includes(stripped),
      `got ${JSON.stringify(variants)} — the retired backfill wrote the stripped form, so half the corpus would be missed`,
    );
  }

  record(
    "a name with no diacritics yields exactly one variant, not a duplicate pair",
    ingredientMatchVariants("mandel").length === 1,
    `got ${JSON.stringify(ingredientMatchVariants("mandel"))} — array-contains-any would waste an operand slot`,
  );
  record(
    "uppercase input is folded before matching",
    ingredientMatchVariants("MJÖLK").includes("mjölk") &&
      ingredientMatchVariants("MJÖLK").includes("mjolk"),
    `got ${JSON.stringify(ingredientMatchVariants("MJÖLK"))}`,
  );

  // Both cascades must actually USE it — a correct helper nothing calls is the
  // shape this bug already took once.
  for (const querier of [
    "src/ingredients/on-ingredient-soft-deleted.ts",
    "src/ingredients/on-ingredient-properties-changed.ts",
  ]) {
    const src = fs.readFileSync(
      path.join(REPO_ROOT, "functions", querier),
      "utf8",
    );
    record(
      `${path.basename(querier)} queries with array-contains-any over the variants`,
      /"array-contains-any"[\s\S]{0,40}ingredientNameVariants/.test(src),
      "the union query is the fix; a bare array-contains matches half the corpus",
    );
    record(
      `${path.basename(querier)} no longer claims ingredientsNormalized is diacritic-stripped`,
      !/ingredientsNormalized stores Swedish-normalized names/.test(src),
      "that comment was false and is what made the bug look intentional",
    );
  }
}

function main(): void {
  indexesDeclared();
  queriersStillMatch();
  bothSpellingsAreQueried();

  let failed = 0;
  for (const r of results) {
    if (r.passed) {
      console.log(`  PASS  ${r.name}`);
    } else {
      failed += 1;
      console.log(`  FAIL  ${r.name}`);
      if (r.reason) console.log(`        ${r.reason}`);
    }
  }
  console.log(
    `\nBUT-1781 recipe collection-group indexes: ${results.length - failed}/${results.length} passing.`,
  );
  if (failed > 0) process.exit(1);
}

main();
