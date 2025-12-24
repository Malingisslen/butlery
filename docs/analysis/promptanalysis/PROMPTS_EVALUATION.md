# Butlery Analysis Prompts Evaluation

## Introduction

This document evaluates the 15 analysis prompts in `docs/analysis/prompts/` against the actual Butlery codebase. Each prompt is assessed for coverage gaps, relevance to the current architecture, and recommended improvements. The goal is to evolve these prompts to reliably surface the most relevant risks, design issues, and quality concerns.

**Codebase Context**: Butlery is a Flutter recipe management app with MVVM architecture, Firebase backend (Firestore, Auth, Storage, Functions, Analytics, Performance, Messaging), real-time collaboration, offline-first design, and comprehensive social features.

---

## 1. ULTIMATE_CODE_ANALYSIS_PROMPT.md

### Purpose
General code quality and architecture analysis covering patterns, abstractions, and maintainability.

### Relevant Code Areas
- `lib/core/` - Base classes, mixins, DI modules
- `lib/services/` - Business logic layer
- `lib/repositories/` - Data access layer
- `lib/viewmodels/` - Presentation logic
- `lib/models/` - Domain models with facade pattern

### Gaps vs. Current Codebase
1. **Missing: Facade pattern validation** - Butlery uses a specific facade pattern for large models (Recipe → RecipeOperations, RecipeFactory, RecipeSerialization). The prompt doesn't check for this.
2. **Missing: Mixin adoption metrics** - The codebase mandates ErrorHandlingMixin, AsyncOperationMixin, FirebaseServiceMixin adoption. Should verify 100% adoption.
3. **Missing: SerializationUtils usage** - All Firestore parsing must use SerializationUtils. Not mentioned.
4. **Missing: 500-line file limit** - 33 files are intentionally >500 lines with documented rationale. Prompt should reference `ACCEPTED_LARGE_FILES.md`.

### Recommended Improvements
- Add dimension: "Facade Pattern Compliance" - verify large models delegate to focused modules
- Add check: "Mixin adoption rate" for ErrorHandlingMixin, AsyncOperationMixin, FirebaseServiceMixin
- Add check: "SerializationUtils adoption" in all fromFirestore() factories
- Reference `ACCEPTED_LARGE_FILES.md` when flagging large files

### Optional Enhancements
- Check for proper use of `ServiceLocator.get<T>()` vs direct instantiation
- Verify layered architecture: Views → ViewModels → Services → Repositories

---

## 2. ULTIMATE_SECURITY_ANALYSIS_PROMPT.md

### Purpose
Security vulnerabilities, data protection, and compliance analysis.

### Relevant Code Areas
- `firestore.rules` (1337 lines) - Security rules with 20+ helper functions
- `lib/core/mixins/` - PermissionValidationMixin
- `lib/repositories/firebase/base_firebase_repository.dart` - Permission checks
- `lib/services/auth_service.dart` - Authentication logic
- `functions/src/` - Cloud Functions with Admin SDK

### Gaps vs. Current Codebase
1. **Missing: PermissionValidationMixin verification** - All repositories must use this mixin. Prompt doesn't check.
2. **Missing: Collection group query security** - Butlery uses `collectionGroup('members')` queries with specific security rules.
3. **Missing: Subcollection-based sharing** - Issue #014 addressed unlimited sharing via subcollections instead of array limits.
4. **Missing: Cloud Functions security** - Functions use Admin SDK and should never expose sensitive operations to clients.

### Recommended Improvements
- Add check: "PermissionValidationMixin on all repository classes"
- Add check: "Collection group rule coverage" for cross-collection queries
- Add check: "No direct client calls to sensitive Cloud Functions"
- Verify audit logging for GDPR Article 30 compliance in FirebaseAuditRepository

### Optional Enhancements
- Check for proper FCM token scoping (user-specific only)
- Verify consent tracking (GDPR Article 7) in FirebaseConsentRepository

---

## 3. ULTIMATE_FIREBASE_ANALYSIS_PROMPT.md

### Purpose
Firebase services integration, configuration, and best practices.

### Relevant Code Areas
- `lib/core/config/firebase_config.dart` - Multi-platform configuration
- `lib/core/mixins/firebase_service_mixin.dart` (820 lines) - Centralized Firebase operations
- `lib/repositories/firebase/` - 15+ repository implementations
- `functions/src/index.ts` - 10+ Cloud Functions
- `firebase.json`, `firestore.rules`

