
### Executive Summary

BUTLERY PRODUCT ANALYTICS & GROWTH ANALYSIS - PHASE 1 FINDINGS
================================================================
Analysis Date: 2026-05-04
Analyst: Claude (Opus 4.7)
Scope: Analytics, funnels, retention, notifications, experimentation, onboarding

OVERALL SCORE: 66/100
+-- Analytics Instrumentation:        11/20 points
+-- Funnel Coverage:                  9/18 points
+-- Retention & Cohort Tracking:      12/15 points
+-- Notification Strategy:            11/15 points
+-- Feature Flags & Experimentation:  8/12 points
+-- Onboarding Optimization:          8/10 points
+-- ASO Technical Readiness:          3/5 points
+-- Re-Engagement Infrastructure:     4/5 points

STATUS: Needs Work

CRITICAL GAPS: 2 found
HIGH PRIORITY: 6 found
MEDIUM PRIORITY: 7 found
LOW PRIORITY: 4 found

TOP 5 GROWTH RISKS:
1. Core import funnel is not fully measurable in primary app flows (missing consistent started/success/failure sessioned events).
2. Import events are not correlatable end-to-end (`session_id` TODO), blocking reliable drop-off attribution.
3. Several core engagement actions are missing events (`favorite`, `content_shared_to_group`, menu recipe add/load/delete actions).
4. Onboarding page-step analytics misses first-page view, weakening first-step drop-off analysis.
5. Web analytics path is a no-op, creating a full measurement blind spot for web users.

### Dimension 1: Analytics Instrumentation Completeness (11/20)

Summary: The codebase has a strong event taxonomy and central registry (`lib/services/analytics/analytics_events.dart:18`) with tracker modules (`lib/services/analytics/trackers/trackers.dart:1`). Parameter hygiene is generally strong (PII hashing/drop at repository layer: `lib/repositories/firebase/firebase_analytics_repository.dart:19`, `:32`, `:51`, `:449`). The main weakness is coverage of core import and several product actions.

CRITICAL
- Core import actions are not consistently instrumented in the primary import flow.
Evidence: Primary flow runs in `SmartImportViewModel.startImport` and `ImportManager.autoImport` (`lib/viewmodels/smart_import_viewmodel.dart:266`, `lib/services/import/import_manager.dart:191`) but explicit import telemetry appears in `ReceiveShareView` (`lib/views/receive_share_view.dart:98`, `:165`) and onboarding-only events (`lib/views/onboarding/onboarding_import_page.dart:211`, `:217`).
Impact: Core activation funnel cannot reliably answer “started -> success/fail” across normal app imports.
Required fix: Emit `import_started/import_success/import_failed/import_cancelled` from the shared import orchestration path, not only share/onboarding surfaces.
Effort: 2-3 days.

HIGH
- Favorite action is untracked.
Evidence: Favorite toggle path exists (`lib/viewmodels/recipe_detail_viewmodel.dart:320`) but no corresponding recipe-favorite event exists in taxonomy (`lib/services/analytics/analytics_events.dart:54`).
Impact: Cannot quantify favorite behavior as a retention driver.
Required fix: Add `recipe_favorited` (with `is_favorite`) and emit in both detail/list favorite toggles.
Effort: 0.5 day.

- `content_shared_to_group` exists but is not used in active share paths.
Evidence: Event exists (`lib/services/analytics/analytics_events.dart:96`) and tracker method exists (`lib/services/analytics/trackers/social_events_tracker.dart:137`), while group/friend share flows emit `recipe_shared` (`lib/viewmodels/group_recipe_selection_viewmodel.dart:191`, `lib/viewmodels/recipe_selection_viewmodel.dart:278`, `lib/services/share_service.dart:415`).
Impact: Group-sharing behavior cannot be segmented cleanly from generic sharing.
Required fix: Emit `content_shared_to_group` on group share path, keep `recipe_shared` as umbrella if needed.
Effort: 0.5-1 day.

- Menu editing lifecycle is under-instrumented.
Evidence: Menu event taxonomy has generate/save/share/load/delete (`lib/services/analytics/analytics_events.dart:66`) but realtime add/remove/reorder operations have no analytics (`lib/viewmodels/realtime_menu_viewmodel.dart:139`, `lib/viewmodels/realtime_menu/realtime_menu_operations.dart:25`).
Impact: Cannot analyze menu-building engagement depth.
Required fix: Add `menu_recipe_added/removed/reordered` events in realtime menu ops.
Effort: 1-2 days.

MEDIUM
- `menu_loaded` and `menu_deleted` paths are defined but not emitted from active viewmodel flows.
Evidence: Methods exist in analytics service (`lib/services/analytics_service.dart:439`, `:453`), but menu load/delete paths in `MenuViewModel` have no analytics call (`lib/viewmodels/menu_viewmodel.dart:363`, `:404`).
Impact: Incomplete saved-menu lifecycle analytics.
Required fix: Emit load/delete on successful operations.
Effort: 0.5 day.

