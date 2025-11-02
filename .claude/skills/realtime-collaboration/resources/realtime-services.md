# Real-Time Services

Comprehensive guide to Butlery's real-time collaboration services: RealtimeRecipeService, RealtimeMenuService, and RealtimeSyncService.

## Overview

Butlery's real-time collaboration is built on three core services:

1. **RealtimeRecipeService** - Multi-user collaborative recipe editing
2. **RealtimeMenuService** - Category-based collaborative menu management
3. **RealtimeSyncService** - Core synchronization engine with conflict resolution

All services use Firebase Firestore snapshot listeners for real-time updates.

---

## RealtimeRecipeService

**Location**: `lib/services/realtime/realtime_recipe_service.dart`

**Purpose**: Enable multiple users to collaboratively edit recipes in real-time

### Key Methods

```dart
class RealtimeRecipeService extends ChangeNotifier {
  // Create collaborative recipe
  Future<RealtimeRecipe> createRealtimeRecipe({
    required Recipe recipe,
    required List<String> sharedWith,
    required PermissionLevel ownerPermission,
  });

  // Watch recipe for real-time updates
  Stream<RealtimeRecipe> watchRealtimeRecipe(String recipeId);

  // Basic info updates
  Future<void> updateBasicInfo(
    String recipeId, {
    String? title,
    String? description,
    MealType? mealType,
    int? portions,
    int? timeMinutes,
  });

  // Ingredient operations
  Future<void> addIngredient(String recipeId, Ingredient ingredient);
  Future<void> removeIngredient(String recipeId, String ingredientId);
  Future<void> updateIngredients(String recipeId, List<Ingredient> ingredients);

  // Instruction operations
  Future<void> addInstruction(String recipeId, String instruction);
  Future<void> removeInstruction(String recipeId, int index);
  Future<void> updateInstructions(String recipeId, List<String> instructions);

  // Image operations
  Future<void> addImage(String recipeId, String imageUrl);
  Future<void> removeImage(String recipeId, String imageUrl);
  Future<void> updateImages(String recipeId, List<String> imageUrls);

  // Participant management
  Future<void> addParticipant(
    String recipeId, {
    required String userId,
    required PermissionLevel permission,
  });
  Future<void> removeParticipant(String recipeId, String userId);
  Future<void> updateParticipantPermission(
    String recipeId,
    String userId,
    PermissionLevel newPermission,
  );

  // Utilities
  Future<void> deleteRealtimeRecipe(String recipeId);
  Future<Recipe> createPersonalCopy(String recipeId);
  Future<bool> hasRecipeChangedSince(String recipeId, DateTime timestamp);
  Future<Map<String, dynamic>> getRecipeChangesSummary(String recipeId);
}
```

### State Management

```dart
// Current processing state
bool isProcessing = false;

// Last error
String? lastError;

// Notify listeners on state changes
notifyListeners();
```

### Module Delegation

RealtimeRecipeService delegates operations to focused modules:

```dart
// Content operations (ingredients, instructions, images)
final _contentOps = RecipeContentOperations(
  firestoreRepository: _firestoreRepository,
  authRepository: _authRepository,
);

// Participant management
final _participants = RecipeParticipants(
  firestoreRepository: _firestoreRepository,
  authRepository: _authRepository,
);
```

### Usage Example

```dart
final service = ServiceLocator.get<RealtimeRecipeService>();

// Create collaborative recipe
final realtimeRecipe = await service.createRealtimeRecipe(
  recipe: myRecipe,
  sharedWith: ['user-id-1', 'user-id-2'],
  ownerPermission: PermissionLevel.editor,
);

// Watch for updates
service.watchRealtimeRecipe(realtimeRecipe.id).listen((updated) {
  print('Recipe updated: ${updated.recipe.title}');
  print('Last edited by: ${updated.lastEditedByDisplayName}');
});

// Update recipe
await service.updateBasicInfo(
  realtimeRecipe.id,
  title: 'New Title',
  portions: 4,
);

// Add ingredient
await service.addIngredient(
  realtimeRecipe.id,
  Ingredient(
    id: Uuid().v4(),
    name: 'Tomato',
    amount: 2,
    unit: 'st',
  ),
);

// Add participant
await service.addParticipant(
  realtimeRecipe.id,
  userId: 'new-user-id',
  permission: PermissionLevel.editor,
);
```

