// lib/services/unified/operations/collaborative_menu_operations.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/repositories/interfaces/menu_collaboration_repository.dart';

/// Comprehensive collaborative menu operations providing real-time menu sharing and social cooking collaboration features.
/// This operations class implements sophisticated collaborative menu functionality following Single Responsibility Principle,
/// handling all aspects of multi-user menu collaboration including real-time editing, rating systems, commenting,
/// and template management. It provides comprehensive collaborative cooking features while maintaining clean separation
/// from basic menu operations and individual recipe management concerns.
/// **Single Responsibility Focus:**
/// This class exclusively handles collaborative menu operations:
/// - **Real-time Collaboration**: Live menu editing with multiple users and conflict resolution
/// - **Social Rating System**: Comprehensive menu rating and review system with statistical tracking
/// - **Comment System**: Threaded menu discussions with likes and real-time streaming capabilities
/// - **Template Management**: Collaborative menu templates with sharing and reuse functionality
/// **What This Class Does NOT Handle:**
/// - Basic menu CRUD operations (handled by parent service)
/// - Individual recipe management (handled by recipe operations)
/// - User authentication and permissions (handled by permission services)
/// - Non-collaborative menu features (handled by basic menu operations)
/// **Collaborative Menu Features:**
/// - **Real-time Editing**: Multi-user menu collaboration with live updates and activity logging
/// - **Rating System**: Comprehensive 5-star rating system with comments and average rating calculations
/// - **Discussion System**: Threaded comments with likes, replies, and real-time streaming
/// - **Template System**: Menu template creation, sharing, and reuse with usage tracking
/// - **Activity Logging**: Complete collaboration activity tracking with detailed audit trails
/// **Usage Examples:**
/// ```dart
/// final collaborativeOps = CollaborativeMenuOperations(parentService, firestore);
/// // Enable collaborative menu editing
/// await collaborativeOps.enableMenuCollaboration(
///   menuId: menuId,
///   collaboratorIds: ['user1', 'user2'],
///   collaboratorDisplayNames: {'user1': 'Anna', 'user2': 'Erik'},
/// );
/// // Collaborative recipe management
/// await collaborativeOps.addRecipeToCollaborativeMenu(
///   menuId: menuId,
///   category: 'Huvudrätt',
///   recipe: recipe,
///   suggestion: 'Perfekt för söndagsmiddag!',
/// );
/// // Social interaction features
/// await collaborativeOps.rateMenu(menuId: menuId, rating: 5.0, comment: 'Fantastisk meny!');
/// await collaborativeOps.addMenuComment(menuId: menuId, comment: 'Vilken kreativ kombination!');
/// // Template system
/// final templateId = await collaborativeOps.createMenuTemplate(
///   templateName: 'Veckomeny Familj',
///   menuSnapshot: menuData,
///   description: 'Perfekt för familjer med barn',
/// );
/// ```
class CollaborativeMenuOperations {
  final MenuCollaborationRepository _repository;
  final UnifiedMenuService _parent;

  // Local caches for UI performance
  final Map<String, List<Map<String, dynamic>>> _menuComments = {};
  final Map<String, Map<String, double>> _menuRatings =
      {}; // menuId -> userId -> rating
  final Map<String, Set<String>> _menuTemplates =
      {}; // userId -> template menu IDs

  CollaborativeMenuOperations(this._parent, this._repository);

  /// Enable real-time collaboration for a menu
  Future<bool> enableMenuCollaboration({
    required String menuId,
    required List<String> collaboratorIds,
    Map<String, String>? collaboratorDisplayNames,
  }) async {
    final result = await _repository.enableCollaboration(
      menuId: menuId,
      collaboratorIds: collaboratorIds,
      collaboratorDisplayNames: collaboratorDisplayNames,
    );

    if (result) {
      // Start real-time listener for collaborative menu
      _startMenuCollaborationListener(menuId);
    }

    return result;
  }

