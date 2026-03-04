/**
 * Fetches ingredients from Livsmedelsverket's open data API and outputs
 * candidate CSV rows for human review before merging into the ingredient DB.
 *
 * The API provides ~2,575 Swedish food items with canonical Swedish names
 * and food group classifications (Huvudgrupp).
 *
 * Prerequisites:
 *   No auth needed — public API (CC BY 4.0 license)
 *
 * Usage:
 *   cd functions
 *   npx ts-node src/admin/fetch-livsmedelsverket.ts [--output path] [--dry-run]
 *
 * Default output: ../docs/tagging/data/livsmedelsverket_candidates.csv
 */

import * as fs from "fs";
import * as path from "path";
import { stripDiacritics } from "../shared/swedish-normalize";

const API_BASE = "https://dataportal.livsmedelsverket.se/livsmedel/api/v1";
const PAGE_SIZE = 100;

// Swedish language code for the API
const LANG_SV = 1;

interface LivsmedelsverketItem {
  nummer: number;
  namn: string;
  vetenskapligtNamn?: string;
  huvudgrupp?: string;
}

interface CandidateRow {
  livsmedelsverketId: number;
  swedish: string;
  huvudgrupp: string;
  butleryGroup: string;
  scientificName: string;
  isComposedDish: boolean;
}

/**
 * Maps Livsmedelsverket Huvudgrupp → Butlery group hierarchy.
 *
 * Livsmedelsverket groups are broad categories; this maps them to
 * the Butlery group prefix system (protein/*, vegetable/*, etc.).
 */
const HUVUDGRUPP_MAP: Record<string, string> = {
  // Meats
  "Nötkött": "protein/meat/beef",
  "Griskött": "protein/meat/pork",
  "Lammkött": "protein/meat/lamb",
  "Fågelkött": "protein/poultry",
  "Viltkött": "protein/meat/game",
  "Köttberedningar, charkuterier": "protein/meat/processed",
  "Inälvor": "protein/meat/offal",

  // Seafood
  "Fisk": "protein/seafood/fish",
  "Skaldjur": "protein/seafood/shellfish",
  "Fiskberedningar": "protein/seafood/processed",

  // Dairy & Eggs
  "Mjölk": "protein/dairy",
  "Ost": "protein/dairy/cheese",
  "Grädde, créme fraiche": "protein/dairy",
  "Ägg": "protein/egg",
  "Yoghurt, fil": "protein/dairy",

  // Fats & Oils
  "Smör, margarin": "fat/butter",
  "Oljor": "fat/oil",
  "Övrigt fett (ister, talg, kokosfett)": "fat/other",

  // Grains & Bread
  "Bröd": "grain/bread",
  "Gryn, flingor": "grain/cereal",
  "Mjöl, stärkelse": "grain/flour",
  "Pasta, ris": "grain/pasta",

  // Vegetables
  "Grönsaker": "vegetable/other",
  "Rotfrukter": "vegetable/root",
  "Baljväxter": "vegetable/legume",
  "Kål": "vegetable/cabbage",
  "Bladgrönsaker": "vegetable/leafy",
  "Svamp": "vegetable/mushroom",
  "Lök": "vegetable/allium",

  // Fruits & Berries
  "Frukt": "fruit/other",
  "Bär": "fruit/berry",
  "Citrusfrukter": "fruit/citrus",
  "Torkad frukt": "fruit/dried",

  // Nuts & Seeds
  "Nötter, frön": "other/nuts-seeds",

  // Spices & Herbs
  "Kryddor": "spice/herb",
  "Salt, smaktillsatser": "spice/seasoning",

  // Sweets & Baking
  "Socker, sirap, honung": "other/sweetener",
  "Choklad, godis": "other/confectionery",
  "Bakverk, kakor": "other/baking",

  // Beverages
  "Juice, nektar": "other/beverage",
  "Läsk, saft": "other/beverage",
  "Alkoholhaltiga drycker": "other/beverage",
  "Kaffe, te": "other/beverage",

  // Composed dishes — these should be filtered out
  "Maträtter": "_composed_dish",
  "Soppor, buljonger": "_composed_dish",
  "Såser": "_composed_dish",
  "Smörgåsar": "_composed_dish",
  "Sallader": "_composed_dish",
  "Desserter": "_composed_dish",
  "Snacks": "_composed_dish",
  "Barnmat": "_composed_dish",
  "Vegetariska rätter": "_composed_dish",
  "Pizzor, pirog, paj": "_composed_dish",
};

/**
 * Fetch all food items from the API with pagination.
 */
