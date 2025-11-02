# Service Pattern in Butlery

This guide covers Butlery's service pattern implementation using BaseService with ErrorHandlingMixin, layered architecture, and business logic coordination.

## Overview

Services in Butlery handle all business logic and coordinate repositories. They sit between ViewModels and repositories, implementing workflows and business rules.

**Key Characteristics**:
- Extend `BaseService` for all instance-based services
- Coordinate one or more repositories
- Implement business rules and workflows
- **NO direct Firebase access** - use repositories
- **YES** to auth checks, network checks, caching
- **YES** to coordinating multiple data sources

## BaseService Architecture

### Core Functionality

BaseService provides:
- ✅ ErrorHandlingMixin (automatic error handling)
- ✅ Service lifecycle management (initialize, dispose)
- ✅ Pre-flight checks (auth, network, permissions)
- ✅ Caching infrastructure with expiry
- ✅ Batch operations support
- ✅ Consistent error messaging

### Basic Service Implementation

```dart
// lib/services/recipe_service.dart
class RecipeService extends BaseService {
  final RecipeRepository _repository;
  final UserRepository _userRepository;

  RecipeService({
    required RecipeRepository repository,
    required UserRepository userRepository,
  })  : _repository = repository,
        _userRepository = userRepository;

  @override
  String get serviceName => 'RecipeService';

  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(
      () => _repository.read(id),
      operationName: 'Get recipe',
      requiresAuth: true,
    );
  }

  Future<Recipe> createRecipe(Recipe recipe) async {
    return await executeServiceOperation(
      () async {
        // Business logic: Set owner
        final currentUser = await _userRepository.getCurrentUserProfile();
        final recipeWithOwner = recipe.copyWith(
          createdBy: currentUser.id,
          createdAt: DateTime.now(),
        );

        return await _repository.create(recipeWithOwner);
      },
      operationName: 'Create recipe',
      requiresAuth: true,
    );
  }
}
```

## ErrorHandlingMixin Operations

### executeServiceOperation

Standard operation wrapper with error handling:

```dart
Future<T> executeServiceOperation<T>(
  Future<T> Function() operation, {
  String? operationName,
  bool requiresAuth = false,
  bool requiresNetwork = false,
}) async {
  // Pre-flight checks
  if (requiresAuth && !await checkAuth()) {
    throw AuthenticationException('User not authenticated');
  }

  if (requiresNetwork && !await checkNetwork()) {
    throw NetworkException('No network connection');
  }

  try {
    return await operation();
  } catch (e) {
    // Automatic error handling, logging, user feedback
    handleError(e, operationName);
    rethrow;
  }
}
```

**Usage**:
```dart
// Simple operation
final recipe = await executeServiceOperation(
  () => _repository.read(id),
  operationName: 'Get recipe',
);

// With auth check
final created = await executeServiceOperation(
  () => _repository.create(recipe),
  operationName: 'Create recipe',
  requiresAuth: true,
);

// With network check
final synced = await executeServiceOperation(
  () => _syncService.sync(),
  operationName: 'Sync data',
  requiresNetwork: true,
);
```

### Batch Operations

Execute multiple operations with continue-on-error support:

```dart
Future<void> importRecipes(List<Recipe> recipes) async {
  await safeBatchOperation(
    recipes.map((recipe) => () => _repository.create(recipe)).toList(),
    'Import recipes',
    continueOnError: true,  // Don't stop on first error
  );
}
```

### Retry Operations

Automatic retry for transient failures:

```dart
// Automatically retries up to 3 times
final data = await executeWithRetry(
  () => _repository.fetchRemoteData(),
  maxRetries: 3,
  operationName: 'Fetch remote data',
);
```

## Layered Service Architecture

For complex domains, use **layered services** to organize operations by type:

### Layer Structure

```dart
class UnifiedRecipeService extends BaseService {
  final PersonalRecipeModule _personal;
  final SocialRecipeCoordinator _social;
  final RealtimeRecipeService _realtime;
  final RecipeSharingManager _share;

  // Layer 1: Personal Operations
  PersonalRecipeModule get personal => _personal;

  // Layer 2: Social Operations
  SocialRecipeCoordinator get social => _social;

  // Layer 3: Realtime Operations
  RealtimeRecipeService get realtime => _realtime;

  // Layer 4: Share Operations (optional)
  RecipeSharingManager get share => _share;

  @override
  String get serviceName => 'UnifiedRecipeService';
}
```

### Layer 1: Personal Operations

User's own content - no sharing or collaboration:

```dart
// lib/services/unified/modules/personal_recipe_module.dart
class PersonalRecipeModule {
  final RecipeRepository _repository;
  final ImageService _imageService;

  Future<List<Recipe>> getAllRecipes() async {
    return await _repository.readAll();
  }

  Future<Recipe> createRecipe(Recipe recipe) async {
    // Business logic: optimize image before saving
    if (recipe.imageUrl != null) {
      recipe = recipe.copyWith(
        imageUrl: await _imageService.optimizeImage(recipe.imageUrl!),
      );
    }

    return await _repository.create(recipe);
  }

  Future<void> deleteRecipe(String id) async {
    // Business logic: delete associated images
    final recipe = await _repository.read(id);
    if (recipe?.imageUrl != null) {
      await _imageService.deleteImage(recipe!.imageUrl!);
    }

    await _repository.delete(id);
  }
}
```

### Layer 2: Social Operations

Sharing and collaboration features:

```dart
// lib/services/unified/operations/social_recipe_coordinator.dart
class SocialRecipeCoordinator {
  final SocialRecipeRepository _socialRepository;
  final FriendsRepository _friendsRepository;
  final NotificationService _notificationService;

  Future<SharedRecipe> shareWithFriends(
    String recipeId,
    List<String> friendIds,
  ) async {
    // Business logic: verify friends, create shared recipe, notify
    final validFriends = await _friendsRepository.verifyFriends(friendIds);

    final sharedRecipe = await _socialRepository.shareRecipe(
      recipeId: recipeId,
      sharedWith: validFriends,
    );

    // Business logic: send notifications
    for (final friendId in validFriends) {
      await _notificationService.sendShareNotification(
        userId: friendId,
        recipeTitle: sharedRecipe.title,
      );
    }

    return sharedRecipe;
  }
}
```

### Layer 3: Realtime Operations

Live synchronization and collaborative editing:

```dart
// lib/services/realtime/realtime_recipe_service.dart
class RealtimeRecipeService {
  final RecipeRepository _repository;
  final PresenceService _presenceService;

  Stream<Recipe?> watchRecipe(String recipeId) {
    return _repository.watch(recipeId);
  }

  Future<void> updateRecipeField(
    String recipeId,
    String field,
    dynamic value,
  ) async {
    // Business logic: conflict resolution, presence tracking
    await _presenceService.markAsEditing(recipeId, field);

    final recipe = await _repository.read(recipeId);
    if (recipe != null) {
      final updated = _applyFieldUpdate(recipe, field, value);
      await _repository.update(updated);
    }

    await _presenceService.markAsIdle(recipeId);
  }
}
```

### Layer 4: Share Operations (Optional)

Platform-specific sharing workflows:

```dart
// lib/services/unified/modules/recipe_sharing_manager.dart
class RecipeSharingManager {
  final DeepLinkService _deepLinkService;
  final ShareService _shareService;

  Future<String> generateShareLink(String recipeId) async {
    return await _deepLinkService.createRecipeLink(recipeId);
  }

  Future<void> shareViaSystem(Recipe recipe) async {
    final link = await generateShareLink(recipe.id);
    await _shareService.share(
      'Check out this recipe: ${recipe.title}',
      link,
    );
  }
}
```

### Using Layered Services

```dart
// In ViewModel
class RecipeViewModel extends BaseViewModel {
  final UnifiedRecipeService _service;

  // Personal operations
  Future<void> createRecipe(Recipe recipe) async {
    await _service.personal.createRecipe(recipe);
  }

  // Social operations
  Future<void> shareWithFriends(List<String> friendIds) async {
    await _service.social.shareWithFriends(_recipe.id, friendIds);
  }

  // Realtime operations
  void watchRecipe(String recipeId) {
    _subscription = _service.realtime.watchRecipe(recipeId).listen((recipe) {
      if (recipe != null) {
        _recipe = recipe;
        notifyListeners();
      }
    });
  }

  // Share operations
  Future<void> shareViaSystem() async {
    await _service.share.shareViaSystem(_recipe);
  }
}
```

## Business Logic Patterns

### Pattern 1: Multi-Repository Coordination

