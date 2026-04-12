# Sprint Backlog

## Sprint: Veckomeny Constraint Parser — 2026-04-11

**Goal:** Replace the count-only regex parser in `MenuService.generateMenuFromPrompt` with a deterministic, lexicon-driven Swedish constraint parser. Users can write rich prompts (allergens, dieter, cuisines, formats, themes, time limits, day-anchored idioms like *tacofredag*). A transparent extraction-chip strip above the calendar shows what was understood, with amber chips for anything that wasn't — no silent failures, no LLM cost. Pre-production: lexicon ships as code (sprint 1) behind a `LexiconProvider` interface so a follow-up sprint can swap in a Google-Sheet-sourced Firestore overlay (BUT-360, to be filed) without parser changes.

**Plan file:** `C:\Users\malla\.claude\plans\tranquil-zooming-codd.md`

### Agent A: flutter-developer — Models + Lexicon scaffold

- [ ] **A1. Value classes** — `lib/models/menu/parsed_menu_request.dart`: `ParsedMenuRequest`, `SlotRequest`, `RecipeConstraint`, `DayPin`, `ExtractionTrace`, `TraceEntry`. Immutable, equatable. Const constructors where possible. (BUT-359)

- [ ] **A2. LexiconProvider interface** — `lib/services/menu/parser/lexicon_provider.dart`: `LexiconCategory` enum (18 entries), `Lexicon` value class with `of(category)` lookup + `mergedWith(overlay)` method, `abstract class LexiconProvider { Future<Lexicon> load(); }`. Sprint 2 will add `FirestoreLexiconProvider` against this interface — keep the surface minimal. (BUT-359)

- [ ] **A3. CodeLexiconProvider seed** — `lib/services/menu/parser/code_lexicon_provider.dart`: 18 `static const Map<String, String>` fields with the ~250 seed stems from the plan (numbers, vagueQuantity, everydayPhrases, mealStems, dietaryStems, allergenFreeStems, allergenNounStems, negationWords, cuisineStems, formatStems, verbObjectMap, themeStems, timeKeywords, dayNames, dayIdioms, subdivisionWords, politePreamble, skipFrukostMarkers). All canonical values verified against `AllergenConfig.allKeys`, `DietaryConfig.all`, `CuisineConfig.cuisines`. (BUT-359)

- [ ] **A4. DI registration** — `lib/core/di/modules/content_module.dart`: register `LexiconProvider` interface → `CodeLexiconProvider` impl as lazy singleton. Verify dependency order: must register before `MenuService`. (BUT-359)

### Agent B: flutter-developer — Parser engine

- [ ] **B1. Text normalizer** — `lib/services/menu/parser/text_normalizer.dart`: `normalize(input)` (lowercase + NFC + collapse whitespace + strip trailing punctuation), `stripDiacritics`, `stripPolitePreamble(words)`, `levenshtein1Lookup(token, candidates)` with bigram pre-index for sub-millisecond fallback on tokens ≥6 chars. Pure functions, no state. (BUT-359)

- [ ] **B2. MenuConstraintParser engine** — `lib/services/menu/parser/menu_constraint_parser.dart`: `static ParsedMenuRequest parse(String prompt, Lexicon lexicon)`. Implement the 7-step pipeline from the plan: normalize → extract globals (negations, dietary, day idioms, day-name+format pins) → clause-split on `[,;] | och | samt | plus` → per-clause (count + meal + subdivision + modifier sweep) → second-pass verb+object → trace assembly → return. Handle `den ena ... den andra`, soft markers (helst/gärna/minst), range counts (`2-3`, `två till tre`), vague quantities, everyday phrases (`varje dag`, `hela veckan`). (BUT-359)

- [ ] **B3. Parser unit tests** — `test/unit/services/menu/menu_constraint_parser_test.dart`: 80+ test cases organized by taxonomy group (counts, meal types, dietary, allergens, cuisines, formats and verbs, time, day pins, themes, subdivisions, skip frukost, robustness, graceful failure, full motivating example). Each test asserts a single specific behaviour. Pure Dart, no Firebase. (BUT-359)

