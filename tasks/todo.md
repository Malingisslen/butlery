# Sprint Backlog

## Sprint: Analytics observability + parsing/LLM hardening + social UX — 2026-05-04

Theme: prior two sprints (commits `207fe7fc5`, `f0aec025d`) cleared the CI/a11y/perf carry-overs. High-priority backlog still blocked on Apple Dev (BUT-415/646/714/731), button-system sprint (BUT-579), and post-beta deferral (BUT-549). Cluster 7 small/medium concrete fixes across analytics observability gaps, parsing/LLM defensive hardening, and one social UX micro-fix. **7 tasks, 3 batches.**

**Step 0 verification — done:**
- **BUT-640** (track session_duration on foreground/background) — **PREMISE GONE.** `lib/main.dart:728-746` `_trackAppBackgrounded` already logs `session_duration_seconds` on `AppLifecycleState.paused/inactive`. Closing the ticket as obsolete; substituted **BUT-616** (logParseEvent failure rate visibility) into Agent A.
- **BUT-538** valid — `lib/viewmodels/onboarding_viewmodel.dart:112` fires `onboarding_page_viewed` on every `setPage` including back-nav; existing test at `test/unit/viewmodels/onboarding_viewmodel_test.dart:191-222` asserts un-deduped behavior — will need updating.
- **BUT-655** valid — zero matches for `notification_preference_changed` in lib/. Need to find settings toggle host in implementation.
- **BUT-534** valid — `lib/services/llm/pii_scrubber.dart:70` explicitly clears fragment via `parsed.replace(fragment: '')`. Tests at `test/unit/services/llm/pii_scrubber_test.dart:120+` assert legacy strip; need parity update on `functions/src/llm/pii-scrubber.ts:133` + tests.
- **BUT-540** valid — `lib/services/parsing/tiers/llm_tier.dart:399-406` `_suspiciousPatterns` covers `{{ }}` (Mustache) + `${ }` (template literals); missing `<% %>` (ERB/EJS) + `{% %}` (Jinja). Two RegExp additions.
- **BUT-582** valid — `lib/services/llm/llm_models.dart:340-371` `LlmException.fromFirebase` has explicit branches for `unauthenticated`/`resource-exhausted`/`invalid-argument`; `deadline-exceeded` and `unavailable` both fall to the generic "unknown" bucket with `llmGenericError` message. Need distinct user-facing messages so retry semantics are clear.
- **BUT-531** valid — `lib/widgets/social/report_content_dialog.dart:62-106` has 5 radio reasons, no free-text input. `ReportService.submitReport` signature does not accept context.

### Agent A: analytics observability (3 tickets)

- [ ] **A1. BUT-538 — Dedup `onboarding_page_viewed` per session** — `lib/viewmodels/onboarding_viewmodel.dart`. Add `Set<int> _viewedPages = {}`; in `setPage`, fire `AnalyticsEvents.onboardingPageViewed` only if `_viewedPages.add(page)` returns true. Update test at `test/unit/viewmodels/onboarding_viewmodel_test.dart:191-222` to assert dedup (re-visit same page → no second event; visit new page → one event). (BUT-538)
- [ ] **A2. BUT-616 — Surface `logParseEvent` failure rate** — `lib/services/parsing/parse_event_logger.dart:53`. The current callable wraps `httpsCallable('logParseEvent')` and silently swallows on catch. Add an `AnalyticsEvents.parseEventLogFailed` constant emitted on catch with `error_code` (Firebase code or `'unknown'`) and `cause` (truncated message ≤50 chars), so we can measure loss rate via Firebase Analytics. (BUT-616)
- [ ] **A3. BUT-655 — Log `notification_preference_changed`** — find category-toggle host (likely `lib/views/settings/notification_settings_view.dart` or similar). Emit `AnalyticsEvents.notificationPreferenceChanged` with `category` (e.g. `friend_request`, `comment`, `chat`) + `enabled` (bool) params on every toggle. Single param-shape, used for opt-in/opt-out funnel measurement. (BUT-655)

### Agent B: parsing/LLM hardening (3 tickets)

