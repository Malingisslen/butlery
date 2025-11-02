# Offline-First Patterns Skill

**Purpose**: Master offline-first architecture, caching strategies, and sync mechanisms in Butlery

**Domain**: Offline support, local caching, sync strategies, network resilience

**Use Cases**:
- Implementing offline data access
- Building sync mechanisms for offline edits
- Cache management and invalidation
- Network connectivity handling
- Multi-user offline support

---

## Quick Reference

### OfflineService - Main Facade

```dart
// Initialize offline service
final offlineService = ServiceLocator.get<OfflineService>();
await offlineService.initialize();

// Check online status
if (offlineService.isOnline) {
  print('Connected to internet');
}

// Save recipe offline
await offlineService.saveRecipeOfflineForUser(
  recipe: myRecipe,
  userId: currentUserId,
);

// Sync when back online
final result = await offlineService.syncNow();
print('Synced ${result.syncedCount} recipes');

// Check queue status
if (offlineService.hasQueuedChanges) {
  print('${offlineService.queuedChangesCount} pending changes');
}

// Clear user data (on logout)
await offlineService.clearUserData(userId);
```

### IntelligentCacheManager - Smart Caching

```dart
// Initialize cache
final cacheManager = ServiceLocator.get<IntelligentCacheManager>();
await cacheManager.initialize();

// Cache recipe
await cacheManager.cacheRecipe(
  recipe,
  priority: CachePriority.high,
);

// Get from cache
final recipe = await cacheManager.getCachedRecipe(recipeId);

// Prefetch based on behavior
await cacheManager.prefetchRecipes([recipeId1, recipeId2]);

// Clear cache
await cacheManager.clearCache();
```

### Offline-First Read Pattern

```dart
Future<Recipe?> getRecipe(String recipeId) async {
  // 1. Try offline storage first
  final offline = await offlineService.getRecipeOfflineForUser(
    recipeId,
    userId,
  );
  if (offline != null) return offline;

  // 2. Try cache
  final cached = await cacheManager.getCachedRecipe(recipeId);
  if (cached != null) return cached;

  // 3. Fetch from Firebase (if online)
  if (offlineService.isOnline) {
    final recipe = await _recipeRepository.getById(recipeId);

    // Save to offline and cache
    await offlineService.saveRecipeOfflineForUser(recipe, userId);
    await cacheManager.cacheRecipe(recipe);

    return recipe;
  }

  // 4. No data available
  return null;
}
```

---

## Core Architecture

### Three-Layer Storage

```
Layer 1: Memory (IntelligentCacheManager)
├─ 50MB limit
├─ Predictive loading
├─ Smart eviction
└─ Fastest access

Layer 2: Local Storage (OfflineService + Hive)
├─ User-prefixed keys
├─ Persistent across sessions
├─ Sync queue management
└─ Multi-user support

Layer 3: Cloud Storage (Firebase)
├─ Source of truth
├─ Real-time sync
├─ Collaborative editing
└─ Requires network
```

### Modular Components

**OfflineService** delegates to:
```
OfflineService (facade)
├─ OfflineInitialization - Hive setup, connectivity monitoring
├─ OfflineUserStorage - Multi-user data isolation
└─ OfflineSyncManager - Sync with retry logic
```

---

## Key Patterns

### Pattern 1: Offline-First Write

```dart
Future<void> updateRecipe(Recipe recipe) async {
  final offlineService = ServiceLocator.get<OfflineService>();
  final userId = authService.currentUserId;

  // 1. Save locally immediately (optimistic)
  await offlineService.saveRecipeOfflineForUser(
    recipe: recipe,
    userId: userId,
  );

  // Mark as modified offline
  recipe.offlineData = RecipeOfflineData(
    isModifiedOffline: true,
    lastSyncedAt: null,
    pendingChanges: ['title', 'ingredients'],
  );

  // 2. If online, sync to Firebase
  if (offlineService.isOnline) {
    try {
      await _recipeRepository.update(recipe);

      // Mark as synced
      recipe.offlineData = RecipeOfflineData(
        isModifiedOffline: false,
        lastSyncedAt: DateTime.now(),
        pendingChanges: null,
      );

      await offlineService.saveRecipeOfflineForUser(recipe, userId);
    } catch (e) {
      // Sync failed - stays in queue
      print('Sync failed: $e');
    }
  }
  // 3. If offline, stays in queue until next sync
}
```

