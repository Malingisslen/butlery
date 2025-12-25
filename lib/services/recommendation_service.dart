// lib/services/recommendation_service.dart

import 'dart:async';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart' as perm;
import 'package:butlery/models/recommendation.dart';

/// Recommendation service for AI-powered content recommendations
class RecommendationService extends BaseService {
  @override
  String get serviceName => 'RecommendationService';

  // Cache for recommendations
  final Map<String, Recommendation> _recommendationCache = {};
  final Map<String, List<String>> _userRecommendations =
      {}; // userId -> recommendation IDs
  final Map<String, Map<FeedbackType, int>> _feedbackHistory =
      {}; // recommendationId -> feedback counts

  // Dismissed recommendations tracking
  final Map<String, Set<String>> _dismissedRecommendations =
      {}; // userId -> set of dismissed recommendation IDs
  final Map<String, DateTime> _dismissalTimestamps =
      {}; // recommendationId -> timestamp

  static const Duration _undoDismissalWindow = Duration(minutes: 5);

  RecommendationService();

  /// Generate personalized recommendations for user
  Future<List<Recommendation>> generateRecommendations({
    required String userId,
    int limit = 10,
    List<RecommendationType>? types,
  }) async {
    final result = await safeExecute(
      () async {
        AppLogger.info('🤖 Generating recommendations for user: $userId');

        // Get user's existing recommendations
        final existingIds = _userRecommendations[userId] ?? [];
        final recommendations = <Recommendation>[];

        // In a real implementation, this would use ML/AI to generate recommendations
        // For now, we'll create intelligent mock recommendations based on patterns

        // Get user preferences and history (mock)
        final userPreferences = await _getUserPreferences(userId);
        final recentActivity = await _getUserRecentActivity(userId);

        // Use recent activity to personalize recommendations
        final recentCategories = _extractCategoriesFromActivity(recentActivity);
        final personalizedPreferences =
            Map<String, dynamic>.from(userPreferences);

        // Enhance preferences based on recent activity
        if (recentCategories.isNotEmpty) {
          personalizedPreferences['recentCategories'] = recentCategories;
          personalizedPreferences['activityWeight'] =
              1.2; // Boost recent activity influence
        }

        AppLogger.debug(
            'User has ${existingIds.length} existing recommendations');
        AppLogger.debug('User has ${recentActivity.length} recent activities');
        AppLogger.debug('Personalized with categories: $recentCategories');

        // Generate different types of recommendations
        if (types == null ||
            types.contains(RecommendationType.similarToShared)) {
          recommendations.addAll(await _generateSimilarToSharedRecommendations(
              userId, userPreferences));
        }

        if (types == null ||
            types.contains(RecommendationType.trendingForYou)) {
          recommendations.addAll(
              await _generateTrendingRecommendations(userId, userPreferences));
        }

        if (types == null ||
            types.contains(RecommendationType.basedOnFriends)) {
          recommendations
              .addAll(await _generateFriendBasedRecommendations(userId));
        }

        if (types == null || types.contains(RecommendationType.seasonal)) {
          recommendations
              .addAll(await _generateSeasonalRecommendations(userPreferences));
        }

        // Filter out dismissed recommendations
        final dismissedIds = _dismissedRecommendations[userId] ?? {};
        final filteredRecommendations = recommendations
            .where((rec) => !dismissedIds.contains(rec.id))
            .toList();

        // Sort by relevance score
        filteredRecommendations.sort((a, b) => b.score.compareTo(a.score));

        // Limit results
        final limitedRecommendations =
            filteredRecommendations.take(limit).toList();

        // Cache recommendations
        for (final rec in limitedRecommendations) {
          _recommendationCache[rec.id] = rec;
        }

        // Track user recommendations
        _userRecommendations[userId] =
            limitedRecommendations.map((r) => r.id).toList();

        AppLogger.success(
            '✅ Generated ${limitedRecommendations.length} recommendations');
        return limitedRecommendations;
      },
      operationName: 'Generate Recommendations',
      customErrorMessage: 'Failed to generate recommendations',
    );

    return result ?? [];
  }

  /// Provide feedback on a recommendation
  Future<void> provideFeedback(
      String recommendationId, FeedbackType feedbackType) async {
    await safeExecute(
      () async {
        AppLogger.info(
            '👍 Recording feedback: $feedbackType for recommendation: $recommendationId');

        final recommendation = _recommendationCache[recommendationId];
        if (recommendation == null) {
          throw Exception('Recommendation not found');
        }

        // Update recommendation state
        switch (feedbackType) {
          case FeedbackType.like:
            recommendation.isLiked = true;
            recommendation.isDismissed = false;
            break;
          case FeedbackType.dismiss:
          case FeedbackType.notInterested:
            recommendation.isDismissed = true;
            recommendation.isLiked = false;
            break;
          case FeedbackType.save:
            recommendation.isLiked = true;
            break;
        }

        // Track feedback history
        _feedbackHistory.putIfAbsent(recommendationId, () => {});
        _feedbackHistory[recommendationId]![feedbackType] =
            (_feedbackHistory[recommendationId]![feedbackType] ?? 0) + 1;

        // Update recommendation score based on feedback
        await _updateRecommendationScore(recommendation, feedbackType);

        // Learn from feedback for future recommendations
        await _learnFromFeedback(recommendation, feedbackType);

        AppLogger.success('✅ Feedback recorded successfully');
      },
      operationName: 'Provide Recommendation Feedback',
      customErrorMessage: 'Failed to record feedback',
    );
  }

