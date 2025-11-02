# Sync Mechanisms

Guide to sync strategies: queue management, retry logic, conflict resolution, and automatic sync triggers.

## Overview

**Sync Strategy**: Queue-based with continue-on-error and exponential backoff

**Key Features**:
- Automatic sync on reconnect
- Manual sync trigger
- Exponential backoff (1s, 2s, 4s)
- Continue-on-error (process all items)
- Detailed sync result reporting

---

## Queue Management

### Sync Queue Structure

```dart
// Hive box: sync_queue
// Key: recipeId
// Value: timestamp (ISO 8601)

{
  "recipe-123": "2025-01-31T10:00:00Z",
  "recipe-456": "2025-01-31T10:05:00Z",
  "recipe-789": "2025-01-31T10:10:00Z"
}
```

### Queue Operations

```dart
// Add to queue
Future<void> addToSyncQueue(String recipeId) async {
  await _syncQueueBox.put(recipeId, DateTime.now().toIso8601String());
  notifyListeners();  // Update UI
}

// Remove from queue (after successful sync)
Future<void> removeFromSyncQueue(String recipeId) async {
  await _syncQueueBox.delete(recipeId);
  notifyListeners();
}

// Get queued recipe IDs
List<String> getQueuedRecipeIds() {
  return _syncQueueBox.keys.cast<String>().toList();
}

// Check if in queue
bool isInSyncQueue(String recipeId) {
  return _syncQueueBox.containsKey(recipeId);
}

// Clear queue (for testing or manual intervention)
Future<void> clearSyncQueue() async {
  await _syncQueueBox.clear();
}
```

---

## Sync Execution

### Main Sync Loop

```dart
Future<SyncResult> syncNow() async {
  // 1. Pre-flight checks
  if (!isOnline) {
    return SyncResult.failure('No internet connection');
  }

  if (_isSyncing) {
    return SyncResult.failure('Sync already in progress');
  }

  _isSyncing = true;
  int syncedCount = 0;
  int failedCount = 0;
  final failures = <String, String>{};  // recipeId -> error

  try {
    final queuedIds = getQueuedRecipeIds();
    print('🔄 Starting sync for ${queuedIds.length} recipes');

    // 2. Process each queued recipe (continue-on-error)
    for (final recipeId in queuedIds) {
      try {
        // Load recipe
        final recipe = await _storage.getRecipe(recipeId, _currentUserId);
        if (recipe == null) {
          await removeFromSyncQueue(recipeId);
          continue;
        }

        // Check if sync needed
        if (!recipe.offlineData.needsSync) {
          await removeFromSyncQueue(recipeId);
          continue;
        }

        // Sync with retry
        await _syncWithRetry(recipe);
        syncedCount++;
        await removeFromSyncQueue(recipeId);

        print('✅ Synced: ${recipe.id}');
      } catch (e) {
        failedCount++;
        failures[recipeId] = e.toString();
        print('❌ Failed: $recipeId - $e');
        // Continue to next item (don't break)
      }
    }

    // 3. Return detailed result
    final result = SyncResult(
      success: failedCount == 0,
      message: _buildSyncMessage(syncedCount, failedCount),
      syncedCount: syncedCount,
      failedCount: failedCount,
    );

    notifyListeners();
    return result;
  } finally {
    _isSyncing = false;
  }
}

String _buildSyncMessage(int synced, int failed) {
  if (failed == 0) {
    return 'Synkade $synced recept';
  } else if (synced == 0) {
    return 'Misslyckades synka $failed recept';
  } else {
    return 'Synkade $synced recept, $failed misslyckades';
  }
}
```

---

## Retry Logic with Exponential Backoff

```dart
Future<void> _syncWithRetry(
  Recipe recipe, {
  int attempt = 0,
}) async {
  const maxAttempts = 3;

  try {
    // Attempt to save to Firebase
    await _repository.update('recipes/${recipe.id}', recipe.toJson());

    // Success - update offline data
    recipe.offlineData = RecipeOfflineData.synced();
    await _storage.saveRecipe(recipe, _currentUserId);

    print('✅ Sync successful (attempt ${attempt + 1})');
  } catch (e) {
    if (attempt < maxAttempts - 1) {
      // Calculate exponential delay: 2^attempt seconds
      final delaySeconds = pow(2, attempt).toInt();
      print('⏱️ Retry after ${delaySeconds}s (attempt ${attempt + 1}/$maxAttempts)');

      await Future.delayed(Duration(seconds: delaySeconds));

      // Retry
      return _syncWithRetry(recipe, attempt: attempt + 1);
    } else {
      // Max attempts reached
      throw Exception('Max retry attempts ($maxAttempts) reached: $e');
    }
  }
}

// Retry delays:
// Attempt 0: 2^0 = 1 second
// Attempt 1: 2^1 = 2 seconds
// Attempt 2: 2^2 = 4 seconds
```

---

## Automatic Sync Triggers

### On Reconnect

```dart
class OfflineInitialization {
  void setupConnectivityMonitoring(Function() onReconnect) {
    _connectivity.onConnectivityChanged.listen((result) {
      final wasOffline = !_isOnline;
      _isOnline = result != ConnectivityResult.none;

      // Trigger sync when transitioning offline → online
      if (wasOffline && _isOnline) {
        print('🌐 Back online - auto-syncing');
        onReconnect();  // Calls OfflineService.syncNow()
      }
    });
  }
}
```