async function fetchAllItems(): Promise<LivsmedelsverketItem[]> {
  const items: LivsmedelsverketItem[] = [];
  let offset = 0;
  let totalRecords = Infinity;

  while (offset < totalRecords) {
    const url = `${API_BASE}/livsmedel?offset=${offset}&limit=${PAGE_SIZE}&sprak=${LANG_SV}`;
    console.error(`Fetching ${url}...`);

    const response = await fetch(url);
    if (!response.ok) {
      throw new Error(`API error ${response.status}: ${response.statusText}`);
    }

    const data = await response.json() as {
      _meta: { totalRecords: number; count: number };
      livsmedel: Array<{ nummer: number; namn: string; vetenskapligtNamn?: string }>;
    };

    totalRecords = data._meta.totalRecords;

    for (const item of data.livsmedel) {
      items.push({
        nummer: item.nummer,
        namn: item.namn,
        vetenskapligtNamn: item.vetenskapligtNamn,
      });
    }

    offset += data._meta.count;
    console.error(`  Fetched ${items.length} / ${totalRecords}`);
  }

  return items;
}

/**
 * Fetch classifications (Huvudgrupp) for a single food item.
 */
async function fetchHuvudgrupp(nummer: number): Promise<string> {
  const url = `${API_BASE}/livsmedel/${nummer}/klassificeringar?sprak=${LANG_SV}`;

  try {
    const response = await fetch(url);
    if (!response.ok) return "unknown";

    const data = await response.json() as Array<{ typ: string; namn: string }>;

    // Find Huvudgrupp classification
    const hg = data.find((c) => c.typ === "Huvudgrupp");
    return hg?.namn || "unknown";
  } catch {
    return "unknown";
  }
}

/**
 * Normalize ingredient name for comparison.
 */
function normalize(name: string): string {
  return stripDiacritics(name.toLowerCase().trim())
    .replace(/[^a-z0-9\s-]/g, "")
    .replace(/\s+/g, " ");
}

/**
 * Load existing ingredient names from the Butlery CSV for deduplication.
 */
function loadExistingNames(csvPath: string): Set<string> {
  const names = new Set<string>();

  if (!fs.existsSync(csvPath)) {
    console.error(`Warning: CSV not found at ${csvPath}, skipping dedup`);
    return names;
  }

  const content = fs.readFileSync(csvPath, "utf-8");
  const lines = content.split("\n").slice(1); // skip header

  for (const line of lines) {
    if (!line.trim()) continue;

    // Parse CSV line (simplified — handles quoted fields)
    const fields = parseCsvLine(line);
    const swedish = fields[1]?.trim(); // column index 1 = swedish
    if (swedish) {
      names.add(normalize(swedish));
    }

    // Also add aliases (column index 5 = aliases_sv)
    const aliases = fields[5]?.trim();
    if (aliases) {
      for (const alias of aliases.split(";")) {
        const trimmed = alias.trim();
        if (trimmed) names.add(normalize(trimmed));
      }
    }
  }

  return names;
}

function parseCsvLine(line: string): string[] {
  const result: string[] = [];
  let current = "";
  let inQuotes = false;

  for (let i = 0; i < line.length; i++) {
    const char = line[i];
    if (char === '"') {
      if (inQuotes && i + 1 < line.length && line[i + 1] === '"') {
        current += '"';
        i++;
      } else {
        inQuotes = !inQuotes;
      }
    } else if (char === "," && !inQuotes) {
      result.push(current);
      current = "";
    } else {
      current += char;
    }
  }
  result.push(current);
  return result;
}

/**
 * Generate a kebab-case ID from a Swedish name.
 */
function toId(name: string): string {
  return stripDiacritics(name.toLowerCase().trim())
    .replace(/[^a-z0-9\s-]/g, "")
    .replace(/\s+/g, "-")
    .replace(/-+/g, "-")
    .replace(/^-|-$/g, "");
}

function escapeCsv(value: string): string {
  if (value.includes(",") || value.includes('"') || value.includes("\n")) {
    return `"${value.replace(/"/g, '""')}"`;
  }
  return value;
}