- [ ] **B4. Normalizer + lexicon tests** — `test/unit/services/menu/parser/text_normalizer_test.dart` (lowercase, NFC, diacritic strip, levenshtein lookup, polite-preamble stripping doesn't eat real content) + `test/unit/services/menu/parser/code_lexicon_provider_test.dart` (no duplicate stems within a category, all canonical values exist in their respective tagging configs). (BUT-359)

### Agent C: flutter-developer — MenuService + distribution integration

- [ ] **C1. MenuService.generateMenuFromParsedRequest** — `lib/services/menu_service.dart`: add the new method per the plan. Reuse `_weightedSelect`, `_enforceCuisineDiversity`, `SeasonUtils.currentSeasonTag`. Implement `_passesGlobals` (allergen + dietary), `_matchesConstraint` (dietary, allergen, requiredTags, requiredCuisines via `CuisineConfig.extractCuisineTag`, maxTimeMinutes via `recipe.timeInMinutes ?? totalTime`). Place day pins first (so tacofredag wins). Soft constraint fallback to unconstrained slot pool. (BUT-359)

- [ ] **C2. Wire the parser into the existing entrypoint** — `MenuService.generateMenuFromPrompt` becomes a thin wrapper: load lexicon (cached on first use via injected `LexiconProvider`), call `MenuConstraintParser.parse`, return early if `isEmpty`, otherwise delegate to `generateMenuFromParsedRequest`. Constructor or setter inject `LexiconProvider`. Backwards-compatible: count-only prompts still produce identical results because empty `RecipeConstraint`s pass `_matchesConstraint`. (BUT-359)

- [ ] **C3. Distribution layer learns DayPin** — `lib/services/menu/weekly_menu_plan_service.distributeFromGeneratedMenu`: new optional param `List<DayPin> dayPins = const []`. Place pinned recipes on their pinned weekday/slot first; remaining recipes flow into the existing today-anchored chronological fill. Output shape unchanged. Update existing tests; add new test for tacofredag pinning. (BUT-359)

- [ ] **C4. Service-layer integration tests** — `test/unit/services/menu_service_parsed_request_test.dart`: hand-built recipe pool with diverse `TagResult`. Assert: dietary filter respected, allergen filter respected, global filter applies to every slot, soft constraint falls back when hard match empty, cuisine diversity preserved, day pin placement, time-bound filter. Mocktail pattern from existing `menu_viewmodel_test.dart`. (BUT-359)

### Agent D: flutter-developer + uiux-designer — Extraction chips UI

- [ ] **D1. ParsedExtractionChips widget** — `lib/widgets/menu/parsed_extraction_chips.dart`: stateless. Renders nothing when `parsed == null`. When present: green pill chips for `trace.understood` (icon per category), amber pill chips for `trace.notUnderstood`, "Förfina prompten" link only when warnings/notUnderstood present. Reuses existing pill-chip widget from the design system — no new theme tokens, SQUARE corners. Theme constants only. (BUT-359)

- [ ] **D2. ViewModel surface** — `lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart`: expose latest `ParsedMenuRequest?` (set after each successful generation). Notify listeners. Guard async gaps with `if (isDisposed) return`. (BUT-359)

- [ ] **D3. Calendar widget integration** — `lib/widgets/menu/calendar_weekly_menu_widget.dart`: render `ParsedExtractionChips` strip above the day grid when the ViewModel exposes a parse. No layout shift when parse is null. (BUT-359)

- [ ] **D4. Localization** — `lib/l10n/app_sv.arb` + `lib/l10n/app_en.arb`: keys `weeklyMenuChipsHeading` ("Vi förstod:"), `weeklyMenuChipsHeadingNotUnderstood` ("Vi förstod inte:"), `weeklyMenuChipsRefinePrompt` ("Förfina prompten"), category labels for trace icons. Both languages. (BUT-359)

### Post-Sprint Steps

- [ ] Run `dart analyze --fatal-infos`
- [ ] Run `flutter test test/unit/services/menu/ test/unit/services/menu_service_parsed_request_test.dart test/unit/viewmodels/menu_viewmodel_test.dart`
- [ ] Chrome end-to-end with the prompts from the plan's verification section (full motivating example, tacofredag, snabba middagar max 30 min, vague intentional, legacy "3 middagar")
- [ ] Canonical-tag check: confirm whether `matlåda`, `snabb`, `bröd`, `vardagsmat` exist in the canonical tag set; file follow-up note if any are missing
- [ ] Commit, push, PR, merge
- [ ] File BUT-360 in Linear: "Google Sheet → Firestore overlay for menu_lexicon (mirror ingredient pipeline)"
- [ ] Update Linear: BUT-359 → Done

---

## What this means in plain language

- You can write your weekly menu prompt the way you'd say it out loud — *"3 middagar varav en glutenfri och två matlådor, 4 luncher där en är vegansk och en italiensk, tacofredag, inget jordnötter, baka bröd två dagar, snabba vardagsmiddagar"* — and the app understands all of it.
- It works for counts, vague counts (*några, ett par, varje dag*), ranges (*2–3 middagar*), allergens, dieter, cuisines, recipe formats (soppa, gryta, tacos…), themes (*vardagsmat, festmat, husmanskost*), time limits (*max 30 minuter*), and Friday traditions (*tacofredag*).
- Above the calendar, a small chip strip shows exactly what the app understood. If something didn't fit (e.g. *low-FODMAP* or a free-form wish), an amber warning chip tells you so — no silent failures.
- No AI, no extra cost, no waiting. Same speed as today.
- "Baka bröd" just means "include a bread recipe from your collection" — same as any other recipe, no special task list.
- Old simple prompts work exactly like today.
- Risk: Low. The parser only runs *before* the existing recipe picker. Anything it doesn't recognise becomes a visible chip and gets ignored. Easy to revert in one PR.
- Next sprint (BUT-360): the lexicon moves to a Google Sheet you edit directly — same workflow as the ingredient list. Adding a new word becomes a one-row edit, no code change. This sprint puts the abstraction in place so the follow-up is plumbing only.

---

## Archive: Sprint Calendar Weekly Menu — Phase 1 — 2026-04-11

- [x] S0–S10: HTML preview, WeeklyMenuPlan model + repo + service + DI, ViewModel, CalendarWeeklyMenuWidget with all UI states, drag-and-drop, Lista/Kalender toggle + auto-distribute, GDPR deletion + export, l10n (BUT-211)

---

## Archive: Sprint Skafferiet (Pantry) — 2026-04-10

- [x] A1-A3, B1, C1-C3, D1: Pantry model/repo/service/DI/VM, PantryView, "Laga med vad jag har" filter, navigation, GDPR/l10n/tests (BUT-349, BUT-205) — PR #143

---

## Archive: Sprint Social Activity Feed — Phase 1 (completed 2026-04-10)

- [x] S1-S10: ActivityEvent model, repository, service, DI, ViewModel, FeedTab UI, tab integration, emission points, GDPR, l10n (BUT-339)

---

## Archive: Sprint Consent Hardening (completed 2026-04-10)

- [x] A1: Consent change callback (BUT-356)
- [x] A2: FCM mid-session re-enable (BUT-356)
- [x] B1: ConsentService.checkSafely tests (BUT-357)

---

## Archive: Sprint Insights & Engagement (completed 2026-04-10)

- [x] A1: Cooking photos (BUT-338)
- [x] A2: Tag-based collection insights (BUT-350)
- [x] B1: Tag analytics heat map (BUT-223)
- [x] C1: Allergen EU FIC audit (BUT-354)
- [x] C2: Golden tests + coverage gates (BUT-214)

---

## Archive: Sprint Social Polish & Tech Debt (completed 2026-04-09)

- [x] A1: Fix share dialog dead end (BUT-342)
- [x] A2: Add reply shortcut on shared recipe cards (BUT-343)
- [x] A3: Improve comment engagement (BUT-305)
- [x] B1: Add search history + Algolia highlights (BUT-304)
- [x] B2: Handcraft warm dark color scheme (BUT-346)
- [x] C1: Accept or refactor 9 files exceeding 500-line limit (BUT-302)

---

## Archive: Previous Sprints

- Feature & Polish (2026-04-09): BUT-348, BUT-355, BUT-352, BUT-353
- Social & Stability Blitz (2026-04-08): BUT-345, BUT-341, BUT-314, BUT-323, BUT-337, BUT-324, BUT-300, BUT-301
- Tech Debt Consolidation (2026-04-08): BUT-303, BUT-306, BUT-299
- Bug Stability + Hardening H2 (2026-04-08): BUT-308, BUT-320, BUT-335, BUT-319, BUT-336, BUT-331, BUT-317, BUT-297, BUT-313, BUT-311, BUT-312, BUT-332, BUT-327
- Security Hardening (2026-04-08): BUT-334, BUT-315, BUT-310, BUT-325, BUT-326, BUT-330, BUT-316, BUT-333, BUT-318, BUT-329, BUT-328, BUT-321
- Household + Menu Voting (2026-04-08): BUT-256, BUT-239
- Bug Cleanup + Loading Polish (2026-04-07): BUT-292-296, BUT-244
- Share & Discover (2026-04-07): BUT-219, BUT-242, BUT-272, BUT-271
- Tech Debt + UX Polish (2026-04-07): BUT-289, BUT-288, BUT-253, BUT-218, BUT-212
- Smart Import + Menu Intelligence (2026-04-06): BUT-208, BUT-241, BUT-247, BUT-204, BUT-270
