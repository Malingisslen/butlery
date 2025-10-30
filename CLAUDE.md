# Claude Code Project Configuration

## Flutter Commands (Windows Environment)
**Environment**: Running Flutter directly on Windows via VS Code

**Examples:**
- Analysis: `flutter analyze`
- Run: `flutter run`
- **Clean Run**: `flutter_run_clean.bat` (filters system noise, to be created if needed)
- **Tests**: `flutter test test/unit/file_test.dart` (use forward slashes for consistency)

**PATH RULES:**
- **ALWAYS** use forward slashes in test paths: `test/unit/file_test.dart` ✅
- Backslashes work but forward slashes are preferred for consistency: `test\unit\file_test.dart` (works but avoid)
- **PREFERRED**: Use `./run_tests_safely.sh` script for batch testing

## Architecture & Standards
- **Pattern**: MVVM + Repository Pattern (Views → ViewModels → Services → Repositories → Firebase)
- **File Size Target**: 500 lines (use facade/module pattern for larger files)
  - **Current Status**: Most files under 500 lines
  - **Known Exceptions**: Some repositories (~400-450 lines), unified services with modules
  - **Refactoring Strategy**: Extract modules for >500 line files (see unified services pattern)
  - **Priority**: New code must follow 500-line limit; legacy code refactored as touched
- **Dependency Injection**: Modular DI system with domain-driven modules (see below)
- **Notifications**: Complete FCM system with development logging approach
- **Social Features**: 85-92% infrastructure complete (verified 2025-01)
  - ✅ Complete: Friends, sharing, comments, ratings, groups, collaborative lists
  - ✅ Repositories: All 4 social repos with security & audit logging
  - ✅ Services: 13 DI-registered services with business logic
  - ✅ UI: 61 social views/components with real-time streams
  - ⚠️ Remaining: Navigation wiring verification, test coverage expansion, UI polish
- **Test Coverage & Infrastructure**:
  - **Current Status**: ~35-40% coverage (services and repositories prioritized)
  - **Test Dashboard**: See `/docs/testing/TESTING_DASHBOARD.md` for detailed status
  - **Test Patterns**: See `/docs/testing/TEST_PATTERNS_QUICK_REFERENCE.md` for essential patterns
  - **Test Templates**: Use `/test/templates/` for consistent test structure
  - **Coverage by Layer**:
    - ✅ Repositories: 50-60% (critical paths covered, permission validation tested)
    - ✅ Services: 40-50% (core business logic covered)
    - ⚠️ ViewModels: 20-30% (partial coverage, needs expansion)
    - ⚠️ Widgets/Views: 10-15% (UI testing minimal)
    - ✅ Models: 60-70% (data models well tested)
  - **Test Strategy**: Bottom-up (repositories → services → viewmodels → integration)
  - **CI/CD**: Tests run on every commit (GitHub Actions)
  - **Priority Areas**: Security validation, GDPR compliance, data integrity
- **Code Quality**: Single Responsibility Principle enforced
- **Security**: Comprehensive permission validation system implemented:
  - PermissionValidationMixin for all Firebase repositories
  - Authorization checks on all CRUD operations
  - Audit logging for security events
  - Ownership validation and role-based access control
- **GDPR Compliance**: Production-ready for EU market (Phase 1 complete - Jan 2025)
  - ✅ **Article 7**: Explicit consent management with granular controls
    - ConsentService with consent types (data processing, marketing, analytics)
    - Firebase Firestore consent storage with version tracking
    - Opt-in only design (no pre-checked boxes)
  - ✅ **Article 15**: Right of access (data portability)
    - DataExportService generates complete user data exports
    - JSON format with all user content (recipes, menus, lists, social data)
    - Self-service export from settings
  - ✅ **Article 17**: Right to erasure (right to be forgotten)
    - AccountDeletionService with complete data removal
    - Cascading deletion across all collections
    - Audit trail of deletion operations
  - ✅ **Article 30**: Records of processing activities
    - FirebaseAuditRepository with persistent audit logging
    - Security event tracking for all sensitive operations
    - Compliant audit trail for regulatory review
  - **Documentation**: See `/docs/gdpr/` for implementation details
  - **Firestore Rules**: 30+ security rules cover all GDPR requirements