### Firestore Structure

```
realtime_recipes/{recipeId}
  ├─ id: "recipe-123"
  ├─ type: "recipe"
  ├─ ownerId: "user-123"
  ├─ ownerDisplayName: "John Doe"
  ├─ participants: {
  │    "user-123": "owner",
  │    "user-456": "editor",
  │    "user-789": "viewer"
  │  }
  ├─ recipe: {
  │    title: "Pasta Carbonara",
  │    ingredients: [...],
  │    instructions: [...],
  │    ...
  │  }
  ├─ createdAt: Timestamp
  ├─ lastEditedAt: Timestamp
  ├─ lastEditedBy: "user-456"
  ├─ lastEditedByDisplayName: "Jane Smith"
  ├─ editCount: 15
  ├─ isActive: true
  └─ metadata: {...}
```

---

## RealtimeMenuService

**Location**: `lib/services/realtime/realtime_menu_service.dart`

**Purpose**: Enable collaborative menu planning with category-based organization

### Key Methods

```dart
class RealtimeMenuService extends ChangeNotifier {
  // Create collaborative menu
  Future<RealtimeMenu> createRealtimeMenu({
    required Menu menu,
    required List<String> sharedWith,
  });

  // Watch menu for real-time updates
  Stream<RealtimeMenu> watchRealtimeMenu(String menuId);

  // Category operations
  Future<void> addRecipeToCategory(
    String menuId, {
    required String categoryName,
    required Recipe recipe,
  });
  Future<void> removeRecipeFromCategory(
    String menuId,
    String categoryName,
    String recipeId,
  );
  Future<void> moveRecipeBetweenCategories(
    String menuId, {
    required String recipeId,
    required String fromCategory,
    required String toCategory,
  });
  Future<void> replaceRecipeInCategory(
    String menuId, {
    required String categoryName,
    required String oldRecipeId,
    required Recipe newRecipe,
  });
  Future<void> clearCategory(String menuId, String categoryName);
  Future<void> updateWholeCategory(
    String menuId,
    String categoryName,
    List<Recipe> recipes,
  );
  Future<void> regenerateCategory(
    String menuId,
    String categoryName,
    String prompt,
  );

  // Participant operations (same as recipe service)
  Future<void> addParticipant(...);
  Future<void> removeParticipant(...);
  Future<void> updateParticipantPermission(...);

  // Utilities
  Future<void> deleteRealtimeMenu(String menuId);
  Future<Menu> createPersonalCopy(String menuId);
}
```

### Local Cache

```dart
// Cache current menu for performance
RealtimeMenu? _currentMenu;

// Clear cache on updates
void _clearCache() {
  _currentMenu = null;
}
```

### Module Delegation

```dart
// Menu operations (categories, recipes)
final _menuOps = MenuOperations(
  firestoreRepository: _firestoreRepository,
  authRepository: _authRepository,
);

// Participant management
final _participants = MenuParticipants(
  firestoreRepository: _firestoreRepository,
  authRepository: _authRepository,
);
```

### Usage Example

```dart
final service = ServiceLocator.get<RealtimeMenuService>();

// Create collaborative menu
final realtimeMenu = await service.createRealtimeMenu(
  menu: myMenu,
  sharedWith: ['user-id-1', 'user-id-2'],
);

// Watch for updates
service.watchRealtimeMenu(realtimeMenu.id).listen((updated) {
  print('Menu updated: ${updated.title}');
  print('Categories: ${updated.categories.keys.join(', ')}');
});

// Add recipe to category
await service.addRecipeToCategory(
  realtimeMenu.id,
  categoryName: 'Middag',
  recipe: newRecipe,
);

// Move recipe between categories
await service.moveRecipeBetweenCategories(
  realtimeMenu.id,
  recipeId: 'recipe-123',
  fromCategory: 'Lunch',
  toCategory: 'Middag',
);

// Regenerate category with AI
await service.regenerateCategory(
  realtimeMenu.id,
  'Frukost',
  'Healthy breakfast options with oats',
);
```

