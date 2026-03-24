import 'dart:ui';

import 'package:collection/collection.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/events/group_events.dart';
import 'package:butlery/repositories/firebase/firebase_friends_repository.dart';
import 'package:butlery/repositories/firebase/friends/friend_category_repository.dart';
import 'package:butlery/services/unified/operations/friend_categories_operations.dart';
import 'package:butlery/services/unified/operations/modules/invitation_validation_module.dart';
import 'package:butlery/services/unified/operations/modules/invitation_statistics_module.dart';

/// Friends invitations operations for multi-channel invitation management and tracking.
/// Handles friend invitation operations including sending, tracking, and analytics.
class FriendsInvitationsOperations {
  final String? Function() _getCurrentUserId;
  final String? Function() _getCurrentUserDisplayName;
  final List<GroupInvitation> Function() _getAllSentInvitationsInternal;
  final List<GroupInvitation> Function(String)
      _getReceivedGroupInvitationsInternal;
  final GroupInvitation? Function(String) _getSentInvitationByIdInternal;
  final void Function(GroupInvitation) _addSentInvitationInternal;
  final void Function(String, GroupInvitation) _updateSentInvitationInternal;
  final void Function(FriendCategory) _addCategoryInternal;
  final VoidCallback _notifyListeners;
  final FirebaseFriendsRepository _friendsRepository;
  final FriendCategoryRepository _categoryRepository;
  final Future<bool> Function(
      {required String email,
      required GroupInvitation invitation}) _sendEmailInvitationInternal;
  final Future<bool> Function(
      {required String phoneNumber,
      required GroupInvitation invitation}) _sendSMSInvitationInternal;
  final Future<String> Function(String) _createInvitationLinkInternal;
  final Future<void> Function(String, GroupInvitationStatus)
      _updateInvitationStatusInternal;
  final bool Function() _getIsLoading;
  final bool Function() _getHasError;
  final String? Function() _getError;
  final FriendsCategoriesOperations Function() _getCategories;

  // Modules
  late final InvitationValidationModule _validation;
  late final InvitationStatisticsModule _statistics;

  FriendsInvitationsOperations({
    required String? Function() getCurrentUserId,
    required String? Function() getCurrentUserDisplayName,
    required List<GroupInvitation> Function() getAllSentInvitationsInternal,
    required List<GroupInvitation> Function(String)
        getReceivedGroupInvitationsInternal,
    required GroupInvitation? Function(String) getSentInvitationByIdInternal,
    required void Function(GroupInvitation) addSentInvitationInternal,
    required void Function(String, GroupInvitation)
        updateSentInvitationInternal,
    required void Function(FriendCategory) addCategoryInternal,
    required VoidCallback notifyListeners,
    required FirebaseFriendsRepository friendsRepository,
    required FriendCategoryRepository categoryRepository,
    required Future<bool> Function(
            {required String email, required GroupInvitation invitation})
        sendEmailInvitationInternal,
    required Future<bool> Function(
            {required String phoneNumber, required GroupInvitation invitation})
        sendSMSInvitationInternal,
    required Future<String> Function(String) createInvitationLinkInternal,
    required Future<void> Function(String, GroupInvitationStatus)
        updateInvitationStatusInternal,
    required bool Function() getIsLoading,
    required bool Function() getHasError,
    required String? Function() getError,
    required FriendsCategoriesOperations Function() getCategories,
  })  : _getCurrentUserId = getCurrentUserId,
        _getCurrentUserDisplayName = getCurrentUserDisplayName,
        _getAllSentInvitationsInternal = getAllSentInvitationsInternal,
        _getReceivedGroupInvitationsInternal =
            getReceivedGroupInvitationsInternal,
        _getSentInvitationByIdInternal = getSentInvitationByIdInternal,
        _addSentInvitationInternal = addSentInvitationInternal,
        _updateSentInvitationInternal = updateSentInvitationInternal,
        _addCategoryInternal = addCategoryInternal,
        _notifyListeners = notifyListeners,
        _friendsRepository = friendsRepository,
        _categoryRepository = categoryRepository,
        _sendEmailInvitationInternal = sendEmailInvitationInternal,
        _sendSMSInvitationInternal = sendSMSInvitationInternal,
        _createInvitationLinkInternal = createInvitationLinkInternal,
        _updateInvitationStatusInternal = updateInvitationStatusInternal,
        _getIsLoading = getIsLoading,
        _getHasError = getHasError,
        _getError = getError,
        _getCategories = getCategories {
    _validation = InvitationValidationModule();
    _statistics = InvitationStatisticsModule();
  }

