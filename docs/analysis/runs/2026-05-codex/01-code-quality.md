BUTLERY CODE QUALITY & ARCHITECTURE ANALYSIS - PHASE 1 FINDINGS
================================================================
Analysis Date: 2026-05-02
Analyst: Codex (GPT-5)
Codebase: 1,252 hand-written .dart files, 327,280 LOC (excluding generated)

OVERALL SCORE: 63/100
+-- Architecture Compliance:        11/20 points
+-- File Size & Complexity:          8/15 points
+-- Deduplication & Infrastructure:  9/15 points
+-- Error Handling & Resilience:    10/15 points
+-- Documentation Health:            7/10 points
+-- Code Readability:                6/10 points
+-- Production Readiness:            8/10 points
+-- Deprecated API & Tech Debt:      4/5 points

STATUS: Needs Work

CRITICAL ISSUES: 1 found
HIGH PRIORITY: 8 found
MEDIUM PRIORITY: 13 found
LOW PRIORITY: 11 found

## Dimension 1 - Architecture Compliance (11/20)
Summary:
Core layering is mostly present, but there are repeated layer bypasses where views/viewmodels call repositories directly and where view-layer helper classes instantiate services directly. Architecture enforcement tests currently check only a narrow FirebaseFirestore singleton rule and therefore do not catch these broader MVVM/repository violations. Data source discipline is also inconsistent for user profile fields.

### HIGH
1) View layer directly calls repositories (MVVM layer bypass)
- Evidence: "'`lib/views/social/shared_with_me/shared_content_actions.dart:15`, `lib/views/social/shared_with_me/shared_content_actions.dart:16`, `lib/views/social/shared_with_me/shared_content_actions.dart:433`, `lib/views/social/shared_with_me/shared_content_actions.dart:475`, `lib/views/social/friends_list/feed_tab.dart:14`, `lib/views/social/friends_list/feed_tab.dart:346`, `lib/views/social/friends_list/feed_tab.dart:347`, `lib/viewmodels/public_profile_viewmodel.dart:6`, `lib/viewmodels/public_profile_viewmodel.dart:7`, `lib/viewmodels/public_profile_viewmodel.dart:27`, `lib/viewmodels/public_profile_viewmodel.dart:36`
- Impact: Business/data access policy can diverge across UI entry points; harder to test and secure consistently.
- Required fix: Route these actions through ViewModel -> Service -> Repository paths and keep repository types out of views.
- Effort: 2-4 days.

2) ViewModel-side storage module performs direct Firestore persistence logic
- Evidence: `lib/viewmodels/menu/menu_storage.dart:3`, `lib/viewmodels/menu/menu_storage.dart:9`, `lib/viewmodels/menu/menu_storage.dart:64`, `lib/viewmodels/menu/menu_storage.dart:65`, `lib/viewmodels/menu/menu_storage.dart:104`, `lib/viewmodels/menu/menu_storage.dart:105`
- Impact: Data-access rules are embedded in viewmodel-adjacent code, raising coupling and increasing regression surface.
- Required fix: Move persistence operations into a dedicated service/repository boundary and keep `MenuStorage` orchestration-only.
- Effort: 1-2 days.

3) Data source discipline violation risk (auth-profile used for denormalized user metadata)
- Evidence: Prompt rule: `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:107`, `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:108`, `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:109`, `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:110`; auth-derived currentUser model: `lib/services/permission_service.dart:123`, `lib/services/permission_service.dart:124`, `lib/services/permission_service.dart:129`, `lib/services/permission_service.dart:132`; usage for shared metadata: `lib/services/unified/operations/modules/recipe_sharing_manager.dart:533`, `lib/services/unified/operations/modules/recipe_sharing_manager.dart:534`; additional usage: `lib/services/realtime/realtime_menu_service.dart:53`, `lib/services/realtime/realtime_menu_service.dart:54`
- Impact: Display/avatar fields can be stale or incomplete versus profile source of truth; subtle persistence inconsistency risk.
- Required fix: For denormalized social/display fields, source from `UserService.currentUserProfile`; keep `PermissionService.currentUser*` for auth/permission checks.
- Effort: 1-2 days.