LOW
- Web platform analytics are disabled by design.
Evidence: DI registers `NoOpAnalyticsRepository` on web (`lib/core/di/modules/core_module.dart:211`), and repository methods are no-op (`lib/repositories/noop/noop_analytics_repository.dart:13`).
Impact: Full analytics blind spot for web cohorts.
Required fix: Add web analytics provider or explicit telemetry fallback.
Effort: 2-4 days.

Recommendations
- Move import instrumentation into shared orchestration (`SmartImportViewModel` + `ImportManager`).
- Expand lifecycle tracking to favorites/menu edit lifecycle.
- Keep PII policy as-is; it is strong and centrally enforced (`lib/repositories/firebase/firebase_analytics_repository.dart:449`).

Quick wins
- Add `recipe_favorited` and emit in `toggleFavorite`.
- Emit `menu_loaded/menu_deleted` at existing success points.

### Dimension 2: Funnel Coverage (9/18)

Summary: Onboarding is heavily instrumented and has resume/abandon handling (`lib/viewmodels/onboarding_viewmodel.dart:105`, `lib/services/onboarding/onboarding_progress_service.dart:170`, `lib/main.dart:1219`). Import funnel coverage is fragmented across share/onboarding paths with missing universal instrumentation and missing session correlation.

CRITICAL
- End-to-end import funnel is not reliably measurable.
Evidence: Main import path lacks universal import start/success/fail events (`lib/viewmodels/smart_import_viewmodel.dart:266`, `lib/services/import/import_manager.dart:191`), while per-tier parse events are emitted separately (`lib/services/parsing/recipe_parser_service.dart:787`) and share flow logs its own import events (`lib/views/receive_share_view.dart:98`, `:165`).
Impact: Cannot trust funnel drop-off and conversion rate by import entry point.
Required fix: Centralize import funnel events around shared import state machine.
Effort: 2-3 days.

HIGH
- Import event correlation gap (`session_id`) prevents joining stages.
Evidence: Explicit TODO in parse tracker (`lib/services/analytics/trackers/parse_events_tracker.dart:28`) and parser emitter (`lib/services/parsing/recipe_parser_service.dart:799`).
Impact: Cannot join `import_started` to `import_tier_*` to `import_success` for root-cause funnel analysis.
Required fix: Thread one import session ID through start/tier/success/failure/post-edit.
Effort: 1-2 days.

MEDIUM
- Onboarding first-page step is not explicitly logged as viewed on initial render.
Evidence: Page view event fires in `setPage` (`lib/viewmodels/onboarding_viewmodel.dart:117`), which is triggered by `PageView.onPageChanged` (`lib/views/onboarding/onboarding_view.dart:98`), but initial page render does not trigger `onPageChanged`.
Impact: First-step drop-off precision is reduced.
Required fix: Emit initial page view once on onboarding mount.
Effort: 0.5 day.

Funnel diagrams (instrumented vs uninstrumented)
- Onboarding funnel:
  App opens -> onboarding gate/resume (`lib/main.dart:1174`, `:1221`) -> `onboarding_started` (`lib/viewmodels/onboarding_viewmodel.dart:108`) -> `onboarding_page_viewed` on transitions (`lib/viewmodels/onboarding_viewmodel.dart:118`) -> `onboarding_completed/onboarding_skipped` (`lib/viewmodels/onboarding_viewmodel.dart:223`, `:218`) -> first recipe activation metrics (`lib/viewmodels/recipe_form/recipe_persistence_manager.dart:410`).
- Import funnel:
  Smart import entry (`lib/viewmodels/smart_import_viewmodel.dart:266`) -> parsing tiers (`lib/services/parsing/recipe_parser_service.dart:787`) -> import result (`lib/viewmodels/smart_import_viewmodel.dart:314`) -> recipe save + `recipe_created(source=import)` (`lib/viewmodels/recipe_form/recipe_persistence_manager.dart:372`) -> post-import edit (`lib/viewmodels/recipe_form/recipe_persistence_manager.dart:472`).
  Missing: universal import started/success/failure/cancel events in the main path.
- Social activation funnel:
  first friend (`lib/viewmodels/friends_viewmodel.dart:237`) -> first share (`lib/services/share_service.dart:421`) -> first comment (`lib/services/unified/operations/modules/comment_crud_operations.dart:70`) -> first group (`lib/viewmodels/create_group_viewmodel.dart:378`, `lib/viewmodels/group_invitations_viewmodel.dart:428`).

Recommendations
- Treat import as one canonical funnel state machine.
- Add explicit initial onboarding-page view event.

Quick wins
- Add `session_id` plumbing.
- Add mount-time page-view for onboarding page 0.
### Dimension 3: Retention & Cohort Tracking Infrastructure (12/15)

