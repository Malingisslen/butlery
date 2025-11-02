# Offline Service

Comprehensive guide to OfflineService: the main facade for offline support, component architecture, and initialization.

## Overview

**Location**: `lib/services/offline_service.dart`

**Purpose**: Provide offline-first data access with automatic sync and multi-user support

**Architecture**: Facade pattern with three focused components:
- **OfflineInitialization** - Hive setup & connectivity monitoring
- **OfflineUserStorage** - Multi-user data isolation
- **OfflineSyncManager** - Queue-based sync with retry logic

---

## OfflineService (Facade)

### Key Properties

```dart
class OfflineService extends ChangeNotifier {
  // Online status (observable)
  bool get isOnline => _initialization.isOnline;

  // Queue status
  bool get hasQueuedChanges => _syncQueue.isNotEmpty;
  int get queuedChangesCount => _syncQueue.keys.length;

  // Sync status
  bool get isSyncing => _syncManager.isSyncing;

  // Current user
  String? _currentUserId;
}
```

### Key Methods

```dart
// Initialize Hive and connectivity monitoring
Future<void> initialize();

// Save recipe offline with user prefix
Future<void> saveRecipeOfflineForUser({
  required Recipe recipe,
  required String userId,
});

// Get recipe from offline storage
Future<Recipe?> getRecipeOfflineForUser(String recipeId, String userId);

// Get all offline recipes for user
Future<List<Recipe>> getAllRecipesOfflineForUser(String userId);

// Sync all queued changes
Future<SyncResult> syncNow();

// Set current user (for multi-user support)
void setCurrentUser(String userId);

// Clear all data for user (on logout)
Future<void> clearUserData(String userId);

// Get all users with offline data
List<String> getUsersWithOfflineData();
```

### Initialization

```dart
Future<void> initialize() async {
  // 1. Initialize Hive
  await _initialization.initializeHive();

  // 2. Setup connectivity monitoring
  _initialization.setupConnectivityMonitoring((bool isOnline) {
    if (isOnline && hasQueuedChanges) {
      // Auto-sync when back online
      syncNow();
    }
  });

  // 3. Load sync queue
  _syncQueue = await _storage.loadSyncQueue();

  notifyListeners();
}
```

### Usage Example

```dart
// In main.dart or app initialization
final offlineService = ServiceLocator.get<OfflineService>();
await offlineService.initialize();

// Set current user
offlineService.setCurrentUser(authService.currentUserId);

// Save recipe offline
await offlineService.saveRecipeOfflineForUser(
  recipe: myRecipe,
  userId: currentUserId,
);

// Sync when online
if (offlineService.isOnline && offlineService.hasQueuedChanges) {
  final result = await offlineService.syncNow();
  print(result.message);
}

// On logout
await offlineService.clearUserData(userId);
```

---

## OfflineInitialization

**Location**: `lib/services/offline/offline_initialization.dart`

**Purpose**: Setup Hive storage and monitor network connectivity

### Hive Initialization

```dart
Future<void> initializeHive() async {
  // 1. Initialize Hive
  await Hive.initFlutter('butlery_cache');

  // 2. Open boxes
  _recipesBox = await Hive.openBox<Map>('recipes_offline');
  _syncQueueBox = await Hive.openBox<String>('sync_queue');

  print('📦 Hive initialized with ${_recipesBox.length} recipes');
}
```

### Connectivity Monitoring

```dart
void setupConnectivityMonitoring(Function(bool) onConnectivityChanged) {
  // Monitor connectivity changes
  _connectivity.onConnectivityChanged.listen((result) {
    final wasOffline = !_isOnline;
    _isOnline = _isConnectivityOnline(result);

    // Callback when transitioning offline → online
    if (wasOffline && _isOnline) {
      print('🌐 Back online - triggering sync callback');
      onConnectivityChanged(_isOnline);
    }
  });

  // Initial connectivity check
  _checkInitialConnectivity();
}

bool _isConnectivityOnline(ConnectivityResult result) {
  // Consider VPN, WiFi, Mobile as online
  return result != ConnectivityResult.none;
}
```

---

## OfflineUserStorage

**Location**: `lib/services/offline/offline_user_storage.dart`

