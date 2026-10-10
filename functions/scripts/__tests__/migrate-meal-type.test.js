/**
 * BUT-1875: tests for the meal-type migration.
 *
 * Plain Node + node:assert, run by `npm run test:script-meal-type-migration`,
 * which run-ci-unit-tests.js discovers.
 */

const assert = require("assert");
const fs = require("fs");
const path = require("path");
const {
  CANONICAL,
  SYNONYMS,
  classify,
  isUserRecipePath,
  runMigration,
  report,
} = require("../migrate-meal-type.js");

const results = [];
async function test(name, fn) {
  try {
    await fn();
    results.push({ name, ok: true });
  } catch (err) {
    results.push({ name, ok: false, err });
  }
}

function recipe(id, mealType, { hasCore = true, uid = "u1" } = {}) {
  return {
    path: `users/${uid}/recipes/${id}`,
    hasCore,
    mealType,
    ref: id,
    updateTime: `t-${id}`,
  };
}

function fakeDeps(docs, outcomes = {}) {
  const writes = [];
  return {
    writes,
    async *recipes() {
      for (const d of docs) yield d;
    },
    write: async (ref, mealType, updateTime) => {
      writes.push({ ref, mealType, updateTime });
      return outcomes[ref] || "ok";
    },
  };
}

// Like BulkWriter: a write settles only once the writer is flushed.
function batchingDeps(docs) {
  const pending = [];
  return {
    async *recipes() {
      for (const d of docs) yield d;
    },
    write: () => new Promise((resolve) => pending.push(() => resolve("ok"))),
    flush: async () => {
      for (const settle of pending.splice(0)) settle();
    },
  };
}

async function main() {
  await test("writes that settle only on flush are flushed, not awaited forever", async () => {
    const deps = batchingDeps([recipe("a", "dinner"), recipe("b", "lunch")]);
    const counts = await Promise.race([
      runMigration(deps, { apply: true }),
      new Promise((_, reject) => setTimeout(() => reject(new Error("hung")), 1000)),
    ]);
    assert.strictEqual(counts.written, 2);
  });

  await test("exact canonical values are kept; case and spacing variants are rewrites", () => {
    assert.deepStrictEqual(classify(recipe("a", "Middag")), { outcome: "canonical", value: "Middag" });
    assert.deepStrictEqual(classify(recipe("a", "middag")), { outcome: "rewrite", from: "middag", to: "Middag" });
    assert.deepStrictEqual(classify(recipe("a", "Middag ")), { outcome: "rewrite", from: "middag", to: "Middag" });
    assert.deepStrictEqual(classify(recipe("a", "Main  Course")), { outcome: "rewrite", from: "main course", to: "Middag" });
  });

  await test("free text, no value and flat recipes are never rewritten", () => {
    assert.strictEqual(classify(recipe("a", "Soppor")).outcome, "other");
    assert.strictEqual(classify(recipe("a", undefined)).outcome, "missing");
    assert.strictEqual(classify(recipe("a", "")).outcome, "missing");
    assert.strictEqual(classify(recipe("a", "dinner", { hasCore: false })).outcome, "flat");
  });

  await test("only users/{uid}/recipes/{id} is a user recipe", () => {
    assert.ok(isUserRecipePath("users/u/recipes/r"));
    assert.ok(!isUserRecipePath("groups/g/recipes/r"));
    assert.ok(!isUserRecipePath("users/u/recipes/r/versions/v"));
  });

  await test("a dry run counts and writes nothing", async () => {
    const deps = fakeDeps([recipe("a", "dinner"), recipe("b", "Middag"), recipe("c", "Soppor")]);
    const counts = await runMigration(deps, { apply: false });
    assert.strictEqual(deps.writes.length, 0);
    assert.strictEqual(counts.total, 3);
    assert.deepStrictEqual(counts.rewrite, { "dinner → Middag": 1 });
    assert.strictEqual(counts.canonical.Middag, 1);
    assert.strictEqual(counts.other, 1);
  });

  await test("apply writes only synonyms, preconditioned on the read update time", async () => {
    const deps = fakeDeps([
      recipe("a", "dinner"),
      recipe("b", "Middag"),
      recipe("c", "Soppor"),
      recipe("d", "lunch", { hasCore: false }),
      { ...recipe("e", "dinner"), path: "groups/g/recipes/e" },
    ]);
    const counts = await runMigration(deps, { apply: true });
    assert.deepStrictEqual(deps.writes, [{ ref: "a", mealType: "Middag", updateTime: "t-a" }]);
    assert.strictEqual(counts.written, 1);
    assert.strictEqual(counts.flat, 1);
    assert.strictEqual(counts.notUserRecipe, 1);
  });

  await test("an edit made meanwhile and a failed write are counted apart", async () => {
    const deps = fakeDeps(
      [recipe("a", "dinner"), recipe("b", "breakfast"), recipe("c", "snack")],
      { a: "changed", b: "failed" },
    );
    const counts = await runMigration(deps, { apply: true });
    assert.strictEqual(counts.written, 1);
    assert.strictEqual(counts.changedMeanwhile, 1);
    assert.strictEqual(counts.failed, 1);
  });

  await test("the report names no recipe, uid or free text", async () => {
    const deps = fakeDeps([recipe("secret-id", "Mormors special", { uid: "secret-uid" })]);
    const text = report(await runMigration(deps, { apply: true }), true);
    assert.ok(!/secret|Mormors/.test(text), text);
  });

  await test("the synonym table matches MealTypes in the app", () => {
    const dart = fs.readFileSync(
      path.join(__dirname, "../../../lib/models/recipe/meal_types.dart"),
      "utf8",
    );
    const consts = Object.fromEntries(
      [...dart.matchAll(/static const (\w+) = '([^']+)';/g)].map((m) => [m[1], m[2]]),
    );
    const block = dart.slice(dart.indexOf("_synonyms = {"), dart.indexOf("};", dart.indexOf("_synonyms = {")));
    const dartSynonyms = Object.fromEntries(
      [...block.matchAll(/'([^']+)': (\w+),/g)].map((m) => [m[1], consts[m[2]]]),
    );
    assert.ok(Object.keys(dartSynonyms).length > 10, "parsed too few Dart synonyms");
    assert.deepStrictEqual(SYNONYMS, dartSynonyms);
    const all = dart.slice(dart.indexOf("List<String> all = ["), dart.indexOf("];", dart.indexOf("List<String> all = [")));
    assert.deepStrictEqual(CANONICAL, [...all.matchAll(/(\w+),/g)].map((m) => consts[m[1]]));
  });

  let failed = 0;
  for (const r of results) {
    if (r.ok) console.log(`  PASS  ${r.name}`);
    else {
      failed++;
      console.log(`  FAIL  ${r.name}\n        ${r.err && r.err.message}`);
    }
  }
  console.log(`\n${results.length - failed}/${results.length} passed`);
  if (failed > 0) process.exit(1);
}

main();