### MEDIUM
1) Direct service instantiation in view-layer helper
- Evidence: `lib/views/messaging/chat_view/chat_action_handler.dart:35`, `lib/views/messaging/chat_view/chat_action_handler.dart:36`, `lib/views/messaging/chat_view/chat_action_handler.dart:37`, `lib/views/messaging/chat_view/chat_action_handler.dart:38`
- Impact: Runtime wiring and test seams are harder to control; lifecycle consistency depends on ad-hoc instantiation paths.
- Required fix: Inject `MessagingMediaService` from DI instead of constructing inside the action handler.
- Effort: 0.5-1 day.

2) Singleton Firebase access appears outside repository layer
- Evidence: `lib/views/onboarding/onboarding_age_gate_blocked_view.dart:22`, `lib/core/di/di_container.dart:237`, `lib/services/notifications/fcm_service.dart:80`, `lib/services/notifications/modules/fcm_token_manager.dart:84`
- Impact: Broadens direct SDK coupling and makes policy/testing patterns less uniform.
- Required fix: Centralize singleton access behind service/repository seams where possible.
- Effort: 1-2 days.

3) Architecture guardrails are narrow and can pass despite layer bypasses
- Evidence: test scope: `test/architecture/architecture_test.dart:65`, `test/architecture/architecture_test.dart:72`, `test/architecture/architecture_test.dart:86`, `test/architecture/architecture_test.dart:103`; test run pass signal: `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:6`
- Impact: CI architecture checks can report green while real MVVM/repository bypasses persist.
- Required fix: Add architecture assertions for view/viewmodel repository imports and service instantiation in UI layer.
- Effort: 1-2 days.

Recommendations:
- Enforce import constraints (`views` and `viewmodels` cannot import repository implementations).
- Add lint/architecture tests for direct `Service(` construction in UI layer.
- Normalize user identity/display sourcing rules in one ADR and enforce via helper APIs.

Quick wins:
- Refactor `SharedContentActions` and `PublicProfileViewModel` first (high impact, localized files).

## Dimension 2 - File Size & Complexity (8/15)
Summary:
File-size pressure is very high: 131 non-generated Dart files exceed 500 lines and 6 exceed 1000 lines. The accepted-large-file registry is present and recently updated, but method-level complexity remains concentrated in long UI builds and DI configure methods.

### HIGH
1) High concentration of large files
- Evidence: `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:2`, `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:132`
- Impact: Reviewability, onboarding speed, and change isolation degrade as files grow.
- Required fix: Prioritize extraction in non-core UI and orchestration hotspots first.
- Effort: 8-12 days (batched).

2) Six files over 1000 lines
- Evidence: `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:2`, `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:3`, `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:4`, `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:5`, `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:6`, `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:7`
- Impact: Elevated defect and merge-conflict probability in high-change files.
- Required fix: Split along existing seams (handlers/build sections/modules) before adding features.
- Effort: 5-8 days.

### MEDIUM
1) Large-method hotspots (top 20 by span proxy)
- Evidence locations:
  - `lib/views/recipe_detail_view.dart:159`
  - `lib/views/skriv_sjalv_recept_view.dart:268`
  - `lib/views/auth_view.dart:153`
  - `lib/core/di/modules/content_module.dart:352`
  - `lib/views/photo_import_view.dart:145`
  - `lib/core/router/app_router.dart:125`
  - `lib/core/di/modules/core_module.dart:147`
  - `lib/core/di/modules/ui_module.dart:161`
  - `lib/views/social/friend_profile_view.dart:61`
  - `lib/repositories/firebase/modules/message_mutation_module.dart:31`
  - `lib/views/social/friends_list_view.dart:139`
  - `lib/widgets/recipe/comment_item_widgets.dart:258`
  - `lib/services/import/text_import_strategy.dart:223`
  - `lib/core/di/modules/social_module.dart:229`
  - `lib/widgets/tagging/tag_editor_dialog.dart:122`
  - `lib/widgets/common/input/shopping_item_dialog.dart:158`
  - `lib/views/pantry/add_pantry_item_sheet.dart:147`
  - `lib/widgets/menu/menu_content_widgets.dart:475`
  - `lib/services/offline/offline_sync_manager.dart:69`
  - `lib/services/parsing/tiers/llm_tier.dart:90`
