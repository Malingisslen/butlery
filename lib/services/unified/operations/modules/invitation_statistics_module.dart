// lib/services/unified/operations/modules/invitation_statistics_module.dart

import 'package:butlery/models/group_invitation.dart';

/// Module handling invitation statistics and analytics.
/// Provides stats calculation, metrics, search, and filtering.
class InvitationStatisticsModule {
  InvitationStatisticsModule();

  /// Get invitation statistics
  Map<String, dynamic> getInvitationStats(List<GroupInvitation> invitations) {
    final total = invitations.length;
    final pending = invitations
        .where((i) => i.status == GroupInvitationStatus.pending)
        .length;
    final accepted = invitations
        .where((i) => i.status == GroupInvitationStatus.accepted)
        .length;
    final rejected = invitations
        .where((i) => i.status == GroupInvitationStatus.rejected)
        .length;
    final cancelled = invitations
        .where((i) => i.status == GroupInvitationStatus.cancelled)
        .length;
    final expired = getExpiredInvitations(invitations).length;

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
  Map<String, dynamic> getInvitationMetrics(List<GroupInvitation> invitations) {
    final stats = getInvitationStats(invitations);
    final recentInvitations = invitations
        .where((i) =>
            i.sentAt.isAfter(DateTime.now().subtract(const Duration(days: 30))))
        .length;

    return {
      ...stats,
      'recentInvitations': recentInvitations,
      'averageResponseTime': calculateAverageResponseTime(invitations),
    };
  }

  /// Get expired invitations
  List<GroupInvitation> getExpiredInvitations(
      List<GroupInvitation> invitations) {
    final now = DateTime.now();
    return invitations.where((i) => i.expiresAt.isBefore(now)).toList();
  }

  /// Calculate average response time in hours
  double calculateAverageResponseTime(List<GroupInvitation> invitations) {
    final respondedInvitations = invitations
        .where((i) =>
            i.status == GroupInvitationStatus.accepted ||
            i.status == GroupInvitationStatus.rejected)
        .where((i) => i.respondedAt != null)
        .toList();

    if (respondedInvitations.isEmpty) return 0;

    final totalHours = respondedInvitations
        .map((i) => i.respondedAt!.difference(i.sentAt).inHours)
        .fold(0, (sum, hours) => sum + hours);

    return totalHours / respondedInvitations.length;
  }

  /// Search invitations by query
  List<GroupInvitation> searchInvitations(
      List<GroupInvitation> invitations, String query) {
    final searchTerm = query.toLowerCase();
    return invitations
        .where((i) =>
            (i.toUserId.toLowerCase().contains(searchTerm)) ||
            (i.fromUserName.toLowerCase().contains(searchTerm)) ||
            (i.groupName.toLowerCase().contains(searchTerm)))
        .toList();
  }

  /// Get invitations by status
  List<GroupInvitation> getInvitationsByStatus(
      List<GroupInvitation> invitations, GroupInvitationStatus status) {
    return invitations.where((i) => i.status == status).toList();
  }

  /// Get pending invitations
  List<GroupInvitation> getPendingInvitations(
      List<GroupInvitation> invitations) {
    return invitations
        .where((i) => i.status == GroupInvitationStatus.pending)
        .toList();
  }
}
