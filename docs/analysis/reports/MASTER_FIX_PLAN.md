# Master Fix Plan - Butlery Analysis Remediation

**Created**: 2026-02-10
**Status**: In Progress
**Source**: Six analysis reports scored 70.2/100 avg across 145 issues (10 critical, 32 high, 62 medium, 41 low)

---

## Sprint 0: Quick Wins (~8-10 hours)

No dependencies. High ROI. All items parallelizable.

| ID | Issue | Files | Hours | Status |
|----|-------|-------|-------|--------|
| S0-1 | Remove 250ms placeholder delays in bootstrap stages | `lib/core/bootstrap/stages/core_stage.dart:61`, `ui_stage.dart:43,48` | 0.5 | [x] |
| S0-2 | Fix dispose() leaks in MenuStateManager + ChatViewModel | `lib/viewmodels/menu/menu_state_manager.dart`, `lib/viewmodels/chat_viewmodel.dart:461` | 1 | [x] |
| S0-3 | Set image cache size limits (100 items / 50MB) | `lib/main.dart` (after ensureInitialized) | 0.5 | [x] |
| S0-4 | Set Firestore cache size limit (replace UNLIMITED with 100MB) | `lib/services/unified/unified_recipe_service.dart:437`, `lib/repositories/firebase/firebase_service_mixin.dart:671` | 1 | [x] |
| S0-5 | Remove section divider comments (`// ====`) across files | `lib/theme/app_colors.dart` (24), `lib/services/tagging/personal_tag_service.dart` (18), +9 files | 1 | [x] |
| S0-6 | Dispose IntelligentCacheManager on app termination | `lib/main.dart` (_ButleryAppState.dispose) | 0.5 | [x] |
| S0-7 | Add CI workflow concurrency limits to cancel superseded runs | `.github/workflows/*.yml` (5 files) | 1 | [x] |
| S0-8 | Parallelize independent services in ContentModule init | `lib/core/di/modules/content_module.dart:374-392` | 2 | [x] |

---

## Sprint 1: Production Blockers (~25-35 hours)

Must complete before store submission. S1-1 is prerequisite for most others.

**DEFERRED** - All items pending account setup (package name, Apple Dev, Firebase envs).

| ID | Issue | Files | Hours | Depends | Status |
|----|-------|-------|-------|---------|--------|
| S1-1 | Change package name from `com.example.butlery` | `android/app/build.gradle.kts`, `ios/Runner.xcodeproj/project.pbxproj`, `macos/`, `linux/` | 4-6 | User decides name | DEFERRED |
| S1-2 | Configure Android release signing | `android/app/build.gradle.kts:38`, new `android/key.properties` | 3-4 | S1-1 | DEFERRED |
| S1-3 | Configure iOS signing and provisioning | `ios/Runner.xcodeproj/project.pbxproj` | 4-6 | S1-1 + Apple Dev | DEFERRED |
| S1-4 | Firebase environment separation (dev/staging/prod) | `.env.*`, `firebase.json`, `lib/firebase_options.dart` | 8-12 | S1-1 | DEFERRED |
| S1-5 | Enable Firestore PITR + backup configuration | Firebase Console (no code changes) | 2-4 | S1-4 | DEFERRED |
| S1-6 | App store metadata and privacy policy | `store_assets/`, `assets/legal/` | 4-8 | S1-1 | DEFERRED |

---

## Sprint 2: Security & Architecture (~20-28 hours)

| ID | Issue | Files | Hours | Depends | Status |
|----|-------|-------|-------|---------|--------|
| S2-1 | Add authorization check to sendNotification Cloud Function | `functions/src/notifications/send-notification.ts:62-70` | 4-6 | - | [x] |
| S2-2 | Fix SSL pinning to fail closed (return false, not true) | `lib/core/network/ssl_pinning_service.dart:78` | 2-3 | - | [x] |
| S2-3 | Inject Firestore into AuthService + TagConfigService | `lib/services/auth_service.dart:32`, `lib/services/tagging/tag_config_service.dart:67` | 3-4 | - | [x] |
| S2-4 | Migrate PersistenceService from SharedPreferences to encrypted Drift DB | `lib/services/persistence_service.dart` | 3-4 | - | DEFERRED |
| S2-5 | Refactor tag_detail_view.dart (1,208 lines) | `lib/views/tag_detail_view.dart` -> extract sub-widgets | 4-6 | - | [x] |
| S2-6 | Verify session timeout is fully wired end-to-end | `lib/services/session_timeout_service.dart` | 2-3 | - | [x] (verified) |

