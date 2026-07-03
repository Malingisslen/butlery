/**
 * CanonicalPoolKey — SERVER AUTHORITY for the v1 pooled-ratings recipe-identity
 * key ("Butlery-betyget"). See tasks/pooled-ratings-plan.md (decision 1,
 * revised 2026-07-03) and the Dart twin lib/services/rating/canonical_pool_key.dart.
 *
 * The aggregation Cloud Function recomputes the key HERE from recipe content and
 * NEVER trusts a client-written key for pool routing (pool-poisoning defense,
 * decision 2). This TS implementation is the authority; the Dart side is only a
 * display/index hint. Both MUST produce byte-identical keys — enforced by the
 * shared fixture test/fixtures/pool_key_parity.json (Dart:
 * canonical_pool_key_parity_test.dart, TS: __tests__/pool-key-parity.test.ts,
 * condition C4). Any change here must be mirrored in the Dart twin and the fixture.
 *
 * C5 follow-up: the word lists below are duplicated from the Dart twin; share
 * them via one JSON asset (or a CI byte-diff) so the two languages cannot drift.
 */

import { createHash } from "crypto";

const VERSION = "v1";

// Mirror of RecipeTextNormalizer.ingredientUnits (Dart). Contains diacritics;
// a folded copy drives ingredient unit-stripping (see foldedUnitsRe).
const INGREDIENT_UNITS = [
  "dl", "msk", "tsk", "krm", "g", "kg", "ml", "l", "cl", "st", "stk", "port",
  "portion", "portioner", "nypa", "nypor", "bit", "bitar", "skiva", "skivor",
  "klyfta", "klyftor", "kvist", "kvistar", "blad", "paket", "burk", "burkar",
  "påse", "påsar", "ask", "askar",
];

// Mirror of RecipeTextNormalizer.titleStopWords (Dart). Diacritic forms — the
// stop-word filter runs on unfolded lowercased title words.
const TITLE_STOP_WORDS = new Set([
  "och", "med", "på", "i", "till", "för", "av", "en", "ett", "den", "det", "de",
  "som", "från", "and", "with", "the", "a", "an", "of", "for", "to", "in", "on",
  "enkel", "enkelt", "lätt", "snabb", "snabbt", "god", "gott", "bästa",
  "klassisk", "klassiskt", "hemlagad", "hemlagat", "äkta",
]);

const APPROXIMATE_WORDS = ["ca", "cirka", "ungefär", "about", "approximately"];

// Folded (å/ä/ö→a/o) — matched against the folded dish anchor.
const DISH_QUALIFIERS = new Set([
  "gammaldags", "tunna", "tunn", "tunt", "mjuk", "mjuka", "mjukt", "kramig",
  "kramiga", "saftig", "saftiga", "nyttig", "nyttiga", "festlig", "festliga",
  "matig", "matiga", "krispig", "krispiga", "ugnsbakad", "ugnsbakade",
  "grillad", "grillade", "stekt", "stekta", "kokt", "kokta", "perfekt",
  "perfekta", "lyxig", "lyxiga", "billig", "billiga", "vardaglig",
  "vardagliga", "fina", "godaste", "allra",
]);

// Folded generic dish-category nouns → fail closed (do not pool).
const GENERIC_ANCHORS = new Set([
  "soppa", "sas", "kaka", "kakor", "bullar", "bulle", "paj", "gryta", "grateng",
  "sallad", "rora", "pytt", "lada", "form", "gratin", "mos", "stuvning",
  "soppor", "ratt", "ratter", "mat", "middag", "lunch", "frukost", "efterratt",
  "dessert", "bakelse", "tarta", "paltbrod", "brod", "kex", "soppan", "sasen",
  "kakan", "grytan", "pajen", "salladen", "roran", "tartan", "bakelsen",
  "stuvningen", "gratengen", "brodet", "moset",
]);

