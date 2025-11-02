# Butlery Architecture Skill

## Purpose

Enforce **MVVM + Repository pattern** with strict layer separation, **7-module dependency injection**, and **layered service architecture**. This skill ensures all code follows Butlery's world-class architectural standards.

## When to Use This Skill

This skill activates automatically when:
- Creating or modifying services, repositories, ViewModels, or DI configuration
- Questions about architecture, layer separation, or dependency injection
- Refactoring code or adding new features
- Files in `lib/services/`, `lib/repositories/`, `lib/viewmodels/`, or `lib/core/di/`

## Architecture Overview

Butlery follows a strict **4-layer MVVM + Repository pattern**:

```
┌──────────────────────────────────────────────────┐
│              PRESENTATION LAYER                  │
│  Views → ViewModels (Provider pattern)          │
│  Location: lib/views/, lib/viewmodels/          │
└────────────────┬─────────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────────┐
│               BUSINESS LAYER                     │
│  Services coordinate repositories                │
│  Location: lib/services/                         │
└────────────────┬─────────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────────┐
│                DATA LAYER                        │
│  Repositories (BaseFirebaseRepository pattern)   │
│  Location: lib/repositories/                     │
└────────────────┬─────────────────────────────────┘
                 │
┌────────────────▼─────────────────────────────────┐
│            INFRASTRUCTURE                        │
│  Firebase SDK, Cloud Firestore, FCM              │
└──────────────────────────────────────────────────┘
```

### Layer Responsibilities

**Presentation Layer** (`lib/views/`, `lib/viewmodels/`, `lib/widgets/`):
- **Views**: Stateless/Stateful widgets - NO business logic
- **ViewModels**: ChangeNotifier-based state management - NO direct repository access
- **Widgets**: Reusable UI components

**Business Layer** (`lib/services/`):
- Services coordinate repositories
- Business rules and workflows
- **NO direct Firebase access** - must use repositories
- Example: `UnifiedRecipeService` orchestrates personal, social, realtime layers

**Data Layer** (`lib/repositories/`, `lib/models/`):
- Repository interfaces define contracts
- Firebase implementations with permission validation
- Models for data transfer

**Infrastructure**: Firebase SDK, network, storage, platform APIs

### Critical Rules

❌ **NEVER:**
- Use `FirebaseFirestore.instance` directly (inject `FirestoreRepository` instead)
- Use legacy `sl<T>()` pattern (use `ServiceLocator.get<T>()` instead)
- Let Views access Services directly (use ViewModels)
- Let ViewModels access Repositories directly (use Services)
- Bypass permission validation in repositories

✅ **ALWAYS:**
- Extend `BaseService` for all instance-based services
- Extend `BaseFirebaseRepository<T>` for all Firebase repositories
- Use `ServiceLocator.get<T>()` for runtime access (widgets, ViewModels)
- Use constructor injection in DI module registration
- Validate permissions on all repository CRUD operations

## Dependency Injection System

Butlery uses **GetIt service locator** with **7 modular domain modules**:

### 7 Application Modules

1. **CoreModule** (`lib/core/di/modules/core_module.dart`) - Auth, Storage, Analytics
2. **ContentModule** (`lib/core/di/modules/content_module.dart`) - Recipes, Menus, Import
3. **SocialModule** (`lib/core/di/modules/social_module.dart`) - Friends, Sharing, Comments
4. **MessagingModule** (`lib/core/di/modules/messaging_module.dart`) - Chat, Notifications
5. **CollaborationModule** (`lib/core/di/modules/collaboration_module.dart`) - Realtime, Shopping
6. **PerformanceModule** (`lib/core/di/modules/performance_module.dart`) - Cache, Monitoring
7. **UIModule** (`lib/core/di/modules/ui_module.dart`) - ViewModels, Navigation, UI State

### Service Access Patterns

**Pattern 1: Constructor Injection** (For DI module registration):
```dart
// In DI module:
container.registerSingleton<MyService>(
  MyService(
    recipeRepository: container<RecipeRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);
```

**Pattern 2: ServiceLocator.get<T>()** (For runtime access):
```dart
// In ViewModel or Widget:
class MyViewModel extends BaseViewModel {
  late final UserService _userService;

  void initialize() {
    _userService = ServiceLocator.get<UserService>();
  }
}
```

### Registration Patterns

- **registerSingleton**: Eager initialization (Core infrastructure - Auth, Storage, Firebase)
- **registerLazySingleton**: Lazy initialization (Feature modules - PREFERRED for non-critical services)

**Rule of thumb**: Core module uses eager singletons, all other modules prefer lazy singletons.

## Layered Service Architecture

**Unified services** use a consistent 3-4 layer architecture for complex domains:

### Example: UnifiedRecipeService

```dart
class UnifiedRecipeService extends BaseService {
  // Layer 1: Personal Operations - User's own content
  PersonalRecipeModule get personal;

  // Layer 2: Social Operations - Sharing and collaboration
  SocialRecipeCoordinator get social;

  // Layer 3: Realtime Operations - Live synchronization
  RealtimeRecipeService get realtime;

  // Layer 4: Share Operations (optional) - Specific sharing workflows
  RecipeSharingManager get share;
}
```

### Usage:
```dart
// Personal recipe creation
final recipe = await recipeService.personal.createRecipe(...);

// Social sharing
await recipeService.social.shareWithFriends(recipeId, friendIds);

// Realtime watching
final stream = recipeService.realtime.watchRecipe(recipeId);

// Share link generation
final link = await recipeService.share.generateShareLink(recipeId);
```

### Usage Rules:
- Always use the appropriate layer for the operation type
- Don't bypass layers (e.g., don't use personal ops for shared content)
- Each layer handles its own permissions and validation

## Quick Reference

### Creating a New Service

```dart
// lib/services/my_feature_service.dart
class MyFeatureService extends BaseService {
  final MyFeatureRepository _repository;

  MyFeatureService({
    required MyFeatureRepository repository,
  }) : _repository = repository;

  @override
  String get serviceName => 'MyFeatureService';

  Future<MyEntity?> getEntity(String id) async {
    return await executeServiceOperation(
      () => _repository.getById(id),
      operationName: 'Get entity',
      requiresAuth: true,
    );
  }
}

// Register in appropriate DI module:
container.registerLazySingleton<MyFeatureService>(
  () => MyFeatureService(
    repository: container<MyFeatureRepository>(),
  ),
);
```

### Creating a New Repository

```dart
// lib/repositories/firebase/firebase_my_feature_repository.dart
class FirebaseMyFeatureRepository extends BaseFirebaseRepository<MyEntity>
    with UserScopedFirebaseRepository<MyEntity>
    implements MyFeatureRepository {

  FirebaseMyFeatureRepository({required super.authRepository});

  @override
  String get collectionName => 'my_features';

  @override
  MyEntity fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) =>
      MyEntity.fromFirestore(doc);

  @override
  Map<String, dynamic> toFirestore(MyEntity entity) => entity.toFirestore();

  @override
  String getId(MyEntity entity) => entity.id;
}
```

### Creating a New ViewModel

```dart
// lib/viewmodels/my_feature_viewmodel.dart
class MyFeatureViewModel extends ChangeNotifier
    with StateNotifierMixin, AsyncOperationMixin {
  final MyFeatureService _service;

  MyFeatureViewModel({
    MyFeatureService? service,
  }) : _service = service ?? ServiceLocator.get<MyFeatureService>();

  Future<void> loadData() => executeAsync(() async {
    final data = await _service.getData();
    // Process data
    notifyListeners();
  });
  // isLoading, hasError, errorMessage provided automatically
}
```

## Resource Files

For deeper understanding of specific architectural topics, see:

- **[mvvm-layers.md](./resources/mvvm-layers.md)** - Detailed layer responsibilities, communication patterns, and examples
- **[repository-pattern.md](./resources/repository-pattern.md)** - BaseFirebaseRepository guide with permission validation patterns
- **[service-pattern.md](./resources/service-pattern.md)** - BaseService guide with ErrorHandlingMixin and layered architecture
- **[critical-anti-patterns.md](./resources/critical-anti-patterns.md)** - Anti-patterns with real violations and fixes

**Note**: For comprehensive dependency injection documentation (7-module DI system, registration patterns, service access, testing), see the **[dependency-injection-patterns](../dependency-injection-patterns/SKILL.md)** skill.

## Related Skills

**Complementary Skills**:
- 📋 **[testing-patterns](../testing-patterns/SKILL.md)** - For testing services, repositories, and ViewModels following this architecture
- 🗄️ **[firebase-repository-patterns](../firebase-repository-patterns/SKILL.md)** - For BaseFirebaseRepository implementation details
- 🔧 **[dependency-injection-patterns](../dependency-injection-patterns/SKILL.md)** - For deep dive into the 7-module DI system
- 🎨 **[state-management-patterns](../state-management-patterns/SKILL.md)** - For ViewModel state management patterns

## Examples from Butlery Codebase

All examples in this skill are taken from the actual Butlery codebase (`lib/` directory). When implementing new features, follow these proven patterns.

---

**Last Updated**: 2025-01-31
**Skill Version**: 1.0.0
**Applicable To**: All code in `lib/services/`, `lib/repositories/`, `lib/viewmodels/`, `lib/core/di/`
