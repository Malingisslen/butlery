# ADR-002: Use GetIt for Dependency Injection

**Status**: Accepted
**Date**: 2024-Q3 (Retroactive documentation 2025-11-17)
**Deciders**: Core development team
**Technical Story**: Need service locator pattern for 150+ services and 30+ repositories

---

## Context

Butlery's MVVM architecture (see ADR-001) requires **dependency injection** to wire together:

- **60+ ViewModels** (registered for Provider access)
- **150+ Services** (business logic orchestration)
- **30+ Repositories** (Firebase data access)
- **Cross-cutting concerns** (Auth, Analytics, Logging, Caching)

**Requirements**:
- **Type-safe** dependency resolution
- **Lazy loading** - services created only when needed
- **Singleton management** - single instance per service
- **Testability** - easy mock registration for tests
- **Circular dependency prevention** - avoid initialization deadlocks
- **Low boilerplate** - minimal setup code
- **No code generation** - avoid build runner complexity

**Current Scale**:
- 150+ services registered in DI container
- 7 domain modules (see ADR-004)
- ~240 total registrations (ViewModels + Services + Repositories)

---

## Decision

**We will use GetIt service locator with lazy singletons and modular registration.**

```dart
// Access pattern
import 'package:butlery/core/providers/application_provider.dart';

final recipeService = ServiceLocator.get<UnifiedRecipeService>();
```

**Key Patterns**:

### 1. Lazy Singleton Registration
```dart
container.registerLazySingleton<RecipeService>(
  () => RecipeService(
    repository: container<RecipeRepository>(),
    userService: container<UserService>(),
  ),
);
```
- Service created on first `ServiceLocator.get<RecipeService>()` call
- Subsequent calls return same instance
- Avoids circular dependencies during startup

### 2. Eager Singleton Registration (Core Infrastructure Only)
```dart
container.registerSingleton<AuthRepository>(
  FirebaseAuthRepository(),
);
```
- Service created immediately during DI setup
- Used only for Core Module (Auth, Storage, Firestore)
- Guarantees availability at app startup

### 3. Modular Organization (7 Modules)
- See [ADR-004](ADR-004-seven-domain-modules.md) for module structure
- Each module registers its own services
- ApplicationBootstrap orchestrates initialization

---

## Alternatives Considered

### 1. **Provider (flutter/provider package)**
- ❌ **Rejected**: Designed for STATE management, not SERVICE registration
- ❌ Requires widget tree access for registration
- ❌ Difficult to access services outside widget context
- ❌ Verbose for 150+ services (MultiProvider with 150 entries)
- ✅ **Still used**: For ChangeNotifier ViewModels in widget tree
- **Verdict**: Keep Provider for ViewModels, use GetIt for Services

### 2. **InheritedWidget (Flutter's built-in)**
- ❌ **Rejected**: Too low-level and boilerplate-heavy
- ❌ Manual caching required
- ❌ Type-casting needed
- ❌ No singleton lifecycle management
- **Verdict**: Provider is better abstraction over InheritedWidget

### 3. **Riverpod**
- ❌ **Rejected**: Requires complete rewrite from Provider
- ❌ Different mental model (Ref, watch, read, listen)
- ❌ Team unfamiliar with Riverpod patterns
- ⚠️ Excellent for new projects, but migration cost too high
- **Verdict**: Too disruptive to migrate from existing Provider setup

### 4. **injectable + get_it (Code Generation)**
- ❌ **Rejected**: Requires build runner
- ❌ Adds build complexity and time
- ❌ Annotations clutter code
- ⚠️ Reduces boilerplate, but not worth code generation overhead
- **Verdict**: Manual GetIt registration is acceptable for our scale

