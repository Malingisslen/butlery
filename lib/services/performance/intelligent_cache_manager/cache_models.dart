import 'package:clock/clock.dart';
import 'package:butlery/core/utils/serialization_utils.dart';
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