### Firestore Structure

```
realtime_menus/{menuId}
  ├─ id: "menu-123"
  ├─ type: "menu"
  ├─ ownerId: "user-123"
  ├─ participants: {...}
  ├─ data: {
  │    title: "Veckomeny",
  │    menuNotes: "Vårmatsedel 2025",
  │    favoriteRecipeIds: ["recipe-1", "recipe-2"],
  │    createdForDate: Timestamp,
  │    originalPrompt: "En vecka med vegetariska rätter",
  │    categories: {
  │      "Måndag": [Recipe, Recipe],
  │      "Tisdag": [Recipe],
  │      "Onsdag": [Recipe, Recipe, Recipe],
  │      ...
  │    }
  │  }
  ├─ createdAt: Timestamp
  ├─ lastEditedAt: Timestamp
  ├─ editCount: 8
  └─ metadata: {...}
```

---

## RealtimeSyncService

**Location**: `lib/services/realtime_sync_service.dart`

**Purpose**: Core synchronization engine with automatic conflict resolution

### Key Methods

```dart
class RealtimeSyncService extends BaseService {
  // Watch any realtime resource
  Stream<T> watchResource<T extends RealtimeResource>(String resourceId);

  // Update resource with automatic conflict resolution
  Future<void> updateResource<T extends RealtimeResource>(
    String resourceId, {
    required T Function(T current) updater,
  });

  // Delete resource
  Future<void> deleteResource(String resourceId);

  // Resolve conflict manually
  Future<void> resolveConflict<T extends RealtimeResource>(
    String resourceId, {
    required T localVersion,
    required T serverVersion,
  });

  // Get cached resource
  T? getCachedResource<T extends RealtimeResource>(String resourceId);

  // Clear cache
  void clearCache();
}
```

### Internal Modules

RealtimeSyncService uses three internal modules:

```dart
// Connection state monitoring
final _connectionModule = ConnectionStateModule(
  firestoreRepository: _firestoreRepository,
  authRepository: _authRepository,
);

// Resource parsing (Firestore → Dart models)
final _parserModule = ResourceParserModule();

// Conflict resolution logic
final _conflictModule = ConflictResolutionModule();
```

### Conflict Resolution Strategy

**Primary Key**: `editCount` (incremented on each edit)
```dart
if (server.editCount > local.editCount) {
  // Server has more edits - server wins
  return server;
} else if (local.editCount > server.editCount) {
  // Local has more edits - local wins
  return local;
}
```

**Secondary Key**: `lastEditedAt` (timestamp tiebreaker)
```dart
if (server.lastEditedAt.isAfter(local.lastEditedAt)) {
  return server;
} else {
  return local;
}
```

**Field-Level Merging** (for complex cases):
```dart
// Merge non-conflicting fields
final merged = T(
  id: resourceId,
  // Take server's scalar fields
  title: server.title,
  // Merge arrays (union of both)
  tags: [...local.tags, ...server.tags].toSet().toList(),
  // Use conflict resolution key
  editCount: max(local.editCount, server.editCount) + 1,
);
```

### Usage Example

```dart
final service = ServiceLocator.get<RealtimeSyncService>();

// Watch any resource type
final recipeStream = service.watchResource<RealtimeRecipe>('recipe-123');
final menuStream = service.watchResource<RealtimeMenu>('menu-456');

// Update with automatic conflict resolution
await service.updateResource<RealtimeRecipe>(
  'recipe-123',
  updater: (current) {
    current.recipe.title = 'New Title';
    current.lastEditedAt = DateTime.now();
    current.editCount += 1;
    return current;
  },
);

// Manual conflict resolution
final local = await _getLocalVersion('recipe-123');
final server = await _getServerVersion('recipe-123');

await service.resolveConflict<RealtimeRecipe>(
  'recipe-123',
  localVersion: local,
  serverVersion: server,
);
```

