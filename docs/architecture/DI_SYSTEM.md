# Dependency Injection System

**Complete guide to Butlery's modular DI architecture with GetIt service locator**

**Last Updated**: January 2025
**Related Guides**: [Architecture Overview](ARCHITECTURE_OVERVIEW.md) | [MVVM Pattern](MVVM_PATTERN.md) | [Best Practices](BEST_PRACTICES.md)

---

## Overview

Butlery implements a **clean modular dependency injection system** using GetIt service locator with **7 domain-focused modules**.

### System Architecture

```
┌──────────┐  ┌──────────┐  ┌────────────┐  ┌─────────┐
│  Core    │  │ Content  │  │   Social   │  │Messaging│
│ Module   │  │  Module  │  │   Module   │  │ Module  │
└────┬─────┘  └────┬─────┘  └──────┬─────┘  └────┬────┘
     │             │               │              │
┌────▼─────┐  ┌───▼──────┐  ┌─────▼──────┐  ┌───▼──────┐
│Collabor- │  │Perform.  │  │     UI     │  │          │
│  ation   │  │  Module  │  │    Module  │  │          │
│ Module   │  │Module    │  │            │  │          │
└────┬─────┘  └────┬──────┘  └─────┬──────┘  │          │
     │             │               │          │          │
     └─────────────┴───────────────┴──────────┴──────────┘
                   │
             ┌─────▼──────┐
             │  Services  │
             │ (via       │
             │ServiceLoc) │
             └────────────┘
```

**Key Principles:**
- **Modularity**: Domain-focused modules with clear responsibilities
- **Lazy Loading**: Services created on-demand using lazy singletons
- **Testability**: Easy mock registration for testing
- **Separation**: Clear boundaries between modules
- **Type Safety**: Compile-time dependency resolution

---

## Domain Modules

The system is organized into **7 domain modules**:

### 1. Core Module (`lib/core/di/modules/core_module.dart`)

**Responsibilities:**
- Authentication (Firebase Auth)
- Storage (Firebase Storage)
- Analytics (Firebase Analytics)
- Persistence (Hive)
- Configuration

**Services Registered:**
- `AuthRepository` → `FirebaseAuthRepository`
- `AuthService`
- `StorageService`
- `AnalyticsService`
- `ConfigService`

**Dependencies:** None (base module)

### 2. Content Module (`lib/core/di/modules/content_module.dart`)

**Responsibilities:**
- Recipe management
- Menu planning
- Import systems (AI, URL, Web)
- Search functionality

**Services Registered:**
- `UnifiedRecipeService`
- `MenuService`
- `ImportService`
- `SearchService`
- `RecipeRepository` → `FirebaseRecipeRepository`

**Dependencies:** Core Module

### 3. Social Module (`lib/core/di/modules/social_module.dart`)

**Responsibilities:**
- Friend management
- Recipe sharing
- Comments and ratings
- Social feeds

**Services Registered:**
- `UnifiedFriendsService`
- `SocialRecipeService`
- `FriendsRepository` → `FirebaseFriendsRepository`
- `SocialRecipeRepository` → `FirebaseSocialRecipeRepository`

**Dependencies:** Core, Content

### 4. Messaging Module (`lib/core/di/modules/messaging_module.dart`)

**Responsibilities:**
- Direct messaging
- Push notifications
- FCM integration

**Services Registered:**
- `MessagingService`
- `NotificationService`
- `FCMService`

**Dependencies:** Core, Social

### 5. Collaboration Module (`lib/core/di/modules/collaboration_module.dart`)

**Responsibilities:**
- Real-time collaborative editing
- Shopping list coordination
- Group management
- Permission validation

**Services Registered:**
- `RealtimeRecipeService`
- `ShoppingListService`
- `GroupService`
- `PermissionService`

**Dependencies:** All modules

### 6. Performance Module (`lib/core/di/modules/performance_module.dart`)

**Responsibilities:**
- Caching strategies
- Performance monitoring
- Memory management

**Services Registered:**
- `CacheService`
- `PerformanceMonitor`

**Dependencies:** Core

### 7. UI Module (`lib/core/di/modules/ui_module.dart`)

