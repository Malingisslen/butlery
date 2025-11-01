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
  - **Current Status**: 48 files >500 lines (verified Jan 2025)
  - **Acceptable Exceptions**: 18-20 well-architected facades using proper modularization
    - ✅ **Exemplary Pattern**: `recipe_form_viewmodel.dart` (905 lines) - facade with 6 focused managers
    - ✅ **Accepted**: Extracted modules like `recipe_image_manager.dart`, separate widgets like `editable_image_widget.dart`
    - ✅ **Facade Pattern Celebrated**: Large files with clear module extraction and single responsibility are acceptable
  - **True Violations**: 20-30 files requiring refactoring (monolithic files without modularization)
  - **Refactoring Strategy**: Extract modules for monolithic >500 line files (see unified services pattern)
  - **Priority**: New code must follow 500-line limit OR use facade pattern; legacy monoliths refactored as touched
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

### Code Deduplication Infrastructure
**Status:** Comprehensive infrastructure in place (Jan 2025)
**Impact:** 3,000-4,000 lines of duplication eliminated
**Adoption:** Partial (21-46% - varies by component, needs expansion)
**Documentation:** See `/docs/architecture/DEDUPLICATION_PATTERNS.md`

**Available Infrastructure:**

1. **ErrorHandlingMixin** (`lib/core/mixins/error_handling_mixin.dart`)
   - 669 lines eliminating 1,100-1,400 lines of duplicate error handling
   - Comprehensive async/sync error handling patterns
   - Network operations with retry logic (max 3 retries)
   - CRUD operation wrappers (safeCreate, safeUpdate, safeDelete, safeLoad)
   - Batch operations with continue-on-error support
   - Error classification (DNS, network, auth, 404, 503)
   - Usage: `with ErrorHandlingMixin` or extend `BaseService`

2. **AsyncOperationMixin** (`lib/core/mixins/async_operation_mixin.dart`)
   - 458 lines of infrastructure eliminating ~250-280 lines of boilerplate
   - **Initiative Status**: ✅ COMPLETE (Jan 2025)
   - **Adoption**: 80-100% of viable candidates (12-15 of 97 ViewModels migrated)
   - **Key Learning**: Only 12-15 of 97 ViewModels benefit from migration; many have well-architected custom state management that should not be replaced
   - Automatic loading/error/success states for ViewModels
   - Named operations preventing duplicate concurrent executions
   - Debouncing & throttling for search/input operations
   - Caching with automatic expiry
   - Batch and sequential operation execution
   - Usage: `with StateNotifierMixin, AsyncOperationMixin` in ViewModels
   - **Migration Patterns**: Full migration (2), Partial migration (10), Deferred (well-architected custom state)
   - **Documentation**: See `/ASYNCOPERATION_FINAL_REPORT.md` and `/docs/architecture/WEEK3_MIGRATION_SUCCESS.md`

3. **BaseService** (`lib/core/base/base_service.dart`)
   - 495 lines of infrastructure eliminating ~500-600 lines of boilerplate
   - **Initiative Status**: ⚠️ IN PROGRESS (Jan 2025)
   - **Adoption**: 21% (39/186 services)
   - **Opportunity**: 147 services could benefit from BaseService adoption
   - **Key Learning**: Only instance-based services benefit; ChangeNotifier services (9) and static utilities (2) intentionally use different patterns
   - Includes ErrorHandlingMixin automatically
   - Pre-flight checks (auth, network, permissions)
   - Built-in caching with expiry management
   - Batch operations and lifecycle hooks (onInitialize, onDispose)
   - **Recent Migrations** (Jan 2025): PermissionService, PerformanceMonitoringService, ImageUploadService, RecipeDiscoveryService
   - Usage: `extends BaseService` for all new instance-based services

4. **BaseFirebaseRepository** (`lib/repositories/base/`)
   - ~400 lines eliminating 2,000-2,500 lines of CRUD duplication
   - Standard CRUD operations with permission validation
   - Audit logging (GDPR Article 30 compliance)
   - Streaming support with real-time updates
   - **Adoption**: 46.6% (27/58 repositories)
   - **Opportunity**: 31 repositories could benefit from BaseFirebaseRepository
   - Usage: `extends BaseFirebaseRepository<T>` (standard pattern)

5. **SerializationUtils** (`lib/core/utils/serialization_utils.dart`)
   - 371 lines eliminating 600-800 lines of manual parsing
   - Safe data extraction with null handling and type conversion
   - Firebase Timestamp handling (DateTime, String, int, Timestamp)
   - Nested object and list parsing with converters
   - Enum serialization/deserialization
   - **Current Adoption: 0% - High opportunity!**
   - Usage: `SerializationUtils.safeString(data, 'field')` or extension methods

