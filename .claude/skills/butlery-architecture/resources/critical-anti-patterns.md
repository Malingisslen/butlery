# Critical Anti-Patterns in Butlery

This document lists the most critical anti-patterns that **must be avoided** in Butlery. These violations break the architectural integrity and should trigger immediate correction.

## 1. Direct Firebase Access (CRITICAL 🔥)

### ❌ Anti-Pattern
```dart
class BadService {
  Future<void> createRecipe(Recipe recipe) async {
    // NEVER DO THIS - Bypasses repository layer and security validation
    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipe.id)
        .set(recipe.toMap());
  }
}
```

### Why It's Bad
- Bypasses repository layer
- No permission validation
- No audit logging
- Breaks testability
- Violates architecture

### ✅ Correct Pattern
```dart
class GoodService extends BaseService {
  final RecipeRepository _repository;

  GoodService({required RecipeRepository repository})
      : _repository = repository;

  Future<void> createRecipe(Recipe recipe) async {
    await executeServiceOperation(
      () => _repository.create(recipe),  // ✅ Uses repository with permission validation
      operationName: 'Create recipe',
    );
  }
}
```

---

## 2. Legacy `sl<T>()` Pattern (CRITICAL 🔥)

### ❌ Anti-Pattern
```dart
// NEVER DO THIS - This pattern was removed from codebase
final service = sl<RecipeService>();
```

### Why It's Bad
- Legacy pattern completely removed
- Code won't compile
- Inconsistent with current DI system

### ✅ Correct Pattern
```dart
// Use ServiceLocator.get<T>() for runtime access
final service = ServiceLocator.get<RecipeService>();
```

---

## 3. Layer Bypassing (CRITICAL 🔥)

### ❌ Anti-Pattern - ViewModel Accessing Repository Directly
```dart
class BadViewModel extends ChangeNotifier {
  final RecipeRepository _repository;  // ❌ Should use Service layer

  Future<void> loadRecipes() async {
    final recipes = await _repository.readAll();  // ❌ Bypasses business logic
  }
}
```

### Why It's Bad
- Bypasses business logic layer
- Duplicates logic across ViewModels
- Hard to maintain
- Breaks layer separation

### ✅ Correct Pattern
```dart
class GoodViewModel extends ChangeNotifier with AsyncOperationMixin {
  final UnifiedRecipeService _recipeService;  // ✅ Service layer

  Future<void> loadRecipes() => executeAsync(() async {
    final recipes = await _recipeService.personal.getAllRecipes();  // ✅ Business logic included
  });
}
```

---

## 4. View Accessing Service Directly (HIGH 🔥)

### ❌ Anti-Pattern
```dart
class BadView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final service = ServiceLocator.get<RecipeService>();  // ❌ View shouldn't access service

    return ElevatedButton(
      onPressed: () async {
        await service.deleteRecipe(recipeId);  // ❌ Business logic in view
      },
      child: Text('Delete'),
    );
  }
}
```

### Why It's Bad
- Business logic in UI layer
- No state management
- Hard to test
- No loading/error states

### ✅ Correct Pattern
```dart
class GoodView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final viewModel = Provider.of<RecipeViewModel>(context);  // ✅ Use ViewModel

    return ElevatedButton(
      onPressed: viewModel.isLoading ? null : () => viewModel.deleteRecipe(),
      child: viewModel.isLoading
          ? CircularProgressIndicator()
          : Text('Delete'),
    );
  }
}
```

---

## 5. Service Not Extending BaseService (HIGH 🔥)

### ❌ Anti-Pattern
```dart
class BadService {  // ❌ Should extend BaseService
  Future<Recipe?> getRecipe(String id) async {
    try {  // ❌ Manual error handling
      return await _repository.getById(id);
    } catch (e) {
      print('Error: $e');  // ❌ Poor error handling
      return null;
    }
  }
}
```

### Why It's Bad
- No ErrorHandlingMixin
- Inconsistent error handling
- No service lifecycle management
- Missing pre-flight checks
- No caching infrastructure

### ✅ Correct Pattern
```dart
class GoodService extends BaseService {  // ✅ Extends BaseService
  final RecipeRepository _repository;

  GoodService({required RecipeRepository repository})
      : _repository = repository;

  @override
  String get serviceName => 'RecipeService';

  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(  // ✅ ErrorHandlingMixin automatic
      () => _repository.getById(id),
      operationName: 'Get recipe',
    );
  }
}
```

---

## 6. Repository Not Extending BaseFirebaseRepository (HIGH 🔥)

### ❌ Anti-Pattern
```dart
class BadRepository implements RecipeRepository {  // ❌ Should extend BaseFirebaseRepository
  Future<Recipe> create(Recipe recipe) async {
    // ❌ No permission validation
    // ❌ No audit logging
    // ❌ Manual Firestore operations
    await FirebaseFirestore.instance
        .collection('recipes')
        .doc(recipe.id)
        .set(recipe.toMap());
    return recipe;
  }
}
```

