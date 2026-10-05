/**
 * Nightly `recipe_from_url` AI corpus (BUT-2239): sends each import-gate site
 * page, as the app's AI fallback would send it, through the same server code
 * the `structureRecipe` callable runs, and writes a scored summary.
 *
 * Input: the JSON written by test/golden/llm/recipe_from_url_inputs_test.dart
 * (the stripped text, already cut to the server's limit, plus gold).
 *
 * Without GOOGLE_CLOUD_PROJECT there is no way to reach Vertex AI, and the
 * script writes a "skipped" summary instead of calling anything.
 *
 * Usage:
 *   cd functions
 *   npx ts-node src/admin/golden-recipe-from-url.ts <inputs.json> <summary.json>
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import { calculateGeminiCost, MAX_TOKENS } from "../llm/gemini-client";
import { runStructureRecipe } from "../llm/structure-recipe";
import {
  GoldenInput,
  GoldenOutcome,
  GoldenSummary,
  mayCall,
  skippedSummary,
  summariseRun,
} from "./golden-recipe-from-url-core";

// The system prompt and schema ride on every call; 4,000 tokens covers them.
const PROMPT_OVERHEAD_TOKENS = 4000;

function ceilingFor(input: GoldenInput): number {
  return calculateGeminiCost({
    promptTokenCount: Math.ceil(input.text.length / 3) + PROMPT_OVERHEAD_TOKENS,
    candidatesTokenCount: MAX_TOKENS,
  });
}

async function main(): Promise<void> {
  const [inputsPath, summaryPath] = process.argv.slice(2);
  if (!inputsPath || !summaryPath) {
    throw new Error("usage: golden-recipe-from-url.ts <inputs.json> <summary.json>");
  }
  const capUsd = Number(process.env.COST_CAP_USD ?? "1.00");
  const write = (s: GoldenSummary): void =>
    fs.writeFileSync(summaryPath, JSON.stringify(s, null, 2));

  if (!process.env.GOOGLE_CLOUD_PROJECT) {
    write(skippedSummary("no Google Cloud access configured", capUsd));
    console.log("recipe_from_url: skipped, no Google Cloud access configured");
    return;
  }

  admin.initializeApp();
  const inputs = JSON.parse(fs.readFileSync(inputsPath, "utf8")) as GoldenInput[];
  const outcomes: GoldenOutcome[] = [];
  let spent = 0;

  for (const input of inputs) {
    if (!mayCall(spent, ceilingFor(input), capUsd)) {
      console.log(`recipe_from_url: stopping before ${input.id}, cap reached`);
      break;
    }
    try {
      const res = await runStructureRecipe(
        { text: input.text, mode: "extract", sourceUrl: input.url },
        "golden-ci"
      );
      spent += res.estimatedCost;
      outcomes.push({
        id: input.id,
        title: res.recipe?.title,
        ingredientNames: res.recipe?.ingredients.map((i) => i.name),
        estimatedCost: res.estimatedCost,
        ...(res.success ? {} : { error: res.error ?? "no recipe" }),
      });
    } catch (e) {
      // A call that threw may still have been billed: count it at its ceiling.
      spent += ceilingFor(input);
      outcomes.push({ id: input.id, estimatedCost: ceilingFor(input), error: String(e) });
    }
  }

  const summary = summariseRun(inputs, outcomes, capUsd);
  write(summary);
  for (const p of summary.pages) {
    console.log(
      `${p.id}: title ${p.titleMatches ? "ok" : "MISS"}, ` +
        `${p.ingredientsFound}/${p.goldIngredients} ingredients, $${p.costUsd.toFixed(5)}` +
        (p.error ? ` (${p.error})` : "")
    );
  }
  console.log(`recipe_from_url: ${summary.calls} calls, $${summary.total_cost_usd.toFixed(5)}`);
  if (summary.over_cap) process.exitCode = 1;
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