async function main(): Promise<void> {
  const args = process.argv.slice(2);
  const dryRun = args.includes("--dry-run");
  const outputIdx = args.indexOf("--output");
  const outputPath =
    outputIdx >= 0 && args[outputIdx + 1]
      ? path.resolve(args[outputIdx + 1])
      : path.resolve(
          __dirname,
          "../../..",
          "docs/tagging/data/livsmedelsverket_candidates.csv"
        );

  console.error("=== Livsmedelsverket Ingredient Fetch ===\n");

  // Step 1: Load existing names for dedup
  const existingCsvPath = path.resolve(
    __dirname,
    "../../..",
    "docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv"
  );
  const existingNames = loadExistingNames(existingCsvPath);
  console.error(`Loaded ${existingNames.size} existing ingredient names\n`);

  // Step 2: Fetch all items from API
  const items = await fetchAllItems();
  console.error(`\nFetched ${items.length} total items from Livsmedelsverket\n`);

  // Step 3: Fetch classifications (batched to avoid rate limiting)
  console.error("Fetching classifications...");
  const candidates: CandidateRow[] = [];
  let skippedDuplicate = 0;
  let skippedComposed = 0;
  let skippedUnmapped = 0;

  const BATCH_SIZE = 10;
  for (let i = 0; i < items.length; i += BATCH_SIZE) {
    const batch = items.slice(i, i + BATCH_SIZE);
    const results = await Promise.all(
      batch.map(async (item) => {
        const huvudgrupp = await fetchHuvudgrupp(item.nummer);
        return { ...item, huvudgrupp };
      })
    );

    for (const item of results) {
      const butleryGroup = HUVUDGRUPP_MAP[item.huvudgrupp] || "";

      // Skip composed dishes
      if (butleryGroup === "_composed_dish") {
        skippedComposed++;
        continue;
      }

      // Skip if no mapping exists
      if (!butleryGroup) {
        skippedUnmapped++;
        continue;
      }

      // Check for duplicate against existing DB
      const normalizedName = normalize(item.namn);
      if (existingNames.has(normalizedName)) {
        skippedDuplicate++;
        continue;
      }

      candidates.push({
        livsmedelsverketId: item.nummer,
        swedish: item.namn.toLowerCase().trim(),
        huvudgrupp: item.huvudgrupp,
        butleryGroup,
        scientificName: item.vetenskapligtNamn || "",
        isComposedDish: false,
      });
    }

    if ((i + BATCH_SIZE) % 500 === 0 || i + BATCH_SIZE >= items.length) {
      console.error(
        `  Processed ${Math.min(i + BATCH_SIZE, items.length)} / ${items.length}`
      );
    }
  }

  // Sort candidates by Swedish name
  candidates.sort((a, b) => a.swedish.localeCompare(b.swedish, "sv"));

  console.error(`\n=== Summary ===`);
  console.error(`Total API items: ${items.length}`);
  console.error(`Candidates (new ingredients): ${candidates.length}`);
  console.error(`Skipped (already exists): ${skippedDuplicate}`);
  console.error(`Skipped (composed dish): ${skippedComposed}`);
  console.error(`Skipped (unmapped group): ${skippedUnmapped}`);

  // Group distribution
  const groupCounts = new Map<string, number>();
  for (const c of candidates) {
    const top = c.butleryGroup.split("/")[0];
    groupCounts.set(top, (groupCounts.get(top) || 0) + 1);
  }
  console.error(`\nGroup distribution:`);
  for (const [group, count] of [...groupCounts.entries()].sort()) {
    console.error(`  ${group}: ${count}`);
  }

  if (dryRun) {
    console.error(`\nDry run — not writing output.`);
    // Print first 10 candidates as preview
    console.error(`\nFirst 10 candidates:`);
    for (const c of candidates.slice(0, 10)) {
      console.error(
        `  ${c.swedish} [${c.butleryGroup}] (LV#${c.livsmedelsverketId})`
      );
    }
    return;
  }

  // Write candidate CSV (matches Butlery_Ingredients_INGREDIENTS.csv columns)
  const header = [
    "id",
    "swedish",
    "english",
    "group",
    "properties",
    "aliases_sv",
    "aliases_en",
    "search_terms",
    "notes_sv",
    "notes_en",
    "season_availability",
    "typical_storage",
    "typical_unit",
    "price_category",
    "avg_price_sek",
    "carbon_footprint_category",
    "status",
    "created_date",
    "updated_date",
    "created_by",
    "verified_by",
    "ai_generated",
    "export_ready",
  ].join(",");

  const now = new Date().toISOString().split("T")[0] + " 00:00:00";

  const rows = candidates.map((c) => {
    const id = toId(c.swedish);
    const searchTerms = normalize(c.swedish);

    return [
      escapeCsv(id),
      escapeCsv(c.swedish),
      "", // english — needs manual fill
      escapeCsv(c.butleryGroup),
      "", // properties — needs manual review
      "", // aliases_sv
      "", // aliases_en
      escapeCsv(searchTerms),
      c.scientificName
        ? escapeCsv(`Livsmedelsverket #${c.livsmedelsverketId}. ${c.scientificName}`)
        : escapeCsv(`Livsmedelsverket #${c.livsmedelsverketId}`),
      "", // notes_en
      "year-round",
      "", // typical_storage
      "g", // typical_unit
      "", // price_category
      "", // avg_price_sek
      "", // carbon_footprint_category
      "draft",
      now,
      now,
      "livsmedelsverket",
      "", // verified_by
      "0",
      "0",
    ].join(",");
  });

  fs.mkdirSync(path.dirname(outputPath), { recursive: true });
  fs.writeFileSync(outputPath, header + "\n" + rows.join("\n") + "\n");

  console.error(`\nWritten ${candidates.length} candidates to: ${outputPath}`);
  console.error(
    `\nNext steps:\n` +
      `  1. Review candidates — filter out composed dishes and verify group mappings\n` +
      `  2. Add properties (allergens, diet flags)\n` +
      `  3. Append approved rows to Butlery_Ingredients_INGREDIENTS.csv\n` +
      `  4. Run: npm run sync-ingredients -- --force\n` +
      `  5. Run full CRF pipeline to retrain`
  );
}

main().catch((e) => {
  console.error("Error:", e);
  process.exit(1);
});