**Responsibilities:**
- Theme management
- Component themes
- UI utilities

**Services Registered:**
- `ThemeService`
- `ComponentThemes`

**Dependencies:** Core

---

## Application Bootstrap

The bootstrap system orchestrates initialization in stages:

### Bootstrap Structure

```
lib/core/bootstrap/
├── application_bootstrap.dart   # Main orchestrator
└── stages/
    ├── platform_stage.dart     # Flutter bindings, platform setup
    ├── core_stage.dart         # Essential services (Auth, Storage)
    ├── content_stage.dart      # Recipe services, Import systems
    ├── social_stage.dart       # Social platform services
    └── messaging_stage.dart    # Messaging and notifications
```

### Bootstrap Implementation

```dart
// lib/core/bootstrap/application_bootstrap.dart
class ApplicationBootstrap {
  static Future<void> initialize() async {
    // Stage 1: Platform setup
    await PlatformStage().execute();

    // Stage 2: Core services
    await CoreStage().execute();

    // Stage 3: Content services
    await ContentStage().execute();

    // Stage 4: Social services
    await SocialStage().execute();

    // Stage 5: Messaging services
    await MessagingStage().execute();
  }
}
```

### Bootstrap Stage Pattern

```dart
class CoreStage extends BootstrapStage {
  @override
  Future<void> execute() async {
    // Initialize Firebase
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );

    // Initialize App Check for security
    await FirebaseAppCheck.instance.activate(
      androidProvider: AndroidProvider.debug,
      appleProvider: AppleProvider.debug,
    );

    // Configure Core Module
    await CoreModule().configure(DIContainer.instance);
  }
}
```

### Main.dart Integration

```dart
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // ✅ Clean bootstrap initialization
  await ApplicationBootstrap.initialize();

  // Widget bindings
  FlutterNativeSplash.preserve(widgetsBinding: WidgetsBinding.instance);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Run app with provider
  runApp(
    ApplicationProvider(
      child: const ButleryApp(),
    ),
  );
}
```

---

## Service Access Pattern

### Import Statement

```dart
import 'package:butlery/core/providers/application_provider.dart';
```

### Accessing Services

```dart
// In ViewModels
class RecipeViewModel extends ChangeNotifier {
  final _recipeService = ServiceLocator.get<UnifiedRecipeService>();
  final _authService = ServiceLocator.get<AuthService>();
}

// In Services
class SocialService {
  final _authService = ServiceLocator.get<AuthService>();
  final _friendsService = ServiceLocator.get<UnifiedFriendsService>();
}

// In Widgets
@override
Widget build(BuildContext context) {
  final recipeService = ServiceLocator.get<UnifiedRecipeService>();
  // ...
}
```

### Best Practices

✅ **DO:**
- Register services as lazy singletons
- Use interfaces when possible
- Keep registrations in appropriate modules
- Access via `ServiceLocator.get<T>()`

❌ **DON'T:**
- Register UI components
- Create circular dependencies
- Access DI container directly: `GetIt.instance.get<T>()` ❌
- Use legacy pattern: `sl<T>()` ❌ (completely removed)

---

## Service Pattern Decision Matrix

Two critical architectural decisions when creating services:

### Decision 1: BaseService vs ChangeNotifier

**Use BaseService when:**
- ✅ Service performs stateless operations (CRUD, API calls)
- ✅ Need error handling with retry logic
- ✅ Need pre-flight checks (auth, network, permissions)
- ✅ Need built-in caching with expiry
- ✅ Service doesn't need to notify listeners
- ✅ Service is utility/helper focused

**Example:** `RecipeService`, `StorageService`, `AnalyticsService`
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

**Use ChangeNotifier when:**
- ✅ Service manages reactive state
- ✅ ViewModels need to listen to service changes
- ✅ Service coordinates real-time data (Firebase streams)
- ✅ Service manages app-wide state (auth, user session)
- ✅ Need to notify multiple listeners on state changes

