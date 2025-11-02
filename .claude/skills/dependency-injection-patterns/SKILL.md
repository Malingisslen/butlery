# Dependency Injection Patterns

Comprehensive guide to Butlery's modular dependency injection system using GetIt service locator with 7 application modules.

## Overview

Butlery uses a clean modular DI architecture for managing dependencies:
- **7 Application Modules**: Core, Content, Social, Messaging, Collaboration, Performance, UI
- **GetIt Service Locator**: Centralized dependency registry
- **Bootstrap Pattern**: ApplicationBootstrap orchestrates initialization
- **Two Access Patterns**: Constructor injection (services) + ServiceLocator (runtime)
- **Testing Support**: Test service locator with mocks

**Key Rule**: NO direct imports of singleton instances. ALL services accessed via DI.

## When This Skill Activates

Auto-activates when you:
- Register new services in DI modules
- Access services using ServiceLocator
- Set up dependency injection in tests
- Initialize application modules
- Work with ApplicationBootstrap

## Quick Reference

### Service Registration

```dart
// In DI module (lib/core/di/modules/content_module.dart)
void registerContentModule(GetIt container) {
  // Eager singleton (created immediately)
  container.registerSingleton<RecipeRepository>(
    FirebaseRecipeRepository(
      firestore: container<FirestoreRepository>(),
    ),
  );

  // Lazy singleton (created on first access)
  container.registerLazySingleton<RecipeService>(
    () => RecipeService(
      repository: container<RecipeRepository>(),
      userService: container<UserService>(),
    ),
  );
}
```

### Service Access

**Pattern 1: Constructor Injection** (Preferred for services):
```dart
class RecipeService {
  final RecipeRepository _repository;
  final UserService _userService;

  RecipeService({
    required RecipeRepository repository,
    required UserService userService,
  }) : _repository = repository,
       _userService = userService;
}
```

**Pattern 2: ServiceLocator.get<T>()** (For runtime access):
```dart
// In widgets
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final recipeService = ServiceLocator.get<UnifiedRecipeService>();
    return ...;
  }
}

// In ViewModels (late initialization)
class RecipeViewModel {
  late final RecipeService _service;

  void initialize() {
    _service = ServiceLocator.get<RecipeService>();
  }
}
```

### Testing with DI

```dart
// In test setUp
setUp() async {
  await TestServiceLocator.setup();

  // Register mocks
  TestServiceLocator.registerMock<RecipeRepository>(
    mockRecipeRepository,
  );
}

tearDown() async {
  await TestServiceLocator.reset();
}
```

## 7 Application Modules

Butlery's DI is organized into 7 domain-driven modules:

### 1. Core Module (`lib/core/di/modules/core_module.dart`)

**Purpose**: Foundational infrastructure (auth, storage, logging)

**Services Registered**:
- `AuthRepository` - Firebase authentication
- `FirestoreRepository` - Firestore database access
- `StorageRepository` - Firebase Storage
- `AnalyticsService` - Analytics tracking
- `Logger` - Logging infrastructure
- `ConnectivityService` - Network monitoring

**Registration Type**: Eager singletons (needed at startup)

**Dependencies**: None (foundation layer)

### 2. Content Module (`lib/core/di/modules/content_module.dart`)

**Purpose**: Content management (recipes, menus, import)

**Services Registered**:
- `RecipeRepository`, `MenuRepository`
- `UnifiedRecipeService`, `UnifiedMenuService`
- `ImportService` (photo, OCR, social media)
- `ImagePickerService`, `OCRExtractionService`

**Registration Type**: Lazy singletons (created on demand)

**Dependencies**: Core Module (auth, firestore, storage)

### 3. Social Module (`lib/core/di/modules/social_module.dart`)

**Purpose**: Social features (friends, sharing, comments, ratings)

**Services Registered**:
- `FriendsRepository`, `SocialRecipeRepository`
- `UnifiedFriendsService`, `SocialRecipeService`
- `CommentsRepository`, `RatingsRepository`
- `RecipeDiscoveryService`, `RecipeSharingManager`

**Registration Type**: Lazy singletons

**Dependencies**: Core + Content Modules

### 4. Messaging Module (`lib/core/di/modules/messaging_module.dart`)

**Purpose**: Messaging and notifications

**Services Registered**:
- `MessagingRepository`, `NotificationsRepository`
- `MessagingService`, `FCMService`
- `MessagingMediaService`

**Registration Type**: Lazy singletons

**Dependencies**: Core + Social Modules

### 5. Collaboration Module (`lib/core/di/modules/collaboration_module.dart`)

**Purpose**: Real-time collaboration (shopping, menus)