### 5. **Manual Singleton Pattern**
- ❌ **Rejected**: 150+ static instances
- ❌ No testability (can't replace with mocks)
- ❌ No lifecycle management
- ❌ Difficult to manage dependencies
- **Verdict**: DI container is essential

### 6. **Constructor Injection Only (No Service Locator)**
- ❌ **Rejected**: Requires passing dependencies through entire widget tree
- ❌ Extremely verbose for deep component trees
- ❌ Widgets need access to 5-10 services (too many parameters)
- ⚠️ Ideal pattern, but impractical for Flutter widgets
- **Verdict**: Service Locator is pragmatic compromise for Flutter

---

## Consequences

### Positive

✅ **Simplicity**:
- Clean API: `ServiceLocator.get<T>()`
- No code generation
- No annotations
- Minimal learning curve

✅ **Type Safety**:
- Compile-time type checking
- No string-based lookups
- IDE autocomplete support

✅ **Testability**:
```dart
// Easy mock registration
setUp(() {
  ServiceLocator.unregister<RecipeService>();
  ServiceLocator.register<RecipeService>(MockRecipeService());
});
```

✅ **Lazy Loading**:
- Services created only when needed
- Faster app startup (don't initialize all 150 services immediately)
- Prevents circular dependency deadlocks

✅ **Singleton Management**:
- Guaranteed single instance per service
- No manual instance tracking
- Clear lifecycle

✅ **Scalability**:
- Successfully scaled to 150+ services
- No performance issues
- Easy to add new services

✅ **No Build Runner**:
- Faster builds
- No generated code to maintain
- No annotation processing complexity

### Negative

⚠️ **Manual Registration Boilerplate**:
```dart
// Must manually register 240+ services
container.registerLazySingleton<RecipeService>(...);
container.registerLazySingleton<MenuService>(...);
// ... 238 more registrations
```
- **Mitigation**: Organized into 7 modules (see ADR-004)
- **Mitigation**: Registration is one-time cost

⚠️ **Service Locator is Anti-Pattern (Fowler)**:
- Martin Fowler calls Service Locator "a poor man's DI"
- Hides dependencies (not explicit in constructor)
- Can lead to tight coupling if overused
- **Mitigation**: Use constructor injection for DI registration, Service Locator for runtime access
- **Mitigation**: Strict rule: Only access via ServiceLocator in Views and ViewModels

⚠️ **No Compile-Time Dependency Graph**:
- Can't detect circular dependencies until runtime
- No static analysis of dependency tree
- **Mitigation**: Lazy singletons prevent circular initialization
- **Mitigation**: Clear module boundaries (see ADR-004)

⚠️ **Global State**:
- GetIt container is global singleton
- Potential for accidental state sharing
- **Mitigation**: All services are stateless or manage state via ChangeNotifier
- **Mitigation**: Clear ownership rules (Services own business state, ViewModels own UI state)

⚠️ **Runtime Errors for Missing Registrations**:
```dart
// Throws at runtime if RecipeService not registered
final service = ServiceLocator.get<RecipeService>();
```
- **Mitigation**: Comprehensive integration tests
- **Mitigation**: ApplicationBootstrap verifies all registrations at startup

---

## Implementation Guidelines

### 1. Registration Patterns

**Use Lazy Singletons (Preferred)**:
```dart
container.registerLazySingleton<SocialRecipeService>(
  () => SocialRecipeService(
    repository: container<SocialRecipeRepository>(),
    userService: container<UserService>(),
  ),
);
```
- For most services (Feature modules)
- Prevents circular dependencies
- Faster startup

**Use Eager Singletons (Core Only)**:
```dart
container.registerSingleton<AuthRepository>(
  FirebaseAuthRepository(),
);
```
- Only for Core Module infrastructure
- When service must be available immediately

### 2. Access Patterns

**Constructor Injection (DI Registration)**:
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
- ✅ Use in DI module registration
- ✅ Makes dependencies explicit

**ServiceLocator.get<T>() (Runtime Access)**:
```dart
class RecipeListView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final recipeService = ServiceLocator.get<UnifiedRecipeService>();
    // ...
  }
}
```
- ✅ Use in Views and ViewModels
- ✅ Prevents deep constructor chains

### 3. Testing Pattern

```dart
setUp(() {
  // Clear all registrations
  ServiceLocator.reset();

  // Register mocks
  ServiceLocator.register<RecipeService>(MockRecipeService());
  ServiceLocator.register<UserService>(MockUserService());
});

tearDown(() {
  ServiceLocator.reset();
});
```

---

## Migration Path (If Needed)

If GetIt becomes a bottleneck:

1. **Short-term**: Add injectable code generation
   - Reduces manual registration boilerplate
   - Keeps GetIt as foundation

2. **Long-term**: Migrate to Riverpod
   - Complete state management + DI solution
   - Requires full rewrite of Provider ViewModels
   - Estimated effort: 8-12 weeks

**Current Assessment**: GetIt is sufficient for current scale. No migration needed.

---

## References

- **Project Guidelines**: [CLAUDE.md](../../CLAUDE.md)
- **Module Structure**: [ADR-004: 7 Domain Modules](ADR-004-seven-domain-modules.md)
- **MVVM Pattern**: [ADR-001: MVVM + Repository Pattern](ADR-001-mvvm-repository-pattern.md)
- **GetIt Package**: [pub.dev/packages/get_it](https://pub.dev/packages/get_it)
- **Service Locator Pattern**: [Martin Fowler on Service Locator](https://martinfowler.com/articles/injection.html#UsingAServiceLocator)

---

## Related ADRs

- [ADR-001: Use MVVM + Repository Pattern](ADR-001-mvvm-repository-pattern.md) - Architecture that GetIt supports
- [ADR-004: Organize DI into 7 Domain Modules](ADR-004-seven-domain-modules.md) - How we structure GetIt registrations
