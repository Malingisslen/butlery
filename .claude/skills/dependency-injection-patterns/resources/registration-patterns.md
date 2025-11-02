# Registration Patterns - Singleton vs Lazy vs Factory

Comprehensive guide to choosing the correct registration pattern for dependency injection in Butlery.

## Overview

GetIt supports three main registration patterns:
- **registerSingleton** - Eager initialization (created immediately)
- **registerLazySingleton** - Lazy initialization (created on first access)
- **registerFactory** - New instance per access (not singleton)

**Key Decision**: When to use each pattern?

## Registration Patterns Comparison

| Pattern | Created When | Instance Count | Use Case |
|---------|--------------|----------------|----------|
| `registerSingleton` | Module load | 1 (eager) | Core infrastructure |
| `registerLazySingleton` | First access | 1 (lazy) | Most services |
| `registerFactory` | Each access | N (per call) | ViewModels, disposables |

## 1. Eager Singleton (registerSingleton)

### When to Use

**Use eager singletons for**:
- ✅ Core infrastructure (Auth, Storage, Firestore)
- ✅ Services needed at app startup
- ✅ Lightweight services (no heavy I/O)
- ✅ No circular dependency risks
- ✅ Services that configure other services

**When NOT to use**:
- ❌ Services with heavy initialization
- ❌ Services that depend on other lazy services
- ❌ Services not needed immediately
- ❌ Cross-module dependencies

### Syntax

```dart
container.registerSingleton<T>(
  ConcreteType(...), // Instance created NOW
);
```

### Examples

**Core Infrastructure**:
```dart
// Firestore - needed immediately for all database operations
container.registerSingleton<FirestoreRepository>(
  FirebaseFirestoreRepository(),
);

// Auth - needed immediately for permission checks
container.registerSingleton<AuthRepository>(
  FirebaseAuthRepository(),
);

// Logger - needed immediately for logging
container.registerSingleton<Logger>(
  Logger(),
);
```

**Configuration Services**:
```dart
// Analytics - configure immediately
container.registerSingleton<AnalyticsService>(
  FirebaseAnalyticsService(),
);

// Connectivity - start monitoring immediately
container.registerSingleton<ConnectivityService>(
  ConnectivityService(),
);
```

### Characteristics

**Timing**:
- Instance created when `registerSingleton` is called
- Happens during module initialization
- Before app UI is shown

**Memory**:
- Instance exists in memory immediately
- Cannot be freed (singleton for app lifetime)

**Performance**:
- Adds to startup time (every eager singleton increases init time)
- Subsequent access is instant (already created)

**Dependencies**:
- Can only depend on services registered BEFORE it
- Cannot have circular dependencies

### Best Practices

1. **Minimize eager singletons** - Only use for truly needed services
2. **Register in order** - Dependencies before dependents
3. **Lightweight only** - No heavy I/O or network calls
4. **Core Module only** - Rare outside Core Module

### Example: Core Module (Eager Singletons)

```dart
void registerCoreModule(GetIt container) {
  // 1. Firestore (no dependencies)
  container.registerSingleton<FirestoreRepository>(
    FirebaseFirestoreRepository(),
  );

  // 2. Auth (no dependencies)
  container.registerSingleton<AuthRepository>(
    FirebaseAuthRepository(),
  );

  // 3. Storage (no dependencies)
  container.registerSingleton<StorageRepository>(
    FirebaseStorageRepository(
      storage: FirebaseStorage.instance,
    ),
  );

  // 4. Logger (no dependencies)
  container.registerSingleton<Logger>(
    Logger(),
  );

  // 5. Permission Service (depends on Auth - registered above)
  container.registerSingleton<PermissionService>(
    PermissionService(
      authRepository: container<AuthRepository>(), // OK - already registered
    ),
  );
}
```

**Load Time**: ~50-100ms for all Core Module services

---

## 2. Lazy Singleton (registerLazySingleton)

### When to Use

**Use lazy singletons for**:
- ✅ Most services (90% of services)
- ✅ Services with heavy initialization
- ✅ Cross-module dependencies
- ✅ Services not needed at startup
- ✅ Feature modules (Content, Social, etc.)
- ✅ Services that might create circular deps

**When NOT to use**:
- ❌ Services needed at app startup
- ❌ Services needed by eager singletons
- ❌ ViewModels (use factory instead)

### Syntax

```dart
container.registerLazySingleton<T>(
  () => ConcreteType(...), // Instance created on first access
);
```

### Examples