**Purpose**: Multi-user data isolation with user-prefixed keys

### Key Prefixing Strategy

```dart
String _getUserKey(String userId, String recipeId) {
  return '${userId}_$recipeId';
}

// Examples:
// "user123_recipe456"
// "user789_recipe101"
```

**Benefits**:
- Complete data isolation per user
- No cross-user data access
- Easy batch operations (prefix filtering)
- User discovery via key analysis

### Storage Operations

```dart
Future<void> saveRecipe(Recipe recipe, String userId) async {
  final key = _getUserKey(userId, recipe.id!);
  await _recipesBox.put(key, recipe.toJson());
}

Future<Recipe?> getRecipe(String recipeId, String userId) async {
  final key = _getUserKey(userId, recipeId);
  final data = _recipesBox.get(key);

  if (data == null) return null;
  return Recipe.fromJson(data);
}

Future<List<Recipe>> getUserRecipes(String userId) async {
  final prefix = '${userId}_';
  final userKeys = _recipesBox.keys
      .where((key) => key.toString().startsWith(prefix));

  return userKeys
      .map((key) => Recipe.fromJson(_recipesBox.get(key)))
      .toList();
}

Future<void> deleteRecipe(String recipeId, String userId) async {
  final key = _getUserKey(userId, recipeId);
  await _recipesBox.delete(key);
}
```

### Batch Operations

```dart
// Get all users with offline data
List<String> getUsers() {
  final userIds = <String>{};

  for (final key in _recipesBox.keys) {
    final parts = key.toString().split('_');
    if (parts.length >= 2) {
      userIds.add(parts[0]);  // Extract userId prefix
    }
  }

  return userIds.toList();
}

// Clear all data for user
Future<void> clearUserData(String userId) async {
  final prefix = '${userId}_';
  final userKeys = _recipesBox.keys
      .where((key) => key.toString().startsWith(prefix))
      .toList();

  for (final key in userKeys) {
    await _recipesBox.delete(key);
  }

  print('🗑️ Cleared ${userKeys.length} recipes for user $userId');
}
```

---

## OfflineSyncManager

**Location**: `lib/services/offline/offline_sync_manager.dart`

**Purpose**: Queue-based sync with intelligent retry logic

### Sync Queue Management

```dart
// Add to sync queue
Future<void> addToQueue(String recipeId) async {
  await _syncQueueBox.put(recipeId, DateTime.now().toIso8601String());
}

// Remove from queue (after successful sync)
Future<void> removeFromQueue(String recipeId) async {
  await _syncQueueBox.delete(recipeId);
}

// Get all queued recipe IDs
List<String> getQueuedRecipeIds() {
  return _syncQueueBox.keys.cast<String>().toList();
}

// Check if recipe is queued
bool isQueued(String recipeId) {
  return _syncQueueBox.containsKey(recipeId);
}
```

### Sync Execution

```dart
Future<SyncResult> sync({
  required String userId,
  required FirestoreRepository repository,
}) async {
  if (_isSyncing) {
    return SyncResult.failure('Sync already in progress');
  }

  _isSyncing = true;
  int syncedCount = 0;
  int failedCount = 0;

  try {
    final queuedIds = getQueuedRecipeIds();

    // Continue-on-error approach
    for (final recipeId in queuedIds) {
      try {
        // Load recipe
        final recipe = await _storage.getRecipe(recipeId, userId);
        if (recipe == null) continue;

        // Check if sync needed
        if (!recipe.offlineData.needsSync) {
          await removeFromQueue(recipeId);
          continue;
        }

        // Sync with retry
        await _retrySync(recipe, repository);
        syncedCount++;

        // Remove from queue
        await removeFromQueue(recipeId);

        print('✅ Synced recipe: ${recipe.id}');
      } catch (e) {
        failedCount++;
        print('❌ Failed to sync $recipeId: $e');
        // Continue to next item
      }
    }

    return SyncResult(
      success: failedCount == 0,
      message: 'Synced $syncedCount recipes, $failedCount failed',
      syncedCount: syncedCount,
      failedCount: failedCount,
    );
  } finally {
    _isSyncing = false;
  }
}
```

### Retry Logic with Exponential Backoff

