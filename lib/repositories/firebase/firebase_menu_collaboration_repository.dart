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
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase implementation of MenuCollaborationRepository.
/// Handles shared menu CRUD, collaboration setup, and real-time listeners.
class FirebaseMenuCollaborationRepository
    extends BaseFirebaseRepository<SharedMenu>
    implements MenuCollaborationRepository {
  // Real-time listeners for collaboration
  final Map<String, StreamSubscription> _menuListeners = {};

  FirebaseMenuCollaborationRepository({
    super.firestore,
    AuthRepository? authRepository,
    super.auditRepository,
    super.timestampProvider,
  }) : super(authRepository: authRepository ?? FirebaseAuthRepository());
  @override
  String get collectionName => FirestoreCollections.sharedContent;

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
    String userId,
    SharedMenu entity,
  ) async {
    // Users can only create shared menus as themselves (must be the owner)
    return entity.sharedByUserId == userId;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    SharedMenu? entity,
  ) async {
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
    String userId,
    String resourceId,
    SharedMenu entity,
  ) async {
    // Owner can always update their shared menu
    if (entity.sharedByUserId == userId) return true;

    // Active collaborators can update if collaboration is enabled
    // Note (Issue #014): Simplified permission check - actual membership validation in SharedMenuRepository
    if (entity.allowCollaboration) return true;

    return false;
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
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
          'Cannot enable collaboration: User display name not available',
        );
        return false;
      }

      final collaborationData = {
        'allowCollaboration': true,
        'collaboratorIds': collaboratorIds,
        'collaboratorDisplayNames': collaboratorDisplayNames.orEmpty(),
        'collaborationEnabledAt': timestampProvider.serverTimestamp(),
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
      final allowCollaboration = (menuData['allowCollaboration'] as bool?)
          .orFalse();
      final sharedByUserId = menuData['sharedByUserId'] as String?;
      final sharedToUserIds = List<String>.from(
        (menuData['sharedToUserIds'] as List?).orEmpty(),
      );
      final collaboratorIds = List<String>.from(
        (menuData['collaboratorIds'] as List?).orEmpty(),
      );

      return allowCollaboration &&
          (sharedByUserId == userId ||
              sharedToUserIds.contains(userId) ||
              collaboratorIds.contains(userId));
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to check collaboration permission: $e',
        stackTrace,
      );
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
        'lastUpdatedAt': timestampProvider.serverTimestamp(),
        'lastUpdatedBy': userId,
        'lastUpdatedByDisplayName': userDisplayName,
      });

      AppLogger.success('Added recipe "${recipe.id}" to collaborative menu');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to add recipe to collaborative menu: $e',
        stackTrace,
      );
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
          'Cannot remove recipe: User display name not available',
        );
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
      final menuSnapshot = (menuData['menuSnapshot'] as Map<String, dynamic>?)
          .orEmpty();
      final categoryRecipes = List<Map<String, dynamic>>.from(
        (menuSnapshot[category] as List?).orEmpty(),
      );

      final recipeToRemove = categoryRecipes
          .where((r) => r['id'] == recipeId)
          .firstOrNull;
      if (recipeToRemove == null) {
        AppLogger.warning(
          'Recipe not found in menu, may have been already removed',
        );
        return true;
      }

      // Remove recipe using FieldValue operations
      await collection.doc(menuId).update({
        'menuSnapshot.$category': FieldValue.arrayRemove([recipeToRemove]),
        'lastUpdatedAt': timestampProvider.serverTimestamp(),
        'lastUpdatedBy': userId,
        'lastUpdatedByDisplayName': userDisplayName,
      });

      AppLogger.success('Removed recipe from collaborative menu');
      return true;
    } catch (e, stackTrace) {
      AppLogger.error(
        'Failed to remove recipe from collaborative menu: $e',
        stackTrace,
      );
      return false;
    }
  }

  @override
  void startCollaborationListener(
    String menuId,
    Function(SharedMenu) onUpdate,
  ) {
    if (_menuListeners.containsKey(menuId)) return;

    _menuListeners[menuId] = collection.doc(menuId).snapshots().listen((
      snapshot,
    ) {
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
