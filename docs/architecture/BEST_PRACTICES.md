# Best Practices and Patterns

**Development guidelines, common patterns, and troubleshooting for Butlery**

**Last Updated**: January 2025
**Related Guides**: [Architecture Overview](ARCHITECTURE_OVERVIEW.md) | [MVVM Pattern](MVVM_PATTERN.md) | [DI System](DI_SYSTEM.md)

---

## Repository Pattern Benefits

### 1. Testability

Easy to mock repositories for unit tests:

```dart
class MockRecipeRepository extends Mock implements RecipeRepository {}

void main() {
  late RecipeService service;
  late MockRecipeRepository mockRepository;

  setUp(() {
    mockRepository = MockRecipeRepository();
    service = RecipeService(repository: mockRepository);
  });

  test('should create recipe successfully', () async {
    when(() => mockRepository.create(any())).thenAnswer((_) async => testRecipe);
    await service.createRecipe(testRecipe);
    verify(() => mockRepository.create(testRecipe)).called(1);
  });
}
```

### 2. Flexibility

Easy to switch backends without changing business logic:

```dart
// Current: Firebase implementation
abstract class RecipeRepository {
  Future<Recipe> create(Recipe recipe);
}

class FirebaseRecipeRepository implements RecipeRepository { }

// Future: Could add SQL, REST API, etc.
class SQLRecipeRepository implements RecipeRepository { }
class RESTRecipeRepository implements RecipeRepository { }
```

### 3. Separation of Concerns

Business logic separated from data access:

```dart
class RecipeService {
  final RecipeRepository _repository;

  // Business logic
  Future<void> publishRecipe(Recipe recipe) async {
    // Validate
    if (!recipe.isValid) throw ValidationException();

    // Business rules
    recipe.publishedAt = DateTime.now();
    recipe.status = RecipeStatus.published;

    // Delegate to repository
    await _repository.update(recipe);
  }
}
```

### 4. Consistency

Unified interfaces across all data operations:

```dart
abstract class Repository<T> {
  Future<T> create(T entity);
  Future<T?> read(String id);
  Future<List<T>> readAll();
  Future<void> update(T entity);
  Future<void> delete(String id);
}

// All domain repositories follow same pattern
class RecipeRepository extends Repository<Recipe> { }
class MenuRepository extends Repository<Menu> { }
class UserRepository extends Repository<UserProfile> { }
```

---

## Error Handling

### Comprehensive Error Handling at Every Layer

**1. Repository Layer:**
```dart
class FirebaseRecipeRepository {
  @override
  Future<Recipe> create(Recipe recipe) async {
    try {
      await _userCollection?.doc(recipe.id).set(recipe.toFirestore());
      return recipe;
    } on FirebaseException catch (e) {
      throw RepositoryException('Failed to create recipe: ${e.message}');
    }
  }
}
```

**2. Service Layer:**
```dart
class RecipeService {
  Future<Result<Recipe>> createRecipe(Recipe recipe) async {
    try {
      final created = await _repository.create(recipe);
      notifyListeners();
      return Success(created);
    } on RepositoryException catch (e) {
      return Failure(e.message);
    } catch (e) {
      return Failure('Unexpected error creating recipe');
    }
  }
}
```

**3. ViewModel Layer:**
```dart
class RecipeViewModel {
  Future<void> createRecipe(Recipe recipe) async {
    _error = null;
    _isLoading = true;
    notifyListeners();

    final result = await _recipeService.createRecipe(recipe);

    result.when(
      success: (recipe) {
        _recipes.add(recipe);
        _isLoading = false;
        notifyListeners();
      },
      failure: (error) {
        _error = error;
        _isLoading = false;
        notifyListeners();
      },
    );
  }
}
```

---

## Performance Optimizations

### 1. Lazy Loading

Services created only when needed:

```dart
class ContentModule extends DIModule {
  @override
  Future<void> configure(GetIt container) async {
    // Lazy singleton - created on first access
    container.registerLazySingleton<RecipeService>(
      () => RecipeService(),
    );
  }
}
```

### 2. Stream Management

Proper cleanup to prevent memory leaks:

```dart
class RecipeService extends ChangeNotifier {
  StreamSubscription? _recipeSubscription;

  void watchRecipes(String userId) {
    _recipeSubscription?.cancel();
    _recipeSubscription = _repository.watchRecipes(userId).listen(
      (recipes) {
        _recipes = recipes;
        notifyListeners();
      },
    );
  }

  @override
  void dispose() {
    _recipeSubscription?.cancel();
    super.dispose();
  }
}
```

### 3. Cache Strategy

Implement caching to reduce Firebase reads:

```dart
class CacheService {
  final Map<String, CachedData> _cache = {};

  Future<T> getOrFetch<T>(
    String key,
    Future<T> Function() fetcher,
    Duration ttl,
  ) async {
    final cached = _cache[key];

    if (cached != null && !cached.isExpired) {
      return cached.data as T;
    }

    final data = await fetcher();
    _cache[key] = CachedData(data: data, expiry: DateTime.now().add(ttl));
    return data;
  }
}
```

### 4. Batch Operations

Reduce Firebase writes with batching:

```dart
class RecipeRepository {
  Future<void> batchCreateRecipes(List<Recipe> recipes) async {
    final batch = _firestore.batch();

    for (final recipe in recipes) {
      final ref = _userCollection?.doc(recipe.id);
      if (ref != null) {
        batch.set(ref, recipe.toFirestore());
      }
    }

    await batch.commit();
  }
}
```

### 5. Pagination

Load data in chunks for better performance:

```dart
class RecipeRepository {
  Future<List<Recipe>> getRecipesPaginated({
    required int limit,
    DocumentSnapshot? startAfter,
  }) async {
    Query query = _userCollection!.orderBy('createdAt').limit(limit);

    if (startAfter != null) {
      query = query.startAfterDocument(startAfter);
    }

    final snapshot = await query.get();
    return snapshot.docs.map((doc) => Recipe.fromFirestore(doc)).toList();
  }
}
```

---

## Adding New Features

### Complete Feature Addition Workflow

**Step 1: Define the Model**
```dart
// lib/models/menu.dart
class Menu {
  final String id;
  final String title;
  final List<String> recipeIds;
  final DateTime startDate;
  final DateTime endDate;

  Menu({
    required this.id,
    required this.title,
    required this.recipeIds,
    required this.startDate,
    required this.endDate,
  });

  Map<String, dynamic> toFirestore() => {
    'title': title,
    'recipeIds': recipeIds,
    'startDate': Timestamp.fromDate(startDate),
    'endDate': Timestamp.fromDate(endDate),
  };

  factory Menu.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return Menu(
      id: doc.id,
      title: data['title'],
      recipeIds: List<String>.from(data['recipeIds']),
      startDate: (data['startDate'] as Timestamp).toDate(),
      endDate: (data['endDate'] as Timestamp).toDate(),
    );
  }
}
```

**Step 2: Define Repository Interface**
```dart
// lib/repositories/interfaces/menu_repository.dart
abstract class MenuRepository {
  Future<Menu> create(Menu menu);
  Future<Menu?> read(String id);
  Future<List<Menu>> readAll();
  Future<void> update(Menu menu);
  Future<void> delete(String id);
  Stream<List<Menu>> watchMenus(String userId);
}
```

**Step 3: Implement Firebase Repository**
```dart
// lib/repositories/firebase/firebase_menu_repository.dart
class FirebaseMenuRepository implements MenuRepository {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  FirebaseMenuRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authRepository = authRepository;

  @override
  Future<Menu> create(Menu menu) async {
    final ref = _userCollection;
    if (ref == null) throw Exception('No authenticated user');
    await ref.doc(menu.id).set(menu.toFirestore());
    return menu;
  }

  CollectionReference<Map<String, dynamic>>? get _userCollection {
    final uid = _authRepository.currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('menus');
  }
}
```

**Step 4: Create Service**
```dart
// lib/services/menu_service.dart
class MenuService extends ChangeNotifier {
  final _repository = ServiceLocator.get<MenuRepository>();

  List<Menu> _menus = [];
  bool _isLoading = false;
  String? _error;

  List<Menu> get menus => _menus;
  bool get isLoading => _isLoading;
  String? get error => _error;

  Future<void> loadMenus() async {
    _isLoading = true;
    notifyListeners();

    try {
      _menus = await _repository.readAll();
      _error = null;
    } catch (e) {
      _error = 'Failed to load menus: $e';
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  Future<void> createMenu(Menu menu) async {
    await _repository.create(menu);
    await loadMenus();
  }
}
```

