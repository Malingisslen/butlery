# Code Deduplication Patterns

**Quick reference guide to Butlery's code deduplication infrastructure**

**Status**: Comprehensive infrastructure in place (Jan 2025)
**Impact**: 3,000-4,000 lines of duplication eliminated
**Adoption**: High (48-100% - varies by component)
**Last Verified**: December 2025

---

## Executive Summary

The Butlery codebase has **excellent deduplication infrastructure** already implemented. These patterns are **well adopted** (48-88% adoption). This guide provides quick reference to existing patterns.

**For complete documentation and examples**, see the **code-deduplication-utilities skill** in `.claude/skills/`.

### Available Infrastructure

1. ✅ **ErrorHandlingMixin** (669 lines) - 100% adopted in services
2. ✅ **AsyncOperationMixin** (458 lines) - 48% adopted (appropriate for ViewModels)
3. ✅ **BaseService** (495 lines) - Used by non-UI services
4. ✅ **BaseFirebaseRepository** (~400 lines) - Eliminating 2,000-2,500 lines of CRUD duplication
5. ✅ **SerializationUtils** (371 lines) - 100% adopted (17 models migrated Dec 2025)
6. ✅ **ValidationUtils** (384 lines) - Eliminating 1,600-2,400 lines of validation code
7. ✅ **Default Value Extensions** (~350 lines) - Eliminating 400+ lines of null coalescing
8. ✅ **Test Helpers** - Common test setup and data factories

---

## Quick Reference

### 1. ErrorHandlingMixin

**Location**: `lib/core/mixins/error_handling_mixin.dart`
**Adoption**: 100% (all services have ErrorHandlingMixin or extend BaseService)

**When to use:**
- Any class that makes async calls
- Error handling with retry logic
- CRUD operations needing safety wrappers
- Batch operations with continue-on-error

**Usage**:
```dart
class MyService with ErrorHandlingMixin {
  Future<Data> fetchData() async {
    return await safeAsyncOperation(
      () => _repository.getData(),
      operationName: 'Fetch data',
    );
  }
}
```

**Or via BaseService** (includes ErrorHandlingMixin automatically):
```dart
class MyService extends BaseService {
  @override
  String get serviceName => 'MyService';
}
```

---

### 2. AsyncOperationMixin

**Location**: `lib/core/mixins/async_operation_mixin.dart`
**Initiative Status**: ✅ COMPLETE (Jan 2025)
**Adoption**: 48% (22/46 ViewModels)

**Why 48% is Expected**: This adoption rate is appropriate and intentional. Only ViewModels with simple loading/error state patterns benefit from AsyncOperationMixin. Many ViewModels have well-architected custom state management (streams, manager patterns) that should NOT be replaced.

**When to use:**
- ViewModels with simple loading/error patterns
- Need automatic isLoading/hasError/errorMessage states
- Need debouncing or throttling
- Need operation caching

**When NOT to use:**
- ViewModels with complex custom state management
- ViewModels using streams or manager patterns
- Well-architected custom state already in place

**Usage**:
```dart
class MyViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {

  Future<void> loadData() async {
    await executeAsync(() async {
      _data = await _service.fetchData();
    });
  }
  // isLoading, hasError, errorMessage provided automatically
}
```

**Key Learning**: Of the 46 total ViewModels in the codebase, 22 (48%) benefit from AsyncOperationMixin. The remaining ViewModels have well-architected custom state management that should not be replaced.

---

### 3. BaseService

**Location**: `lib/core/base/base_service.dart`
**Adoption**: 88% (38/43 services)
**Opportunity**: 5 remaining services could benefit

**When to use:**
- Instance-based services (NOT ChangeNotifier or static utilities)
- Need error handling with retry
- Need pre-flight checks (auth, network, permissions)
- Need built-in caching