**Content Services**:
```dart
// Recipe service - not needed until user opens recipes
container.registerLazySingleton<UnifiedRecipeService>(
  () => UnifiedRecipeService(
    personalRepository: container<RecipeRepository>(),
    socialRepository: container<SocialRecipeRepository>(),
  ),
);

// Menu service - not needed until user opens menus
container.registerLazySingleton<UnifiedMenuService>(
  () => UnifiedMenuService(
    menuRepository: container<MenuRepository>(),
  ),
);
```

**Social Services**:
```dart
// Friends service - not needed until user opens friends tab
container.registerLazySingleton<UnifiedFriendsService>(
  () => UnifiedFriendsService(
    friendsRepository: container<FriendsRepository>(),
    userService: container<UserService>(),
  ),
);
```

**Repositories**:
```dart
// All repositories are lazy (created when first accessed)
container.registerLazySingleton<RecipeRepository>(
  () => FirebaseRecipeRepository(
    firestore: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);
```

### Characteristics

**Timing**:
- Instance created on first `container.get<T>()` call
- Not created during module initialization
- Subsequent access returns same instance

**Memory**:
- No memory used until first access
- Instance persists after creation (singleton)
- Better startup performance

**Performance**:
- No startup time impact
- First access is slightly slower (creation + registration)
- Subsequent access is instant

**Dependencies**:
- Can depend on ANY registered service (lazy prevents circular deps)
- Circular dependencies between lazy singletons are OK

### Best Practices

1. **Default choice** - Use lazy singleton unless you have reason not to
2. **All feature modules** - Content, Social, Messaging, etc.
3. **All repositories** - Repository creation can be lazy
4. **Services with cross-module deps** - Lazy prevents circular ref issues

### Example: Content Module (Lazy Singletons)

```dart
void registerContentModule(GetIt container) {
  // All repositories lazy
  container.registerLazySingleton<RecipeRepository>(
    () => FirebaseRecipeRepository(
      firestore: container<FirestoreRepository>(), // Core Module service
      authRepository: container<AuthRepository>(), // Core Module service
    ),
  );

  container.registerLazySingleton<MenuRepository>(
    () => FirebaseMenuRepository(
      firestore: container<FirestoreRepository>(),
      authRepository: container<AuthRepository>(),
    ),
  );

  // All services lazy
  container.registerLazySingleton<UnifiedRecipeService>(
    () => UnifiedRecipeService(
      personalRepository: container<RecipeRepository>(), // Will create if not exists
      authRepository: container<AuthRepository>(),
      logger: container<Logger>(),
    ),
  );

  container.registerLazySingleton<UnifiedMenuService>(
    () => UnifiedMenuService(
      menuRepository: container<MenuRepository>(),
      authRepository: container<AuthRepository>(),
    ),
  );
}
```

**Load Time**: 0ms at startup, 10-20ms on first access per service

### Handling Circular Dependencies with Lazy

**Problem**: Service A needs Service B, Service B needs Service A

**Solution**: Lazy initialization prevents circular ref during construction

```dart
// Both services registered as lazy
container.registerLazySingleton<ServiceA>(
  () => ServiceA(
    serviceB: container<ServiceB>(), // Will create ServiceB if needed
  ),
);

container.registerLazySingleton<ServiceB>(
  () => ServiceB(
    serviceA: container<ServiceA>(), // Will create ServiceA if needed
  ),
);

// First access to ServiceA:
// 1. Creates ServiceA
// 2. Needs ServiceB → creates ServiceB
// 3. ServiceB needs ServiceA → returns already-being-created ServiceA instance
// No infinite loop!
```

**Key**: Lazy singletons are "registered" before "created", so circular references work.

---

## 3. Factory (registerFactory)

### When to Use

**Use factory for**:
- ✅ ViewModels (new instance per screen)
- ✅ Disposable services
- ✅ Stateful components needing fresh state
- ✅ Short-lived objects

**When NOT to use**:
- ❌ Long-lived services (use singleton instead)
- ❌ Expensive-to-create objects (unless needed)
- ❌ Services needing shared state

### Syntax

```dart
container.registerFactory<T>(
  () => ConcreteType(...), // New instance EVERY time
);
```

### Examples

**ViewModels**:
```dart
// Each screen gets fresh ViewModel instance
container.registerFactory<RecipeViewModel>(
  () => RecipeViewModel(
    service: container<UnifiedRecipeService>(),
  ),
);

container.registerFactory<RecipeDetailViewModel>(
  () => RecipeDetailViewModel(
    service: container<UnifiedRecipeService>(),
    socialService: container<SocialRecipeService>(),
  ),
);

container.registerFactory<FriendsViewModel>(
  () => FriendsViewModel(
    service: container<UnifiedFriendsService>(),
  ),
);
```