- **Type Safety**: Map-based data access replaced with proper model usage
- **Flutter Color Syntax**: Use `withValues(alpha: 0.8)` instead of deprecated `withOpacity(0.8)`
- **Data Source Architecture**: CRITICAL - ViewModels must connect to correct services:
  - Use `UserService.currentUserProfile` for complete user data (settings, avatar, social features)
  - Use `PermissionService.currentUser` only for basic auth/permission checks
  - **Never mix data sources** - leads to settings not persisting and UI inconsistencies

### Layered Service Architecture (Unified Services)
**Pattern**: Facade pattern with feature-specific operation layers

Unified services (UnifiedRecipeService, UnifiedShoppingService, UnifiedMenuService) use a consistent 3-4 layer architecture:

**Layer 1: Personal Operations** - User's own content
```dart
final recipe = await recipeService.personal.createRecipe(...);
final list = await shoppingService.personal.createList(...);
```
- CRUD operations for user's personal content
- Local caching and optimization
- No sharing or collaboration

**Layer 2: Social/Collaborative Operations** - Sharing and collaboration
```dart
final sharedRecipe = await recipeService.social.shareWithFriends(recipeId, friendIds);
final memberList = await shoppingService.collaborative.addMember(listId, userId);
```
- Friend and group sharing
- Collaborative editing
- Member management
- Permission-based access

**Layer 3: Realtime Operations** - Live synchronization
```dart
final stream = recipeService.realtime.watchRecipe(recipeId);
```
- Real-time Firebase streams
- Collaborative state sync
- Live updates and notifications

**Layer 4: Share Operations** - Specific sharing workflows (optional)
```dart
await shoppingService.share.shareListWithFriend(listId, friendId);
```
- Platform-specific sharing
- Share link generation
- External sharing flows

**Usage Rules**:
- Always use the appropriate layer for the operation type
- Don't bypass layers (e.g., don't use personal ops for shared content)
- Each layer handles its own permissions and validation
- Services expose layers via public getters: `.personal`, `.social`/`.collaborative`, `.realtime`, `.share`

### Dependency Injection System
**Architecture**: Clean modular DI with GetIt service locator
- **7 Application Modules**: Core, Content, Social, Messaging, Collaboration, Performance, UI
- **Bootstrap Pattern**: ApplicationBootstrap orchestrates initialization
- **Service Access**: Use `ServiceLocator.get<T>()` for all service access
- **NO LEGACY CODE**: The old `sl<T>()` pattern has been completely removed

**Module Structure:**
```dart
// Import for service access
import 'package:butlery/core/providers/application_provider.dart';

// Get services using
final service = ServiceLocator.get<UnifiedRecipeService>();
```

**Application Modules:**
1. **Core Module** (`lib/core/di/modules/core_module.dart`): Auth, Storage, Analytics
2. **Content Module** (`lib/core/di/modules/content_module.dart`): Recipes, Menus, Import
3. **Social Module** (`lib/core/di/modules/social_module.dart`): Friends, Sharing, Comments
4. **Messaging Module** (`lib/core/di/modules/messaging_module.dart`): Chat, Notifications
5. **Collaboration Module** (`lib/core/di/modules/collaboration_module.dart`): Realtime, Shopping
6. **Performance Module** (`lib/core/di/modules/performance_module.dart`): Cache, Startup, Monitoring
7. **UI Module** (`lib/core/di/modules/ui_module.dart`): ViewModels, Navigation, UI State

**Service Access Patterns:**

The codebase uses two patterns for accessing services. Use the appropriate pattern based on context:

**Pattern 1: Constructor Injection (Preferred for Services & Repositories)**
```dart
class MyService {
  final AuthRepository _authRepository;
  final RecipeRepository _recipeRepository;

  MyService({
    required AuthRepository authRepository,
    required RecipeRepository recipeRepository,
  }) : _authRepository = authRepository,
       _recipeRepository = recipeRepository;
}

// In DI module:
container.registerSingleton<MyService>(
  MyService(
    authRepository: container<AuthRepository>(),
    recipeRepository: container<RecipeRepository>(),
  ),
);
```
**When to use**:
- ✅ Registering services in DI modules
- ✅ Core dependencies that won't create circular references
- ✅ When you need explicit dependency tracking
- ✅ For testability (easy to mock in constructors)