  /// Send group invitation to an existing user
  Future<bool> sendGroupInvitationToUser({
    required String userId,
    required String groupId,
    String? customMessage,
  }) async {
    try {
      // Validate inputs
      if (!_validation.validateGroupInvitationInputs(
          userId: userId, groupId: groupId)) {
        AppLogger.error(
            'Cannot send invitation: userId and groupId are required');
        return false;
      }

      // Get current user info
      final currentUserId = _getCurrentUserId();
      if (currentUserId == null) {
        AppLogger.error('Cannot send invitation: User not authenticated');
        return false;
      }

      // Check if already invited
      final existingInvitation = _validation.findDuplicateGroupInvitation(
        invitations: getSentInvitations(),
        userId: userId,
        groupId: groupId,
      );

      if (existingInvitation != null) {
        AppLogger.warning(
            'Invitation already exists for user $userId to group $groupId');
        return false;
      }

      // Get group information
      final group = _getCategories().getCategoryById(groupId);
      if (group == null) {
        AppLogger.error('Cannot send invitation: Group $groupId not found');
        return false;
      }

      // Get sender name
      final currentUserDisplayName = _getCurrentUserDisplayName() ?? 'Unknown';

      // Create proper invitation
      final invitation = GroupInvitation(
        id: '${currentUserId}_${userId}_${groupId}_${DateTime.now().millisecondsSinceEpoch}',
        groupId: groupId,
        groupName: group.name,
        groupEmoji: group.emoji ?? '',
        fromUserId: currentUserId,
        fromUserName: currentUserDisplayName,
        toUserId: userId,
        personalMessage: customMessage,
        sentAt: DateTime.now(),
      );

      await _friendsRepository.saveInvitation(invitation);
      _addSentInvitationInternal(invitation);
      _notifyListeners();

      AppLogger.success(
          'Group invitation sent to user $userId for group "${group.name}"');
      return true;
    } catch (e) {
      AppLogger.error('Failed to send group invitation', e);
      return false;
    }
  }

  /// Send invitation via email
  Future<bool> sendEmailInvitation({
    required String email,
    String? customMessage,
    String? senderName,
  }) async {
    try {
      if (!_validation.isValidEmail(email)) {
        AppLogger.error('Invalid email address');
        return false;
      }

      if (_validation.hasDuplicateInvitationByEmail(
          getSentInvitations(), email)) {
        AppLogger.warning('Invitation already sent to this email');
        return false;
      }

      final currentUserId = _getCurrentUserId();
      final currentUserDisplayName = _getCurrentUserDisplayName();

      if (!_validation.hasUserInformation(
          currentUserId: currentUserId,
          currentUserDisplayName: currentUserDisplayName)) {
        AppLogger.error(
            'Cannot send invitation: User information not available');
        return false;
      }

      final invitation = GroupInvitation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groupId: '',
        groupName: '',
        groupEmoji: '👥',
        fromUserId: currentUserId!,
        fromUserName: senderName ?? currentUserDisplayName!,
        toUserId: email,
        personalMessage: customMessage,
        sentAt: DateTime.now(),
      );

      _addSentInvitationInternal(invitation);
      _notifyListeners();

      final emailSent = await _sendEmailInvitationInternal(
        email: email,
        invitation: invitation,
      );

      if (emailSent) {
        AppLogger.success('Email invitation sent to ${email.maskedEmail}');
        return true;
      } else {
        AppLogger.error(
            'Email invitation failed: Email service not implemented');
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to send email invitation', e);
      return false;
    }
  }