6. **ValidationUtils** (`lib/core/utils/validation_utils.dart`)
   - 384 lines eliminating 1,600-2,400 lines of validation code
   - Null/empty/whitespace validation for strings, lists, maps
   - String length and format validation (email, etc.)
   - Business rule validation (recipe names, amounts, etc.)
   - Collection helpers (hasItems, safeCount, safeList)
   - Extension methods for cleaner syntax
   - Usage: `ValidationUtils.validateRequired(value)` or `value.isNullOrEmpty`

7. **Default Value Extensions** (`lib/core/extensions/default_value_extensions.dart`)
   - ~350 lines eliminating 400+ lines of null coalescing
   - String, List, Map, DateTime, Int, Double, Bool extensions
   - Clean null-safe default values: `.orEmpty()`, `.orZero()`, `.orNow()`
   - Null checking helpers: `.isNullOrEmpty`, `.hasValue`, `.hasItems`
   - **Current Adoption: 0% (newly created)**
   - Usage: Replace `value ?? default` with `value.orDefault()`

8. **Test Helpers** (`test/helpers/`)
   - RepositoryTestBase: Common repository test setup (FakeFirestore, mocks)
   - ServiceTestBase: Common service test setup (auth, utilities)
   - TestDataFactory: Consistent test data generation
   - **Current Adoption: 0% (newly created)**
   - Usage: `extends RepositoryTestBase` in repository tests

**Adoption Guidelines:**

**Immediate Use (All New Code):**
- ✅ Extension methods for null coalescing
- ✅ ValidationUtils for form validation
- ✅ BaseFirebaseRepository for new repositories
- ✅ SerializationUtils for Firestore parsing
- ✅ Test helpers for new tests
- ✅ AsyncOperationMixin for new ViewModels with simple loading/error patterns

**High Priority (When Touching Existing Code):**
- ⚠️ BaseService for services without it
- ⚠️ ErrorHandlingMixin for classes with try-catch blocks

**Opportunistic (AsyncOperationMixin - Initiative Complete):**
- ✅ Apply to ViewModels when refactoring IF they have simple loading/error patterns
- ✅ Use decision framework: Full migration vs. Partial migration vs. Defer
- ✅ Respect well-architected custom state management (streams, manager patterns)
- ✅ See `/ASYNCOPERATION_FINAL_REPORT.md` for migration guidelines

**Examples:**

```dart
// Service with ErrorHandlingMixin (via BaseService)
class RecipeService extends BaseService {
  @override
  String get serviceName => 'RecipeService';

  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(
      () => _repository.getById(id),
      operationName: 'Get recipe',
    );
  }
}

// ViewModel with AsyncOperationMixin
class RecipeViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {

  Future<void> loadRecipes() async {
    await executeAsync(() async {
      _recipes = await _service.fetchRecipes();
    });
  }
  // isLoading, hasError, errorMessage provided automatically
}

// Model with SerializationUtils
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Recipe(
    title: SerializationUtils.safeString(data, 'title'),
    portions: SerializationUtils.safeInt(data, 'portions', defaultValue: 4),
    createdAt: SerializationUtils.safeDateTime(data, 'createdAt') ?? DateTime.now(),
    ingredients: SerializationUtils.safeStringList(data, 'ingredients'),
  );
}

// Using extension methods
final name = recipe.title.orEmpty(); // Instead of: recipe.title ?? ''
final items = cart.items.orEmpty(); // Instead of: cart.items ?? []
if (ingredients.hasItems) { /* ... */ } // Instead of: ingredients != null && ingredients.isNotEmpty
```

**See Also:**
- Comprehensive documentation: `/docs/architecture/DEDUPLICATION_PATTERNS.md`
- Usage examples and migration guides in documentation
- Test patterns: `/docs/testing/TEST_PATTERNS_QUICK_REFERENCE.md`

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
  - ✅ **Exception**: Accessing via repository getter is acceptable: `_firestoreRepository.firestore`
    - Repository is injected via constructor (✅ follows pattern)
    - Access controlled through repository layer (✅ maintains architecture)
    - Example: AccountDeletionService, DataExportService use this pattern correctly

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

## Critical Rules
- **NEVER BE LAZY** - you are a senior developer
- Find root causes, fix properly, no workarounds
- Focus on simplicity and minimal code impact
- Proper error handling and security validation
- Ask before moving away from planned todos