**Example:** `UnifiedRecipeService`, `AuthService`, `UserService`
```dart
class UnifiedRecipeService extends ChangeNotifier with ErrorHandlingMixin {
  List<Recipe> _recipes = [];
  bool _isLoading = false;

  List<Recipe> get recipes => _recipes;
  bool get isLoading => _isLoading;

  Future<void> loadRecipes() async {
    _isLoading = true;
    notifyListeners(); // Notify listeners of state change

    try {
      _recipes = await _repository.fetchRecipes();
    } catch (e) {
      handleError(e);
    } finally {
      _isLoading = false;
      notifyListeners(); // Notify listeners
    }
  }
}
```

**Current Usage in Codebase:**
- **BaseService**: 39 services (20%) - Stateless operations
- **ChangeNotifier**: 12 services - Reactive state management
- **Other**: 144 services - Standalone utilities, wrappers

**Decision Matrix:**

| Service Characteristic | BaseService | ChangeNotifier |
|------------------------|-------------|----------------|
| Has reactive state | ❌ | ✅ |
| Needs listeners | ❌ | ✅ |
| Stateless operations | ✅ | ❌ |
| Error handling with retry | ✅ | ⚠️ Manual |
| Pre-flight checks | ✅ | ⚠️ Manual |
| Built-in caching | ✅ | ❌ |
| Real-time data coordination | ❌ | ✅ |

### Decision 2: Constructor Injection vs ServiceLocator.get<T>()