  /// Send invitation via SMS
  Future<bool> sendSMSInvitation({
    required String phoneNumber,
    String? customMessage,
    String? senderName,
  }) async {
    try {
      if (!_validation.isValidPhoneNumber(phoneNumber)) {
        AppLogger.error('Invalid phone number');
        return false;
      }

      if (_validation.hasDuplicateInvitationByPhone(
          getSentInvitations(), phoneNumber)) {
        AppLogger.warning('Invitation already sent to this phone number');
        return false;
      }

      final currentUserId = _getCurrentUserId();
      final currentUserDisplayName = _getCurrentUserDisplayName();

      if (!_validation.hasUserInformation(
          currentUserId: currentUserId,
          currentUserDisplayName: currentUserDisplayName)) {
        AppLogger.error(
            'Cannot send invitation: User information not available');
        return false;
      }

      final invitation = GroupInvitation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groupId: '',
        groupName: '',
        groupEmoji: '👥',
        fromUserId: currentUserId!,
        fromUserName: senderName ?? currentUserDisplayName!,
        toUserId: phoneNumber,
        personalMessage: customMessage,
        sentAt: DateTime.now(),
      );

      _addSentInvitationInternal(invitation);
      _notifyListeners();

      final smsSent = await _sendSMSInvitationInternal(
        phoneNumber: phoneNumber,
        invitation: invitation,
      );

      if (smsSent) {
        AppLogger.success('SMS invitation sent to ${phoneNumber.maskedPhone}');
        return true;
      } else {
        AppLogger.error('SMS invitation failed: SMS service not implemented');
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to send SMS invitation', e);
      return false;
    }
  }

