// lib/viewmodels/discovery_dashboard/discovery_recommendations_manager.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/services/recommendation_service.dart';
import 'package:butlery/models/recommendation.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// Manages personalized recommendations for the discovery dashboard.
/// Handles AI-powered content recommendations with user feedback and learning.
class DiscoveryRecommendationsManager extends ChangeNotifier {
  final RecommendationService _recommendationService;

  // Recommendations state
  List<Map<String, dynamic>> _personalizedRecommendations = [];
  bool _isLoading = false;
  String? _error;

  DiscoveryRecommendationsManager({
    required RecommendationService recommendationService,
  }) : _recommendationService = recommendationService;

  // ===== GETTERS =====

  List<Map<String, dynamic>> get personalizedRecommendations =>
      List.unmodifiable(_personalizedRecommendations);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasRecommendations => _personalizedRecommendations.isNotEmpty;
  int get recommendationsCount => _personalizedRecommendations.length;

  /// Get active (non-dismissed) recommendations
  List<Map<String, dynamic>> get activeRecommendations {
    return _personalizedRecommendations
        .where((rec) => rec['isDismissed'] != true)
        .toList();
  }

  /// Get liked recommendations
  List<Map<String, dynamic>> get likedRecommendations {
    return _personalizedRecommendations
        .where((rec) => rec['isLiked'] == true)
        .toList();
  }

  // ===== RECOMMENDATIONS LOADING =====

  /// Load personalized content recommendations
  Future<void> loadPersonalizedRecommendations() async {
    _setLoading(true);
    _clearError();

    try {
      AppLogger.info('🎯 Loading personalized recommendations');

      // Get current user ID from permission service
      final permissionService = ServiceLocator.get<PermissionService>();
      final userId = permissionService.currentUserId;

      if (userId == null) {
        AppLogger.warning('⚠️ No user ID available for recommendations');
        _personalizedRecommendations = [];
        notifyListeners();
        return;
      }

      // Generate recommendations using the AI-powered recommendation service
      final recommendations =
          await _recommendationService.generateRecommendations(
        userId: userId,
        limit: 15,
      );

      // Convert Recommendation objects to the expected Map format
      _personalizedRecommendations = recommendations.map((rec) {
        return {
          'id': rec.id,
          'type': rec.type.toString().split('.').last,
          'title': rec.title,
          'description': rec.description,
          'imageUrl': rec.imageUrl,
          'reason': rec.reason,
          'contentType': rec.contentType,
          'contentId': rec.contentId,
          'score': rec.score,
          'isDismissed': rec.isDismissed,
          'isLiked': rec.isLiked,
          'metadata': rec.metadata,
        };
      }).toList();

      AppLogger.success(
          '✅ Loaded ${_personalizedRecommendations.length} personalized recommendations');
      notifyListeners();
    } catch (e) {
      _setError('Failed to load recommendations: $e');
      AppLogger.error('❌ Failed to load personalized recommendations', e);
      _personalizedRecommendations = [];
      notifyListeners();
      rethrow; // Rethrow to allow parent to handle error
    } finally {
      _setLoading(false);
    }
  }

  /// Provide feedback on a recommendation
  Future<void> provideRecommendationFeedback(
      String recommendationId, FeedbackType feedbackType) async {
    try {
      AppLogger.info('👍 Providing recommendation feedback: $feedbackType');

      await _recommendationService.provideFeedback(
          recommendationId, feedbackType);

      // Update local state
      final index = _personalizedRecommendations
          .indexWhere((rec) => rec['id'] == recommendationId);
      if (index != -1) {
        switch (feedbackType) {
          case FeedbackType.like:
            _personalizedRecommendations[index]['isLiked'] = true;
            _personalizedRecommendations[index]['isDismissed'] = false;
            break;
          case FeedbackType.dismiss:
          case FeedbackType.notInterested:
            _personalizedRecommendations[index]['isDismissed'] = true;
            _personalizedRecommendations[index]['isLiked'] = false;
            break;
          case FeedbackType.save:
            _personalizedRecommendations[index]['isSaved'] = true;
            _personalizedRecommendations[index]['isDismissed'] = false;
            break;
        }
        notifyListeners();
      }

      AppLogger.success('✅ Recommendation feedback provided successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to provide recommendation feedback', e);
      _setError('Failed to provide feedback: $e');
    }
  }

