import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/repositories/interfaces/menu_collaboration_repository.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Firebase implementation of MenuCollaborationRepository.
/// This repository provides comprehensive menu collaboration functionality using
/// Firestore as the backend, abstracting all Firebase-specific operations including
/// FieldValue operations, real-time streams, and complex document updates.
/// **Firebase Collections Used:**
/// - `shared_menus`: Main collaboration menu documents
/// - `menu_ratings/{menuId}/ratings`: Individual menu ratings
/// - `menu_comments/{menuId}/comments`: Menu comment threads
/// - `menu_templates`: Reusable menu templates
/// - `menu_activity/{menuId}/activities`: Collaboration activity logs
/// **FieldValue Operations Abstracted:**
/// - `FieldValue.serverTimestamp()`: For consistent server-side timestamps
/// - `FieldValue.arrayUnion()`: For adding recipes to menu categories
/// - `FieldValue.arrayRemove()`: For removing recipes from menu categories
/// - `FieldValue.increment()`: For template usage counters and statistics
/// **Testing Strategy:**
/// - Unit tests mock this repository using production_mocks.dart
/// - Integration tests use Firebase emulator for FieldValue operations
/// - Follows repository pattern for clean testability separation
/// **Real-time Features:**
/// - Collaboration listener management with proper subscription lifecycle
/// - Real-time comment streams for live discussions
/// - Activity logging for comprehensive audit trails
class FirebaseMenuCollaborationRepository
    extends BaseFirebaseRepository<SharedMenu>
    implements MenuCollaborationRepository {
  // Real-time listeners for collaboration
  final Map<String, StreamSubscription> _menuListeners = {};

  FirebaseMenuCollaborationRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.auditRepository,
  }) : super(authRepository: authRepository ?? FirebaseAuthRepository());
  @override
  String get collectionName => 'shared_menus';

  @override
  SharedMenu fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return SharedMenu.fromFirestore(doc.data()!, doc.id);
  }

  @override
  Map<String, dynamic> toFirestore(SharedMenu menu) {
    return menu.toFirestore();
  }

  @override
  String getId(SharedMenu menu) => menu.id;
  @override
  Future<bool> validateCreatePermission(
      String userId, SharedMenu entity) async {
    // Users can only create shared menus as themselves (must be the owner)
    return entity.sharedByUserId == userId;
  }

  @override
  Future<bool> validateReadPermission(
      String userId, String resourceId, SharedMenu? entity) async {
    if (entity == null) return false;

    // Owner can always read their shared menu
    if (entity.sharedByUserId == userId) return true;

    // If collaboration is allowed, grant read access
    // Note (Issue #014): Actual membership validation happens in SharedMenuRepository
    if (entity.allowCollaboration) return true;

    return false;
  }

  @override
  Future<bool> validateUpdatePermission(
      String userId, String resourceId, SharedMenu entity) async {
    // Owner can always update their shared menu
    if (entity.sharedByUserId == userId) return true;

    // Active collaborators can update if collaboration is enabled
    // Note (Issue #014): Simplified permission check - actual membership validation in SharedMenuRepository
    if (entity.allowCollaboration) return true;

    return false;
  }

  @override
  Future<bool> validateDeletePermission(
      String userId, String resourceId) async {
    // Only the owner can delete the shared menu
    try {
      final menu = await read(resourceId);
      if (menu == null) return false;
      return menu.sharedByUserId == userId;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<bool> enableCollaboration({
    required String menuId,
    required List<String> collaboratorIds,
    Map<String, String>? collaboratorDisplayNames,
  }) async {
    try {
      final userId = requireCurrentUserId();
      final userDisplayName = authRepository.currentUser?.displayName;

      if (userDisplayName == null) {
        AppLogger.error(
            'Cannot enable collaboration: User display name not available');
        return false;
      }

      final collaborationData = {
        'allowCollaboration': true,
        'collaboratorIds': collaboratorIds,
        'collaboratorDisplayNames': collaboratorDisplayNames.orEmpty(),
        'collaborationEnabledAt': FieldValue.serverTimestamp(),
        'collaborationEnabledBy': userId,
        'collaborationSettings': {
          'allowRating': true,
          'allowComments': true,
          'allowEditing': true,
          'requireApprovalForChanges': false,
        },
      };

      await collection.doc(menuId).update(collaborationData);

      AppLogger.success('Enabled collaboration for menu $menuId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to enable menu collaboration: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<bool> canCollaborate(String menuId, String userId) async {
    try {
      final menuDoc = await collection.doc(menuId).get();
      if (!menuDoc.exists ||
          !menuDoc.data()!.containsKey('allowCollaboration')) {
        return false;
      }

      final menuData = menuDoc.data()!;
      final allowCollaboration =
          (menuData['allowCollaboration'] as bool?).orFalse();
      final sharedByUserId = menuData['sharedByUserId'] as String?;
      final sharedToUserIds =
          List<String>.from((menuData['sharedToUserIds'] as List?).orEmpty());
      final collaboratorIds =
          List<String>.from((menuData['collaboratorIds'] as List?).orEmpty());

      return allowCollaboration &&
          (sharedByUserId == userId ||
              sharedToUserIds.contains(userId) ||
              collaboratorIds.contains(userId));
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to check collaboration permission: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<bool> addRecipeToMenu({
    required String menuId,
    required String category,
    required Recipe recipe,
    String? suggestedBy,
    String? suggestion,
  }) async {
    try {
      final userId = requireCurrentUserId();
      final userDisplayName = authRepository.currentUser?.displayName;

      if (userDisplayName == null) {
        AppLogger.error('Cannot add recipe: User display name not available');
        return false;
      }

      // Check collaboration permission
      if (!await canCollaborate(menuId, userId)) {
        AppLogger.error('Cannot add recipe: No collaboration permission');
        return false;
      }

      // Update menu snapshot with FieldValue operations
      await collection.doc(menuId).update({
        'menuSnapshot.$category': FieldValue.arrayUnion([recipe.toFirestore()]),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': userId,
        'lastUpdatedByDisplayName': userDisplayName,
      });

      // Log the collaboration activity
      await logMenuActivity(
        menuId: menuId,
        activity: {
          'operation': 'add_recipe',
          'category': category,
          'recipe': recipe.toFirestore(),
          'addedBy': userId,
          'addedByDisplayName': userDisplayName,
          'addedAt': FieldValue.serverTimestamp(),
          'suggestedBy': suggestedBy,
          'suggestion': suggestion,
          'status': 'approved',
        },
        userId: userId,
        userDisplayName: userDisplayName,
      );

      AppLogger.success('Added recipe "${recipe.title}" to collaborative menu');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to add recipe to collaborative menu: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<bool> removeRecipeFromMenu({
    required String menuId,
    required String category,
    required String recipeId,
    String? reason,
  }) async {
    try {
      final userId = requireCurrentUserId();
      final userDisplayName = authRepository.currentUser?.displayName;

      if (userDisplayName == null) {
        AppLogger.error(
            'Cannot remove recipe: User display name not available');
        return false;
      }

      // Check collaboration permission
      if (!await canCollaborate(menuId, userId)) {
        AppLogger.error('Cannot remove recipe: No collaboration permission');
        return false;
      }

      // Get current menu to find the recipe
      final menuDoc = await collection.doc(menuId).get();
      if (!menuDoc.exists) {
        AppLogger.error('Menu not found');
        return false;
      }

      final menuData = menuDoc.data()!;
      final menuSnapshot =
          (menuData['menuSnapshot'] as Map<String, dynamic>?).orEmpty();
      final categoryRecipes = List<Map<String, dynamic>>.from(
          (menuSnapshot[category] as List?).orEmpty());

      final recipeToRemove =
          categoryRecipes.where((r) => r['id'] == recipeId).firstOrNull;
      if (recipeToRemove == null) {
        AppLogger.warning(
            'Recipe not found in menu, may have been already removed');
        return true;
      }

      // Remove recipe using FieldValue operations
      await collection.doc(menuId).update({
        'menuSnapshot.$category': FieldValue.arrayRemove([recipeToRemove]),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
        'lastUpdatedBy': userId,
        'lastUpdatedByDisplayName': userDisplayName,
      });

      // Log the collaboration activity
      await logMenuActivity(
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
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to remove recipe from collaborative menu: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<bool> rateMenu({
    required String menuId,
    required double rating,
    String? comment,
  }) async {
    try {
      final userId = requireCurrentUserId();
      final userDisplayName = authRepository.currentUser?.displayName;

      if (userDisplayName == null) {
        AppLogger.error('Cannot rate menu: User display name not available');
        return false;
      }

      if (rating < 1.0 || rating > 5.0) {
        AppLogger.error('Invalid rating: must be between 1.0 and 5.0');
        return false;
      }

      final ratingData = {
        'rating': rating,
        'comment': comment,
        'ratedBy': userId,
        'ratedByDisplayName': userDisplayName,
        'ratedAt': FieldValue.serverTimestamp(),
      };

      await firestore
          .collection('menu_ratings')
          .doc(menuId)
          .collection('ratings')
          .doc(userId)
          .set(ratingData);

      // Update menu's cached average rating
      await updateMenuRatingStatistics(menuId);

      AppLogger.success('Rated menu: $rating stars');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to rate menu: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getMenuRatings(String menuId) async {
    try {
      final ratingsSnapshot = await firestore
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
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get menu ratings: $e', stackTrace);
      return [];
    }
  }

  @override
  Future<double> getMenuAverageRating(String menuId) async {
    try {
      final ratings = await getMenuRatings(menuId);
      if (ratings.isEmpty) return 0.0;

      final totalRating = ratings.fold<double>(
          0.0, (total, rating) => total + (rating['rating'] as double));
      return totalRating / ratings.length;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get menu average rating: $e', stackTrace);
      return 0.0;
    }
  }

  @override
  Future<void> updateMenuRatingStatistics(String menuId) async {
    try {
      final averageRating = await getMenuAverageRating(menuId);
      final ratingsCount = (await getMenuRatings(menuId)).length;

      await collection.doc(menuId).update({
        'averageRating': averageRating,
        'ratingsCount': ratingsCount,
      });
    } catch (e, stackTrace) {
      AppLogger.error(
          'Failed to update menu rating statistics: $e', stackTrace);
    }
  }

  @override
  Future<bool> addMenuComment({
    required String menuId,
    required String comment,
    String? replyToCommentId,
  }) async {
    try {
      final userId = requireCurrentUserId();
      final userDisplayName = authRepository.currentUser?.displayName;

      if (userDisplayName == null) {
        AppLogger.error('Cannot add comment: User display name not available');
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

      await firestore
          .collection('menu_comments')
          .doc(menuId)
          .collection('comments')
          .add(commentData);

      AppLogger.success('Added comment to menu');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to add menu comment: $e', stackTrace);
      return false;
    }
  }

  @override
  Stream<List<Map<String, dynamic>>> getMenuCommentsStream(String menuId) {
    return firestore
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

  @override
  Future<bool> deleteMenuComment({
    required String menuId,
    required String commentId,
  }) async {
    try {
      final userId = requireCurrentUserId();

      final commentRef = firestore
          .collection('menu_comments')
          .doc(menuId)
          .collection('comments')
          .doc(commentId);

      final commentDoc = await commentRef.get();
      if (!commentDoc.exists) return false;

      final commentData = commentDoc.data()!;
      if (commentData['commentedBy'] != userId) {
        AppLogger.warning(
            'Cannot delete comment - not authored by current user');
        return false;
      }

      await commentRef.delete();
      AppLogger.success('Deleted menu comment: $commentId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete menu comment: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<bool> removeMenuRating(String menuId) async {
    try {
      final userId = requireCurrentUserId();

      final ratingRef = firestore
          .collection('menu_ratings')
          .doc(menuId)
          .collection('ratings')
          .doc(userId);

      final ratingDoc = await ratingRef.get();
      if (!ratingDoc.exists) return false;

      await ratingRef.delete();
      await updateMenuRatingStatistics(menuId);

      AppLogger.success('Removed menu rating for menu: $menuId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to remove menu rating: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<bool> toggleCommentLike({
    required String menuId,
    required String commentId,
  }) async {
    try {
      final userId = requireCurrentUserId();

      final commentRef = firestore
          .collection('menu_comments')
          .doc(menuId)
          .collection('comments')
          .doc(commentId);

      final commentDoc = await commentRef.get();
      if (!commentDoc.exists) return false;

      final commentData = commentDoc.data()!;
      final likedBy =
          List<String>.from((commentData['likedBy'] as List?).orEmpty());
      final currentLikes = (commentData['likes'] as int?).orZero();

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
    } catch (e, stackTrace) {
      AppLogger.error('Failed to toggle comment like: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<String?> createMenuTemplate({
    required String templateName,
    required Map<String, List<Recipe>> menuSnapshot,
    String? description,
    List<String>? tags,
  }) async {
    try {
      final userId = requireCurrentUserId();
      final userDisplayName = authRepository.currentUser?.displayName;

      if (userDisplayName == null) {
        AppLogger.error(
            'Cannot create template: User display name not available');
        return null;
      }

      final templateData = {
        'templateName': templateName,
        'description': description,
        'ownerId': userId,
        'ownerDisplayName': userDisplayName,
        'menuSnapshot': menuSnapshot.map((category, recipes) =>
            MapEntry(category, recipes.map((r) => r.toFirestore()).toList())),
        'tags': tags.orEmpty(),
        'isTemplate': true,
        'isPublic': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
        'useCount': 0,
        'totalRecipeCount': menuSnapshot.values
            .fold(0, (total, recipes) => total + recipes.length),
        'categories': menuSnapshot.keys.toList(),
      };

      final docRef =
          await firestore.collection('menu_templates').add(templateData);

      AppLogger.success('Created menu template: $templateName');
      return docRef.id;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create menu template: $e', stackTrace);
      return null;
    }
  }

  @override
  Future<List<Map<String, dynamic>>> getUserMenuTemplates() async {
    try {
      final userId = requireCurrentUserId();

      final snapshot = await firestore
          .collection('menu_templates')
          .where('ownerId', isEqualTo: userId)
          .orderBy('createdAt', descending: true)
          .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'templateName': data['templateName'] ?? '',
          'description': data['description'] ?? '',
          'categories': List<String>.from(data['categories'] ?? []),
          'totalRecipeCount': data['totalRecipeCount'] ?? 0,
          'useCount': data['useCount'] ?? 0,
          'createdAt': data['createdAt'],
        };
      }).toList();
    } catch (e, stackTrace) {
      AppLogger.error('Failed to get user menu templates: $e', stackTrace);
      return [];
    }
  }

  @override
  Future<bool> deleteMenuTemplate(String templateId) async {
    try {
      final userId = requireCurrentUserId();

      // Verify ownership before deletion
      final doc =
          await firestore.collection('menu_templates').doc(templateId).get();
      if (!doc.exists) return false;

      final data = doc.data();
      if (data?['ownerId'] != userId) {
        AppLogger.warning('Cannot delete template - not owned by current user');
        return false;
      }

      await firestore.collection('menu_templates').doc(templateId).delete();
      AppLogger.success('Deleted menu template: $templateId');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to delete menu template: $e', stackTrace);
      return false;
    }
  }

  @override
  Future<String?> createMenuFromTemplate({
    required String templateId,
    required String menuTitle,
    List<String>? sharedToUserIds,
    String? shareMessage,
    bool enableCollaboration = false,
  }) async {
    try {
      final userId = requireCurrentUserId();
      final userDisplayName = authRepository.currentUser?.displayName;

      if (userDisplayName == null) {
        AppLogger.error(
            'Cannot create menu from template: User display name not available');
        return null;
      }

      // Get template
      final templateDoc =
          await firestore.collection('menu_templates').doc(templateId).get();

      if (!templateDoc.exists) {
        AppLogger.error('Template not found');
        return null;
      }

      final templateData = templateDoc.data()!;
      final menuSnapshot =
          ((templateData['menuSnapshot'] as Map<String, dynamic>?)?.map(
        (category, recipes) => MapEntry(
          category,
          (recipes as List<dynamic>)
              .map((r) => Recipe.fromMap('', r as Map<String, dynamic>))
              .toList(),
        ),
      )).orEmpty();

      // Create shared menu
      final sharedMenu = SharedMenu.create(
        sharedByUserId: userId,
        sharedByDisplayName: userDisplayName,
        sharedToUserIds: sharedToUserIds.orEmpty(),
        shareMessage: shareMessage,
        menuTitle: menuTitle,
        menuSnapshot: menuSnapshot,
        allowCollaboration: enableCollaboration,
      );

      // Save to Firestore
      await collection.doc(sharedMenu.id).set(toFirestore(sharedMenu));

      // Increment template use count using FieldValue
      await firestore
          .collection('menu_templates')
          .doc(templateId)
          .update({'useCount': FieldValue.increment(1)});

      AppLogger.success('Created menu from template: $menuTitle');
      return sharedMenu.id;
    } catch (e, stackTrace) {
      AppLogger.error('Failed to create menu from template: $e', stackTrace);
      return null;
    }
  }

  @override
  Future<void> logMenuActivity({
    required String menuId,
    required Map<String, dynamic> activity,
    required String userId,
    required String userDisplayName,
  }) async {
    try {
      await firestore
          .collection('menu_activity')
          .doc(menuId)
          .collection('activities')
          .add({
        ...activity,
        'menuId': menuId,
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (e, stackTrace) {
      AppLogger.error('Failed to log menu activity: $e', stackTrace);
    }
  }

  @override
  void startCollaborationListener(
      String menuId, Function(SharedMenu) onUpdate) {
    if (_menuListeners.containsKey(menuId)) return;

    _menuListeners[menuId] =
        collection.doc(menuId).snapshots().listen((snapshot) {
      if (snapshot.exists) {
        try {
          final menu = fromFirestore(snapshot);
          onUpdate(menu);
          AppLogger.debug('Menu $menuId updated in real-time');
        } catch (e, stackTrace) {
          AppLogger.error('Failed to process menu update: $e', stackTrace);
        }
      }
    });
  }

  @override
  void stopCollaborationListener(String menuId) {
    final subscription = _menuListeners.remove(menuId);
    subscription?.cancel();
  }

  @override
  void disposeAllListeners() {
    for (final subscription in _menuListeners.values) {
      subscription.cancel();
    }
    _menuListeners.clear();
    AppLogger.info('Disposed all menu collaboration listeners');
  }
}