### Gaps vs. Current Codebase
1. **Missing: FirebaseServiceMixin adoption** - This 820-line mixin eliminates 300+ lines of duplicate code. Should verify adoption.
2. **Missing: Multi-platform Firebase config** - Butlery supports Web, Android, iOS, macOS, Windows.
3. **Missing: Emulator configuration** - Development uses Firebase emulators.
4. **Missing: DNS resilience patterns** - FirebaseServiceMixin includes DNS-aware error handling.

### Recommended Improvements
- Add check: "FirebaseServiceMixin adoption" across all Firebase-accessing services
- Add check: "Multi-platform Firebase initialization" in firebase_config.dart
- Add check: "Emulator support" for local development
- Verify: `executeFirebaseOperationWithDNSResilience()` usage for critical operations

### Optional Enhancements
- Check Cloud Function triggers (onCreate, onUpdate, onDelete) for rating aggregation
- Verify LLM integration (Mistral AI) in structureRecipe/ocrRecipeImage functions

---

## 4. ULTIMATE_PERFORMANCE_ANALYSIS_PROMPT.md

### Purpose
App performance optimization covering rendering, memory, and network efficiency.

### Relevant Code Areas
- `lib/services/performance/intelligent_cache_manager.dart` - Caching layer
- `lib/core/cache/json_cache_helper.dart` - JSON caching
- `lib/services/offline/` - Offline sync with Drift database
- `lib/core/mixins/stream_management_mixin.dart` - Stream lifecycle
- Real-time listeners with 50-recipe limits

### Gaps vs. Current Codebase
1. **Missing: Drift database performance** - Butlery migrated from Hive to Drift. Should check DAO query efficiency.
2. **Missing: Stream listener limits** - Recipes are limited to 50 per stream. Should verify pagination patterns.
3. **Missing: Image compression** - FirebaseStorageRepository includes compression. Not mentioned.
4. **Missing: Firebase Performance traces** - Custom traces with `traceOperation<T>()`. Should verify coverage.

### Recommended Improvements
- Add dimension: "Offline Storage Performance" - Drift DAO query patterns, index usage
- Add check: "Stream pagination limits" to prevent memory bloat
- Add check: "Image compression before upload" in storage operations
- Verify: Firebase Performance trace coverage for critical operations

### Optional Enhancements
- Check for proper stream disposal via StreamManagementMixin
- Verify intelligent cache expiration policies

---

## 5. ULTIMATE_TESTING_ANALYSIS_PROMPT.md

### Purpose
Test coverage, quality, and testing infrastructure analysis.

### Relevant Code Areas
- `test/` - 468 test files
- `test/infrastructure/` - Mocks, builders, factories
- `test/test_support/` - Base test classes, helpers
- `docs/testing/` - Testing documentation

### Gaps vs. Current Codebase
1. **Missing: Mock infrastructure quality** - 4,780 lines in production_mocks.dart. Should evaluate completeness.
2. **Missing: Test builder patterns** - RecipeBuilder, MenuBuilder, etc. use fluent API.
3. **Missing: Three-tier E2E strategy** - Mock (70%), Emulator (25%), Staging (5%). Should verify tier coverage.
4. **Missing: TestServiceLocator pattern** - Mirrors production DI for test isolation.

### Recommended Improvements
- Add check: "Mock completeness" - all repositories and services have corresponding mocks
- Add check: "Builder coverage" - fluent builders exist for all major models
- Add check: "E2E tier distribution" - proper balance across mock/emulator/staging
- Verify: TestServiceLocator initialization/cleanup in all test files

### Optional Enhancements
- Check for proper fallback value registration in mocktail
- Verify stream stabilizer usage for async stream testing

---

## 6. ULTIMATE_CICD_ANALYSIS_PROMPT.md

### Purpose
CI/CD pipeline analysis covering build, test, and deployment automation.

### Relevant Code Areas
- `.github/workflows/` - 5 active workflows
- `tools/validate_architecture.dart` - Custom architecture validation
- `.github/dependabot.yml` - Dependency management
- `.github/PULL_REQUEST_TEMPLATE.md` - PR requirements

### Gaps vs. Current Codebase
1. **Missing: Architecture validation integration** - Custom tool generates JSON reports and PR comments.
2. **Missing: FLUTTER_VERSION centralization** - Version 3.32.4 pinned across all workflows.
3. **Critical Gap: Deployment automation** - No automated deployment to app stores exists.
4. **Missing: Placeholder package name** - `com.example.butlery` needs unique ID for production.

