/// Intelligent cache manager with predictive loading and user behavior analysis.
/// This service implements advanced caching strategies to optimize app performance
/// by predicting what content users are likely to need next and preloading it.
/// Features:
/// - User behavior pattern analysis
/// - Predictive recipe prefetching
/// - Friends' activity caching
/// - Smart cache eviction policies
/// - Memory pressure handling

import 'package:clock/clock.dart';
import 'dart:async';
import 'package:butlery/core/cache/json_cache_helper.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/offline_service.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// User behavior pattern data
class UserBehaviorPattern {
  final String userId;
  final Map<String, int> recipeViews; // recipeId -> view count
  final Map<String, DateTime> lastViewedTimes; // recipeId -> last viewed
  final Map<String, int> mealTypePreferences; // mealType -> count
  final Map<int, int> viewTimePreferences; // hour of day -> count
  final Set<String> favoriteRecipeIds;
  final Set<String>
  activeFriendIds; // Friends whose content is frequently viewed

  UserBehaviorPattern({
    required this.userId,
    Map<String, int>? recipeViews,
    Map<String, DateTime>? lastViewedTimes,
    Map<String, int>? mealTypePreferences,
    Map<int, int>? viewTimePreferences,
    Set<String>? favoriteRecipeIds,
    Set<String>? activeFriendIds,
  }) : recipeViews = recipeViews.orEmpty(),
       lastViewedTimes = lastViewedTimes.orEmpty(),
       mealTypePreferences = mealTypePreferences.orEmpty(),
       viewTimePreferences = viewTimePreferences.orEmpty(),
       favoriteRecipeIds = favoriteRecipeIds ?? {},
       activeFriendIds = activeFriendIds ?? {};

  /// Get likely recipes based on current time and preferences
  List<String> getLikelyRecipeIds({int limit = 10}) {
    final sortedRecipes = recipeViews.entries.toList()
      ..sort((a, b) {
        // Weight by view count and recency
        final aScore = a.value * _getRecencyScore(lastViewedTimes[a.key]);
        final bScore = b.value * _getRecencyScore(lastViewedTimes[b.key]);
        return bScore.compareTo(aScore);
      });

    return sortedRecipes.take(limit).map((e) => e.key).toList();
  }

  double _getRecencyScore(DateTime? lastViewed) {
    if (lastViewed == null) return 0.5;
    final daysSince = clock.now().difference(lastViewed).inDays;
    // Exponential decay: recent views score higher
    return 1.0 / (1.0 + daysSince * 0.1);
  }

  Map<String, dynamic> toJson() => {
    'userId': userId,
    'recipeViews': recipeViews,
    'lastViewedTimes': lastViewedTimes.map(
      (k, v) => MapEntry(k, v.toIso8601String()),
    ),
    'mealTypePreferences': mealTypePreferences,
    'viewTimePreferences': viewTimePreferences,
    'favoriteRecipeIds': favoriteRecipeIds.toList(),
    'activeFriendIds': activeFriendIds.toList(),
  };

  factory UserBehaviorPattern.fromJson(Map<String, dynamic> json) {
    return UserBehaviorPattern(
      userId: json['userId'],
      recipeViews: Map<String, int>.from(
        (json['recipeViews'] as Map?).orEmpty(),
      ),
      lastViewedTimes: ((json['lastViewedTimes'] as Map<String, dynamic>?)?.map(
        (k, v) => MapEntry(k, DateTime.tryParse(v) ?? clock.now()),
      )).orEmpty(),
      mealTypePreferences: Map<String, int>.from(
        (json['mealTypePreferences'] as Map?).orEmpty(),
      ),
      viewTimePreferences:
          SerializationUtils.safeIntKeyIntMap(json, 'viewTimePreferences') ??
          {},
      favoriteRecipeIds: Set<String>.from(
        (json['favoriteRecipeIds'] as List?).orEmpty(),
      ),
      activeFriendIds: Set<String>.from(
        (json['activeFriendIds'] as List?).orEmpty(),
      ),
    );
  }
}