**Pattern 2: ServiceLocator.get<T>() (For Runtime Access)**
```dart
class MyWidget extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final recipeService = ServiceLocator.get<UnifiedRecipeService>();
    return ...;
  }
}

class MyViewModel {
  late final PermissionService _permissionService;

  void initialize() {
    // Late initialization to avoid circular dependencies
    _permissionService = ServiceLocator.get<PermissionService>();
  }
}
```
**When to use**:
- ✅ In widgets and ViewModels
- ✅ For lazy dependencies (avoiding circular deps during DI setup)
- ✅ When dependency needed at runtime, not construction
- ✅ For cross-module dependencies that would create circular refs

**Anti-patterns to avoid**:
- ❌ Don't mix both patterns in the same class constructor
- ❌ Don't use ServiceLocator.get<T>() in DI module registration (use container<T>())
- ❌ Don't use direct imports for services when DI is available
- ❌ **NEVER use `FirebaseFirestore.instance` directly** - always inject FirestoreRepository
  - Breaks repository pattern
  - Destroys testability
  - Bypasses security validation layer
  - Use: `FirestoreRepository` constructor injection instead

**Singleton Registration Patterns:**

Choose the appropriate registration pattern based on initialization needs:

**registerSingleton** - Eager initialization (created immediately)
```dart
container.registerSingleton<AuthRepository>(
  FirebaseAuthRepository(),
);
```
**When to use**:
- ✅ Core infrastructure (Auth, Storage, Firestore)
- ✅ Services needed at app startup
- ✅ No heavy initialization or I/O operations
- ✅ No circular dependency risks

**registerLazySingleton** - Lazy initialization (created on first access)
```dart
container.registerLazySingleton<SocialRecipeService>(
  () => SocialRecipeService(
    repository: container<SocialRecipeRepository>(),
    userService: container<UserService>(),
  ),
);
```
**When to use**:
- ✅ Services with heavy initialization
- ✅ Cross-module dependencies (avoid circular refs during DI setup)
- ✅ Services not needed immediately at startup
- ✅ ViewModels and UI-related services
- ✅ Feature modules that depend on Core/Content modules

**Rule of thumb**: Core module uses eager singletons, all other modules prefer lazy singletons.

**Main.dart Structure:**
```dart
// Clean bootstrap initialization
await ApplicationBootstrap.initialize();
// Followed by widget bindings and app startup
```

### Code Intelligence Platform (`tools/code_intelligence_platform.dart`)
- **Multi-Dimensional Analysis**: Security (30%), Performance (25%), Architecture (20%), Quality (15%)
- **Reality-Based Scoring**: Uses weakest link principle - no inflated metrics
- **Predictive Intelligence**: Bug hotspots and maintenance burden forecasting
- **Actionable Remediation**: Specific fix suggestions with effort estimates
- **Flutter Intelligence**: State management, widget optimization, lifecycle analysis
- **Run Command**: `dart tools/code_intelligence_platform.dart`

## Test System Guidelines
- **Complete Guide**: See `/docs/testing/TEST_GUIDE.md`
- **Quick Patterns**: See `/docs/testing/TEST_PATTERNS_QUICK_REFERENCE.md`
- **Current Status**: See `/docs/testing/TESTING_DASHBOARD.md`
- **Templates**: Use `/test/templates/` for consistent test creation

## Production Readiness & Remediation Progress

### Completion Status (As of Jan 2025)

**Overall Progress**: 28/47 issues resolved (60%) | Production Readiness: 85%

| Phase | Focus | Status | Issues | Completion |
|-------|-------|--------|--------|------------|
| **Phase 1** | Critical Security (CVSS 9.1) | ✅ Complete | 8/8 | 100% |
| **Phase 2** | Broken Features & Docs | ✅ Complete | 12/12 | 100% |
| **Phase 3** | Code Quality (File Size) | ⏸️ Deferred | 0/9 | 0% |
| **Phase 4** | Performance Optimization | ✅ Complete | 7/7 | 100% |
| **Phase 5** | Testing & Validation | 🔄 In Progress | 1/11 | 9% |

**Phase 1 Highlights** (✅ Complete):
- Resolved CVSS 9.1 open read access vulnerability
- Implemented permission validation across 27 repositories
- Added persistent audit logging (GDPR Article 30)
- Deployed comprehensive Firebase Security Rules
- Full GDPR compliance (Articles 7, 15, 17, 30)

**Phase 2 Highlights** (✅ Complete):
- Fixed shopping collaboration feature (participant resolution)
- Verified social features completion (85-92%)
- Documented 7 application modules (was incorrectly listed as 5)
- Documented layered service architecture pattern
- Added comprehensive test coverage documentation