- Impact: Complex methods hide multiple responsibilities and make behavior regressions harder to localize.
- Required fix: Extract builders/steps/subroutines with explicit contracts and unit seams.
- Effort: 10-16 days (parallelizable).

### LOW
1) Accepted-large-files registry and current snapshot are close but not fully synchronized
- Evidence: accepted registry count: `docs/architecture/ACCEPTED_LARGE_FILES.md:11`; current snapshot bounds: `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:2`, `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:132`
- Impact: Refactoring governance can drift if this is not kept synchronized per release wave.
- Required fix: Keep accepted-file registry auto-refreshed from a script in CI.
- Effort: 0.5 day.

Recommendations:
- Target long UI `build()` methods first; they offer highest readability gain per LOC moved.
- Keep DI module `configure()` methods thin by extracting registration groups.

Quick wins:
- Extract `FeedTab._navigateToRecipe` repository logic and split large `build()` sections into private widgets.

## Dimension 3 - Code Deduplication & Infrastructure (9/15)
Summary:
Infrastructure patterns are strong in core mixins, but adoption is not uniform across service/repository classes. Baseline prompt metadata says BaseService and BaseFirebaseRepository adoption are high but not complete; current code still contains key holdouts with direct Firebase singleton dependencies.

### HIGH
1) BaseService adoption not uniform across service classes
- Evidence: baseline target/current: `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:234`; non-BaseService declarations: `lib/services/auth_service.dart:22`, `lib/services/user_service.dart:25`, `lib/services/realtime/realtime_menu_service.dart:26`, `lib/services/unified/unified_recipe_service.dart:68`, `lib/services/unified/unified_menu_service.dart:77`, `lib/services/unified/unified_shopping_service.dart:58`
- Impact: Inconsistent error/loading/lifecycle semantics across services increases maintenance and resilience variance.
- Required fix: Either migrate these classes to BaseService-compatible facades or explicitly document/standardize justified exceptions.
- Effort: 3-5 days.

2) Remaining repository holdouts still use direct Firebase instance patterns
- Evidence: prompt holdout list: `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:251`, `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:252`, `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:253`, `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:254`, `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:255`; implementations: `lib/repositories/parsing_correction_repository.dart:27`, `lib/repositories/parsing_correction_repository.dart:31`, `lib/repositories/collaborative_recipe_repository.dart:68`, `lib/repositories/collaborative_recipe_repository.dart:77`, `lib/repositories/site_config_repository.dart:12`, `lib/repositories/site_config_repository.dart:28`, `lib/repositories/firebase/firebase_category_preferences_repository.dart:10`, `lib/repositories/firebase/firebase_category_preferences_repository.dart:19`, `lib/repositories/firebase/firebase_menu_lexicon_repository.dart:18`, `lib/repositories/firebase/firebase_menu_lexicon_repository.dart:28`, `lib/repositories/firebase/firebase_ingredient_repository.dart:19`, `lib/repositories/firebase/firebase_ingredient_repository.dart:22`
- Impact: Auditing/logging/perms are less centralized than intended for CRUD-heavy paths.
- Required fix: Continue BUT-442 migration path or codify explicit exception criteria.
- Effort: 4-7 days.