  /// Send invitation via share link
  Future<String?> createInvitationLink({
    String? customMessage,
    DateTime? expiresAt,
  }) async {
    try {
      final currentUserId = _getCurrentUserId();
      final currentUserDisplayName = _getCurrentUserDisplayName();

      if (!_validation.hasUserInformation(
          currentUserId: currentUserId,
          currentUserDisplayName: currentUserDisplayName)) {
        AppLogger.error(
            'Cannot create invitation link: User information not available');
        return null;
      }

      final invitation = GroupInvitation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groupId: '',
        groupName: '',
        groupEmoji: '👥',
        fromUserId: currentUserId!,
        fromUserName: currentUserDisplayName!,
        toUserId: '',
        personalMessage: customMessage,
        sentAt: DateTime.now(),
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      );

      _addSentInvitationInternal(invitation);
      _notifyListeners();

      final link = await _createInvitationLinkInternal(invitation.id);

      AppLogger.success('Invitation link created');
      return link;
    } catch (e) {
      AppLogger.error('Failed to create invitation link', e);
      return null;
    }
  }

  /// Send bulk invitations
  Future<Map<String, bool>> sendBulkInvitations({
    required List<dynamic> contacts,
    String? customMessage,
    String? senderName,
  }) async {
    final results = <String, bool>{};
    for (final contact in contacts) {
      try {
        bool success = false;
        if (contact is Map<String, dynamic>) {
          final email = contact['email'] as String?;
          final phoneNumber = contact['phoneNumber'] as String?;
          if (email != null) {
            success = await sendEmailInvitation(
                email: email,
                customMessage: customMessage,
                senderName: senderName);
            results[email] = success;
          } else if (phoneNumber != null) {
            success = await sendSMSInvitation(
                phoneNumber: phoneNumber,
                customMessage: customMessage,
                senderName: senderName);
            results[phoneNumber] = success;
          }
        }
      } catch (e) {
        AppLogger.error('Failed to send invitation to contact', e);
        results['unknown'] = false;
      }
    }
    return results;
  }

  /// Cancel an invitation
  Future<bool> cancelInvitation(String invitationId) async {
    try {
      final invitation = _getSentInvitationByIdInternal(invitationId);

      if (invitation == null) {
        AppLogger.error('Invitation not found');
        return false;
      }

      if (invitation.status != GroupInvitationStatus.pending) {
        AppLogger.error(
            'Cannot cancel invitation with status: ${invitation.status}');
        return false;
      }

      // Remove from local state (invitation will be deleted from Firebase)
      _updateSentInvitationInternal(
        invitationId,
        invitation.copyWith(
          status: GroupInvitationStatus.cancelled,
          respondedAt: DateTime.now(),
        ),
      );
      _notifyListeners();

      // Delete from Firebase (Firestore rules block sender updates, but allow delete)
      await _updateInvitationStatusInternal(
          invitationId, GroupInvitationStatus.cancelled);

      AppLogger.success('Invitation cancelled');
      return true;
    } catch (e) {
      AppLogger.error('Failed to cancel invitation', e);
      return false;
    }
  }

  /// Resend an invitation
  Future<bool> resendInvitation(String invitationId) async {
    try {
      final invitation = _getSentInvitationByIdInternal(invitationId);

      if (invitation == null) {
        AppLogger.error('Invitation not found');
        return false;
      }

      if (invitation.status == GroupInvitationStatus.accepted) {
        AppLogger.error('Cannot resend accepted invitation');
        return false;
      }

      final resentInvitation = invitation.copyWith(
        status: GroupInvitationStatus.pending,
        respondedAt: null,
      );

      _updateSentInvitationInternal(invitationId, resentInvitation);
      _notifyListeners();

      final emailSent = await _sendEmailInvitationInternal(
        email: invitation.toUserId,
        invitation: resentInvitation,
      );

      if (emailSent) {
        await _updateInvitationStatusInternal(
            resentInvitation.id, resentInvitation.status);
        AppLogger.success('Invitation resent');
        return true;
      } else {
        AppLogger.error('Resend failed: Email service not implemented');
        _updateSentInvitationInternal(invitationId, invitation);
        _notifyListeners();
        return false;
      }
    } catch (e) {
      AppLogger.error('Failed to resend invitation', e);
      return false;
    }
  }

  /// Mark invitation as viewed
  Future<bool> markInvitationAsViewed(String invitationId) async {
    try {
      final invitation = _getSentInvitationByIdInternal(invitationId);
      if (invitation == null) {
        AppLogger.error('Invitation not found');
        return false;
      }

      final viewedInvitation = invitation.copyWith(
        status: GroupInvitationStatus.pending,
        respondedAt: DateTime.now(),
      );

      _updateSentInvitationInternal(invitationId, viewedInvitation);
      _notifyListeners();
      await _updateInvitationStatusInternal(
          viewedInvitation.id, viewedInvitation.status);

      AppLogger.success('Invitation marked as viewed');
      return true;
    } catch (e) {
      AppLogger.error('Failed to mark invitation as viewed', e);
      return false;
    }
  }

  /// Get all sent invitations
  List<GroupInvitation> getSentInvitations() {
    return List.unmodifiable(_getAllSentInvitationsInternal());
  }

  /// Get invitations by status
  List<GroupInvitation> getInvitationsByStatus(GroupInvitationStatus status) {
    return _statistics.getInvitationsByStatus(
        _getAllSentInvitationsInternal(), status);
  }

  /// Get pending invitations
  List<GroupInvitation> getPendingInvitations() {
    return _statistics.getPendingInvitations(_getAllSentInvitationsInternal());
  }

  /// Get expired invitations
  List<GroupInvitation> getExpiredInvitations() {
    return _statistics.getExpiredInvitations(_getAllSentInvitationsInternal());
  }

  /// Check if invitation exists
  bool hasInvitation({String? email, String? phoneNumber}) {
    final invitations = _getAllSentInvitationsInternal();
    if (email != null) {
      return _validation.hasDuplicateInvitationByEmail(invitations, email);
    }
    if (phoneNumber != null) {
      return _validation.hasDuplicateInvitationByPhone(
          invitations, phoneNumber);
    }
    return false;
  }

  /// Get invitation by ID
  GroupInvitation? getInvitationById(String invitationId) {
    // Search sent invitations
    final sentInvitation = _getAllSentInvitationsInternal()
        .firstWhereOrNull((i) => i.id == invitationId);

    if (sentInvitation != null) return sentInvitation;

    // Search received invitations
    final currentUserId = _getCurrentUserId();
    if (currentUserId != null) {
      final receivedInvitation =
          _getReceivedGroupInvitationsInternal(currentUserId)
              .firstWhereOrNull((i) => i.id == invitationId);

      if (receivedInvitation != null) return receivedInvitation;
    }

    return null;
  }

  /// Search invitations
  List<GroupInvitation> searchInvitations(String query) {
    return _statistics.searchInvitations(
        _getAllSentInvitationsInternal(), query);
  }

  /// Get invitation statistics
  Map<String, dynamic> getInvitationStats() {
    return _statistics.getInvitationStats(_getAllSentInvitationsInternal());
  }

  /// Get invitation performance metrics
  Map<String, dynamic> getInvitationMetrics() {
    return _statistics.getInvitationMetrics(_getAllSentInvitationsInternal());
  }

  /// Get invitation suggestions from contacts
  Future<List<dynamic>> getInvitationSuggestions() async {
    try {
      // This would integrate with contacts API
      // For now, return empty list
      return [];
    } catch (e) {
      AppLogger.error('Failed to get invitation suggestions', e);
      return [];
    }
  }

  /// Import contacts for invitations
  Future<List<dynamic>> importContacts() async {
    try {
      // This would integrate with contacts API
      // For now, return empty list
      return [];
    } catch (e) {
      AppLogger.error('Failed to import contacts', e);
      return [];
    }
  }

  List<GroupInvitation> get pendingReceivedInvitations {
    try {
      final currentUserId = _getCurrentUserId();
      if (currentUserId == null) {
        AppLogger.warning('Cannot get received invitations: No current user');
        return [];
      }
      return _getReceivedGroupInvitationsInternal(currentUserId);
    } catch (e) {
      AppLogger.error('Error getting pending received invitations', e);
      return [];
    }
  }

  bool get isLoading => _getIsLoading();
  bool get hasError => _getHasError();
  String? get error => _getError();
  Future<void> refresh() async {}

  Future<bool> acceptGroupInvitation(String invitationId) async {
    try {
      final invitation = getInvitationById(invitationId);
      if (invitation == null) {
        AppLogger.error('Invitation not found: $invitationId');
        return false;
      }

      var existingGroup = _getCategories().getCategoryById(invitation.groupId);

      if (existingGroup == null) {
        try {
          final fetchedGroup = await _categoryRepository.getCategory(
            invitation.fromUserId,
            invitation.groupId,
          );

          if (fetchedGroup != null) {
            _addCategoryInternal(fetchedGroup);
            existingGroup = fetchedGroup;
          } else {
            AppLogger.error('Group not found in Firestore');
            return false;
          }
        } catch (e) {
          AppLogger.error('Failed to fetch group from Firestore', e);
          return false;
        }
      }

      final addedToGroup = await _getCategories().addFriendToCategory(
        invitation.toUserId,
        invitation.groupId,
        skipFriendshipCheck: true,
        skipPermissionCheck: true,
      );

      if (!addedToGroup) {
        AppLogger.error(
            'Failed to add user to group after accepting invitation');
        return false;
      }

      final acceptedInvitation = invitation.accept();

      _updateSentInvitationInternal(invitationId, acceptedInvitation);
      _notifyListeners();
      await _updateInvitationStatusInternal(
          acceptedInvitation.id, acceptedInvitation.status);

      GroupEventBus.memberAdded();
      AppLogger.success('Group invitation accepted successfully');

      return true;
    } catch (e) {
      AppLogger.error('Failed to accept invitation', e);
      return false;
    }
  }

  Future<bool> rejectGroupInvitation(String invitationId) async {
    try {
      final invitation = getInvitationById(invitationId);
      if (invitation == null) return false;

      final rejectedInvitation = invitation.reject();

      _updateSentInvitationInternal(invitationId, rejectedInvitation);
      _notifyListeners();
      await _updateInvitationStatusInternal(
          rejectedInvitation.id, rejectedInvitation.status);

      return true;
    } catch (e) {
      AppLogger.error('Failed to reject invitation', e);
      return false;
    }
  }
}
