# Ingredient Section Headers (recipe sub-groups like "Deg" / "Fyllning" / "Glasyr")

> After approval: copy this plan to `tasks/todo.md` (workflow-discipline requirement) before starting chunk 1.

## Context

Recipes with multiple components (sponge + icing, dough + filling) currently import and display as one flat ingredient list. The pipeline already *detects* Swedish section headings at import (line classifier, section-detector vocabulary, and the Gemini prompt) but throws the information away — the Gemini prompt even flattens group names into the free-text `preparation` field for lack of a proper slot. Malin decided: build it as **one feature — capture at import + display + full editing** (no read-only phase; heuristic-detected headings must be user-correctable from day one).

Stakeholder router verdict: **full-panel** (12 roles). Panel result: **no blocks**; all conditions are folded in below as binding acceptance criteria.

## Decided design (do not re-litigate)

- New optional `section: String?` on `RecipeIngredient` + `ParsedIngredient`, serialized only inside the existing `structuredIngredients` array. **The flat `ingredients` List<String> NEVER contains heading lines** (allergen tagging reads it — this is the safety invariant of the whole feature). No schemaVersion bump (additive optional key; old readers ignore it), no Firestore migration, no rules change, no new collections/indexes.
- Contiguous runs of the same `section` value render as one subheading. Missing/misaligned section data → render exactly as today (fail open).
- Sections persist through duplication/sharing/collaborative editing (they're part of the recipe doc). Shopping aggregation ignores sections (sugar in Deg + Fyllning still merges). Old recipes stay flat unless re-imported or manually sectioned in the form ("Lägg till rubrik" works on any recipe).
- Capture is gated behind one kill-switch feature flag (`ingredient_section_capture`, default on) using the existing feature-flag service — rollback lever if heuristics misfire broadly (PM condition). Display/editing always on (inert without data).

## Design summary

**Data (chunks 1–2).** `section` field + JSON round-trip in `recipe_ingredient.dart` (via SerializationUtils, `copyWithSection` to avoid null-vs-unset ambiguity) and `parsed_ingredient.dart`. `structured_ingredient_deriver.dart`: `deriveAll(lines, {reuse, sections})` where `sections` is authoritative; **fix the byRaw reuse collision** (duplicate raw lines like "1 dl socker" under two headings) with a FIFO multimap (`Map<String, Queue<RecipeIngredient>>`). `recipe_operations.dart`: in-place edit preserves old entry's section; append inherits the last section; full line rewrite drops section→null (accepted degradation).

**Import capture (chunks 3–6).**
- *Cloud (LLM)*: `section` (nullable STRING) added to `INGREDIENT_SCHEMA` in `gemini-client.ts`; replace the flatten-into-preparation rule (line ~268) with a section-field rule + explicit "don't duplicate the group name in preparation"; rework EXEMPEL 4. `PROMPT_VERSION` 2.2.0 → **3.0.0 (MAJOR — schema change)** + `PROMPT_CHANGELOG.md` entry (hard gate; `prompt-changelog-guard.test.ts` enforces sync). Covers extract, OCR (printed + handwritten), spoken — all share the schema. **No new LLM calls, no model change (stays gemini-2.5-flash-lite), no rate-limiter weight change, no free-text elaboration in the schema.**
- *Client LLM bridge*: `ExtractedIngredient.section` → `ParsedIngredient`; **fix `llm_tier._deduplicateIngredients`** to key on `name|section` so same-name ingredients in different sections never merge.
- *Text/social*: `swedish_line_classifier.dart` — the `sectionHeader` discard (`break` at ~304) becomes "set currentSection" for ingredient-side sub-headers; `ParsedRecipeStructure` gains index-aligned `ingredientSections` (incl. isolate serialization); applied post-`parseLines` in `rule_based_tier.dart`.
- *schema.org*: conservative pre-scan in `schema_org_tier._extractIngredients`: heading iff (trailing `:` OR RecipeSectionDetector vocabulary) AND no digit AND no Swedish unit token AND length ≤ 40 AND a line follows. **Every uncertain case stays an ingredient** — a false heading would remove an allergen-bearing line from tagging input, the one direction we must never err.

**Display (chunks 7–8).** New sealed `IngredientDisplayRow` (heading|line, ~70 lines, `lib/models/recipe/ingredient_display_row.dart`); `build(structured, displayLines)` fails open on length mismatch; works because `PortionScalerLogic.scaleEntries` preserves 1:1 order. Cooking mode: rows cached in the viewmodel (ctor + `updatePortions`), headings excluded from the substitution long-press. Detail view: computed + memoized inside `RecipeDetailContent` (it already receives both inputs; threading a channel through `recipe_detail_actions` would touch 4 files for nothing). Tablet reuses the same widget — zero changes.

**Editing (chunks 9–11).** Sidecar row model — `FormFieldsManager` stays line-only (shared with instructions/tags; only gains a `moveAt` primitive). New `IngredientSectionState` (~220 lines, new file) owns the ordered row list (`HeadingRow(id)` | `LineRow` markers), heading controllers, `sectionsForValues()` (single derivation point at save), `seedFromStructured()`, reorder row→line index mapping (adjust once, §test matrix), caps (max 20 headings, 60 chars). `RecipeFormState.createRecipe` filters values+sections in lockstep; **new `_seedStructured` field captured even for `isTemplate` loads — closes the discovered gap where imported sections would be silently dropped on first save** (template loads null out `_originalRecipe`, emptying the deriver's reuse). Collaborative sync needs no payload change (`syncToCollaborative` already ships full `createRecipe()` output; old clients ignore the unknown key). New `SectionedIngredientListBuilder` widget (~280 lines, new file) for ingredients only — `DynamicListBuilder` untouched for instructions/tags. Auto-append keys to the last *LineRow*; heading ValueKeys are id-stable (`hdr_${id}`), line keys index-based as today.

Form wireframe:
```
Ingrediens
┌──────────────────────────────────────┐
│ ≡  ▐ DEG                        [🗑] │   ← heading row (tinted, bold, no quantity)
│ ≡  5 dl vetemjöl                [🗑] │
│ ≡  25 g jäst                    [🗑] │
│ ≡  ▐ FYLLNING                   [🗑] │
│ ≡  75 g rumsvarmt smör          [🗑] │
│ ≡  (tom rad — auto-append)           │
└──────────────────────────────────────┘
[ + Lägg till rubrik ]
```
Detail view:
```
INGREDIENSER            [– 4 port +]
──────────────────────────────────
DEG                                ← Semantics(header: true), titleSmall bold
   5 dl │ vetemjöl            ⇄
  25 g  │ jäst                ⇄
FYLLNING
  75 g  │ smör, rumsvarmt     ⇄
```
All styling via theme tokens (AppTextStyles, butleryColors, theme spacing; square design — no radius). New l10n keys in BOTH `app_sv.arb` + `app_en.arb`, butler voice (no exclamation marks): `recipeIngredientHeadingHint` ("Rubrik, t.ex. Deg"), `recipeAddIngredientHeading` ("Lägg till rubrik"), `a11yRemoveIngredientHeading`, `recipeMoveToSection` ("Flytta till rubrik").

## Binding acceptance criteria (from the stakeholder panel — these are gates, not notes)

**Safety / allergen (Data-ML, Legal, Architect):**
1. Test: `createRecipe().ingredients` and every import path's flat list contain no heading text, ever; a sectioned recipe produces the identical allergen/tagging result as its unsectioned twin (extend tagging_service suite).
2. Test: no code path emits a `structuredIngredients` entry for a heading line (alignment invariant `entry.raw == ingredients[i]` extended to cover section presence).
3. Test: section label text never feeds CONTAINS/FREE verdict logic.
4. ≥15 new golden fixture cases for ambiguous headers ("Till glasyren:", "2 såser:", unit-bearing colon lines) proving the schema.org heuristic fails open; re-run the swedish_line_classifier golden set and re-verify (don't carry over) the "100% validation" claim in PARSER_ARCHITECTURE.md.

**Round-trip integrity (Data-Integrations, Architect, Performance):**
5. FIFO reuse test: two identical raw lines under different headings keep distinct sections through edit/reorder (byRaw fix).
6. Test: same raw text moved from section A to B on save persists B (sections param authoritative over reuse).
7. Round-trip test: import → edit (add/remove/reorder heading) → save → reload keeps `structuredIngredients[i].section` aligned with flat position; scale-up/down/save cycle preserves sections (scaler passes field through, never re-derives from position).
8. Template/import save path test: LLM-captured sections survive first save (`_seedStructured`).

**Security:**
9. `section` capped at 60 chars in the form AND truncated server-side in the CF output-shaping step (Gemini responseSchema can't enforce length). Rendered via plain `Text` widgets only — verify no HTML/markdown renderer in the path.
10. Follow-up ticket (not this PR, required before GA): server-side shape validation for `structuredIngredients` entries — today the array is wholly client-controlled at the trust boundary.

**Accessibility:**
11. Heading rows carry `Semantics(header: true)` + localized labels in form, detail, and cooking mode (verify via `find.bySemanticsLabel` / `tester.ensureSemantics()`); heading delete button announces "ta bort rubrik", not the ingredient-delete label.
12. Non-drag section reassignment: ingredient rows get a "Flytta till rubrik…" action (overflow/long-press menu, shown when ≥1 heading exists) — drag-only would be WCAG 2.1.1-inaccessible. Inline heading rename tap target ≥ 48dp.

**LLM / cost / vendor (FinOps, Vendor, Privacy, Monetization):**
13. PROMPT_VERSION 3.0.0 + changelog entry in the same commit (guard test enforces); before/after run on the existing sample-capture loop to confirm no exact-match-rate regression and no group-word duplication in `preparation`.
14. No new LLM calls, no model tier change, no rate-limiter weight change; token growth rides existing cost telemetry (verify `estimatedCost` still logged).
15. Verify the GDPR export path has no field allowlist on `structuredIngredients` that would drop `section` (Art. 15 completeness).

**Product (PM):**
16. Defined empty-heading behavior: headings with no following lines are form-only artifacts, produce nothing at save (documented in `IngredientSectionState`); delete-heading merges lines into the previous section, immediate, no dialog.
17. Manual sectioning affordance ("Lägg till rubrik") available in the edit form for existing recipes — in scope, chunk 11.
18. Lightweight analytics event: recipe saved with ≥1 section (existing AnalyticsEvents infra).
19. Kill-switch flag `ingredient_section_capture` gates all three capture points.

## Implementation chunks (≤3 prod files each, per agent-timeout guidance; commit each with its gates)

| # | Files | What |
|---|---|---|
| 1 | recipe_ingredient.dart, parsed_ingredient.dart, structured_ingredient_deriver.dart | `section` field + serialization + `copyWithSection`; deriveAll(sections:) authoritative; FIFO byRaw fix |
| 2 | recipe_operations.dart (+tests) | edit ops preserve/inherit section; recipe JSON/Firestore round-trip tests (recipe_unified needs no code change) |
| 3 | gemini-client.ts, PROMPT_CHANGELOG.md | schema + prompt rule + EXEMPEL 4; v3.0.0; CF-side 60-char truncation |
| 4 | llm_models.dart, ingredient_conversion.dart, llm_tier.dart | ExtractedIngredient.section; cross-section dedup fix |
| 5 | swedish_line_classifier.dart, rule_based_tier.dart | keep sub-headers as section context; `ingredientSections` incl. isolate round-trip |
| 6 | schema_org_tier.dart (+ recipe_section_detector.dart helper if needed) | conservative fail-open heuristic; flag-gated |
| 7 | ingredient_display_row.dart (new), cooking_mode_viewmodel.dart, cooking_mode_view.dart | display rows + cooking-mode panel |
| 8 | recipe_detail_content.dart | memoized rows + heading rendering (HTML preview via `docs/design/previews/_butlery-template.html` first — one preview covering BOTH the detail-view heading style and the form heading row used in chunk 11) |
| 9 | ingredient_section_state.dart (new), form_fields_manager.dart | sidecar row model; `moveAt` primitive (reorderAt refactored, existing callers identical) |
| 10 | recipe_form_state.dart, recipe_backward_compatibility_mixin.dart | seed/save/draft wiring; heading mutation API + syncToCollaborative |
| 11 | sectioned_ingredient_list_builder.dart (new), edit_recipe_view.dart, skriv_sjalv_recept_view.dart (+2 .arb, gen-l10n) | form UI incl. "Flytta till rubrik" non-drag path; per `.claude/rules/html-previews.md`, add the heading-row / sectioned-list component to `_butlery-components.html` (approved via the chunk-8 preview) before writing the Dart widget |
| 12 | tests only | cross-cutting: allergen twin test, aggregator ignores sections, golden fixtures |

New logic lives in the three new files — `recipe_form_state.dart` (803 lines) and `recipe_detail_content.dart` (859) get thin wiring only (both on/near the accepted-large-files list; check rationale rows before touching). If `recipe_operations.dart` (465) tips over 500 in chunk 2, split the facade then, not later.

## Verification (per CLAUDE.md rule #5 — part of the work)

- Per chunk: `dart analyze --fatal-infos` clean; the named test suites in the chunk pass; **plus `flutter test test/architecture/architecture_test.dart` locally before every push** (3×-recurring lesson: `?? ''` ban, raw-spinner ban, EdgeInsetsDirectional guard, AppColors keep-set grep — live risks in chunks 7/8/11) and a quick `git diff | grep "?? ''"` self-check on UI chunks; commit gates: code-reviewer + testing-specialist markers on all Dart chunks; cloud-functions-specialist on chunk 3; `/code-review high` (xhigh for chunk 3 per CLAUDE.md).
- Watch for `docs/onboarding/workflow-map.stale` after edits to mapped import/parsing code — if stamped, re-trace only the triggered flows, update the map JSON, run `tools/check_workflow_map.py`, delete the marker, commit both (CLAUDE.md rule).
- End-to-end (`/verify` before final commit): in Chrome — import a text recipe with "Deg:/Fyllning:" headings → headings appear in detail view; open in edit form → rename a heading, drag an ingredient across it, save → detail reflects it; scale portions → headings intact; add the recipe to a shopping list → duplicated ingredient names merged (no section split); recipe without sections renders pixel-identical to today.
- Full-suite runs for touched areas (per lessons.md: run EVERY existing suite constructing changed classes — especially recipe_form_state/viewmodel suites after chunk 10).

## Risks

- **Old-client collaborative save wipes sections** (re-derives structuredIngredients without the field): accepted graceful degradation — no crash, flat list intact; next sectioned edit restores. Release-note it.
- **Prompt MAJOR bump regression**: mitigated by the explicit no-duplication rule, reworked example, and the before/after sample run (criterion 13).
- **Mixed-row reorder is new surface**: pinned by the 4-way direction/type test matrix + drag-across-heading test; heading keys id-stable to avoid controller detach mid-drag.
- **Draft restore loses empty (line-less) headings**: accepted, documented.

## Follow-ups (out of scope, to ticket)

- Server-side validation of `structuredIngredients` entry shape (security criterion 10).
- Telemetry counter for schema.org heading-heuristic hits/rejections (flywheel visibility).
- Consider sections in share/print output (render headings in `share_service` / print HTML) — cosmetic, separate small ticket.

## What this means in plain language

- Recipes like kanelbullar will show their ingredients under small headings — "Deg", "Fyllning", "Glasyr" — instead of one long mixed list, both on the recipe page and in cooking mode.
- New recipes you import get these headings automatically when the original recipe has them; your existing recipes stay exactly as they are until you re-import or add headings yourself.
- In the recipe editor you can add a heading anywhere, rename it, delete it, and drag ingredients between sections — so if the app guesses a heading wrong, you can always fix it.
- Shopping lists and allergy warnings work exactly as before — headings can never sneak in as fake ingredients, and we prove that with automatic tests.
- There's an off-switch: if the automatic heading detection misbehaves after launch, we can turn the detection off remotely without an app update.
- Running costs stay basically zero — no new AI calls, just a tiny bit of extra text on calls that already happen.
- If something goes wrong it's easy to undo: old recipes are untouched, and the whole thing degrades back to today's flat list.