**Services Registered**:
- `ShoppingRepository`, `CollaborativeRecipeRepository`
- `UnifiedShoppingService`, `RealtimeRecipeService`
- `GroupSharedContentService`, `PresenceService`

**Registration Type**: Lazy singletons

**Dependencies**: Core + Content + Social Modules

### 6. Performance Module (`lib/core/di/modules/performance_module.dart`)

**Purpose**: Performance optimization (cache, startup)

**Services Registered**:
- `CacheOptimizationService`, `StartupOptimizationService`
- `PerformanceMonitoringService`, `RecipeDataRepairService`

**Registration Type**: Lazy singletons

**Dependencies**: Core + Content Modules

### 7. UI Module (`lib/core/di/modules/ui_module.dart`)

**Purpose**: ViewModels, navigation, UI state

**Services Registered**:
- All ViewModels (RecipeViewModel, MenuViewModel, etc.)
- Navigation-related services

**Registration Type**: Factory (new instance each time)

**Dependencies**: All other modules

## Module Dependency Graph

```
Foundation:
  Core Module
    ↓
Content Layer:
  Content Module
    ↓
Social Layer:
  Social Module → Messaging Module
    ↓
Collaboration Layer:
  Collaboration Module
    ↓
Optimization Layer:
  Performance Module
    ↓
Presentation Layer:
  UI Module
```

**Rule**: Modules can only depend on modules above them in the hierarchy.

## Registration Patterns

### Eager Singleton (registerSingleton)

**When to use**:
- Core infrastructure (Auth, Storage, Firestore)
- Services needed at app startup
- No heavy initialization or I/O
- No circular dependency risks

**Example**:
```dart
container.registerSingleton<AuthRepository>(
  FirebaseAuthRepository(),
);
```

**Characteristics**:
- Created immediately when module loads
- Instance exists before first access
- Use for lightweight, always-needed services

### Lazy Singleton (registerLazySingleton)

**When to use**:
- Services with heavy initialization
- Cross-module dependencies (avoid circular refs during setup)
- Services not needed immediately at startup
- Feature modules (Content, Social, etc.)
- ViewModels and UI-related services

**Example**:
```dart
container.registerLazySingleton<RecipeService>(
  () => RecipeService(
    repository: container<RecipeRepository>(),
    userService: container<UserService>(),
  ),
);
```

**Characteristics**:
- Created on first access
- Lazy initialization prevents circular dependency issues
- Use for services with complex dependencies

### Factory (registerFactory)

**When to use**:
- ViewModels (new instance per screen)
- Disposable services
- Stateful components that need fresh state

**Example**:
```dart
container.registerFactory<RecipeViewModel>(
  () => RecipeViewModel(
    service: container<RecipeService>(),
  ),
);
```

**Characteristics**:
- New instance created on each access
- Used rarely in Butlery (mostly for ViewModels)
- Each screen gets independent ViewModel instance

## Service Access Patterns

### Pattern 1: Constructor Injection (Recommended for Services)

**Use for**:
- ✅ Registering services in DI modules
- ✅ Core dependencies that won't create circular refs
- ✅ Explicit dependency tracking
- ✅ Testability (easy to mock in constructors)

**Example**:
```dart
// Service definition
class RecipeService {
  final RecipeRepository _repository;
  final UserService _userService;

  RecipeService({
    required RecipeRepository repository,
    required UserService userService,
  }) : _repository = repository,
       _userService = userService;
}

// DI registration
container.registerLazySingleton<RecipeService>(
  () => RecipeService(
    repository: container<RecipeRepository>(),
    userService: container<UserService>(),
  ),
);
```

**Benefits**:
- Dependencies explicit in constructor
- Easy to test (inject mocks)
- Type-safe at compile time
- Clear dependency graph

### Pattern 2: ServiceLocator.get<T>() (For Runtime Access)

**Use for**:
- ✅ Widgets and ViewModels
- ✅ Lazy dependencies (avoiding circular deps during DI setup)
- ✅ Runtime-determined dependencies
- ✅ Cross-module dependencies that would create circular refs

**Example**:
```dart
// In widgets
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final service = ServiceLocator.get<UnifiedRecipeService>();
    return Consumer<RecipeViewModel>(
      builder: (context, viewModel, _) => ...
    );
  }
}

// In ViewModels (late initialization)
class RecipeViewModel extends ChangeNotifier {
  late final RecipeService _service;

  RecipeViewModel() {
    _service = ServiceLocator.get<RecipeService>();
  }
}
```

**Benefits**:
- Avoids circular dependencies during DI setup
- Flexible runtime access
- Works when dependency needed later

### Anti-Pattern: Direct Firestore Access

**❌ NEVER do this**:
```dart
// WRONG - Bypasses repository pattern, destroys testability
final firestore = FirebaseFirestore.instance;
final doc = await firestore.collection('recipes').doc(id).get();
```

