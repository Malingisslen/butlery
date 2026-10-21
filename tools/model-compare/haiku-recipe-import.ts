/**
 * One-off model comparison for recipe import: sends the same pages the
 * nightly `recipe_from_url` corpus uses, with the production system prompt,
 * to Claude models and scores them against the same gold.
 *
 * Run from `functions/` with NODE_PATH=functions/node_modules (see
 * .github/workflows/model-compare.yml). Reads ANTHROPIC_API_KEY from the
 * environment; nothing here is imported by the app or the Cloud Functions.
 */

import Anthropic from "@anthropic-ai/sdk";
import * as fs from "fs";
import { RECIPE_EXTRACTION_SYSTEM_PROMPT } from "../../functions/src/llm/gemini-client";
import { scrubPii } from "../../functions/src/llm/pii-scrubber";
import {
  GoldenInput,
  GoldenOutcome,
  scorePage,
} from "../../functions/src/admin/golden-recipe-from-url-core";

// $ per million tokens at prompts up to 100K tokens (Claude API price list).
const PRICES: Record<string, { input: number; output: number }> = {
  "claude-haiku-5-5": { input: 0.1, output: 0.5 },
  "claude-sonnet-5-5": { input: 2, output: 10 },
};

const nullable = (type: string) => ({ anyOf: [{ type }, { type: "null" }] });

const RECIPE_JSON_SCHEMA = {
  type: "object",
  properties: {
    title: { type: "string" },
    description: nullable("string"),
    portions: nullable("number"),
    prepTimeMinutes: nullable("number"),
    cookTimeMinutes: nullable("number"),
    ingredients: {
      type: "array",
      items: {
        type: "object",
        properties: {
          amount: nullable("number"),
          unit: nullable("string"),
          name: { type: "string" },
          preparation: nullable("string"),
          section: nullable("string"),
        },
        required: ["amount", "unit", "name", "preparation", "section"],
        additionalProperties: false,
      },
    },
    instructions: { type: "array", items: { type: "string" } },
    tags: { type: "array", items: { type: "string" } },
    difficulty: nullable("string"),
    source: nullable("string"),
  },
  required: [
    "title", "description", "portions", "prepTimeMinutes", "cookTimeMinutes",
    "ingredients", "instructions", "tags", "difficulty", "source",
  ],
  additionalProperties: false,
};

interface ModelResult {
  model: string;
  totalCostUsd: number;
  totalSeconds: number;
  pages: ReturnType<typeof scorePage>[];
}

async function runModel(
  client: Anthropic,
  model: string,
  inputs: GoldenInput[]
): Promise<ModelResult> {
  const price = PRICES[model];
  const pages: ReturnType<typeof scorePage>[] = [];
  let total = 0;
  const started = Date.now();

  for (const input of inputs) {
    const outcome: GoldenOutcome = { id: input.id, estimatedCost: 0 };
    try {
      const res = await client.messages.create({
        model,
        max_tokens: 8000,
        system: RECIPE_EXTRACTION_SYSTEM_PROMPT,
        output_config: {
          effort: "low",
          format: { type: "json_schema", schema: RECIPE_JSON_SCHEMA },
        },
        messages: [
          {
            role: "user",
            content:
              `Extrahera receptet från följande text:\n\n${scrubPii(input.text)}` +
              `\n\nKälla: ${input.url}`,
          },
        ],
      });
      outcome.estimatedCost =
        (res.usage.input_tokens / 1e6) * price.input +
        (res.usage.output_tokens / 1e6) * price.output;
      const block = res.content.find((b) => b.type === "text");
      if (res.stop_reason !== "end_turn" || !block || block.type !== "text") {
        outcome.error = `stop_reason ${res.stop_reason}`;
      } else {
        const recipe = JSON.parse(block.text) as {
          title: string;
          ingredients: { name: string }[];
        };
        outcome.title = recipe.title;
        outcome.ingredientNames = recipe.ingredients.map((i) => i.name);
      }
    } catch (e) {
      outcome.error = String(e);
    }
    total += outcome.estimatedCost;
    pages.push(scorePage(input, outcome));
    console.log(`${model} ${input.id}: ${outcome.error ?? "ok"}`);
  }
  return {
    model,
    totalCostUsd: total,
    totalSeconds: (Date.now() - started) / 1000,
    pages,
  };
}

function markdown(results: ModelResult[]): string {
  const lines = ["| Modell | Rätt titel | Ingredienser hittade | Fel | Kostnad | Tid |", "|---|---|---|---|---|---|"];
  for (const r of results) {
    const titles = r.pages.filter((p) => p.titleMatches).length;
    const found = r.pages.reduce((s, p) => s + p.ingredientsFound, 0);
    const gold = r.pages.reduce((s, p) => s + p.goldIngredients, 0);
    const errors = r.pages.filter((p) => p.error).length;
    lines.push(
      `| ${r.model} | ${titles}/${r.pages.length} | ${found}/${gold} | ${errors} | $${r.totalCostUsd.toFixed(4)} | ${r.totalSeconds.toFixed(0)} s |`
    );
  }
  lines.push("", "Sidor där en modell missade titel eller ingredienser:");
  for (const r of results) {
    for (const p of r.pages) {
      if (!p.titleMatches || p.ingredientsFound < p.goldIngredients || p.error) {
        lines.push(
          `- ${r.model} / ${p.id}: titel ${p.titleMatches ? "ok" : "miss"}, ${p.ingredientsFound}/${p.goldIngredients}` +
            (p.error ? ` (${p.error})` : "")
        );
      }
    }
  }
  return lines.join("\n");
}

async function main(): Promise<void> {
  const [inputsPath, outPath] = process.argv.slice(2);
  const models = (process.env.MODELS ?? "claude-haiku-5-5").split(",");
  const inputs = JSON.parse(fs.readFileSync(inputsPath, "utf8")) as GoldenInput[];
  const client = new Anthropic();
  const results: ModelResult[] = [];
  for (const model of models) {
    if (!PRICES[model]) throw new Error(`no price for ${model}`);
    results.push(await runModel(client, model, inputs));
  }
  fs.writeFileSync(outPath, JSON.stringify(results, null, 2));
  const md = markdown(results);
  console.log(md);
  if (process.env.GITHUB_STEP_SUMMARY) {
    fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, md + "\n");
  }
}

main().catch((e) => {
  console.error(e);
  process.exitCode = 1;
});