  /// Dismiss a recommendation
  Future<void> dismissRecommendation(String recommendationId) async {
    await safeExecute(
      () async {
        AppLogger.info('🚫 Dismissing recommendation: $recommendationId');

        final recommendation = _recommendationCache[recommendationId];
        if (recommendation == null) {
          throw Exception('Recommendation not found');
        }

        // Get current user ID from permission service
        final permissionService = ServiceLocator.get<perm.PermissionService>();
        final userId = permissionService.currentUserId ?? 'anonymous';

        // Mark as dismissed
        recommendation.isDismissed = true;
        _dismissedRecommendations
            .putIfAbsent(userId, () => {})
            .add(recommendationId);
        _dismissalTimestamps[recommendationId] = DateTime.now();

        // Record dismissal feedback
        await provideFeedback(recommendationId, FeedbackType.dismiss);

        AppLogger.success('✅ Recommendation dismissed');
      },
      operationName: 'Dismiss Recommendation',
      customErrorMessage: 'Failed to dismiss recommendation',
    );
  }

  /// Undo dismissal of a recommendation
  Future<void> undoDismissal(String recommendationId) async {
    await safeExecute(
      () async {
        AppLogger.info(
            '↩️ Undoing dismissal for recommendation: $recommendationId');

        final dismissalTime = _dismissalTimestamps[recommendationId];
        if (dismissalTime == null) {
          throw Exception('Recommendation was not dismissed');
        }

        // Check if within undo window
        if (DateTime.now().difference(dismissalTime) > _undoDismissalWindow) {
          throw Exception('Undo window has expired');
        }

        final recommendation = _recommendationCache[recommendationId];
        if (recommendation == null) {
          throw Exception('Recommendation not found');
        }

        // Get current user ID from permission service
        final permissionService = ServiceLocator.get<perm.PermissionService>();
        final userId = permissionService.currentUserId ?? 'anonymous';

        // Remove from dismissed set
        recommendation.isDismissed = false;
        _dismissedRecommendations[userId]?.remove(recommendationId);
        _dismissalTimestamps.remove(recommendationId);

        AppLogger.success('✅ Dismissal undone');
      },
      operationName: 'Undo Recommendation Dismissal',
      customErrorMessage: 'Failed to undo dismissal',
    );
  }

  Future<Map<String, dynamic>> _getUserPreferences(String userId) async {
    // In real implementation, this would fetch from user preferences service
    return {
      'dietaryRestrictions': ['vegetarian'],
      'cuisinePreferences': ['italian', 'swedish', 'asian'],
      'cookingTime': 'quick', // quick, moderate, long
      'skillLevel': 'intermediate',
      'familySize': 4,
    };
  }

  Future<List<String>> _getUserRecentActivity(String userId) async {
    // In real implementation, this would fetch from activity tracking
    return ['recipe_123', 'menu_456', 'recipe_789'];
  }

  Future<List<Recommendation>> _generateSimilarToSharedRecommendations(
    String userId,
    Map<String, dynamic> preferences,
  ) async {
    // Generate recommendations similar to what user has shared
    return [
      Recommendation(
        id: 'rec_similar_${DateTime.now().millisecondsSinceEpoch}',
        contentId: 'recipe_similar_1',
        contentType: 'recipe',
        title: 'Krämig vegetarisk pasta',
        description: 'En härlig pastarätt med färska grönsaker',
        reason: 'Liknar din delade "Grönsakslasagne"',
        type: RecommendationType.similarToShared,
        score: 0.92,
      ),
    ];
  }

  Future<List<Recommendation>> _generateTrendingRecommendations(
    String userId,
    Map<String, dynamic> preferences,
  ) async {
    // Generate trending recommendations personalized for user
    return [
      Recommendation(
        id: 'rec_trending_${DateTime.now().millisecondsSinceEpoch}',
        contentId: 'recipe_trending_1',
        contentType: 'recipe',
        title: 'One-pot pasta med kyckling',
        description: 'Snabb vardagsrätt på 20 minuter',
        reason: 'Populärt bland användare med liknande smak',
        type: RecommendationType.trendingForYou,
        score: 0.88,
      ),
    ];
  }

  Future<List<Recommendation>> _generateFriendBasedRecommendations(
      String userId) async {
    // Generate recommendations based on friends' activity
    return [
      Recommendation(
        id: 'rec_friends_${DateTime.now().millisecondsSinceEpoch}',
        contentId: 'recipe_friends_1',
        contentType: 'recipe',
        title: 'Asiatisk wok med tofu',
        description: 'Smakrik vegetarisk wok',
        reason: '5 av dina vänner har sparat detta',
        type: RecommendationType.basedOnFriends,
        score: 0.85,
      ),
    ];
  }

