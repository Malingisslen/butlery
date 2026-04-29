# Plan Review Checklist

Review the plan as if a senior engineer reviewing a junior colleague's work. For each section, think about what could go wrong and what was missed. If you find issues, update the plan file, then call ExitPlanMode again.

## 1. Design System — Zero Hardcoded Values

The theme system is the single source of truth for all visual properties. Read the theme files if you need to verify specific tokens exist.

**Colors** — Every color in the plan must come from the theme (AppColors, ButleryColors extension, or ColorScheme). Check for:
- No hex literals (#RRGGBB), no Color(0xFF...), no Colors.* from Material
- rust is decorative only — never used for errors (AppColors.error is distinct)
- Status colors (success/warning/error/info) come from the theme, not custom colors
- Platform brand colors use the brand colors file, not hardcoded hex

**Typography** — Every text style must reference the theme. Check for:
- No inline TextStyle() constructors with literal font sizes or weights
- No literal font family strings — use the theme's defined fonts
- Semantic styles exist for common uses (recipe metadata, section headers, badges, errors, etc.)

**Spacing & Dimensions** — Every size, padding, margin, icon size, avatar size must come from the theme. Check for:
- No literal numeric values for spacing (EdgeInsets.all(16) → use theme constant)
- No literal icon sizes, avatar sizes, button heights, dialog constraints
- The theme has preset EdgeInsets for common patterns — use those

**Border Radius** — The design language is SQUARE. Check for:
- No BorderRadius.circular() with literal values
- All border radius constants in the theme are 0.0 (except for fully circular elements)

**Shadows, Elevation, Opacity** — Check for:
- No inline BoxShadow() — use theme shadow presets
- No literal elevation values — use theme elevation constants
- No .withOpacity() (deprecated) — use .withValues(alpha:) with theme opacity constants

**Animations** — Check for:
- No Duration(milliseconds: N) with literal values — use theme duration constants
- No literal Curves.* — use theme curve constants

**Responsive Layout** — Check for:
- Content views use Center + ConstrainedBox with responsive max width
- Responsive breakpoint utilities used for adaptive layouts
- Not assuming a single screen size

**Components** — Check for:
- Using styled button variants, not raw Material buttons
- Using state builder widgets for loading/error/data patterns
- Using theme component classes for input decoration, cards, navigation, chips

**HTML preview template sync** — If this plan changes theme tokens (colors, spacing, fonts, border radius), also update `docs/design/previews/_butlery-template.html` CSS custom properties to match. The template mirrors the Flutter theme for HTML previews.

## 2. Architecture & Layers

**MVVM compliance** — Each layer only talks to the layer below it:
- Views → ViewModels only (via Provider, never import services)
- ViewModels → Services only (via ServiceLocator, never import repositories)
- Services → Repositories (via constructor injection in DI, never access Firestore directly)
- Repositories → Firebase (the ONLY layer that touches Firestore)

**Base classes** — New code must use the project's infrastructure:
- Services must extend the base service class with error handling mixin
- Repositories must extend the base firebase repository with permission validation
- ViewModels must extend ChangeNotifier with appropriate state management mixins
- Service methods must use the standard operation wrapper (pre-flight checks, auth, error handling)

**Unified service pattern** — Large services use sub-modules (.personal, .social, .realtime). If the plan adds significant functionality to a unified service, is it going in the right sub-module?

**File size** — Does every new/modified file stay under 500 lines? If exceeding, is facade pattern proposed with a specific module breakdown?

**Data sources** — Does the plan consistently use the correct service for user data? (Complete user data comes from one service, basic auth checks from another — never mixed.)

## 3. Security & Data Integrity

**Repository security** — New repositories must have permission validation. Are Firestore security rules considered for new/modified collections?

**Serialization** — New models must use the project's safe serialization utilities for ALL Firestore field parsing. No raw map access (data['field'] as String).

**GDPR** — If storing new personal data: Is audit logging in place? Is the data covered by account deletion cascade? Is it included in data export?

**Input validation** — Is validation happening at system boundaries (user input, external APIs)? Not just trusting internal data.

**Firestore operations** — Are atomic operations (arrayUnion/arrayRemove) used for list fields? Is the batch write limit (500 ops) considered for bulk operations?

## 4. UI States & Localization

**All five states** — Does every data-dependent view handle: loading, error, empty, offline, and success? Not just the happy path.

**Error messages** — Are errors using the contextual error engine (not generic strings)? The engine needs error type + user action context + connectivity status.

**Localization** — Are ALL new user-facing strings added to BOTH language files (Swedish primary + English)? No hardcoded Swedish in Dart code.

**Empty states** — First-use experience: what does the user see when there's no data? Is there an illustration, helpful text, and a call to action?

## 5. DI & Registration

**Module placement** — Is the new service/repository registered in the correct DI module? The project has 7 domain modules with a specific initialization order.

**Lazy singletons** — Is lazy registration used by default? Eager only for core infrastructure.

**Interface registration** — Are services registered as their interface type (not implementation)? This is a common source of "service not found" bugs.

**Dependency order** — Are all dependencies registered before their dependents?

## 6. Testing

**Test intention** — Does each proposed test verify a specific behavior? Can you state in one sentence what breaks if the test fails? Tests that exist only for coverage or that mock away the thing they claim to test don't count.

**Test scenarios** — Are specific test cases identified (not just "add tests")? What scenarios need coverage?

**Test patterns** — Does the plan reference the project's test templates and setup patterns? Common gotchas:
- Mock service state setup requires explicit initialization flags
- Debounced ViewModel methods need fake async with time advancement
- The ServiceLocator bridge pattern is needed for ViewModel tests

**Verification steps** — The plan must explicitly list its verification steps as part of the work, not leave them implicit. Required (when applicable):
- `flutter analyze --fatal-infos` passes
- Specific tests named (file paths or test names) — not "add tests"
- For UI changes: manual verification step (Chrome MCP or device run) before declaring done
- For Firestore rules / repository changes: rules-test execution against emulator
A plan that says "implement X" without listing how it will verify X is done is incomplete (CLAUDE.md Rule #5: "Plans = execute + verify").

## 7. Edge Cases & Resilience

**Offline** — What happens when the user has no connectivity? Can the feature degrade gracefully?

**Empty data** — What happens on first use when there's nothing to show?

**Interrupted operations** — What if the app is backgrounded mid-operation? Are uploads, saves, and batch operations resilient?

**Race conditions** — Are there concurrent access scenarios? Collaborative editing, multiple devices, realtime subscriptions?

**Large datasets** — Is pagination used for potentially unbounded collections? Does the plan respect batch size limits?

## 8. Code Reuse

**Existing utilities** — Does the plan reuse the project's existing mixins, base classes, and utility functions? Read the mixin and utility files before proposing new helpers.

**Pattern matching** — Are there existing similar features in the codebase? The plan should reference them and follow the same patterns.

**Duplication** — Is any proposed code duplicating functionality that already exists? Check widgets/common/, core/mixins/, core/utils/.

## 9. Visual Previews

**ASCII wireframes in plan** — If the plan creates new views or significantly changes existing ones, does it include ASCII wireframes showing the layout? Plans that describe UI in text only ("add a card with a button") are insufficient — show the structure visually.

**Preview tier selection** — For each UI change, is the right preview tier identified?
- ASCII wireframe in plan file: structural layout decisions
- HTML preview before implementation: full-screen designs, color/typography, responsive layouts
- No preview needed: bug fixes, backend changes, minor tweaks

**Component library check** — If the plan creates new reusable widgets or modifies existing ones:
- Are the new widgets added to `_butlery-components.html`?
- Are modified widgets updated in the library to reflect visual changes?
- Does the plan reference existing components from the library instead of creating duplicates?

**Design decisions resolved** — Are visual choices (layout, component placement, hierarchy) resolved in the plan, or deferred to implementation? Prefer resolving during planning using ASCII mockups or AskUserQuestion with preview options.

## 10. Scope & Simplicity

**Minimal** — Is every proposed file, abstraction, and feature necessary for THIS task? No future-proofing, no "while we're at it" additions.

**No unnecessary docs** — No new .md files unless explicitly requested. No READMEs for new directories.

**Comment quality** — Comments explain WHY, not WHAT. No section dividers. All in English.

**Proportional complexity** — Is the solution complexity proportional to the problem? Would a staff engineer approve this scope?

**Cost discipline** — Per CLAUDE.md Cost Principles:
- New LLM calls must be justified: would deterministic code (rules, regex, lookup tables, algorithms) work? LLMs only for genuinely free-text understanding or creative generation.
- New Firebase reads/writes must consider batching, caching, and query efficiency. Plans that add per-item writes where a batch would do should be flagged.
- If the plan adds either, it should say WHY the cheaper alternative doesn't work — not just propose the expensive one silently.

## 11. Plain-Language Summary (mandatory section in plan)

Per `.claude/rules/workflow-discipline.md`, every plan MUST end with a section called **"What this means in plain language"** that:

- Explains what the user will notice changing (new button, different behavior, etc.)
- Uses zero technical jargon — no "viewmodel", "repository", "mixin", "provider", "widget tree"
- Summarizes the risk: what could break, and how easy it is to undo
- Is max 5-8 bullet points, written as if explaining to a friend who doesn't code

**Audit rule:** if this section is missing, that's a 🔴 RED — the plan is incomplete regardless of technical merit. If the section exists but uses banned jargon or exceeds 8 bullets, that's a 🟡 YELLOW — fix the wording before exit.
