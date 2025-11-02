# Service Access Patterns - Constructor Injection vs ServiceLocator

Comprehensive guide to accessing services in Butlery's dependency injection system.

## Overview

Butlery uses **two patterns** for accessing services:
- **Pattern 1**: Constructor Injection (preferred for services)
- **Pattern 2**: ServiceLocator.get<T>() (for widgets/ViewModels)

**Key Rule**: Choose the pattern based on WHERE you're accessing the service, not what service it is.

## Two Service Access Patterns

| Pattern | Use When | Example |
|---------|----------|---------|
| **Constructor Injection** | Registering services in DI modules | `MyService({required Repository repo})` |
| **ServiceLocator.get<T>()** | Widgets, ViewModels, runtime access | `ServiceLocator.get<MyService>()` |

## Pattern 1: Constructor Injection (Recommended for Services)

### When to Use

**Use constructor injection when**:
- ✅ Registering services in DI modules
- ✅ Core dependencies that won't create circular refs
- ✅ Want explicit dependency tracking
- ✅ Need testability (easy to mock in constructors)
- ✅ Service depends on service (same or lower-level module)

**When NOT to use**:
- ❌ In widgets (creates tight coupling)
- ❌ In ViewModels (can use, but ServiceLocator more flexible)
- ❌ When it creates circular dependencies during DI setup
- ❌ When dependency is needed at runtime, not construction

### Syntax

```dart
// Service definition with constructor injection
class RecipeService {
  final RecipeRepository _repository;
  final UserService _userService;

  RecipeService({
    required RecipeRepository repository,
    required UserService userService,
  }) : _repository = repository,
       _userService = userService;
}

// DI registration (inject dependencies via constructor)
container.registerLazySingleton<RecipeService>(
  () => RecipeService(
    repository: container<RecipeRepository>(),  // Constructor injection
    userService: container<UserService>(),      // Constructor injection
  ),
);
```

### Examples

**Simple Service**:
```dart
class RecipeService {
  final RecipeRepository _repository;

  RecipeService({required RecipeRepository repository})
      : _repository = repository;

  Future<Recipe?> getRecipe(String id) async {
    return await _repository.getById(id);
  }
}

// Registration
container.registerLazySingleton<RecipeService>(
  () => RecipeService(
    repository: container<RecipeRepository>(),
  ),
);
```

**Service with Multiple Dependencies**:
```dart
class SocialRecipeService {
  final SocialRecipeRepository _repository;
  final UserService _userService;
  final PermissionService _permissionService;
  final Logger _logger;

  SocialRecipeService({
    required SocialRecipeRepository repository,
    required UserService userService,
    required PermissionService permissionService,
    required Logger logger,
  }) : _repository = repository,
       _userService = userService,
       _permissionService = permissionService,
       _logger = logger;
}

// Registration
container.registerLazySingleton<SocialRecipeService>(
  () => SocialRecipeService(
    repository: container<SocialRecipeRepository>(),
    userService: container<UserService>(),
    permissionService: container<PermissionService>(),
    logger: container<Logger>(),
  ),
);
```

### Benefits of Constructor Injection

1. **Explicit Dependencies**:
   ```dart
   // Clear what dependencies service needs
   RecipeService({
     required RecipeRepository repository,  // Easy to see
     required UserService userService,      // Dependencies are explicit
   })
   ```

2. **Easy to Test**:
   ```dart
   // Test: Just pass mocks to constructor
   test('getRecipe returns recipe', () {
     final service = RecipeService(
       repository: mockRepository,  // Mock injected
       userService: mockUserService,
     );

     // Test service...
   });
   ```

3. **Type-Safe at Compile Time**:
   ```dart
   // Compiler enforces dependencies
   RecipeService(
     repository: container<RecipeRepository>(),
     // Forgot userService? → Compile error!
   )
   ```

4. **Clear Dependency Graph**:
   ```dart
   // Easy to see: RecipeService → RecipeRepository + UserService
   // Helps understand architecture
   ```

### Best Practices