---

## Sprint 3: Performance & Scalability (~15-25 hours)

| ID | Issue | Files | Hours | Depends | Status |
|----|-------|-------|-------|---------|--------|
| S3-1 | Fix ingredient collection unbounded listener | `lib/repositories/firebase/firebase_ingredient_repository.dart:85` | 8-16 | - | [x] |
| S3-2 | Defer non-critical DI modules to post-first-frame | `lib/main.dart`, `lib/core/bootstrap/application_bootstrap.dart` | 8-16 | S0-8 | DEFERRED |
| S3-3 | Convert ListView to ListView.builder in data-heavy views | `tag_detail_view.dart`, `edit_recipe_view.dart`, `personal_tags_view.dart` | 4-8 | Benefits S2-5 | DEFERRED |
| S3-4 | Timer audit - ensure all 86 Timer usages are properly cancelled | Priority: `performance_monitoring_service.dart`, `notification_offline_manager.dart` | 4-8 | - | [x] |

---

## Sprint 4: Quality & Polish (~40-60 hours)

| ID | Issue | Files | Hours | Depends | Status |
|----|-------|-------|-------|---------|--------|
| S4-1 | Begin Colors.* to AppColors/Theme migration (2,135 refs) | `lib/views/` (732), `lib/widgets/` (1,147) | 16-24 | - | [x] (14 non-transparent refs migrated, 36 Colors.transparent kept as idiomatic, 4 in ColorScheme defs kept) |
| S4-2 | Add Semantics to 80+ interactive elements | 51 files in `lib/widgets/` | 8-12 | - | [x] (49 markers added: 38 Semantics + 11 tooltips across ~34 files) |
| S4-3 | Color contrast audit (WCAG 2.1 AA 4.5:1) | `lib/theme/app_colors.dart` | 4-6 | Benefits S4-1 | [x] (4 colors adjusted: textMedium, success, warning, info; textLight kept for decorative/large-text only) |
| S4-4 | Wire up l10n infrastructure (~469 hardcoded Swedish strings) | `lib/l10n/app_sv.arb`, `lib/l10n/app_en.arb`, view files | 8-16 | - | [ ] |
| S4-5 | Upgrade 7 major-version-behind dependencies | `pubspec.yaml` - csv, flutter_dotenv, device_info_plus, http_certificate_pinning, local_auth, flutter_local_notifications, flutter_secure_storage | 6-8 | - | [x] (5/7 upgraded, csv needs Dart 3.10+, device_info_plus needs AGP 8.12+) |

---

## Backlog

| ID | Issue | Effort | Depends | Status |
|----|-------|--------|---------|--------|
| B-1 | Automated deployment pipeline (Fastlane + GH Actions) | 2-4 weeks | S1-1,2,3 | [ ] |
| B-2 | notifyListeners() optimization (527 calls) | 5-10 days | - | [ ] |
| B-3 | Focus traversal + keyboard navigation | 2 days | S4-2 | [ ] |
| B-4 | Text scaling overflow testing (200% scale) | 2 days | - | [ ] |
| B-5 | Dark mode systematic testing | 2-3 days | S4-1 | [ ] |
| B-6 | Firestore subcollection migration for sharedWith arrays | 5-8 days | - | [ ] |
| B-7 | Add osv-scanner to CI for vulnerability scanning | 1 day | - | [ ] |
| B-8 | iOS build in CI (macOS runner) | 1-2 days | S1-3 | [ ] |
| B-9 | Remove FirebaseAuth.instance from firebase_social_recipe_repository.dart | 1-2 hours | - | [x] (explicit injection via social_module.dart) |

---

## Projected Score Impact

| Sprint | Current Avg | After | Key Dimension Jumps |
|--------|-------------|-------|---------------------|
| Sprint 0 | 70.2 | ~73 | Perf 71->75, Code 82->84 |
| Sprint 1 | ~73 | ~79 | Infra 58->72, UX 62->66 |
| Sprint 2 | ~79 | ~84 | Security 76->84, Code 84->88 |
| Sprint 3 | ~84 | ~88 | Perf 75->85 |
| Sprint 4 | ~88 | ~92 | UX 66->80, Deps 72->80 |

---

## Verification Protocol

After each sprint:
1. `flutter analyze` - zero new warnings
2. `flutter test` - all existing tests pass
3. Spot-check affected features in Chrome (`flutter run -d chrome`)
4. Re-run relevant analysis prompt to measure score improvement