Summary: Server-side retention/cohort infrastructure is mature: day-N retention (`functions/src/analytics/track-retention.ts:33`), feature retention (`functions/src/analytics/compute-feature-retention.ts:2`), and weekly North Star metrics (`functions/src/scheduled/north-star-weekly.ts:2`). Cohort properties are supported via acquisition and first-recipe-source milestones (`lib/services/analytics/acquisition_milestone.dart:37`, `lib/services/analytics/first_recipe_source_milestone.dart:15`).

HIGH
- Lifecycle stage updates are session-start centric; cook-path reclassification is not wired in the audited cook flow.
Evidence: lifecycle bootstrap runs on session start (`lib/main.dart:824`, `lib/services/analytics/user_property_bootstrap.dart:32`), while cook path logs `recipe_cooked` only (`lib/viewmodels/recipe_detail_viewmodel.dart:306`).
Impact: Lifecycle segmentation may lag within active sessions.
Required fix: Trigger `emitLifecycle` after successful cook completion.
Effort: 0.5-1 day.

Strengths
- Retention day buckets: D1/D7/D14/D30/D90/D180 (`functions/src/analytics/track-retention.ts:33`, `:140`).
- Feature-level retention flags (`functions/src/analytics/compute-feature-retention.ts:69`, `:169`).
- North Star snapshots with WAU/cooks/retention W1-W3 (`functions/src/scheduled/north-star-weekly.ts:8`, `:155`).
- Acquisition cohorting via UTM + first-write-wins persistence (`lib/core/bootstrap/handlers/deep_link_handler.dart:154`, `lib/services/analytics/acquisition_milestone.dart:83`).

Recommendations
- Add lifecycle reclassification hook post-cook.
- Keep server metrics schedule as-is; coverage is good.

Quick wins
- Post-cook lifecycle emit.

### Dimension 4: Notification Strategy & Segmentation (11/15)

Summary: Notification taxonomy and delivery strategy are well-structured (immediate/batchable/silent/digest/optional) with category and priority metadata (`lib/services/notifications/notification_types.dart:43`, `:65`, `:72`). Preferences, quiet hours, and delivery/open/dismiss/action telemetry are implemented (`lib/services/notifications/modules/notification_preference_manager.dart:36`, `lib/services/notifications/modules/notification_analytics_manager.dart:34`). Deep-link routing has allowlisted routes and analytics for opened/missing/unknown paths (`lib/services/notifications/notification_deep_link_router.dart:35`, `:174`, `:199`).