**✅ CORRECT - Use dependency injection**:
```dart
class RecipeService {
  final RecipeRepository _repository;

  RecipeService({required RecipeRepository repository})
      : _repository = repository;

  Future<Recipe?> getRecipe(String id) async {
    return await _repository.getById(id);
  }
}
```

**Exception**: Accessing via repository getter is acceptable:
```dart
class AccountDeletionService {
  final FirestoreRepository _firestoreRepository;

  AccountDeletionService({required FirestoreRepository firestoreRepository})
      : _firestoreRepository = firestoreRepository;

  Future<void> deleteAccount() async {
    // Repository is injected ✅
    // Access controlled through repository layer ✅
    final firestore = _firestoreRepository.firestore;
    await firestore.collection('users').doc(userId).delete();
  }
}
```

## ApplicationBootstrap Pattern

**Purpose**: Orchestrates initialization of all 7 modules

**Location**: `lib/core/bootstrap/application_bootstrap.dart`

**Usage in main.dart**:
```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize all modules
  await ApplicationBootstrap.initialize();

  runApp(MyApp());
}
```

**What it does**:
1. Initializes GetIt container
2. Registers all 7 modules in order
3. Initializes Firebase
4. Sets up error handling
5. Configures logging

**Module registration order** (dependency-aware):
```dart
class ApplicationBootstrap {
  static Future<void> initialize() async {
    final container = GetIt.instance;

    // 1. Core (foundation)
    registerCoreModule(container);

    // 2. Content (depends on Core)
    registerContentModule(container);

    // 3. Social (depends on Core + Content)
    registerSocialModule(container);

    // 4. Messaging (depends on Core + Social)
    registerMessagingModule(container);

    // 5. Collaboration (depends on Core + Content + Social)
    registerCollaborationModule(container);

    // 6. Performance (depends on Core + Content)
    registerPerformanceModule(container);

    // 7. UI (depends on all modules)
    registerUIModule(container);
  }
}
```

## Testing with DI

### Test Service Locator

**Purpose**: Separate DI container for tests with mock support

**Location**: `test/infrastructure/di/test_service_locator.dart`

**Usage**:
```dart
import 'package:butlery/test/infrastructure/di/test_service_locator.dart';

void main() {
  group('RecipeService', () {
    late RecipeService service;
    late MockRecipeRepository mockRepository;

    setUpAll(() async {
      await TestServiceLocator.setup();
    });

    setUp() {
      mockRepository = MockRecipeRepository();

      // Register mock
      TestServiceLocator.registerMock<RecipeRepository>(
        mockRepository,
      );

      // Get service with injected mock
      service = ServiceLocator.get<RecipeService>();
    });

    tearDown() async {
      await TestServiceLocator.reset();
    });

    test('getRecipe returns recipe from repository', () async {
      when(() => mockRepository.getById(any()))
          .thenAnswer((_) async => testRecipe);

      final result = await service.getRecipe('recipe-123');

      expect(result, testRecipe);
      verify(() => mockRepository.getById('recipe-123')).called(1);
    });
  });
}
```

### Mocking Dependencies

**Pattern**: Register mocks in test setUp

```dart
setUp() {
  // Create mocks
  mockAuthRepository = MockAuthRepository();
  mockRecipeRepository = MockRecipeRepository();
  mockUserService = MockUserService();

  // Register mocks in test service locator
  TestServiceLocator.registerMock<AuthRepository>(mockAuthRepository);
  TestServiceLocator.registerMock<RecipeRepository>(mockRecipeRepository);
  TestServiceLocator.registerMock<UserService>(mockUserService);

  // Get service under test (dependencies auto-injected)
  service = ServiceLocator.get<RecipeService>();
}
```

## Common Patterns

### Pattern 1: Service with Multiple Dependencies

```dart
class UnifiedRecipeService {
  final RecipeRepository _personalRepo;
  final SocialRecipeRepository _socialRepo;
  final UserService _userService;
  final PermissionService _permissionService;

  UnifiedRecipeService({
    required RecipeRepository personalRepository,
    required SocialRecipeRepository socialRepository,
    required UserService userService,
    required PermissionService permissionService,
  }) : _personalRepo = personalRepository,
       _socialRepo = socialRepository,
       _userService = userService,
       _permissionService = permissionService;
}

// DI registration
container.registerLazySingleton<UnifiedRecipeService>(
  () => UnifiedRecipeService(
    personalRepository: container<RecipeRepository>(),
    socialRepository: container<SocialRecipeRepository>(),
    userService: container<UserService>(),
    permissionService: container<PermissionService>(),
  ),
);
```

### Pattern 2: Circular Dependency Avoidance