/// Cache entry with metadata for intelligent eviction
class CacheEntry<T> {
  final String key;
  final T data;
  final DateTime cachedAt;
  final int size; // Approximate size in bytes
  int accessCount;
  DateTime lastAccessed;

  CacheEntry({
    required this.key,
    required this.data,
    required this.size,
    DateTime? cachedAt,
  }) : cachedAt = cachedAt.orNow(),
       lastAccessed = clock.now(),
       accessCount = 0;

  /// Update access statistics
  void recordAccess() {
    accessCount++;
    lastAccessed = clock.now();
  }

  /// Calculate priority score for eviction (lower = more likely to evict)
  double get evictionScore {
    final age = clock.now().difference(cachedAt).inMinutes;
    final recency = clock.now().difference(lastAccessed).inMinutes;

    // Favor frequently accessed and recently accessed items
    return (accessCount * 10.0) / (1.0 + recency * 0.1) / (1.0 + age * 0.01);
  }
}

/// Intelligent cache manager service
class IntelligentCacheManager {
  // Dependencies (lazy loaded via getter)
  final Map<String, CacheEntry<Recipe>> _recipeCache = {};
  final Map<String, CacheEntry<UserProfile>> _userCache = {};
  final Map<String, CacheEntry<dynamic>> _genericCache = {};

  // Configuration
  static const int _maxMemoryMB = 50; // Maximum cache size in MB
  static const int _prefetchLimit = 20; // Max items to prefetch
  static const Duration _prefetchInterval = Duration(minutes: 5);
  static const Duration _behaviorSaveInterval = Duration(minutes: 10);

  // State
  UserBehaviorPattern? _currentPattern;
  Timer? _prefetchTimer;
  Timer? _behaviorSaveTimer;
  bool _clearInProgress = false;

  // Services (lazy loaded)
  UnifiedRecipeService? _recipeService;
  UnifiedFriendsService? _friendsService;
  PermissionService? _permissionService;

  IntelligentCacheManager();

  /// Lazy getter for behavior cache - initializes from OfflineService when first accessed
  JsonCacheHelper get _behaviorCache {
    if (_behaviorCacheField == null) {
      final offlineService = ServiceLocator.get<OfflineService>();
      _behaviorCacheField = JsonCacheHelper(
        'intelligent_cache_behavior',
        offlineService.database.cacheDao,
      );
    }
    return _behaviorCacheField!;
  }

  JsonCacheHelper? _behaviorCacheField;

  /// Initialize the cache manager
  Future<void> initialize() async {
    try {
      AppLogger.info('🧠 Initializing IntelligentCacheManager...');

      // Load user behavior patterns
      await _loadBehaviorPattern();

      // Start periodic prefetching
      _startPrefetchTimer();

      // Start periodic behavior saving
      _startBehaviorSaveTimer();

      AppLogger.success('✅ IntelligentCacheManager initialized');
    } catch (e) {
      AppLogger.error('❌ Failed to initialize IntelligentCacheManager: $e');
    }
  }

  /// Get cached recipe with intelligent loading
  Future<Recipe?> getCachedRecipe(String recipeId) async {
    // Check memory cache first
    final cached = _recipeCache[recipeId];
    if (cached != null) {
      cached.recordAccess();
      _recordRecipeView(recipeId);
      return cached.data;
    }

    // Try to load from service
    try {
      _recipeService ??= ServiceLocator.get<UnifiedRecipeService>();
      // ignore: await_only_futures
      final recipe = await _recipeService!.getRecipeById(recipeId);

      if (recipe != null) {
        _cacheRecipe(recipe);
        _recordRecipeView(recipeId);
      }

      return recipe;
    } catch (e) {
      AppLogger.error('Failed to load recipe $recipeId: $e');
      return null;
    }
  }