1. **Use in DI modules** - All service registrations use constructor injection
2. **Inject interfaces** - Depend on abstractions, not concrete types
3. **Keep constructors lean** - No logic, just assignment
4. **All dependencies via constructor** - Don't mix with ServiceLocator in same class

### Example: Content Module Services

```dart
void registerContentModule(GetIt container) {
  // Repository: Injected with Core Module services
  container.registerLazySingleton<RecipeRepository>(
    () => FirebaseRecipeRepository(
      firestore: container<FirestoreRepository>(),  // Constructor injection
      authRepository: container<AuthRepository>(),  // Constructor injection
    ),
  );

  // Service: Injected with Repository + Core services
  container.registerLazySingleton<UnifiedRecipeService>(
    () => UnifiedRecipeService(
      personalRepository: container<RecipeRepository>(),  // Constructor injection
      authRepository: container<AuthRepository>(),        // Constructor injection
      logger: container<Logger>(),                        // Constructor injection
    ),
  );
}
```

**Result**: Clear dependency graph, easy to test, type-safe

---

## Pattern 2: ServiceLocator.get<T>() (For Runtime Access)

### When to Use

**Use ServiceLocator.get<T>() when**:
- ✅ In widgets (accessing services for UI)
- ✅ In ViewModels (late initialization)
- ✅ Lazy dependencies (avoiding circular deps during DI setup)
- ✅ Runtime-determined dependencies
- ✅ Cross-module dependencies that would create circular refs

**When NOT to use**:
- ❌ When registering services in DI modules (use constructor injection)
- ❌ When dependency is known at construction time
- ❌ When you want explicit dependency tracking

### Syntax

```dart
import 'package:butlery/core/providers/application_provider.dart';

// Access service at runtime
final service = ServiceLocator.get<RecipeService>();
```

### Examples

**In Widgets**:
```dart
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    // Access service in build method
    final recipeService = ServiceLocator.get<UnifiedRecipeService>();

    return Consumer<RecipeViewModel>(
      builder: (context, viewModel, _) {
        return RecipeListContent(viewModel: viewModel);
      },
    );
  }
}

// Or with Provider
ChangeNotifierProvider(
  create: (_) => ServiceLocator.get<RecipeViewModel>(),
  child: RecipeListView(),
)
```

**In ViewModels (Late Initialization)**:
```dart
class RecipeViewModel extends ChangeNotifier {
  late final RecipeService _service;
  late final UserService _userService;

  RecipeViewModel() {
    // Lazy initialization (avoids circular deps during DI setup)
    _service = ServiceLocator.get<RecipeService>();
    _userService = ServiceLocator.get<UserService>();
  }

  Future<void> loadRecipes() async {
    _recipes = await _service.getUserRecipes();
    notifyListeners();
  }
}
```

**Cross-Module Dependencies**:
```dart
class ServiceA {
  late final ServiceB _serviceB;

  ServiceA() {
    // ServiceB is in different module
    // Late initialization prevents circular ref during DI setup
    _serviceB = ServiceLocator.get<ServiceB>();
  }
}
```

### Benefits of ServiceLocator

1. **Avoids Circular Dependencies**:
   ```dart
   // Service A and B depend on each other
   // Late initialization prevents infinite loop during DI setup

   class ServiceA {
     late final ServiceB _serviceB;
     ServiceA() {
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

2. **Flexible Runtime Access**:
   ```dart
   // Determine which service to use at runtime
   final service = userIsPro
       ? ServiceLocator.get<ProRecipeService>()
       : ServiceLocator.get<BasicRecipeService>();
   ```

3. **No Provider Boilerplate**:
   ```dart
   // Don't need to pass services through widget tree
   class MyWidget extends StatelessWidget {
     @override
     Widget build(BuildContext context) {
       // Access anywhere, anytime
       final service = ServiceLocator.get<MyService>();
       return ...;
     }
   }
   ```

4. **Works When Dependency Needed Later**:
   ```dart
   // ViewModel created, but service not needed until method called
   class MyViewModel {
     late final MyService _service;

     void initialize() {
       _service = ServiceLocator.get<MyService>();
     }

     void doSomething() {
       _service.performAction(); // Service accessed when needed
     }
   }
   ```

### Best Practices

1. **Use in widgets** - ServiceLocator is widget-friendly
2. **Use in ViewModels** - Late initialization prevents circular deps
3. **Import ApplicationProvider** - Always import for ServiceLocator
4. **Document why** - Comment why ServiceLocator used vs constructor injection

### Example: Widget with ServiceLocator

```dart
import 'package:butlery/core/providers/application_provider.dart';