### Cache Management

```dart
// Internal cache for performance
final Map<String, RealtimeResource> _cache = {};

// Get from cache
final cached = service.getCachedResource<RealtimeRecipe>('recipe-123');

// Clear cache (on logout, app restart)
service.clearCache();
```

---

## Error Handling

All services use comprehensive error handling:

```dart
try {
  await service.updateBasicInfo(recipeId, title: 'New');
} on PermissionDeniedException catch (e) {
  // User lacks permission
  showError('Du har inte behörighet att redigera detta recept');
} on ResourceNotFoundException catch (e) {
  // Recipe not found
  showError('Receptet hittades inte');
} on ConflictException catch (e) {
  // Conflict resolution failed
  showError('Konflikt uppstod. Försök igen.');
} catch (e) {
  // Generic error
  showError('Ett fel uppstod: $e');
}
```

---

## Testing

```dart
group('RealtimeRecipeService', () {
  late RealtimeRecipeService service;
  late MockFirestoreRepository mockFirestore;
  late MockAuthRepository mockAuth;

  setUp() {
    mockFirestore = MockFirestoreRepository();
    mockAuth = MockAuthRepository();

    service = RealtimeRecipeService(
      firestoreRepository: mockFirestore,
      authRepository: mockAuth,
    );
  });

  test('createRealtimeRecipe creates collaborative recipe', () async {
    when(() => mockAuth.currentUserId).thenReturn('user-123');

    final recipe = Recipe(title: 'Test Recipe');
    final result = await service.createRealtimeRecipe(
      recipe: recipe,
      sharedWith: ['user-456'],
      ownerPermission: PermissionLevel.editor,
    );

    expect(result.recipe.title, 'Test Recipe');
    expect(result.participants, contains('user-123'));
    expect(result.participants, contains('user-456'));
  });

  test('watchRealtimeRecipe emits updates', () async {
    final stream = service.watchRealtimeRecipe('recipe-123');

    expect(
      stream,
      emits(isA<RealtimeRecipe>().having(
        (r) => r.id,
        'id',
        'recipe-123',
      )),
    );
  });

  test('updateBasicInfo increments editCount', () async {
    await service.updateBasicInfo('recipe-123', title: 'New Title');

    verify(() => mockFirestore.update(
      'realtime_recipes/recipe-123',
      argThat(contains('editCount')),
    )).called(1);
  });
});
```

---

## Best Practices

1. **Use appropriate service for resource type**
   - RealtimeRecipeService for recipes
   - RealtimeMenuService for menus
   - RealtimeSyncService for generic resources

2. **Let services handle conflict resolution**
   - Automatic resolution via editCount
   - Manual resolution only when necessary
   - Trust the conflict resolution strategy

3. **Implement proper error handling**
   - Catch permission errors
   - Handle resource not found
   - Provide user-friendly error messages

4. **Use streams for UI updates**
   - StreamBuilder pattern
   - Automatic cleanup
   - Error propagation

5. **Cache locally for performance**
   - RealtimeSyncService provides caching
   - Clear cache on logout/restart
   - Don't hold stale data

---

## Related Resources

- [presence-tracking.md](presence-tracking.md) - PresenceService patterns
- [conflict-resolution.md](conflict-resolution.md) - Detailed conflict strategies
- [realtime-models.md](realtime-models.md) - RealtimeResource, RealtimeRecipe, RealtimeMenu
- [ui-integration.md](ui-integration.md) - StreamBuilder and UI patterns

---

**Services**: RealtimeRecipeService, RealtimeMenuService, RealtimeSyncService
**Performance**: Optimized with caching and module delegation
**Status**: ✅ Production-ready
