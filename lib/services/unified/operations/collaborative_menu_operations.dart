// lib/services/unified/operations/collaborative_menu_operations.dart

import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Comprehensive collaborative menu operations providing real-time menu sharing and social cooking collaboration features.
///
/// This operations class implements sophisticated collaborative menu functionality following Single Responsibility Principle,
/// handling all aspects of multi-user menu collaboration including real-time editing, rating systems, commenting,
/// and template management. It provides comprehensive collaborative cooking features while maintaining clean separation
/// from basic menu operations and individual recipe management concerns.
///
/// **Single Responsibility Focus:**
/// This class exclusively handles collaborative menu operations:
/// - **Real-time Collaboration**: Live menu editing with multiple users and conflict resolution
/// - **Social Rating System**: Comprehensive menu rating and review system with statistical tracking
/// - **Comment System**: Threaded menu discussions with likes and real-time streaming capabilities
/// - **Template Management**: Collaborative menu templates with sharing and reuse functionality
///
/// **What This Class Does NOT Handle:**
/// - Basic menu CRUD operations (handled by parent service)
/// - Individual recipe management (handled by recipe operations)
/// - User authentication and permissions (handled by permission services)
/// - Non-collaborative menu features (handled by basic menu operations)
///
/// **Collaborative Menu Features:**
/// - **Real-time Editing**: Multi-user menu collaboration with live updates and activity logging
/// - **Rating System**: Comprehensive 5-star rating system with comments and average rating calculations
/// - **Discussion System**: Threaded comments with likes, replies, and real-time streaming
/// - **Template System**: Menu template creation, sharing, and reuse with usage tracking
/// - **Activity Logging**: Complete collaboration activity tracking with detailed audit trails
///
/// **Usage Examples:**
/// ```dart
/// final collaborativeOps = CollaborativeMenuOperations(parentService, firestore);
/// 
/// // Enable collaborative menu editing
/// await collaborativeOps.enableMenuCollaboration(
///   menuId: menuId,
///   collaboratorIds: ['user1', 'user2'],
///   collaboratorDisplayNames: {'user1': 'Anna', 'user2': 'Erik'},
/// );
/// 
/// // Collaborative recipe management
/// await collaborativeOps.addRecipeToCollaborativeMenu(
///   menuId: menuId,
///   category: 'Huvudrätt',
///   recipe: recipe,
///   suggestion: 'Perfekt för söndagsmiddag!',
/// );
/// 
/// // Social interaction features
/// await collaborativeOps.rateMenu(menuId: menuId, rating: 5.0, comment: 'Fantastisk meny!');
/// await collaborativeOps.addMenuComment(menuId: menuId, comment: 'Vilken kreativ kombination!');
/// 
/// // Template system
/// final templateId = await collaborativeOps.createMenuTemplate(
///   templateName: 'Veckomeny Familj',
///   menuSnapshot: menuData,
///   description: 'Perfekt för familjer med barn',
/// );
/// ```
class CollaborativeMenuOperations {
  final FirebaseFirestore _firestore;
  final dynamic _parent; // UnifiedMenuService

  // Real-time state for menu collaboration
  final Map<String, StreamSubscription> _menuListeners = {};
  final Map<String, List<Map<String, dynamic>>> _menuComments = {};
  final Map<String, Map<String, double>> _menuRatings = {}; // menuId -> userId -> rating
  final Map<String, Set<String>> _menuTemplates = {}; // userId -> template menu IDs

  CollaborativeMenuOperations(this._parent, this._firestore);

  // ===== REAL-TIME MENU COLLABORATION =====

