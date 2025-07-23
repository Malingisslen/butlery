// lib/views/social/friends_list/group_invitation_card.dart

import 'package:flutter/material.dart';
import '../../../models/group_invitation.dart';
import '../../../services/unified/unified_friends_service.dart';
import '../../../theme/app_dimensions.dart';
import '../../../core/utils/snackbar_utils.dart';

/// GroupInvitationCard - Group invitation card component
///
/// Displays group invitation with accept/reject actions.
class GroupInvitationCard {
  static Widget build(
    BuildContext context,
    GroupInvitation invitation,
    UnifiedFriendsService service,
  ) {
    return Card(
      color: Theme.of(context).colorScheme.tertiaryContainer.withValues(alpha: 0.3),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        side: BorderSide(
          color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.3),
          width: 1,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                  ),
                  child: Center(
                    child: Text(
                      invitation.groupEmoji,
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.groupName,
                        style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Inbjudan från ${invitation.fromUserName}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                      Text(
                        'Skickat: ${invitation.timeAgoText}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (invitation.personalMessage?.isNotEmpty == true) ...[
              const SizedBox(height: 12),
              Container(
                padding: EdgeInsets.all(AppDimensions.spacingS),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.05),
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                ),
                child: Text(
                  invitation.personalMessage!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: service.invitations.isLoading
                        ? null
                        : () => _rejectInvitation(context, invitation.id, service),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Theme.of(context).colorScheme.error,
                      side: BorderSide(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                    child: const Text('Avvisa'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: FilledButton(
                    onPressed: service.invitations.isLoading
                        ? null
                        : () => _acceptInvitation(context, invitation.id, service),
                    style: FilledButton.styleFrom(
                      backgroundColor: Theme.of(context).colorScheme.primary,
                    ),
                    child: const Text('Acceptera'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static Future<void> _acceptInvitation(
    BuildContext context,
    String invitationId,
    UnifiedFriendsService service,
  ) async {
    final success = await service.invitations.acceptGroupInvitation(invitationId);

    if (success && context.mounted) {
      SnackBarUtils.showSuccess(
        context,
        'Inbjudan accepterad! Välkommen till gruppen! 🎉',
      );
    } else if (context.mounted && service.invitations.hasError) {
      SnackBarUtils.showError(
        context,
        'Fel: ${service.invitations.error}',
      );
    }
  }

  static Future<void> _rejectInvitation(
    BuildContext context,
    String invitationId,
    UnifiedFriendsService service,
  ) async {
    final success = await service.invitations.rejectGroupInvitation(invitationId);

    if (success && context.mounted) {
      SnackBarUtils.showWarning(context, 'Inbjudan avvisad');
    } else if (context.mounted && service.invitations.hasError) {
      SnackBarUtils.showError(
        context,
        'Fel: ${service.invitations.error}',
      );
    }
  }
}