**Step 5: Register in DI Module**
```dart
// lib/core/di/modules/content_module.dart
class ContentModule extends DIModule {
  @override
  Future<void> configure(GetIt container) async {
    // Register repository
    container.registerLazySingleton<MenuRepository>(
      () => FirebaseMenuRepository(
        authRepository: container.get<AuthRepository>(),
      ),
    );

    // Register service
    container.registerLazySingleton<MenuService>(
      () => MenuService(),
    );
  }
}
```

**Step 6: Create ViewModel**
```dart
// lib/viewmodels/menu_viewmodel.dart
class MenuViewModel extends ChangeNotifier {
  final _menuService = ServiceLocator.get<MenuService>();

  List<Menu> get menus => _menuService.menus;
  bool get isLoading => _menuService.isLoading;
  String? get error => _menuService.error;

  Future<void> loadMenus() async {
    await _menuService.loadMenus();
  }

  Future<void> createMenu(Menu menu) async {
    await _menuService.createMenu(menu);
  }
}
```

**Step 7: Create View**
```dart
// lib/views/menu_list_view.dart
class MenuListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => MenuViewModel()..loadMenus(),
      child: Consumer<MenuViewModel>(
        builder: (context, viewModel, child) {
          if (viewModel.isLoading) {
            return LoadingIndicator();
          }

          if (viewModel.error != null) {
            return ErrorDisplay(error: viewModel.error!);
          }

          return ListView.builder(
            itemCount: viewModel.menus.length,
            itemBuilder: (context, index) {
              return MenuCard(menu: viewModel.menus[index]);
            },
          );
        },
      ),
    );
  }
}
```

**Step 8: Write Tests**
```dart
// test/unit/services/menu_service_test.dart
void main() {
  late MenuService service;
  late MockMenuRepository mockRepository;

  setUp(() {
    mockRepository = MockMenuRepository();
    DIContainer.instance.registerSingleton<MenuRepository>(mockRepository);
    service = MenuService();
  });

  test('should load menus successfully', () async {
    when(() => mockRepository.readAll()).thenAnswer((_) async => [testMenu]);

    await service.loadMenus();

    expect(service.menus, hasLength(1));
    expect(service.error, isNull);
  });
}
```

---

## Testing Guidelines

### Test Structure

```
test/
├── unit/
│   ├── services/        # Service tests (96.2% coverage)
│   ├── viewmodels/      # ViewModel tests (86.7% coverage)
│   ├── repositories/    # Repository tests (29.3% coverage - needs improvement)
│   └── models/          # Model tests
├── widget/              # Widget tests (149 tests)
├── integration/         # Integration tests (13 tests)
├── mocks/               # Centralized mocks
├── factories/           # Test data factories
└── templates/           # Test templates for consistency
```

### Service Test Template

```dart
// test/unit/services/recipe_service_test.dart
void main() {
  late RecipeService service;
  late MockRecipeRepository mockRepository;
  late MockAuthRepository mockAuthRepository;

  setUp(() {
    mockRepository = MockRecipeRepository();
    mockAuthRepository = MockAuthRepository();

    DIContainer.instance.registerSingleton<RecipeRepository>(mockRepository);
    DIContainer.instance.registerSingleton<AuthRepository>(mockAuthRepository);

    service = RecipeService();
  });

  tearDown(() {
    DIContainer.reset();
  });

  group('RecipeService', () {
    test('should create recipe successfully', () async {
      when(() => mockAuthRepository.currentUserId).thenReturn('user123');
      when(() => mockRepository.create(any())).thenAnswer((_) async => testRecipe);

      await service.createRecipe(testRecipe);

      verify(() => mockRepository.create(testRecipe)).called(1);
      expect(service.recipes, contains(testRecipe));
    });
  });
}
```

### ViewModel Test Template

```dart
// test/unit/viewmodels/recipe_viewmodel_test.dart
void main() {
  late RecipeViewModel viewModel;
  late MockRecipeService mockService;

  setUp(() {
    mockService = MockRecipeService();
    DIContainer.instance.registerSingleton<RecipeService>(mockService);
    viewModel = RecipeViewModel();
  });

  group('RecipeViewModel', () {
    test('should update loading state correctly', () async {
      when(() => mockService.loadRecipes()).thenAnswer(
        (_) => Future.delayed(Duration(milliseconds: 100)),
      );

      final loadingStates = <bool>[];
      viewModel.addListener(() => loadingStates.add(viewModel.isLoading));

      await viewModel.loadRecipes();

      expect(loadingStates, [true, false]);
    });
  });
}
```