```dart
Future<void> _retrySync(
  Recipe recipe,
  FirestoreRepository repository, {
  int attempt = 0,
}) async {
  const maxAttempts = 3;

  try {
    await repository.update('recipes/${recipe.id}', recipe.toJson());

    // Update offline data (mark as synced)
    recipe.offlineData = RecipeOfflineData.synced();
    await _storage.saveRecipe(recipe, _currentUserId);
  } catch (e) {
    if (attempt < maxAttempts) {
      // Exponential backoff: 1s, 2s, 4s
      final delaySeconds = pow(2, attempt).toInt();
      print('⏱️ Retry $attempt after ${delaySeconds}s');

      await Future.delayed(Duration(seconds: delaySeconds));
      return _retrySync(recipe, repository, attempt: attempt + 1);
    } else {
      throw Exception('Max retry attempts ($maxAttempts) reached: $e');
    }
  }
}
```

---

## SyncResult Model

**Location**: `lib/services/offline/sync_result.dart`

```dart
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final bool isRetry;

  SyncResult({
    required this.success,
    required this.message,
    this.syncedCount = 0,
    this.failedCount = 0,
    this.isRetry = false,
  });

  factory SyncResult.success(String message, int count) {
    return SyncResult(
      success: true,
      message: message,
      syncedCount: count,
    );
  }

  factory SyncResult.failure(String message) {
    return SyncResult(
      success: false,
      message: message,
      failedCount: 1,
    );
  }
}
```

---

## Dependency Injection

```dart
// In ContentModule
container.registerSingleton<OfflineService>(
  OfflineService(
    firestoreRepository: container<FirestoreRepository>(),
    authRepository: container<AuthRepository>(),
  ),
);

// Initialize after registration
final offlineService = container<OfflineService>();
await offlineService.initialize();
```

---

## Testing

```dart
group('OfflineService', () {
  late OfflineService service;

  setUp() async {
    service = OfflineService(
      firestoreRepository: MockFirestoreRepository(),
      authRepository: MockAuthRepository(),
    );
    await service.initialize();
  });

  test('saves recipe offline with user prefix', () async {
    await service.saveRecipeOfflineForUser(
      recipe: testRecipe,
      userId: 'user-123',
    );

    final retrieved = await service.getRecipeOfflineForUser(
      testRecipe.id!,
      'user-123',
    );

    expect(retrieved, isNotNull);
    expect(retrieved!.id, testRecipe.id);
  });

  test('syncs queued recipes when online', () async {
    // Add recipe to queue
    await service.saveRecipeOfflineForUser(
      recipe: testRecipe,
      userId: 'user-123',
    );

    // Sync
    final result = await service.syncNow();

    expect(result.success, isTrue);
    expect(result.syncedCount, 1);
    expect(service.hasQueuedChanges, isFalse);
  });

  test('multi-user data isolation', () async {
    await service.saveRecipeOfflineForUser(
      recipe: testRecipe,
      userId: 'user-A',
    );

    // User B should not see user A's data
    final retrieved = await service.getRecipeOfflineForUser(
      testRecipe.id!,
      'user-B',
    );

    expect(retrieved, isNull);
  });
});
```

---

## Best Practices

1. **Initialize on app start**
   - Call `initialize()` before first use
   - Setup connectivity monitoring early
   - Handle initialization errors gracefully

2. **Multi-user support**
   - Always pass userId to storage operations
   - Clear user data on logout
   - Prevent cross-user data access

3. **Graceful error handling**
   - Continue-on-error during sync
   - Exponential backoff for retries
   - Detailed sync result reporting

4. **Notify UI of changes**
   - Use ChangeNotifier pattern
   - Update isOnline, hasQueuedChanges
   - Trigger UI rebuild automatically

---

## Related Resources

- [sync-mechanisms.md](sync-mechanisms.md) - Detailed sync strategies
- [offline-models.md](offline-models.md) - RecipeOfflineData structure
- [ui-integration.md](ui-integration.md) - UI components and patterns

---

**Components**: OfflineInitialization, OfflineUserStorage, OfflineSyncManager
**Storage**: Hive with two boxes (recipes_offline, sync_queue)
**Status**: ✅ Production-ready