### Pattern 2: Automatic Sync on Reconnect

```dart
class OfflineInitialization {
  void _setupConnectivityMonitoring() {
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOffline = !_isOnline;
      _isOnline = _isConnectivityOnline(result);

      // Transitioned from offline to online
      if (wasOffline && _isOnline) {
        print('🌐 Back online - triggering automatic sync');
        _syncCallback?.call();  // Calls OfflineService.syncNow()
      }
    });
  }
}
```

### Pattern 3: Queue-Based Sync with Continue-on-Error

```dart
Future<SyncResult> syncNow() async {
  if (!isOnline) {
    return SyncResult.failure('No internet connection');
  }

  if (_isSyncing) {
    return SyncResult.failure('Sync already in progress');
  }

  _isSyncing = true;
  int syncedCount = 0;
  int failedCount = 0;

  try {
    final queuedIds = await _getQueuedRecipeIds(userId);

    // Continue-on-error approach
    for (final recipeId in queuedIds) {
      try {
        final recipe = await _loadRecipe(recipeId);

        if (recipe.offlineData.needsSync) {
          await _retrySync(recipe);
          syncedCount++;
          await _removeFromQueue(recipeId);
        }
      } catch (e) {
        failedCount++;
        // Log but continue to next item
        print('Failed to sync $recipeId: $e');
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

### Pattern 4: Exponential Backoff for Retries

```dart
Future<void> _retrySync(Recipe recipe, {int attempt = 0}) async {
  const maxAttempts = 3;

  try {
    await _recipeRepository.update(recipe);
  } catch (e) {
    if (attempt < maxAttempts) {
      // Exponential backoff: 1s, 2s, 4s
      final delaySeconds = pow(2, attempt).toInt();
      await Future.delayed(Duration(seconds: delaySeconds));

      return _retrySync(recipe, attempt: attempt + 1);
    } else {
      throw Exception('Max retry attempts reached: $e');
    }
  }
}
```

### Pattern 5: Multi-User Data Isolation

```dart
class OfflineUserStorage {
  // User-prefixed key format
  String _getUserKey(String userId, String recipeId) {
    return '${userId}_$recipeId';
  }

  // Save with user prefix
  Future<void> saveRecipe(Recipe recipe, String userId) async {
    final key = _getUserKey(userId, recipe.id!);
    await _recipesBox.put(key, recipe.toJson());
  }

  // Get all recipes for user
  Future<List<Recipe>> getUserRecipes(String userId) async {
    final prefix = '${userId}_';
    final userKeys = _recipesBox.keys
        .where((key) => key.toString().startsWith(prefix));

    return userKeys
        .map((key) => Recipe.fromJson(_recipesBox.get(key)))
        .toList();
  }

  // Clear user data (on logout)
  Future<void> clearUserData(String userId) async {
    final prefix = '${userId}_';
    final userKeys = _recipesBox.keys
        .where((key) => key.toString().startsWith(prefix))
        .toList();

    for (final key in userKeys) {
      await _recipesBox.delete(key);
    }
  }
}
```

---

## Offline Data Models

### RecipeOfflineData

```dart
class RecipeOfflineData {
  final DateTime? lastSyncedAt;
  final bool isModifiedOffline;
  final List<String>? pendingChanges;

  RecipeOfflineData({
    this.lastSyncedAt,
    required this.isModifiedOffline,
    this.pendingChanges,
  });

  // Check if sync needed
  bool get needsSync {
    return isModifiedOffline || lastSyncedAt == null;
  }