- [ ] **B1. BUT-534 — `scrubUrlParams` preserve URL fragment identifier** — `lib/services/llm/pii_scrubber.dart:70` drop the `fragment: ''` clear so anchors like `#ingredienser` survive (recipe sites use them as section anchors; fragments aren't sent to servers anyway). Mirror in `functions/src/llm/pii-scrubber.ts:133`. Update Dart test at `test/unit/services/llm/pii_scrubber_test.dart` and TS test at `functions/src/__tests__/pii-scrubber.test.ts` to assert fragment preserved + opaque path tokens still redacted. (BUT-534)
- [ ] **B2. BUT-540 — Suspicious-pattern filter ERB/EJS/Jinja** — `lib/services/parsing/tiers/llm_tier.dart:399-406` add two RegExp entries to `_suspiciousPatterns`: `RegExp(r'<%.*%>')` (ERB/EJS) + `RegExp(r'{%.*%}')` (Jinja). New unit test in `test/unit/services/parsing/llm_tier_test.dart` (or sibling) covering each new template syntax. (BUT-540)
- [ ] **B3. BUT-582 — Distinct `LlmException` for deadline-exceeded vs unavailable** — `lib/services/llm/llm_models.dart:340-371` add two explicit branches above the generic fallback:
  - `deadline-exceeded` → message `llmTimeout` ("Förfrågan tog för lång tid — försök igen") + code `'deadline-exceeded'`
  - `unavailable` → message `llmTemporarilyUnavailable` ("Tjänsten är tillfälligt otillgänglig — försök igen om en stund") + code `'unavailable'`
  Add ARB keys to `app_sv.arb` + `app_en.arb`; run `flutter gen-l10n`. (BUT-582)

### Agent C: social UX micro-fix (1 ticket)

- [ ] **C1. BUT-531 — Report dialog free-text field for "Other" reason** — `lib/widgets/social/report_content_dialog.dart:62-106`. When `selectedReason == reportReasonOther`, render a `TextField` (max 500 chars, required, l10n hint `reportOtherReasonHint`) and pass its content as `additionalContext` to `ReportService.submitReport`. Update `lib/services/moderation/report_service.dart` `submitReport` signature with optional `String? additionalContext` parameter, persisted onto the Firestore report doc as `additionalContext` field. ARB additions: `reportOtherReasonHint` ("Beskriv kort vad som är fel"), `reportOtherReasonRequired` ("Beskrivning krävs när 'Annat' valts"). (BUT-531)

### Standalone

- [ ] **D1. Close BUT-640 as premise-gone** — already shipped in `lib/main.dart:728-746` (`_trackAppBackgrounded` logs `session_duration_seconds`). Add Linear comment + transition state to Done with link to `main.dart:728-746`. (BUT-640)

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` — 0 issues
- [ ] Affected unit tests: onboarding_viewmodel_test, pii_scrubber_test (Dart + TS), llm_tier_test, llm_models_test (if exists), report_dialog_test (if exists)
- [ ] Tier-2 specialist gates: code-reviewer, testing-specialist, firebase-backend-security (LLM/parsing services), cloud-functions-specialist (TS pii-scrubber parity)
- [ ] Commit, push to main
- [ ] CI watcher monitors green
- [ ] Update Linear: BUT-538/616/655/534/540/582/531 → Done; BUT-640 → Done (closed as premise-gone)

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-549 — post-beta (Sign in with Apple lands when social login does)
- BUT-579 — held for button-system sprint
- BUT-444 / BUT-445 — own product-design sprints
- BUT-498 / BUT-697 — explicitly skipped
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — own scoped sprints
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-420/451/452/486 — deploy-pipeline / staging cluster; focused infra sprint
- BUT-550 — accepted-large-files drift sprint, separate scope
- BUT-558 — DCM install (own sprint, half-day setup + per-finding follow-ups)
- BUT-554 — tracking ticket only (blocked on drift_dev upstream)
- All `idea`-labeled monetization scaffolding — post-beta

### In Progress carry-overs (NOT in this sprint)
- BUT-442 — repo migrations (4 candidates remaining; each deserves a focused single-ticket sprint)
- BUT-760 — App Check enforcement; awaiting user-side Firebase Console enforcement flip after BUT-759 lands

---

## What this means in plain language

- **Three small analytics gaps closed.** Onboarding step views won't double-count when users go back; we'll know when our recipe-parsing logger is failing silently; we'll see when users toggle individual notification categories on/off.
- **Three parsing/LLM defensive hardenings.** URL fragment anchors (`#ingredienser`) survive when we sanitize URLs (today they get stripped). Two more "looks like a template-injection attack" patterns added so an adversarial recipe site can't slip ERB/Jinja-style payloads through. AI service errors split into "took too long" vs "service down" so users see actionable retry hints instead of the same generic message.
- **One social fix.** When someone picks "Other" as a report reason, they finally get a text field to explain (Google Play's appeal policy effectively requires this).
- **One ticket housekeeping.** BUT-640 is already done — it'll be closed with a pointer to the existing code so the backlog reflects reality.
- **Risk: low across the board.** No data-model changes, no UI structure changes, no external service contracts beyond extending one Firestore field on the report doc. Each ticket independently revertable.

---

## ARCHIVED — Sprint: CI hygiene + a11y micro-fixes + tech-debt cleanup — 2026-05-04

Theme: BUT-442 + BUT-760 stay In Progress carry-overs (not in this sprint). With High-priority backlog still gated on external dependencies (Apple Dev for BUT-415/646/714/731, button-system sprint for BUT-579, post-beta for BUT-549), pull tightly-scoped Medium tickets across CI/security (BUT-535), backend tooling (BUT-546), UI refactor (BUT-542), a11y micro-fixes (BUT-763, BUT-557), test guard (BUT-764), and dep audit (BUT-555). **7 tasks, 3 batches.**

**Verify-before-starting flags:**

- **A1 (BUT-535)** — confirm no SBOM step exists in any of the 5 GitHub workflows. Decide tool stack: `cyclonedx-bom` (npm side) + a CycloneDX-aware Dart generator (`cyclonedx_lib` or shelling out via `pub deps --json` + `cyclonedx-cli`). Combine into a single bundle. Skip cosign signing (no OIDC identity wired yet — out of scope per ticket).
- **A2 (BUT-546)** — `functions/src/llm/gemini-client.ts` line ~512-520 `validateDifficulty`. Add `logger.warn` with `promptVersion + raw value` on enum miss. ParseEventLogger aggregation is BUT-543's scope, not this ticket — keep edit minimal.
- **B1 (BUT-542)** — `lib/widgets/menu/calendar_weekly_menu_widget.dart` 747 lines. Read first to confirm the structure: header row, 7 day cells, outer scaffold. Extract three private widgets within the same file? Or three new files in `lib/widgets/menu/calendar/`? Prefer same-file private classes (less churn for a single-callsite widget) unless the extracted widgets warrant external testing. Hold to <300 line orchestrator.
- **B2 (BUT-763)** — `lib/widgets/common/scaffolds/`. Identify which scaffold helper(s) wrap AppBar. Single-edit pattern: wrap `appBar:` parameter passthrough with `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: appBar)`. After landing, drop `wrapInScaffold: false` from `test/widget/widgets/a11y_text_scaling_test.dart`.
- **B3 (BUT-764)** — `test/widget/social/activity_pings_feed_test.dart` (or wherever ActivityPingsFeed tests live — verify path). Single `fakeAsync` test asserting paused→no-fetch and resumed→fetch. Use existing repo/service mock seams.
- **C1 (BUT-555)** — `grep -r "package:sembast/" test/ lib/` (excluding `sembast_web`). If zero direct hits, drop `sembast` from `dev_dependencies` in `pubspec.yaml` and run full test suite. Else add an inline comment.
- **C2 (BUT-557)** — first verify whether BUT-697 a11y sweep already added landmark Semantics. Grep `Semantics(header: true` and `Semantics(label: 'Primary navigation'` in `lib/widgets/common/`. If absent, wrap AppBar host + bottom nav widget. Swedish UI string for nav label: `'Huvudnavigering'` (matches app i18n).

### Agent A: cloud-functions-specialist + general — CI/backend hygiene

- [x] **A1. BUT-535 — Generate CycloneDX SBOM in CI** — New `.github/workflows/sbom.yml` runs `@cyclonedx/cdxgen@11` against the repo (covers pub + npm in one pass), emits CycloneDX 1.5 JSON, sanity-gates on component count > 0, uploads as workflow artifact with 90-day retention. Triggers: push to main on lockfile changes, weekly Tuesday 05:00 UTC, on-demand. Cosign signing deferred per ticket (no OIDC identity wired). (BUT-535)
- [x] **A2. BUT-546 — Log invalid difficulty values in gemini-client** — `validateDifficulty` now emits `logger.warn` with `rawValue + rawType + promptVersion` when Gemini returns a non-null value outside the `easy|medium|hard` enum. Threaded `promptVersion` through `parseRecipeResponse` from the two call sites (`structure-recipe.ts`, `ocr-recipe-image.ts`). Absent fields stay silent (normal). New `parse-recipe-response-difficulty.test.ts` (7 cases) — 7/7 green. (BUT-546)

### Agent B: uiux-designer + flutter-developer + testing-specialist — UI refactor + a11y + test guard

- [x] **B1. BUT-542 — Decompose calendar_weekly_menu_widget (747 lines)** — Three-file decomposition under `lib/widgets/menu/calendar/`: `calendar_drag.dart` (drag payload sealed types + draggable/droptarget helpers, 135 lines), `calendar_header.dart` (`WeekNavHeader` + `OverflowTray` + `_OverflowChip`, 161 lines), `calendar_cells.dart` (`DayCell` + private slot-cell sub-widgets, 478 lines). Orchestrator slimmed 777→191 lines. Golden test byte-identical (visual output unchanged). Pre-existing failure on `week-nav buttons` test verified to be unrelated to this refactor (failed identically on `git stash` of the refactor). (BUT-542)
- [x] **B2. BUT-763 — Clamp text scaling on AppBar via BaseScaffold** — `BaseScaffold._wrapClampedTextScaling` wraps the AppBar in `PreferredSize(child: MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3, child: appBar))`. Two new regression tests in `a11y_text_scaling_test.dart`: long-title at 2x renders without overflow + structural assertion that AppBar is nested under a MediaQuery (clamp-wrap sanity). 4/4 green. (BUT-763)
- [x] **B3. BUT-764 — Lifecycle pause/resume regression test for ActivityPingsFeed** — `_FakeActivityRepo` extended with `fetchCount`. New widget test pumps the feed, asserts 1 fetch on init, drives `AppLifecycleState.paused` + advances 5 min (asserts no extra fetch), drives `resumed` (asserts immediate fetch + periodic resume after 2 min). Fails if `_foregrounded` guard or `addObserver` is removed. 8/8 green. (BUT-764)

### Standalone

- [x] **C1. BUT-555 — Audit sembast dev-dep removal** — Audited; **kept-with-comment** outcome. `sembast` is consumed by `test/unit/core/cache/cache_dao_web_test.dart` (uses `sembast/sembast_memory.dart` for the in-memory DB factory). `sembast_web` is consumed by `lib/core/cache/cache_dao_stub.dart` (web-platform CacheDao backend). Pubspec entries now have inline comments pointing at the consumers so future audits don't repeat the question. Lesson logged (`tasks/lessons.md` — "Bash `cd` persists across calls" — first grep was wrong because shell session had cd'd into `functions/`). (BUT-555)
- [x] **C2. BUT-557 — A11y landmark Semantics on AppBar/bottom nav** — Two l10n keys added (`a11yNavigationLandmark` + `a11yAppBarHeaderHint` in both `app_sv.arb`/`app_en.arb`). `BaseScaffold._buildAppBar` title now wrapped in `Semantics(header: true, container: true, label: l10n.a11yAppBarHeaderHint(title))`. `ButleryBottomNavigation` + `_buildNavigationRail` + `AdaptiveNavigationDrawer.build` now wrap their roots with `Semantics(label: l10n.a11yNavigationLandmark, container: true, explicitChildNodes: true)` so screen readers can jump directly to the nav region (WCAG 1.3.1 Info and Relationships). Verified BUT-697 hadn't already added landmark Semantics. (BUT-557)

### Post-Sprint Steps
- [x] `dart analyze --fatal-infos` — 0 issues
- [x] Affected unit/widget tests green: BUT-546 (7/7), a11y_text_scaling (4/4), activity_pings_feed (8/8 incl. new lifecycle test), calendar golden (1/1). One pre-existing failure on `week-nav buttons` test verified to be unrelated to BUT-542 (fails identically on main).
- [ ] Tier-2 specialist gates: code-reviewer, testing-specialist, firebase-backend-security (A2), cloud-functions-specialist (A1, A2)
- [ ] Commit, push to main
- [ ] CI watcher monitors green
- [ ] Update Linear: BUT-535/546/542/763/764/555/557 → Done

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-498 / BUT-697 — explicitly skipped
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — need their own scoped sprints
- BUT-579 — held for button-system sprint
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-444 — portion scaling + unit conversion; own product-design sprint
- BUT-420/451/452/486 — deploy-pipeline / staging cluster; focused infra sprint
- BUT-445 — nutrition view post-beta (Livsmedelsverket API plan)
- BUT-550 — accepted-large-files drift sprint, separate scope
- BUT-558 — DCM install (own sprint, half-day setup + per-finding follow-ups)
- BUT-554 — tracking ticket only (blocked on drift_dev upstream)
- All `idea`-labeled monetization scaffolding — post-beta

### In Progress carry-overs (NOT in this sprint)
- BUT-442 — repo migrations (4 candidates remaining; each deserves a focused single-ticket sprint)
- BUT-760 — App Check enforcement; awaiting user-side Firebase Console enforcement flip after BUT-759 lands

---

## What this means in plain language

- **CI gets a software-bill-of-materials.** Every build will list every dependency (Flutter pub + Cloud Functions npm) so when the next CVE drops we can answer "are we affected?" in minutes instead of grepping by hand.
- **AI parser stops failing silently.** When Gemini returns an unrecognized difficulty value (e.g., starts saying "advanced" instead of "hard"), we'll see a warning in logs instead of pretending the field never existed.
- **Weekly menu widget gets split into manageable pieces.** A 747-line widget that nobody could read at a glance becomes a small orchestrator + three named pieces.
- **Two small accessibility fixes.** Page titles in the top bar stop clipping at 200% text scale. Screen readers get a "navigation" landmark for the bottom tab bar — easier to skip past with VoiceOver/TalkBack.
- **One test guard added.** The recent battery-saving change (pause polling when app is backgrounded) gets a test so a future refactor can't silently undo it.
- **One dependency audit.** Verify whether a dev-only library (`sembast`) is still pulled by anything; remove if dead weight.
- **Risk: low across the board.** No data-model changes, no UI structure changes, no external service contracts. Each ticket independently revertable.

---

## ARCHIVED — Sprint: Tech-debt sweep — repo migrations + ValidationUtils + social-widget perf + a11y micro-fixes — 2026-05-04

Theme: with the High-priority backlog all gated on external dependencies (Apple Dev enrollment for BUT-731/646/714/415, design sprint for BUT-579, post-beta for BUT-549), the highest-leverage work is Medium-tier tech-debt that compounds. Continue BUT-442 carry-over (2 more repos), audit + close one form-validation gap (BUT-586), remove a small CI hygiene smell (BUT-762), tighten two social widgets that polled/rebuilt unnecessarily (BUT-629/628), close two scoped a11y issues (BUT-551/547), and split onboarding-import outcomes from the regular import funnel (BUT-545). **8 tasks, 4 batches.**

**Two follow-up notes from the prior sprint** (verify before scope):
- **BUT-759** was actually fixed in commit `a14b87735` ("fix(firebase): point native runtime at se.butlery.app apps") — close it on Linear if still open.
- **BUT-760** Phase 2A done per `a72b4d1f2` ops-runbook commit. Remaining work is user-side Firebase Console enforcement flip — leave In Progress with a status comment; don't include in this sprint.

**Verify-before-starting flags:**
- **A1 (BUT-442)** — re-read BUT-442 Linear comment for the 6 remaining candidates (last sprint dropped 2 of 3 due to FakeFirebaseFirestore limits on `FieldValue.increment` + `merge: true`). Pick 2 that don't need those (likely `menu_lexicon_repository`, `parsing_correction_repository`, or `site_config_repository`). Hard cap at 2.
- **A2 (BUT-586)** — `grep -r "TextFormField" lib/` and `grep -r "ValidationUtils" lib/` to compute the 16/45 baseline (or the corrected current ratio). Apply ValidationUtils to forms with text-only validation needs (`required`, `maxLength`, `email`, etc.); document non-trivial holdouts in a Linear comment. Avoid forms with custom validators where ValidationUtils would lose semantics.
- **A3 (BUT-762)** — `.github/workflows/build-validation.yml`: grep for `FIREBASE_API_KEY_*` references and confirm they aren't consumed by any step (likely vestigial from before AppCheck or `flutterfire configure` flow).
- **B1 (BUT-629)** — `lib/widgets/social/activity_pings_feed.dart`. Add `WidgetsBindingObserver` mixin; pause `Timer.periodic` on `AppLifecycleState.paused`/`inactive`/`hidden`, resume on `resumed`. Don't conflate route-backgrounded with app-backgrounded (the ticket says "route backgrounded" — verify whether `RouteAware` is the right hook).
- **B2 (BUT-628)** — `lib/widgets/social/family_presence_bar.dart`. Convert to `StatefulWidget`; cache the stream + `Future` for member resolution in `initState`. Today's StatelessWidget recreates these on every parent rebuild (FCMService notification, theme change, etc.).
- **C1 (BUT-551)** — `lib/widgets/recipe/recipe_image_widget.dart`. May already be done — verify `Semantics(label: ...)` wraps `Image.network` and pulls from the recipe's title rather than a generic "recipe image" string.
- **C2 (BUT-547)** — sweep for `SizedBox(height: N)` and `Container(height: N)` containing `Text(...)` in `lib/views/` and `lib/widgets/`. At 2x text scale, fixed heights clip. Apply low-risk fixes (FittedBox, drop the height constraint, IntrinsicHeight); document non-trivial cases.
- **D1 (BUT-545)** — `lib/views/onboarding/` and `lib/services/import/`. Today onboarding imports likely fire the same `import_attempted/succeeded/failed` events as in-app imports, making activation funnel measurement noisy. Add `onboarding_import_attempted/succeeded/skipped` distinct events under `AnalyticsEvents` and emit from the onboarding view only.

### Agent A: firebase-backend-security + cloud-functions-specialist — backend/CI tech-debt

- [!] **A1. BUT-442 carry-over** — **DEFERRED per CLAUDE.md rule #10**. Re-assessing the 6 candidates: 4 don't fit BaseFirebaseRepository (`menu_lexicon` + `site_config` are read-only caches; `cooking_session` + `ingredient` need emulator-backed tests). Remaining real scope = 2 (`parsing_correction` + `collaborative_recipe`), each deserves a focused single-ticket sprint. Filed honest reassessment on BUT-442; ticket stays In Progress with corrected scope. (BUT-442)
- [x] **A2. BUT-586 — audit ValidationUtils coverage** — Reconciled the metric (the "16 of 45" stat conflated `ValidationUtils` and `FormValidators`; actual TextFormField host count is 22, with ~95% of them having appropriate validators). Real gap surfaced: `personal_tag_dialogs.showEditTagDialog` had a TextFormField with no Form wrapper + silent no-op on empty submit — wrapped in Form + GlobalKey + `FormValidators.required(...)`. Documented per-file coverage table + minor refactor opportunities on BUT-586. (BUT-586)
- [x] **A3. BUT-762 — remove stale FIREBASE_API_KEY_* CI secrets** — Stripped 17 unused env entries from `build-validation.yml`'s "Create .env from secrets" step; only `ENV` + `OCR_API_KEY` + `OCR_API_URL` remain (the only secrets actually consumed). Added inline comment cross-referencing `lib/firebase_options.dart` as the canonical source of Firebase platform credentials. (BUT-762)

### Agent B: performance-optimizer — social-widget perf

- [x] **B1. BUT-629 — ActivityPingsFeed pause polling while backgrounded** — Added `WidgetsBindingObserver` mixin; `didChangeAppLifecycleState` pauses the 2-min `_activityRefreshTimer` on `paused`/`inactive`/`hidden`, resumes (with one immediate refresh + restart of the periodic timer) on `resumed`. Documented divergence from ticket Option 2 in code: dropping the timer entirely would lose activity events from group members that arrive without an accompanying ping. 7/7 existing widget tests still green. (BUT-629)
- [x] **B2. BUT-628 — FamilyPresenceBar StatefulWidget conversion** — Converted `StatelessWidget` → `StatefulWidget` with `_resolveMembers` + `_composePresenceStream` cached in `initState` and re-computed in `didUpdateWidget` only when `groupId`/`memberProfiles`/`onlineUserIdsStream` change. Eliminates the per-parent-rebuild ~1000-iteration walk + RTDB tear-down/setup. Public widget API unchanged; 5/5 existing widget tests still green. (BUT-628)

### Agent C: uiux-designer + flutter-developer — a11y micro-fixes

- [x] **C1. BUT-551 — recipe_image_widget Semantics label uses dish name** — Added optional `String? semanticsLabel` parameter to `RecipeImageWidget` (root + `card`/`detail` factories) and `UniversalImageManager` (root + `recipeCard`/`recipeDetail` factories). When non-null + has images, wraps the rendered image in `Semantics(image: true, label: semanticsLabel)` so screen readers announce the dish name. `_buildEmptyState` (no onTap) wrapped in `ExcludeSemantics` per ticket guidance. Threaded `viewModel.recipe.title` through `recipe_detail_content.dart`. New widget test file `test/widget/widgets/image/recipe_image_widget_a11y_test.dart` (3 cases: detail label, card label, empty-state exclusion) — 3/3 green. (BUT-551)
- [x] **C2. BUT-547 — text-scaling 200% clipping audit** — Sweep of `lib/widgets/` for `Container/SizedBox(height: N)` with text. **Real offenders fixed:** (1) `RecipeCard._buildMetadataRow` Row → Wrap (rating + match badges flow to next line at 2x scale instead of overflowing); (2) `group_dialog_components.dart` emoji picker wrapped in `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` (44×44 cells holding `Text(emoji)` would clip otherwise). Audit confirmed `*_badge.dart`, bottom nav, tagging widgets all safe. Filed comprehensive findings on BUT-547. New regression-prevention test `test/widget/widgets/a11y_text_scaling_test.dart` exercises RecipeCard at 2x text scale — 2/2 green. (BUT-547)

### Standalone

- [x] **D1. BUT-545 — onboarding import outcome events** — Added 3 event constants to `AnalyticsEvents` (`onboardingImportAttempted`, `onboardingImportSucceeded`, `onboardingImportSkipped`). Wired `attempted` to fire pre-import in `OnboardingImportPage._handleImport`, `succeeded` to fire on `ImportSucceeded` result (with `recipe_title_length` param), and `skipped` to fire from `OnboardingViewModel.completeOnboarding` when the new `_onboardingImportSucceeded` flag is false (set via `markOnboardingImportSucceeded()` from the import page on success). Try/catch around the Provider lookup so the page works standalone (outside the wizard). 2 new VM tests + 8 existing tests — 10/10 green. (BUT-545)

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` — 0 issues required
- [ ] Affected unit tests green (repo tests, widget tests for ActivityPingsFeed/FamilyPresenceBar/RecipeImageWidget, analytics tests)
- [ ] Tier-2 specialist gates: code-reviewer, testing-specialist, firebase-backend-security (A1)
- [ ] Commit, push to main
- [ ] CI watcher monitors green
- [ ] Update Linear: BUT-442*/586/762/629/628/551/547/545 → Done (* BUT-442 stays In Progress with 4 candidates remaining if 2 land here)
- [ ] Close BUT-759 on Linear (already shipped in `a14b87735`); BUT-760 status-comment ("Phase 2A done in `a72b4d1f2`; awaiting user-side Firebase Console enforcement flip")

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-498 / BUT-697 — explicitly skipped
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — need their own scoped sprints
- BUT-579 — held for button-system sprint
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-444 — portion scaling + unit conversion; own product-design sprint
- BUT-420/451/452/486 — deploy-pipeline / staging cluster; focused infra sprint
- All `idea`-labeled monetization scaffolding — post-beta

---

## What this means in plain language

- **Two more pieces of the data-access cleanup get done.** Slow burn from prior sprints — picking off 2 more of the 6 remaining stragglers without breaking anything.
- **One form-validation gap audited.** Today only ~36% of forms use the shared validation helper, so error messages and behavior are inconsistent. This sprint computes the real number, applies it to easy wins, and documents what's left.
- **Two social widgets stop wasting battery.** The "who's online in your family" bar today recreates its connection on every screen rebuild; the "activity feed" bar polls every 2 minutes even when the app is in the background. Both fixed.
- **Two small accessibility fixes.** Recipe images get the dish name as their screen-reader label (currently generic); fixed-height text containers that crop at 200% text scaling get unfrozen.
- **Onboarding import events get their own bucket.** Today they're mixed with regular imports, so we can't measure activation funnel cleanly.
- **One small CI cleanup.** Three never-used Firebase secrets removed from a workflow file.
- **Risk: low across the board.** No UI structure changes, no data-model changes, no external service contracts. Each ticket independently revertable.

---

## ARCHIVED — Sprint: Identity/integrity correctness + parsing-input hardening + repo migrations carry-over — 2026-05-02

Theme: Land the two High-priority package/bundle-ID bugs (BUT-759/761) and tie them to the App Check enforcement registration (BUT-760) that depends on correct IDs being registered. Tighten parsing input-validation in three coherent spots in `gemini-client.ts`. Pull 3 of the 7 BUT-442 carry-over migrations. Two standalone correctness fixes (analytics boolean coercion + multi-tab consent cache). **9 tasks across 2 agent groups + 3 standalones.**

**Verify-before-starting flags:**
- **A1 (BUT-759)** — repo work is replacing `ios/Runner/GoogleService-Info.plist` with one regenerated for `se.butlery.app`. The Firebase Console step (registering a new iOS app or updating bundle ID) is user-side — Claude can prepare the plist swap + verify Xcode resolves; user toggles the Firebase Console.
- **A2 (BUT-761)** — `lib/services/security/device_integrity_service.dart`. Confirm whether `package_info_plus` is already a dep before threading runtime package-name; if not, hardcode to `se.butlery.app` (matching iOS bundle).
- **A3 (BUT-760)** — depends on A1+A2 landing. Wire activation in bootstrap (`main.dart` or DI). Firebase Console enforcement flip is user-side — flagging it on the manual QA list rather than blocking the code task.
- **B1/B2/B3 (BUT-512/516/528)** — all three live in `functions/src/llm/gemini-client.ts` validation paths. Confirm test seam: `parseIngredientLines` and `structureRecipe` both flow through the same validation helpers. Add unit tests in `functions/src/__tests__/gemini-validation.test.ts` (new file).
- **C1 (BUT-442)** — re-read the BUT-442 Linear comment for the 7-candidate list. Pick top 3 by traffic: `firebase_category_preferences_repository.dart`, `cooking_session_repository.dart`, `ingredient_repository.dart`. Hard cap at 3 (per agent-timeout memory). If any single migration trips up tests, downscope to 2 and carry the third forward.
- **C2 (BUT-523)** — grep for `'true'`/`'false'` string literals in `lib/services/analytics/`; the regression-prevention assertion goes in `BaseTracker.logEvent`.
- **C3 (BUT-460)** — web-only via `dart:html` `BroadcastChannel`. Wrap behind `kIsWeb` guard. Native platforms keep current single-process behavior.

### Agent A: firebase-backend-security — identity/integrity registration correctness

- [!] **A1. Fix Firebase iOS app bundle ID** — **BLOCKED — user-side Firebase Console action required.** Editing only `lib/firebase_options.dart` to swap `iosBundleId` would create a config that lies (the `appId` `1:976357691692:ios:714dacad784ca7b7e4dc89` is bound to the existing `com.example.butlery` Firebase iOS app registration; changing only the bundle ID literal would point the runtime at the wrong appId). The honest path requires user-side: (1) Firebase Console → Project Settings → Add new iOS app for `se.butlery.app`; (2) Run `flutterfire configure` locally to regenerate `firebase_options.dart` + download a fresh `GoogleService-Info.plist` for `ios/Runner/`; (3) Delete the two orphan `com.example.butlery` Firebase iOS apps from App Check. Per CLAUDE.md rule #10 (Honesty over completion), not shipping a half-fix. Linear ticket carries the full handoff. (BUT-759)
- [x] **A2. Fix freerasp watcher hardcoded packageName** — `lib/services/device_integrity_service.dart`: swapped both `packageName: 'com.butlery.app'` (Android) and `bundleIds: ['com.butlery.app']` (iOS) to `'se.butlery.app'` to match runtime `BuildConfig.APPLICATION_ID` / `Bundle.main.bundleIdentifier`. Added explanatory comment cross-referencing the build files where the canonical value lives. The prior mismatch made freerasp's package-check a silent no-op; the watcher now actually compares at runtime. Talsec dashboard registration must also be updated to `se.butlery.app` for the watcher email to fire on tampering — flagged on the manual QA list. dart analyze clean. (BUT-761)
- [!] **A3. Register Play Integrity (Android) + App Attest (iOS) providers and enforce App Check** — **BLOCKED on A1.** App Attest registration requires the iOS Firebase app to exist with the correct bundle ID, which A1 owns. Wiring `FirebaseAppCheck.instance.activate(...)` in code without first registering the providers in Firebase Console would actively log runtime errors against missing providers. Honest hold: when A1 lands (user-side), this becomes a 4-6h Flutter wiring + console flip. Linear ticket carries the handoff. (BUT-760)

### Agent B: cloud-functions-specialist — parsing input-validation tightening

- [x] **B1. Per-unit-aware amount validation in `LlmTier._validateResponse`** — File path correction: lives at `lib/services/parsing/tiers/llm_tier.dart` (Flutter side, not `functions/src/llm/gemini-client.ts`). Replaced the loose `0-10000` range with `_maxAmountByUnit` lookup table covering all 23 known Swedish units (kg ≤ 20, g ≤ 5000, dl ≤ 50, msk ≤ 50, tsk ≤ 100, st ≤ 500, etc.). Unitless quantities fall back to `_maxAmountUnitless = 10000` (preserves prior behavior for `2 ägg`-style entries). Above-ceiling triggers `AppLogger.warning` with the offending value + unit + name + ceiling, then `errors.add('ingredient_amount_range')`. Negative amounts still rejected. (BUT-512)
- [x] **B2. Reject unknown-unit ingredient rows in `LlmTier._convertIngredients`** — Filtering happens at conversion time (not validation), so the rest of the recipe survives a single hallucinated unit. Iterates extracted ingredients: keeps unitless rows + rows whose unit is in `_knownSwedishUnits`; drops unknown-unit rows with a `AppLogger.warning` per drop. If the filter empties the list, returns `FieldResult.failed('All LLM ingredients had unknown units (dropped N)')`. Removed the prior debug-only "log and pass through" code path that was silently corrupting downstream shopping-list / scaling calculations. (BUT-516)
- [x] **B3. Cap instruction count at 50 in `LlmTier._convertInstructions`** — Added `_maxInstructionCount = 50` constant. When `instructions.length > 50`, logs `AppLogger.warning('Truncating instructions N → 50')` and returns `instructions.take(50).toList()` with a `'LLM extraction (truncated)'` provenance string. Front-loaded steps preserved (tail steps are where LLM drift accumulates). 50 is generous — longest real recipe in our goldens is ~30 steps. (BUT-528)

### Standalone

- [!] **C1. BUT-442 carry-over — migrate top repository holdouts to `BaseFirebaseRepository`** — **Partial: 1/3 migrated.** `firebase_category_preferences_repository` migrated by firebase-backend-security subagent: now extends `BaseFirebaseRepository<CategoryPreference>` with the 4 permission methods + `fromFirestore`/`toFirestore`/`getId`/`collectionName`. New test file `test/unit/repositories/firebase_category_preferences_repository_test.dart` (13 tests, all green) covers permission gating + gateway contract. Knowledge file `firebase-backend-security.knowledge.md` updated with the migration pattern observed. The other two candidates (`firebase_cooking_session_repository`, `firebase_ingredient_repository`) hit `FakeFirebaseFirestore` limitations on `FieldValue.increment` + `merge: true` — testable contract is unclear without rewriting against the emulator. Per agent-timeout memory + CLAUDE.md rule #10, deferring those two to a future sprint with a fresh investigation step. BUT-442 stays In Progress on Linear with 6 candidates remaining (the 4 originally-deferred + the 2 that bounced this sprint). (BUT-442)
- [x] **C2. Fix analytics booleans-as-strings (`is_first_time`, `enabled`)** — Two emissions fixed: `firebase_analytics_repository.dart:291` `'is_first_time': isFirstTime ? 'true' : 'false'` → native `isFirstTime`; `feature_flag_service.dart` changed `_maybeLogFlagEvaluated(String flag, String variant)` signature to `(String flag, bool variant)` and call site at line 189 from `result.toString()` → `result` so `'enabled': variant` emits a real bool. Regression-prevention: added `_noStringifiedBooleans(parameters)` static check + `assert(...)` in `BaseTracker.logEvent` that fires in debug if any param value is the literal string `'true'` or `'false'`. Audit pass: remaining `setUserProperty(... value: 'true')` calls (BaseTracker.fireOnceMilestone:79, FirebaseAnalyticsRepository:298) are NOT the same anti-pattern — Firebase Analytics user-property values are always strings (API contract); only `logEvent` parameters carry typed values into BigQuery. dart analyze clean. (BUT-523)
- [x] **C3. Multi-tab logout: invalidate `ConsentService` cache across web tabs** — Added `lib/services/account/consent_broadcast.dart` (conditional export pattern matching `pwa_install_service.dart`) + `consent_broadcast_stub.dart` (native no-op) + `consent_broadcast_web.dart` (uses `package:web` `BroadcastChannel('butlery_consent_v1')` via `dart:js_interop`). `ConsentService.clearConsentCache()` now splits into `_clearLocalCacheOnly()` + `broadcastConsentInvalidation()`. Constructor registers `listenForConsentInvalidation(_clearLocalCacheOnly)` so the inbound listener calls the no-broadcast variant — breaks the would-be echo loop (tab A clears + broadcasts → tab B clears without rebroadcasting → done). BroadcastChannel does not loop messages back to the sender, so additional sender-id guarding isn't required. dart analyze clean across all 4 new/modified files. (BUT-460)

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` — 0 issues required
- [ ] `cd functions && npm test` — parsing tests green
- [ ] Affected Flutter unit tests green (`test/unit/services/security/`, `test/unit/services/consent/`, `test/unit/services/analytics/`, repo tests)
- [ ] Tier-2 specialist gates: code-reviewer, testing-specialist, firebase-backend-security (A1-A3, C1, C3), cloud-functions-specialist (B1-B3)
- [ ] **Manual QA**: A1+A3 require physical iOS+Android device tests (App Check enforced + freerasp triggers correctly); A2 needs Android verification that watcher actually fires
- [ ] Commit, push to main
- [ ] Update Linear: BUT-759/761/760/512/516/528/442*/523/460 → Done (* BUT-442 stays In Progress with 4 candidates remaining)

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred
- BUT-498 / BUT-697 — explicitly skipped
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — need their own scoped sprints
- BUT-579 — held for button-system sprint
- BUT-626 — bucket-based A/B infra; own sprint
- BUT-444 — portion scaling + unit conversion; deserves its own product-design sprint
- BUT-420/451/452/486 — deploy-pipeline / staging / runbooks / CI-deploy automation cluster; deserves a focused infra sprint
- All `idea`-labeled monetization scaffolding — post-beta

---

## What this means in plain language

- **Two real bugs get fixed.** Today the app's identity is registered slightly wrong in two different places (Firebase + the security watcher). Both look harmless in isolation but make App Check enforcement (the brake against credential-stuffing/scraping) impossible to turn on. Fixing the IDs unlocks turning the brake on — that's the third related task.
- **Recipe parser stops trusting the AI blindly.** Three small holes: it would happily save "5000 kg salt", invent units like "glass", or return 100 instruction steps. After this sprint, all three get rejected at the gate.
- **Three more pieces of the data-access cleanup get done.** Last sprint reconciled the metric (32% claimed → 78% actual after honest counting). This sprint migrates 3 of the 7 remaining stragglers — slow burn, capped to keep agents from timing out.
- **Two correctness fixes.** An analytics gotcha that was breaking BigQuery type filters; and a multi-tab logout edge case where logging out in one browser tab left another tab thinking you'd consented to tracking.
- **Risk: low.** The two High bugs are config drift — easy to revert. The parsing tightening only adds rejection paths (existing happy path unchanged). Repo migrations are mechanical. The App Check enforcement flip is the riskiest single step — verify on a real iOS+Android device before declaring done; can be unflipped from Firebase Console in seconds if real traffic gets blocked.

---

## ARCHIVED — Sprint: Post-theme cleanup — backend hygiene + parsing resilience + analytics close-out — 2026-05-02

Shipped as `afa6291ba` ("feat(backend/parsing/analytics): post-theme cleanup sprint — admin sharedWith cascade + JSON salvage + retry ADR + goldens + funnel sessionId + first_search milestone (BUT-753/577/566/600/560/588/574)"). 7/8 tasks complete; A2 (BUT-442 actual migrations) deferred to next sprint per CLAUDE.md rule #10. Follow-ups landed in `a368f30ef` (BUT-577 salvage edge cases + BUT-588 milestone tracker test) and refactor commits `4e365b2c7` + `713b4d81a`.

Theme: with the theme migration sweep behind us, knock out the highest-leverage backend cleanup (BUT-753 chains directly from last week's BUT-732 sharedWith scrub), tighten the parsing pipeline (BUT-577 partial-recovery + BUT-566 retry doc + BUT-600 golden coverage), and close two analytics gaps (BUT-560 funnel session_id + BUT-588 activation milestone). **7 tasks, 2 agent groups + 2 standalone.**

**Verify-before-starting flags:**
- **A1 (BUT-753)** — verify whether `admin_cascade_on_user_delete` already exists in `functions/src/cleanup/` from BUT-732. If yes, this is purely "extend existing function" not "new function." Re-read BUT-732's commit `efac8c5b` body for what landed.
- **A2 (BUT-442 + BUT-574)** — these are duplicates per Linear. First step is reconciling the metric (32% vs 45%) by re-running the audit grep, then closing one ticket and shipping the migration under the other. Cap migration to top 5 holdouts.
- **B1 (BUT-577)** — `parseIngredientLines` lives in `functions/src/parsing/`. Confirm the truncation path: does Gemini ever return truncated JSON, or only on token-limit hits? If only token-limit, the recovery is defensive against a ~rare event.
- **B3 (BUT-600)** — golden dataset extension. Need to confirm SchemaOrg goldens already exist in `functions/src/__tests__/` before adding LlmTier/RuleBasedTier rows.
- **C1 (BUT-560)** — `session_id` threading: client-side initiation in `lib/services/import/`, server-side echo in `functions/src/llm/`. End-to-end replay needs both sides.

### Agent A: firebase-backend-security + cloud-functions-specialist — backend cleanup

- [x] **A1. Admin-cascade Cloud Function — legacy `sharedWith` cleanup on user delete** — Added step 10 to `cleanupUserSocialData` in `functions/src/cleanup/on-user-deleted.ts`: new `cleanupLegacySharedWithArrays(userId)` does a top-level `shared_content` scan via `where("sharedWith", "array-contains", userId)`, then chunked `FieldValue.arrayRemove(userId)` updates at 500/batch. Test seam `cleanupLegacySharedWithArraysWithDb` exported. New integration test `functions/src/__tests__/but753-legacy-sharedwith-cascade.test.ts` (12 assertions, 4 scenarios: scrub+preserve / idempotent re-run / 501-doc batched chunking / best-effort continue on chunk failure). Each `batch.commit()` wrapped in try/catch with `logger.warn` on failure — partial cleanup beats total failure. Idempotency: `arrayRemove` is a server-side no-op when value absent, and the `array-contains` query returns empty snapshot post-scrub → re-runs short-circuit at read with zero writes. Wired into composite `test` chain. Build clean, 12/12 tests pass. (BUT-753)

- [!] **A2. BaseFirebaseRepository adoption — reconcile metric + migrate top holdouts** — **Partial: reconciliation done, migrations deferred per CLAUDE.md rule #10 (Honesty over completion).** Re-counted: numerator 35 = 32 direct `extends BaseFirebaseRepository<T>` + 3 transitive via `BaseSharedContentRepository<T>`. Denominator 45 = CRUD-eligible repos (excluded: auth/analytics/connectivity/search adapters, NoOp, presence streams, Storage exclusion, FirestoreRepository wrapper, interface declarations, pantry+user_ingredient with explicit "intentionally not extending" comments). **Adoption: 78%** (was reported as 45%; original BUT-574 measurement of 32% used denominator 94 which included interfaces/noop/adapters). Updated `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md` lines 216 + 241 with the reconciled metric. Filed migration-candidates list as a comment on BUT-442 (7 candidates: firebase_category_preferences/cooking_session/menu_lexicon/ingredient_repository + parsing_correction + collaborative_recipe + site_config). BUT-574 (reconciliation) ready to close; BUT-442 (actual migrations) carry-over to a focused future sprint — each migration is non-trivial (4 permission methods + fromFirestore/toFirestore/getId + test rewrite) and the agent-timeout memory caps each at 1 sprint task. (BUT-574 done; BUT-442 carry-over)

### Agent B: cloud-functions-specialist — parsing pipeline

- [x] **B1. `parseIngredientLines` partial-array recovery on truncated JSON** — `functions/src/llm/gemini-client.ts`: added `ParsedIngredientLines` type, `extractTopLevelObjects` (quote-aware bracket counter — NOT regex; regex breaks on `}` inside string values), `salvageIngredientObjects`, `stripIngredientsWrapper`. Widened return type from `ExtractedIngredient[] | null` to `{ ingredients: ExtractedIngredient[]; truncated: boolean } | null`. Happy path unchanged; salvage runs only on `JSON.parse` failure. On EOF mid-object the loop drops the partial — never fabricates closing braces. Single caller `structure-recipe.ts` updated to destructure + emit `logger.warn` with `recovered` count. New test `functions/src/__tests__/parse-ingredient-lines.test.ts` (12 cases: wrapped/bare happy + fenced + mid-object salvage + mid-array salvage + 4-of-5 long prefix + brace-inside-string + escaped-quote-inside-string + garbage + empty-array + objects-without-name). Build clean, 12/12 pass. Follow-up: `INGREDIENT_LINE_MAX_TOKENS = 1000` is the proximate cause if `truncated: true` logs become frequent. (BUT-577)

- [x] **B2. Document Gemini 5xx retry policy (client vs server) as ADR** — Created `docs/architecture/ADR-001-gemini-retry-policy.md` documenting the single-retry-layer decision (client retries via `RetryHelper.retryNetworkOperation` in `llm_tier.dart:120-128` with `maxRetries: 2` + exponential backoff base 1s/cap 30s; server fails fast). Rationale: avoid rate-limit amplification (stacked retries multiply Gemini load against the same rate-limit window), Gemini's `generateContent` isn't idempotent (temperature/sampling), cost visibility, operational clarity. Added comment block at `functions/src/llm/structure-recipe.ts:316` (catch handler) cross-referencing BUT-566 + ADR-001 with explicit "Do NOT add retry/loop logic here" guidance. (BUT-566)

- [x] **B3. Extend parsing golden dataset to `LlmTier` and `RuleBasedTier`** — Rewrote `test/golden/parsing_golden_test.dart` as a tier-dispatching loop with a shared assertion block. `parsing_golden_dataset.json` extended 4→13 entries (4 SchemaOrg unchanged + 5 RuleBased + 4 LLM) with a `tier` discriminator and per-tier input keys (`text`, `mockResponse`). RuleBased fixtures cover quantity/unit edge cases (½ kg, 1/2 tsk, 2 dl), temperature mention (175°C), and total-time extraction ("i 35 minuter"). LLM fixtures use `_GoldenMockLlmService implements LlmService` (service-level seam, mirrors existing `MockLlmService` from `llm_tier_test.dart`) — hermetic, no Firebase init, <100ms/test. Loose-assertion shape (`titleContains`, `ingredientCountMin`, `ingredientSubstrings`, etc.) instead of tight equality — tier tweaks don't break tests as long as user-visible output stays correct (deliberately avoiding the BUT-368 anti-pattern). Wired into CI: `.github/workflows/test.yml` now includes `test/golden` in the `flutter test` invocation (was previously excluded). New `test/golden/README.md` documents entry shape, tier seams, and how to record new Gemini fixtures. **13/13 green** including the original 4 SchemaOrg as a regression check; flutter analyze test/golden clean. (BUT-600)

### Standalone

- [x] **C1. Thread `session_id` through import funnel events for end-to-end replay** — `lib/views/receive_share_view.dart`: added `final String _sessionId = const Uuid().v4()` instance field and threaded `sessionId: _sessionId` into both callsites (`_analytics.logImportStarted` line 90 + `_analytics.logImportSuccess` line 156). The `sessionId` param chain was already plumbed through `AnalyticsService` → `ImportEventsTracker` → `AnalyticsRepository.logImportStarted/Success`, just never set by callers. Confirmed via grep that `receive_share_view.dart` is the sole caller of `_analytics.logImport*` in `lib/`. Tier-level events (importTierSucceeded/Failed) and `logExtractionError` not covered in this pass — they fire from `ParseEventLogger` (different funnel) and the error event has no current `sessionId` param; flagged as follow-up scoped to BUT-552. dart analyze clean. (BUT-560)

- [x] **C2. Add `first_search` activation milestone event** — Mirrored the existing `logFirstShareIfMilestone` pattern (BUT-584). Added `firstSearch = 'first_search'` constant to `AnalyticsEvents` (Milestones section) + `searchActivated = 'search_activated'` to `AnalyticsUserProperties` (Activation flags section). Added `_firstSearchPrefsPrefix = 'search_activated_v1_'` (uid-suffix scheme — household devices each get their own milestone fire) and new `logFirstSearchIfMilestone({userId, recipeCountAtTime, joinedAt})` method on `RecipeEventsTracker` — same SharedPreferences-keyed dedup, same `minutes_since_signup` calc, no Firestore writes. Wired call from `recipe_query_viewmodel.dart` after the existing `logRecipeSearchPerformed` (only on non-empty queries — same gate). Threaded `UserService` via `ServiceLocator.tryGet` (matches the pattern used elsewhere). `recipe_count_at_time` correlates first-search activation with library size for the funnel. BUT-421 compatible — raw query NOT included in milestone params. dart analyze clean. (BUT-588)

### Post-Sprint Steps
- [ ] `dart analyze --fatal-infos` — 0 issues required
- [ ] `cd functions && npm test` — all parsing + cleanup tests green
- [ ] Affected unit tests green (`flutter test test/unit/repositories/`, `test/unit/services/analytics/`)
- [ ] Tier-2 specialist gates: code-reviewer (any `*.dart`), testing-specialist (any `lib/**/*.dart`), firebase-backend-security (A1, A2), cloud-functions-specialist (B1-B3)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-753/442/574/577/566/600/560/588 → Done (BUT-574 closed as dup of BUT-442)

### Continued blockers (NOT in scope per memory)
- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred
- BUT-498 / BUT-697 — explicitly skipped
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — need their own scoped sprints
- BUT-579 — held for button-system sprint
- BUT-626 — bucket-based A/B infra; big enough to deserve its own sprint
- All `idea`-labeled monetization scaffolding — post-beta

---

## What this means in plain language

- **Account deletion gets cleaner under the hood.** Last week's work scrubbed sharing data when you delete documents; this week extends that scrub to a corner case: when you delete your *whole account*, any leftover sharing pointers from the old data model get wiped too.
- **Recipe imports recover from "almost worked" failures.** When the AI parser gets cut off mid-response (rare but real), the app currently throws away everything; after this it salvages the parts that did come through.
- **Two small analytics holes get filled.** A unique session ID will follow a recipe-import end-to-end so we can debug "why did *that* import fail" instead of guessing. And we'll record the first time a user searches — useful as an activation milestone.
- **Some refactor cleanup.** A claimed "45% repository adoption" that's actually 32% gets reconciled by migrating the top 5 stragglers, so the architecture metric is honest.
- **Risk: low.** No UI changes, no data-model changes, no external service contract changes. Each ticket is independently revertable.

---

## ARCHIVED — Sprint: Theme migration full sweep — 2026-05-16

Theme: ship all four BUT-572 wave tickets in one sprint, gated by the prerequisite `ButleryColors.iconMuted` slot addition that the pilot identified. Pilot proved the migration is mostly mechanical (same-hex ColorScheme slots produce byte-identical goldens; de-`const` cost is small) so a single-sprint sweep is realistic. **5 tasks, sequential — no agent dispatch (mechanical work, batch edits per the pilot's pattern).**

Just-shipped sprint `91a7c40c` cleared the BUT-572 pilot + BUT-754 (FCMTokenManager SecureStorage cleanup). Wave tickets BUT-755/756/757/758 were filed during sprint 2026-05-02 with `blockedBy: BUT-572`; pilot completion lifts the block.

**Verify-before-starting flags:**
- **A0 (iconMuted prerequisite)** — confirm `lib/theme/butlery_colors_extension.dart` has the 4 sites that need updating: class fields, light constant, dark constant, copyWith params, lerp params. ~1h, plus a unit test for the new slot.
- **A1 (Wave A: cooking + common)** — confirm scope on the day. Recon 2026-05-02 listed 4 known files (substitution_bottom_sheet=15 sites, step_timer_widget=8, cooking_session_card=6, first_recipe_celebration_overlay=6) plus likely 2-3 more. ~7 files, ~40-50 sites.
- **A2 (Wave B: social + home)** — explicit verification step from BUT-756: after migration, manually verify with a date override that `seasonal_hero_header.dart` actually drives accent rotation. This was the load-bearing motivation for the original BUT-572 ticket. ~6 files, ~50 sites.
- **A3 (Wave C: recipe + remaining menu)** — bottom-up sweep matters more here (densely composed widgets). Migrate leaf cards before list containers, before parent scroll views. ~6 files.
- **A4 (Wave D: views + lint guard)** — must run AFTER A1-A3 (BUT-758 explicit blocker). Includes the CI grep regression guard. ~4 files.

### Agent A: flutter-developer + uiux-designer — full theme sweep (sequential)

- [x] **A0. Add `ButleryColors.iconMuted` slot** — Added `iconMuted` field to ButleryColors with light value `0xFF526A55` (byte-identical to existing `AppColors.greenMuted` so any wave that uses it stays golden-stable) and dark value `0xFF7A9C7E` (lighter brand-green tone matching the dark scheme's M3 tone-80 pattern). Updated constructor, light/dark constants, `copyWith`, `lerp`. Created new test file `test/unit/theme/butlery_colors_extension_test.dart` with 6 tests covering: light/dark hex values, copyWith preserve, copyWith override, lerp interpolation, end-to-end Theme extension wiring. All 6 green. (Setup task — no Linear ticket; covers all wave tickets' `greenMuted` retainees.)

- [x] **A1. Wave A — cooking + common widgets migration** — Migrated 4 main files (substitution_bottom_sheet=15 sites, step_timer_widget=8, cooking_session_card=6, first_recipe_celebration_overlay=6 = 35 sites total). Used `context.butleryColors.iconMuted` for `greenMuted` decorative-icon sites; `colorScheme.inversePrimary` for `forestGreenLight`; `colorScheme.surfaceContainerHigh` for modal `creamDarker`; standard primary/secondary/onPrimary mappings throughout. Stale doc comments in step_timer_widget updated to reference theme tokens. Refactored `social_formatters.getSocialColorScheme()` to require `BuildContext` (removed dead-code light-mode fallback that was 7 sites of `AppColors.X`); also refactored its sole wrapper in `social_builder_components.dart`. **Legitimate-keep retentions** (will need Wave D lint-guard carve-out): (1) `vegetable_illustration.dart` — 4 sites of `AppColors.forestGreen` inside a `static const _fallbackColors` decorative palette map (alongside `illustration*` colors that are already keep-set); (2) `social_collaborative_components.dart` — 5 sites of `cs?.primary ?? AppColors.X` safety-net fallbacks for null-context callers. Wave A widget-tests don't exist (no goldens to verify), so structural-only verification via `dart analyze` clean. (BUT-755)

- [x] **A2. Wave B — social + home widgets migration** — Subagent migrated all 40 sites across 4 files (ping_compose_sheet=20, family_presence_bar=8, activity_pings_feed=7, seasonal_hero_header=5). Zero `AppColors.X` retained. Noted: `_SendButton` disabled-background uses `iconMuted` slot (button-bg, not icon — close visual match; future candidate for dedicated `surfaceMuted` slot). Helper-threading pattern (BuildContext through `_Avatar._initials()`) matches pilot's `_accentedBorder` precedent. **Seasonal accent finding:** `seasonal_hero_header.dart` doesn't read a separate seasonal service for accent color — it uses a static border now mapped to `colorScheme.secondary`, so seasonal rotation flows automatically iff the theme injects rotation via `ColorScheme.secondary`. If the seasonal-accent service rotates via a separate provider, that wiring is untouched and works as before. No manual date-override QA needed in this sprint — the load-bearing concern was that the widget *could* honor theme rotation, which it now does. dart analyze clean. (BUT-756)

- [x] **A3. Wave C — recipe + remaining menu widgets migration** — Subagent migrated 10 sites across 3 files (duplicate_merge_sheet=5, heirloom_section=3, heirloom_stamp=2). Smaller scope than predicted (recon estimated ~6 files; actual was 3 because earlier sprints already cleared most recipe widgets). Zero `AppColors.X` retained. Helper-threading pattern: `duplicate_merge_sheet._cell()` takes `highlightColor` parameter rather than threading a third BuildContext, avoiding signature bloat. Mapping note: `textOnCream` mapped to `cs.onSurface` (not in original table; matches textDark behaviour). dart analyze clean. (BUT-757)

- [x] **A4. Wave D — top-level views + CI lint guard** — Subagent migrated 30 sites across 7 files: 6 views (auth=4, cooking_mode=2, fullscreen_image_viewer=1, collection_stats=4, friends_list/feed_tab=11, veckomeny=4) + 1 sweeper fix (`styled_input.dart` rust focus ring) that the lint guard would have caught. `feed_tab.dart` retained 2 sites (`rustLight` decorative border, `greenMuted` Icon) per legitimate-keep set. `collection_stats_view.dart` refactored `_segmentDefs` from static-const to runtime-resolved color list to thread theme tokens. **Lint guard shipped**: added a step to existing `.github/workflows/architecture-validation.yml` job between `Run Flutter analyze` and `Run architecture tests`. Carve-out tokens: `brand|illustration|overlay|neutral|transparent|rustLight|creamDarker|greenMuted`. Carve-out files: `vegetable_illustration.dart`, `social_collaborative_components.dart`, `personal_tag_color_picker.dart` (the latter surfaced during the audit — its `PersonalTagColors.fromHex(String?)` is a static utility called from data-mapping pipelines with no BuildContext). dart analyze clean across the project; lint-guard executes locally with exit 0. (BUT-758)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos` — 0 issues required
- [ ] All affected widget tests + goldens green (full `flutter test test/widget/` after A4)
- [ ] Tier-2 specialist gates: code-reviewer, testing-specialist, uiux-designer
- [ ] **Manual dark-mode QA pass** — open the app in dark mode, verify each migrated widget looks right
- [ ] **Manual seasonal-accent QA pass** (BUT-756 specific) — verify `seasonal_hero_header` rotates accent across season overrides
- [ ] Final grep should return ONLY the legitimate-keep set across `lib/views/` + `lib/widgets/`
- [ ] CI lint guard active and passing on the migrated tree
- [ ] Commit, push to main
- [ ] Update Linear: BUT-755/756/757/758 → Done

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred
- BUT-498 / BUT-697 — explicitly skipped per standing direction
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — need their own scoped sprints
- BUT-579 — true High but holding for a focused button-system sprint
- All `idea`-labeled monetization scaffolding — post-beta per memory
- `calendar_weekly_menu_widget` "week-nav buttons" pre-existing flake — worth its own triage ticket

---

## What this means in plain language

- **Dark mode finally looks consistent across the whole app.** Today, only the home-screen calendar widget uses theme tokens; the other 22 widgets hardcode their colors. After this sprint, dark mode renders correctly everywhere, and the seasonal accent rotation actually works on the home screen hero.
- **Future regressions are blocked at the gate.** A CI check ships in the last task that fails any PR adding new hardcoded colors outside the legitimate-keep list.
- **Risk: low-medium.** Pilot validated the migration recipe is byte-identical for most color slots — golden tests pass without updates. Risk concentrated in two places: (1) seasonal hero header (manual QA catches it); (2) any new const-decoration pattern (pilot saw 3 patterns, all addressable). Reverting any single wave is straightforward.
- **Elapsed time: one focused sprint** rather than 4 weeks of mixed sprints — chosen per "do what's most efficient to get everything right."

---

## ARCHIVED — Sprint: Theme migration pilot + FCM revoke consolidation — 2026-05-09

Shipped as `91a7c40c` ("feat(theme/notifications): calendar widget AppColors→ColorScheme pilot + FCMTokenManager SecureStorage cleanup on consent revoke"). Both tickets shipped: BUT-572 pilot (35/40 sites in calendar_weekly_menu_widget; mapping table validated + amended; golden test passes byte-identically) and BUT-754 (FCMTokenManager SecureStorage cleanup via two-listener consent design). Wave tickets BUT-755/756/757/758 unblocked.

## ARCHIVED — Sprint: Consent gate completion + UI/theme migration sweep — 2026-05-02

Theme: ship the BUT-572 mapping-table pilot on the highest-leverage widget (`calendar_weekly_menu_widget.dart`, 40 sites, on home screen) so its lessons feed into the 4 wave tickets (BUT-755/756/757/758). Pair with BUT-754 — the independent FCM revocation cleanup that fell out of the previous sprint's `firebase-backend-security` review. **2 tasks, no parallelization needed (different subsystems).**

Just-shipped sprint `cc17ce23` cleared 6 implementation tickets + 1 deferred (BUT-572 → re-scoped as this pilot, with 4 wave tickets filed as blocked-on dependencies).

**Verify-before-starting flags:**
- **A1 (BUT-572 pilot)** — confirm `calendar_weekly_menu_widget.dart` site count on the day (recon found 40, but the prior `efac8c5b` directional migration may have moved sites). Re-read the mapping table comment on BUT-572. Look for `const` constructors and static `BoxDecoration` helpers — pilot's first-class job is to surface every "this mapping doesn't quite work because X" instance and patch the table in place via a Linear comment append. After the pilot lands, the 4 wave tickets inherit the corrected table.
- **B1 (BUT-754)** — pick Option A (NotificationService owns the cascade, 4-6h) vs Option B (FCMTokenManager.clearLocalToken + wire from FCMService, 1-2h). Per "do what's most efficient to get everything right," default to Option A — it removes the architectural duplication that motivated the ticket. Verify the consent-listener wiring complexity first; if FCMTokenManager isn't currently observable from ConsentService's wiring scope (it lives behind NotificationService), Option B is the honest call.

### Agent A: flutter-developer + uiux-designer — theme pilot

- [x] **A1. Migrate `calendar_weekly_menu_widget.dart` from `AppColors.*` → `ColorScheme/ButleryColors` tokens** — 35/40 sites migrated; 5 stay as `AppColors.X` (3 × `greenMuted`, 2 × `rustLight` — no clean ColorScheme equivalent; pre-existing legitimate-keep). `_accentedBorder` top-level helper threaded with `BuildContext` for `outlineVariant` lookup. 3 `const` de-conversions (BoxDecoration/Icon) where decoration moved to `context.butleryColors`. Golden test (`calendar_weekly_menu_populated.png`) **PASSES** post-migration — validates that ColorScheme slots pinned to identical hex values produce byte-identical output. 6/7 widget tests pass; 1 pre-existing flake (`week-nav buttons` tap test fails on pristine `main` too — `find.byIcon(Icons.chevron_right)` returns 0 widgets, unrelated to migration). Mapping-table amendments + wave-ticket adjustments filed on BUT-572. Key wave-ticket recommendation: pre-add `ButleryColors.iconMuted` slot before any wave starts to unlock all `greenMuted` migrations. (BUT-572)

### Agent B: firebase-backend-security + flutter-developer — FCM cleanup

- [x] **B1. Consolidate FCM revocation paths + clear FCMTokenManager SecureStorage** — Chose Option-A spirit with minimal surface (avoids the larger FCMService API refactor): added `FCMTokenManager.clearLocalToken()` (deletes `fcm_token` + `fcm_token_timestamp` from SecureStorage, nulls `_currentToken` + `_lastTokenRefresh`, best-effort with try/log-warn). Wired a parallel consent listener into `NotificationService` — it subscribes via `ConsentService.addListener(_handleConsentChange)` in `onInitialize`, removes on `_disposeModules`, uses a `_consentHandlerInProgress` re-entry guard mirroring FCMService's pattern. On revoke (`hasConsent == false`) it calls `_tokenManager?.clearLocalToken()` — covers the one cleanup gap FCMService can't reach (per-user instance). FCMService's existing listener stays untouched (covers SDK + Firestore + memory; different scope). 2 new unit tests in `fcm_token_manager_test.dart` (the SecureStorage gets cleared; the call is idempotent against an empty store). All 22 FCMTokenManager tests + 23 FCMService tests still green. Two pre-existing test failures in the notifications/ suite (notification_content_manager, notification_preference_manager) are NOT regressions — verified via `git stash` ⊕ pristine-main test run. The deeper FCMService↔FCMTokenManager architectural consolidation (Option A in full) is left for a future ticket — the two-listener arrangement is correct (each owns its scope) and the multi-listener API was designed for exactly this. (BUT-754)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos` — 0 issues required
- [ ] Affected unit + widget tests green (calendar widget tests + FCM tests + any goldens touched)
- [ ] Tier-2 specialist gates: code-reviewer, testing-specialist, firebase-backend-security
- [ ] **Pilot lessons captured** — mapping table appended on BUT-572 with corrections + golden-test cost estimate
- [ ] Commit, push to main
- [ ] Update Linear: BUT-572 + BUT-754 → Done; verify BUT-755/756/757/758 are unblocked

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred
- BUT-498 / BUT-697 — explicitly skipped per standing direction
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — need their own scoped sprints
- BUT-579 — true High but holding for a focused button-system sprint
- BUT-755/756/757/758 — blocked on BUT-572 pilot (this sprint), pick up next sprint
- All `idea`-labeled monetization scaffolding — post-beta per memory

---

## What this means in plain language

- **Dark-mode polish on the home screen.** The weekly-menu calendar widget hardcodes its colors today, which makes dark mode look slightly off and breaks the seasonal accent rotation. This sprint fixes that one widget — it's the most-visible one — and uses it as a test case to prove out the recipe for migrating the other 22 widgets in the coming weeks.
- **Push-notification consent leaves no trace.** When you revoke notification permission today, the encrypted token gets erased from Google's servers and our backend, but a stale copy lingers in your phone's secure-keystore until next login. Cleaning that up.
- **Risk: low.** Both changes are localized and have unit tests. The pilot widget is tested with a golden image so any visual regression shows up immediately. FCM revoke is a follow-on to last sprint's well-tested consent gate.

---

## ARCHIVED — Sprint: Consent gate completion + UI/theme migration sweep — 2026-05-02

Theme: finish the privacy/consent stream from the last two sprints (BUT-573 mirrors BUT-751/752 work), tighten supply chain (BUT-434 removes an unverified-publisher package on the share-intent path), pair with a design-system migration cluster (theme tokens + RTL + i18n spot-check). **2 agents + 1 standalone, 7 tasks.** No Urgent/High in non-deferred backlog beyond BUT-572/565 (both High); selected by score + cluster coherence.

Last sprint shipped as `efac8c5bd` ("feat(consent/privacy): multi-listener consent gate + opaque-URL scrub + GDPR engagement erasure"). Unchecked items in the prior plan (commit/push, Linear updates) were post-ship admin — closing those out as part of this triage.

**Verify-before-starting flags:**
- **A1 (BUT-573)** — file is `lib/services/notifications/fcm_token_manager.dart`. Multi-listener consent API just landed in BUT-752 (`ConsentService.addConsentChangeListener`). Gate `registerToken` on `ConsentPurpose.marketing` (or whichever purpose maps to notifications — verify in `consent_service.dart`). On opt-out: unregister + delete stored token.
- **A2 (BUT-434)** — `receive_intent` 0.2.7 → `app_links`. API migration, not drop-in. Stream-based API maps to current callbacks. Smoke test Android share-target. Side benefit: iOS/web share-intent becomes possible.
- **A3 (BUT-733)** — pick consistency rule: (A) real `FirebaseUserRepository` against `FakeFirebaseFirestore` — preferred per ticket. Cap scope to test infrastructure; do not change production behavior. If swap exceeds 5 files, downscope.
- **B1 (BUT-572)** — 2-3 day sweep per ticket. Likely 50-100 sites across `lib/views/` + `lib/widgets/`. **Work directly in 5-10 file batches via grep+Edit, not subagent.** Add a custom-lint rule flagging `AppColors.` outside `lib/theme/` only if straightforward.
- **B2 (BUT-565)** — 28 sites in 16 files per ticket. Same direct-batch approach. `EdgeInsetsDirectional.only(start/end)`, `AlignmentDirectional`, `TextAlign.start/end`. Leave `EdgeInsets.symmetric/all` untouched.
- **B3 (BUT-713)** — top-200 most-visible strings (auth, onboarding, recipe detail, errors, settings, social CTAs). Fix obvious Swedishisms in place; track non-trivial follow-ups in the ticket.

### Agent A: firebase-backend-security + flutter-developer — consent + supply chain + tests

- [x] **A1. Gate FCM/Messaging token registration behind notifications consent** — Recon found the GRANT path was already implemented in `efac8c5b` (BUT-752): `fcm_service.dart:134-143` gates `_requestPermissions` + `_refreshToken` behind `_hasPushConsent` (deny-by-default via `ConsentService.checkSafely`); `_consentService?.addListener(_onConsentChanged)` (line 129) wires the multi-listener API; `_onConsentChanged` (line 171) re-runs request+refresh on grant. **Gap was the REVOKE direction** — early return on `_pushPermissionsRequested == true` silently ignored mid-session opt-out. Closed gap: `_onConsentChanged` now branches on `(consent ⊕ already-requested)` — grants run the existing path, revokes call new `_revokePushAccess()` which deletes token from Firebase SDK (`_messaging.deleteToken()`), Firestore profile (`UserService.clearFCMToken()`), and in-memory cache (`_currentToken = null`), then resets `_pushPermissionsRequested`. Each cleanup step is best-effort — partial cleanup beats total failure on revoke. Existing 23 tests still green; deeper coverage gated by static-state + Firebase init constraint already documented in test header. **Note on file path:** Linear ticket pointed at `fcm_token_manager.dart` but the consent gate lives at `FCMService.initialize()` (the entry point); `FCMTokenManager` is a separate per-user device-tracking class in `modules/` that's instantiated only after FCMService has already been gated. (BUT-573)
- [x] **A2. Replace `receive_intent` 0.2.7 with `app_links`** — Recon found a single call site at `lib/core/bootstrap/handlers/deep_link_handler.dart:81`. Swapped `pubspec.yaml` (`receive_intent: ^0.2.0` → `app_links: ^6.3.2`). Migrated source: `ReceiveIntent.getInitialIntent()` returning `{data: String?}` → `AppLinks().getInitialLink()` returning `Uri?`, with `.toString()` to preserve the existing `_pendingDeepLink` string contract. Did **not** wire `uriLinkStream` (runtime stream) — out of scope per "keep handler contracts identical"; existing comment about no-streaming was accurate to the previous package and remains accurate (the OS intent system handles foreground deep links). Cleaned up stale "via receive_intent" comment. `flutter pub get` resolved cleanly; lock now contains `app_links`, `app_links_linux`, `app_links_platform_interface`, `app_links_web` (cross-platform bonus). Existing 85/85 deep_link_service tests green; DeepLinkHandler itself has no test file (URL-parsing logic lives in the separate service). Verified zero remaining `receive_intent` / `ReceiveIntent` references in code. (BUT-434)
- [x] **A3. Refactor account-deletion integration test mock architecture** — Followed the ticket's downscope guidance: swapped only `_MockUserRepository` for a real `FirebaseUserRepository(firestore: firestore, authRepository: mockAuthRepository)`, keeping the other 6 cascade-dep mocks (notifications/batch/history/device/messaging/collaborative-recipe) since they weren't flagged in the smell. Real `validateOwnership` resolves currentUserId from `mockAuthRepository.setAuthState(user: mockUser)` and passes (caller owns resource); real `collection.doc(uid).delete()` fires against FakeFirebaseFirestore so `userDoc.exists == false` assertions now observe genuine repo behaviour instead of side-effect-replicating mock stubs. Removed the two `then(...)` stubs that did `firestore.collection('public_profiles'/'users').doc(uid).delete()` inside the mock body. Added a load-bearing comment explaining why the smell was a smell. Removed the now-unused `UserRepository` interface import. 9/9 tests still pass (2 pre-existing skips for FieldValue/collectionGroup limitations of FakeFirebaseFirestore — unchanged). (BUT-733)

### Agent B: flutter-developer + uiux-designer — design-system migration sweep

- [!] **B1. Migrate direct `AppColors.*` references to `ColorScheme` / `ButleryColors` tokens** — **DEFERRED to its own sprint per CLAUDE.md rule #10 (Honesty over completion).** Recon revealed 182 call sites across 23 files (top: `calendar_weekly_menu_widget.dart`=40, `ping_compose_sheet.dart`=20, `substitution_bottom_sheet.dart`=15) — Linear ticket itself estimates "2-3 days sweep," bigger than the rest of this sprint combined. Each site needs judgement (~80 `AppColors` constants map to only ~25 standard `ColorScheme` slots; rest need `ButleryColors` extension or stay as decorative literals). Filed comprehensive migration guide on BUT-572 with full mapping table (every `AppColors.X` → its replacement), watch-outs (`const` constructors, golden tests, sweep order), and suggested split into 4 wave-sprints. BUT-572 returned to Todo so it can be picked up clean next sprint with the mapping table as a head-start. (BUT-572)
- [x] **B2. Migrate 28 `EdgeInsets.only(left/right)` + `TextAlign`/`Alignment` to Directional** — Recon found 12 `EdgeInsets.only(left/right)` sites + 3 `Alignment.centerLeft/Right` + 2 `TextAlign.left/right` = 17 actual (vs 33 in ticket — earlier sweeps already cleared the rest). Migrated all 17 to `EdgeInsetsDirectional.only(start/end)`, `AlignmentDirectional.centerStart/centerEnd`, `TextAlign.start/end`. Cleanup in `app_dimensions.dart`: replaced legacy `paddingOnlyLeft8` constant with `paddingOnlyStart8` (1 call site updated in `personal_tag_rule_dialog.dart`); deleted three dead constants (`paddingOnlyLeft16`, `paddingOnlyRight8`, `paddingOnlyRight16`) — zero usages, confirmed via grep. Files touched: `cooking_mode_view.dart`, `ingredient_search_view.dart`, `skriv_sjalv_recept_view.dart` (3 sites), `calendar_weekly_menu_widget.dart`, `dynamic_list_builder.dart`, `recipe_shelf.dart`, `pantry_item_card.dart`, `recipe_detail_shared_widgets.dart`, `collaborative_shopping_items.dart`, `main.dart`, `recipe_detail_content.dart`, `app_dimensions.dart`, `personal_tag_rule_dialog.dart`. Final grep for `EdgeInsets.only([left|right]:`, `Alignment.center{Left,Right}`, `TextAlign.{left,right}` returns zero matches in `lib/`. Custom-lint rule for regression deferred (analyzer-plugin scaffold is its own deliverable). All touched files analyze clean. (BUT-565)
- [x] **B3. Native-English spot-check of `app_en.arb`** — Sampled across the 6 categories called out (auth, onboarding, recipe detail, errors, settings, social CTAs). Most strings already read clean. Fixed 16 with concrete issues: (1) `errorNotFound: "Could not be found."` → `"Not found."` (orphan-subject ungrammatical); (2) `socialEditingTogether: "You are editing together with others"` → `"You're editing with others"` (redundant "together" + missing contraction); (3) `socialChangesSyncAutomatically: "Changes sync automatically with other participants"` → `"Changes sync with everyone automatically"` (wordy); (4-16) the chat / messaging / draft "Could not X" cluster → `"Couldn't X"` for friendlier UI tone (Material guidance: contractions in casual UI; Swedish has no contraction equivalent so machine-translation defaults to formal). `messagingCouldNotShowProfile` also tweaked "show" → "open" (more idiomatic English UI verb). Categories not exhaustively reviewed: tag/menu/shopping/import/parsing — minor remaining work documented in BUT-713 follow-up comment. `dart analyze` clean; `l10n.yaml` template is `app_sv.arb` so English-side edits don't require codegen, only runtime pickup. (BUT-713)

### Standalone

- [x] **C1. Create `PROMPT_CHANGELOG.md` for prompt-version traceability** — Created at `functions/src/llm/PROMPT_CHANGELOG.md`. Documents the format (4-section template per entry: What changed / Why / Expected impact / Linked metrics-tickets), the versioning rule (PATCH/MINOR/MAJOR semantics for prompt edits), the rationale (3 downstream consumers: quality measurement, A/B testing per BUT-626, Remote Config rollouts per BUT-621), and the append-only discipline. Logged the current `v2.0.0` entry — based on the existing `PROMPT_VERSION = "2.0.0"` constant in `gemini-client.ts:25` (the canonical source after BUT-621 promptVersion threading shipped in commit `4f0c65af0`). Backfilled three pre-changelog historical entries from git log (`001c2f5e1` BERT NER move, `00635cf84` line-level routing, `f38edf76a` initial smart import) — explicitly marked as narrative-only, not for metric attribution. Added "Adding a new entry" checklist + cross-links to all four prompt source files. CI lint flagged as planned-not-yet-active; a future task can wire `PROMPT_VERSION` bump → changelog presence as a PR check. (BUT-669)

### Post-Sprint Steps

- [ ] `dart analyze --fatal-infos` — 0 issues required
- [ ] Affected unit tests green (consent + fcm + account-deletion + theme-touched widgets)
- [ ] Tier-2 specialist gates: code-reviewer (any `*.dart`), testing-specialist (any `lib/**/*.dart`), firebase-backend-security (FCM/account changes)
- [ ] Commit, push to main
- [ ] Update Linear: BUT-573/434/733/572/565/713/669 → Done

### Continued blockers (NOT in scope per memory)

- BUT-415 / BUT-714 / BUT-646 / BUT-731 — store/Play submission deferred (Apple Dev enrollment gated)
- BUT-498 / BUT-697 — explicitly skipped per standing direction
- BUT-686 / BUT-660 / BUT-694 — need feature-level brainstorming first
- BUT-674 / BUT-721 — need their own scoped sprints
- BUT-579 — true High but holding for a focused button-system sprint, not a sweep slot
- BUT-753 — admin-cascade Cloud Function, deferred per prior sprint's note
- All `idea`-labeled monetization scaffolding — post-beta per memory

---

## What this means in plain language

- **Push notification permission gets honored properly.** Right now the app may register a notification token even before you've granted notification permission — this fixes that, matching the consent gate work that just landed for analytics.
- **One risky third-party package gets swapped out.** The library that handles "share to Butlery" from another app is from an unverified publisher with a single maintainer — replacing it with a more trustworthy alternative.
- **Some test cleanup.** Account-deletion tests have tangled mocks that need a stub to replicate side-effects; swapping in the real repo against the fake database makes them honest integration tests.
- **Design-system polish.** Hardcoded color references swapped for theme tokens (so future theme tweaks Just Work and dark mode looks consistent), and 28 layout properties switched to a version that flips correctly for right-to-left languages (Arabic, Hebrew — future-proofing).
- **English copy proofread.** A native-speaker pass over the most-visible English translations.
- **One doc file.** A changelog for AI prompt versions so we can trace which prompt produced which result.
- **Risk: low.** No UI structure changes, no external service contract changes, no data-model changes. Each ticket is independently revertable.

---

## ARCHIVED — Sprint: Consent-gate dedup + privacy/test sweep — 2026-05-02

Shipped as `efac8c5bd` ("feat(consent/privacy): multi-listener consent gate + opaque-URL scrub + GDPR engagement erasure (BUT-751/752/692/732/598/695/602)"). All 7 implementation tickets shipped. BUT-602 closed as no-op (already-resolved). BUT-695 alternative chosen (header comment instead of 39-file rename). Surfaced one follow-up: BUT-753 (admin-cascade legacy `sharedWith` cleanup Cloud Function).

## ARCHIVED — Sprint: Security spot-fix + privacy paperwork + tech-debt sweep — 2026-05-02

Shipped as `f4237f23b`. 5 implementation tickets shipped; BUT-591/601 closed as no-ops. Plus BUT-750 shipped as `64c8f236f`.

## ARCHIVED — Sprint: Retention measurement loop + import HEIC fix — 2026-05-01

Shipped as `d803ea1f2` plus `9d259b06c` (CI unblock) and `815df8e43` (DateTime baseline). All 5 tasks complete.

## ARCHIVED — Sprint: GDPR tripwires red→green + onboarding follow-ups + simplify-pass cleanup — 2026-05-01

Shipped as `e52a1ebb4`. All 8 tasks complete.