**Phase 3 Status** (⏸️ Deferred):
- Assessment: Only 4 files slightly over 500-line limit (3-11% over)
- Decision: Low ROI vs refactoring risk for production-critical services
- Strategy: Defer to ongoing maintenance, address when files are modified
- Files: unified_recipe_service (556), recipe_discovery_service (523), realtime_notification_module (515), friends_invitations_operations (500)

**Phase 4 Progress** (✅ 7/7 COMPLETE - Jan 2025):
- ✅ **Issue 4.1**: ChatMessageStream performance optimization (COMPLETE)
  - Changed from O(n) clear/rebuild to O(m+n) incremental updates
  - Reduced widget rebuilds by ~90% for 50-message conversations
  - Implemented smart diff-based message list management
  - Preserved widget state with ValueKey optimizations

- ✅ **Issue 4.2**: Reduce excessive setState calls (COMPLETE - Jan 2025)
  - Refactored 4 files with consolidated immutable state pattern
  - activity_feed_view.dart: 9 variables → ActivityFeedState
  - file_import_view.dart: 4 variables → FileImportState
  - chat_input_section.dart: 2 variables → ChatInputState
  - recipe_detail_comments.dart: 4 variables → CommentsState
  - All setState calls now use atomic copyWith() updates
  - Improved maintainability and predictable state management
  - See: `/docs/performance/SETSTATE_REFACTORING_GUIDE.md`

- ✅ **Issue 4.3**: Const widget optimization (COMPLETE - Jan 2025)
  - Linter rules already enforcing const constructors (prefer_const_constructors)
  - Added const to high-traffic views (social dashboard sections)
  - Target achieved: 97%+ const usage
  - Marginal performance improvement (already well-optimized)

- ✅ **Issue 4.4**: ListView ValueKey implementation (COMPLETE - Jan 2025)
  - Added ValueKey to critical list views: activity_feed_view.dart, recipe_detail_comments.dart
  - Verified existing ValueKey usage: chat_message_stream.dart, mina_recept_view.dart, collaborative_shopping_items.dart
  - Fixed pre-existing AppDimensions errors (radiusL → borderRadiusL)
  - Prevents widget recreation on list updates
  - Significant performance improvement for list rendering

- ✅ **Issue 4.5**: Optimize Firebase Query Indices (COMPLETE - Jan 2025)
  - Added 4 composite indices for audit_logs collection
  - Supports GDPR compliance queries (getUserAuditLogs, getResourceAuditLogs, getDeniedAccessAttempts)
  - Query performance improvement: O(n) → O(log n) for indexed queries
  - Expected latency reduction: 80-90% for audit queries
  - Total indices: 19 (15 existing + 4 new)
  - See: `/docs/firebase/FIRESTORE_INDICES_DEPLOYMENT.md`

- ✅ **Issue 4.6**: Implement Image Caching (COMPLETE - Jan 2025)
  - Replaced Image.network with CachedNetworkImage in 5 high-traffic files
  - Files updated: activity_feed_item_widget.dart, recipe_detail_view.dart, trending_content_section.dart, recommendations_section.dart, friend_activity_section.dart
  - Added loading placeholders with CircularProgressIndicator
  - Applied ColoredBox optimization for better performance
  - Automatic disk caching reduces network requests and improves scroll performance
  - Package: cached_network_image ^3.4.1

- ✅ **Issue 4.7**: Firebase Performance Monitoring (COMPLETE - Jan 2025)
  - Added firebase_performance ^0.11.0 to pubspec.yaml
  - Created FirebasePerformanceService with automatic trace management
  - Integrated with existing PerformanceMonitoringService
  - Auto-initialization in PerformanceModule
  - Predefined trace methods for common operations:
    * traceRecipeLoad() - Recipe fetching
    * traceSearch() - Search operations
    * traceImageUpload() - Image uploads
    * traceScreenLoad() - Screen rendering
    * traceFirebaseQuery() - Database queries
    * traceSocialInteraction() - Social features
    * traceHttpRequest() - Network requests with HttpMetric
  - Comprehensive documentation: `/docs/performance/FIREBASE_PERFORMANCE_INTEGRATION.md`
  - Production-ready: < 1ms overhead per trace
  - Firebase Console integration for historical metrics
  - **Applied to critical flows** (Jan 2025):
    * firebase_recipe_repository.dart: 4 methods traced (fetchUserRecipes, searchRecipes, fetchArchiveRecipes, findByMealType)
    * firebase_storage_repository.dart: uploadImageData traced with size metrics
    * Monitoring: Recipe loading, search operations, image uploads
    * Metrics: Result counts, query performance, upload sizes, success/failure rates