### MEDIUM
1) SerializationUtils adoption is partial in some fromFirestore factories
- Evidence: direct map indexing in fromFirestore paths: `lib/models/parsing/site_config.dart:183`, `lib/models/parsing/site_config.dart:184`, `lib/models/parsing/site_config.dart:197`, `lib/models/parsing/site_config.dart:201`; additional raw indexing: `lib/models/shared_shopping_list.dart:119`, `lib/models/shared_shopping_list.dart:121`, `lib/models/shared_shopping_list.dart:122`, `lib/models/shared_shopping_list.dart:125`
- Impact: Type-safety and malformed-document resilience are weaker in these parsing paths.
- Required fix: Standardize on `SerializationUtils.safe*` wrappers for all external data fields.
- Effort: 1-2 days.

### LOW
1) Positive resilience infrastructure exists and is reusable
- Evidence: network retry defaults: `lib/core/mixins/error_handling_mixin.dart:291`, `lib/core/mixins/error_handling_mixin.dart:296`, `lib/core/mixins/error_handling_mixin.dart:302`, `lib/core/mixins/error_handling_mixin.dart:312`; DNS-aware execution API: `lib/core/mixins/firebase_service_mixin.dart:235`, `lib/core/mixins/firebase_service_mixin.dart:257`, `lib/core/mixins/firebase_service_mixin.dart:267`, `lib/core/mixins/firebase_service_mixin.dart:271`
- Impact: Good foundation; adoption consistency is the remaining gap.
- Required fix: expand usage audits rather than redesign the infrastructure.
- Effort: 1 day.

Recommendations:
- Finalize BUT-442 repository holdout migration.
- Add static checks for raw `data['"'x']"'` in `fromFirestore` factories.

Quick wins:
- Normalize `SiteConfig.fromFirestore` and `SharedShoppingList.fromFirestore` field parsing first.

## Dimension 4 - Error Handling & Resilience (10/15)
Summary:
Core resilience primitives are in place, but there is still a build-breaking analyzer error in pre-analysis artifacts and a few silent/unawaited error paths that can hide operational failures. Localized fixes are straightforward.

### CRITICAL
1) Build-breaking analyzer error captured in pre-analysis
- Evidence: `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:5`
- Impact: Static analysis gate is red; release readiness is blocked until this is reconciled.
- Required fix: reconcile `ConsentPurpose` symbol resolution path and re-run `flutter analyze` in CI lane.
- Effort: 0.5 day.

### HIGH
1) Unawaited async notification send in cook-snap flow
- Evidence: unawaited call: `lib/services/cook_snap_service.dart:222`; surrounding try/catch only wraps sync boundary: `lib/services/cook_snap_service.dart:220`, `lib/services/cook_snap_service.dart:230`; callee returns `Future<void>`: `lib/services/notifications/notification_service.dart:204`
- Impact: Notification failures can escape local error handling and become silent/untracked async failures.
- Required fix: await or explicitly `unawaited(...)` + dedicated error handler path.
- Effort: 0.5 day.

### MEDIUM
1) Silent catches hide persistence/UX state failures
- Evidence: `lib/viewmodels/recipe_list_viewmodel.dart:841`, `lib/viewmodels/recipe_list_viewmodel.dart:844`, `lib/viewmodels/recipe_list_viewmodel.dart:848`, `lib/viewmodels/recipe_list_viewmodel.dart:856`
- Impact: Banner state persistence or load failures are invisible to telemetry and support diagnosis.
- Required fix: log at least warning-level context and emit non-blocking diagnostics.
- Effort: 0.5 day.

2) Multiple empty catch blocks remain
- Evidence examples: `lib/services/parsing/tiers/llm_tier.dart:338`, `lib/services/parsing/tiers/llm_tier.dart:340`, `lib/services/unified/operations/modules/recipe_sharing_manager.dart:178`, `lib/services/unified/operations/modules/recipe_sharing_manager.dart:185`, `lib/services/cook_snap_service.dart:115`, `lib/services/cook_snap_service.dart:125`
- Impact: Reduced observability when non-critical operations degrade.
- Required fix: replace empty catches with lightweight telemetry/logging for non-critical paths.
- Effort: 1 day.

