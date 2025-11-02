# Caching Strategies

Guide to intelligent caching: IntelligentCacheManager with predictive loading and RecipeCacheModule orchestration.

## Overview

**Two-layer caching**:
1. **IntelligentCacheManager** - Memory cache (50MB limit) with predictive loading
2. **RecipeCacheModule** - Orchestrates cache + Firebase sync + debouncing

---

## IntelligentCacheManager

**Location**: `lib/services/performance/intelligent_cache_manager.dart`

**Purpose**: Smart memory caching with predictive loading and intelligent eviction

### Key Features

- **50MB memory limit** - Automatic eviction when exceeded
- **Predictive loading** - Based on user behavior patterns
- **Smart eviction** - LRU + access frequency scoring
- **Priority-based caching** - High/medium/low priority levels
- **Automatic cleanup** - 24-hour stale data removal

### Key Methods

```dart
class IntelligentCacheManager {
  // Cache recipe
  Future<void> cacheRecipe(
    Recipe recipe, {
    CachePriority priority = CachePriority.medium,
  });

  // Get from cache
  Future<Recipe?> getCachedRecipe(String recipeId);

  // Prefetch recipes (predictive loading)
  Future<void> prefetchRecipes(List<String> recipeIds);

  // Clear cache
  Future<void> clearCache();

  // Get cache statistics
  CacheStatistics getStatistics();
}
```

### Predictive Loading

```dart
// Based on UserBehaviorPattern
Future<void> _startPredictiveLoading() async {
  Timer.periodic(Duration(minutes: 5), (_) async {
    final pattern = await _getUserBehaviorPattern();

    // Prefetch frequently accessed recipes
    if (pattern.frequentlyAccessedRecipes.isNotEmpty) {
      await prefetchRecipes(pattern.frequentlyAccessedRecipes);
    }

    // Prefetch by time of day
    final currentHour = DateTime.now().hour;
    if (currentHour >= 17 && currentHour <= 20) {
      // Evening: Prefetch dinner recipes
      await prefetchRecipes(pattern.dinnerRecipes);
    }
  });
}
```

### Smart Eviction

```dart
void _evictIfNeeded() {
  if (_currentCacheSize > _maxCacheSize) {
    // Calculate eviction scores (access count × recency)
    final scores = _cache.entries.map((entry) {
      final accessCount = _accessCounts[entry.key] ?? 1;
      final lastAccess = _lastAccess[entry.key] ?? DateTime.now();
      final recency = DateTime.now().difference(lastAccess).inHours;

      return MapEntry(entry.key, accessCount / (recency + 1));
    }).toList();

    // Sort by score (lowest first)
    scores.sort((a, b) => a.value.compareTo(b.value));

    // Evict lowest-scoring items
    for (final entry in scores.take(_evictionCount)) {
      _cache.remove(entry.key);
      _currentCacheSize -= _getRecipeSize(entry.key);
    }
  }
}
```

---

## RecipeCacheModule

**Location**: `lib/services/unified/modules/recipe_cache_module.dart`

**Purpose**: Orchestrate caching, Firebase sync, and debouncing

### Module Architecture

```dart
class RecipeCacheModule {
  final CacheOperations _cacheOps;           // Local save/load
  final FirebaseSyncManager _syncManager;     // Real-time sync
  final DebouncedSyncOperations _debounced;   // 2-sec debounce
  final CacheOptimization _optimization;      // Cleanup
}
```

### Debounced Writes (2-second)

```dart
class DebouncedSyncOperations {
  Timer? _debounceTimer;

  Future<void> debouncedSave(Recipe recipe) async {
    _debounceTimer?.cancel();

    _debounceTimer = Timer(Duration(seconds: 2), () async {
      await _saveToFirebase(recipe);
    });
  }
}
```

### Cache-First Read Pattern