**Use Constructor Injection when:**
- ✅ Registering services in DI modules
- ✅ Core dependencies (won't create circular refs)
- ✅ Need explicit dependency tracking
- ✅ Maximum testability (easy constructor mocks)

**Example:** DI Module Registration
```dart
// In content_module.dart
container.registerLazySingleton<RecipeService>(
  () => RecipeService(
    repository: container<RecipeRepository>(), // Constructor injection
    authService: container<AuthService>(),
    storageService: container<StorageService>(),
  ),
);
```

**Use ServiceLocator.get<T>() when:**
- ✅ In ViewModels and widgets
- ✅ Lazy dependencies (avoid circular deps during DI setup)
- ✅ Runtime dependency resolution
- ✅ Cross-module dependencies that create circular refs
- ✅ Late initialization patterns

**Example 1:** ViewModel Late Initialization
```dart
class RecipeViewModel extends ChangeNotifier {
  // Late initialization to avoid circular dependencies
  late final PermissionService _permissionService;
  late final UnifiedRecipeService _recipeService;

  RecipeViewModel() {
    _permissionService = ServiceLocator.get<PermissionService>();
    _recipeService = ServiceLocator.get<UnifiedRecipeService>();
  }
}
```

**Example 2:** Lazy Getter Pattern (Operation Modules)
```dart
class UnifiedShoppingService {
  // Lazy getter with ??= for on-demand initialization
  ShoppingShareOperations? __shareOps;
  ShoppingShareOperations get _shareOps =>
      __shareOps ??= ShoppingShareOperations(
        firestoreRepository: _firestoreRepository,
        permissionService: ServiceLocator.get<PermissionService>(), // Lazy!
      );

  // Operation only initialized when first accessed
  Future<void> shareList(String listId, String friendId) async {
    await _shareOps.shareWithFriend(listId, friendId); // Creates on first call
  }
}
```

**Why Lazy Getter Pattern?**
- Avoids circular dependency errors during DI module initialization
- Operation modules only created when actually needed (performance optimization)
- Used extensively in UnifiedRecipeService, UnifiedShoppingService, UnifiedMenuService
- **383 occurrences** of ServiceLocator.get<T>() across codebase (pervasive pattern)

**Current Usage in Codebase:**
- **Constructor Injection**: 39 services (DI module registration)
- **ServiceLocator.get<T>()**: 178 files (ViewModels, widgets, late initialization)

**Decision Matrix:**

| Use Case | Constructor Injection | ServiceLocator.get<T>() |
|----------|----------------------|-------------------------|
| DI module registration | ✅ ALWAYS | ❌ NEVER |
| Service → Service deps | ✅ Preferred | ⚠️ If circular ref |
| ViewModel deps | ❌ | ✅ ALWAYS |
| Widget deps | ❌ | ✅ ALWAYS |
| Late initialization | ❌ | ✅ ALWAYS |
| Testing | ✅ Easier mocking | ⚠️ Requires DI setup |

### Anti-Patterns to Avoid

❌ **Don't mix patterns in same constructor:**
```dart
// BAD: Mixing constructor injection and ServiceLocator
class BadService {
  final AuthService _authService; // Constructor injection

  BadService({required AuthService authService})
    : _authService = authService {
    final otherService = ServiceLocator.get<OtherService>(); // Mixed!
  }
}
```

❌ **Don't use ServiceLocator.get<T>() in DI modules:**
```dart
// BAD: Using ServiceLocator in module registration
container.registerLazySingleton<RecipeService>(
  () => RecipeService(
    repository: ServiceLocator.get<RecipeRepository>(), // WRONG!
  ),
);

// GOOD: Use container<T>()
container.registerLazySingleton<RecipeService>(
  () => RecipeService(
    repository: container<RecipeRepository>(), // CORRECT
  ),
);
```

❌ **Don't use constructor injection in ViewModels:**
```dart
// BAD: ViewModels shouldn't use constructor injection
class BadViewModel extends ChangeNotifier {
  final RecipeService _recipeService;

  BadViewModel({required RecipeService recipeService}) // Tight coupling!
    : _recipeService = recipeService;
}

// GOOD: Use ServiceLocator
class GoodViewModel extends ChangeNotifier {
  final _recipeService = ServiceLocator.get<UnifiedRecipeService>();
}
```

---

## Singleton Registration Patterns

Choose the appropriate registration pattern based on initialization needs:

### registerSingleton - Eager Initialization

Created immediately when registered:

```dart
container.registerSingleton<AuthRepository>(
  FirebaseAuthRepository(),
);
```

**When to use:**
- ✅ Core infrastructure (Auth, Storage, Firestore)
- ✅ Services needed at app startup
- ✅ No heavy initialization or I/O operations
- ✅ No circular dependency risks

### registerLazySingleton - Lazy Initialization

Created on first access:

```dart
container.registerLazySingleton<SocialRecipeService>(
  () => SocialRecipeService(
    repository: container<SocialRecipeRepository>(),
    userService: container<UserService>(),
  ),
);
```

**When to use:**
- ✅ Services with heavy initialization
- ✅ Cross-module dependencies (avoid circular refs during DI setup)
- ✅ Services not needed immediately at startup
- ✅ ViewModels and UI-related services
- ✅ Feature modules that depend on Core/Content modules

**Rule of thumb**: Core module uses eager singletons, all other modules prefer lazy singletons.

---

## Testing with DI

### Test Setup Pattern

```dart
setUpAll(() async {
  // Reset container
  DIContainer.reset();

  // Configure required modules
  await CoreModule().configure(DIContainer.instance);

  // Register mocks
  DIContainer.instance.registerSingleton<AuthService>(
    MockAuthService(),
  );
});

tearDownAll(() {
  DIContainer.reset();
});
```

### Mock Registration Example

```dart
class MockAuthService extends Mock implements AuthService {}

void main() {
  late RecipeService recipeService;
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    DIContainer.instance.registerSingleton<AuthService>(mockAuthService);
    recipeService = RecipeService();
  });

  test('should create recipe successfully', () async {
    when(() => mockAuthService.currentUserId).thenReturn('user123');
    // Test implementation
  });
}
```

---

## DI System Evolution

### Legacy System (REMOVED)

```dart
// ❌ OLD: Monolithic injection.dart (700 lines)
final sl = GetIt.instance;

void setupDependencies() {
  // All services registered in one massive file
  sl.registerSingleton<AuthRepository>(FirebaseAuthRepository());
  sl.registerSingleton<RecipeRepository>(...);
  // ... 50+ more registrations
}

// Usage:
final service = sl<RecipeService>(); // ❌ No longer used
```

### Modern System (IMPLEMENTED)

```dart
// ✅ NEW: Modular domain modules
class CoreModule extends DIModule {
  @override
  Future<void> configure(GetIt container) async {
    container.registerLazySingleton<AuthRepository>(
      () => FirebaseAuthRepository(),
    );
  }
}

// Usage:
final service = ServiceLocator.get<RecipeService>(); // ✅ Current pattern
```

### Migration Results

- ✅ **Zero compilation errors** (269 → 0)
- ✅ **119+ files migrated** from `sl<T>()` to `ServiceLocator.get<T>()`
- ✅ **All legacy code removed**
- ✅ **70% reduction** in complexity
- ✅ **7 domain modules** created and operational
- ✅ **main.dart reduced** from 530 to 436 lines

### Why the Change?

1. **Modularity**: Clear domain separation
2. **Maintainability**: Easier to understand and modify
3. **Testability**: Test modules independently
4. **Scalability**: Add services to appropriate modules
5. **Team-friendly**: Multiple developers can work in parallel

> **📖 See archived DI migration story for complete migration details**

---

## Complete Example: Adding New Feature

### Step 1: Create Repository Interface

```dart
// lib/repositories/interfaces/shopping_repository.dart
abstract class ShoppingRepository {
  Future<ShoppingList> create(ShoppingList list);
  Future<ShoppingList?> read(String id);
  Stream<List<ShoppingList>> watchLists(String userId);
}
```

### Step 2: Implement Firebase Repository

```dart
// lib/repositories/firebase/firebase_shopping_repository.dart
class FirebaseShoppingRepository implements ShoppingRepository {
  final FirebaseFirestore _firestore;
  final AuthRepository _authRepository;

  FirebaseShoppingRepository({
    FirebaseFirestore? firestore,
    required AuthRepository authRepository,
  }) : _firestore = firestore ?? FirebaseFirestore.instance,
       _authRepository = authRepository;

  @override
  Future<ShoppingList> create(ShoppingList list) async {
    final ref = _userCollection;
    if (ref == null) throw Exception('No authenticated user');
    await ref.doc(list.id).set(list.toFirestore());
    return list;
  }

  CollectionReference<Map<String, dynamic>>? get _userCollection {
    final uid = _authRepository.currentUserId;
    if (uid == null) return null;
    return _firestore.collection('users').doc(uid).collection('shopping_lists');
  }
}
```

### Step 3: Create Service

```dart
// lib/services/shopping_service.dart
class ShoppingService extends BaseService {
  final ShoppingRepository _repository;

  ShoppingService({required ShoppingRepository repository})
    : _repository = repository;

  @override
  String get serviceName => 'ShoppingService';

  Future<ShoppingList> createList(String name) async {
    return await executeServiceOperation(
      () => _repository.create(ShoppingList(name: name)),
      operationName: 'Create shopping list',
      requiresAuth: true,
    );
  }
}
```

### Step 4: Register in Module

```dart
// lib/core/di/modules/collaboration_module.dart
class CollaborationModule extends DIModule {
  @override
  Future<void> configure(GetIt container) async {
    // Register repository
    container.registerLazySingleton<ShoppingRepository>(
      () => FirebaseShoppingRepository(
        authRepository: container<AuthRepository>(),
      ),
    );

    // Register service
    container.registerLazySingleton<ShoppingService>(
      () => ShoppingService(
        repository: container<ShoppingRepository>(),
      ),
    );
  }
}
```

### Step 5: Use in ViewModel

```dart
// lib/viewmodels/shopping_viewmodel.dart
class ShoppingViewModel extends ChangeNotifier {
  final _shoppingService = ServiceLocator.get<ShoppingService>();

  Future<void> createNewList(String name) async {
    try {
      await _shoppingService.createList(name);
      notifyListeners();
    } catch (e) {
      // Handle error
    }
  }
}
```

---

## Next Steps

- **Implement a feature**: Follow the complete example above
- **Learn MVVM**: See [MVVM_PATTERN.md](MVVM_PATTERN.md) for architecture patterns
- **Firebase Integration**: See [FIREBASE_INTEGRATION.md](FIREBASE_INTEGRATION.md) for backend setup
- **Best Practices**: See [BEST_PRACTICES.md](BEST_PRACTICES.md) for troubleshooting

---

**Last Updated**: January 2025 | **Verified Against**: Actual codebase implementation