  /// Preload likely content based on user patterns
  Future<void> preloadLikelyContent(String userId) async {
    try {
      if (_currentPattern == null || _currentPattern!.userId != userId) {
        await _loadBehaviorPattern();
      }

      final patterns = _currentPattern;
      if (patterns == null) return;

      AppLogger.info('🔮 Preloading content for user based on patterns...');

      // Preload likely recipes
      final likelyRecipeIds = patterns.getLikelyRecipeIds(
        limit: _prefetchLimit,
      );
      await _preloadRecipes(likelyRecipeIds);

      // Preload active friends' recent recipes
      await _preloadFriendsActivity(patterns.activeFriendIds);

      // Preload based on current time preferences
      await _preloadTimeBasedContent(patterns);

      AppLogger.success('✅ Preloaded ${likelyRecipeIds.length} likely recipes');
    } catch (e) {
      AppLogger.error('Failed to preload content: $e');
    }
  }

  /// Compute current memory usage from actual cache contents
  int get _currentMemoryUsage {
    var total = 0;
    for (final entry in _recipeCache.values) {
      total += entry.size;
    }
    for (final entry in _userCache.values) {
      total += entry.size;
    }
    for (final entry in _genericCache.values) {
      total += entry.size;
    }
    return total;
  }

  /// Cache a recipe with memory management
  void _cacheRecipe(Recipe recipe) {
    if (_clearInProgress) return;

    final size = _estimateRecipeSize(recipe);

    // Check memory pressure
    _ensureMemoryAvailable(size);

    _recipeCache[recipe.id] = CacheEntry(
      key: recipe.id,
      data: recipe,
      size: size,
    );
  }

  /// Preload multiple recipes
  Future<void> _preloadRecipes(List<String> recipeIds) async {
    _recipeService ??= ServiceLocator.get<UnifiedRecipeService>();

    // Filter out already cached recipes
    final toLoad = recipeIds
        .where((id) => !_recipeCache.containsKey(id))
        .toList();

    if (toLoad.isEmpty) return;

    // Load in parallel with limited concurrency
    const batchSize = 5;
    for (var i = 0; i < toLoad.length; i += batchSize) {
      final batch = toLoad.skip(i).take(batchSize).toList();

      await Future.wait(
        batch.map((id) async {
          try {
            // ignore: await_only_futures
            final recipe = await _recipeService!.getRecipeById(id);
            if (recipe != null) {
              _cacheRecipe(recipe);
            }
          } catch (e) {
            AppLogger.debug('Failed to preload recipe $id: $e');
          }
        }),
      );
    }
  }

  /// Preload friends' recent activity
  Future<void> _preloadFriendsActivity(Set<String> friendIds) async {
    if (friendIds.isEmpty) return;

    try {
      _friendsService ??= ServiceLocator.get<UnifiedFriendsService>();
      _recipeService ??= ServiceLocator.get<UnifiedRecipeService>();

      // Get friends' recent recipes (would need to implement this method)
      // For now, we'll simulate by preloading some recipes

      AppLogger.debug(
        'Preloading activity for ${friendIds.length} active friends',
      );
    } catch (e) {
      AppLogger.error('Failed to preload friends activity: $e');
    }
  }

  /// Preload content based on time of day preferences
  Future<void> _preloadTimeBasedContent(UserBehaviorPattern patterns) async {
    final currentHour = clock.now().hour;

    // Determine meal type based on time
    String mealType;
    if (currentHour >= 5 && currentHour < 11) {
      mealType = 'Frukost';
    } else if (currentHour >= 11 && currentHour < 14) {
      mealType = 'Lunch';
    } else if (currentHour >= 14 && currentHour < 17) {
      mealType = 'Mellanmål';
    } else {
      mealType = 'Middag';
    }

    // Find user's preferred recipes for this meal type
    final preferredForMealType = patterns.recipeViews.entries
        .where((e) => _recipeCache[e.key]?.data.mealType == mealType)
        .map((e) => e.key)
        .take(5)
        .toList();

    if (preferredForMealType.isNotEmpty) {
      await _preloadRecipes(preferredForMealType);
    }
  }