```dart
class RecipeDiscoveryService extends BaseService {
  final SocialRecipeRepository _socialRepository;
  final UserRepository _userRepository;
  final FriendsRepository _friendsRepository;

  Future<List<SharedRecipe>> discoverRecipes() async {
    return await executeServiceOperation(
      () async {
        // Business logic: Coordinate multiple repositories
        final friendIds = await _friendsRepository.getFriendIds();
        final userProfile = await _userRepository.getCurrentUserProfile();
        final allRecipes = await _socialRepository.getDiscoverableRecipes();

        // Business logic: Filter by friends and preferences
        return allRecipes.where((recipe) {
          final isFriendRecipe = friendIds.contains(recipe.ownerId);
          final matchesPreferences = _matchesUserPreferences(
            recipe,
            userProfile,
          );
          return isFriendRecipe || matchesPreferences;
        }).toList();
      },
      operationName: 'Discover recipes',
      requiresAuth: true,
    );
  }

  bool _matchesUserPreferences(SharedRecipe recipe, UserProfile profile) {
    // Business rule implementation
    if (profile.dietaryRestrictions.isNotEmpty) {
      return recipe.tags.any(
        (tag) => profile.dietaryRestrictions.contains(tag),
      );
    }
    return true;
  }
}
```

### Pattern 2: Data Transformation

```dart
class RecipeImportService extends BaseService {
  final RecipeRepository _repository;
  final RecipeParserService _parser;
  final ImageService _imageService;

  Future<Recipe> importFromUrl(String url) async {
    return await executeServiceOperation(
      () async {
        // Business logic: Parse, transform, save
        final rawData = await _parser.parseUrl(url);

        // Transform to internal format
        final recipe = Recipe(
          id: const Uuid().v4(),
          title: rawData.title,
          ingredients: _normalizeIngredients(rawData.ingredients),
          instructions: _normalizeInstructions(rawData.instructions),
        );

        // Optimize image
        if (rawData.imageUrl != null) {
          final optimizedUrl = await _imageService.downloadAndOptimize(
            rawData.imageUrl!,
          );
          recipe = recipe.copyWith(imageUrl: optimizedUrl);
        }

        return await _repository.create(recipe);
      },
      operationName: 'Import recipe from URL',
      requiresAuth: true,
      requiresNetwork: true,
    );
  }
}
```

### Pattern 3: Validation & Business Rules

```dart
class RecipeValidationService extends BaseService {
  Future<ValidationResult> validateRecipe(Recipe recipe) async {
    return await executeServiceOperation(
      () async {
        final errors = <String>[];

        // Business rule: Title required
        if (recipe.title.trim().isEmpty) {
          errors.add('Title is required');
        }

        // Business rule: At least one ingredient
        if (recipe.ingredients.isEmpty) {
          errors.add('At least one ingredient required');
        }

        // Business rule: Portions must be positive
        if (recipe.portions <= 0) {
          errors.add('Portions must be greater than 0');
        }

        // Business rule: Image size limit
        if (recipe.imageUrl != null) {
          final size = await _imageService.getImageSize(recipe.imageUrl!);
          if (size > 5 * 1024 * 1024) {  // 5MB
            errors.add('Image must be less than 5MB');
          }
        }

        return ValidationResult(
          isValid: errors.isEmpty,
          errors: errors,
        );
      },
      operationName: 'Validate recipe',
    );
  }
}
```

### Pattern 4: Caching

```dart
class RecipeService extends BaseService {
  final RecipeRepository _repository;
  final Map<String, Recipe> _cache = {};
  final Map<String, DateTime> _cacheExpiry = {};
  final Duration _cacheTimeout = const Duration(minutes: 5);

  Future<Recipe?> getRecipe(String id) async {
    // Check cache first
    if (_cache.containsKey(id)) {
      final expiry = _cacheExpiry[id];
      if (expiry != null && DateTime.now().isBefore(expiry)) {
        return _cache[id];
      }
    }

    // Fetch from repository
    final recipe = await executeServiceOperation(
      () => _repository.read(id),
      operationName: 'Get recipe',
    );

    // Update cache
    if (recipe != null) {
      _cache[id] = recipe;
      _cacheExpiry[id] = DateTime.now().add(_cacheTimeout);
    }

    return recipe;
  }

  void invalidateCache(String id) {
    _cache.remove(id);
    _cacheExpiry.remove(id);
  }
}
```

## Service Registration in DI

### Singleton Registration

```dart
// In DI module
class ContentModule implements DIModule {
  @override
  Future<void> configure(GetIt container) async {
    // Eager singleton (core services)
    container.registerSingleton<AuthService>(
      AuthService(
        authRepository: container<AuthRepository>(),
      ),
    );

    // Lazy singleton (feature services - PREFERRED)
    container.registerLazySingleton<UnifiedRecipeService>(
      () => UnifiedRecipeService(
        recipeRepository: container<RecipeRepository>(),
        userRepository: container<UserRepository>(),
        imageService: container<ImageService>(),
      ),
    );
  }
}
```

**Rule of thumb**:
- Core module: Eager singletons
- All other modules: Lazy singletons

## Service Lifecycle

### Initialize