### Widget Test Template

```dart
// test/widget/recipe_card_test.dart
void main() {
  testWidgets('RecipeCard displays recipe information', (tester) async {
    final recipe = TestFactories.createTestRecipe(title: 'Test Recipe');

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: RecipeCard(recipe: recipe),
        ),
      ),
    );

    expect(find.text('Test Recipe'), findsOneWidget);
    expect(find.byType(RecipeImage), findsOneWidget);
  });
}
```

> **📖 See [../testing/TESTING_COMPLETE_GUIDE.md](../testing/TESTING_COMPLETE_GUIDE.md) for complete testing guide**

---

## Code Quality Standards

### File Size Limit: 500 Lines Maximum

When a file exceeds 500 lines, apply the **Facade Pattern**:

```dart
// Before: Large service file (>500 lines)
class RecipeService {
  // 50+ methods
}

// After: Facade pattern with operation classes
class RecipeService {
  final RecipeCRUDOperations _crudOps;
  final RecipeSearchOperations _searchOps;
  final RecipeSharingOperations _sharingOps;

  RecipeService({
    required RecipeCRUDOperations crudOps,
    required RecipeSearchOperations searchOps,
    required RecipeSharingOperations sharingOps,
  }) : _crudOps = crudOps,
       _searchOps = searchOps,
       _sharingOps = sharingOps;

  // Delegate to operation classes
  Future<Recipe> createRecipe(Recipe recipe) => _crudOps.create(recipe);
  Future<List<Recipe>> searchRecipes(String query) => _searchOps.search(query);
  Future<void> shareRecipe(String id, List<String> userIds) =>
    _sharingOps.share(id, userIds);
}
```

### Single Responsibility Principle

Each class should have **one reason to change**:

```dart
// ✅ GOOD: Single responsibility
class RecipeValidator {
  bool isValid(Recipe recipe) {
    return recipe.title.isNotEmpty && recipe.ingredients.isNotEmpty;
  }
}

class RecipeRepository {
  Future<void> save(Recipe recipe) async {
    // Only handles data persistence
  }
}

// ❌ BAD: Multiple responsibilities
class RecipeManager {
  bool isValid(Recipe recipe) { } // Validation
  Future<void> save(Recipe recipe) { } // Persistence
  String formatForDisplay(Recipe recipe) { } // Presentation
}
```

### Flutter Color Syntax

Use modern `withValues` instead of deprecated `withOpacity`:

```dart
// ✅ CORRECT
Color.blue.withValues(alpha: 0.8)

// ❌ DEPRECATED
Color.blue.withOpacity(0.8)
```

### Const Constructors

Use `const` for immutable widgets:

```dart
// ✅ GOOD
const Text('Hello')
const SizedBox(height: 16)
const Icon(Icons.home)

// ❌ MISSING OPTIMIZATION
Text('Hello')
SizedBox(height: 16)
Icon(Icons.home)
```

---

## Troubleshooting Guide

### 1. Firebase Not Initialized Error

**Error Message:**
```
FirebaseException: [core/no-app] No Firebase App '[DEFAULT]' has been created
```

**Solution:**
```dart
// Ensure Firebase initialized before accessing services
await Firebase.initializeApp(
  options: DefaultFirebaseOptions.currentPlatform,
);
```

**Check initialization status:**
```dart
final status = await AppInitializer.getInitializationStatus();
print('Firebase initialized: ${status['firebase']}');
print('Auth state: ${status['auth']}');
```

### 2. Dependency Injection Errors

**Error Message:**
```
GetItException: Object/factory with type ServiceType is not registered
```

**Solution:**
```dart
// Check service is registered in module
DIContainer.instance.isRegistered<ServiceType>();

// Verify module initialized in bootstrap
await ContentModule().configure(DIContainer.instance);
```

**Debug registration:**
```dart
// List all registered services
final types = DIContainer.instance.getRegisteredTypes();
print('Registered services: $types');
```

### 3. Authentication State Issues

**Problem:** User logged in but data not loading

