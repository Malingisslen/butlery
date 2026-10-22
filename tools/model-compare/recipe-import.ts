/**
 * Model comparison for recipe import. Sends pasted-text recipes and the
 * import gate's site pages, with the production system prompt, to Claude
 * models and scores them against the gate's gold files.
 *
 * Run from `functions/` with NODE_PATH and TS_NODE_PROJECT pointing into
 * functions/ (see .github/workflows/model-compare.yml). Reads
 * ANTHROPIC_API_KEY from the environment. Nothing here is imported by the app
 * or the Cloud Functions.
 */

import Anthropic from "@anthropic-ai/sdk";
import * as fs from "fs";
import * as path from "path";
import { RECIPE_EXTRACTION_SYSTEM_PROMPT } from "../../functions/src/llm/gemini-client";
import { scrubPii } from "../../functions/src/llm/pii-scrubber";

// $ per million tokens at prompts up to 100K tokens (Claude API price list).
const PRICES: Record<string, { input: number; output: number }> = {
  "claude-haiku-5-5": { input: 0.1, output: 0.5 },
  "claude-sonnet-5-5": { input: 2, output: 10 },
};

// A site page whose stripped text is shorter than this carries its recipe only
// in hidden structured data, which the app reads without AI.
const MIN_SITE_TEXT_CHARS = 300;

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

interface Gold {
  title: string;
  steps: number;
  ingredients: { key: string; allergen?: string | null }[];
  headings: string[];
}

interface Case {
  id: string;
  kind: "site" | "text";
  url?: string;
  text: string;
  gold: Gold;
}

interface PageScore {
  id: string;
  kind: "site" | "text";
  titleClose: boolean;
  ingredientsFound: number;
  ingredientsGold: number;
  allergenFound: number;
  allergenGold: number;
  headingsAsIngredients: number;
  stepsMatch: boolean;
  stepsNear: boolean;
  costUsd: number;
  error?: string;
  gotTitle?: string;
  gotSteps?: number;
  missedKeys: string[];
}

interface ModelResult {
  model: string;
  totalCostUsd: number;
  totalSeconds: number;
  pages: PageScore[];
}

const norm = (s: string): string => s.trim().toLowerCase();

function loadCases(inputsPath: string, repoRoot: string): Case[] {
  const importGate = path.join(repoRoot, "test/import_gate");
  const siteGold = JSON.parse(
    fs.readFileSync(path.join(importGate, "sites/gold.json"), "utf8")
  ) as Record<string, Gold>;
  const siteInputs = JSON.parse(fs.readFileSync(inputsPath, "utf8")) as {
    id: string;
    url: string;
    text: string;
  }[];

  const cases: Case[] = [];
  for (const input of siteInputs) {
    if (input.text.length < MIN_SITE_TEXT_CHARS) {
      console.log(`skipping ${input.id}: no recipe in the visible text`);
      continue;
    }
    cases.push({ id: input.id, kind: "site", url: input.url, text: input.text, gold: siteGold[input.id] });
  }

  const textDir = path.join(importGate, "text");
  for (const file of fs.readdirSync(textDir).filter((f) => f.endsWith(".txt")).sort()) {
    const id = file.replace(/\.txt$/, "");
    cases.push({
      id,
      kind: "text",
      text: fs.readFileSync(path.join(textDir, file), "utf8"),
      gold: JSON.parse(fs.readFileSync(path.join(textDir, `${id}.gold.json`), "utf8")) as Gold,
    });
  }
  return cases;
}

function score(c: Case, recipe: { title: string; ingredients: { name: string }[]; instructions: string[] } | undefined, cost: number, error?: string): PageScore {
  const names = (recipe?.ingredients ?? []).map((i) => norm(i.name));
  const has = (key: string) => names.some((n) => n.includes(norm(key)));
  const allergens = c.gold.ingredients.filter((i) => i.allergen);
  const title = recipe ? norm(recipe.title) : "";
  const goldTitle = norm(c.gold.title);
  const steps = recipe?.instructions.length ?? 0;
  return {
    id: c.id,
    kind: c.kind,
    titleClose: title !== "" && (title.includes(goldTitle) || goldTitle.includes(title)),
    ingredientsFound: c.gold.ingredients.filter((i) => has(i.key)).length,
    ingredientsGold: c.gold.ingredients.length,
    allergenFound: allergens.filter((i) => has(i.key)).length,
    allergenGold: allergens.length,
    headingsAsIngredients: names.filter((n) =>
      c.gold.headings.some((h) => norm(h) === n || `${norm(h)}:` === n)
    ).length,
    stepsMatch: steps === c.gold.steps,
    stepsNear: Math.abs(steps - c.gold.steps) <= 1,
    costUsd: cost,
    ...(error !== undefined ? { error } : {}),
    gotTitle: recipe?.title,
    gotSteps: recipe ? steps : undefined,
    missedKeys: c.gold.ingredients.filter((i) => !has(i.key)).map((i) => i.key),
  };
}