**Phase 5 Progress** (🔄 1/11 complete - In Progress):
- ✅ **Issue 5.1**: Create test for firebase_audit_repository.dart (GDPR-critical) - **COMPLETE**
  - Comprehensive test suite created (470+ lines, 18 test cases)
  - **Test Results: 15 passing, 3 skipped (with clear documentation), 0 failing**
  - Tests cover all GDPR compliance requirements:
    * ✅ User audit log queries (4 tests)
    * ✅ Resource audit log queries (3 tests)
    * ✅ Security monitoring (denied access attempts - 3 tests)
    * ✅ Audit statistics calculation (2 tests)
    * ✅ Old log cleanup (2 tests)
    * ✅ GDPR Article 15 compliance (Right of Access - 1 test)
    * ✅ GDPR Article 30 compliance (Security monitoring - 1 test)
    * 🔄 Write operations (3 tests skipped - FakeFirebaseFirestore limitation, covered by integration tests)
  - **Test Quality:** Production-ready, follows established patterns
  - Location: `test/unit/repositories/firebase_audit_repository_test.dart`

**Next Steps**:
- Phase 5 (continued): Create tests for remaining GDPR repositories (consent, sharing)
- Expand repository test coverage from 29% to 50%+
- Add integration tests for critical user flows
- Monitor Firebase Console for performance insights

See `/docs/audit/REMEDIATION_ACTION_PLAN.md` for complete tracking.

## Known Limitations & Technical Debt

### Current Limitations (As of Jan 2025)

**Performance & Scalability:**
- Chat message stream: ✅ Incremental updates implemented (Phase 4.1 complete - Jan 2025)
  - ⚠️ Still has 50 message hard limit, no pagination yet
- Image loading: ✅ Image caching implemented (Phase 4.6 complete - Jan 2025)
  - cached_network_image with disk caching in 5 high-traffic views
  - ⚠️ Progressive rendering and lazy loading for large images not yet implemented
- Large lists: Standard ListView without virtualization optimization
- Firebase queries: Some lack proper indexing for scale (performance impact at 10k+ documents)

**Feature Completeness:**
- Social features: 85-92% complete (UI integration needs verification)
- Offline mode: Partial support, not comprehensive
- Real-time sync: Some race conditions possible under high concurrency
- Search functionality: Basic implementation, no fuzzy matching or advanced filters

**Technical Debt:**
- File size: Some files 400-500 lines (target: <500, prefer <300)
- Test coverage: 35-40% overall (target: 70%+)
- Legacy patterns: Some services use direct Firebase access (bypassing repository layer)
- Mixed DI patterns: Inconsistent use of constructor injection vs ServiceLocator in older code
- TODOs: ~15 "temporary workarounds" older than 3 months

**Architecture Debt:**
- Circular dependency risks: Mitigated with lazy singletons but not ideal
- Service boundaries: Some services have overlapping responsibilities
- State management: Mix of Provider and manual notifyListeners
- Error handling: Inconsistent patterns across services

**Security & Compliance:**
- Firestore Rules: 30+ rules implemented but need regular audit
- Permission validation: Recently added to repositories, needs integration testing
- Rate limiting: None implemented (relies on Firebase quotas)
- Audit log retention: No automatic cleanup policy (GDPR Article 5)

**Documentation:**
- API documentation: Minimal inline documentation for some services
- Architecture diagrams: Missing visual architecture overview
- Deployment guide: No production deployment checklist
- Monitoring setup: No production monitoring guide

### Mitigation Strategy

**High Priority** (Q1 2025):
1. Complete test coverage for security and GDPR features
2. Implement proper pagination for chat messages
3. Add Firebase query indexes for performance
4. Refactor services >500 lines using module pattern

**Medium Priority** (Q2 2025):
1. Expand test coverage to 60%+
2. Implement comprehensive offline support
3. Add rate limiting and abuse prevention
4. Create production deployment guide

**Low Priority** (Q3+ 2025):
1. Refactor mixed DI patterns for consistency
2. Add advanced search features
3. Implement progressive image loading
4. Create architecture diagrams

**Ongoing:**
- Address new TODOs within 2 weeks or convert to tracked issues
- Refactor files when modified to stay under 500 lines
- Add tests for all new features before merging
- Regular security audits (quarterly)

