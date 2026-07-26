# performance-optimizer — raw record (append-only)

Dated entries with device class, before/after measurements, and the concrete code
change. The distilled principles live in `performance-optimizer.knowledge.md`;
this file is what you grep when a principle is too compressed to explain what
you are seeing. **Never delete an entry — supersede it with a newer dated one.**

---

## 2026-07-25 — BUT-1661/BUT-1662 efficiency pass (review only, nothing fixed)

**Scope**: staged diff over `recipe_section_detector.dart`,
`export_pagination_helper.dart`, `content_export_manager.dart`,
`activity_export_manager.dart`, `weekly_menu_plan_service.dart`.
**Device class**: none — static review, no profiler run. No before/after numbers;
all costs below are counted from the code, not measured.

**1. Partial regex hoist (the diff's own blind spot).**
`recipe_section_detector.dart` correctly lifted 26 Swedish/English ingredient-word
patterns to `static final _ingredientWordPatterns` (they had been built inside
`looksLikeIngredient` via `RegExp('\\b$word\\b')` per call — and `\b` being
ASCII-only was the BUT-1661 bug being fixed). But four sibling `RegExp(...)`
literals in the SAME method were left inline: the Swedish measurement pattern
(:389), the English measurement pattern (:396), the fraction class (:403), and
the bullet-prefix pattern (:415). `hasRecipeStructure` (:459, :462, :465) has
three more.
Counted cost: `looksLikeIngredient` is called once per line in loops at
`multi_recipe_splitter.dart:76,120,173` and `text_import_strategy.dart:376,540`,
so a 100-line recipe import compiles ~400 throwaway RegExp objects (two of them
non-trivial alternations of 13 and 11 units). Not measured on device; the import
path is user-visible ("Importera recept" spinner), and only the structural
rule-based tier is on an isolate — `text_import_strategy` is not.
Recommended change (not applied): four more `static final` fields.

**2. `.any()` over N compiled patterns = N scans.**
Even after hoisting, a non-ingredient line runs all 26 `hasMatch` passes before
returning false (worst case is the common case — most lines are not ingredients).
One alternation, `RegExp('(?<![a-zåäö0-9])(mjöl|socker|…|pepper)(?![a-zåäö0-9])')`,
is a single pass and keeps the same Unicode-safe boundaries. Deferred as churn on
code that had just passed correctness review.

**3. `toLowerCase()` inside the `.any()` closure.**
`hasIngredientKeywords` (:430) and `hasInstructionKeywords` (:451) both call
`text.toLowerCase()` *inside* the closure, so the whole input is re-lowercased once
per keyword — 6× and 12× respectively. `text_import_strategy.dart:56-57` calls both
on the entire normalised recipe body, so an 8 KB paste allocates ~144 KB of throwaway
strings just to answer "is this a recipe?". Pre-existing, untouched by the diff.
Also `keyword.toLowerCase()` on literals that are already lowercase.

**4. False cost claim in a doc comment.**
`export_pagination_helper.dart:232` documents `fetchCapped` as costing "exactly one
extra document read per section". Verified false at two of the thirteen call sites:
`exportRecipes` (`content_export_manager.dart:98` and `:115`) and `exportMenus`
(`:149` and `:161`) each run two `fetchCapped` calls, so two probe rows per section;
and `exportShoppingLists` (`:190`) probes
`FirebaseDataExportRepository.exportPersonalShoppingLists`, which fetches an `items`
subcollection per returned list row (`firebase_data_export_repository.dart:230-233`,
`maxItemsPerList = 500`). The probe row there costs 1 list doc plus up to 500 item
docs, and `sublist(0, cap)` then discards all of it. The N+1 probe itself is
intended design (BUT-1562/BUT-1662) and correct — only the comment is wrong.
Recommended wording: "one extra row per sub-query; that row may itself pull a
subcollection."

**5. Sequential independent reads.**
`exportRecipes` awaits the personal subcollection query, then the top-level
owner query; `exportMenus` awaits personal, then shared. Each pair is independent
and could be `Future.wait`ed — the idiom is already used two files away at
`activity_export_manager.dart:59`. Marginal, because
`DataExportService.exportAllUserData` already runs the sections concurrently
(`Future.wait(..., eagerError: true)`), so the saving is one round-trip on the
critical path of whichever section is slowest. Reported, not applied.

**Clean**: `weekly_menu_plan_service.dart:318-323` (the BUT-1668 anchor guard is one
integer comparison inside a loop that already runs, and it makes the loop do *less*
work by skipping the map/slot lookups for a stale pin) and
`activity_export_manager.dart:106-119` (net -1 call, no added work).
