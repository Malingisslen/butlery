/// 🔍 AI INFO BLOCK:
/// Component: Friends Invitations Operations - Feature interface for managing friend invitations
/// File: lib/services/unified/operations/friends_invitations_operations.dart
/// Quick Guide: Handles all friend invitation operations including sending, tracking, and managing
/// Dependencies IN: UnifiedFriendsService, FriendInvitation model, Contact model
/// Dependencies OUT: Used by ViewModels for invitation operations
/// Data flow: ViewModels -> FriendsInvitationsOperations -> UnifiedFriendsService -> Firebase
/// State management: Real-time updates for invitations and responses
/// Purpose: Separate invitation management concerns from unified service
/// Common issues: Contact validation, invitation tracking, duplicate prevention
/// Test coverage: Unit tests for invitation operations and tracking
/// Performance: Optimistic updates with Firebase sync
/// Analytics: Invitation success rates, sharing patterns
/// Code smells: None - follows single responsibility principle
/// Connected to: UnifiedFriendsService, Invitation ViewModels, Contact integration
/// Used in phases: Phase 5 - Service Consolidation

import '../../../models/group_invitation.dart';
import '../../../core/utils/logger.dart';

/// Friends invitations operations feature interface
/// 
/// Handles all operations related to friend invitations:
/// - Sending invitations via various channels
/// - Tracking invitation status and responses
/// - Managing invitation templates and messages
/// - Contact integration and discovery
/// - Invitation analytics and insights
class FriendsInvitationsOperations {
  final dynamic _parent; // UnifiedFriendsService

  FriendsInvitationsOperations(this._parent);

  // ===== INVITATION SENDING =====