### Why It's Bad
- No permission validation
- No audit logging
- Duplicate CRUD code
- No streaming support
- Inconsistent patterns

### ✅ Correct Pattern
```dart
class GoodRepository extends BaseFirebaseRepository<Recipe>
    with UserScopedFirebaseRepository<Recipe>
    implements RecipeRepository {

  GoodRepository({required super.authRepository});

  @override
  String get collectionName => 'recipes';

  @override
  Recipe fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      Recipe.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(Recipe recipe) => recipe.toFirestore();

  @override
  String getId(Recipe recipe) => recipe.id;

  // CRUD operations inherited with permission validation + audit logging
}
```

---

## 7. Missing Permission Validation (CRITICAL 🔥)

### ❌ Anti-Pattern
```dart
class BadRepository extends BaseFirebaseRepository<Recipe> {
  // ❌ No permission validation override

  Future<void> update(Recipe recipe) async {
    // ❌ Anyone can update any recipe
    await super.update(recipe);
  }
}
```

### Why It's Bad
- Security vulnerability
- No ownership checks
- GDPR compliance risk
- Data integrity issues

### ✅ Correct Pattern
```dart
class GoodRepository extends BaseFirebaseRepository<Recipe> {
  @override
  Future<bool> validateUpdatePermission(String userId, Recipe entity) async {
    // ✅ Verify user owns the recipe
    final ownerId = entity.socialData?.ownerId ?? entity.createdBy ?? userId;
    return ownerId == userId;
  }

  @override
  Future<void> update(Recipe recipe) async {
    // ✅ Permission validation automatic via BaseFirebaseRepository
    await super.update(recipe);
  }
}
```

---

## 8. Constructor Injection in Runtime Code (MEDIUM ⚠️)

### ❌ Anti-Pattern
```dart
// In ViewModel initialization
class BadViewModel extends BaseViewModel {
  BadViewModel() {
    // ❌ Constructor injection outside DI module
    final service = RecipeService(
      repository: RecipeRepository(),  // ❌ Manual instantiation
    );
  }
}
```

### Why It's Bad
- Bypasses DI system
- Hard to test
- Inconsistent with DI pattern
- Creates dependencies manually

### ✅ Correct Pattern
```dart
class GoodViewModel extends BaseViewModel {
  late final UnifiedRecipeService _service;

  void initialize() {
    // ✅ ServiceLocator for runtime access
    _service = ServiceLocator.get<UnifiedRecipeService>();
  }
}
```

---

## 9. ServiceLocator in DI Module Registration (MEDIUM ⚠️)

### ❌ Anti-Pattern
```dart
// In DI module:
class BadModule implements DIModule {
  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<MyService>(
      MyService(
        repository: ServiceLocator.get<MyRepository>(),  // ❌ Don't use ServiceLocator here
      ),
    );
  }
}
```

### Why It's Bad
- Circular dependency risk during DI setup
- Inconsistent DI pattern
- Hard to debug initialization order

### ✅ Correct Pattern
```dart
// In DI module:
class GoodModule implements DIModule {
  @override
  Future<void> configure(GetIt container) async {
    container.registerSingleton<MyService>(
      MyService(
        repository: container<MyRepository>(),  // ✅ Use container<T>()
      ),
    );
  }
}
```

---

## 10. Mixing Both Service Access Patterns (MEDIUM ⚠️)

### ❌ Anti-Pattern
```dart
class BadService extends BaseService {
  final RecipeRepository _repository;

  BadService({required RecipeRepository repository})
      : _repository = repository;

  Future<void> doSomething() async {
    // ❌ Mixing constructor injection with ServiceLocator
    final userService = ServiceLocator.get<UserService>();
    // ...
  }
}
```

### Why It's Bad
- Inconsistent dependency management
- Some deps explicit, some hidden
- Hard to test and mock

### ✅ Correct Pattern
```dart
class GoodService extends BaseService {
  final RecipeRepository _repository;
  final UserService _userService;

  // ✅ All dependencies in constructor (for services)
  GoodService({
    required RecipeRepository repository,
    required UserService userService,
  })  : _repository = repository,
        _userService = userService;

  // OR for ViewModels (late initialization to avoid circular deps):
  late final UserService _userService;

  void initialize() {
    _userService = ServiceLocator.get<UserService>();
  }
}
```

---

## 11. ViewModel Notifying Without State Change (MEDIUM ⚠️)

### ❌ Anti-Pattern
```dart
class BadViewModel extends ChangeNotifier {
  Future<void> loadData() async {
    notifyListeners();  // ❌ Notifying before state change
    final data = await _service.getData();
    _data = data;
    // ❌ Not notifying after state change
  }
}
```

### Why It's Bad
- UI updates at wrong time
- Missing updates after state change
- Inconsistent behavior

### ✅ Correct Pattern
```dart
class GoodViewModel extends ChangeNotifier with AsyncOperationMixin {
  Future<void> loadData() => executeAsync(() async {
    final data = await _service.getData();
    _data = data;
    notifyListeners();  // ✅ Notify after state change
  });
  // AsyncOperationMixin handles loading states automatically
}
```