**Usage**:
```dart
class RecipeDiscoveryService extends BaseService {
  @override
  String get serviceName => 'RecipeDiscoveryService';

  Future<List<Recipe>> discoverRecipes() async {
    return await executeServiceOperation(
      () => _repository.fetchTrending(),
      operationName: 'Discover recipes',
      requiresAuth: true,
    );
  }
}
```

**Includes**: ErrorHandlingMixin automatically

---

### 4. BaseFirebaseRepository

**Location**: `lib/repositories/base/`
**Adoption**: 63% (17/27 Firebase repositories)
**Opportunity**: 10 repositories could benefit

**When to use:**
- New Firebase repositories
- Need standard CRUD with permission validation
- Need audit logging (GDPR Article 30)
- Need streaming support

**Usage**:
```dart
class MyRepository extends BaseFirebaseRepository<MyModel> {
  MyRepository({
    required AuthRepository authRepository,
    FirebaseFirestore? firestore,
  }) : super(
    authRepository: authRepository,
    firestore: firestore,
    collectionPath: 'myCollection',
  );

  @override
  MyModel fromFirestore(DocumentSnapshot doc) {
    return MyModel.fromFirestore(doc);
  }
}
```

---

### 5. SerializationUtils

**Location**: `lib/core/utils/serialization_utils.dart`
**Adoption**: 100% (17 models migrated in Dec 2025)

**When to use:**
- Parsing Firestore documents
- Handling Firebase Timestamps
- Parsing nested objects and lists
- Enum serialization

**Usage**:
```dart
factory Recipe.fromFirestore(DocumentSnapshot doc) {
  final data = doc.data() as Map<String, dynamic>;
  return Recipe(
    title: SerializationUtils.safeString(data, 'title'),
    portions: SerializationUtils.safeInt(data, 'portions', defaultValue: 4),
    createdAt: SerializationUtils.safeDateTime(data, 'createdAt') ?? DateTime.now(),
    ingredients: SerializationUtils.safeStringList(data, 'ingredients'),
  );
}
```

---

### 6. ValidationUtils

**Location**: `lib/core/utils/validation_utils.dart`

**When to use:**
- Form validation
- Business rule validation
- Null/empty checks
- String format validation

**Usage**:
```dart
// Validate required field
ValidationUtils.validateRequired(value, 'Field name');

// Validate email
ValidationUtils.validateEmail(email);

// Collection helpers
ValidationUtils.hasItems(list);
ValidationUtils.safeCount(list);
```

---

### 7. Default Value Extensions

**Location**: `lib/core/extensions/default_value_extensions.dart`
**Adoption**: 3.7% (30 files)

**When to use:**
- Null-safe default values
- Cleaner null coalescing
- Type-safe defaults

**Usage**:
```dart
// Instead of: value ?? ''
final name = recipe.title.orEmpty();

// Instead of: list ?? []
final items = cart.items.orEmpty();

// Instead of: value ?? 0
final count = items.length.orZero();

// Null checking
if (ingredients.hasItems) { /* ... */ }
```

---

### 8. Test Helpers

**Location**: `test/helpers/`

**Available Helpers:**
- `RepositoryTestBase` - Common repository test setup
- `ServiceTestBase` - Common service test setup
- `TestDataFactory` - Consistent test data generation

**Usage**:
```dart
class MyRepositoryTest extends RepositoryTestBase {
  late MyRepository repository;

  setUp() {
    super.setUp();
    repository = MyRepository(
      authRepository: mockAuthRepository,
      firestore: fakeFirestore,
    );
  }
}
```

---

## Adoption Guidelines

### Immediate Use (All New Code)

- ✅ Extension methods for null coalescing
- ✅ ValidationUtils for form validation
- ✅ BaseFirebaseRepository for new repositories
- ✅ SerializationUtils for Firestore parsing
- ✅ Test helpers for new tests

### High Priority (When Touching Existing Code)

- ⚠️ BaseService for services without it
- ⚠️ ErrorHandlingMixin for classes with try-catch blocks