class RecipeDetailView extends StatelessWidget {
  final String recipeId;

  const RecipeDetailView({required this.recipeId});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) {
        // Access ViewModel via ServiceLocator
        final viewModel = ServiceLocator.get<RecipeDetailViewModel>();
        viewModel.loadRecipe(recipeId);
        return viewModel;
      },
      child: Consumer<RecipeDetailViewModel>(
        builder: (context, viewModel, _) {
          return LoadingStateBuilder<Recipe>(
            isLoading: viewModel.isLoading,
            error: viewModel.error,
            data: viewModel.recipe,
            builder: (context, recipe) {
              return RecipeDetailContent(recipe: recipe);
            },
          );
        },
      ),
    );
  }
}
```

---

## Decision Tree: Which Pattern to Use?

```
Where are you accessing the service?

├─ In DI module registration?
│   └─ Use: Constructor Injection
│       Example: container.registerLazySingleton<Service>(
│                  () => Service(repo: container<Repo>())
│                )
│
├─ In a Widget?
│   └─ Use: ServiceLocator.get<T>()
│       Example: final service = ServiceLocator.get<Service>();
│
├─ In a ViewModel?
│   ├─ Can inject via constructor? (no circular deps)
│   │   └─ Use: Constructor Injection (optional)
│   │       Example: ViewModel({required Service service})
│   │
│   └─ Need late initialization?
│       └─ Use: ServiceLocator.get<T>()
│           Example: late final _service = ServiceLocator.get<Service>();
│
└─ Circular dependency risk?
    └─ Use: ServiceLocator.get<T>() (late initialization)
```

## Comparing Both Patterns

### Example: RecipeService

**Pattern 1: Constructor Injection** (in DI module):
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

**Pattern 2: ServiceLocator** (in widget):
```dart
// Widget accessing service
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final recipeService = ServiceLocator.get<RecipeService>();

    return FutureBuilder(
      future: recipeService.getUserRecipes(),
      builder: (context, snapshot) => ...,
    );
  }
}
```

**Both patterns access the SAME service instance** (RecipeService is a singleton).

---

## Anti-Patterns to Avoid

### Anti-Pattern 1: ServiceLocator in Constructor During DI Registration

**❌ WRONG**:
```dart
// DON'T use ServiceLocator when registering services
container.registerLazySingleton<RecipeService>(
  () => RecipeService(
    repository: ServiceLocator.get<RecipeRepository>(),  // WRONG!
  ),
);
```

**Why wrong**:
- Creates tight coupling
- Harder to test
- Circular dependency risks
- Use `container<T>()` instead

**✅ RIGHT**:
```dart
container.registerLazySingleton<RecipeService>(
  () => RecipeService(
    repository: container<RecipeRepository>(),  // Use container<T>()
  ),
);
```

### Anti-Pattern 2: Mixing Patterns in Same Constructor

**❌ WRONG**:
```dart
class RecipeService {
  final RecipeRepository _repository;
  late final UserService _userService;

  RecipeService({required RecipeRepository repository})
      : _repository = repository {
    // Mixing constructor injection with ServiceLocator in constructor
    _userService = ServiceLocator.get<UserService>();  // Confusing!
  }
}
```

**Why wrong**:
- Inconsistent pattern
- Hard to understand dependencies
- Some dependencies explicit, some hidden

**✅ RIGHT - Option A (All constructor injection)**:
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

**✅ RIGHT - Option B (All ServiceLocator)**:
```dart
class RecipeService {
  late final RecipeRepository _repository;
  late final UserService _userService;