HIGH
- Pre-analysis analyzer defect in notification consent path.
Evidence: `Undefined name 'ConsentPurpose'` in pre-analysis output (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`).
Impact: Release-quality and confidence risk in notification stack.
Required fix: Resolve analyzer break and re-run static analysis.
Effort: 0.5 day.

MEDIUM
- Preference-change analytics exclude digest frequency and quiet-hours changes.
Evidence: scope explicitly limited to category toggles (`lib/views/settings/notification_preferences_view.dart:90`), while digest/quiet-hours updates persist without event logging (`lib/views/settings/notification_preferences_view.dart:271`, `:328`).
Impact: Cannot attribute retention shifts to digest cadence or quiet-hours changes.
Required fix: Add dedicated events for digest frequency + quiet-hours edits.
Effort: 0.5-1 day.

- Notification effectiveness is measured, but action-conversion linkage is weak outside win-back.
Evidence: send/open streams and CTR suppression exist (`functions/src/shared/notification-send-events.ts:4`, `functions/src/notifications/record-notification-opened.ts:20`, `functions/src/analytics/suppress-low-performers.ts:4`), and win-back conversion is explicit (`lib/services/analytics/winback_attribution_service.dart:220`).
Impact: Strong CTR visibility, weaker “notification -> product action” clarity for non-winback types.
Required fix: Add type-specific downstream conversion markers.
Effort: 1-2 days.

Notification type inventory and capability matrix

| Type example | Implemented | User-configurable | Deep link path | Send/Open tracked | Conversion tracked |
|---|---|---|---|---|---|
| `friendRequest` (`immediate`,`critical`) | Yes (`lib/services/notifications/notification_types.dart:114`) | Yes via category prefs (`lib/services/notifications/modules/notification_preference_manager.dart:47`) | Yes (`/friend_request`) (`lib/services/notifications/notification_deep_link_router.dart:40`, `:245`) | Yes (`lib/services/notifications/modules/notification_analytics_manager.dart:34`, `:111`) | Partial (no dedicated downstream event) |
| `recipeShared` (`immediate`,`high`) | Yes (`lib/services/notifications/notification_types.dart:127`) | Yes (`notification_preference_manager.dart:47`) | Yes (`/recipe`) (`notification_deep_link_router.dart:37`, `:217`) | Yes | Partial |
| `recipeComment` (`batchable`) | Yes (`lib/services/notifications/notification_types.dart:155`) | Yes | Yes (`/comment_thread`) (`notification_deep_link_router.dart:43`, `:230`) | Yes | Partial |
| `activityDigest` (`digest`) | Yes (`lib/services/notifications/notification_types.dart:191`, `functions/src/analytics/send-activity-digest.ts:26`) | Yes (`digestFrequency`) (`lib/views/settings/notification_preferences_view.dart:271`) | Uses `/winback` target (`functions/src/analytics/send-activity-digest.ts:161`) | Yes | Partial |
| `win_back_*` | Yes (`functions/src/analytics/detect-lapsed-users.ts:49`) | Indirect via master/system/quiet-hours (`functions/src/shared/preference-aware-push.ts:163`, `:179`) | Yes (`/winback`) (`functions/src/analytics/detect-lapsed-users.ts:226`) | Yes | Yes (`lib/services/analytics/winback_attribution_service.dart:220`) |

Recommendations
- Keep RC + quiet-hours gating model; it is strong (`functions/src/shared/notification-gate.ts:79`).
- Expand conversion metrics beyond win-back.

Quick wins
- Add digest/quiet-hours preference-change events.
- Resolve pre-analysis analyzer defect and rerun.

### Dimension 5: Feature Flag & Experimentation Infrastructure (8/12)

Summary: Remote Config feature flags are extensive and initialized early (`lib/services/feature_flags/feature_flag_service.dart:44`, `lib/core/bootstrap/stages/core_stage.dart:45`). Kill switches and live updates are implemented (`feature_flag_service.dart:69`, `:250`, `lib/widgets/maintenance_mode_gate.dart:68`). Experiment assignment infrastructure exists and is production-used for win-back (`lib/services/analytics/experiment_assignment.dart:58`, `lib/services/analytics/winback_attribution_service.dart:176`).

HIGH
- Gradual rollout helper exists but rollout usage is limited in audited feature entry points.
Evidence: rollout API is implemented (`lib/services/feature_flags/feature_flag_service.dart:177`), while common feature routing uses boolean `isEnabled` checks (`lib/services/search/recipe_search_router.dart:93`, `lib/core/di/modules/search_module.dart:145`).
Impact: 1%->10%->50% progressive rollout workflows are not broadly exercised.
Required fix: Adopt `isInRollout` for targeted rollouts on candidate features.
Effort: 1-2 days.

MEDIUM
- `feature_flag_evaluated` analytics fires only in rollout path.
Evidence: event emit is called from `isInRollout` (`lib/services/feature_flags/feature_flag_service.dart:191`, `:215`), not from `isEnabled` (`:117`).
Impact: Limited observability of most flag evaluations.
Required fix: Add lightweight sampled logging for key `isEnabled` checks.
Effort: 0.5-1 day.

- Experimentation is currently win-back-centric, not generalized.
Evidence: experiment assignment exists (`lib/services/analytics/experiment_assignment.dart:58`) and is bootstrapped specifically from win-back bridge fields (`lib/services/analytics/winback_attribution_service.dart:145`, `:176`).
Impact: A/B capability exists but adoption is narrow.
Required fix: Add experiment wrappers for onboarding/import UX tests.
Effort: 1-2 days.

Feature flag inventory

| Flag group | Examples | Source |
|---|---|---|
| Safety kill switches | `enable_social_features`, `enable_sharing`, `enable_messaging`, `app_maintenance_mode` | `lib/services/feature_flags/feature_flag_service.dart:65`, `:69` |
| Gradual rollout | `new_search_rollout_percentage` | `lib/services/feature_flags/feature_flag_service.dart:73` |
| Search/provider | `enable_algolia_search` and provider switch | `lib/services/feature_flags/feature_flag_service.dart:46`, `lib/core/di/modules/search_module.dart:145` |
| Operational | `audit_log_retention_days`, `enable_performance_monitoring` | `lib/services/feature_flags/feature_flag_service.dart:61` |
| Tagging thresholds | `tag_*` thresholds | `lib/services/feature_flags/feature_flag_service.dart:75` |

Recommendations
- Start with one staged rollout use-case (onboarding/import CTA variant).
- Add experiment naming conventions and dashboard templates.

Quick wins
- Add sampled `isEnabled` analytics for top 5 product flags.

### Dimension 6: Onboarding Flow Optimization (8/10)

Summary: Onboarding structure, personalization capture, and resume handling are strong. The flow persists step progress, supports resume, and logs resume/abandon nudges (`lib/services/onboarding/onboarding_progress_service.dart:133`, `lib/main.dart:1221`). Activation metrics (`time_to_first_recipe`, `user_activated`) are emitted on first recipe save (`lib/viewmodels/recipe_form/recipe_persistence_manager.dart:410`).

HIGH
- First onboarding page-view tracking is incomplete on initial render.
Evidence: page-view logging happens on page change (`lib/viewmodels/onboarding_viewmodel.dart:117`) from `PageView.onPageChanged` (`lib/views/onboarding/onboarding_view.dart:98`), not on first paint.
Impact: Page-0 drop-off undercount.
Required fix: Emit page-0 view on onboarding mount once.
Effort: 0.5 day.

MEDIUM
- Onboarding import outcome analytics are URL-inline centric.
Evidence: success event is logged in inline import handler (`lib/views/onboarding/onboarding_import_page.dart:217`), while photo option navigates out (`lib/views/onboarding/onboarding_import_page.dart:174`, `:180`) without onboarding-specific outcome logging in this component.
Impact: Partial visibility into onboarding import method performance.
Required fix: Propagate onboarding context into photo import success/failure events.
Effort: 1 day.

Strengths
- Personalization capture (age/allergens/dietary) and save (`lib/viewmodels/onboarding_viewmodel.dart:191`, `:201`).
- Starter recipes and seed event (`lib/viewmodels/onboarding_viewmodel.dart:256`, `:278`).
- Resume + 24h abandonment nudge analytics (`lib/main.dart:1224`, `:1228`).

Recommendations
- Close first-page and photo-import attribution gaps.

Quick wins
- Add first-page view event at mount.
- Thread onboarding source into photo import completion.

### Dimension 7: ASO Technical Readiness (3/5)

Summary: In-app review prompting is implemented with meaningful-trigger gates and analytics (`lib/services/in_app_review_service.dart:13`, `:69`, `:126`). Deep linking is configured on Android and iOS (`android/app/src/main/AndroidManifest.xml:71`, `ios/Runner/Runner.entitlements:5`) and campaign attribution from UTM is tracked (`lib/core/bootstrap/handlers/deep_link_handler.dart:154`, `:163`).

MEDIUM
- No explicit app-indexing integration surfaced in mobile dependencies/config.
Evidence: dependency set includes deep links and Firebase analytics/remote config but no dedicated app-indexing package (`pubspec.yaml:27`, `:87`).
Impact: Discoverability via app indexing likely limited.
Required fix: Evaluate platform-native indexing strategy and implement if required.
Effort: 1-2 days.

LOW
- Structured data support is inbound (import parsing), not outbound publishing.
Evidence: schema.org parsing is used for import extraction (`lib/services/import/url_import_strategy.dart:205`).
Impact: Good for import quality; does not itself improve store/search discoverability.
Required fix: If web landing pages exist, add outbound structured metadata there.
Effort: 1-2 days (web scope).

Recommendations
- Keep review prompt timing strategy; it is well gated.
- Extend discoverability strategy beyond deep links/UTM.

Quick wins
- Add ASO technical checklist to release pipeline (indexing + link verification checks).

### Dimension 8: Re-Engagement & Win-Back Infrastructure (4/5)

Summary: Win-back infra is robust: daily lapsed-user detection (7/14/30 days), Remote Config copy variants, quiet-hours/prefs gate, and conversion attribution back to product actions (`functions/src/analytics/detect-lapsed-users.ts:49`, `functions/src/analytics/winback-variant.ts:57`, `lib/services/analytics/winback_attribution_service.dart:220`). This is one of the strongest growth systems in the codebase.

MEDIUM
- Re-engagement channel coverage is push-only today.
Evidence: server writes `lastWinBackChannel: "push"` (`functions/src/analytics/detect-lapsed-users.ts:193`) and client docs explicitly note email is future work (`lib/services/analytics/winback_attribution_service.dart:9`).
Impact: No fallback channel for users who disable push.
Required fix: Add email win-back channel with preference/unsubscribe controls.
Effort: 3-5 days.

Strengths
- Lapsed detection and staged escalation (`functions/src/analytics/detect-lapsed-users.ts:49`).
- Win-back A/B copy via deterministic assignment + RC (`functions/src/analytics/winback-variant.ts:72`, `:189`).
- Conversion event on meaningful action (`lib/services/analytics/winback_attribution_service.dart:83`, `:220`).

Recommendations
- Add secondary channel (email) and shared attribution model.

Quick wins
- Add “push-disabled lapsed users” dashboard segment.
### Analytics Event Inventory (Growth Scope)

| Event | Key parameters | Trigger location(s) |
|---|---|---|
| `onboarding_started` | none | `lib/viewmodels/onboarding_viewmodel.dart:108` |
| `onboarding_page_viewed` | `page` | `lib/viewmodels/onboarding_viewmodel.dart:118` |
| `onboarding_resumed` | `last_step` | `lib/services/onboarding/onboarding_progress_service.dart:172` |
| `onboarding_abandoned` | `last_step` | `lib/services/onboarding/onboarding_progress_service.dart:183` |
| `onboarding_skipped` | `skipped_at_page` | `lib/viewmodels/onboarding_viewmodel.dart:218` |
| `onboarding_completed` | `allergen_count`,`dietary_count` | `lib/viewmodels/onboarding_viewmodel.dart:223` |
| `onboarding_recipes_seeded` | `count` | `lib/viewmodels/onboarding_viewmodel.dart:278` |
| `onboarding_import_attempted` | none | `lib/views/onboarding/onboarding_import_page.dart:211` |
| `onboarding_import_succeeded` | `recipe_title_length` | `lib/views/onboarding/onboarding_import_page.dart:217` |
| `onboarding_import_skipped` | `completed_via_skip` | `lib/viewmodels/onboarding_viewmodel.dart:237` |
| `time_to_first_recipe` | `minutes_since_signup` | `lib/viewmodels/recipe_form/recipe_persistence_manager.dart:411` |
| `user_activated` | none | `lib/viewmodels/recipe_form/recipe_persistence_manager.dart:418` |
| `recipe_created` | `source`,`has_image` | `lib/viewmodels/recipe_form/recipe_persistence_manager.dart:373` |
| `recipe_viewed` | `recipe_id`,`recipe_type`,`source` | `lib/viewmodels/recipe_detail_viewmodel.dart:112` |
| `recipe_edited` | `recipe_id`,`fields_changed` | `lib/viewmodels/recipe_form/recipe_persistence_manager.dart:431` |
| `post_import_edit` | `recipe_id`,`fields_changed`,`hours_since_import`,`tier_used?` | `lib/viewmodels/recipe_form/recipe_persistence_manager.dart:472`, `lib/services/analytics/post_import_edit_decider.dart:42` |
| `recipe_deleted` | `recipe_id`,`meal_type`,`recipe_type`,`days_since_created` | `lib/viewmodels/recipe_detail_viewmodel.dart:234` |
| `recipe_cooked` | `recipe_id`,`meal_type`,`is_first_time`,`days_since_last?` | `lib/viewmodels/recipe_detail_viewmodel.dart:306` |
| `recipe_shared` | `method`,`recipient_count_bucket`,`recipe_id` | `lib/services/share_service.dart:415`, `lib/viewmodels/recipe_selection_viewmodel.dart:278`, `lib/viewmodels/group_recipe_selection_viewmodel.dart:191` |
| `recipe_search_performed` | `search_query` (sanitized),`results_count`,`filters_applied?` | `lib/viewmodels/recipe/recipe_query_viewmodel.dart:129`, `lib/repositories/firebase/firebase_analytics_repository.dart:465` |
| `first_share` | `share_method`,`minutes_since_signup?` | `lib/services/share_service.dart:421` |
| `first_search` | `recipe_count_at_time`,`minutes_since_signup?` | `lib/viewmodels/recipe/recipe_query_viewmodel.dart:137` |
| `friend_request_sent` | `recipient_id`,`source?` | `lib/viewmodels/friends_viewmodel.dart:190` |
| `friend_request_accepted` | `sender_id` | `lib/viewmodels/friends_viewmodel.dart:233` |
| `first_friend` | `minutes_since_signup?` | `lib/viewmodels/friends_viewmodel.dart:237` |
| `comment_created` | `recipe_id`,`comment_length` | `lib/services/unified/operations/modules/comment_crud_operations.dart:63` |
| `first_comment` | `minutes_since_signup?` | `lib/services/unified/operations/modules/comment_crud_operations.dart:70` |
| `recipe_rated` | `recipe_id`,`rating`,`previous_rating?` | `lib/services/unified/operations/modules/recipe_rating_system.dart:76` |
| `group_created` | `group_id`,`group_type`,`member_count` | `lib/viewmodels/create_group_viewmodel.dart:369` |
| `group_joined` | `group_id`,`source` | `lib/viewmodels/group_invitations_viewmodel.dart:420` |
| `first_group` | `minutes_since_signup?` | `lib/viewmodels/create_group_viewmodel.dart:378`, `lib/viewmodels/group_invitations_viewmodel.dart:428` |
| `menu_generation_started` | `prompt_length?` | `lib/viewmodels/menu_viewmodel.dart:122` |
| `menu_generated` | `recipe_count`,`method` | `lib/viewmodels/menu_viewmodel.dart:136` |
| `menu_generation_failed` | `error_code`,`error_message?` | `lib/viewmodels/menu_viewmodel.dart:155` |
| `menu_saved` | `menu_id`,`recipe_count`,`is_shared` | `lib/viewmodels/menu_viewmodel.dart:293` |
| `menu_shared` | `menu_id`,`recipient_count`,`share_method?` | `lib/viewmodels/menu_viewmodel.dart:321` |
| `first_meal_plan` | `recipe_count_in_plan`,`minutes_since_signup?` | `lib/viewmodels/menu_viewmodel.dart:301` |
| `shopping_list_created` | `list_id`,`list_type`,`initial_item_count?` | `lib/viewmodels/unified_shopping_viewmodel.dart:143`, `:177` |
| `shopping_list_item_added` | `list_id`,`source?` | `lib/viewmodels/unified_shopping_viewmodel.dart:280` |
| `shopping_list_item_checked` | `list_id`,`item_count` | `lib/viewmodels/unified_shopping_viewmodel.dart:326` |
| `shopping_list_completed` | `list_id`,`item_count`,`time_to_complete_minutes?` | `lib/viewmodels/unified_shopping_viewmodel.dart:332` |
| `import_started` | `source`,`platform?`,`session_id?`,`image_format` | `lib/views/receive_share_view.dart:98` |
| `import_success` | `source`,`platform?`,`recipe_length?`,`session_id?`,`image_format*` | `lib/views/receive_share_view.dart:165` |
| `extraction_error` | `platform`,`error_category`,`error_type`,`error_message`,`url_domain` | `lib/views/receive_share_view.dart:186`, `lib/repositories/firebase/firebase_analytics_repository.dart:216` |
| `manual_copy_fallback` | `platform`,`reason?` | `lib/views/receive_share_view.dart:234` |
| `import_tier_succeeded` | `tier`,`duration_ms`,`platform_bucket`,`session_id?` | `lib/services/parsing/recipe_parser_service.dart:802` |
| `import_tier_failed` | `tier`,`duration_ms`,`platform_bucket`,`session_id?` | `lib/services/parsing/recipe_parser_service.dart:808` |
| `parse_event_log_failed` | `error_code`,`cause` | `lib/services/parsing/parse_event_logger.dart:74` |
| `campaign_click` | `utm_source`,`utm_medium`,`utm_campaign` | `lib/core/bootstrap/handlers/deep_link_handler.dart:163` |
| `notification_preference_changed` | `category`,`enabled`,`source` | `lib/views/settings/notification_preferences_view.dart:96` |
| `notification_opened` | `route?`,`notificationType?` | `lib/services/notifications/notification_deep_link_router.dart:199` |
| `notification_payload_missing_route` | `notificationType?` | `lib/services/notifications/notification_deep_link_router.dart:174` |
| `notification_payload_unknown_route` | `route`,`notificationType?` | `lib/services/notifications/notification_deep_link_router.dart:186` |
| `feature_flag_evaluated` | `flag`,`enabled` | `lib/services/feature_flags/feature_flag_service.dart:215` |
| `maintenance_mode_shown` | none | `lib/widgets/maintenance_mode_gate.dart:70` |
| `experiment_assigned` | `experiment_name`,`variant` | `lib/services/analytics/experiment_assignment.dart:95` |
| `winback_converted` | `channel`,`variant`,`bucket`,`hours_since_send`,`action_type` | `lib/services/analytics/winback_attribution_service.dart:220` |
| `in_app_review_requested` | `rating` | `lib/services/in_app_review_service.dart:126` |
| `in_app_review_dismissed` | `rating` | `lib/services/in_app_review_service.dart:130` |

### Critical Action Coverage Matrix

| Action | Tracked? | Evidence |
|---|---|---|
| Recipe created (manual) | Yes | `lib/viewmodels/recipe_form/recipe_persistence_manager.dart:372` |
| Recipe imported (URL) | Partial | Import signals in share flow (`lib/views/receive_share_view.dart:98`), not universal flow (`lib/viewmodels/smart_import_viewmodel.dart:266`) |
| Recipe imported (OCR/image) | Partial | OCR import path exists (`lib/services/import/photo_import_strategy.dart:106`), but no universal import telemetry in shared flow (`lib/viewmodels/smart_import_viewmodel.dart:266`) |
| Recipe imported (AI structured) | Partial | Tier/LLM parse analytics exists (`lib/services/parsing/recipe_parser_service.dart:343`, `:803`) but not universally joined to import save |
| Recipe edited | Yes | `lib/viewmodels/recipe_form/recipe_persistence_manager.dart:431` |
| Recipe deleted | Yes | `lib/viewmodels/recipe_detail_viewmodel.dart:234` |
| Recipe viewed | Yes | `lib/viewmodels/recipe_detail_viewmodel.dart:112` |
| Recipe cooked | Yes | `lib/viewmodels/recipe_detail_viewmodel.dart:306` |
| Recipe shared | Yes | `lib/services/share_service.dart:415` |
| Recipe favorited | No | Favorite action exists (`lib/viewmodels/recipe_detail_viewmodel.dart:320`) without dedicated event taxonomy entry (`lib/services/analytics/analytics_events.dart:54`) |
| Friend request sent | Yes | `lib/viewmodels/friends_viewmodel.dart:190` |
| Friend request accepted | Yes | `lib/viewmodels/friends_viewmodel.dart:233` |
| Comment posted | Yes | `lib/services/unified/operations/modules/comment_crud_operations.dart:63` |
| Rating given | Yes | `lib/services/unified/operations/modules/recipe_rating_system.dart:76` |
| Group created | Yes | `lib/viewmodels/create_group_viewmodel.dart:369` |
| Group joined | Yes | `lib/viewmodels/group_invitations_viewmodel.dart:420` |
| Content shared to group | No | Event exists (`lib/services/analytics/analytics_events.dart:96`) but active share paths use `recipe_shared` (`lib/viewmodels/group_recipe_selection_viewmodel.dart:191`) |
| Menu created/generated | Yes | `lib/viewmodels/menu_viewmodel.dart:136` |
| Menu recipe added | No | Realtime add flow has no analytics (`lib/viewmodels/realtime_menu_viewmodel.dart:139`) |
| Shopping list generated | Yes | `shopping_list_created` emitted on list creation (`lib/viewmodels/unified_shopping_viewmodel.dart:143`) |
| Shopping list item checked | Yes | `lib/viewmodels/unified_shopping_viewmodel.dart:326` |
| Import initiated (method-tagged) | Partial | Present in share flow (`lib/views/receive_share_view.dart:98`), missing in universal flow (`lib/viewmodels/smart_import_viewmodel.dart:266`) |
| Import tier used | Yes | `lib/services/parsing/recipe_parser_service.dart:787` |
| Import succeeded | Partial | Present in share flow (`lib/views/receive_share_view.dart:165`), not universal |
| Import failed with reason | Partial | `extraction_error` taxonomy includes reason/category (`lib/repositories/firebase/firebase_analytics_repository.dart:220`) |
| Import duration | Partial | Tier duration and parse time exist (`lib/services/parsing/recipe_parser_service.dart:796`, `lib/services/parsing/parse_event_logger.dart:41`) |
| Post-import edit | Yes | `lib/viewmodels/recipe_form/recipe_persistence_manager.dart:472` |
| Screen views | Partial | Observer path wired (`lib/main.dart:794`, `lib/core/observers/consent_aware_analytics_observer.dart:67`) |
| Tab switches | No | No tab-switch event in growth event taxonomy (`lib/services/analytics/analytics_events.dart:49`) |
| Search performed | Yes | `lib/viewmodels/recipe/recipe_query_viewmodel.dart:129` |

### Onboarding Flow Instrumentation Map

| Step | Instrumented | Evidence |
|---|---|---|
| Onboarding entry | Yes | `onboarding_started` (`lib/viewmodels/onboarding_viewmodel.dart:108`) |
| Per-page progress | Partial | `onboarding_page_viewed` on page changes (`lib/viewmodels/onboarding_viewmodel.dart:118`) |
| Resume from partial | Yes | `onboarding_resumed` (`lib/services/onboarding/onboarding_progress_service.dart:172`) and call from gate (`lib/main.dart:1225`) |
| Abandon nudge after 24h | Yes | stale logic (`lib/services/onboarding/onboarding_progress_service.dart:195`) and event call (`lib/main.dart:1228`) |
| Skip completion | Yes | `lib/viewmodels/onboarding_viewmodel.dart:218` |
| Full completion | Yes | `lib/viewmodels/onboarding_viewmodel.dart:223` |
| Import attempt in onboarding | Yes | `lib/views/onboarding/onboarding_import_page.dart:211` |
| Import success in onboarding | Yes (inline URL path) | `lib/views/onboarding/onboarding_import_page.dart:217` |
| Activation metric (first value) | Yes | `lib/viewmodels/recipe_form/recipe_persistence_manager.dart:410` |

### Analytics Coverage Dashboard

| User Action Category | Actions Defined | Actions Tracked | Coverage |
|---------------------|-----------------|-----------------|----------|
| Recipe lifecycle | 10 | 7 | 70% |
| Social actions | 7 | 6 | 86% |
| Menu planning | 4 | 3 | 75% |
| Import pipeline | 7 | 4 | 57% |
| Navigation | 3 | 2 | 67% |
| Onboarding | 8 | 7 | 88% |

### Phase 2 Preparation

Total issue counts
- Critical: 2
- High: 6
- Medium: 7
- Low: 4

Estimated total remediation effort
- 12-18 engineering days (single engineer), excluding QA hardening for notification + import analytics dashboards.

Cross-cutting pre-analysis blockers to include in Phase 2 sequencing
- Analyzer error (notification consent path) reported by pre-analysis (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-analyze.txt:3`).
- Test suite hang in `infrastructure_integration_test.dart` with repeated 10-minute timeouts (`docs/analysis/runs/2026-05-codex/_pre-analysis/flutter-test.txt:31508`, `:31512`, `:31518`, `:31525`).

Recommended Phase 2 sequence
1. Fix critical import instrumentation + session correlation.
2. Add missing high-impact product events (`favorite`, group-share specificity, menu action events).
3. Patch onboarding first-page tracking and onboarding-photo attribution.
4. Expand notification effectiveness conversion events and preference-change telemetry.
5. Add rollout/experimentation operationalization beyond win-back.
6. Re-run static analysis and full tests after fixing known pre-analysis blockers.