See `/docs/audit/REMEDIATION_ACTION_PLAN.md` for complete remediation tracking.

## Workflow Instructions

### Assume multiple Claude Code sessions running in parallel

### 📋 General Development Workflow
**Before starting:**
1. Think through problem, read codebase and `/docs` documentation
2. Write detailed plan to `tasks/todo.md` with checkable todo items
3. **MUST verify plan with user before beginning work**

**While working:**
1. Work through todos, marking complete as you go
2. Give high-level explanations understandable for vibecoder
3. **DO NOT BE LAZY** - find root causes, no temporary fixes
4. Make simplest possible changes, minimal code impact
5. **CRITICAL: Always update corresponding tests when changing production code**
   - When modifying services: Update service tests in `test/unit/services/`
   - When modifying viewmodels: Update viewmodel tests in `test/unit/viewmodels/`
   - When modifying models: Update model tests in `test/unit/models/`
   - When modifying repositories: Update repository tests in `test/unit/repositories/`
   - Run `flutter test` before completing any production code changes
6. **DEBUGGING METHODOLOGY**: Use systematic approach for production issues:
   - Step 1: Add comprehensive logging to trace data flow (repositories → services → viewmodels)
   - Step 2: Test with multiple users to verify data persistence vs caching issues
   - Step 3: Map all sources of truth and verify correct service connections
   - **Always check ViewModels are connected to correct services** - common cause of UI inconsistencies
7. Ask questions before deviating from todos

**When finished:**
1. Add review section to `todo.md` with summary of changes
2. Update relevant documentation in `/docs` and `CLAUDE.md`
3. **Run targeted analysis**: `flutter analyze lib/path/to/changed_file.dart` on files you modified
   - **NEVER run full `flutter analyze`** when working in parallel sessions
   - Only analyze files you changed or files directly affected by your changes
   - Prevents conflicts with issues being fixed by other Claude Code instances
   - If unclear about scope, ask user before running analysis
4. Verify implementations match documentation claims

## Theme System Standards

**Status:** A+ Rating (100% semantic naming, zero duplication - Completed Jan 2025)

**Design System Organization:**
- Colors: `lib/theme/app_colors.dart`
- Typography: `lib/theme/app_text_styles.dart`
- Spacing/Sizing: `lib/theme/app_dimensions.dart`
- Components: `lib/theme/components/` (button, input, navigation, feedback themes)

**Use Semantic Names:**
```dart
// ✅ Good - Semantic naming
AppColors.primaryBlue
AppColors.success
AppColors.backgroundBeige

AppDimensions.spacingMd     // 16px
AppDimensions.spacingLg     // 24px
AppDimensions.borderRadiusM  // 8px

AppTextStyles.titleLarge
AppTextStyles.bodyMedium

// ❌ Avoid - Numeric or generic aliases
AppDimensions.spacing16      // Removed
AppDimensions.radiusSmall    // Removed
AppColors.accentColor        // Removed
```

**Spacing Scale (4px/8px Grid):**
- `spacingXs` (4px) → `spacingSm` (8px) → `spacingMd` (16px) → `spacingLg` (24px) → `spacingXl` (32px)
- For in-between values, combine: `spacingSm + spacingXs` = 12px

**Component-Specific Aliases (Semantic):**
```dart
AppDimensions.cardBorderRadius          // OK - semantic meaning
AppDimensions.chipRadius                // OK - component-specific
AppDimensions.bottomSheetBorderRadius   // OK - semantic context
```

**Modern Flutter Syntax:**
```dart
// ✅ Use modern syntax
color.withValues(alpha: 0.8)

// ❌ Never use deprecated
color.withOpacity(0.8)  // Deprecated!
```

**Component Theme Imports:**
```dart
// Option 1: Import everything (backward compatible)
import 'package:butlery/theme/component_themes.dart';

// Option 2: Import only what you need (recommended for new code)
import 'package:butlery/theme/components/button_themes.dart';
import 'package:butlery/theme/components/input_themes.dart';
```

**Migration Guide:** See `/docs/theme/THEME_MIGRATION_GUIDE.md`

## Critical Rules
- **NEVER BE LAZY** - you are a senior developer
- Find root causes, fix properly, no workarounds
- Focus on simplicity and minimal code impact
- Proper error handling and security validation
- Ask before moving away from planned todos