**Widget Usage**:
```dart
// Each widget creation gets new ViewModel
ChangeNotifierProvider(
  create: (_) => ServiceLocator.get<RecipeViewModel>(), // Calls factory
  child: RecipeListView(),
)

// Navigation to different screen
Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<RecipeDetailViewModel>(), // New instance
      child: RecipeDetailView(),
    ),
  ),
)
```

### Characteristics

**Timing**:
- Instance created on every `container.get<T>()` call
- No caching (new instance every time)

**Memory**:
- Multiple instances can exist simultaneously
- Each widget gets independent ViewModel
- Instances should be disposed when done

**Performance**:
- Creating instance on every access
- Slight overhead (but ViewModels are lightweight)

**Dependencies**:
- Services injected are singletons (shared across ViewModels)
- Each ViewModel is independent

### Best Practices

1. **ViewModels only** - Rare outside UI layer
2. **Dispose properly** - ViewModel.dispose() when widget disposes
3. **Lightweight objects** - Factory objects should be cheap to create
4. **Share services** - Inject singleton services, not factories

### Example: UI Module (Factory Pattern)

```dart
void registerUIModule(GetIt container) {
  // All ViewModels use factory pattern
  container.registerFactory<RecipeViewModel>(
    () => RecipeViewModel(
      service: container<UnifiedRecipeService>(), // Singleton service
    ),
  );

  container.registerFactory<RecipeDetailViewModel>(
    () => RecipeDetailViewModel(
      service: container<UnifiedRecipeService>(),
      socialService: container<SocialRecipeService>(),
    ),
  );

  container.registerFactory<MenuViewModel>(
    () => MenuViewModel(
      service: container<UnifiedMenuService>(),
    ),
  );

  container.registerFactory<UnifiedShoppingViewModel>(
    () => UnifiedShoppingViewModel(
      service: container<UnifiedShoppingService>(),
    ),
  );

  // 20-30 more ViewModels...
}
```

**Instance Creation**: <1ms per ViewModel (lightweight)

---

## Decision Tree

```
Is this a ViewModel?
├─ YES → registerFactory (new instance per screen)
└─ NO → Is it core infrastructure (Auth, Firestore, Logger)?
    ├─ YES → registerSingleton (eager, needed at startup)
    └─ NO → registerLazySingleton (lazy, most services)
```

### Detailed Decision Tree

```
1. Is it a ViewModel?
   ├─ YES → registerFactory
   └─ NO → Continue

2. Is it core infrastructure (Auth, Storage, Firestore, Logger)?
   ├─ YES → Is it lightweight (<10ms creation)?
   │   ├─ YES → registerSingleton (eager)
   │   └─ NO → registerLazySingleton
   └─ NO → Continue

3. Is it needed at app startup?
   ├─ YES → Is there circular dependency risk?
   │   ├─ YES → registerLazySingleton
   │   └─ NO → registerSingleton
   └─ NO → Continue

4. Default: registerLazySingleton
```

## Registration Pattern Examples by Module

### Core Module (Eager Singletons)

```dart
registerSingleton<FirestoreRepository>(...)    ✅ Eager (core infrastructure)
registerSingleton<AuthRepository>(...)         ✅ Eager (core infrastructure)
registerSingleton<Logger>(...)                 ✅ Eager (core infrastructure)
registerSingleton<ConnectivityService>(...)    ✅ Eager (lightweight utility)
```

### Content Module (Lazy Singletons)

```dart
registerLazySingleton<RecipeRepository>(...)      ✅ Lazy (feature repository)
registerLazySingleton<MenuRepository>(...)        ✅ Lazy (feature repository)
registerLazySingleton<UnifiedRecipeService>(...)  ✅ Lazy (feature service)
registerLazySingleton<PhotoImportService>(...)    ✅ Lazy (not needed at startup)
```

### Social Module (Lazy Singletons)

```dart
registerLazySingleton<FriendsRepository>(...)     ✅ Lazy (feature repository)
registerLazySingleton<UnifiedFriendsService>(...) ✅ Lazy (feature service)
registerLazySingleton<SocialRecipeService>(...)   ✅ Lazy (cross-module deps)
```

### UI Module (Factory Pattern)

```dart
registerFactory<RecipeViewModel>(...)          ✅ Factory (new instance per screen)
registerFactory<RecipeDetailViewModel>(...)    ✅ Factory (new instance per screen)
registerFactory<FriendsViewModel>(...)         ✅ Factory (new instance per screen)
```

## Common Mistakes

### Mistake 1: Using Singleton for ViewModels

