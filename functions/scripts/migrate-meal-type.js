/**
 * BUT-1875 one-time migration: store every recipe's meal type in the app's
 * spelling ("dinner" → "Middag"), so the one vocabulary in
 * lib/models/recipe/meal_types.dart holds for stored data too.
 *
 * Reads `users/{uid}/recipes/{id}` and rewrites `core.mealType` only, and only
 * for a known synonym. Free text ("Soppor") is left alone and counted. A legacy
 * flat recipe (no `core`) is counted and never written: updating
 * `core.mealType` on it would create a `core` that hides the rest of the
 * recipe. Each write is preconditioned on the document's update time, so an
 * edit made while the script runs is skipped and counted, not overwritten.
 * `updatedAt` and `rev` are not touched.
 *
 * Prints counts only, never a uid, a recipe id or free text. Dry run unless
 * `--apply`. Idempotent: a rerun finds nothing left to rewrite unless an older
 * app has written a synonym back since.
 *
 * Usage (from functions/):
 *   GOOGLE_APPLICATION_CREDENTIALS=<service-account.json> \
 *     node scripts/migrate-meal-type.js [--apply]
 */

const CANONICAL = ["Frukost", "Lunch", "Middag", "Dessert", "Mellanmål", "Fika"];

// Mirrors MealTypes._synonyms in lib/models/recipe/meal_types.dart.
const SYNONYMS = {
  frukost: "Frukost",
  breakfast: "Frukost",
  lunch: "Lunch",
  middag: "Middag",
  dinner: "Middag",
  "huvudrätt": "Middag",
  "huvudrätter": "Middag",
  "main course": "Middag",
  "main dish": "Middag",
  dessert: "Dessert",
  desserts: "Dessert",
  desserter: "Dessert",
  "efterrätt": "Dessert",
  "efterrätter": "Dessert",
  "mellanmål": "Mellanmål",
  mellanmal: "Mellanmål",
  snack: "Mellanmål",
  snacks: "Mellanmål",
  fika: "Fika",
};

function synonymKey(value) {
  return value.trim().replace(/\s+/g, " ").toLowerCase();
}

/**
 * Decides one recipe from what its document holds. Exact bytes decide
 * "canonical": "middag" and "Middag " are rewrites.
 */
function classify(doc) {
  if (!doc.hasCore) return { outcome: "flat" };
  const value = doc.mealType;
  if (typeof value !== "string" || value === "") return { outcome: "missing" };
  if (CANONICAL.includes(value)) return { outcome: "canonical", value };
  const key = synonymKey(value);
  const to = SYNONYMS[key];
  if (to) return { outcome: "rewrite", from: key, to };
  return { outcome: "other" };
}

/** True for `users/{uid}/recipes/{id}` and nothing else named `recipes`. */
function isUserRecipePath(path) {
  const parts = path.split("/");
  return parts.length === 4 && parts[0] === "users" && parts[2] === "recipes";
}

/**
 * `deps.recipes()` yields `{ path, hasCore, mealType, ref, updateTime }`;
 * `deps.write(ref, mealType, updateTime)` resolves to "ok", "changed" (the
 * document was edited since it was read) or "failed".
 */
async function runMigration(deps, { apply }) {
  const counts = {
    total: 0,
    canonical: Object.fromEntries(CANONICAL.map((c) => [c, 0])),
    rewrite: {},
    other: 0,
    missing: 0,
    flat: 0,
    notUserRecipe: 0,
    written: 0,
    changedMeanwhile: 0,
    failed: 0,
  };
  const writes = [];
  for await (const doc of deps.recipes()) {
    if (!isUserRecipePath(doc.path)) {
      counts.notUserRecipe++;
      continue;
    }
    counts.total++;
    const result = classify(doc);
    switch (result.outcome) {
      case "canonical":
        counts.canonical[result.value]++;
        break;
      case "rewrite": {
        const label = `${result.from} → ${result.to}`;
        counts.rewrite[label] = (counts.rewrite[label] || 0) + 1;
        if (apply) {
          writes.push(
            deps.write(doc.ref, result.to, doc.updateTime).then((r) => {
              if (r === "ok") counts.written++;
              else if (r === "changed") counts.changedMeanwhile++;
              else counts.failed++;
            }),
          );
        }
        break;
      }
      default:
        counts[result.outcome]++;
    }
  }
  // BulkWriter sends a partial batch only when flushed, so the flush has to
  // start before its writes are awaited.
  const flushed = deps.flush ? deps.flush() : undefined;
  await Promise.all(writes);
  await flushed;
  return counts;
}

function firestoreDeps(admin) {
  const db = admin.firestore();
  const writer = db.bulkWriter();
  return {
    async *recipes() {
      const pageSize = 500;
      let last;
      for (;;) {
        let q = db
          .collectionGroup("recipes")
          .orderBy(admin.firestore.FieldPath.documentId())
          .select("core.mealType", "core.title")
          .limit(pageSize);
        if (last) q = q.startAfter(last);
        const page = await q.get();
        for (const snap of page.docs) {
          const core = snap.get("core");
          yield {
            path: snap.ref.path,
            hasCore: core !== undefined && core !== null && typeof core === "object",
            mealType: snap.get("core.mealType"),
            ref: snap.ref,
            updateTime: snap.updateTime,
          };
        }
        if (page.size < pageSize) return;
        last = page.docs[page.docs.length - 1];
      }
    },
    write: (ref, mealType, updateTime) =>
      writer
        .update(ref, { "core.mealType": mealType }, { lastUpdateTime: updateTime })
        .then(
          () => "ok",
          (err) => (err.code === 9 || err.code === 5 ? "changed" : "failed"),
        ),
    flush: () => writer.close(),
  };
}

function report(counts, apply) {
  const lines = [
    `## Meal type migration (${apply ? "apply" : "dry run"})`,
    "",
    `Recipes: ${counts.total}`,
    "",
    "Already in the app's spelling:",
    ...Object.entries(counts.canonical).map(([k, v]) => `- ${k}: ${v}`),
    "",
    `To rewrite: ${Object.values(counts.rewrite).reduce((a, b) => a + b, 0)}`,
    ...Object.entries(counts.rewrite).map(([k, v]) => `- ${k}: ${v}`),
    "",
    `Other text (left alone): ${counts.other}`,
    `No meal type: ${counts.missing}`,
    `Legacy flat recipes (not written): ${counts.flat}`,
    `Other collections named recipes (skipped): ${counts.notUserRecipe}`,
  ];
  if (apply) {
    lines.push(
      "",
      `Written: ${counts.written}`,
      `Edited meanwhile, skipped: ${counts.changedMeanwhile}`,
      `Failed: ${counts.failed}`,
    );
  }
  return lines.join("\n");
}

async function main() {
  const admin = require("firebase-admin");
  admin.initializeApp();
  const apply = process.argv.includes("--apply");
  const counts = await runMigration(firestoreDeps(admin), { apply });
  console.log(report(counts, apply));
  if (counts.failed > 0) process.exitCode = 1;
}

if (require.main === module) {
  main().catch((err) => {
    console.error(`migration failed: ${err.code || err.name}`);
    process.exit(1);
  });
}

module.exports = {
  CANONICAL,
  SYNONYMS,
  classify,
  isUserRecipePath,
  runMigration,
  report,
};
