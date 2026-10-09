// lib/views/social/group_detail/group_invitation_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// GroupInvitationCard - Invitation card component
/// Displays pending group invitation with cancel action.
class GroupInvitationCard {
  static Widget build(
    BuildContext context,
    GroupInvitation invitation,
    VoidCallback onCancelled, {
    String? inviteeName,
  }) {
    final name = (inviteeName?.isNotEmpty ?? false) ? inviteeName : null;
    return RepaintBoundary(
      child: Card(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        child: ListTile(
          leading: Stack(
            children: [
              // The row is about who was invited, not who invited them.
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: Text(
                    name != null ? name.characters.first.toUpperCase() : '?',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: Theme.of(context).colorScheme.onSurface,
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
            name ?? context.l10n.groupInvitationSent,
            style: AppTextStyles.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${context.l10n.groupInvitationSentDate}: ${invitation.timeAgoText}',
              ),
              Text(
                '${context.l10n.groupInvitationExpires}: ${invitation.expiresInText}',
              ),
            ],
          ),
          trailing: PressFill(
            surface: PressSurface.base,
            child: PopupMenuButton<String>(
              icon: ButleryIcon(
                ButleryIcons.moreVertical,
                color: Theme.of(context).colorScheme.tertiary,
              ),
              onSelected: (value) => _handleAction(
                context,
                value,
                invitation,
                name,
                onCancelled,
              ),
              itemBuilder: (context) => [
                ButleryMenuItem(
                  value: 'cancel_invitation',
                  child: Row(
                    children: [
                      ButleryIcon(
                        ButleryIcons.x,
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
      ),
    );
  }

  static void _handleAction(
    BuildContext context,
    String action,
    GroupInvitation invitation,
    String? inviteeName,
    VoidCallback onCancelled,
  ) {
    switch (action) {
      case 'cancel_invitation':
        _cancelInvitation(context, invitation, inviteeName, onCancelled);
        break;
    }
  }

  static Future<void> _cancelInvitation(
    BuildContext context,
    GroupInvitation invitation,
    String? inviteeName,
    VoidCallback onCancelled,
  ) async {
    final shouldCancel = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.groupCancelInvitationConfirm),
        // Names the invitee; without a readable name the title alone asks.
        content: inviteeName == null
            ? null
            : Text(context.l10n.groupCancelInvitationMessage(inviteeName)),
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
        SnackBarUtils.showInfo(context, context.l10n.groupInvitationCancelled);
        onCancelled();
      } else if (context.mounted &&
          groupInvitationService.invitations.hasError) {
        AppLogger.error(
          'Failed to cancel group invitation',
          groupInvitationService.invitations.error,
        );
        SnackBarUtils.showFailure(
          context,
          what: context.l10n.groupInvitationCancelFailed,
        );
      }
    }
  }
}