---

## 12. Not Disposing Resources (HIGH 🔥)

### ❌ Anti-Pattern
```dart
class BadViewModel extends ChangeNotifier {
  final StreamSubscription _subscription;

  BadViewModel() {
    _subscription = _stream.listen((data) {
      // Handle data
    });
  }

  // ❌ No dispose() - memory leak!
}
```

### Why It's Bad
- Memory leaks
- Resource leaks
- Performance degradation

### ✅ Correct Pattern
```dart
class GoodViewModel extends ChangeNotifier {
  StreamSubscription? _subscription;

  void initialize() {
    _subscription = _stream.listen((data) {
      // Handle data
    });
  }

  @override
  void dispose() {
    _subscription?.cancel();  // ✅ Clean up resources
    super.dispose();
  }
}
```

---

## 13. Hardcoded User ID Instead of Auth Service (CRITICAL 🔥)

### ❌ Anti-Pattern
```dart
class BadService extends BaseService {
  Future<Recipe> createRecipe(Recipe recipe) async {
    // ❌ Hardcoded or passed-in user ID
    recipe = recipe.copyWith(createdBy: 'user-123');
    return await _repository.create(recipe);
  }
}
```

### Why It's Bad
- Security vulnerability
- User impersonation possible
- No auth verification

### ✅ Correct Pattern
```dart
class GoodService extends BaseService {
  final AuthRepository _authRepository;

  GoodService({
    required RecipeRepository repository,
    required AuthRepository authRepository,
  })  : _repository = repository,
        _authRepository = authRepository;

  Future<Recipe> createRecipe(Recipe recipe) async {
    // ✅ Get current user from auth service
    final currentUser = _authRepository.currentUser;
    if (currentUser == null) {
      throw AuthenticationException('User not authenticated');
    }

    recipe = recipe.copyWith(createdBy: currentUser.uid);
    return await executeServiceOperation(
      () => _repository.create(recipe),
      operationName: 'Create recipe',
      requiresAuth: true,
    );
  }
}
```

---

## 14. Using Wrong Data Source for User Profile (HIGH 🔥)

### ❌ Anti-Pattern
```dart
class BadViewModel extends BaseViewModel {
  Future<void> loadUserSettings() async {
    // ❌ PermissionService only for basic auth/permission checks
    final user = _permissionService.currentUser;
    final settings = user?.settings;  // ❌ Won't have settings data
  }
}
```

### Why It's Bad
- `PermissionService.currentUser` doesn't have profile data
- Settings won't persist
- UI inconsistencies

### ✅ Correct Pattern
```dart
class GoodViewModel extends BaseViewModel {
  Future<void> loadUserSettings() async {
    // ✅ UserService.currentUserProfile has complete data
    final userProfile = _userService.currentUserProfile;
    final settings = userProfile?.settings;  // ✅ Full user data with settings
  }
}
```

**Data Source Rules**:
- Use `UserService.currentUserProfile` for complete user data (settings, avatar, social features)
- Use `PermissionService.currentUser` only for basic auth/permission checks
- **Never mix data sources** - leads to settings not persisting

---

## 15. Synchronous Operations in Async Context (LOW 💡)

### ❌ Anti-Pattern
```dart
class BadViewModel extends BaseViewModel {
  Future<void> loadData() async {
    _isLoading = true;
    notifyListeners();

    final data = _service.getData();  // ❌ Not awaiting async operation
    _data = data;  // ❌ Will be a Future, not data

    _isLoading = false;
    notifyListeners();
  }
}
```

### Why It's Bad
- Data won't be loaded
- Type mismatch (Future vs actual data)
- UI shows wrong state

### ✅ Correct Pattern
```dart
class GoodViewModel extends BaseViewModel with AsyncOperationMixin {
  Future<void> loadData() => executeAsync(() async {
    final data = await _service.getData();  // ✅ Awaiting async operation
    _data = data;
    notifyListeners();
  });
}
```

---

## Detection Checklist

When reviewing code, check for:

- [ ] No `FirebaseFirestore.instance` direct usage
- [ ] No `sl<T>()` pattern (use `ServiceLocator.get<T>()`)
- [ ] Services extend `BaseService`
- [ ] Repositories extend `BaseFirebaseRepository`
- [ ] ViewModels don't access repositories directly
- [ ] Views don't access services directly
- [ ] Permission validation on all repository operations
- [ ] Resources properly disposed
- [ ] Correct user data source (`UserService` vs `PermissionService`)
- [ ] All async operations properly awaited
- [ ] `notifyListeners()` after state changes
- [ ] Constructor injection in DI modules, ServiceLocator in runtime code

---

**Priority Levels**:
- 🔥 **CRITICAL**: Block PR, must fix immediately (security/architecture violations)
- 🔥 **HIGH**: Should fix before merge (maintainability issues)
- ⚠️ **MEDIUM**: Fix when convenient (inconsistency, tech debt)
- 💡 **LOW**: Nice to fix (minor issues, style)