  RecipeService() {
    _repository = ServiceLocator.get<RecipeRepository>();
    _userService = ServiceLocator.get<UserService>();
  }
}
```

### Anti-Pattern 3: Direct Firestore Access

**❌ WRONG**:
```dart
class RecipeService {
  Future<Recipe?> getRecipe(String id) async {
    // Bypassing repository pattern and DI
    final firestore = FirebaseFirestore.instance;  // WRONG!
    final doc = await firestore.collection('recipes').doc(id).get();
    return Recipe.fromFirestore(doc);
  }
}
```

**Why wrong**:
- Bypasses repository layer
- Destroys testability
- Violates architecture

**✅ RIGHT**:
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

**✅ ACCEPTABLE EXCEPTION** (accessing via injected repository):
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

### Anti-Pattern 4: Provider for Services (Instead of DI)

**❌ WRONG**:
```dart
// Using Provider to provide services (bypassing DI)
Provider<RecipeService>(
  create: (_) => RecipeService(...),  // Recreated every time
  child: MyApp(),
)
```

**Why wrong**:
- Provider creates new instance (not singleton)
- Bypasses DI system
- Hard to test

**✅ RIGHT**:
```dart
// Services registered in DI, accessed via ServiceLocator
// Provider only for ViewModels
ChangeNotifierProvider(
  create: (_) => ServiceLocator.get<RecipeViewModel>(),  // ViewModel from DI
  child: RecipeListView(),
)
```

## Testing Both Patterns

### Testing Constructor Injection

```dart
test('RecipeService uses injected repository', () async {
  // Create mock
  final mockRepository = MockRecipeRepository();
  when(() => mockRepository.getById(any()))
      .thenAnswer((_) async => testRecipe);

  // Inject mock via constructor
  final service = RecipeService(
    repository: mockRepository,
    userService: mockUserService,
  );

  // Test
  final result = await service.getRecipe('recipe-123');

  expect(result, testRecipe);
  verify(() => mockRepository.getById('recipe-123')).called(1);
});
```

### Testing ServiceLocator Access

```dart
test('Widget accesses service via ServiceLocator', () async {
  // Setup test service locator
  await TestServiceLocator.setup();

  // Register mock
  TestServiceLocator.registerMock<RecipeService>(mockRecipeService);

  // Widget will access via ServiceLocator.get<RecipeService>()
  await tester.pumpWidget(
    MaterialApp(home: RecipeListView()),
  );

  // Verify service was accessed
  verify(() => mockRecipeService.getUserRecipes()).called(1);

  // Cleanup
  await TestServiceLocator.reset();
});
```

## Best Practices Summary

1. **Constructor injection in DI modules** - Explicit dependencies
2. **ServiceLocator in widgets** - Flexible runtime access
3. **ServiceLocator in ViewModels** - Late initialization prevents circular deps
4. **Never mix patterns** - Choose one per class
5. **Never bypass DI** - No direct FirebaseFirestore.instance
6. **Test with mocks** - Inject mocks for testing
7. **Document exceptions** - Comment why ServiceLocator used

## Quick Reference

| Scenario | Pattern | Example |
|----------|---------|---------|
| Registering service in DI module | Constructor Injection | `MyService({required Repo repo})` |
| Accessing service in widget | ServiceLocator | `ServiceLocator.get<MyService>()` |
| Accessing service in ViewModel | ServiceLocator (late) | `late final _service = ServiceLocator.get<>()` |
| Circular dependency | ServiceLocator | `late final _serviceB = ServiceLocator.get<>()` |
| Testing | Constructor Injection | `MyService(repository: mockRepo)` |

## Related Resources

- [module-structure.md](module-structure.md) - 7 modules and their services
- [registration-patterns.md](registration-patterns.md) - Singleton vs lazy vs factory
- [testing-with-di.md](testing-with-di.md) - Testing with mocks

---

**Impact**: Correct pattern usage → testable, maintainable code
**Rule**: Constructor injection in DI, ServiceLocator in widgets/ViewModels
**Testing**: Both patterns support mocking for tests
