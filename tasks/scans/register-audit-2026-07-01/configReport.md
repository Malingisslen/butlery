All evidence gathered. Findings below.

# Allergen/Dietary Config Audit — Findings

Register stats (from `docs/tagging/data/Butlery_Ingredients_INGREDIENTS.csv`, 2230 rows): status = **1210 draft / 1003 validated / 13 verified / 4 needs-review** (54% draft confirmed).

---

## Q1 — Config ↔ CSV vocabulary reconciliation

**Config → CSV: clean.** All 19 distinct `triggerProperty` values in `AllergenConfig` (allergen_config.dart:69-232) and all excluded/required properties in `DietaryConfig` (dietary_config.dart:46-117) exist as rows in `Butlery_Ingredients_PROPERTIES.csv`. `PropertyRegistry.validateAllConfigs()` (property_registry.dart:108-155) enforces this at startup against its hardcoded set.

**CSV → Config: NOT clean.** Two animal/marine properties in the vocabulary are consumed by NO allergen or dietary config, so ingredients carrying only them silently never fire any verdict:

### [DANGER] `seafood` property fires no allergen and no dietary exclusion
- `seafood` (PROPERTIES.csv row 7, category `diet-base`) is absent from every `AllergenEntry.triggerProperty` (allergen_config.dart:69-232) and from every `DietaryEntry.excludedProperties` (dietary_config.dart:52, 91 use only `fish`/`crustacean`/`mollusc` — the comment at dietary_config.dart:50-51 even acknowledges the split).
- **6 live register rows carry `seafood` as their ONLY marine marker** (no fish/crustacean/mollusc): `skaldjursfond` (shellfish stock, status=**validated**), `tom-kha-paste` (typically contains shrimp paste, status=**validated**), `furikake` (contains fish flakes, draft), `jellyfish`, `sea-cucumber`, `sea-urchin` (draft).
- Consequence: a recipe with **skaldjursfond** at 100% coverage gets `skaldjursfri` = FREE (`getPropertyStatus`/`getCombinedPropertyStatus`, ingredient_lookup_result.dart:114-135 check only the listed properties), `fiskfri` = FREE, **and** `vegetarisk` = FREE, `kosheranpassad` = FREE. A shellfish stock marked free-from-shellfish is exactly the dangerous false-FREE the audit brief describes — and two of the six rows are validated, so the draft warning doesn't even show.

### [MEDIUM] Legacy `shellfish` property is a landmine (vocab row exists, zero coverage in config)
- `shellfish` exists in PROPERTIES.csv (row 15, `meat-detail`) and in `PropertyRegistry.validProperties` (property_registry.dart:44 as `seafood`… specifically `'seafood'` line 44; `shellfish` is NOT in the registry — see below), but the combined `skaldjur` allergen triggers only on `crustacean OR mollusc` (allergen_config.dart:220). Currently **0 ingredient rows use `shellfish`** (verified programmatically), so no live harm — but any future row tagged with the still-documented vocabulary property would produce false FREE verdicts for skaldjur/kräftdjur/blötdjur.
- Note asymmetry: `shellfish` is in the CSV vocabulary but **not** in `PropertyRegistry.validProperties` (property_registry.dart:14-62), while `wheat` (property_registry.dart:22) is in the registry but **not** in the CSV vocabulary and used by no config and no ingredient row. Registry and CSV vocabulary have drifted in both directions. [LOW for wheat]

Other vocab properties consumed by no config (`game`, `lamb`, `poultry`, `plant-based`, `vegan-friendly`, `processed`, `needs-cooking`, `doesnt-freeze-well`): intentional non-verdict metadata — no finding.

---

## Q2 — How `skaldjur` works

`skaldjur` is declared with `triggerProperty: 'crustacean OR mollusc'` (allergen_config.dart:218-224). `AllergenEntry.triggerProperties` splits on the case-insensitive `\s+OR\s+` regex (allergen_config.dart:50-58), `isCombined` routes it to the combined branch in `Phase1AllergenCalculator.calculate` (tag_phase1_allergen.dart:81-131), which calls `lookup.getCombinedPropertyStatus(props)` — CONTAINS if ANY matched ingredient has ANY of the two properties, FREE only at 100% coverage with neither (ingredient_lookup_result.dart:127-135).

**It covers crustacean AND mollusc, but NOT legacy `shellfish` and NOT `seafood`** — see Q1 findings.

---

## Q3 — `status='draft'` effect on verdicts

### [DANGER] Draft ingredients produce full CONTAINS/FREE verdicts, identical to verified — with only a cosmetic warning
- The verdict path never inspects `status`: `getPropertyStatus` (ingredient_lookup_result.dart:114-122) and `hasProperty`/`hasAnyProperty` (ingredient_lookup_result.dart:83-90) iterate all of `matched` regardless of status. A draft (AI-generated, unvalidated) ingredient with a missing `contains-gluten` property yields `glutenfri` = FREE.
- `hasDraftIngredients` is computed as `ingredients.matched.any((i) => i.status == 'draft')` in `tag_generator.dart:108` and `:324`, stored on `TagResult` (tag_result.dart:80, persisted at :359/:397), and surfaces **only** as a warning banner in `tag_result_display.dart:82-85` (`_buildDraftWarning`, :264). It does not downgrade any verdict to UNKNOWN, and with 54% of the register draft, over half of all allergen FREE verdicts rest on unvalidated data while displaying as authoritative.
- [LOW] Side note: 1003 rows have status `validated`, which is not in the documented enum `'verified', 'draft', 'needs-review', 'user-defined'` (ingredient_data.dart:69). `hasDraft` only checks `== 'draft'` so it happens to behave, but any future `status == 'verified'` check would treat 1003 validated rows as unverified.

