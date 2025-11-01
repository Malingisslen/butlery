# Code Deduplication Patterns - Butlery Application

**Status**: Comprehensive infrastructure in place (Jan 2025)
**Impact**: 3,000-4,000 lines of duplication already eliminated
**Adoption**: Partial (20-30% of codebase actively using patterns)

---

## Executive Summary

The Butlery codebase has **excellent deduplication infrastructure** already implemented, including:

- ✅ **ErrorHandlingMixin** (669 lines) - Comprehensive error handling patterns
- ✅ **AsyncOperationMixin** (458 lines) - Loading states, debouncing, caching
- ✅ **BaseService** (495 lines) - Service layer standardization
- ✅ **BaseFirebaseRepository** - Repository CRUD standardization
- ✅ **SerializationUtils** (371 lines) - Safe data transformation
- ✅ **ValidationUtils** (384 lines) - Validation pattern consolidation
- ✅ **Default Value Extensions** (350 lines) - Null-safe default values

**Challenge**: These patterns exist but are **underutilized** (20-30% adoption). This document provides guidance on using existing patterns rather than creating new ones.

---

## Table of Contents

1. [Error Handling Patterns](#error-handling-patterns)
2. [Async Operation Patterns](#async-operation-patterns)
3. [Service Layer Patterns](#service-layer-patterns)
4. [Repository Layer Patterns](#repository-layer-patterns)
5. [Serialization Patterns](#serialization-patterns)
6. [Validation Patterns](#validation-patterns)
7. [Extension Methods](#extension-methods)
8. [Model Patterns](#model-patterns)
9. [Test Patterns](#test-patterns)
10. [Adoption Guidelines](#adoption-guidelines)

---

## 1. Error Handling Patterns

### Location: `lib/core/mixins/error_handling_mixin.dart`

**Lines of Code**: 669 lines
**Eliminates**: 1,100-1,400 lines of duplicate error handling
**Current Adoption**: ~15% (needs expansion)

### Pattern Overview

The `ErrorHandlingMixin` provides comprehensive error handling for any class:

```dart
// Instead of manual try-catch everywhere:
try {
  final result = await operation();
  return result;
} catch (e, stackTrace) {
  AppLogger.error('Operation failed: $e', stackTrace);
  throw Exception('Operation failed: $e');
}

// Use ErrorHandlingMixin:
class MyService with ErrorHandlingMixin {
  Future<Recipe?> fetchRecipe(String id) async {
    return await safeExecute(
      () => _repository.fetchRecipe(id),
      operationName: 'Fetch recipe',
      defaultValue: null,
    );
  }
}
```

### Available Methods

#### Basic Operations
- `safeExecute<T>()` - Async operations with error handling
- `safeExecuteSync<T>()` - Sync operations with error handling

#### CRUD Operations
- `safeCreate<T>()` - Create operations with user-friendly errors
- `safeUpdate<T>()` - Update operations
- `safeDelete()` - Delete operations with boolean return
- `safeLoad<T>()` - Load/fetch operations

#### List Operations
- `safeLoadList<T>()` - List loading with empty list default
- `safeLoadListWithEmptyCheck<T>()` - With empty state handling

#### Network Operations
- `safeNetworkOperation<T>()` - With retry logic (max 3 retries)
- Network error detection and user messaging

#### Permission Operations
- `safePermissionOperation<T>()` - Permission-aware operations
- `safeValidatedOperation<T>()` - With validation checks

#### Batch Operations
- `safeBatchOperation<T>()` - Multiple operations with continue-on-error
- `operationWithFallback<T>()` - Primary + fallback operations
- `retryOperation<T>()` - Exponential backoff retries

#### Error Classification
- `classifyError()` - DNS, network, auth, 404, 503 errors
- `isRecoverableError()` - Determines retry feasibility
- `isDNSResolutionError()` - Specific DNS error detection
- `extractUserMessage()` - User-friendly error messages

### Usage Examples

#### Simple Service Operation
```dart
class RecipeService with ErrorHandlingMixin {
  Future<List<Recipe>> fetchUserRecipes(String userId) async {
    return await safeLoadList(
      () => _repository.fetchUserRecipes(userId),
      'recipes',
    );
  }
}
```

#### With Custom Error Messages
```dart
Future<Recipe?> createRecipe(Recipe recipe) async {
  return await safeCreate(
    () => _repository.create(recipe),
    'recipe',
  ); // Automatic error message: "Kunde inte skapa recipe"
}
```

#### Network Operation with Retries
```dart
Future<List<Recipe>> searchRecipes(String query) async {
  return await safeNetworkOperation(
    () => _api.searchRecipes(query),
    operationName: 'Search recipes',
    defaultValue: [],
    maxRetries: 3,
  );
}
```

#### Batch Operations
```dart
Future<List<Recipe>> importMultipleRecipes(List<Recipe> recipes) async {
  final operations = recipes.map((r) => () => _repository.create(r)).toList();

  return await safeBatchOperation(
    operations,
    'Import recipes',
    continueOnError: true, // Continue importing even if some fail
  );
}
```

### Integration with BaseService

`BaseService` automatically includes `ErrorHandlingMixin`:

```dart
abstract class BaseService with ErrorHandlingMixin {
  // executeServiceOperation() uses safeExecute() internally
  Future<T?> executeServiceOperation<T>(
    Future<T> Function() operation, {
    String? operationName,
    T? defaultValue,
    bool requiresAuth = true,
  }) async {
    // Pre-flight auth checks...
    return await safeExecute(operation, operationName: operationName);
  }
}
```

### When to Use

✅ **Use ErrorHandlingMixin when:**
- Creating new services
- Refactoring services with repetitive try-catch blocks
- Need consistent error logging and user messaging
- Need network retry logic or fallback strategies

❌ **Don't use when:**
- Service already extends BaseService (you get it automatically)
- Errors need special handling beyond logging
- You need to expose errors to the caller for decision-making

---

## 2. Async Operation Patterns

### Location: `lib/core/mixins/async_operation_mixin.dart`

**Lines of Code**: 458 lines
**Eliminates**: 800-1,000 lines of loading state management
**Current Adoption**: ~5% (used in 2 base ViewModels only)

### Pattern Overview

`AsyncOperationMixin` provides comprehensive async operation management for ViewModels:

```dart
// Instead of manual loading state management:
class MyViewModel extends ChangeNotifier {
  bool _isLoading = false;
  bool get isLoading => _isLoading;

  Future<void> loadData() async {
    if (_isLoading) return;
    _isLoading = true;
    notifyListeners();

    try {
      _data = await _service.fetchData();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// Use AsyncOperationMixin:
class MyViewModel extends ChangeNotifier with StateNotifierMixin, AsyncOperationMixin {
  Future<void> loadData() async {
    await executeAsync(() async {
      _data = await _service.fetchData();
    });
  }
}
```

### Available Methods

#### Basic Operations
- `executeAsync<T>()` - Basic async with loading/error states
- `executeNamedOperation<T>()` - Named operations (prevents duplicates)
- `executeCachedOperation<T>()` - With automatic caching

#### Concurrency Control
- `executeNamedOperation()` with `allowConcurrent: false` - Prevents duplicate ops
- `isOperationActive()` - Check if operation is running
- `cancelOperation()` - Cancel specific operation
- `cancelAllOperations()` - Cancel all operations

#### Debouncing & Throttling
- `executeDebounced<T>()` - Delays execution until calls stop (search)
- `executeThrottled<T>()` - Limits execution frequency

#### Batch Operations
- `executeBatch<T>()` - Parallel execution of multiple operations
- `executeSequence<T>()` - Sequential execution

#### Background Operations
- `executeInBackground<T>()` - No loading state changes
- Custom success/error callbacks

### Usage Examples

#### Basic ViewModel with Loading States
```dart
class RecipeListViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {

  List<Recipe> _recipes = [];
  List<Recipe> get recipes => _recipes;

  Future<void> loadRecipes() async {
    await executeAsync(() async {
      _recipes = await _recipeService.fetchUserRecipes();
    });
  }

  // Automatic loading state: isLoading
  // Automatic error state: hasError, errorMessage
  // Automatic success state: isSuccess
}
```

#### Debounced Search
```dart
class SearchViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {

  Future<void> search(String query) async {
    await executeDebounced(
      'search',
      () async {
        _results = await _searchService.search(query);
      },
      Duration(milliseconds: 500),
    );
  }
}
```

#### Cached Operation
```dart
Future<void> loadUserProfile() async {
  await executeCachedOperation(
    'user_profile',
    () async {
      _profile = await _userService.getUserProfile();
    },
    cacheExpiry: Duration(minutes: 5),
  );
}
```

#### Prevent Duplicate Operations
```dart
Future<void> saveRecipe() async {
  await executeNamedOperation(
    'save_recipe',
    () async {
      await _recipeService.saveRecipe(_currentRecipe);
    },
    allowConcurrent: false, // Prevents multiple simultaneous saves
  );
}
```

#### Batch Parallel Operations
```dart
Future<void> loadDashboardData() async {
  await executeBatch({
    'recipes': () async => _recipeService.fetchRecent(),
    'friends': () async => _friendsService.fetchOnline(),
    'activity': () async => _activityService.fetchRecent(),
  });
}
```

### State Access

```dart
// In your UI:
if (viewModel.isLoading) {
  return CircularProgressIndicator();
}

if (viewModel.hasError) {
  return ErrorWidget(viewModel.errorMessage);
}

// Check specific operations:
if (viewModel.isOperationActive('save_recipe')) {
  // Show save indicator
}
```

### When to Use

✅ **Use AsyncOperationMixin when:**
- Building ViewModels with async operations
- Need automatic loading/error state management
- Need to prevent duplicate concurrent operations
- Implementing search with debouncing
- Need operation caching

❌ **Don't use when:**
- Simple synchronous ViewModels
- Need custom loading state logic beyond boolean flags
- Building services (use ErrorHandlingMixin instead)

---

## 3. Service Layer Patterns

### Location: `lib/core/base/base_service.dart`

**Lines of Code**: 495 lines
**Eliminates**: 1,500-2,000 lines of service boilerplate
**Current Adoption**: ~40% (storage, messaging, recommendation services)

### Pattern Overview

`BaseService` provides standardized service layer patterns:

```dart
abstract class BaseService with ErrorHandlingMixin {
  String get serviceName; // For logging

  // Lifecycle hooks
  Future<void> onInitialize() async {}
  Future<void> onDispose() async {}

  // Service operations with pre-flight checks
  Future<T?> executeServiceOperation<T>(
    Future<T> Function() operation, {
    bool requiresAuth = true,
    bool requiresNetwork = false,
    bool requiresPermission = false,
  });

  // Caching, batch operations, validation patterns...
}
```

### Features

#### Automatic Error Handling
- Integrates `ErrorHandlingMixin` automatically
- `executeServiceOperation()` wraps all operations

#### Pre-Flight Checks
- Authentication validation (`requiresAuth`)
- Network connectivity (`requiresNetwork`)
- Permission checking (`requiresPermission`)

#### Built-in Caching
- `getCachedOrExecute<T>()` - Cache with expiry
- `clearCache()` / `clearAllCache()`
- Automatic cache timestamp management

#### Batch Operations
- `executeBatchOperation<T>()` - Multiple operations
- `continueOnError` support

#### Lifecycle Management
- `initialize()` / `dispose()` with logging
- `onInitialize()` / `onDispose()` hooks

### Usage Examples

#### Basic Service
```dart
class RecipeService extends BaseService {
  final RecipeRepository _repository;

  RecipeService(this._repository);

  @override
  String get serviceName => 'RecipeService';

  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(
      () => _repository.getById(id),
      operationName: 'Get recipe',
      requiresAuth: true,
    );
  }
}
```

#### With Caching
```dart
Future<List<Recipe>> getTrendingRecipes() async {
  return await getCachedOrExecute(
    'trending_recipes',
    () async => _repository.fetchTrending(),
    cacheDuration: Duration(hours: 1),
  ) ?? [];
}
```

#### With Batch Operations
```dart
Future<List<Recipe>> importRecipes(List<Recipe> recipes) async {
  final operations = recipes
      .map((r) => () => _repository.create(r))
      .toList();

  return await executeBatchOperation(
    operations,
    'Import recipes',
    continueOnError: true,
  );
}
```

#### With Lifecycle
```dart
@override
Future<void> onInitialize() async {
  // Load cached data
  _cachedRecipes = await _loadFromCache();

  // Setup streams
  _subscription = _repository.watchRecipes().listen(_onRecipeChange);
}

@override
Future<void> onDispose() async {
  await _subscription?.cancel();
  await _saveToCache();
}
```

### Mixins for BaseService

#### UserContextMixin
```dart
class UserRecipeService extends BaseService with UserContextMixin {
  Future<List<Recipe>> getMyRecipes() async {
    return await executeAsUser((userId) async {
      return _repository.fetchUserRecipes(userId);
    });
  }
}
```

#### NotificationMixin
```dart
class SocialService extends BaseService with NotificationMixin {
  Future<void> shareRecipe(Recipe recipe) async {
    await _shareRepository.share(recipe);
    await notifySuccess('Recipe shared successfully!');
  }
}
```

### When to Use

✅ **Use BaseService when:**
- Creating new services
- Service needs auth/network/permission checks
- Need built-in caching
- Want standardized logging and lifecycle

❌ **Don't use when:**
- Building ViewModels (use AsyncOperationMixin)
- Service is just a thin wrapper (direct repository access ok)
- Need to extend another base class

---

## 4. Repository Layer Patterns

### Location: `lib/repositories/base/base_firebase_repository.dart`

**Lines of Code**: ~400 lines
**Eliminates**: 2,000-2,500 lines of CRUD duplication
**Current Adoption**: 90%+ (27 repositories)

### Pattern Overview

```dart
abstract class BaseFirebaseRepository<T>
    with PermissionValidationMixin, FirebaseAuditMixin {

  // Collection reference
  CollectionReference getCollectionRef();

  // Model conversion
  T fromFirestore(DocumentSnapshot doc);
  Map<String, dynamic> toFirestore(T entity);

  // CRUD operations (implemented by base class)
  Future<T?> getById(String id);
  Future<List<T>> getAll();
  Future<T> create(T entity);
  Future<void> update(String id, T entity);
  Future<void> delete(String id);

  // Streaming
  Stream<T?> watchById(String id);
  Stream<List<T>> watchAll();

  // Permission validation (implement in subclass)
  Future<void> validateCreatePermission(String userId, T entity);
  Future<void> validateReadPermission(String userId, String resourceId, T? entity);
  Future<void> validateUpdatePermission(String userId, String resourceId, T entity);
  Future<void> validateDeletePermission(String userId, String resourceId);
}
```

### Usage Example

```dart
class RecipeRepository extends BaseFirebaseRepository<Recipe> {
  @override
  CollectionReference getCollectionRef() => firestore.collection('recipes');

  @override
  Recipe fromFirestore(DocumentSnapshot doc) {
    return Recipe.fromFirestore(doc);
  }

  @override
  Map<String, dynamic> toFirestore(Recipe recipe) {
    return recipe.toFirestore();
  }

  @override
  Future<void> validateCreatePermission(String userId, Recipe recipe) async {
    // Must be authenticated
    if (userId.isEmpty) {
      throw PermissionDeniedException('Must be authenticated');
    }
  }

  @override
  Future<void> validateReadPermission(String userId, String recipeId, Recipe? recipe) async {
    // Public read or owner
    if (recipe != null && recipe.isPublic) return;
    if (recipe != null && recipe.ownerId == userId) return;
    throw PermissionDeniedException('Cannot read this recipe');
  }

  // ... other permission methods
}
```

### Features

- ✅ CRUD operations implemented
- ✅ Permission validation integration
- ✅ Audit logging (GDPR Article 30)
- ✅ Streaming support
- ✅ Error handling with retry logic
- ✅ Timestamp management

### When to Use

✅ **Always use** for Firebase repositories - it's the standard pattern

---

## 5. Serialization Patterns

### Location: `lib/core/utils/serialization_utils.dart`

**Lines of Code**: 371 lines
**Eliminates**: 600-800 lines of manual parsing
**Current Adoption**: 0% (opportunity!)

### Pattern Overview

Safe data extraction from maps with null handling and type conversion:

```dart
// Instead of manual null checking:
final title = data['title'] as String? ?? '';
final portions = data['portions'] as int? ?? 1;
final timestamp = data['createdAt']; // Complex Firebase Timestamp handling

// Use SerializationUtils:
final title = SerializationUtils.safeString(data, 'title');
final portions = SerializationUtils.safeInt(data, 'portions', defaultValue: 1);
final createdAt = SerializationUtils.safeDateTime(data, 'createdAt');
```

### Available Methods

#### Basic Types
- `safeString()` / `safeNullableString()`
- `safeInt()` / `safeNullableInt()`
- `safeDouble()` / `safeNullableDouble()`
- `safeBool()` / `safeNullableBool()`

#### Date/Time
- `safeDateTime()` - Handles Firebase Timestamp, String, int
- `safeRequiredDateTime()` - With default
- `serializeDateTime()` - To ISO8601 string

#### Lists
- `safeList<T>()` - With converter function
- `safeStringList()` - Strings specifically
- `safeObjectList<T>()` - Object lists with fromJson

#### Maps
- `safeMap()` - Safe map extraction
- `safeNullableMap()`

#### Nested Objects
- `safeNestedObject<T>()` - With fromJson converter
- `serializeNestedObject<T>()` - With toJson converter

#### Enums
- `safeEnum<T>()` - Enum parsing with default
- `serializeEnum<T>()` - Enum to string

#### Validation
- `hasRequiredFields()` - Check required fields exist
- `getMissingFields()` - List missing fields
- `cleanMap()` - Remove null values

### Usage Examples

#### Model Deserialization
```dart
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;

  return Recipe(
    id: doc.id,
    title: SerializationUtils.safeString(data, 'title'),
    portions: SerializationUtils.safeInt(data, 'portions', defaultValue: 4),
    rating: SerializationUtils.safeDouble(data, 'rating'),
    createdAt: SerializationUtils.safeDateTime(data, 'createdAt') ?? DateTime.now(),
    ingredients: SerializationUtils.safeStringList(data, 'ingredients'),
    tags: SerializationUtils.safeStringList(data, 'tags'),
  );
}
```

#### Nested Object Lists
```dart
final steps = SerializationUtils.safeObjectList<RecipeStep>(
  data,
  'steps',
  (json) => RecipeStep.fromJson(json),
  defaultValue: [],
);
```

#### Extension Methods
```dart
// Use extension methods for cleaner syntax:
final title = data.safeString('title');
final portions = data.safeInt('portions', defaultValue: 4);
final createdAt = data.safeDateTime('createdAt');
final ingredients = data.safeStringList('ingredients');
```

### When to Use

✅ **Use SerializationUtils when:**
- Parsing Firestore documents
- Parsing JSON from APIs
- Need Firebase Timestamp handling
- Want null-safe data extraction

❌ **Don't use when:**
- Using code generation (json_serializable)
- Data is already properly typed

---

## 6. Validation Patterns

### Location: `lib/core/utils/validation_utils.dart`

**Lines of Code**: 384 lines
**Eliminates**: 1,600-2,400 lines of validation code
**Current Adoption**: ~15% (9 files)

### Pattern Overview

Centralized validation with localized error messages:

```dart
// Instead of repetitive validation:
String? validateTitle(String? title) {
  if (title == null || title.isEmpty) {
    return 'Title is required';
  }
  if (title.length < 3 || title.length > 100) {
    return 'Title must be 3-100 characters';
  }
  return null;
}

// Use ValidationUtils:
String? validateTitle(String? title) {
  return ValidationUtils.validateRecipeName(title);
}
```

### Available Methods

#### Basic Validation
- `isNullOrEmpty()` - String null/empty check
- `isNullOrWhitespace()` - With whitespace check
- `isNullOrEmptyList<T>()` - List check
- `isNullOrEmptyMap<K,V>()` - Map check

#### String Validation
- `validateRequired()` - Required field with custom name
- `validateLength()` - Min/max length validation
- `validateEmail()` - Email format

#### Business Rules
- `validateRecipeName()` - 2-100 characters
- `validateGroupName()` - 2-50 characters
- `validateShoppingItemName()` - 1-100 characters
- `validateAmount()` - Positive number validation

#### Collection Helpers
- `hasItems<T>()` - List not null and not empty
- `safeCount<T>()` - List length or 0
- `safeList<T>()` - List or empty list

#### Permission Validation
- `validateUserId()` - User ID required
- `canAccess()` - Ownership validation

#### Composite Validation
- `validateMultiple()` - Multiple validators, collect errors
- `isFormValid()` - All validators pass

### Usage Examples

#### Form Field Validation
```dart
TextFormField(
  validator: (value) => ValidationUtils.validateRequired(value, fieldName: 'Recipe Title'),
);

TextFormField(
  validator: (value) => ValidationUtils.validateEmail(value),
);
```

#### Custom Validation
```dart
String? validateRecipeForm(RecipeFormData data) {
  if (ValidationUtils.isNullOrEmpty(data.title)) {
    return 'Title required';
  }
  if (ValidationUtils.isNullOrEmptyList(data.ingredients)) {
    return 'At least one ingredient required';
  }
  return null;
}
```

#### Extension Methods
```dart
// Use extension methods for cleaner syntax:
if (title.isNullOrEmpty) {
  return 'Title required';
}

if (ingredients.isNullOrEmpty) {
  return 'Ingredients required';
}

final name = userName.orEmpty(); // '' if null
```

### When to Use

✅ **Use ValidationUtils when:**
- Form validation
- Input sanitization
- Business rule validation
- Null-safe collection access

❌ **Don't use when:**
- Complex multi-field validation (create custom validators)
- Async validation (use separate async validator)

---

## 7. Extension Methods

### Location: `lib/core/extensions/default_value_extensions.dart`

**Lines of Code**: ~350 lines
**Eliminates**: 400+ lines of null coalescing
**Current Adoption**: Phase 1+2: 19-24% (201 migrations across 17 files, Nov 2025)

### Phase 1 Completion (Nov 2025)

**Status**: ✅ Complete
**Models Migrated**: 10 core models
**Total Migrations**: 129
**Lines Improved**: ~120-150 lines of verbose null coalescing eliminated

**Migrated Models**:
1. `recipe_unified.dart` - 11 migrations (RecipeCore, RecipeSocialData, RecipeRealtimeData)
2. `shared_shopping_list.dart` - 14 migrations (fromFirestore, fromMap, fromJson)
3. `activity_feed_item.dart` - 16 migrations (metadata access patterns, 4 reverted due to method chaining)
4. `unified_shopping_list.dart` - 8 migrations (collaborative features)
5. `shared_menu.dart` - 20 migrations (menu snapshot reconstruction)
6. `shared_content.dart` - 11 migrations (permissions, SharingPermissions)
7. `unified_shopping_item.dart` - 8 migrations (fromJson, fromFirestore)
8. `recipe_serialization.dart` - 16 migrations (sanitization, compression, import/export)
9. `user_profile.dart` - 12 migrations (social networking, notifications)
10. `realtime_invitation.dart` - 13 migrations (temporal management, _parseDateTime)

### Phase 2 Completion (Nov 2025)

**Status**: ✅ Complete (93.5% of phase target)
**ViewModels Migrated**: 7 critical ViewModels
**Total Migrations**: 72
**Lines Improved**: ~70-85 lines of verbose null coalescing eliminated

**Migrated ViewModels**:
1. `recipe_auto_save_manager.dart` - 16 migrations (draft loading, template validation, JSON parsing)
2. `group_content_viewmodel.dart` - 15 migrations (content conversion, metadata extraction, filtering)
3. `realtime_recipe_viewmodel.dart` - 11 migrations (collaborative editing, all `?? false` patterns)
4. `recipe_form_state.dart` - 10 migrations (form state management, draft serialization)
5. `recipe_query_viewmodel.dart` - 9 migrations (recipe filtering, analytics, aggregations)
6. `menu_storage.dart` - 6 migrations (local storage, menu persistence, JSON deserialization)
7. `unified_shopping_viewmodel.dart` - 5 migrations (shopping list analytics, completion tracking)

**Combined Phase 1+2 Results**:
- **Total Files**: 17 (10 models + 7 ViewModels)
- **Total Migrations**: 201 (129 Phase 1 + 72 Phase 2)
- **Total Lines Improved**: ~190-235 lines
- **Adoption Rate**: 19-24% of target (201 of 800-1000 locations)

**Extension Methods Usage Breakdown**:
- `.orEmpty()` - 31× in Phase 2 (String and collection defaults)
- `.orFalse()` - 15× in Phase 2 (Boolean defaults)
- `.orZero()` - 17× in Phase 2 (Integer defaults)
- `.orNow()` - 2× in Phase 2 (DateTime defaults)
- `.orDefault(value)` - 7× in Phase 2 (Custom defaults)

**Key Learnings**:
- **Phase 1**: Method chaining requires parentheses: `(field?.toString()).orEmpty()` not `field?.toString().orEmpty()`
- **Phase 2**: ValidationUtils extensions conflict with default value extensions; keep `??` where ValidationUtils is imported to avoid `ambiguous_extension_member_access` errors
- Extensions work well with SerializationUtils: `SerializationUtils.safeDateTime(data, 'field').orNow()`
- Some patterns require keeping `??` for complex method chaining (`.cast<T>()`, `.toDate()`)

**Phase 3 Targets (Optional)**:
- Expand to Services/Repositories (~20-25 files, estimated 100-150 migrations)
- Focus on high-usage services (UnifiedRecipeService, UnifiedShoppingService, etc.)
- Add linter rule to encourage adoption in new code
- Target: 80%+ adoption in critical layers achieved (Models: 100%, ViewModels: 93.5%)

### Available Extensions

#### String Extensions
```dart
String? name = user.name;
final displayName = name.orEmpty(); // '' if null
final status = order.status.orDefault('pending');
final cleanInput = userInput.orEmptyTrimmed();

if (email.isNullOrEmpty) { /* ... */ }
if (comment.hasValue) { /* ... */ }
if (input.isNullOrWhitespace) { /* ... */ }
```

#### List Extensions
```dart
List<Recipe>? recipes = await service.fetchRecipes();
final safeRecipes = recipes.orEmpty(); // [] if null
final count = recipes.safeLength; // 0 if null

if (tags.isNullOrEmpty) { /* ... */ }
if (ingredients.hasItems) { /* ... */ }

final first = items.firstOrNull; // null if empty/null
final last = items.lastOrNull;
```

#### Map Extensions
```dart
Map<String, dynamic>? settings = user.settings;
final safeSettings = settings.orEmpty(); // {} if null
final count = settings.safeLength; // 0 if null

if (metadata.isNullOrEmpty) { /* ... */ }
if (preferences.hasEntries) { /* ... */ }
```

#### DateTime Extensions
```dart
DateTime? timestamp = log.createdAt;
final time = timestamp.orNow(); // DateTime.now() if null
final startDate = event.startDate.orDefault(DateTime(2025, 1, 1));

if (lastSyncedAt.isNull) { /* ... */ }
if (completedAt.hasValue) { /* ... */ }

final iso = timestamp.toIso8601OrEmpty(); // '' if null
```

#### Numeric Extensions
```dart
int? count = recipe.portions;
final portions = count.orZero(); // 0 if null
final timeout = config.timeout.orDefault(30);

if (quantity.isNullOrZero) { /* ... */ }
if (rating.isPositive) { /* ... */ }

double? price = product.price;
final displayPrice = price.orZero(); // 0.0 if null
```

#### Bool Extensions
```dart
bool? isActive = user.isActive;
final active = isActive.orFalse(); // false if null
final enabled = feature.isEnabled.orTrue(); // true if null
```

### Usage Examples

#### Before (Manual Null Coalescing)
```dart
final name = recipe.title ?? '';
final ingredients = recipe.ingredients ?? [];
final timestamp = log.createdAt ?? DateTime.now();
final portions = recipe.portions ?? 4;
```

#### After (Extension Methods)
```dart
final name = recipe.title.orEmpty();
final ingredients = recipe.ingredients.orEmpty();
final timestamp = log.createdAt.orNow();
final portions = recipe.portions.orDefault(4);
```

### When to Use

✅ **Always use** instead of manual `?? value` patterns

---

## 8. Model Patterns

### Shared Content Models

**Location**: `lib/models/shared_content/`

Excellent deduplication already achieved:
- `BaseSharedContentModel` - Common fields and serialization
- `SharedContentStatusMixin` - View/engagement/dismiss tracking
- `CopyOnWriteSupport` - Collaborative editing patterns

### Usage
```dart
class SharedRecipe extends BaseSharedContentModel<Recipe>
    with SharedContentStatusMixin, CopyOnWriteSupport {

  @override
  Map<String, dynamic> toFirestore() {
    return {
      ...getCommonFirestoreFields(), // From base class
      ...getCopyOnWriteFirestoreFields(), // From mixin
      'originalRecipeId': originalRecipeId,
      'recipeSnapshot': recipeSnapshot.toFirestore(),
    };
  }
}
```

**Status**: Well-designed, minimal duplication remaining ✅

---

## 9. Test Patterns

### Test Base Classes

**Status**: To be created (see test helpers section)

### Recommended Structure
```dart
abstract class RepositoryTestBase {
  late MockAuthRepository mockAuthRepository;
  late FakeFirebaseFirestore fakeFirestore;

  @mustCallSuper
  void setUpRepository() {
    mockAuthRepository = MockAuthRepository();
    fakeFirestore = FakeFirebaseFirestore();
    setupDefaultMocks();
  }

  void setupDefaultMocks() {
    when(mockAuthRepository.currentUserId).thenReturn('test-user-123');
  }
}
```

### Test Data Factory
```dart
class TestDataFactory {
  static Recipe createRecipe({
    String? id,
    String? title,
    String? ownerId,
  }) {
    return Recipe(
      id: id ?? 'test-recipe-${DateTime.now().millisecondsSinceEpoch}',
      title: title ?? 'Test Recipe',
      ownerId: ownerId ?? 'test-user-123',
      // ... other fields with sensible defaults
    );
  }
}
```

---

## 10. Adoption Guidelines

### Priority Levels

#### Immediate (Use in all new code)
1. ✅ Extension methods for null coalescing
2. ✅ ValidationUtils for form validation
3. ✅ BaseFirebaseRepository for new repositories
4. ✅ SerializationUtils for Firestore parsing

#### High Priority (Refactor when touching code)
1. ⚠️ BaseService for services without it
2. ⚠️ AsyncOperationMixin for ViewModels
3. ⚠️ ErrorHandlingMixin for classes with try-catch blocks

#### Medium Priority (Gradual adoption)
1. 📋 Migrate manual try-catch to ErrorHandlingMixin methods
2. 📋 Replace manual loading states with AsyncOperationMixin
3. 📋 Consolidate service caching using BaseService.getCachedOrExecute()

#### Low Priority (Nice to have)
1. 💭 Refactor old repositories to BaseFirebaseRepository (if not already)
2. 💭 Add test base classes for new tests
3. 💭 Document custom patterns in this file

### Migration Strategy

#### For Services
```dart
// Current (manual error handling)
class MyService {
  Future<Recipe?> getRecipe(String id) async {
    try {
      return await _repository.getById(id);
    } catch (e, stackTrace) {
      AppLogger.error('Get recipe failed: $e', stackTrace);
      return null;
    }
  }
}

// Option 1: Extend BaseService (recommended)
class MyService extends BaseService {
  @override
  String get serviceName => 'MyService';

  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(
      () => _repository.getById(id),
      operationName: 'Get recipe',
    );
  }
}

// Option 2: Add ErrorHandlingMixin
class MyService with ErrorHandlingMixin {
  Future<Recipe?> getRecipe(String id) async {
    return await safeExecute(
      () => _repository.getById(id),
      operationName: 'Get recipe',
    );
  }
}
```

#### For ViewModels
```dart
// Current (manual loading states)
class RecipeViewModel extends ChangeNotifier {
  bool _isLoading = false;
  String? _error;

  Future<void> loadRecipes() async {
    _isLoading = true;
    _error = null;
    notifyListeners();

    try {
      _recipes = await _service.fetchRecipes();
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}

// Refactored (with AsyncOperationMixin)
class RecipeViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {

  Future<void> loadRecipes() async {
    await executeAsync(() async {
      _recipes = await _service.fetchRecipes();
    });
  }

  // isLoading, hasError, errorMessage provided by mixins
}
```

### Code Review Checklist

When reviewing new code, check for:
- [ ] Services extend BaseService or use ErrorHandlingMixin
- [ ] ViewModels use AsyncOperationMixin for loading states
- [ ] Repositories extend BaseFirebaseRepository
- [ ] Firestore parsing uses SerializationUtils
- [ ] Form validation uses ValidationUtils
- [ ] Null coalescing uses extension methods (`orEmpty()`, `orDefault()`)
- [ ] No manual try-catch blocks (use mixin methods)
- [ ] No manual `_isLoading` boolean flags (use AsyncOperationMixin)

---

## Summary

### Infrastructure Quality: A+

The Butlery codebase has **excellent deduplication infrastructure** that eliminates 3,000-4,000 lines of duplication. All major patterns are covered:

- ✅ Error handling
- ✅ Async operations
- ✅ Service layer standardization
- ✅ Repository CRUD operations
- ✅ Serialization and validation
- ✅ Extension methods

### Adoption Challenge: Partial (20-30%)

While the infrastructure is excellent, adoption is partial:
- ErrorHandlingMixin: 15% adoption
- AsyncOperationMixin: 5% adoption
- BaseService: 40% adoption
- SerializationUtils: 0% adoption (opportunity!)
- ValidationUtils: 15% adoption

### Recommendation

**Use this document as a reference** for all new code and refactoring efforts. The patterns exist, are well-designed, and have been proven in production. Focus on:

1. **Immediate adoption** for all new code
2. **Gradual refactoring** when touching existing code
3. **No new patterns** - use what exists
4. **Document exceptions** - if a pattern doesn't fit, document why

---

*Last Updated: January 2025*
*Status: Infrastructure Complete, Adoption In Progress*