### Recommended Improvements
- Add check: "Architecture validation in CI" - tools/validate_architecture.dart runs
- Add check: "Flutter version consistency" across all workflow files
- Add critical flag: "Deployment automation missing" - no Firebase App Distribution or Play Store deployment
- Add check: "Production package name" - must not be com.example.*

### Optional Enhancements
- Check for DORA metrics tracking (deployment frequency, lead time)
- Verify ProGuard/minification enabled for release builds

---

## 7. ULTIMATE_DEPENDENCIES_ANALYSIS_PROMPT.md

### Purpose
Dependency management, versioning, and security analysis.

### Relevant Code Areas
- `pubspec.yaml`, `pubspec.lock`
- `.github/dependabot.yml` - Automated updates
- `functions/package.json` - Cloud Functions dependencies

### Gaps vs. Current Codebase
1. **Missing: Dependabot grouping strategy** - Firebase updates, testing libraries grouped separately.
2. **Missing: Cloud Functions dependencies** - Node.js dependencies in functions/package.json.
3. **Missing: Drift migration** - Hive → Drift migration. Should check for deprecated Hive references.

### Recommended Improvements
- Add check: "Dependabot configuration completeness" - pub packages and GitHub Actions covered
- Add check: "Cloud Functions dependencies" - functions/package.json version analysis
- Add check: "Deprecated package migration" - no Hive references after Drift migration
- Verify: Dart SDK constraint (^3.5.0) compatibility

### Optional Enhancements
- Check for dependency conflict resolution in pubspec.lock
- Verify Mistral AI SDK version in Cloud Functions

---

## 8. ULTIMATE_DISASTER_RECOVERY_ANALYSIS_PROMPT.md

### Purpose
Backup, recovery, and business continuity analysis.

### Relevant Code Areas
- `lib/services/backup_service.dart` - User data backup
- `lib/services/account/data_export_service.dart` - GDPR data export
- `lib/services/offline/` - Offline data persistence
- Firestore automatic backups (infrastructure)

### Gaps vs. Current Codebase
1. **Missing: GDPR data export** - DataExportService provides Article 15 compliance. Should verify completeness.
2. **Missing: Drift local backup** - Offline data stored in Drift database. Recovery patterns needed.
3. **Missing: Sync queue recovery** - OfflineSyncManager tracks pending changes. Should verify error recovery.

### Recommended Improvements
- Add check: "GDPR Article 15 export completeness" - all user data types included
- Add check: "Drift database backup strategy" - local data recovery after app reinstall
- Add check: "Sync queue failure handling" - failed syncs recorded with retry capability
- Verify: Firestore automatic backup configuration in Firebase Console

### Optional Enhancements
- Check for audit log retention policy (GDPR Article 30)
- Verify image backup in Cloud Storage

---

## 9. ULTIMATE_DOCUMENTATION_ANALYSIS_PROMPT.md

### Purpose
Documentation quality, completeness, and accessibility analysis.

### Relevant Code Areas
- `docs/` - Architecture, testing, analysis documentation
- `CLAUDE.md` - AI assistant instructions
- `CHANGELOG.md` - Version history
- Code comments per COMMENTING_STANDARDS.md

### Gaps vs. Current Codebase
1. **Missing: CLAUDE.md as documentation** - This file serves as project configuration for AI tools.
2. **Missing: Commenting standards** - COMMENTING_STANDARDS.md defines "WHY not WHAT" philosophy.
3. **Missing: Architecture docs** - Comprehensive docs in docs/architecture/ (DI, deduplication, metrics).

### Recommended Improvements
- Add check: "CLAUDE.md accuracy" - instructions match actual codebase patterns
- Add check: "Commenting standards compliance" - no section dividers, English comments
- Add check: "Architecture documentation coverage" - all major patterns documented
- Verify: Testing documentation in docs/testing/

### Optional Enhancements
- Check for outdated TODO references in documentation
- Verify ACCEPTED_LARGE_FILES.md rationale accuracy

---

## 10. ULTIMATE_EDGE_CASES_ANALYSIS_PROMPT.md

### Purpose
Edge case handling, error scenarios, and boundary condition analysis.

### Relevant Code Areas
- `lib/core/mixins/error_handling_mixin.dart` - Centralized error handling
- `lib/core/circuit_breaker.dart` - Circuit breaker pattern
- `lib/services/connectivity_monitoring_service.dart` - Network state
- Offline sync conflict resolution