---

## Q4 — Dietary rules consistency

### [DANGER] `vegetarisk` misses `animal-product` — gelatin is marked vegetarian
- `vegetarisk` excludes only `['meat', 'fish', 'crustacean', 'mollusc']` (dietary_config.dart:52). Register rows `gelatin` (properties: `animal-product` only, draft) and `gelatinblad` (`animal-product,processed`, **validated**) carry none of those four → a recipe with gelatin sheets at 100% coverage gets `vegetarisk` = FREE. Gelatin is not vegetarian. Same hole marks jellyfish/sea-urchin/skaldjursfond vegetarian (see Q1).

### [MEDIUM] `vegansk` hangs on a single property with no defense in depth
- `vegansk` excludes only `['animal-product']` (dietary_config.dart:58). Verified: currently **0** rows carry meat/fish/crustacean/mollusc/dairy/egg/seafood without also carrying `animal-product`, so no live hole — but one forgotten `animal-product` on any future row (54% of rows are AI-draft) silently makes it vegan. Belt-and-braces would be `['animal-product', 'meat', 'fish', 'crustacean', 'mollusc', 'dairy', 'egg', 'seafood']`.

### [LOW] `pescetarian` requiredProperties is dead logic
- Both the has-required and lacks-required branches return FREE (tag_phase1_dietary.dart:106-131, deliberate per HIGH-4 comment — vegetarian dishes are pescetarian-compatible). `requiredProperties: ['fish', 'crustacean', 'mollusc']` (dietary_config.dart:66) affects only the decision-log text. Consistent, just decorative. Note pescetarian also inherits the Q1 `seafood` gap only harmlessly (seafood isn't meat).

`halalanpassad`/`kosheranpassad`: kosher inherits the `seafood`-gap (skaldjursfond = kosheranpassad FREE, dietary_config.dart:91) — folded into the Q1 DANGER finding.

---

## Q5 — `excludes_tags` column

**Documentation-only.** A repo-wide search for `excludes_tags`/`excludesTags` matches exactly one line: the CSV header itself (`Butlery_Ingredients_PROPERTIES.csv:1`). No Dart, TypeScript, or tool code parses it. The actual exclusion logic lives entirely in `DietaryConfig`/`AllergenConfig`, and the column's values reference tag ids (`vegan`, `halal`, `gluten-free`, `fish-allergy`, `shellfish-allergy`) that exist nowhere in the verdict pipeline. [LOW] — but note it falsely suggests to a data editor that filling it in has effect.

---

## Q6 — Canonical-vs-alias precedence and determinism

Lookup order in `IngredientLookupService._performLookup` (ingredient_lookup_service.dart:168-201): (1) user-defined ingredients override everything (:174-179), (2) global exact name, (3) global alias, (4) fuzzy variations.

Inside `FirebaseIngredientRepository.findByName` (firebase_ingredient_repository.dart:264-302): Swedish name index → English name index → alias index → fuzzy. So **a row's canonical name always beats another row's alias** for the same string — the alias is shadowed and can never match.

Determinism of duplicates:
- Indexes are plain `Map<String, String>` populated in `_doLoadCache` (firebase_ingredient_repository.dart:163-165 → `_addToCache` :186-231). Duplicate keys **overwrite**, so the last-loaded row wins. `snapshot.docs` from an unordered `.get()` comes back in Firestore's default document-ID (lexicographic) order → **deterministic** (row with the lexicographically greatest doc ID wins) but **arbitrary and silent** — no log when an alias or name collides. [MEDIUM] Two rows sharing an alias with different allergen properties resolve by doc-ID alphabet, and status (validated vs draft) plays no role in the tie-break.
- `findByAlias` returns at most one element (:437-443), so the `.first` calls at ingredient_lookup_service.dart:188/:197 are safe.

---

### Severity summary
| # | Severity | Finding |
|---|---|---|
| 1 | DANGER | `seafood`-only ingredients (incl. validated `skaldjursfond`, `tom-kha-paste`) fire no allergen → false `skaldjursfri`/`fiskfri` FREE |
| 2 | DANGER | Draft (AI-unvalidated) ingredients produce full FREE/CONTAINS verdicts; 54% of register is draft; only a UI banner |
| 3 | DANGER | `vegetarisk` misses `animal-product` → gelatin (validated `gelatinblad`) marked vegetarian |
| 4 | MEDIUM | `vegansk` = single-property (`animal-product`) with no redundancy against draft data errors |
| 5 | MEDIUM | Legacy `shellfish` vocab property covered by no config (0 rows today; landmine); registry/CSV vocab drift both ways (`wheat`, `shellfish`) |
| 6 | MEDIUM | Duplicate name/alias collisions resolved silently by doc-ID order, ignoring validation status |
| 7 | LOW | `excludes_tags` column is dead documentation |
| 8 | LOW | `status='validated'` (1003 rows) absent from the documented status enum; `pescetarian.requiredProperties` is dead logic |