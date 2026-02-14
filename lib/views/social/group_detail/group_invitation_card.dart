// lib/views/social/group_detail/group_invitation_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// GroupInvitationCard - Invitation card component
/// Displays pending group invitation with cancel action.
class GroupInvitationCard {
  static Widget build(
    BuildContext context,
    GroupInvitation invitation,
    VoidCallback onCancelled,
  ) {
    return RepaintBoundary(
      child: Card(
        color: Theme.of(context)
            .colorScheme
            .tertiaryContainer
            .withValues(alpha: AppDimensions.opacityMediumLight),
        child: ListTile(
          leading: Stack(
            children: [
              // Avatar based on username from invitation
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context)
                      .colorScheme
                      .primary
                      .withValues(alpha: AppDimensions.opacityVeryLight),
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    invitation.fromUserName.isNotEmpty
                        ? invitation.fromUserName[0].toUpperCase()
                        : '?',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
              ),
              // Pending indicator
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.tertiary,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 1,
                    ),
                  ),
                ),
              ),
            ],
          ),
          title: Text(
            context.l10n.groupInvitationSent,
            style: AppTextStyles.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                  '${context.l10n.groupInvitationSentDate}: ${invitation.timeAgoText}'),
              Text(
                  '${context.l10n.groupInvitationExpires}: ${invitation.expiresInText}'),
            ],
          ),
          trailing: PopupMenuButton<String>(
            icon: Icon(
              Icons.more_vert,
              color: Theme.of(context).colorScheme.tertiary,
            ),
            onSelected: (value) => _handleAction(
              context,
              value,
              invitation,
              onCancelled,
            ),
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'cancel_invitation',
                child: Row(
                  children: [
                    Icon(
                      Icons.cancel,
                      color: Theme.of(context).colorScheme.error,
                    ),
                    const SizedBox(width: AppDimensions.spacingXs),
                    Text(
                      context.l10n.groupCancelInvitation,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static void _handleAction(
    BuildContext context,
    String action,
    GroupInvitation invitation,
    VoidCallback onCancelled,
  ) {
    switch (action) {
      case 'cancel_invitation':
        _cancelInvitation(context, invitation, onCancelled);
        break;
    }
  }

  static Future<void> _cancelInvitation(
    BuildContext context,
    GroupInvitation invitation,
    VoidCallback onCancelled,
  ) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.groupCancelInvitationConfirm),
        content: Text(
          context.l10n.groupCancelInvitationMessage(invitation.fromUserName),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(context.l10n.commonNo),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            child: Text(context.l10n.groupYesCancel),
          ),
        ],
      ),
    );

    if (shouldCancel == true && context.mounted) {
      final groupInvitationService =
          ServiceLocator.get<UnifiedFriendsService>();
      final success = await groupInvitationService.cancelSentInvitation(
        invitation.id,
      );

      if (success && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.groupInvitationCancelled),
            backgroundColor: Theme.of(context).colorScheme.primary,
          ),
        );
        onCancelled();
      } else if (context.mounted &&
          groupInvitationService.invitations.hasError) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              context.l10n.errorOccurredWithDetails(
                  '${groupInvitationService.invitations.error}'),
            ),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      }
    }
  }
}