### Gaps vs. Current Codebase
1. **Missing: Circuit breaker usage** - CircuitBreaker class exists. Should verify adoption.
2. **Missing: DNS resolution failures** - FirebaseServiceMixin handles DNS errors specifically.
3. **Missing: Offline conflict resolution** - SyncStatus enum includes 'conflict' state.
4. **Missing: Real-time collaboration conflicts** - Multiple editors simultaneously.

### Recommended Improvements
- Add check: "Circuit breaker adoption" for external service calls
- Add check: "DNS error handling" in network operations
- Add check: "Offline sync conflict detection" - conflict state properly surfaced to UI
- Add check: "Collaborative editing conflict resolution" - last-write-wins or merge strategy

### Optional Enhancements
- Check for proper handling of expired friend requests (7-day expiration)
- Verify FCM token refresh handling

---

## 11. ULTIMATE_INTERNATIONALIZATION_ANALYSIS_PROMPT.md

### Purpose
Internationalization and localization support analysis.

### Relevant Code Areas
- `lib/` - UI strings (currently Swedish)
- `lib/models/` - timeAgoText helpers (Swedish localized)
- Date/time formatting throughout

### Gaps vs. Current Codebase
1. **Missing: Single-language status** - App is Swedish-only currently. Prompt assumes multi-language.
2. **Missing: Hardcoded Swedish strings** - timeAgoText methods return Swedish text.
3. **Missing: l10n infrastructure** - No arb files or flutter_localizations setup.

### Recommended Improvements
- Add preliminary check: "Current language status" - single vs. multi-language
- Add check: "Hardcoded string detection" - identify Swedish strings in code
- Add check: "l10n infrastructure readiness" - arb files, MaterialLocalizations
- Scale dimensions based on current language support level

### Optional Enhancements
- Check for proper number/currency formatting
- Verify date format localization

---

## 12. ULTIMATE_MONITORING_ANALYSIS_PROMPT.md

### Purpose
Observability, logging, alerting, and incident response analysis.

### Relevant Code Areas
- Firebase Crashlytics integration
- Firebase Analytics (FirebaseAnalyticsRepository)
- Firebase Performance (custom traces)
- `lib/core/` - AppLogger usage
- Cloud Functions logging

### Gaps vs. Current Codebase
1. **Missing: AppLogger patterns** - Centralized logging utility. Should verify usage.
2. **Missing: Firebase Performance traces** - traceOperation<T>() wrapper. Check coverage.
3. **Missing: Cloud Function logging** - Server-side logs for parseEvent, notifications.
4. **Missing: Debug mode analytics disable** - Analytics disabled in debug to avoid test pollution.

### Recommended Improvements
- Add check: "AppLogger adoption" across services and repositories
- Add check: "Firebase Performance trace coverage" for critical user journeys
- Add check: "Cloud Function logging" with proper severity levels
- Verify: Analytics disabled in debug builds

### Optional Enhancements
- Check for Crashlytics custom keys in error reporting
- Verify structured logging format consistency

---

## 13. ULTIMATE_PLATFORM_ANALYSIS_PROMPT.md

### Purpose
iOS/Android platform compliance, feature parity, and store readiness.

### Relevant Code Areas
- `android/` - Gradle configuration, ProGuard
- `ios/` - Xcode configuration
- `macos/`, `windows/`, `linux/` - Desktop support
- Platform-specific permissions

### Gaps vs. Current Codebase
1. **Missing: Multi-platform scope** - Butlery supports 5 platforms (Android, iOS, Web, macOS, Windows). Prompt focuses on iOS/Android only.
2. **Missing: Debug signing only** - No production signing configured. Critical for store release.
3. **Missing: Placeholder package name** - com.example.butlery is not store-ready.
4. **Missing: ProGuard disabled** - Release builds lack minification.

### Recommended Improvements
- Expand scope: Include web, macOS, Windows platforms
- Add critical check: "Production signing configuration" - keystore/provisioning profiles
- Add critical check: "Unique package/bundle identifier" - not com.example.*
- Add check: "ProGuard/R8 enabled" for Android release builds

### Optional Enhancements
- Check for proper permission declarations per platform
- Verify Firebase configuration per platform (GoogleService-Info.plist, google-services.json)

---

## 14. ULTIMATE_SCALABILITY_ANALYSIS_PROMPT.md

### Purpose
Growth readiness, data structure scaling, and cost projection analysis.

### Relevant Code Areas
- Firestore data model and indexes
- `firestore.rules` - Query patterns
- Stream pagination (50-recipe limits)
- Real-time collaboration architecture

