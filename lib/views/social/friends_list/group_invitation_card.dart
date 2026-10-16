// lib/views/social/friends_list/group_invitation_card.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/cards/styled_card.dart';

/// GroupInvitationCard - Group invitation card component
/// Displays group invitation with accept/reject actions.
class GroupInvitationCard {
  static Widget build(
    BuildContext context,
    GroupInvitation invitation,
    UnifiedFriendsService service,
  ) {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.space16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AvatarCircle(glyph: invitation.groupEmoji),
                const SizedBox(
                  width: (AppDimensions.space8 + AppDimensions.space4),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        invitation.groupName,
                        style: AppTextStyles.titleBold,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        context.l10n.groupInvitationFrom(
                          invitation.fromUserName,
                        ),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      Text(
                        '${context.l10n.groupSent}: ${invitation.timeAgoText}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Theme.of(context).colorScheme.tertiary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (invitation.personalMessage?.isNotEmpty == true) ...[
              const SizedBox(
                height: (AppDimensions.space8 + AppDimensions.space4),
              ),
              Container(
                padding: const EdgeInsets.all(AppDimensions.space4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.radiusControl,
                  ),
                ),
                child: Text(
                  invitation.personalMessage!,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ),
            ],
            const SizedBox(
              height: (AppDimensions.space8 + AppDimensions.space4),
            ),
            Row(
              children: [
                Expanded(
                  child: ActionButtons.outlinedButton(
                    context,
                    isExpanded: true,
                    label: context.l10n.commonDecline,
                    onPressed: service.invitations.isLoading
                        ? null
                        : () => _rejectInvitation(
                            context,
                            invitation.id,
                            service,
                          ),
                  ),
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: ActionButtons.primaryButton(
                    context,
                    isExpanded: true,
                    label: context.l10n.commonAccept,
                    onPressed: service.invitations.isLoading
                        ? null
                        : () => _acceptInvitation(
                            context,
                            invitation.id,
                            service,
                          ),
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
    AppLogger.info(
      '🔘 [UI] Accept button pressed for invitation: $invitationId',
    );
    AppLogger.debug('🔍 [UI] Service type: ${service.runtimeType}');
    AppLogger.debug(
      '🔍 [UI] Invitations type: ${service.invitations.runtimeType}',
    );

    bool success = false;
    // Try calling the method and catch any synchronous exceptions
    try {
      success = await service.invitations.acceptGroupInvitation(invitationId);
      AppLogger.info(
        '📊 [UI] Accept result: success=$success, hasError=${service.invitations.hasError}, error=${service.invitations.error}',
      );
    } catch (e, stack) {
      AppLogger.error('❌ [UI] Exception during accept: $e');
      AppLogger.error('📍 [UI] Stack trace: $stack');
    }

    AppLogger.debug('📊 [UI] After accept call');

    if (success && context.mounted) {
      SnackBarUtils.showSuccess(
        context,
        context.l10n.groupInvitationAccepted,
      );
    } else if (context.mounted && service.invitations.hasError) {
      SnackBarUtils.showFailure(
        context,
        what:
            service.invitations.error ??
            context.l10n.groupCouldNotAcceptInvitation,
      );
    } else if (!success && context.mounted) {
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.groupCouldNotAcceptInvitation,
      );
    }
  }

  static Future<void> _rejectInvitation(
    BuildContext context,
    String invitationId,
    UnifiedFriendsService service,
  ) async {
    final success = await service.invitations.rejectGroupInvitation(
      invitationId,
    );

    if (success && context.mounted) {
      SnackBarUtils.showWarning(context, context.l10n.groupInvitationDeclined);
    } else if (context.mounted && service.invitations.hasError) {
      SnackBarUtils.showFailure(
        context,
        what:
            service.invitations.error ??
            context.l10n.groupInvitationDeclineFailed,
      );
    }
  }
}
