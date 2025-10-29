// lib/services/unified/operations/modules/invitation_validation_module.dart

import 'package:butlery/models/group_invitation.dart';
import 'package:collection/collection.dart';

/// Module handling invitation validation logic.
///
/// Provides email/phone validation, duplicate checking, and authentication validation.
class InvitationValidationModule {
  InvitationValidationModule();

  /// Validate email format
  bool isValidEmail(String email) {
    return RegExp(r'^[\p{L}\p{N}._%-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,4}$',
            unicode: true)
        .hasMatch(email);
  }

  /// Validate phone number format
  bool isValidPhoneNumber(String phoneNumber) {
    return RegExp(r'^\+?[\d\s\-\(\)]+$').hasMatch(phoneNumber);
  }

  /// Check for duplicate invitation by email
  bool hasDuplicateInvitationByEmail(
      List<GroupInvitation> invitations, String email) {
    return invitations.any((i) => i.toUserId == email);
  }

  /// Check for duplicate invitation by phone number
  bool hasDuplicateInvitationByPhone(
      List<GroupInvitation> invitations, String phoneNumber) {
    return invitations.any((i) => i.toUserId == phoneNumber);
  }

  /// Check for duplicate group invitation to user
  GroupInvitation? findDuplicateGroupInvitation({
    required List<GroupInvitation> invitations,
    required String userId,
    required String groupId,
  }) {
    return invitations.firstWhereOrNull(
      (inv) =>
          inv.toUserId == userId &&
          inv.groupId == groupId &&
          inv.status == GroupInvitationStatus.pending,
    );
  }

  /// Validate user authentication and information
  bool canSendInvitation({
    required String? currentUserId,
    required String? currentUserDisplayName,
  }) {
    return currentUserId != null && currentUserDisplayName != null;
  }

  /// Validate invitation inputs for group invitation
  bool validateGroupInvitationInputs({
    required String userId,
    required String groupId,
  }) {
    return userId.isNotEmpty && groupId.isNotEmpty;
  }

  /// Check if user information is available
  bool hasUserInformation({
    required String? currentUserId,
    required String? currentUserDisplayName,
  }) {
    return currentUserId != null && currentUserDisplayName != null;
  }
}