```dart
Future<Recipe?> getRecipe(String recipeId) async {
  // 1. Try cache first
  final cached = await _cacheOps.load(recipeId);
  if (cached != null) {
    _cacheHits++;
    return cached;
  }

  // 2. Fetch from Firebase
  final recipe = await _syncManager.fetch(recipeId);
  if (recipe == null) return null;

  // 3. Save to cache
  await _cacheOps.save(recipe);

  _cacheMisses++;
  return recipe;
}
```

### Cache Optimization (24-hour cleanup)

```dart
Future<void> _startCacheOptimization() async {
  Timer.periodic(Duration(hours: 24), (_) async {
    await _optimization.removeStaleEntries();
  });
}

Future<void> removeStaleEntries() async {
  final now = DateTime.now();
  final staleKeys = <String>[];

  for (final entry in _cache.entries) {
    final lastAccess = _lastAccess[entry.key] ?? now;
    if (now.difference(lastAccess).inHours > 24) {
      staleKeys.add(entry.key);
    }
  }

  for (final key in staleKeys) {
    _cache.remove(key);
  }
}
```

---

## Cache Priority Levels

```dart
enum CachePriority {
  high,    // Favorite recipes, recently viewed
  medium,  // Normal recipes
  low,     // Rarely accessed
}

// Priority affects eviction order
void _cacheWithPriority(Recipe recipe, CachePriority priority) {
  _priorities[recipe.id!] = priority;

  // High priority recipes get bonus in eviction score
  if (priority == CachePriority.high) {
    _accessCounts[recipe.id!] = (_accessCounts[recipe.id!] ?? 0) + 10;
  }
}
```

---

## Usage Patterns

### Pattern 1: Cache-First Read

```dart
Future<Recipe?> getRecipe(String recipeId) async {
  final cacheManager = ServiceLocator.get<IntelligentCacheManager>();

  // Try cache
  final cached = await cacheManager.getCachedRecipe(recipeId);
  if (cached != null) return cached;

  // Fetch from Firebase
  final recipe = await _recipeRepository.getById(recipeId);
  if (recipe == null) return null;

  // Cache for future
  await cacheManager.cacheRecipe(recipe);
  return recipe;
}
```

### Pattern 2: Prefetch User's Favorites

```dart
Future<void> prefetchFavorites() async {
  final cacheManager = ServiceLocator.get<IntelligentCacheManager>();
  final userService = ServiceLocator.get<UserService>();

  final favoriteIds = await userService.getFavoriteRecipeIds();
  await cacheManager.prefetchRecipes(favoriteIds);
}
```

### Pattern 3: Debounced Save

```dart
Future<void> updateRecipe(Recipe recipe) async {
  final cacheModule = ServiceLocator.get<RecipeCacheModule>();

  // Update in cache immediately
  await cacheModule.saveToCache(recipe);

  // Debounced save to Firebase (2 seconds)
  await cacheModule.debouncedSave(recipe);
}
```

---

## Cache Statistics

```dart
class CacheStatistics {
  final int totalCached;
  final int cacheHits;
  final int cacheMisses;
  final double hitRate;
  final int currentSize;
  final int maxSize;

  double get hitRatio => cacheHits / (cacheHits + cacheMisses);
  double get fillPercentage => (currentSize / maxSize) * 100;
}

// Monitor cache performance
final stats = cacheManager.getStatistics();
print('Cache hit rate: ${stats.hitRatio * 100}%');
print('Cache fill: ${stats.fillPercentage}%');
```

---

## Best Practices

1. **Use priority levels** - High for favorites, low for rarely accessed
2. **Monitor hit rate** - Target >80% hit rate
3. **Prefetch strategically** - User behavior, time of day
4. **Debounce writes** - Reduce Firebase operations
5. **Regular cleanup** - Remove stale data (24 hours)

---

## Related Resources

- [offline-service.md](offline-service.md) - OfflineService integration
- [sync-mechanisms.md](sync-mechanisms.md) - Firebase sync strategies

---

**Cache Limit**: 50MB
**Eviction**: LRU + access frequency
**Cleanup**: 24-hour automatic
**Status**: ✅ Production-ready
