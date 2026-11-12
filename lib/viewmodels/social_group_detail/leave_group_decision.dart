import 'package:butlery/models/user_profile.dart';

/// Information about ownership succession when owner leaves group.
/// Used to communicate leave group requirements to the UI.
class LeaveGroupDecision {
  final bool requiresOwnershipTransfer;
  final bool groupIsEmpty;
  final List<UserProfile> availableNewOwners;

  /// At least one member's profile could not be READ, so the member list this
  /// decision was taken from is a subset of unknown size. Both other outcomes
  /// are then unsafe: `groupIsEmpty` routes the owner to a delete dialog, and
  /// `availableNewOwners` would offer a truncated candidate list.
  final bool rosterIncomplete;

  /// Decides what leaving needs from the group's roster, with no service access.
  factory LeaveGroupDecision.forMembers({
    required bool isOwner,
    required bool rosterIncomplete,
    required List<UserProfile> members,
    required String currentUserId,
  }) {
    if (!isOwner) {
      // Non-owner can leave freely
      return const LeaveGroupDecision(
        requiresOwnershipTransfer: false,
        groupIsEmpty: false,
        availableNewOwners: [],
      );
    }

    // An owner whose members failed to load would otherwise be told the group
    // is EMPTY and offered deletion — `members` is the same subset
    // `hasUnresolvedMembers` warns about, and the view routes `groupIsEmpty`
    // straight into a delete dialog. Refused rather than guessed: the failure
    // is transient, and re-reading is free.
    if (rosterIncomplete) {
      return const LeaveGroupDecision(
        requiresOwnershipTransfer: false,
        groupIsEmpty: false,
        availableNewOwners: [],
        rosterIncomplete: true,
      );
    }

    // Owner leaving - check for other members
    final otherMembers = members
        .where((member) => member.uid != currentUserId)
        .toList();

    if (otherMembers.isEmpty) {
      // Empty group - owner can delete it
      return const LeaveGroupDecision(
        requiresOwnershipTransfer: false,
        groupIsEmpty: true,
        availableNewOwners: [],
      );
    } else {
      // Has other members - requires ownership transfer
      return LeaveGroupDecision(
        requiresOwnershipTransfer: true,
        groupIsEmpty: false,
        availableNewOwners: otherMembers,
      );
    }
  }

  const LeaveGroupDecision({
    required this.requiresOwnershipTransfer,
    required this.groupIsEmpty,
    required this.availableNewOwners,
    this.rosterIncomplete = false,
  });
}