  Future<List<Recommendation>> _generateSeasonalRecommendations(
    Map<String, dynamic> preferences,
  ) async {
    // Generate seasonal recommendations
    final month = DateTime.now().month;
    String seasonalTitle;
    String seasonalDescription;

    if (month >= 6 && month <= 8) {
      // Summer
      seasonalTitle = 'Fräsch sommarsallad';
      seasonalDescription = 'Perfekt för varma sommardagar';
    } else if (month >= 12 || month <= 2) {
      // Winter
      seasonalTitle = 'Varm vintersoppa';
      seasonalDescription = 'Värmande och mättande';
    } else if (month >= 3 && month <= 5) {
      // Spring
      seasonalTitle = 'Vårig sparrispasta';
      seasonalDescription = 'Med färsk sparris och citron';
    } else {
      // Fall
      seasonalTitle = 'Höstgryta med rotfrukter';
      seasonalDescription = 'Mustigt och gott';
    }

    return [
      Recommendation(
        id: 'rec_seasonal_${DateTime.now().millisecondsSinceEpoch}',
        contentId: 'recipe_seasonal_1',
        contentType: 'recipe',
        title: seasonalTitle,
        description: seasonalDescription,
        reason: 'Säsongsanpassat recept',
        type: RecommendationType.seasonal,
        score: 0.82,
      ),
    ];
  }

  Future<void> _updateRecommendationScore(
      Recommendation recommendation, FeedbackType feedback) async {
    // Adjust score based on feedback
    switch (feedback) {
      case FeedbackType.like:
      case FeedbackType.save:
        recommendation.score = (recommendation.score * 1.1).clamp(0.0, 1.0);
        break;
      case FeedbackType.dismiss:
      case FeedbackType.notInterested:
        recommendation.score = (recommendation.score * 0.8).clamp(0.0, 1.0);
        break;
    }
  }

  Future<void> _learnFromFeedback(
      Recommendation recommendation, FeedbackType feedback) async {
    // In real implementation, this would update ML model or preference weights
    AppLogger.debug(
        'Learning from feedback: ${recommendation.type} -> $feedback');

    // Track patterns for future recommendations
    // This would typically involve:
    // 1. Updating user preference weights
    // 2. Adjusting recommendation algorithm parameters
    // 3. Training ML models with feedback data
  }

  /// Get recommendation by ID
  Recommendation? getRecommendation(String recommendationId) {
    return _recommendationCache[recommendationId];
  }

  /// Get user's current recommendations
  List<Recommendation> getUserRecommendations(String userId) {
    final recommendationIds = _userRecommendations[userId] ?? [];
    return recommendationIds
        .map((id) => _recommendationCache[id])
        .where((rec) => rec != null)
        .cast<Recommendation>()
        .toList();
  }

  /// Clear dismissed recommendations older than specified duration
  Future<void> clearOldDismissals(
      {Duration age = const Duration(days: 30)}) async {
    final cutoffTime = DateTime.now().subtract(age);
    final toRemove = <String>[];

    for (final entry in _dismissalTimestamps.entries) {
      if (entry.value.isBefore(cutoffTime)) {
        toRemove.add(entry.key);
      }
    }

    for (final recId in toRemove) {
      _dismissalTimestamps.remove(recId);
      for (final set in _dismissedRecommendations.values) {
        set.remove(recId);
      }
    }

    AppLogger.info('Cleared ${toRemove.length} old dismissals');
  }

  /// Extract categories from user's recent activity for personalization
  List<String> _extractCategoriesFromActivity(List<String> recentActivity) {
    // In a real implementation, this would analyze the activity to extract categories
    // For now, return some common categories based on activity patterns
    final categories = <String>[];

    if (recentActivity.isNotEmpty) {
      // Mock category extraction based on activity patterns
      if (recentActivity.length >= 3) {
        categories.addAll(['popular', 'quick']);
      }
      if (recentActivity
          .any((id) => id.contains('vegetarian') || id.contains('veg'))) {
        categories.add('vegetarian');
      }
      if (recentActivity
          .any((id) => id.contains('pasta') || id.contains('italian'))) {
        categories.add('italian');
      }
    }

    return categories;
  }

  /// Get recommendation statistics
  Map<String, dynamic> getRecommendationStats() {
    int totalLikes = 0;
    int totalDismissals = 0;

    for (final feedback in _feedbackHistory.values) {
      totalLikes += feedback[FeedbackType.like] ?? 0;
      totalDismissals += feedback[FeedbackType.dismiss] ?? 0;
    }

    return {
      'totalRecommendations': _recommendationCache.length,
      'totalLikes': totalLikes,
      'totalDismissals': totalDismissals,
      'likeRate': _recommendationCache.isNotEmpty
          ? (totalLikes / _recommendationCache.length * 100).round()
          : 0,
    };
  }

  @override
  Future<void> onDispose() async {
    _recommendationCache.clear();
    _userRecommendations.clear();
    _feedbackHistory.clear();
    _dismissedRecommendations.clear();
    _dismissalTimestamps.clear();
  }
}