3) Testing infrastructure hang observed (deferred owner: Prompt 03)
- Evidence: `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31511`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31512`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31517`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31518`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31525`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31526`; ownership rule: `docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:195`
- Impact: Suite completion and coverage reliability are affected.
- Required fix: Defer full test-infra remediation to Prompt 03 per dedup rules.
- Effort: Deferred.

Recommendations:
- Treat analyzer red state and unawaited notification send as immediate fixes.
- Add telemetry in currently silent non-critical catch paths.

Quick wins:
- `cook_snap_service.dart` await/fail-soft update; add warning logs in `recipe_list_viewmodel.dart` catches.

Input Validation Coverage Matrix (sampled)
- Password change flow: has required/length/match checks. Evidence: `lib/viewmodels/account_security_viewmodel.dart:21`, `lib/viewmodels/account_security_viewmodel.dart:33`, `lib/viewmodels/account_security_viewmodel.dart:37`.
- Ingredient query search inputs: debounced and trimmed before repository call. Evidence: `lib/viewmodels/ingredient_search_viewmodel.dart:61`, `lib/viewmodels/ingredient_search_viewmodel.dart:71`, `lib/viewmodels/ingredient_search_viewmodel.dart:73`.
- URL/menu parser resilience: parsing and fallback paths exist but some non-critical catches are silent. Evidence: `lib/services/parsing/tiers/llm_tier.dart:338`, `lib/services/parsing/tiers/llm_tier.dart:340`.

## Dimension 5 - Documentation Health (7/10)
Summary:
Inline comment quality is mixed: there are still section-divider comments and non-English comments in production code, plus commented-out historical code blocks. TODO debt is concentrated in certificate pinning placeholders.

### MEDIUM
1) Section-divider comments violate project comment style
- Evidence examples: `lib/views/social/friends_list/feed_tab.dart:359`, `lib/models/parsing/parsing_correction.dart:31`, `lib/models/parsing/parsing_correction.dart:45`, `lib/models/parsing/parsing_correction.dart:62`
- Impact: Adds visual noise and weakens “why-over-what” comment quality.
- Required fix: replace dividers with smaller focused types/functions.
- Effort: 0.5 day.

2) Non-English comments remain in runtime files
- Evidence examples: `lib/core/form/form_fields_manager.dart:99`, `lib/core/form/form_fields_manager.dart:100`, `lib/services/user_service.dart:357`, `lib/services/user_service.dart:362`, `lib/viewmodels/recipe_form/recipe_image_manager.dart:293`, `lib/views/importera_fran_arkiv_view.dart:165`
- Impact: Inconsistent team readability against English-comment standard.
- Required fix: translate comments to English while preserving UI/user-facing Swedish text.
- Effort: 0.5-1 day.

### LOW
1) Commented-out code retained in source
- Evidence examples: `lib/services/deep_link_service.dart:344`, `lib/services/deep_link_service.dart:353`, `lib/services/deep_link_service.dart:354`, `lib/services/deep_link_service.dart:355`, `lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart:233`, `lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart:249`
- Impact: Increases cognitive load and obscures current behavior.
- Required fix: remove commented-out code, keep history in VCS/issues.
- Effort: 0.5 day.

2) TODO inventory concentrated in security pin placeholders
- Evidence: `lib/services/security/cert_pin_config.dart:39`, `lib/services/security/cert_pin_config.dart:40`, `lib/services/security/cert_pin_config.dart:43`, `lib/services/security/cert_pin_config.dart:48`, `lib/services/security/cert_pin_config.dart:53`, `lib/services/security/cert_pin_config.dart:60`, `lib/services/security/cert_pin_config.dart:63`, `lib/services/security/cert_pin_config.dart:66`, `lib/services/security/cert_pin_config.dart:69`, plus related placeholders `lib/services/security/pinned_http_client.dart:90`, `lib/services/ocr_extraction_service.dart:218`
- Impact: Security hardening is wired but not fully operational for pin enforcement.
- Required fix: complete BUT-427 ops fingerprint rollout.
- Effort: 1-2 days (plus ops coordination).

Markdown file health / architecture doc drift:
- Deferred to Prompt 12 per ownership rules. Evidence: `docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:230`, `docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:232`, `docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:237`, `docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:239`.

## Dimension 6 - Code Readability (6/10)
Summary:
Readability is impacted more by long methods and mixed naming/comment conventions than by obvious lint noise. Hardcoded collection strings still appear in several places despite a centralized constants file.

### MEDIUM
1) Hardcoded Firestore collection names in runtime logic
- Evidence: `lib/services/unified/unified_menu_service.dart:210`, `lib/services/moderation/report_service.dart:91`, `lib/repositories/firebase/firebase_menu_voting_repository.dart:25`, `lib/repositories/firebase/firebase_menu_voting_repository.dart:42`; central constants exist: `lib/core/constants/firestore_collections.dart:5`, `lib/core/constants/firestore_collections.dart:8`, `lib/core/constants/firestore_collections.dart:53`
- Impact: String drift risk and weaker rename safety.
- Required fix: move repeated literals to `FirestoreCollections` (including missing constants where needed).
- Effort: 0.5-1 day.

2) Mixed-language naming in identifiers and comments
- Evidence: `lib/views/importera_fran_arkiv_view.dart:1`, `lib/views/importera_fran_arkiv_view.dart:19`, `lib/services/user_service.dart:357`, `lib/core/form/form_fields_manager.dart:99`
- Impact: Inconsistent readability standards across teams.
- Required fix: standardize internal naming/comments to English while preserving localized UI content.
- Effort: 1-2 days.

### LOW
1) Style debt: section separators instead of decomposition
- Evidence: `lib/views/social/friends_list/feed_tab.dart:359`, `lib/services/analytics/analytics_events.dart:19`
- Impact: Visual grouping substitutes for structural extraction.
- Required fix: extract thematic blocks into focused types/helpers.
- Effort: 1 day (opportunistic).

Lint compliance report:
- Analyzer: 1 error captured in pre-analysis. Evidence: `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:5`.
- DCM complexity/dead-code outputs: not present in this run artifact set.

## Dimension 7 - Production Readiness (8/10)
Summary:
Core runtime setup is mature, but there are operational risks in dependency hygiene visibility and log data hygiene. Configuration values are explicit and centralized, but some external-facing keys and IDs are still directly embedded.

### HIGH
1) Dependency risk visibility is degraded by advisory decode failures
- Evidence: `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:1`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:23`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:45`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:67`
- Impact: Security/vulnerability status is partially blind during routine outdated checks.
- Required fix: stabilize advisory feed handling in toolchain and add explicit OSV scan artifact in pre-analysis bundle.
- Effort: 0.5-1 day.

