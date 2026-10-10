// lib/services/unified/friends/friends_internal_operations.dart

import 'package:clock/clock.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/friends_repository.dart';
import 'package:butlery/services/unified/friends/friends_state_manager.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';

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
  List<GroupInvitation> getAllSentInvitationsInternal() =>
      _stateManager.sentInvitations;
  void notifyListenersInternal() {
    // Delegate to state manager's notification system
    // This is handled through the state manager's ChangeNotifier
  }

  FriendCategory? getCategoryByIdInternal(String categoryId) {
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

  /// [previous] is the group as this device held it before the change; an
  /// owner's change is then written as that difference (BUT-2326). Without
  /// it the owner's write is a whole-document set, which is only right for a
  /// group being created.
  Future<void> syncCategoryToFirebaseInternal(
    dynamic category, {
    FriendCategory? previous,
  }) async {
    if (category is FriendCategory) {
      try {
        final currentUserId = _authRepository.currentUser?.uid;
        if (currentUserId == null) {
          AppLogger.warning('Cannot sync category: User not authenticated');
          return;
        }

        // Route to correct method based on ownership to prevent privilege escalation
        AppLogger.debug(
          'Syncing category ${category.id} to owner ${category.ownerId.maskedUserId} (current user: ${currentUserId.maskedUserId})',
        );
        if (currentUserId == category.ownerId) {
          await _writeAsOwner(category, previous);
        } else {
          await _writeOwnMembership(category, currentUserId, previous);
        }
        AppLogger.success('✅ Category synced to Firebase: ${category.name}');
      } catch (e) {
        final errorString = e.toString();
        // BUG-016 FIX: Handle web Firestore SDK assertion errors that occur after successful writes
        // The Firestore web SDK can throw "INTERNAL ASSERTION FAILED" during local state sync
        // even when the server write succeeded. Verify by re-fetching the category.
        if (errorString.contains('INTERNAL ASSERTION') ||
            errorString.contains('Unexpected state')) {
          AppLogger.warning(
            '⚠️ Firestore assertion error during sync, verifying write succeeded...',
          );
          try {
            // Verify the category was actually saved by re-fetching
            final savedCategory = await _categoryRepository.getCategory(
              category.ownerId,
              category.id,
            );
            if (savedCategory != null && savedCategory.name == category.name) {
              // Also verify member count matches for member add/remove operations
              final savedMemberCount = savedCategory.friendUserIds.length;
              final expectedMemberCount = category.friendUserIds.length;
              if (savedMemberCount == expectedMemberCount) {
                AppLogger.success(
                  '✅ Verified category was saved despite assertion error: ${category.name} ($savedMemberCount members)',
                );
                return; // Success - don't rethrow
              } else {
                AppLogger.warning(
                  '⚠️ Member count mismatch after save: expected $expectedMemberCount, got $savedMemberCount - retrying save',
                );
                // Retry the save operation (only owner can do full save)
                final retryUserId = _authRepository.currentUser?.uid;
                if (retryUserId == category.ownerId) {
                  await _writeAsOwner(category, previous);
                } else if (retryUserId == null) {
                  throw StateError('Cannot retry sync: not authenticated');
                } else {
                  await _writeOwnMembership(category, retryUserId, previous);
                }
                AppLogger.success(
                  '✅ Retry succeeded: ${category.name} ($expectedMemberCount members)',
                );
                return;
              }
            }
          } catch (verifyError) {
            // A leave that landed takes away the leaver's own read, so the
            // check read is denied.
            final uid = _authRepository.currentUser?.uid;
            final wasOwnLeave =
                uid != null &&
                uid != category.ownerId &&
                !category.friendUserIds.contains(uid);
            if (wasOwnLeave &&
                verifyError.toString().contains('permission-denied')) {
              AppLogger.success(
                '✅ Leave confirmed by the denied check read: ${category.name}',
              );
              return;
            }
            AppLogger.warning('Could not verify save: $verifyError');
          }
        }

        final currentUser = _authRepository.currentUser?.uid;
        AppLogger.error(
          '❌ Failed to sync category to Firebase: ${category.name}',
          e,
        );
        AppLogger.error(
          '   Category owner: ${category.ownerId.maskedUserId}, Current user: $currentUser',
        );
        rethrow;
      }
    } else {
      AppLogger.warning('Invalid category type for Firebase sync');
    }
  }

  Future<void> _writeAsOwner(
    FriendCategory category,
    FriendCategory? previous,
  ) => previous == null
      ? _categoryRepository.saveCategory(category.ownerId, category)
      : _categoryRepository.updateOwnedCategory(
          category.ownerId,
          previous,
          category,
        );

  // A non-owner may only change their own uid in the member list, never
  // overwrite the document; the category they hand in says whether they stay.
  // A change to anyone else's membership is refused here rather than written
  // as the caller's own join.
  Future<void> _writeOwnMembership(
    FriendCategory category,
    String currentUserId,
    FriendCategory? previous,
  ) async {
    if (previous != null) {
      final before = previous.friendUserIds.toSet()..remove(currentUserId);
      final after = category.friendUserIds.toSet()..remove(currentUserId);
      if (before.length != after.length || !before.containsAll(after)) {
        throw PermissionDeniedException(
          'Only the owner can change other members of group ${category.id}',
        );
      }
    }
    if (category.friendUserIds.contains(currentUserId)) {
      await _categoryRepository.addSelfToCategory(
        category.ownerId,
        category.id,
      );
    } else {
      await _categoryRepository.removeSelfFromCategory(
        category.ownerId,
        category.id,
      );
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
      AppLogger.error(
        '❌ Failed to delete category from Firebase: $categoryId',
        e,
      );
      rethrow;
    }
  }

  void addFriendToCategoryInternal(String friendId, String categoryId) {
    final category = _stateManager.getCategoryById(categoryId);
    if (category == null) {
      AppLogger.warning(
        'Cannot add friend to category: Category not found: $categoryId',
      );
      return;
    }

    // Check if friend is already in category
    if (category.friendUserIds.contains(friendId)) {
      AppLogger.debug(
        'Friend already in category: ${friendId.maskedUserId} -> ${category.name}',
      );
      return;
    }

    // Add friend to category's member list
    final updatedCategory = category.copyWith(
      friendUserIds: <String>[
        ...category.friendUserIds.cast<String>(),
        friendId,
      ],
      updatedAt: clock.now(),
    );

    _stateManager.updateCategory(categoryId, updatedCategory);
    AppLogger.success(
      '✅ Added friend ${friendId.maskedUserId} to category ${category.name} (local state)',
    );
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
          .where(
            (invitation) => invitation.status == GroupInvitationStatus.pending,
          )
          .toList();
    } catch (e) {
      AppLogger.error('Error getting received group invitations', e);
      return [];
    }
  }

  // Email/SMS invitations not yet implemented — returns false so callers show
  // "not available yet" instead of pretending the invitation was sent.
  Future<bool> sendEmailInvitationInternal({
    required String email,
    required dynamic invitation,
  }) async => false;
  Future<bool> sendSMSInvitationInternal({
    required String phoneNumber,
    required dynamic invitation,
  }) async => false;
  Future<String> createInvitationLinkInternal(String invitationId) async {
    final userId = ServiceLocator.get<PermissionService>().currentUserId
        .orEmpty();
    final longUrl = DeepLinkService.generateFriendInvitationLink(
      invitationId: invitationId,
      fromUserId: userId,
    );
    return DeepLinkService.generateShortUrl(longUrl);
  }

  Future<void> updateInvitationStatusInternal(
    String invitationId,
    dynamic status,
  ) async {
    if (status is! GroupInvitationStatus) {
      AppLogger.warning(
        'Invalid status type for updateInvitationStatusInternal',
      );
      return;
    }

    try {
      final repo = ServiceLocator.get<FriendsRepository>();

      if (status == GroupInvitationStatus.cancelled) {
        // Sender cancellation: delete the doc (Firestore rules block sender updates)
        await repo.deleteInvitation(invitationId);
        AppLogger.success(
          '✅ Deleted cancelled invitation $invitationId from Firebase',
        );
      } else {
        // Recipient accept/reject: update normally
        await repo.updateInvitation(invitationId, {
          'status': status.toString().split('.').last,
          'respondedAt': clock.now(),
        });
        AppLogger.success(
          '✅ Updated invitation $invitationId status to $status in Firebase',
        );
      }
    } catch (e) {
      AppLogger.error('Failed to update invitation status in Firebase', e);
      rethrow;
    }
  }

  String? getCurrentUserDisplayNameInternal() {
    try {
      // ✅ FIXED: Fetch real user display name from UserService
      return ServiceLocator.get<UserService>()
              .currentUserProfile
              ?.displayName ??
          'Unknown';
    } catch (e) {
      AppLogger.warning('Failed to get current user display name: $e');
      return 'Unknown';
    }
  }
}