async function runModel(client: Anthropic, model: string, cases: Case[]): Promise<ModelResult> {
  const price = PRICES[model];
  const pages: PageScore[] = [];
  let total = 0;
  const started = Date.now();

  for (const c of cases) {
    let cost = 0;
    let recipe: Parameters<typeof score>[1];
    let error: string | undefined;
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
              `Extrahera receptet från följande text:\n\n${scrubPii(c.text)}` +
              (c.url ? `\n\nKälla: ${c.url}` : ""),
          },
        ],
      });
      cost =
        (res.usage.input_tokens / 1e6) * price.input +
        (res.usage.output_tokens / 1e6) * price.output;
      const block = res.content.find((b) => b.type === "text");
      if (res.stop_reason !== "end_turn" || !block || block.type !== "text") {
        error = `stop_reason ${res.stop_reason}`;
      } else {
        recipe = JSON.parse(block.text);
      }
    } catch (e) {
      error = String(e);
    }
    total += cost;
    pages.push(score(c, recipe, cost, error));
    console.log(`${model} ${c.id}: ${error ?? "ok"}`);
  }
  return { model, totalCostUsd: total, totalSeconds: (Date.now() - started) / 1000, pages };
}

const sum = (pages: PageScore[], f: (p: PageScore) => number): number =>
  pages.reduce((s, p) => s + f(p), 0);

function markdown(results: ModelResult[]): string {
  const lines = [
    "| Modell | Recept | Titel nära | Ingredienser | Allergen-ingredienser | Rubrik som ingrediens | Antal steg rätt | Fel | Kostnad |",
    "|---|---|---|---|---|---|---|---|---|",
  ];
  for (const r of results) {
    for (const kind of ["all", "text", "site"] as const) {
      const pages = kind === "all" ? r.pages : r.pages.filter((p) => p.kind === kind);
      if (pages.length === 0) continue;
      const label = kind === "all" ? "alla" : kind === "text" ? "inklistrad text" : "webbsidor";
      lines.push(
        `| ${r.model} (${label}) | ${pages.length} | ${pages.filter((p) => p.titleClose).length} | ` +
          `${sum(pages, (p) => p.ingredientsFound)}/${sum(pages, (p) => p.ingredientsGold)} | ` +
          `${sum(pages, (p) => p.allergenFound)}/${sum(pages, (p) => p.allergenGold)} | ` +
          `${sum(pages, (p) => p.headingsAsIngredients)} | ${pages.filter((p) => p.stepsMatch).length} | ` +
          `${pages.filter((p) => p.error).length} | $${sum(pages, (p) => p.costUsd).toFixed(4)} |`
      );
    }
  }
  lines.push("", "Recept där en modell missade något:");
  for (const r of results) {
    for (const p of r.pages) {
      const problems: string[] = [];
      if (!p.titleClose) problems.push(`titel "${p.gotTitle ?? "-"}"`);
      if (p.missedKeys.length > 0) problems.push(`saknar ${p.missedKeys.join(", ")}`);
      if (p.headingsAsIngredients > 0) problems.push("rubrik som ingrediens");
      if (!p.stepsNear) problems.push(`${p.gotSteps ?? 0} steg`);
      if (p.error) problems.push(p.error);
      if (problems.length > 0) lines.push(`- ${r.model} / ${p.id}: ${problems.join("; ")}`);
    }
  }
  return lines.join("\n");
}

async function main(): Promise<void> {
  const [inputsPath, outPath] = process.argv.slice(2);
  const repoRoot = process.env.REPO_ROOT ?? path.resolve(__dirname, "../..");
  const models = (process.env.MODELS ?? "claude-haiku-5-5").split(",");
  const cases = loadCases(inputsPath, repoRoot);
  console.log(`${cases.length} recipes`);
  const client = new Anthropic();
  const results: ModelResult[] = [];
  for (const model of models) {
    if (!PRICES[model]) throw new Error(`no price for ${model}`);
    results.push(await runModel(client, model, cases));
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