```dart
class RecipeService extends BaseService {
  @override
  Future<void> initialize() async {
    await super.initialize();

    // Custom initialization
    _cache = await _cacheService.loadCache();
    _subscription = _connectivityService.watch().listen(_onConnectivityChange);
  }
}
```

### Dispose

```dart
class RecipeService extends BaseService {
  StreamSubscription? _subscription;

  @override
  Future<void> dispose() async {
    await _subscription?.cancel();
    await _cache.clear();

    await super.dispose();
  }
}
```

## Testing Services

### Mock Dependencies

```dart
void main() {
  group('RecipeService', () {
    late RecipeService service;
    late MockRecipeRepository mockRepository;
    late MockUserRepository mockUserRepository;

    setUp(() {
      mockRepository = MockRecipeRepository();
      mockUserRepository = MockUserRepository();

      service = RecipeService(
        repository: mockRepository,
        userRepository: mockUserRepository,
      );
    });

    test('createRecipe() sets createdBy to current user', () async {
      final currentUser = UserProfile(id: 'user-1', email: 'test@test.com');
      when(() => mockUserRepository.getCurrentUserProfile())
          .thenAnswer((_) async => currentUser);

      final recipe = Recipe(id: 'recipe-1', title: 'Test Recipe');
      when(() => mockRepository.create(any()))
          .thenAnswer((_) async => recipe);

      await service.createRecipe(recipe);

      verify(() => mockRepository.create(
        argThat(predicate<Recipe>((r) => r.createdBy == 'user-1')),
      )).called(1);
    });
  });
}
```

## Common Mistakes

### ❌ Mistake 1: Direct Firebase Access

```dart
// ❌ BAD
class BadService extends BaseService {
  Future<Recipe?> getRecipe(String id) async {
    final doc = await FirebaseFirestore.instance  // ❌ Direct access
        .collection('recipes')
        .doc(id)
        .get();

    return Recipe.fromFirestore(doc);
  }
}

// ✅ GOOD
class GoodService extends BaseService {
  final RecipeRepository _repository;

  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(
      () => _repository.read(id),  // ✅ Use repository
      operationName: 'Get recipe',
    );
  }
}
```

### ❌ Mistake 2: Not Extending BaseService

```dart
// ❌ BAD
class BadService {  // ❌ No BaseService
  Future<Recipe?> getRecipe(String id) async {
    try {  // ❌ Manual error handling
      return await _repository.read(id);
    } catch (e) {
      print('Error: $e');  // ❌ Poor error handling
      return null;
    }
  }
}

// ✅ GOOD
class GoodService extends BaseService {  // ✅ Extends BaseService
  Future<Recipe?> getRecipe(String id) async {
    return await executeServiceOperation(  // ✅ ErrorHandlingMixin
      () => _repository.read(id),
      operationName: 'Get recipe',
    );
  }
}
```

### ❌ Mistake 3: Business Logic in Repository

```dart
// ❌ BAD - Business logic in repository
class BadRepository extends BaseFirebaseRepository<Recipe> {
  Future<Recipe> createWithDefaults(String title) async {
    final recipe = Recipe(
      id: Uuid().v4(),
      title: title,
      portions: 4,  // ❌ Business logic (defaults)
    );
    return await create(recipe);
  }
}

// ✅ GOOD - Business logic in service
class GoodService extends BaseService {
  Future<Recipe> createWithDefaults(String title) async {
    return await executeServiceOperation(
      () async {
        final recipe = Recipe(
          id: Uuid().v4(),
          title: title,
          portions: 4,  // ✅ Business logic in service
        );
        return await _repository.create(recipe);
      },
      operationName: 'Create recipe with defaults',
    );
  }
}
```

## Summary Checklist

When creating a new service:

- [ ] Extend `BaseService`
- [ ] Use constructor injection for dependencies
- [ ] Override `serviceName` getter
- [ ] Use `executeServiceOperation()` for operations
- [ ] Use `requiresAuth: true` for operations requiring authentication
- [ ] Coordinate repositories (don't access Firebase directly)
- [ ] Implement business logic and workflows
- [ ] Write unit tests with mocked dependencies
- [ ] Register in appropriate DI module with lazy singleton
- [ ] NO direct Firebase access
- [ ] NO data access logic (that's repository's job)

---

**See Also**:
- [MVVM Layers](./mvvm-layers.md) - Layer responsibilities
- [Repository Pattern](./repository-pattern.md) - How repositories work
- [Dependency Injection Patterns](../../dependency-injection-patterns/SKILL.md) - How to register services in 7-module DI system
- [Critical Anti-Patterns](./critical-anti-patterns.md) - What to avoid