  /// Record a recipe view for pattern analysis
  void _recordRecipeView(String recipeId) {
    _currentPattern ??= UserBehaviorPattern(
      userId: (_permissionService?.currentUserId).orDefault('anonymous'),
    );

    // Update view count
    _currentPattern!.recipeViews[recipeId] =
        (_currentPattern!.recipeViews[recipeId]).orZero() + 1;

    // Update last viewed time
    _currentPattern!.lastViewedTimes[recipeId] = clock.now();

    // Update time preferences
    final hour = clock.now().hour;
    _currentPattern!.viewTimePreferences[hour] =
        (_currentPattern!.viewTimePreferences[hour]).orZero() + 1;

    // Update meal type preferences if recipe is cached
    final recipe = _recipeCache[recipeId]?.data;
    if (recipe != null) {
      _currentPattern!.mealTypePreferences[recipe.mealType] =
          (_currentPattern!.mealTypePreferences[recipe.mealType]).orZero() + 1;
    }
  }

  /// Ensure enough memory is available
  void _ensureMemoryAvailable(int requiredBytes) {
    const maxBytes = _maxMemoryMB * 1024 * 1024;

    if (_currentMemoryUsage + requiredBytes <= maxBytes) {
      return; // Enough space available
    }

    AppLogger.debug('Cache memory pressure: need to free $requiredBytes bytes');

    // Collect all cache entries for eviction scoring
    final List<CacheEntry> allEntries = [];
    allEntries.addAll(_recipeCache.values);
    allEntries.addAll(_userCache.values);
    allEntries.addAll(_genericCache.values);

    // Sort by eviction score (ascending - lower scores evicted first)
    allEntries.sort((a, b) => a.evictionScore.compareTo(b.evictionScore));

    // Evict entries until we have enough space
    var freedBytes = 0;
    for (final entry in allEntries) {
      if (freedBytes >= requiredBytes) break;

      // Remove from appropriate cache
      if (entry.data is Recipe) {
        _recipeCache.remove(entry.key);
      } else if (entry.data is UserProfile) {
        _userCache.remove(entry.key);
      } else {
        _genericCache.remove(entry.key);
      }

      freedBytes += entry.size;

      AppLogger.debug(
        'Evicted cache entry: ${entry.key} (score: ${entry.evictionScore.toStringAsFixed(2)})',
      );
    }
  }

  /// Estimate recipe size in bytes
  int _estimateRecipeSize(Recipe recipe) {
    // Rough estimation based on content
    var size = 500; // Base size
    size += recipe.title.length * 2; // UTF-16
    size += recipe.description.length * 2;
    size += recipe.ingredients.fold(0, (sum, i) => sum + i.length * 2);
    size += recipe.instructions.fold(0, (sum, i) => sum + i.length * 2);
    size += recipe.imageUrls.length * 100; // URL references
    return size;
  }

  /// Load behavior pattern from cache
  Future<void> _loadBehaviorPattern() async {
    try {
      _permissionService ??= ServiceLocator.get<PermissionService>();
      final userId = _permissionService!.currentUserId;

      if (userId == null) return;

      _behaviorCache.setCurrentUser(userId);
      final data = await _behaviorCache.loadJson('behavior_pattern');

      if (data != null) {
        _currentPattern = UserBehaviorPattern.fromJson(data);
        AppLogger.debug(
          'Loaded behavior pattern for user ${userId.maskedUserId}',
        );
      } else {
        _currentPattern = UserBehaviorPattern(userId: userId);
      }
    } catch (e) {
      AppLogger.error('Failed to load behavior pattern: $e');
    }
  }

