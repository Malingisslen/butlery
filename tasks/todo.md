# Sprint Backlog

## Sprint: tech-debt sweep + dep watch + web polish — 2026-05-05 (K)

Theme: 6 implementations + 1 ticket-state cleanup. Recipe model + viewmodel hygiene (BUT-526/738), CLAUDE.md doc fix (BUT-567), three dep-watch memory entries (BUT-562/564/578), web scrollbar theming (BUT-724). Plus rescoping BUT-581 (plan stale at scope-level).

**In Progress carry-overs (NOT in this sprint):**
- BUT-442 — repo migrations (own focused sprint).
- BUT-760 — App Check enforcement; awaiting Firebase Console flip.

**Step 0 verification — done:**
- **BUT-526** fits — `lib/models/recipe_unified.dart` is 1425 lines vs accepted 1257 (+168, +13%). Modest drift; accept-and-bump is appropriate (distinct from BUT-530's +37% main.dart case which warranted extraction). Document serialization-extraction as a future option in the entry note.
- **BUT-738** fits — `lib/viewmodels/recipe_form/recipe_persistence_manager.dart` is 534 lines (ticket said 532, basically unchanged). `_logRecipeEdited` still around line 423; emits both `recipe_edited` and `post_import_edit` — extraction unblocks that and prevents drift past the 500-line ceiling.
- **BUT-567** fits — pure doc update. The 10 non-adopters listed in the ticket all still exist in `lib/services/`. Update CLAUDE.md / mixin-advisor narrative to "98% with documented exceptions".
- **BUT-562** fits — confirmed pre-1.0 deps in `pubspec.yaml`: `intl: ^0.20.2`, `rxdart: ^0.28.0`, `html: ^0.15.6`, `firebase_app_check: ^0.4.3`, `firebase_performance: ^0.11.3`. Memory entry tracking the watch list.
- **BUT-564** fits — confirmed: `timeago: ^3.7.1`, `html_unescape: ^2.0.0`. Append to dependency watch memory entry.
- **BUT-578** fits — confirmed: `cli_util: ^0.4.2`, `meta: ^1.16.0`. Append to dependency watch memory entry; no pubspec change today (premature tightening costs more than it's worth).
- **BUT-724** fits — `lib/theme/app_theme.dart` has no `scrollbarTheme` configured (verified by grep). Add `ScrollbarThemeData` matching SQUARE design (`Radius.zero`) + forestGreen thumb at 60% alpha.
- **BUT-581 PLAN STALE AT SCOPE** — actual count is 220 occurrences (not 150 or 203). Two competing extensions exist:
  - `lib/core/extensions/default_value_extensions.dart:9` — `String orEmpty()` (method on `String?`)
  - `lib/core/utils/validation_utils.dart:329` — `String get orEmpty` (getter on `String?`)
  Naive codemod picking the wrong one breaks call sites silently. Needs a canonical-extension decision + dual-removal first. → update ticket body, leave in Backlog.

### Agent A: Recipe model + viewmodel hygiene

Specialists: `code-reviewer` + `testing-specialist` (any .dart change).

- [ ] **A1. BUT-526 — Accept recipe_unified.dart's modest size drift** —
  - `docs/architecture/ACCEPTED_LARGE_FILES.md`: bump the `recipe_unified.dart` entry from 1257 to 1425. Add a one-line note: "Drift +168 from added fields/copyWith/serialization. Future: extract `recipe_unified_serialization.dart` if drift exceeds +25%."
  - **No code change** — pure doc update.
  - **Verification**: read the entry; confirm number matches `wc -l`.
  - **Rationale for accept-vs-extract**: 13% drift is within "cohesive growth" range (BUT-530's main.dart was +37% which warranted extraction; this isn't). (BUT-526)

- [ ] **A2. BUT-738 — Extract `RecipeEditAnalyticsEmitter` from `RecipePersistenceManager`** —
  - **New file** `lib/services/analytics/recipe_edit_analytics_emitter.dart`:
    ```dart
    /// Emits recipe-edit analytics events (recipe_edited + post_import_edit)
    /// from a single diff input. Extracted from RecipePersistenceManager so
    /// the manager only coordinates persistence; analytics is the emitter's
    /// sole responsibility.
    library;

    import 'package:butlery/models/recipe_unified.dart';
    import 'package:butlery/models/parsing/parsed_recipe_metadata.dart';
    import 'package:butlery/services/analytics/analytics_events.dart';
    import 'package:butlery/services/analytics/post_import_edit_decider.dart';
    import 'package:butlery/services/analytics_service.dart';
    import 'package:butlery/services/analytics/recipe_field_diff.dart';

    class RecipeEditAnalyticsEmitter {
      final AnalyticsService analytics;
      final PostImportEditDecider decider;
      final int postImportWindowDays;

      RecipeEditAnalyticsEmitter({
        required this.analytics,
        required this.decider,
        this.postImportWindowDays = 14,
      });

      Future<void> emit({
        required Recipe before,
        required Recipe after,
        required ParsedRecipeMetadata? originalParsedMetadata,
      }) async {
        final fieldsChanged = diffRecipeFields(before, after);
        // recipe_edited (existing event)
        await analytics.logEvent(
          name: AnalyticsEvents.recipeEdited,
          parameters: {
            'fields_changed_count': fieldsChanged.length,
            'fields_changed': fieldsChanged.join(','),
          },
        );
        // post_import_edit (BUT-569)
        final outcome = decider.decide(
          recipeAfter: after,
          fieldsChanged: fieldsChanged,
          originalParsedMetadata: originalParsedMetadata,
          windowDays: postImportWindowDays,
        );
        if (outcome != null) {
          await analytics.logEvent(
            name: AnalyticsEvents.postImportEdit,
            parameters: outcome.toAnalyticsParams(),
          );
        }
      }
    }
    ```
    **Note**: actual signatures depend on the existing `_logRecipeEdited` body — Step-1 of implementation reads `recipe_persistence_manager.dart` lines 423-442 and replicates the existing parameter shape exactly. Don't speculate; copy.
  - `lib/viewmodels/recipe_form/recipe_persistence_manager.dart`:
    - Add `RecipeEditAnalyticsEmitter` field, instantiate in constructor (or read via `ServiceLocator.get` if pattern matches surrounding services).
    - Replace `_logRecipeEdited` body with a single `await _editEmitter.emit(...)` call.
  - Tests:
    - **New** `test/unit/services/analytics/recipe_edit_analytics_emitter_test.dart` — covers: emits `recipe_edited` with fields-changed count; emits `post_import_edit` only when decider returns non-null; passes correct params through.
    - **Update** `test/unit/viewmodels/recipe_form/recipe_persistence_manager_test.dart` — analytics assertions move to the emitter test; manager test stubs the emitter and asserts it's called once with the expected `before/after/originalParsedMetadata` triple.
  - **Verification**: `flutter analyze --fatal-infos` clean; both test files pass; `recipe_persistence_manager.dart` line count drops below 500.
  - (BUT-738)

### Agent B: CLAUDE.md narrative fix (no Tier-2 specialist — doc only)

- [ ] **B1. BUT-567 — Update BaseService narrative to "98% with exceptions"** —
  - Find the BaseService claim in `CLAUDE.md` and/or `.claude/skills/mixin-advisor/SKILL.md` (grep first).
  - Update wording from "100% target / all services extend BaseService" → "~98% adoption (81/83). ~10 services legitimately don't adopt because they're pure-compute or 3rd-party wrappers without async Firebase ops".
  - List the legitimate non-adopters in a bullet block:
    - `lib/services/feature_flags/feature_flag_service.dart`
    - `lib/services/device_integrity_service.dart`
    - `lib/services/cache/permission_cache_service.dart`
    - `lib/services/theme/seasonal_accent_service.dart`
    - `lib/services/theme_service.dart` (only ChangeNotifier)
    - `lib/services/performance/firebase_performance_service.dart`
    - `lib/services/parsing/line_classifier/onnx_line_classifier_service.dart`
    - `lib/services/parsing/ner/onnx_ner_service.dart`
    - `lib/services/tagging/tag_resolution_service.dart`
    - `lib/services/monitoring/app_monitoring_service.dart`
  - **Verification**: re-read the updated narrative; verify the listed paths still exist.
  - (BUT-567)

### Agent C: Dependency watch memory entry (process-only, like sprint J's BUT-519/524)

- [ ] **C1. BUT-562 + C2. BUT-564 + C3. BUT-578 — Bundled dep-watch memory entry** —
  - **New file** `C:\Users\malla\.claude\projects\C--Butlery-butlery\memory\dependency_watch_list.md`:
    - Section "Pre-1.0 milestone watch (BUT-562)" — list `intl ^0.20.2`, `rxdart ^0.28.0`, `html ^0.15.6`, `firebase_app_check ^0.4.3`, `firebase_performance ^0.11.3`. Re-check quarterly. Note: firebase_app_check + firebase_performance graduate with the next Firebase BOM major.
    - Section "Dormancy watch (BUT-564)" — `timeago ^3.7.1`, `html_unescape ^2.0.0`. Quarterly pub-points re-check; replacement candidates documented (`timeago` → inline ~30-line Swedish helper; `html_unescape` → use `package:html`'s built-in unescape).
    - Section "Conditional dev-dep tightening (BUT-578)" — `cli_util ^0.4.2`, `meta ^1.16.0`. Do nothing today; tighten only if a future analyzer regression traces back to one of them.
  - Add `MEMORY.md` index entry: `- [Dependency Watch List](dependency_watch_list.md) — pre-1.0 milestones, dormancy watch, conditional dev-dep pin tightening`.
  - Per-Linear-comment + close all three (BUT-562, BUT-564, BUT-578) as Done.

### Agent D: Web scrollbar theming (small UI win)

Specialists: `code-reviewer` (any .dart change). UI-only theme change — no logic.

- [ ] **D1. BUT-724 — Theme web scrollbars to match SQUARE/forestGreen palette** —
  - `lib/theme/app_theme.dart`:
    - Add `scrollbarTheme: const ScrollbarThemeData(...)` to BOTH light and dark theme builders.
    - Settings: `thickness: WidgetStateProperty.all(8)`, `thumbColor: WidgetStateProperty.resolveWith((states) => Color(0x994A7C59))` (forestGreen at ~60% alpha; resolve from the live `ButleryColors` if accessible without breaking const), `radius: Radius.zero` (SQUARE design), `thumbVisibility: WidgetStateProperty.all(true)` for desktop browsers.
    - **Note**: if `scrollbarTheme` requires non-const because of Color resolution from theme tokens, drop the `const` — use a static getter that returns a fresh instance from `ButleryColors.forestGreen.withValues(alpha: 0.6)`.
  - **Verification**: `flutter analyze --fatal-infos` clean; manual verify in `flutter run -d chrome` that scrollbar shows green with sharp corners.
  - **Out of scope**: per-view custom Scrollbar wrappers (centralized theme covers everything that uses `Scrollbar` natively, which is all stock scrolling widgets).
  - (BUT-724)

### Linear cleanup (no code, ticket-state only)

- [ ] **E1. BUT-581 — rescope ticket body** — update Linear description to capture the dual-extension finding. Stay in Backlog. New body:
  ```
  Real count: 220 occurrences of `?? ''` across lib/ (verified 2026-05-05). Original ticket said 150/203 — both stale.

  Two competing `.orEmpty` extensions exist; pick canonical before codemod:
  - `lib/core/extensions/default_value_extensions.dart:9` — `String orEmpty()` (method on `String?`).
  - `lib/core/utils/validation_utils.dart:329` — `String get orEmpty` (getter on `String?`, delegates to `ValidationUtils.safeString`).

  Naive find-replace `?? ''` → `.orEmpty()` would silently bind to whichever extension is in scope at each call site, including the getter that drops trailing whitespace via `safeString`. That's a behavior change, not a refactor.

  Sequenced fix:
  1. Pick one canonical (default_value_extensions.dart's method form preferred — pure pass-through, no ValidationUtils dependency).
  2. Migrate the loser's call sites to the canonical, delete the loser.
  3. Codemod `?? ''` → `.orEmpty()` (220 sites; chunk by ~30 per agent batch per memory/feedback_agent_timeout.md).

  Effort: 4-6h sequenced (1h step 1, 1h step 2, 2-4h step 3).
  ```

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` — 0 issues
- [ ] Affected unit tests: `recipe_edit_analytics_emitter_test`, `recipe_persistence_manager_test`
- [ ] Tier-2 specialist gates: `code-reviewer` (A2 + D1 are .dart changes), `testing-specialist` (A2 lib/ change)
- [ ] Commit, push to main
- [ ] CI watcher monitors green
- [ ] Update Linear: BUT-526/738/567/562/564/578/724 → Done; BUT-581 stays in Backlog with rescoped description

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-549 — post-beta (Sign in with Apple lands when social login does)
- BUT-579 — held for button-system sprint
- BUT-444 / BUT-445 — own product-design sprints
- BUT-686 / BUT-660 / BUT-694 — feature-level brainstorming first
- BUT-674 / BUT-721 — own scoped sprints
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-420 / BUT-451 / BUT-452 / BUT-486 — deploy-pipeline / staging cluster; focused infra sprint
- BUT-550 / BUT-536 / BUT-441 — ACCEPTED_LARGE_FILES drift sprint
- BUT-558 — DCM install (own sprint)
- BUT-554 — tracking ticket (blocked on drift_dev upstream)
- BUT-594 — macOS sandbox audit needs hardware-exercise step
- BUT-701 — focus traversal (2-day a11y sprint)
- BUT-479 — cursor-pagination half is non-trivial; needs design ticket
- BUT-435 + BUT-502/503/507/509 — Dart SDK 3.10 bump cluster (one focused sprint)
- BUT-472 — realtime_session_manager stream/timer migration (next perf sprint)
- BUT-455 / BUT-440 / BUT-504 — repository discipline cluster (paired with BUT-442)
- BUT-453 / BUT-454 — auth/session security (own sprint with product-design input)
- BUT-488 — pubspec auto-bump CI workflow (3h, intricate; standalone)
- BUT-704 — i18n @key ARB descriptions (2-day sweep)
- BUT-520 — VM-migration sweep (rescoped sprint I)
- BUT-431 / BUT-530 — main.dart bootstrap split + extraction (rescoped sprint J)
- BUT-581 — `?? ''` migration (rescoped this sprint; sequenced 4-6h effort)
- BUT-610 — offline-mode hardening (multi-day audit)
- BUT-723 — tablet master-detail layouts (multi-day refactor)
- All `idea`-labeled monetization scaffolding — post-beta

### What this means in plain language
- **Cleaner code, less mess**: One file in the recipe save flow has been doing too many jobs (saving + tracking what users edit + measuring how the parser did). We move the "tracking what users edit" piece into its own focused service. Same behavior, easier to test, and prevents the file from getting unwieldy. Also: a doc file (the project's "we follow these patterns" guide) had a stale claim — fixing the wording so the next contributor reads accurate facts.
- **Web scrollbar polish**: today the web app uses default OS scrollbars (gray, rounded). After this sprint, they'll be forest-green with sharp corners — matching the rest of the app's design.
- **Three "process" tickets bundled together**: same shape as last sprint's BUT-519/524 — we add a memory note tracking five libraries that haven't hit version 1.0 yet, two libraries that look unmaintained, and two dev-only utilities that we should pin tighter only IF we ever see analyzer flakiness. No code changes; just a watch list so we don't forget to re-check them.
- **One ticket cleanup**: a code-cleanup ticket (the `?? ''` → `.orEmpty()` migration) turned out to be sneakier than its description claimed — there are two competing extensions in the codebase, so a naive find-replace would silently change behavior. Updating the ticket so the next sprint that picks it up does it in the right order.
- **Risk**: very low. The recipe-edit refactor preserves identical analytics output (same events, same params); the doc/memory/scrollbar changes are pure additions. Easy to revert per item.

---

## Archived prior sprint (completed in commit 245b71478 + a5288014f)

Dep hygiene + PWA polish + Linear cleanup — 2026-05-05 (J) — shipped BUT-500/519/524/718 + closed BUT-437 (premise gone) + rescoped BUT-431/530. Plus follow-up CI fix allowlisting `firestore_bootstrap.dart` in the architecture test.

## Archived sprint before (completed in commit 1e347b424)

Backend hygiene + auth security micro-hardening — 2026-05-04 (I) — shipped BUT-446/506/465/490 + closed BUT-716 (premise gone) + rescoped BUT-520. See git log for full task breakdown.

## Archived sprint before (completed in commit 44b6f4792)

GDPR cascade + rules tightening + stream lifecycle — 2026-05-04 (H) — shipped BUT-466/464/463/462/461/613/471. See git log for full task breakdown.

## Archived sprint before (completed in commit b33653c47)

Backend perf + observability hardening — 2026-05-04 (G) — shipped BUT-482/483/473/480/592/627. See git log for full task breakdown.

## Archived sprint before (completed in commit 4fc17758e + d9cb88acf)

Parsing/social tech-debt + dependency hygiene — 2026-05-04 (F) — shipped BUT-700/682/676/631/630/513/529 + BUT-698 closed as Duplicate. See git log for full task breakdown.
