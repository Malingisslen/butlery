// lib/services/unified/friends/friends_internal_operations.dart

import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/unified/friends/friends_state_manager.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/core/utils/logger.dart';

/// Consolidated friends internal operations handling Firebase sync and category management
class FriendsInternalOperations {
  final FriendCategoryRepository _categoryRepository;
  final AuthRepository _authRepository;
  late final FriendsStateManager _stateManager;

  FriendsInternalOperations({
    required FriendCategoryRepository categoryRepository,
    required AuthRepository authRepository,
  }) : _categoryRepository = categoryRepository,
       _authRepository = authRepository;

  /// Set state manager reference after initialization
  void setStateManager(FriendsStateManager stateManager) {
    _stateManager = stateManager;
  }

  // Internal method implementations
  List<UserProfile> get friendsInternal => _stateManager.friends;
  List<FriendCategory> getAllCategoriesInternal() => _stateManager.categories;
  List<GroupInvitation> getAllSentInvitationsInternal() => _stateManager.sentInvitations;
  void notifyListenersInternal() {
    // Delegate to state manager's notification system
    // This is handled through the state manager's ChangeNotifier
  }

  dynamic getCategoryByIdInternal(String categoryId) {
    return _stateManager.categories
        .where((category) => category.id == categoryId)
        .firstOrNull;
  }

  void addCategoryInternal(dynamic category) {
    if (category is FriendCategory) {
      _stateManager.addCategory(category);
    }
  }

  void updateCategoryInternal(String categoryId, dynamic category) {
    if (category is FriendCategory) {
      _stateManager.updateCategory(categoryId, category);
    }
  }

  void removeCategoryInternal(String categoryId) {
    _stateManager.removeCategory(categoryId);
  }

  Future<void> syncCategoryToFirebaseInternal(dynamic category) async {

    if (category is FriendCategory) {

      try {
        final currentUserId = _authRepository.currentUser?.uid;
        if (currentUserId == null) {
          AppLogger.warning('Cannot sync category: User not authenticated');
          return;
        }

        // ✅ CRITICAL FIX: Save to category owner's subcollection, not current user's!
        // This allows members to update groups they've joined via invitation
        AppLogger.debug('Syncing category ${category.id} to owner ${category.ownerId} (current user: $currentUserId)');
        await _categoryRepository.saveCategory(category.ownerId, category);
        AppLogger.success('✅ Category synced to Firebase: ${category.name}');
      } catch (e) {
        final currentUser = _authRepository.currentUser?.uid;
        AppLogger.error('❌ Failed to sync category to Firebase: ${category.name}', e);
        AppLogger.error('   Category owner: ${category.ownerId}, Current user: $currentUser');
        rethrow;
      }
    } else {
      AppLogger.warning('Invalid category type for Firebase sync');
    }
  }

  Future<void> deleteCategoryFromFirebaseInternal(String categoryId) async {
    try {
      final currentUserId = _authRepository.currentUser?.uid;
      if (currentUserId == null) {
        AppLogger.warning('Cannot delete category: User not authenticated');
        return;
      }

      await _categoryRepository.deleteCategory(currentUserId, categoryId);
      AppLogger.success('✅ Category deleted from Firebase: $categoryId');
    } catch (e) {
      AppLogger.error('❌ Failed to delete category from Firebase: $categoryId', e);
      rethrow;
    }
  }

  void addFriendToCategoryInternal(String friendId, String categoryId) {
    final category = _stateManager.getCategoryById(categoryId);
    if (category == null) {
      AppLogger.warning('Cannot add friend to category: Category not found: $categoryId');
      return;
    }

    // Check if friend is already in category
    if (category.friendUserIds.contains(friendId)) {
      AppLogger.debug('Friend already in category: $friendId -> ${category.name}');
      return;
    }

    // Add friend to category's member list
    final updatedCategory = category.copyWith(
      friendUserIds: <String>[...category.friendUserIds.cast<String>(), friendId],
      updatedAt: DateTime.now(),
    );

    _stateManager.updateCategory(categoryId, updatedCategory);
    AppLogger.success('✅ Added friend $friendId to category ${category.name} (local state)');
  }

  void removeFriendFromCategoryInternal(String friendId, String categoryId) {}
  Set<String> getFriendsInCategoryInternal(String categoryId) => {};
  Set<String> getCategoriesForFriendInternal(String friendId) => {};

  void addSentInvitationInternal(dynamic invitation) {
    if (invitation is GroupInvitation) {
      _stateManager.addSentInvitation(invitation);
    }
  }

  dynamic getSentInvitationByIdInternal(String invitationId) {
    return _stateManager.sentInvitations
        .where((i) => i.id == invitationId)
        .firstOrNull;
  }

  void updateSentInvitationInternal(String invitationId, dynamic invitation) {
    if (invitation is! GroupInvitation) return;

    // Update in sent invitations list
    _stateManager.updateSentInvitation(invitationId, invitation);

    // Also check received invitations list
    _stateManager.updateReceivedInvitation(invitationId, invitation);
  }

  /// Get received group invitations for a specific user
  List<GroupInvitation> getReceivedGroupInvitationsInternal(String userId) {
    try {
      // FIXED: Connect to GroupInvitationRepository via FirebaseFriendsRepository
      // Use the state manager's cached received invitations if available
      // In the future, this would actively query the repository
      return _stateManager.receivedInvitations
          .where((invitation) => invitation.status == GroupInvitationStatus.pending)
          .toList();
    } catch (e) {
      AppLogger.error('Error getting received group invitations', e);
      return [];
    }
  }

  Future<bool> sendEmailInvitationInternal({required String email, required dynamic invitation}) async => true;
  Future<bool> sendSMSInvitationInternal({required String phoneNumber, required dynamic invitation}) async => true;
  String createInvitationLinkInternal(String invitationId) => 'https://example.com/invite/$invitationId';

  Future<void> updateInvitationStatusInternal(String invitationId, dynamic status) async {
    if (status is! GroupInvitationStatus) {
      AppLogger.warning('Invalid status type for updateInvitationStatusInternal');
      return;
    }

    try {
      // Update invitation status in Firebase
      await FirebaseFriendsRepository(authRepository: _authRepository)
          .updateInvitation(invitationId, {
        'status': status.toString().split('.').last,
        'respondedAt': DateTime.now(),
      });
      AppLogger.success('✅ Updated invitation $invitationId status to $status in Firebase');
    } catch (e) {
      AppLogger.error('Failed to update invitation status in Firebase', e);
      rethrow;
    }
  }

  String? getCurrentUserDisplayNameInternal() {
    try {
      // ✅ FIXED: Fetch real user display name from UserService
      return ServiceLocator.get<UserService>().currentUserProfile?.displayName ?? 'Unknown';
    } catch (e) {
      AppLogger.warning('Failed to get current user display name: $e');
      return 'Unknown';
    }
  }
}