**Solution:**
```dart
// Verify auth state
final user = FirebaseAuth.instance.currentUser;
print('Current user: ${user?.uid}');

// Check repository has auth
final authRepo = ServiceLocator.get<AuthRepository>();
print('Auth repo user: ${authRepo.currentUserId}');
```

### 4. Settings Not Persisting

**Problem:** User settings don't save between sessions

**Root Cause:** Using wrong data source (PermissionService instead of UserService)

**Solution:**
```dart
// ✅ CORRECT: Use UserService for settings
final userService = ServiceLocator.get<UserService>();
await userService.updateSettings(settings);

// ❌ WRONG: Don't use PermissionService for user data
final permissionService = ServiceLocator.get<PermissionService>(); // Only for auth checks!
```

### 5. Notification Not Appearing

**Development Mode:**
```dart
// Check logs for notification output
// Look for: 🔔 [DEV] FCM notification ready
```

**Production Mode:**
```dart
// Check FCM token
final token = await FirebaseMessaging.instance.getToken();
print('FCM Token: $token');

// Check notification permissions
final settings = await FirebaseMessaging.instance.requestPermission();
print('Notification permission: ${settings.authorizationStatus}');
```

### 6. Circular Dependency

**Error Message:**
```
GetItException: Circular dependency detected: ServiceA -> ServiceB -> ServiceA
```

**Solution:**
```dart
// Use lazy initialization to break cycle
class ServiceA {
  late final ServiceB _serviceB;

  ServiceA() {
    _serviceB = ServiceLocator.get<ServiceB>();
  }
}
```

---

## Debug Tools

### Initialization Status Check

```dart
final status = await AppInitializer.getInitializationStatus();
// Returns Map<String, bool> with status of all systems
```

### Firebase Connection Test

```dart
await _performFirestorePing();
// Tests Firestore connectivity for authenticated users
```

### DI Container Inspection

```dart
// List all registered services
DIContainer.instance.getRegisteredTypes();

// Check if service is registered
DIContainer.instance.isRegistered<ServiceType>();

// Reset container (tests only)
DIContainer.reset();
```

---

## Performance Issues

### Slow App Startup

```dart
// Profile initialization
final stopwatch = Stopwatch()..start();
await ApplicationBootstrap.initialize();
stopwatch.stop();
print('Bootstrap time: ${stopwatch.elapsedMilliseconds}ms');
```

### Memory Leaks

```dart
// Ensure proper disposal
class MyService extends ChangeNotifier {
  StreamSubscription? _subscription;

  @override
  void dispose() {
    _subscription?.cancel(); // Important!
    super.dispose();
  }
}
```

### Slow Queries

```dart
// Add Firestore indexes
// Check firestore.indexes.json and Firebase console
```

---

## Common Anti-Patterns

### ❌ Don't Access Firebase Directly

```dart
// BAD: Direct Firebase access
final doc = await FirebaseFirestore.instance
    .collection('recipes')
    .doc(recipeId)
    .get();

// GOOD: Use repository
final recipe = await _recipeRepository.read(recipeId);
```

### ❌ Don't Put Business Logic in Views

```dart
// BAD: Business logic in view
class RecipeView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isValid = recipe.title.isNotEmpty && recipe.ingredients.isNotEmpty;
    // ...
  }
}

// GOOD: Business logic in ViewModel
class RecipeViewModel {
  bool isRecipeValid(Recipe recipe) {
    return recipe.title.isNotEmpty && recipe.ingredients.isNotEmpty;
  }
}
```

### ❌ Don't Create God Classes

```dart
// BAD: God class with too many responsibilities
class RecipeManager {
  Future<void> createRecipe() { }
  Future<void> updateRecipe() { }
  Future<void> deleteRecipe() { }
  Future<void> shareRecipe() { }
  Future<void> exportRecipe() { }
  Future<void> importRecipe() { }
  // ... 50+ more methods
}

// GOOD: Separate concerns
class RecipeService { } // CRUD operations
class RecipeSharingService { } // Sharing operations
class RecipeImportService { } // Import/export operations
```

---

## Next Steps

- **Implement Features**: Follow the complete workflow above
- **Write Tests**: Use test templates for consistency
- **Monitor Performance**: Profile and optimize as needed
- **Review Metrics**: See [PROJECT_METRICS.md](PROJECT_METRICS.md) for current status

---

**Last Updated**: January 2025 | **Verified Against**: Actual codebase implementation
