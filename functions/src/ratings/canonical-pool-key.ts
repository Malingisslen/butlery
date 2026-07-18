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
 * C5 drift guard (CLOSED): the word lists below are pinned IN ORDER to the
 * shared source of truth test/fixtures/pool_key_wordlists.json by
 * pool-key-wordlist-parity.test.ts (this file's `npm test` suite) and its Dart
 * twin canonical_pool_key_wordlist_parity_test.dart. They stay native consts
 * (not loaded from the JSON) so the key stays synchronous and needs no .json
 * copied into the deployed functions/lib bundle; the parity tests are what make
 * the two languages incapable of silently drifting. Adding a word here without
 * updating the JSON and the Dart twin fails CI.
 */

import { createHash } from "crypto";

const VERSION = "v1";

// Mirror of RecipeTextNormalizer.ingredientUnits (Dart). Contains diacritics;
// a folded copy drives ingredient unit-stripping (see foldedUnitsRe).
// Exported for the C5 word-list parity test.
export const INGREDIENT_UNITS = [
  "dl", "msk", "tsk", "krm", "g", "kg", "ml", "l", "cl", "st", "stk", "port",
  "portion", "portioner", "nypa", "nypor", "bit", "bitar", "skiva", "skivor",
  "klyfta", "klyftor", "kvist", "kvistar", "blad", "paket", "burk", "burkar",
  "påse", "påsar", "ask", "askar",
];

// Mirror of RecipeTextNormalizer.titleStopWords (Dart). Diacritic forms — the
// stop-word filter runs on unfolded lowercased title words.
export const TITLE_STOP_WORDS = new Set([
  "och", "med", "på", "i", "till", "för", "av", "en", "ett", "den", "det", "de",
  "som", "från", "and", "with", "the", "a", "an", "of", "for", "to", "in", "on",
  "enkel", "enkelt", "lätt", "snabb", "snabbt", "god", "gott", "bästa",
  "klassisk", "klassiskt", "hemlagad", "hemlagat", "äkta",
]);

export const APPROXIMATE_WORDS = [
  "ca", "cirka", "ungefär", "about", "approximately",
];

// Folded (å/ä/ö→a/o) — matched against the folded dish anchor.
export const DISH_QUALIFIERS = new Set([
  "gammaldags", "tunna", "tunn", "tunt", "mjuk", "mjuka", "mjukt", "kramig",
  "kramiga", "saftig", "saftiga", "nyttig", "nyttiga", "festlig", "festliga",
  "matig", "matiga", "krispig", "krispiga", "ugnsbakad", "ugnsbakade",
  "grillad", "grillade", "stekt", "stekta", "kokt", "kokta", "perfekt",
  "perfekta", "lyxig", "lyxiga", "billig", "billiga", "vardaglig",
  "vardagliga", "fina", "godaste", "allra",
]);

// Folded generic dish-category nouns → fail closed (do not pool).
export const GENERIC_ANCHORS = new Set([
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

/** Deterministic decomposition of a pool key into the pieces a telemetry
 *  consumer needs to distinguish an anchor-only title change from a real dish
 *  change (BUT-1518). */
export interface PoolKeyComponents {
  /** The full pool key (`VERSION:hash` of anchor + ingredient names). */
  poolKey: string;
  /** The dish anchor — the longest significant title token the key is built on;
   *  the cheap "rating-laundering" lever is editing the title to move THIS.
   *  NEVER log this in cleartext: a Swedish dish title can carry a personal name
   *  ("Farmors köttbullar") and telemetry is a log-only tier that must not see
   *  PII. Log `anchorSig` instead — laundering detection only needs to know the
   *  anchor CHANGED, which inequality of the hash proves exactly as well. */
  anchor: string;
  /** 8-hex sha256 of the anchor — the log-safe stand-in for `anchor`. Two events
   *  with the SAME anchorSig share a dish anchor; a moved anchorSig alongside a
   *  held ingredientSig is the anchor-only-title-change (laundering) signal. */
  anchorSig: string;
  /** 8-hex signature of the sorted, strengthened ingredient names ONLY (the
   *  anchor is excluded). Two of a recipe's events with the SAME ingredientSig
   *  but a DIFFERENT poolKey mean the ingredient set held while the anchor
   *  moved — an anchor-only title change — as opposed to a genuine dish change,
   *  where ingredientSig also shifts. */
  ingredientSig: string;
}

/**
 * Decompose a recipe into its pool-key components, or null in EXACTLY the cases
 * `computePoolKey` returns null (no surviving ingredient names, or no usable
 * dish anchor — fail closed). `computePoolKey` delegates here so the key stays
 * single-sourced: the aggregation path can log the anchor + ingredient
 * signature without forking the normalization (the C5 drift risk).
 */
export function poolKeyComponents(
  title: string,
  ingredients: string[]
): PoolKeyComponents | null {
  if (!ingredients || ingredients.length === 0) return null;

  const names = Array.from(
    new Set(
      ingredients.map(strengthenIngredientName).filter((s) => s.length > 0)
    )
  ).sort();
  if (names.length === 0) return null;

  const anchor = dishAnchor(title);
  if (anchor === null) return null;

  const joinedNames = names.slice(0, 12).join("|");
  const hash = createHash("sha256")
    .update(anchor + "::" + joinedNames, "utf8")
    .digest("hex")
    .substring(0, 16);
  const ingredientSig = createHash("sha256")
    .update(joinedNames, "utf8")
    .digest("hex")
    .substring(0, 8);
  const anchorSig = createHash("sha256")
    .update(anchor, "utf8")
    .digest("hex")
    .substring(0, 8);
  return { poolKey: VERSION + ":" + hash, anchor, anchorSig, ingredientSig };
}

/**
 * Compute the pool key for a recipe, or null if it must not pool (no ingredient
 * names survive, or no usable dish anchor — fail closed).
 */
export function computePoolKey(
  title: string,
  ingredients: string[]
): string | null {
  return poolKeyComponents(title, ingredients)?.poolKey ?? null;
}
