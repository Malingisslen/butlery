# Parsing & tagging golden tests

End-to-end regression suite for the recipe parsing pipeline. Each entry in
`parsing_golden_dataset.json` exercises one tier of the parser (`SchemaOrgTier`,
`RuleBasedTier`, or `LlmTier`) against a frozen Swedish-recipe input and a set
of expected-shape assertions.

## Why this exists

A model bump on Gemini, a prompt edit, or a regex tweak in the rule-based parser
can silently regress extraction quality with no other test signal. This suite locks
the user-visible contract: given input X, the tier produces a recipe with title
containing Y, ≥N ingredients, etc. (Tier architecture: `docs/parser/PARSER_ARCHITECTURE.md`.)

Assertions are intentionally **loose** (substring contains / count
greater-than) so the suite survives:

- a 4 px formatter change in the JSON-LD scraper,
- a renamed internal getter,
- a Gemini prompt that re-orders ingredients,
- a rule-based parser refactor that splits one ingredient into two.

It does **not** survive: missing key data (no title), wrong portions, or
crashes inside the tier.

## Dataset entry shape

```json
{
  "id": "rulebased-pannkakor-header-list",
  "tier": "ruleBased",                 // schemaOrg | ruleBased | llm
  "text": "Klassiska pannkakor\n\n…",  // ruleBased / llm only
  "domain": "ica.se",                   // schemaOrg only
  "fixture": "IcaTestFixtures.kottbullarComplete",  // schemaOrg only
  "mockResponse": { … ExtractedRecipe JSON … },     // llm only
  "expected": {
    "titleContains": "pannkakor",
    "portions": 4,
    "ingredientCountMin": 5,
    "ingredientSubstrings": ["3 dl vetemjöl", "1/2 tsk salt"],
    "instructionCountMin": 3,
    "instructionSubstrings": ["vispa"],
    "totalTimeMinutes": 45,
    "minQuality": 0.3
  }
}
```

All `expected` fields are optional. If you don't include a key, that field
isn't asserted. Keep assertions to behaviour the user notices — title,
counts, substrings — not implementation details.

## Tier seams

| Tier | Input | Mock seam |
|---|---|---|
| `SchemaOrgTier` | HTML fixture (loaded from `test/fixtures/swedish_sites/*`) | None — uses the real JSON-LD parser |
| `RuleBasedTier` | Inline plaintext (`text` field) | None — uses the real Swedish line classifier |
| `LlmTier` | Inline plaintext (`text`) + canned `ExtractedRecipe` (`mockResponse`) | `_GoldenMockLlmService` replaces `LlmService.structureRecipe` |

The LLM mock seam is at the **service level**, not the HTTP/Cloud Functions
level — the `httpsCallable` envelope and `LlmException.fromFirebase` are covered
separately by `test/unit/services/llm/llm_service_test.dart`. This suite locks the
**tier-level** contract: given a known LLM response, does `LlmTier` validate,
normalize, and shape it into the right `ParsedRecipe`?

## Recording a new LLM fixture from real Gemini

Don't hit real Gemini in CI. Record once locally, commit the JSON, replay
deterministically.

1. Run the recipe through real Gemini (e.g. via the import flow in the app
   with logging on `LlmService.structureRecipe`'s response).
2. Capture the `recipe` field of the `StructureRecipeResponse` — it
   matches `ExtractedRecipe.toJson()` shape: `title`, `portions`,
   `prepTimeMinutes`, `cookTimeMinutes`, `ingredients` (each with
   `amount`/`unit`/`name`/`preparation`), `instructions`, optional `tags`
   /`difficulty`/`source`.
3. Add a new entry to `parsing_golden_dataset.json` with `tier: "llm"`,
   the source `text` you fed Gemini, and the captured JSON in
   `mockResponse`.
4. Add `expected` assertions covering title substring, portion count, and
   2-3 ingredient substrings. Be loose — Gemini will re-word things on
   future runs and the recorded JSON pins one specific output.

## Replaying

`flutter test test/golden/parsing_golden_test.dart` — runs all entries.
Each test is independent and finishes in <100 ms (no network, no Firebase).

## Adding a new RuleBasedTier fixture

1. Pick a Swedish recipe shape that exercises a parser branch the existing
   fixtures don't (new unit, weird header, prose blob, allergen note,
   etc.).
2. Add an entry with `tier: "ruleBased"` and inline `text`.
3. Run the test once — it will fail and print what the tier actually
   produced (count + substrings).
4. Tune `expected` to match real behaviour, not idealised behaviour. If
   the tier passes a header line through as an ingredient
   (`"Det här behövs:"` is a real example), capture that — don't write an
   aspirational assertion.
5. Keep `ingredientCountMin` 1-2 below the actual count so the test
   doesn't break when a future tweak merges or splits one line.

## Tagging golden suite

`tagging_golden_test.dart` (separate file) covers the auto-tag pipeline
with the same dataset-driven shape. Same philosophy: lock the tag the
user sees, not the internal scoring path.