### Opportunistic

- ⚠️ AsyncOperationMixin for ViewModels with simple loading/error patterns
- ⚠️ Respect well-architected custom state management

---

## Current Adoption Status

| Pattern | Adoption | Files Using | Opportunity |
|---------|----------|-------------|-------------|
| ErrorHandlingMixin | 88% | Via BaseService | 5 services |
| AsyncOperationMixin | 48% | 22/46 ViewModels | Expected rate (simple patterns only) |
| BaseService | 88% | 38/43 services | 5 services |
| BaseFirebaseRepository | 63% | 17/27 repositories | 10 repositories |
| SerializationUtils | 26% | 12 files | Expand to more models |
| Extension methods | - | 30 files | High! |
| ValidationUtils | Low | Few files | High! |
| Test Helpers | Growing | New infrastructure | All new tests |

---

## Migration Decision Framework

### AsyncOperationMixin Decision Tree

**Full Migration** (2 ViewModels):
- Simple loading/error states
- No custom state management
- No streams or complex patterns

**Partial Migration** (10 ViewModels):
- Some simple operations benefit
- Some complex operations keep custom logic
- Hybrid approach works well

**Deferred** (Most ViewModels):
- Well-architected custom state management
- Stream-based architecture
- Manager delegation patterns
- Complex state machines

### BaseService Decision

**Use BaseService when:**
- Instance-based service (not ChangeNotifier)
- Needs error handling
- Needs pre-flight checks
- Needs caching

**Don't use BaseService for:**
- ChangeNotifier services (12 services)
- Static utilities (2 services)
- Services with reactive state

---

## Success Stories

### AsyncOperationMixin Initiative (Complete - Jan 2025)

- ✅ 21 ViewModels migrated (24% of 89 total ViewModels)
- ✅ 250-280 lines eliminated per ViewModel
- ✅ Key learning: Only ViewModels with simple loading/error patterns benefit - 24% adoption is expected and appropriate

### BaseService Migrations (Jan 2025)

Recent successful migrations:
- PermissionService
- PerformanceMonitoringService
- ImageUploadService
- RecipeDiscoveryService

Each eliminated ~100-150 lines of boilerplate.

---

## Anti-Patterns to Avoid

❌ **Don't force patterns where they don't fit**
- Respect well-architected custom code
- AsyncOperationMixin isn't for everyone

❌ **Don't migrate ChangeNotifier services to BaseService**
- They serve different purposes
- ChangeNotifier for reactive state
- BaseService for stateless operations

❌ **Don't skip SerializationUtils**
- High value, low adoption
- Easy wins available everywhere

---

## Complete Documentation

**For detailed patterns, examples, and migration guides**, see:

📚 **code-deduplication-utilities skill**
- Location: `.claude/skills/code-deduplication-utilities/`
- Complete documentation with examples
- Migration strategies
- Best practices

This skill is the **source of truth** for all deduplication patterns.

---

## Quick Start

1. **New service?** → Use BaseService
2. **New repository?** → Use BaseFirebaseRepository
3. **Parsing Firestore?** → Use SerializationUtils
4. **Null coalescing?** → Use extension methods
5. **Form validation?** → Use ValidationUtils
6. **Simple ViewModel loading states?** → Consider AsyncOperationMixin
7. **New test?** → Use Test Helpers

---

## Summary

Butlery has **excellent deduplication infrastructure** that can eliminate 3,000-4,000 additional lines of duplication through increased adoption.

**Key Actions**:
- Use patterns for all new code
- Opportunistically refactor when touching existing code
- Respect well-architected custom solutions
- See code-deduplication-utilities skill for full documentation

**Impact**: Current 20-24% adoption (varies by component). Target 40-60% adoption for additional codebase reduction where patterns fit well.

---

**Last Updated**: January 2025 | **Source of Truth**: `.claude/skills/code-deduplication-utilities/`