2) EOL/discontinued packages present in dependency graph
- Evidence: `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:122`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:198`, `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:199`
- Impact: Future maintenance and security patchability risk.
- Required fix: schedule package migration wave (especially EOL/discontinued entries).
- Effort: 2-4 days.

### MEDIUM
1) Raw user identifiers appear in logs in several paths
- Evidence: `lib/repositories/firebase/firebase_block_repository.dart:59`, `lib/repositories/firebase/firebase_block_repository.dart:61`, `lib/repositories/firebase/firebase_notifications_repository.dart:107`, `lib/repositories/firebase/firebase_notifications_repository.dart:400`, `lib/services/notifications/notification_service.dart:531`
- Impact: PII leakage risk in logs/telemetry systems.
- Required fix: apply masked logging consistently (`maskedUserId`) for user IDs.
- Effort: 0.5-1 day.

### LOW
1) Public app config keys are embedded (expected for FirebaseOptions, but must remain restricted)
- Evidence: `lib/firebase_options.dart:35`, `lib/firebase_options.dart:45`, `lib/firebase_options.dart:53`, `lib/firebase_options.dart:71`; reCAPTCHA key usage: `lib/main.dart:214`, `lib/main.dart:215`
- Impact: Low direct secret risk (public client keys), but restriction hygiene remains critical.
- Required fix: confirm backend/API key restrictions and document rotation procedure.
- Effort: 0.5 day.

Release-readiness notes:
- Toolchain/runtime snapshot: `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-version.txt:1`, `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-version.txt:4`.
- CI workflow inventory present with 6 workflows: `docs/analysis/runs/2026-05-codex/_pre-analysis/ci-workflows.txt:1`, `docs/analysis/runs/2026-05-codex/_pre-analysis/ci-workflows.txt:6`.

## Dimension 8 - Deprecated API & Technical Debt (4/5)
Summary:
No active `.withOpacity()` runtime usage was found in `lib/` code paths sampled, suggesting migration to newer color APIs is effectively complete. Technical debt now concentrates in operational TODOs (certificate pin rollout), lingering commented code, and dependency lifecycle drift.

### MEDIUM
1) Security-related TODO debt remains open
- Evidence: `lib/services/security/cert_pin_config.dart:39`, `lib/services/security/cert_pin_config.dart:40`, `lib/services/security/cert_pin_config.dart:43`, `lib/services/security/cert_pin_config.dart:48`, `lib/services/security/cert_pin_config.dart:53`, `lib/services/security/cert_pin_config.dart:60`, `lib/services/security/cert_pin_config.dart:63`, `lib/services/security/cert_pin_config.dart:66`, `lib/services/security/cert_pin_config.dart:69`
- Impact: Partial hardening state persists longer than intended.
- Required fix: close BUT-427 ops rotation and replace placeholders with real pins.
- Effort: 1-2 days.

### LOW
1) Deprecated color API guidance is modernized in docs
- Evidence: `lib/theme/app_colors.dart:9`, `lib/widgets/CLAUDE.md:13`, `lib/views/CLAUDE.md:41`
- Impact: Good baseline; continue enforcing in reviews.
- Required fix: none beyond standard lint/review checks.
- Effort: 0 days.

2) Commented-out code remains minor debt
- Evidence: `lib/services/deep_link_service.dart:344`, `lib/services/deep_link_service.dart:353`, `lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart:233`
- Impact: Maintainability noise.
- Required fix: remove dead commented snippets.
- Effort: 0.5 day.

## Current vs Gold Standard Metrics
| Metric | Current | Gold Standard | Evidence |
|---|---:|---:|---|
| Hand-written Dart file count | 1,252 | <=1,000 (with strict modularity) | `docs/analysis/runs/2026-05-codex/_pre-analysis/dart-file-count.txt:1` |
| Hand-written LOC | 327,280 | <=200,000 (modular target) | `docs/analysis/runs/2026-05-codex/_pre-analysis/dart-line-count.txt:1` |
| Files >500 lines | 131 | <=50 (excluding accepted exceptions) | `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:2`, `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:132` |
| Files >1000 lines | 6 | 0-2 | `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:2`, `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:7` |
| Direct Firebase singleton usage outside pure repo layer | >=6 files | 0 (except tightly scoped bootstrapping) | `lib/views/onboarding/onboarding_age_gate_blocked_view.dart:22`, `lib/core/di/di_container.dart:237`, `lib/services/notifications/fcm_service.dart:80`, `lib/services/notifications/modules/fcm_token_manager.dart:84`, `lib/core/di/modules/content_module.dart:434`, `lib/main.dart:172` |
| `setState()` in ViewModels | Baseline prompt still says 2 known (migration status unclear) | 0 | `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:126`, `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:127`, `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:128` |
| BaseService adoption | Prompt baseline 96% (~67/~70) | 100% or documented exceptions | `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:234`; exceptions examples: `lib/services/auth_service.dart:22`, `lib/services/user_service.dart:25` |
| BaseFirebaseRepository adoption | Prompt baseline 78% (35/45) | >=90% of eligible repos | `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:241`, `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:248`, `docs/analysis/prompts/01_CODE_QUALITY_AND_ARCHITECTURE.md:251` |
| SerializationUtils adoption in `fromFirestore` | Partial | 100% defensive parsing | `lib/models/parsing/site_config.dart:183`, `lib/models/parsing/site_config.dart:197`, `lib/models/shared_shopping_list.dart:119`, `lib/models/shared_shopping_list.dart:121` |
| TODO/FIXME/HACK markers | 14 markers (13 TODO + 1 XXX sample marker) | <=5 active, ticket-linked | `lib/services/security/cert_pin_config.dart:39`, `lib/services/security/cert_pin_config.dart:69`, `lib/services/parsing/recipe_parser_service.dart:799`, `lib/services/analytics/trackers/parse_events_tracker.dart:28` |
| Deprecated `.withOpacity()` runtime usage | 0 observed in runtime files sampled | 0 | modernization guidance: `lib/theme/app_colors.dart:9` |
| Cyclomatic complexity average | Not available (DCM output missing in artifacts) | <10 average | DCM artifact not present in `_pre-analysis` bundle |
| Class count | Not captured in pre-analysis artifacts | N/A | Not present in `_pre-analysis` artifacts |

## Top 10 Issues Quick Reference
1. [CRITICAL] Analyzer build break (`ConsentPurpose` unresolved in pre-analysis run) | `docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3` | 0.5d | Build/Release
2. [HIGH] View-layer repository access (shared-content actions) | `lib/views/social/shared_with_me/shared_content_actions.dart:433` | 1-2d | Architecture
3. [HIGH] ViewModel repository bypass (public profile VM) | `lib/viewmodels/public_profile_viewmodel.dart:27` | 1d | Architecture
4. [HIGH] ViewModel-adjacent Firestore persistence module | `lib/viewmodels/menu/menu_storage.dart:64` | 1-2d | Architecture
5. [HIGH] Data source discipline risk (`PermissionService.currentUser` used for denormalized profile fields) | `lib/services/unified/operations/modules/recipe_sharing_manager.dart:533` | 1-2d | Data Integrity
6. [HIGH] Unawaited async notification send in cook-snap flow | `lib/services/cook_snap_service.dart:222` | 0.5d | Resilience
7. [HIGH] File-size sprawl (131 files >500 lines, 6 >1000) | `docs/analysis/runs/2026-05-codex/_pre-analysis/files-over-500-lines.txt:2` | 8-12d | Maintainability
8. [HIGH] Dependency lifecycle risk (EOL/discontinued packages) | `docs/analysis/runs/2026-05-codex/_pre-analysis/pub-outdated.txt:122` | 2-4d | Production
9. [MEDIUM] Raw user IDs in logs | `lib/repositories/firebase/firebase_block_repository.dart:59` | 0.5-1d | Privacy/Operations
10. [MEDIUM] TLS pinning still placeholder-driven | `lib/services/security/cert_pin_config.dart:39` | 1-2d + ops | Security Debt

## Phase 2 Preparation
Issue counts by severity:
- Critical: 1
- High: 8
- Medium: 13
- Low: 11

Estimated total remediation effort:
- 31-48 engineer-days (excluding deferred Prompt 03/12/05 owned scopes)

Phase 2 planning notes:
1. Fix build blockers and correctness-critical async handling first (analyzer error, unawaited notification send).
2. Batch architecture fixes by boundary type: (a) views -> repositories, (b) viewmodels -> repositories, (c) service instantiation in UI layer.
3. Run a focused large-method extraction wave on top 20 hotspots, prioritizing UI build and DI configure methods.
4. Coordinate ops-led security debt closure for certificate pin fingerprints and dependency upgrade wave.
5. Keep dedup boundaries explicit:
- Test coverage/infrastructure deep-dive deferred to Prompt 03 (`docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:195`).
- Markdown/doc drift deep-dive deferred to Prompt 12 (`docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:230`, `docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:232`, `docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:237`).
- CVE/license authoritative review deferred to Prompt 05 (`docs/analysis/prompts/MASTER_ANALYSIS_ORCHESTRATOR.md:194`).