### Gaps vs. Current Codebase
1. **Missing: Subcollection-based scaling** - Issue #014 moved from array-based to subcollection sharing.
2. **Missing: Stream pagination limits** - 50 recipes per stream. Should verify all collections.
3. **Missing: Real-time collaboration scaling** - Presence tracking, active editor limits.
4. **Missing: Cloud Function concurrency** - Node.js 20 runtime, concurrent execution limits.

### Recommended Improvements
- Add check: "Subcollection pattern adoption" for unlimited member scaling
- Add check: "Stream query limits" across all real-time watchers
- Add check: "Collaboration participant limits" in realtime resources
- Add check: "Cloud Function timeout/memory configuration"

### Optional Enhancements
- Check for proper Firestore composite index definitions
- Verify batch operation limits (500 documents per batch)

---

## 15. ULTIMATE_UX_UI_ANALYSIS_PROMPT.md

### Purpose
User experience quality, design consistency, and accessibility analysis.

### Relevant Code Areas
- `lib/theme/` - Design system, colors, typography
- `lib/widgets/common/` - Reusable UI components
- `lib/core/responsive/breakpoints.dart` - Responsive design
- `lib/views/` - Feature screens

### Gaps vs. Current Codebase
1. **Missing: Responsive design system** - Breakpoints, ConstrainedBox patterns documented in RESPONSIVE_DESIGN_GUIDE.md.
2. **Missing: Component theming** - button_themes.dart, input_themes.dart provide centralized styling.
3. **Missing: Skeleton loading** - skeleton_components.dart provides loading states.
4. **Missing: Empty states** - empty_states.dart provides consistent empty state widgets.

### Recommended Improvements
- Add check: "Responsive breakpoint compliance" - Narrow (500-600px), Medium (700-800px), Wide (900-1200px)
- Add check: "Component theme adoption" - using ButtonThemes, InputThemes
- Add check: "Loading state patterns" - skeleton components vs spinners
- Add check: "Empty state consistency" - using empty_states.dart widgets

### Optional Enhancements
- Check for proper ConstrainedBox usage for content width limits
- Verify BaseScaffold adoption across views

---

## Cross-Cutting Recommendations

### Systemic Gaps Not Covered by Any Prompt

1. **ServiceLocator Pattern Validation**
   - No prompt checks for proper `ServiceLocator.get<T>()` usage vs direct instantiation
   - Critical for DI consistency across the codebase

2. **Mixin Adoption Tracking**
   - Multiple critical mixins (ErrorHandlingMixin, AsyncOperationMixin, FirebaseServiceMixin)
   - No prompt systematically verifies 100% adoption

3. **Copy-on-Write Collaboration Pattern**
   - SharedRecipe uses copy-on-write for collaborative editing
   - No prompt analyzes this pattern's implementation

4. **Real-time Presence System**
   - Active editor tracking via presence subcollections
   - No prompt covers presence lifecycle (join, heartbeat, cleanup)

5. **Unified Service Layering**
   - Services expose `.personal`, `.social`, `.realtime`, `.share` sub-services
   - No prompt validates this layered API design

### Prompt Prioritization

| Priority | Prompt | Reason |
|----------|--------|--------|
| P0 | Security | Firebase rules complexity (1337 lines), GDPR compliance |
| P0 | Firebase | Core infrastructure, 820-line mixin adoption |
| P0 | CI/CD | Critical deployment automation gap |
| P1 | Code Analysis | Architecture patterns, facade model |
| P1 | Testing | 468 tests, mock infrastructure quality |
| P1 | Performance | Offline-first, real-time listeners |
| P2 | Platform | Multi-platform support, store readiness |
| P2 | Scalability | Subcollection patterns, stream limits |
| P2 | Edge Cases | Circuit breaker, conflict resolution |
| P3 | Others | Lower immediate impact |

---

## Conclusion

The 15 analysis prompts provide comprehensive coverage of software quality dimensions but require updates to match Butlery's specific architecture. Key gaps include:

1. **Mixin-based architecture** - Multiple prompts should verify mixin adoption rates
2. **Facade pattern for models** - Code analysis should check module delegation
3. **Firebase-specific patterns** - FirebaseServiceMixin, subcollection sharing
4. **Deployment automation** - Critical gap requiring immediate attention
5. **Multi-platform scope** - Expand beyond iOS/Android to include web and desktop

Each prompt should be updated with the dimension-specific recommendations above to ensure thorough analysis of the actual Butlery codebase.