  // Create for new offline edit
  factory RecipeOfflineData.modified({
    required List<String> changes,
  }) {
    return RecipeOfflineData(
      isModifiedOffline: true,
      lastSyncedAt: null,
      pendingChanges: changes,
    );
  }

  // Create after successful sync
  factory RecipeOfflineData.synced() {
    return RecipeOfflineData(
      isModifiedOffline: false,
      lastSyncedAt: DateTime.now(),
      pendingChanges: null,
    );
  }
}
```

---

## UI Integration

### Offline Indicator Banner

```dart
class OfflineIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final offlineService = ServiceLocator.get<OfflineService>();

    return Consumer<OfflineService>(
      builder: (context, service, child) {
        if (service.isOnline) return SizedBox.shrink();

        return Container(
          width: double.infinity,
          padding: EdgeInsets.all(12),
          color: Colors.orange,
          child: Row(
            children: [
              Icon(Icons.wifi_off, color: Colors.white),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Offline - Ändringar kommer synkas när du är online igen',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              if (service.hasQueuedChanges)
                Chip(
                  label: Text('${service.queuedChangesCount}'),
                  backgroundColor: Colors.white,
                ),
            ],
          ),
        );
      },
    );
  }
}
```

### Sync Button with Progress

```dart
class SyncButton extends StatefulWidget {
  @override
  _SyncButtonState createState() => _SyncButtonState();
}

class _SyncButtonState extends State<SyncButton> {
  bool _isSyncing = false;

  Future<void> _syncNow() async {
    setState(() => _isSyncing = true);

    final offlineService = ServiceLocator.get<OfflineService>();
    final result = await offlineService.syncNow();

    setState(() => _isSyncing = false);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(result.message),
        backgroundColor: result.success ? Colors.green : Colors.red,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<OfflineService>(
      builder: (context, service, child) {
        return ElevatedButton.icon(
          onPressed: _isSyncing || !service.hasQueuedChanges
              ? null
              : _syncNow,
          icon: _isSyncing
              ? SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : Icon(Icons.sync),
          label: Text(
            _isSyncing
                ? 'Synkar...'
                : 'Synka (${service.queuedChangesCount})',
          ),
        );
      },
    );
  }
}
```

---

## Best Practices

1. **Always read offline-first**
   - Check offline storage → cache → Firebase
   - Fastest data access
   - Works without network

2. **Optimistic writes**
   - Save locally immediately
   - Sync to cloud in background
   - Queue if offline

3. **Multi-user isolation**
   - User-prefixed keys
   - Clear data on logout
   - No cross-user data leaks

4. **Graceful degradation**
   - Continue-on-error during sync
   - Exponential backoff for retries
   - Detailed error reporting

5. **Cache intelligently**
   - Predictive loading
   - Smart eviction (LRU + access frequency)
   - Memory limits (50MB)

6. **Notify users**
   - Offline indicator
   - Queue status
   - Sync progress

---

## Resources

Detailed guides for specific offline-first topics:

- **[offline-service.md](resources/offline-service.md)** - OfflineService, components, initialization
- **[caching-strategies.md](resources/caching-strategies.md)** - IntelligentCacheManager, RecipeCacheModule
- **[sync-mechanisms.md](resources/sync-mechanisms.md)** - Queue management, retry logic, conflict resolution
- **[offline-models.md](resources/offline-models.md)** - RecipeOfflineData, sync metadata
- **[ui-integration.md](resources/ui-integration.md)** - Offline indicators, sync buttons, user feedback

---

## Related Skills

- **realtime-collaboration** - Conflict resolution for offline edits
- **dependency-injection-patterns** - OfflineService registration
- **performance-optimization** - Cache optimization strategies

---

**Status**: ✅ Production-ready
**Storage**: Hive (local) + IntelligentCacheManager (memory)
**Sync**: Automatic on reconnect + manual trigger
**Multi-User**: Complete data isolation