```dart
// ❌ WRONG - ViewModel as singleton
container.registerSingleton<RecipeViewModel>(
  RecipeViewModel(service: container<RecipeService>()),
);

// Problem: All screens share same ViewModel instance
// Result: State leaks between screens, data conflicts

// ✅ RIGHT - ViewModel as factory
container.registerFactory<RecipeViewModel>(
  () => RecipeViewModel(service: container<RecipeService>()),
);
```

### Mistake 2: Using Eager Singleton for Heavy Services

```dart
// ❌ WRONG - Eager singleton for heavy service
container.registerSingleton<RecipeService>(
  RecipeService(
    repository: container<RecipeRepository>(),
    // Heavy initialization: loads all recipes, sets up streams
  ),
);

// Problem: Adds 500ms to startup time
// User doesn't see app until RecipeService is created

// ✅ RIGHT - Lazy singleton
container.registerLazySingleton<RecipeService>(
  () => RecipeService(...),
);

// Result: App starts instantly, RecipeService created when first needed
```

### Mistake 3: Circular Dependencies with Eager Singletons

```dart
// ❌ WRONG - Circular dependency with eager singletons
container.registerSingleton<ServiceA>(
  ServiceA(serviceB: container<ServiceB>()), // Needs ServiceB NOW
);

container.registerSingleton<ServiceB>(
  ServiceB(serviceA: container<ServiceA>()), // Needs ServiceA NOW
);

// Result: Stack overflow during initialization

// ✅ RIGHT - Use lazy singletons
container.registerLazySingleton<ServiceA>(
  () => ServiceA(serviceB: container<ServiceB>()),
);

container.registerLazySingleton<ServiceB>(
  () => ServiceB(serviceA: container<ServiceA>()),
);

// Result: No circular dependency issue (lazy prevents infinite loop)
```

## Testing Different Registration Patterns

### Testing Eager Singletons

```dart
test('eager singleton creates instance immediately', () {
  final container = GetIt.instance;

  // Register eager singleton
  container.registerSingleton<Logger>(Logger());

  // Instance exists before first access
  expect(container.isRegistered<Logger>(), isTrue);

  // Access returns same instance
  final logger1 = container<Logger>();
  final logger2 = container<Logger>();
  expect(identical(logger1, logger2), isTrue);
});
```

### Testing Lazy Singletons

```dart
test('lazy singleton creates instance on first access', () {
  final container = GetIt.instance;

  var creationCount = 0;

  // Register lazy singleton
  container.registerLazySingleton<RecipeService>(
    () {
      creationCount++;
      return RecipeService(repository: mockRepository);
    },
  );

  // Not created yet
  expect(creationCount, 0);

  // First access creates instance
  final service1 = container<RecipeService>();
  expect(creationCount, 1);

  // Second access returns same instance (no new creation)
  final service2 = container<RecipeService>();
  expect(creationCount, 1); // Still 1
  expect(identical(service1, service2), isTrue);
});
```

### Testing Factory Pattern

```dart
test('factory creates new instance on each access', () {
  final container = GetIt.instance;

  var creationCount = 0;

  // Register factory
  container.registerFactory<RecipeViewModel>(
    () {
      creationCount++;
      return RecipeViewModel(service: mockService);
    },
  );

  // First access creates instance
  final viewModel1 = container<RecipeViewModel>();
  expect(creationCount, 1);

  // Second access creates NEW instance
  final viewModel2 = container<RecipeViewModel>();
  expect(creationCount, 2); // Incremented
  expect(identical(viewModel1, viewModel2), isFalse); // Different instances
});
```

## Performance Comparison

| Pattern | Startup Impact | First Access | Subsequent Access | Memory |
|---------|----------------|--------------|-------------------|--------|
| Eager Singleton | High (adds to startup) | Instant | Instant | Always allocated |
| Lazy Singleton | None | Slow (creation) | Instant | Allocated on first use |
| Factory | None | Slow (creation) | Slow (creation) | Multiple instances |

**Recommendation**: Use lazy singletons for 90% of services.

## Best Practices Summary

1. **Eager singletons**: Core infrastructure only (5-10 services)
2. **Lazy singletons**: Most services (40-50 services)
3. **Factory**: ViewModels only (20-30 ViewModels)
4. **Minimize eager**: Each eager singleton adds to startup time
5. **Default to lazy**: When in doubt, use lazy singleton
6. **Test registration**: Verify correct pattern is used

## Related Resources

- [module-structure.md](module-structure.md) - Which module to register in
- [service-access-patterns.md](service-access-patterns.md) - How to access services
- [testing-with-di.md](testing-with-di.md) - Testing with DI

---

**Impact**: Choose correct pattern → faster startup, better performance
**Rule of Thumb**: Lazy singleton unless you have specific reason for eager/factory
**Performance**: Lazy singletons reduce startup time by 200-500ms