  /// Enable real-time collaboration for a menu
  Future<bool> enableMenuCollaboration({
    required String menuId,
    required List<String> collaboratorIds,
    Map<String, String>? collaboratorDisplayNames,
  }) async {
    try {
      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      final userDisplayName = ServiceLocator.get<PermissionService>().currentUserDisplayName;
      
      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot enable collaboration: User not authenticated');
        return false;
      }

      // Update menu to enable collaboration
      final collaborationData = {
        'allowCollaboration': true,
        'collaboratorIds': collaboratorIds,
        'collaboratorDisplayNames': collaboratorDisplayNames ?? {},
        'collaborationEnabledAt': FieldValue.serverTimestamp(),
        'collaborationEnabledBy': userId,
        'collaborationSettings': {
          'allowRating': true,
          'allowComments': true,
          'allowEditing': true,
          'requireApprovalForChanges': false,
        },
      };

      await _firestore
          .collection('shared_menus')
          .doc(menuId)
          .update(collaborationData);

      // Start real-time listener for collaborative menu
      _startMenuCollaborationListener(menuId);

      AppLogger.success('Enabled collaboration for menu $menuId');
      return true;
    } catch (e) {
      AppLogger.error('Failed to enable menu collaboration', e);
      return false;
    }
  }

  /// Add recipe to collaborative menu
  Future<bool> addRecipeToCollaborativeMenu({
    required String menuId,
    required String category,
    required Recipe recipe,
    String? suggestedBy,
    String? suggestion,
  }) async {
    try {
      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      final userDisplayName = ServiceLocator.get<PermissionService>().currentUserDisplayName;
      
      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot add recipe: User not authenticated');
        return false;
      }

      // Check if user can collaborate on this menu
      if (!await _canCollaborateOnMenu(menuId, userId)) {
        AppLogger.error('Cannot add recipe: No collaboration permission');
        return false;
      }

      // Add recipe with collaboration metadata
      final recipeAddition = {
        'operation': 'add_recipe',
        'category': category,
        'recipe': recipe.toFirestore(),
        'addedBy': userId,
        'addedByDisplayName': userDisplayName,
        'addedAt': FieldValue.serverTimestamp(),
        'suggestedBy': suggestedBy,
        'suggestion': suggestion,
        'status': 'approved', // Auto-approve for now, can add approval workflow later
      };

      // Update menu snapshot with new recipe
      await _firestore
          .collection('shared_menus')
          .doc(menuId)
          .update({
            'menuSnapshot.$category': FieldValue.arrayUnion([recipe.toFirestore()]),
            'lastUpdatedAt': FieldValue.serverTimestamp(),
            'lastUpdatedBy': userId,
            'lastUpdatedByDisplayName': userDisplayName,
          });

      // Log the collaboration activity
      await _logMenuActivity(
        menuId: menuId,
        activity: recipeAddition,
        userId: userId,
        userDisplayName: userDisplayName,
      );

      AppLogger.success('Added recipe "${recipe.title}" to collaborative menu');
      return true;
    } catch (e) {
      AppLogger.error('Failed to add recipe to collaborative menu', e);
      return false;
    }
  }

  /// Remove recipe from collaborative menu
  Future<bool> removeRecipeFromCollaborativeMenu({
    required String menuId,
    required String category,
    required String recipeId,
    String? reason,
  }) async {
    try {
      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      final userDisplayName = ServiceLocator.get<PermissionService>().currentUserDisplayName;
      
      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot remove recipe: User not authenticated');
        return false;
      }

      // Check if user can collaborate on this menu
      if (!await _canCollaborateOnMenu(menuId, userId)) {
        AppLogger.error('Cannot remove recipe: No collaboration permission');
        return false;
      }

      // Get current menu to find the recipe
      final menuDoc = await _firestore.collection('shared_menus').doc(menuId).get();
      if (!menuDoc.exists) {
        AppLogger.error('Menu not found');
        return false;
      }

      final menuData = menuDoc.data()!;
      final menuSnapshot = menuData['menuSnapshot'] as Map<String, dynamic>? ?? {};
      final categoryRecipes = List<Map<String, dynamic>>.from(menuSnapshot[category] ?? []);
      
      final recipeToRemove = categoryRecipes.where((r) => r['id'] == recipeId).firstOrNull;
      if (recipeToRemove == null) {
        AppLogger.warning('Recipe not found in menu, may have been already removed');
        return true;
      }

      // Remove recipe from menu snapshot
      await _firestore
          .collection('shared_menus')
          .doc(menuId)
          .update({
            'menuSnapshot.$category': FieldValue.arrayRemove([recipeToRemove]),
            'lastUpdatedAt': FieldValue.serverTimestamp(),
            'lastUpdatedBy': userId,
            'lastUpdatedByDisplayName': userDisplayName,
          });

      // Log the collaboration activity
      await _logMenuActivity(
        menuId: menuId,
        activity: {
          'operation': 'remove_recipe',
          'category': category,
          'recipeId': recipeId,
          'recipeName': recipeToRemove['title'],
          'removedBy': userId,
          'removedByDisplayName': userDisplayName,
          'removedAt': FieldValue.serverTimestamp(),
          'reason': reason,
        },
        userId: userId,
        userDisplayName: userDisplayName,
      );

      AppLogger.success('Removed recipe from collaborative menu');
      return true;
    } catch (e) {
      AppLogger.error('Failed to remove recipe from collaborative menu', e);
      return false;
    }
  }

  // ===== MENU RATING SYSTEM =====

  /// Rate a menu
  Future<bool> rateMenu({
    required String menuId,
    required double rating, // 1.0 to 5.0
    String? comment,
  }) async {
    try {
      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      final userDisplayName = ServiceLocator.get<PermissionService>().currentUserDisplayName;
      
      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot rate menu: User not authenticated');
        return false;
      }

      if (rating < 1.0 || rating > 5.0) {
        AppLogger.error('Invalid rating: must be between 1.0 and 5.0');
        return false;
      }

      // Save rating
      final ratingData = {
        'rating': rating,
        'comment': comment,
        'ratedBy': userId,
        'ratedByDisplayName': userDisplayName,
        'ratedAt': FieldValue.serverTimestamp(),
      };

      await _firestore
          .collection('menu_ratings')
          .doc(menuId)
          .collection('ratings')
          .doc(userId)
          .set(ratingData);

      // Update local ratings cache
      _menuRatings.putIfAbsent(menuId, () => {});
      _menuRatings[menuId]![userId] = rating;

      // Update menu's average rating
      await _updateMenuAverageRating(menuId);

      AppLogger.success('Rated menu: $rating stars');
      return true;
    } catch (e) {
      AppLogger.error('Failed to rate menu', e);
      return false;
    }
  }

  /// Get ratings for a menu
  Future<List<Map<String, dynamic>>> getMenuRatings(String menuId) async {
    try {
      final ratingsSnapshot = await _firestore
          .collection('menu_ratings')
          .doc(menuId)
          .collection('ratings')
          .orderBy('ratedAt', descending: true)
          .get();

      return ratingsSnapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'userId': doc.id,
          'rating': data['rating'],
          'comment': data['comment'],
          'ratedBy': data['ratedBy'],
          'ratedByDisplayName': data['ratedByDisplayName'],
          'ratedAt': data['ratedAt'],
        };
      }).toList();
    } catch (e) {
      AppLogger.error('Failed to get menu ratings', e);
      return [];
    }
  }

  /// Get average rating for a menu
  Future<double> getMenuAverageRating(String menuId) async {
    try {
      final ratings = await getMenuRatings(menuId);
      if (ratings.isEmpty) return 0.0;

      final totalRating = ratings.fold<double>(0.0, (total, rating) => total + (rating['rating'] as double));
      return totalRating / ratings.length;
    } catch (e) {
      AppLogger.error('Failed to get menu average rating', e);
      return 0.0;
    }
  }

  // ===== MENU COMMENTING SYSTEM =====

  /// Add comment to menu
  Future<bool> addMenuComment({
    required String menuId,
    required String comment,
    String? replyToCommentId,
  }) async {
    try {
      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      final userDisplayName = ServiceLocator.get<PermissionService>().currentUserDisplayName;
      
      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot add comment: User not authenticated');
        return false;
      }

      final commentData = {
        'comment': comment,
        'commentedBy': userId,
        'commentedByDisplayName': userDisplayName,
        'commentedAt': FieldValue.serverTimestamp(),
        'replyToCommentId': replyToCommentId,
        'likes': 0,
        'likedBy': [],
      };

      final docRef = await _firestore
          .collection('menu_comments')
          .doc(menuId)
          .collection('comments')
          .add(commentData);

      // Update local comments cache
      _menuComments.putIfAbsent(menuId, () => []);
      _menuComments[menuId]!.add({
        'id': docRef.id,
        ...commentData,
      });

      AppLogger.success('Added comment to menu');
      return true;
    } catch (e) {
      AppLogger.error('Failed to add menu comment', e);
      return false;
    }
  }

  /// Get comments for a menu
  Stream<List<Map<String, dynamic>>> getMenuCommentsStream(String menuId) {
    return _firestore
        .collection('menu_comments')
        .doc(menuId)
        .collection('comments')
        .orderBy('commentedAt', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) {
        return {
          'id': doc.id,
          ...doc.data(),
        };
      }).toList();
    });
  }

  /// Like/unlike a comment
  Future<bool> toggleCommentLike({
    required String menuId,
    required String commentId,
  }) async {
    try {
      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      if (userId == null) return false;

      final commentRef = _firestore
          .collection('menu_comments')
          .doc(menuId)
          .collection('comments')
          .doc(commentId);

      final commentDoc = await commentRef.get();
      if (!commentDoc.exists) return false;

      final commentData = commentDoc.data()!;
      final likedBy = List<String>.from(commentData['likedBy'] ?? []);
      final currentLikes = commentData['likes'] as int? ?? 0;

      if (likedBy.contains(userId)) {
        // Unlike
        likedBy.remove(userId);
        await commentRef.update({
          'likes': currentLikes - 1,
          'likedBy': likedBy,
        });
      } else {
        // Like
        likedBy.add(userId);
        await commentRef.update({
          'likes': currentLikes + 1,
          'likedBy': likedBy,
        });
      }

      return true;
    } catch (e) {
      AppLogger.error('Failed to toggle comment like', e);
      return false;
    }
  }

  // ===== MENU TEMPLATES =====

  /// Create menu template
  Future<String?> createMenuTemplate({
    required String templateName,
    required Map<String, List<Recipe>> menuSnapshot,
    String? description,
    List<String>? tags,
  }) async {
    try {
      final userId = ServiceLocator.get<PermissionService>().currentUserId;
      final userDisplayName = ServiceLocator.get<PermissionService>().currentUserDisplayName;
      
      if (userId == null || userDisplayName == null) {
        AppLogger.error('Cannot create template: User not authenticated');
        return null;
      }

      final templateData = {
        'templateName': templateName,
        'description': description,
        'ownerId': userId,
        'ownerDisplayName': userDisplayName,
        'menuSnapshot': menuSnapshot.map((category, recipes) => 
            MapEntry(category, recipes.map((r) => r.toFirestore()).toList())),
        'tags': tags ?? [],
        'isTemplate': true,
        'isPublic': false, // Private by default
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'useCount': 0,
        'totalRecipeCount': menuSnapshot.values.fold(0, (total, recipes) => total + recipes.length),
        'categories': menuSnapshot.keys.toList(),
      };

      final docRef = await _firestore
          .collection('menu_templates')
          .add(templateData);

      // Update local templates
      _menuTemplates.putIfAbsent(userId, () => {});
      _menuTemplates[userId]!.add(docRef.id);

      AppLogger.success('Created menu template: $templateName');
      return docRef.id;
    } catch (e) {
      AppLogger.error('Failed to create menu template', e);
      return null;
    }
  }

  /// Create menu from template
  Future<String?> createMenuFromTemplate({
    required String templateId,
    required String menuTitle,
    List<String>? sharedToUserIds,
    String? shareMessage,
    bool enableCollaboration = false,
  }) async {
    try {
      // Get template
      final templateDoc = await _firestore
          .collection('menu_templates')
          .doc(templateId)
          .get();

      if (!templateDoc.exists) {
        AppLogger.error('Template not found');
        return null;
      }

      final templateData = templateDoc.data()!;
      final menuSnapshot = (templateData['menuSnapshot'] as Map<String, dynamic>?)?.map(
        (category, recipes) => MapEntry(
          category,
          (recipes as List<dynamic>)
              .map((r) => Recipe.fromMap('', r as Map<String, dynamic>))
              .toList(),
        ),
      ) ?? <String, List<Recipe>>{};

      // Create shared menu using existing factory
      final sharedMenu = SharedMenu.create(
        sharedByUserId: ServiceLocator.get<PermissionService>().currentUserId!,
        sharedByDisplayName: ServiceLocator.get<PermissionService>().currentUserDisplayName!,
        sharedToUserIds: sharedToUserIds ?? [],
        shareMessage: shareMessage,
        menuTitle: menuTitle,
        menuSnapshot: menuSnapshot,
        allowCollaboration: enableCollaboration,
      );

      // Save to Firestore
      await _firestore
          .collection('shared_menus')
          .doc(sharedMenu.id)
          .set(sharedMenu.toFirestore());

      // Increment template use count
      await _firestore
          .collection('menu_templates')
          .doc(templateId)
          .update({'useCount': FieldValue.increment(1)});

      AppLogger.success('Created menu from template: $menuTitle');
      return sharedMenu.id;
    } catch (e) {
      AppLogger.error('Failed to create menu from template', e);
      return null;
    }
  }

  // ===== HELPER METHODS =====

  /// Start real-time listener for menu collaboration
  void _startMenuCollaborationListener(String menuId) {
    if (_menuListeners.containsKey(menuId)) return;

    _menuListeners[menuId] = _firestore
        .collection('shared_menus')
        .doc(menuId)
        .snapshots()
        .listen((snapshot) {
      if (snapshot.exists) {
        AppLogger.debug('Menu $menuId updated in real-time');
        // Notify parent service of menu updates
        _parent?.notifyListeners?.call();
      }
    });
  }

  /// Check if user can collaborate on menu
  Future<bool> _canCollaborateOnMenu(String menuId, String userId) async {
    try {
      final menuDoc = await _firestore.collection('shared_menus').doc(menuId).get();
      if (!menuDoc.exists) return false;

      final menuData = menuDoc.data()!;
      final allowCollaboration = menuData['allowCollaboration'] as bool? ?? false;
      final sharedByUserId = menuData['sharedByUserId'] as String?;
      final sharedToUserIds = List<String>.from(menuData['sharedToUserIds'] ?? []);
      final collaboratorIds = List<String>.from(menuData['collaboratorIds'] ?? []);

      return allowCollaboration && 
             (sharedByUserId == userId || 
              sharedToUserIds.contains(userId) || 
              collaboratorIds.contains(userId));
    } catch (e) {
      AppLogger.error('Failed to check collaboration permission', e);
      return false;
    }
  }

  /// Log menu collaboration activity
  Future<void> _logMenuActivity({
    required String menuId,
    required Map<String, dynamic> activity,
    required String userId,
    required String userDisplayName,
  }) async {
    try {
      await _firestore
          .collection('menu_activity')
          .doc(menuId)
          .collection('activities')
          .add({
            ...activity,
            'menuId': menuId,
            'timestamp': FieldValue.serverTimestamp(),
          });
    } catch (e) {
      AppLogger.error('Failed to log menu activity', e);
    }
  }

  /// Update menu's average rating
  Future<void> _updateMenuAverageRating(String menuId) async {
    try {
      final averageRating = await getMenuAverageRating(menuId);
      final ratingsCount = (await getMenuRatings(menuId)).length;

      await _firestore
          .collection('shared_menus')
          .doc(menuId)
          .update({
            'averageRating': averageRating,
            'ratingsCount': ratingsCount,
          });
    } catch (e) {
      AppLogger.error('Failed to update menu average rating', e);
    }
  }

  // ===== CLEANUP =====

  /// Dispose of resources
  void dispose() {
    for (final subscription in _menuListeners.values) {
      subscription.cancel();
    }
    _menuListeners.clear();
    _menuComments.clear();
    _menuRatings.clear();
    _menuTemplates.clear();

    AppLogger.info('Disposed collaborative menu operations');
  }
}