**Problem**: Service A needs Service B, Service B needs Service A

**Solution**: Use lazy initialization

```dart
class ServiceA {
  late final ServiceB _serviceB;

  ServiceA() {
    // Lazy initialization avoids circular ref during construction
    _serviceB = ServiceLocator.get<ServiceB>();
  }
}

class ServiceB {
  late final ServiceA _serviceA;

  ServiceB() {
    _serviceA = ServiceLocator.get<ServiceA>();
  }
}
```

### Pattern 3: ViewModel with ChangeNotifierProvider

```dart
// ViewModel definition
class RecipeViewModel extends ChangeNotifier {
  final RecipeService _service;

  RecipeViewModel({required RecipeService service})
      : _service = service;
}

// Widget usage
ChangeNotifierProvider(
  create: (_) => ServiceLocator.get<RecipeViewModel>(),
  child: Consumer<RecipeViewModel>(
    builder: (context, viewModel, _) => RecipeListContent(viewModel),
  ),
)
```

## Best Practices

1. **Use constructor injection for services** - Explicit dependencies, testable
2. **Use ServiceLocator for widgets/ViewModels** - Avoids Provider boilerplate
3. **Register in appropriate module** - Follow domain boundaries
4. **Lazy singletons for most services** - Prevents circular deps
5. **Eager singletons for core only** - Keep startup fast
6. **Never access FirebaseFirestore.instance directly** - Always inject repository
7. **Test with TestServiceLocator** - Mock all dependencies
8. **Follow module hierarchy** - Modules only depend on modules above

## Anti-Patterns to Avoid

**1. Direct Singleton Access** (🔥 HIGH):
```dart
// ❌ WRONG - Direct access to singleton
final service = UnifiedRecipeService.instance;

// ✅ RIGHT - DI access
final service = ServiceLocator.get<UnifiedRecipeService>();
```

**2. Mixing DI Patterns** (⚠️):
```dart
// ❌ WRONG - Mixing constructor injection with ServiceLocator in constructor
class MyService {
  final RecipeRepository _repository;

  MyService({required RecipeRepository repository})
      : _repository = repository {
    // Don't do both patterns in same constructor
    final userService = ServiceLocator.get<UserService>();
  }
}

// ✅ RIGHT - Choose one pattern
class MyService {
  final RecipeRepository _repository;
  final UserService _userService;

  MyService({
    required RecipeRepository repository,
    required UserService userService,
  }) : _repository = repository,
       _userService = userService;
}
```

**3. Circular Dependency in Constructor** (🔥 HIGH):
```dart
// ❌ WRONG - Circular dependency
container.registerLazySingleton<ServiceA>(
  () => ServiceA(serviceB: container<ServiceB>()), // Calls ServiceB constructor
);

container.registerLazySingleton<ServiceB>(
  () => ServiceB(serviceA: container<ServiceA>()), // Calls ServiceA constructor
);
// Result: Stack overflow during initialization

// ✅ RIGHT - Use late initialization
class ServiceA {
  late final ServiceB _serviceB;
  ServiceA() {
    _serviceB = ServiceLocator.get<ServiceB>();
  }
}
```

## Resource Files

Detailed documentation for specific DI patterns:

1. **[module-structure.md](resources/module-structure.md)** - 7 modules detailed
   - Core, Content, Social, Messaging, Collaboration, Performance, UI modules
   - Services registered in each module
   - Module dependencies and hierarchy

2. **[registration-patterns.md](resources/registration-patterns.md)** - Registration types
   - Eager singleton (registerSingleton)
   - Lazy singleton (registerLazySingleton)
   - Factory (registerFactory)
   - When to use each pattern

3. **[service-access-patterns.md](resources/service-access-patterns.md)** - Access patterns
   - Constructor injection (preferred for services)
   - ServiceLocator.get<T>() (for widgets/ViewModels)
   - When to use each pattern
   - Anti-patterns to avoid

4. **[testing-with-di.md](resources/testing-with-di.md)** - Testing patterns
   - TestServiceLocator setup/teardown
   - Mocking dependencies
   - Test patterns for services with DI

## Related Skills

**Complementary Skills**:
- 🏗️ **[butlery-architecture](../butlery-architecture/SKILL.md)** - For overall MVVM + Repository architecture
- 🗄️ **[firebase-repository-patterns](../firebase-repository-patterns/SKILL.md)** - For repository layer patterns using DI
- 📋 **[testing-patterns](../testing-patterns/SKILL.md)** - For testing with TestServiceLocator

---

**Skill Version**: 1.0
**Last Updated**: 2025-01-31
**Status**: Week 4 of Claude Code infrastructure system
**Progress**: 92% complete (Weeks 1-3 done, Week 4 in progress)