// JS `\w` is ASCII (same as Dart) — åäö included explicitly where needed.
// These module-level /g regexes are used ONLY with String.replace (stateless).
// Never call .test()/.exec() on them: in a long-lived CF isolate the persisted
// `lastIndex` would produce intermittent wrong keys.
const punctuationRe = /[^\wåäö\s]/g;
const multiSpaceRe = /\s+/g;
const leadingNumbersRe = /^\s*\d+[\s,.\/]*\d*\s*/;
const parentheticalRe = /\([^)]*\)/g;
const leadingDigitsRe = /^\d+/;
const hashtagRe = /#[\wåäö]+/g;
const hasLetterRe = /[a-zåäö]/;

function foldDiacritics(s: string): string {
  return s.replace(/å/g, "a").replace(/ä/g, "a").replace(/ö/g, "o");
}

const foldedUnitsRe = new RegExp(
  "\\b(" + INGREDIENT_UNITS.map(foldDiacritics).join("|") + ")\\b",
  "gi"
);
const foldedApproxRe = new RegExp(
  "\\b(" + APPROXIMATE_WORDS.map(foldDiacritics).join("|") + ")\\b",
  "g"
);

function significantTitleWords(title: string): string[] {
  const normalized = title
    .toLowerCase()
    .replace(punctuationRe, " ")
    .replace(multiSpaceRe, " ")
    .trim();
  return normalized
    .split(" ")
    .filter((w) => w.length > 2 && !TITLE_STOP_WORDS.has(w));
}

// Strip a leading numeric run FIRST so a glued quantity ("500g", "2dl") is not
// turned into letters ("5oog") before it can be recognized as an amount; then
// repair interior digit/letter OCR confusions ("sa1t"→"salt", "d1"→"dl").
function repairOcrDigitsToken(token: string): string {
  const stripped = token.replace(leadingDigitsRe, "");
  if (!hasLetterRe.test(stripped)) return stripped;
  return stripped.replace(/0/g, "o").replace(/1/g, "l");
}

function strengthenIngredientName(raw: string): string {
  let s = foldDiacritics(raw.toLowerCase().trim());
  // Strip the leading amount FIRST (decimal-aware: "1,5", "0,5", "1.5", and
  // glued "500g"→"g"). Must precede OCR repair — otherwise per-token
  // leading-digit stripping turns "1,5" into ",5" and the decimal residue
  // survives, fragmenting the pool for the pervasive decimal-amount recipes.
  s = s.replace(leadingNumbersRe, "");
  s = s.split(" ").map(repairOcrDigitsToken).join(" ");
  s = s.replace(foldedApproxRe, "");
  s = s.replace(foldedUnitsRe, "");
  s = s.replace(parentheticalRe, "");
  s = s.replace(multiSpaceRe, " ").trim();
  return s.length < 2 ? "" : s;
}

function dishAnchor(title: string): string | null {
  const deHashed = title.replace(hashtagRe, " ");
  const tokens = significantTitleWords(deHashed)
    .map(foldDiacritics)
    .map(repairOcrDigitsToken)
    .filter((w) => !DISH_QUALIFIERS.has(w));
  let anchor = "";
  for (const t of tokens) {
    if (t.length > anchor.length) anchor = t; // first-wins on tie
  }
  if (anchor === "" || GENERIC_ANCHORS.has(anchor)) return null;
  return anchor;
}

/**
 * Compute the pool key for a recipe, or null if it must not pool (no ingredient
 * names survive, or no usable dish anchor — fail closed).
 */
export function computePoolKey(
  title: string,
  ingredients: string[]
): string | null {
  if (!ingredients || ingredients.length === 0) return null;

  const names = Array.from(
    new Set(
      ingredients.map(strengthenIngredientName).filter((s) => s.length > 0)
    )
  ).sort();
  if (names.length === 0) return null;

  const anchor = dishAnchor(title);
  if (anchor === null) return null;

  const raw = anchor + "::" + names.slice(0, 12).join("|");
  const hash = createHash("sha256").update(raw, "utf8").digest("hex").substring(0, 16);
  return VERSION + ":" + hash;
}