  /// Dismiss a recommendation
  Future<void> dismissRecommendation(String recommendationId) async {
    await provideRecommendationFeedback(recommendationId, FeedbackType.dismiss);
  }

  /// Like a recommendation
  Future<void> likeRecommendation(String recommendationId) async {
    await provideRecommendationFeedback(recommendationId, FeedbackType.like);
  }

  /// Undo recommendation dismissal
  Future<void> undoRecommendationDismissal(String recommendationId) async {
    try {
      AppLogger.info('↩️ Undoing recommendation dismissal');

      await _recommendationService.undoDismissal(recommendationId);

      // Update local state
      final index = _personalizedRecommendations
          .indexWhere((rec) => rec['id'] == recommendationId);
      if (index != -1) {
        _personalizedRecommendations[index]['isDismissed'] = false;
        notifyListeners();
      }

      AppLogger.success('✅ Recommendation dismissal undone successfully');
    } catch (e) {
      AppLogger.error('❌ Failed to undo recommendation dismissal', e);
      _setError('Failed to undo dismissal: $e');
    }
  }

  /// Load more recommendations for pagination
  Future<void> loadMoreRecommendations() async {
    try {
      AppLogger.info('📄 Loading more recommendations');

      // Get current user ID from permission service
      final permissionService = ServiceLocator.get<PermissionService>();
      final userId = permissionService.currentUserId;

      if (userId == null) {
        AppLogger.warning('⚠️ No user ID available for more recommendations');
        return;
      }

      // Generate more recommendations using the AI-powered recommendation service
      final moreRecommendations =
          await _recommendationService.generateRecommendations(
        userId: userId,
        limit: 8,
      );

      // Convert and add new recommendations
      final newRecommendationMaps = moreRecommendations.map((rec) {
        return {
          'id': rec.id,
          'type': rec.type.toString().split('.').last,
          'title': rec.title,
          'description': rec.description,
          'imageUrl': rec.imageUrl,
          'reason': rec.reason,
          'contentType': rec.contentType,
          'contentId': rec.contentId,
          'score': rec.score,
          'isDismissed': rec.isDismissed,
          'isLiked': rec.isLiked,
          'metadata': rec.metadata,
        };
      }).toList();

      _personalizedRecommendations.addAll(newRecommendationMaps);
      AppLogger.success(
          '✅ Loaded ${newRecommendationMaps.length} more recommendations');
      notifyListeners();
    } catch (e) {
      AppLogger.error('❌ Failed to load more recommendations', e);
      _setError('Failed to load more recommendations: $e');
    }
  }

  /// Refresh recommendations
  Future<void> refreshRecommendations() async {
    await loadPersonalizedRecommendations();
  }

  /// Clear all recommendations (useful for logout/reset)
  void clearRecommendations() {
    _personalizedRecommendations.clear();
    _clearError();
    notifyListeners();
  }

  /// Get recommendation by ID
  Map<String, dynamic>? getRecommendation(String recommendationId) {
    try {
      return _personalizedRecommendations
          .firstWhere((rec) => rec['id'] == recommendationId);
    } catch (e) {
      return null;
    }
  }

  /// Get recommendations by type
  List<Map<String, dynamic>> getRecommendationsByType(String type) {
    return _personalizedRecommendations
        .where((rec) => rec['type'] == type)
        .toList();
  }

  /// Get recommendations by content type
  List<Map<String, dynamic>> getRecommendationsByContentType(
      String contentType) {
    return _personalizedRecommendations
        .where((rec) => rec['contentType'] == contentType)
        .toList();
  }

  // ===== PRIVATE HELPERS =====

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String error) {
    _error = error;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  @override
  void dispose() {
    // Cleanup if needed
    super.dispose();
  }
}