  /// Save behavior pattern to cache
  Future<void> _saveBehaviorPattern() async {
    try {
      if (_currentPattern == null) return;

      await _behaviorCache.saveJson(
        'behavior_pattern',
        _currentPattern!.toJson(),
      );
      AppLogger.debug('Saved behavior pattern');
    } catch (e) {
      AppLogger.error('Failed to save behavior pattern: $e');
    }
  }

  /// Start periodic prefetching
  void _startPrefetchTimer() {
    _prefetchTimer?.cancel();
    _prefetchTimer = Timer.periodic(_prefetchInterval, (_) async {
      final userId = _permissionService?.currentUserId;
      if (userId != null) {
        await preloadLikelyContent(userId);
      }
    });
  }

  /// Start periodic behavior saving
  void _startBehaviorSaveTimer() {
    _behaviorSaveTimer?.cancel();
    _behaviorSaveTimer = Timer.periodic(_behaviorSaveInterval, (_) async {
      await _saveBehaviorPattern();
    });
  }

  /// Get cache statistics
  Map<String, dynamic> getCacheStats() {
    return {
      'recipesCached': _recipeCache.length,
      'usersCached': _userCache.length,
      'genericCached': _genericCache.length,
      'memoryUsageMB': (_currentMemoryUsage / 1024 / 1024).toStringAsFixed(2),
      'maxMemoryMB': _maxMemoryMB,
      'behaviorPatternLoaded': _currentPattern != null,
    };
  }

  /// Clear all caches
  Future<void> clearCache() async {
    _clearInProgress = true;
    try {
      _recipeCache.clear();
      _userCache.clear();
      _genericCache.clear();

      await _behaviorCache.clear();

      AppLogger.info('Cleared all intelligent caches');
    } finally {
      _clearInProgress = false;
    }
  }

  /// Pause background operations when app goes to background.
  /// Stops prefetch timer and behavior save timer to save battery.
  void onAppPaused() {
    _prefetchTimer?.cancel();
    _prefetchTimer = null;
    _behaviorSaveTimer?.cancel();
    _behaviorSaveTimer = null;
    _saveBehaviorPattern(); // Save before pausing
    AppLogger.debug(
      'IntelligentCacheManager paused - background operations stopped',
    );
  }

  /// Resume background operations when app returns to foreground.
  void onAppResumed() {
    _startPrefetchTimer();
    _startBehaviorSaveTimer();
    AppLogger.debug(
      'IntelligentCacheManager resumed - background operations started',
    );
  }

  /// Handle system memory pressure by aggressively clearing caches.
  /// Called when the system is running low on memory and needs apps to free resources.
  /// This method clears all caches except the current user's essential data.
  void handleMemoryPressure() {
    AppLogger.warning(
      'Memory pressure detected - clearing caches aggressively',
    );

    final beforeMemory = _currentMemoryUsage;

    // Clear all recipe cache
    _recipeCache.clear();

    // Clear generic cache
    _genericCache.clear();

    // Keep only current user in user cache
    final currentUserId = _permissionService?.currentUserId;
    if (currentUserId != null) {
      final currentUserEntry = _userCache[currentUserId];
      _userCache.clear();
      if (currentUserEntry != null) {
        _userCache[currentUserId] = currentUserEntry;
      }
    } else {
      _userCache.clear();
    }

    final freedMemory = beforeMemory - _currentMemoryUsage;
    final freedMB = (freedMemory / 1024 / 1024).toStringAsFixed(2);

    AppLogger.info(
      'Memory pressure handled: freed ${freedMB}MB, keeping ${_userCache.length} user entries',
    );
  }

  /// Dispose of resources
  void dispose() {
    _prefetchTimer?.cancel();
    _behaviorSaveTimer?.cancel();
    _saveBehaviorPattern(); // Final save
    _behaviorCache.dispose();
  }
}
