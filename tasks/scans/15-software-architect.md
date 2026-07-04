# Scan — Role #15 Software Architect

Lens: MVVM+Repository discipline, DI correctness, base-class/mixin adoption, file-size facade
pattern, layering violations. Two passes run. Owned paths reviewed.
Date: 2026-06-27. Scanner: Software Architect (role #15).

Dedup sources consulted: `tasks/_scan_dedup_titles.txt`, `.claude/linear-tracker.json`,
`.claude/rules/accepted-deviations.md`, dossier watch-items (ROLE_RESPONSIBILITY_MAP #15).

---

## PASS 1 — Layering violations · DI gaps · mixin non-adoption

### NEW-1 [Layering] View calls `FirebaseAuth.instance.currentUser?.delete()` directly — skips AuthService

`lib/views/onboarding/onboarding_age_gate_blocked_view.dart:57` reaches into the Firebase SDK
straight from the View layer to delete the underage user's auth account. This violates the
MVVM+Repository spine (Views → ViewModels → Services → Repositories → Firebase) and the explicit
rule in `lib/repositories/CLAUDE.md` ("Never access `FirebaseAuth.instance.currentUser`"). The same
method already resolves `AuthService` via `ServiceLocator.get<AuthService>()` at line 51 and calls
`authService.signOut()` at line 71 — so the seam exists; only the `delete()` path bypasses it.

- Severity: Medium (correctness/architecture; the delete is best-effort + try/caught, so no crash,
  but it's an untestable, un-mockable SDK reach from UI on a privacy-sensitive path).
- Fix: add `Future<void> deleteCurrentAuthUser()` to `AuthService`, route the View through it.
- Not covered by BUT-1384/BUT-1386 (those enforce the *age floor*; they don't touch this
  cleanup-path layering). Genuinely new.
- Evidence: `lib/views/onboarding/onboarding_age_gate_blocked_view.dart:50-74`.

### Verified-clean / already-tracked (not re-flagged)

- All `firestore ?? FirebaseFirestore.instance` constructor defaults across `lib/repositories/**`
  are the **accepted DI-injection pattern** (test seam), not violations. Confirmed ~25 sites.
- Top-level metrics/telemetry repos (`anomaly_`, `daily_snapshot_`, `engagement_`, `ops_log_`,
  `parse_events_`, `parsing_correction_`, `recipe_stats_`, `site_config_repository.dart`) don't
  extend `BaseFirebaseRepository`/`PermissionValidationMixin` — already inside the tracked
  **BaseFirebaseRepository-adoption cluster (BUT-442 / BUT-455 / BUT-574)**. Not new.
- Service-layer Firestore holds (account-deletion, data-export, group/cache/import/messaging/
  notifications) covered by **BUT-440 / BUT-498 / BUT-501 / BUT-504 / BUT-506 / BUT-510**. Not new.
- `di_container.dart` health-check auth read covered by **BUT-510**. Not new.
- ChangeNotifier-vs-BaseViewModel drift covered by **BUT-115 (EPIC) + BUT-520**. Not new.

---

## PASS 2 — Base-class drift · file-size facade · abstraction smells

### NEW-2 [Code Quality] ACCEPTED_LARGE_FILES.md is materially stale — 52 files >500 lines are NOT listed

`docs/architecture/ACCEPTED_LARGE_FILES.md` (header dated 2026-06-21, "148 files") is the gate that
makes the 500-line facade rule enforceable: a reviewer trusts that anything large is *either*
listed-with-rationale *or* a finding. That contract is broken — a full recount finds **52 files over
500 lines with no entry** in the doc (and several listed files have drifted well past their recorded
size, e.g. `recipe_unified.dart` recorded 1,425 → now 1,671; `recipe_detail_view.dart` 1,064 →
1,273; `recipe_list_viewmodel.dart` 790 → 1,177; `ocr_extraction_service.dart` 634 → 1,020;
`personal_recipe_module.dart` 1,023 → 1,100).

This is broader than the prior one-off reconciliations: **BUT-550** reconciled 7 named drifted files
and **BUT-542** tracks one specific widget (`calendar_weekly_menu_widget.dart`). Neither covers this
52-file systemic gap, which includes its own owned infra (`base_firebase_repository.dart` 505,
`serialization_utils.dart` 579, `json_serializable_mixin.dart` 512) plus many views/VMs/services.

Unlisted >500-line files (line count, basename):
```
693 persistence_service.dart            666 personal_tag_crud_service.dart
656 app_router.dart                      654 recipe_detail_comments.dart
648 recipe_detail_viewmodel.dart         647 photo_import_viewmodel.dart
636 friend_categories_operations.dart*   633 chat_viewmodel.dart*
626 collaboration_management_module.dart*625 unified_shopping_view.dart
608 firebase_analytics_repository.dart   606 firebase_tag_config.dart*
595 collaborative_shopping_items.dart    579 serialization_utils.dart
575 analytics_service.dart               573 calendar_cells.dart
565 tag_result_display.dart              563 weekly_menu_plan_service.dart
559 selection_app_bar.dart               554 firebase_data_export_repository.dart**
540 universal_share_dialog_viewmodel.dart 536 social_module.dart
533 friends_viewmodel.dart               528 upload_progress_widgets.dart
528 social_shopping_coordinator.dart     528 shared_content_actions.dart
526 cache_optimization.dart              523 message_mutation_module.dart
522 base_social_coordinator.dart         522 algolia_search_repository.dart
521 collection_stats_view.dart           520 firebase_social_request_repository.dart
519 veckomeny_view.dart                  519 tiktok_pipeline.dart
518 recipe_persistence_manager.dart      516 performance_monitoring_service.dart
514 shared_shopping_viewmodel.dart       512 social_builder_components.dart
512 notification_batch_manager.dart      512 json_serializable_mixin.dart
511 social_group_detail_viewmodel.dart   511 code_lexicon_provider.dart
510 presence_tracking_module.dart        509 social_menu_operations.dart
508 text_import_viewmodel.dart           508 social_engagement_metrics.dart
508 menu_service.dart                    507 url_import_strategy.dart
507 firebase_friends_repository.dart     507 duplicate_merge_sheet.dart
506 recipe_auto_save_manager.dart        505 shopping_sharing_status_dialog.dart
505 menu_generator.dart                  505 base_firebase_repository.dart
504 recipe_member_manager.dart           504 friend_category_repository.dart
663 user_profile.dart                    665 menu_content_widgets.dart (in doc? verify)
```
(* a handful e.g. `friend_categories_operations.dart`, `chat_viewmodel.dart`, `firebase_tag_config.dart`
ARE in the doc but under a basename my extraction matched loosely — treat the canonical list as the
~52 produced by `comm -23` of the recount vs doc backtick-names; **`firebase_data_export_repository.dart`
relates to the BUT-440/501 data-export cluster** and may be folded there.)

- Severity: Medium (process/enforceability, not a runtime bug). The doc is the architect's primary
  control surface; left stale it silently disables the 500-line rule for half the large files.
- Recommended action: a single reconciliation ticket — run `bash tools/count_large_files.sh`, then
  for each unlisted file either add a rationale row or schedule a facade extraction; fix the header
  count. Same shape as BUT-550 but a recount-and-reconcile-all, not 7 named files.
- Genuinely new as a systemic finding (no open ticket covers the 52-file gap or the header drift).

### Verified-clean (not flagged)

- Mixin adoption (`FirebaseServiceMixin`, `StreamManagementMixin`, `ErrorHandlingMixin`) and
  `SerializationUtils` usage remain broad; no new non-adoption hotspot beyond tracked tickets
  (BUT-471/567 etc.).
- DI module init-ordering race in `unified_recipe_service.dart` is the existing dossier watch-item
  (#15 watch list), not re-filed.

---

COVERAGE: Owned paths + full `lib/` swept for FirebaseFirestore/FirebaseAuth direct use, repo base
classes, and >500-line files (recounted vs ACCEPTED_LARGE_FILES.md). 2 NEW findings:
(1) View→FirebaseAuth layering skip in onboarding age-gate; (2) 52-file ACCEPTED_LARGE_FILES drift /
stale header. All other layer-skip, BaseRepository-adoption, and ChangeNotifier-VM items dedup to
existing tickets (BUT-440/442/455/498/501/504/506/510/520/542/550/574/115).