### Manual Trigger

```dart
// User-initiated sync
Future<void> onSyncButtonPressed() async {
  final offlineService = ServiceLocator.get<OfflineService>();

  if (!offlineService.isOnline) {
    showError('Du är offline. Anslut till internet för att synka.');
    return;
  }

  final result = await offlineService.syncNow();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(result.message),
      backgroundColor: result.success ? Colors.green : Colors.red,
    ),
  );
}
```

---

## Conflict Resolution

### Detect Conflicts

```dart
Future<bool> hasConflict(Recipe local, Recipe server) async {
  // Compare lastEditedAt timestamps
  if (server.lastEditedAt.isAfter(local.lastEditedAt)) {
    return true;  // Server version is newer
  }

  return false;
}
```

### Resolution Strategies

```dart
Future<Recipe> resolveConflict(Recipe local, Recipe server) async {
  // Strategy 1: Server always wins
  return server;

  // Strategy 2: Local always wins (for offline-first)
  return local;

  // Strategy 3: Merge both (field-level)
  return Recipe(
    id: local.id,
    title: server.title,  // Use server
    ingredients: local.ingredients,  // Use local
    instructions: _mergeInstructions(local, server),
    // ...
  );

  // Strategy 4: Ask user
  final choice = await showConflictDialog(local, server);
  return choice == 'local' ? local : server;
}
```

### Offline Conflict Prevention

```dart
// Mark offline edits clearly
Future<void> saveOfflineEdit(Recipe recipe) async {
  recipe.offlineData = RecipeOfflineData(
    isModifiedOffline: true,
    lastSyncedAt: null,
    pendingChanges: ['title', 'ingredients'],
  );

  await _storage.saveRecipe(recipe, userId);
  await _syncQueue.add(recipe.id!);
}
```

---

## Sync Result Handling

### SyncResult Model

```dart
class SyncResult {
  final bool success;
  final String message;
  final int syncedCount;
  final int failedCount;
  final Map<String, String>? failures;  // recipeId -> error

  bool get hasFailures => failedCount > 0;
  bool get isPartialSuccess => syncedCount > 0 && failedCount > 0;
}
```

### Result Processing

```dart
Future<void> handleSyncResult(SyncResult result) async {
  if (result.success) {
    // Full success
    showSuccess(result.message);
  } else if (result.isPartialSuccess) {
    // Some succeeded, some failed
    showWarning(result.message);

    // Offer to retry failed items
    final shouldRetry = await showRetryDialog(result.failures!);
    if (shouldRetry) {
      await _retryFailed(result.failures!.keys.toList());
    }
  } else {
    // Complete failure
    showError(result.message);

    // Suggest troubleshooting
    showTroubleshootingDialog();
  }
}
```

---

## Background Sync

### Periodic Sync (optional)

```dart
Timer? _periodicSyncTimer;

void startPeriodicSync({Duration interval = const Duration(minutes: 15)}) {
  _periodicSyncTimer?.cancel();

  _periodicSyncTimer = Timer.periodic(interval, (_) async {
    if (isOnline && hasQueuedChanges) {
      print('⏰ Periodic sync triggered');
      await syncNow();
    }
  });
}

void stopPeriodicSync() {
  _periodicSyncTimer?.cancel();
}
```

---

## Testing

```dart
group('Sync Mechanisms', () {
  late OfflineService service;

  setUp() async {
    service = OfflineService();
    await service.initialize();
  });

  test('syncs queued recipes', () async {
    // Add to queue
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

  test('retries failed syncs with exponential backoff', () async {
    int attempts = 0;

    when(() => mockRepository.update(any(), any())).thenAnswer((_) async {
      attempts++;
      if (attempts < 3) throw Exception('Temporary error');
    });

    await service._syncWithRetry(testRecipe);

    expect(attempts, 3);  // 3 attempts total
  });

  test('continues on error for batch sync', () async {
    // Add multiple recipes to queue
    await service.addToSyncQueue('recipe-1');  // Will succeed
    await service.addToSyncQueue('recipe-2');  // Will fail
    await service.addToSyncQueue('recipe-3');  // Will succeed

    final result = await service.syncNow();

    expect(result.syncedCount, 2);
    expect(result.failedCount, 1);
  });
});
```

---

## Best Practices

1. **Continue-on-error** - Process all items, don't stop at first failure
2. **Exponential backoff** - Prevent overwhelming server with retries
3. **Detailed reporting** - Return specific error messages
4. **User feedback** - Show sync progress and results
5. **Conflict prevention** - Mark offline edits clearly
6. **Queue integrity** - Protect against concurrent syncs

---

## Related Resources

- [offline-service.md](offline-service.md) - OfflineService implementation
- [offline-models.md](offline-models.md) - RecipeOfflineData structure
- [conflict-resolution.md](../realtime-collaboration/resources/conflict-resolution.md) - Real-time conflict strategies

---

**Queue**: Hive-based persistent queue
**Retry**: Exponential backoff (max 3 attempts)
**Conflict**: Server-wins or field-merge strategies
**Status**: ✅ Production-ready