  /// Send invitation via email
  Future<bool> sendEmailInvitation({
    required String email,
    String? customMessage,
    String? senderName,
  }) async {
    try {
      if (!_isValidEmail(email)) {
        AppLogger.error('Invalid email address');
        return false;
      }

      // Check if already invited
      if (hasInvitation(email: email)) {
        AppLogger.warning('Invitation already sent to this email');
        return false;
      }

      final currentUserId = _parent.currentUserId;
      final currentUserDisplayName = _parent.currentUserDisplayName;
      
      if (currentUserId == null || currentUserDisplayName == null) {
        AppLogger.error('Cannot send invitation: User information not available');
        return false;
      }
      
      final invitation = GroupInvitation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groupId: '', // Will be set when used for group invitations
        groupName: '', // Will be set when used for group invitations
        groupEmoji: '👥', // Default emoji
        fromUserId: currentUserId,
        fromUserName: senderName ?? currentUserDisplayName,
        toUserId: email, // Using email as user ID for now
        personalMessage: customMessage,
        sentAt: DateTime.now(),
      );

      // Add to local state
      _parent._addSentInvitation(invitation);
      _parent._notifyListeners();

      // Send invitation via email service
      final emailSent = await _parent._sendEmailInvitation(invitation);

      if (emailSent) {
        AppLogger.success('Email invitation sent to $email');
        return true;
      } else {
        AppLogger.error('Email invitation failed: Email service not implemented');
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
      if (!_isValidPhoneNumber(phoneNumber)) {
        AppLogger.error('Invalid phone number');
        return false;
      }

      // Check if already invited
      if (hasInvitation(phoneNumber: phoneNumber)) {
        AppLogger.warning('Invitation already sent to this phone number');
        return false;
      }

      final currentUserId = _parent.currentUserId;
      final currentUserDisplayName = _parent.currentUserDisplayName;
      
      if (currentUserId == null || currentUserDisplayName == null) {
        AppLogger.error('Cannot send invitation: User information not available');
        return false;
      }
      
      final invitation = GroupInvitation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groupId: '', // Will be set when used for group invitations
        groupName: '', // Will be set when used for group invitations
        groupEmoji: '👥', // Default emoji
        fromUserId: currentUserId,
        fromUserName: senderName ?? currentUserDisplayName,
        toUserId: phoneNumber, // Using phone number as user ID for now
        personalMessage: customMessage,
        sentAt: DateTime.now(),
      );

      // Add to local state
      _parent._addSentInvitation(invitation);
      _parent._notifyListeners();

      // Send invitation via SMS service
      final smsSent = await _parent._sendSMSInvitation(invitation);

      if (smsSent) {
        AppLogger.success('SMS invitation sent to $phoneNumber');
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
      final currentUserId = _parent.currentUserId;
      final currentUserDisplayName = _parent.currentUserDisplayName;
      
      if (currentUserId == null || currentUserDisplayName == null) {
        AppLogger.error('Cannot create invitation link: User information not available');
        return null;
      }
      
      final invitation = GroupInvitation(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        groupId: '', // Will be set when used for group invitations
        groupName: '', // Will be set when used for group invitations
        groupEmoji: '👥', // Default emoji
        fromUserId: currentUserId,
        fromUserName: currentUserDisplayName,
        toUserId: '', // Will be set when link is used
        personalMessage: customMessage,
        sentAt: DateTime.now(),
        expiresAt: expiresAt ?? DateTime.now().add(const Duration(days: 7)),
      );

      // Add to local state
      _parent._addSentInvitation(invitation);
      _parent._notifyListeners();

      // Create invitation link
      final link = await _parent._createInvitationLink(invitation);

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
              senderName: senderName,
            );
            results[email] = success;
          } else if (phoneNumber != null) {
            success = await sendSMSInvitation(
              phoneNumber: phoneNumber,
              customMessage: customMessage,
              senderName: senderName,
            );
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

  // ===== INVITATION MANAGEMENT =====

  /// Cancel an invitation
  Future<bool> cancelInvitation(String invitationId) async {
    try {
      final invitation = _parent._getSentInvitationById(invitationId);

      if (invitation == null) {
        AppLogger.error('Invitation not found');
        return false;
      }

      if (invitation.status != GroupInvitationStatus.pending) {
        AppLogger.error('Cannot cancel invitation with status: ${invitation.status}');
        return false;
      }

      // Update invitation status
      final cancelledInvitation = invitation.copyWith(
        status: GroupInvitationStatus.cancelled,
        respondedAt: DateTime.now(),
      );

      // Update local state
      _parent._updateSentInvitation(invitationId, cancelledInvitation);
      _parent._notifyListeners();

      // Update in Firebase
      await _parent._updateInvitationStatus(cancelledInvitation);

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
      final invitation = _parent._getSentInvitationById(invitationId);

      if (invitation == null) {
        AppLogger.error('Invitation not found');
        return false;
      }

      if (invitation.status == GroupInvitationStatus.accepted) {
        AppLogger.error('Cannot resend accepted invitation');
        return false;
      }

      // Update invitation with new sent time
      final resentInvitation = invitation.copyWith(
        status: GroupInvitationStatus.pending,
        respondedAt: null,
      );

      // Update local state
      _parent._updateSentInvitation(invitationId, resentInvitation);
      _parent._notifyListeners();

      // Resend invitation (implementation depends on invitation type)
      final emailSent = await _parent._sendEmailInvitation(resentInvitation);
      
      if (emailSent) {
        // Update in Firebase only if email was actually sent
        await _parent._updateInvitationStatus(resentInvitation);
        AppLogger.success('Invitation resent');
        return true;
      } else {
        AppLogger.error('Resend failed: Email service not implemented');
        // Revert the local state since the resend failed
        final originalInvitation = invitation;
        _parent._updateSentInvitation(invitationId, originalInvitation);
        _parent._notifyListeners();
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
      final invitation = _parent._getSentInvitationById(invitationId);

      if (invitation == null) {
        AppLogger.error('Invitation not found');
        return false;
      }

      final viewedInvitation = invitation.copyWith(
        status: GroupInvitationStatus.pending,
        respondedAt: DateTime.now(),
      );

      // Update local state
      _parent._updateSentInvitation(invitationId, viewedInvitation);
      _parent._notifyListeners();

      // Update in Firebase
      await _parent._updateInvitationStatus(viewedInvitation);

      AppLogger.success('Invitation marked as viewed');
      return true;
    } catch (e) {
      AppLogger.error('Failed to mark invitation as viewed', e);
      return false;
    }
  }

  // ===== INVITATION QUERIES =====

  /// Get all sent invitations
  List<GroupInvitation> getSentInvitations() {
    return List.unmodifiable(_parent._getAllSentInvitations());
  }

  /// Get invitations by status
  List<GroupInvitation> getInvitationsByStatus(GroupInvitationStatus status) {
    return _parent._getAllSentInvitations()
        .where((i) => i.status == status)
        .toList();
  }

  /// Get pending invitations
  List<GroupInvitation> getPendingInvitations() {
    return _parent._getAllSentInvitations()
        .where((i) => i.status == GroupInvitationStatus.pending)
        .toList();
  }

  /// Get expired invitations
  List<GroupInvitation> getExpiredInvitations() {
    final now = DateTime.now();
    return _parent._getAllSentInvitations()
        .where((i) => i.expiresAt.isBefore(now))
        .toList();
  }

  /// Check if invitation exists
  bool hasInvitation({String? email, String? phoneNumber}) {
    return _parent._getAllSentInvitations().any((i) => 
        (email != null && i.toUserId == email) ||
        (phoneNumber != null && i.toUserId == phoneNumber)
    );
  }

  /// Get invitation by ID
  GroupInvitation? getInvitationById(String invitationId) {
    return _parent._getAllSentInvitations()
        .where((i) => i.id == invitationId)
        .firstOrNull;
  }

  /// Search invitations
  List<GroupInvitation> searchInvitations(String query) {
    final searchTerm = query.toLowerCase();
    return _parent._getAllSentInvitations()
        .where((i) => 
            (i.toUserId.toLowerCase().contains(searchTerm)) ||
            (i.fromUserName.toLowerCase().contains(searchTerm)) ||
            (i.groupName.toLowerCase().contains(searchTerm))
        )
        .toList();
  }

  // ===== INVITATION STATISTICS =====

  /// Get invitation statistics
  Map<String, dynamic> getInvitationStats() {
    final total = _parent._getAllSentInvitations().length;
    final pending = _parent._getAllSentInvitations().where((i) => i.status == GroupInvitationStatus.pending).length;
    final accepted = _parent._getAllSentInvitations().where((i) => i.status == GroupInvitationStatus.accepted).length;
    final rejected = _parent._getAllSentInvitations().where((i) => i.status == GroupInvitationStatus.rejected).length;
    final cancelled = _parent._getAllSentInvitations().where((i) => i.status == GroupInvitationStatus.cancelled).length;
    final expired = getExpiredInvitations().length;

    return {
      'total': total,
      'pending': pending,
      'accepted': accepted,
      'rejected': rejected,
      'cancelled': cancelled,
      'expired': expired,
      'acceptanceRate': total > 0 ? (accepted / total * 100).round() : 0,
    };
  }

  /// Get invitation performance metrics
  Map<String, dynamic> getInvitationMetrics() {
    final stats = getInvitationStats();
    final recentInvitations = _parent._getAllSentInvitations()
        .where((i) => i.sentAt.isAfter(DateTime.now().subtract(const Duration(days: 30))))
        .length;

    return {
      ...stats,
      'recentInvitations': recentInvitations,
      'averageResponseTime': _calculateAverageResponseTime(),
    };
  }

  // ===== CONTACT INTEGRATION =====

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

  // ===== PRIVATE HELPER METHODS =====

  bool _isValidEmail(String email) {
    return RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email);
  }

  bool _isValidPhoneNumber(String phoneNumber) {
    return RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(phoneNumber);
  }

  double _calculateAverageResponseTime() {
    final respondedInvitations = _parent._getAllSentInvitations()
        .where((i) => i.status == GroupInvitationStatus.accepted || i.status == GroupInvitationStatus.rejected)
        .where((i) => i.respondedAt != null)
        .toList();

    if (respondedInvitations.isEmpty) return 0;

    final totalHours = respondedInvitations
        .map((i) => i.respondedAt!.difference(i.sentAt).inHours)
        .fold(0, (sum, hours) => sum + hours);

    return totalHours / respondedInvitations.length;
  }

  // Methods expected by ViewModels
  List<GroupInvitation> get pendingReceivedInvitations => getPendingInvitations();
  bool get isLoading => _parent.isLoading;
  bool get hasError => _parent.hasError;
  String? get error => _parent.error;
  
  Future<void> refresh() async {
    // Refresh invitations from parent service
    // This would typically trigger a Firebase sync
  }
  
  Future<bool> acceptGroupInvitation(String invitationId) async {
    try {
      final invitation = getInvitationById(invitationId);
      if (invitation == null) return false;
      
      final acceptedInvitation = invitation.accept();
      
      // Update local state
      _parent._updateSentInvitation(invitationId, acceptedInvitation);
      _parent._notifyListeners();
      
      // Update in Firebase
      await _parent._updateInvitationStatus(acceptedInvitation);
      
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
      
      // Update local state
      _parent._updateSentInvitation(invitationId, rejectedInvitation);
      _parent._notifyListeners();
      
      // Update in Firebase
      await _parent._updateInvitationStatus(rejectedInvitation);
      
      return true;
    } catch (e) {
      AppLogger.error('Failed to reject invitation', e);
      return false;
    }
  }
}