  /// Add recipe to collaborative menu
  Future<bool> addRecipeToCollaborativeMenu({
    required String menuId,
    required String category,
    required Recipe recipe,
    String? suggestedBy,
    String? suggestion,
  }) async {
    return await _repository.addRecipeToMenu(
      menuId: menuId,
      category: category,
      recipe: recipe,
      suggestedBy: suggestedBy,
      suggestion: suggestion,
    );
  }

  /// Remove recipe from collaborative menu
  Future<bool> removeRecipeFromCollaborativeMenu({
    required String menuId,
    required String category,
    required String recipeId,
    String? reason,
  }) async {
    return await _repository.removeRecipeFromMenu(
      menuId: menuId,
      category: category,
      recipeId: recipeId,
      reason: reason,
    );
  }

  /// Rate a menu
  Future<bool> rateMenu({
    required String menuId,
    required double rating, // 1.0 to 5.0
    String? comment,
  }) async {
    final result = await _repository.rateMenu(
      menuId: menuId,
      rating: rating,
      comment: comment,
    );

    if (result) {
      // Update local ratings cache
      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      if (userId != null) {
        _menuRatings.putIfAbsent(menuId, () => {});
        _menuRatings[menuId]![userId] = rating;
      }
    }

    return result;
  }

  /// Get ratings for a menu
  Future<List<Map<String, dynamic>>> getMenuRatings(String menuId) async {
    return await _repository.getMenuRatings(menuId);
  }

  /// Get average rating for a menu
  Future<double> getMenuAverageRating(String menuId) async {
    return await _repository.getMenuAverageRating(menuId);
  }

  /// Add comment to menu
  Future<bool> addMenuComment({
    required String menuId,
    required String comment,
    String? replyToCommentId,
  }) async {
    final result = await _repository.addMenuComment(
      menuId: menuId,
      comment: comment,
      replyToCommentId: replyToCommentId,
    );

    if (result) {
      // Clear local comments cache to force refresh
      _menuComments.remove(menuId);
    }

    return result;
  }

  /// Get comments for a menu
  Stream<List<Map<String, dynamic>>> getMenuCommentsStream(String menuId) {
    return _repository.getMenuCommentsStream(menuId);
  }

  /// Like/unlike a comment
  Future<bool> toggleCommentLike({
    required String menuId,
    required String commentId,
  }) async {
    return await _repository.toggleCommentLike(
      menuId: menuId,
      commentId: commentId,
    );
  }

  /// Create menu template
  Future<String?> createMenuTemplate({
    required String templateName,
    required Map<String, List<Recipe>> menuSnapshot,
    String? description,
    List<String>? tags,
  }) async {
    final templateId = await _repository.createMenuTemplate(
      templateName: templateName,
      menuSnapshot: menuSnapshot,
      description: description,
      tags: tags,
    );

    if (templateId != null) {
      // Update local templates cache
      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      if (userId != null) {
        _menuTemplates.putIfAbsent(userId, () => {});
        _menuTemplates[userId]!.add(templateId);
      }
    }

    return templateId;
  }

  /// Create menu from template
  Future<String?> createMenuFromTemplate({
    required String templateId,
    required String menuTitle,
    List<String>? sharedToUserIds,
    String? shareMessage,
    bool enableCollaboration = false,
  }) async {
    return await _repository.createMenuFromTemplate(
      templateId: templateId,
      menuTitle: menuTitle,
      sharedToUserIds: sharedToUserIds,
      shareMessage: shareMessage,
      enableCollaboration: enableCollaboration,
    );
  }

  /// Start real-time listener for menu collaboration
  void _startMenuCollaborationListener(String menuId) {
    _repository.startCollaborationListener(menuId, (menu) {
      AppLogger.debug('Menu $menuId updated in real-time');
      // Notify parent service of menu updates
      _parent.triggerNotification();
    });
  }

  /// Dispose of resources
  void dispose() {
    // Dispose repository listeners
    _repository.disposeAllListeners();

    // Clear local caches
    _menuComments.clear();
    _menuRatings.clear();
    _menuTemplates.clear();

    AppLogger.info('Disposed collaborative menu operations');
  }
}
