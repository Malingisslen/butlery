// lib/views/social/group_detail/group_invitation_card.dart

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

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
    final cs = Theme.of(context).colorScheme;
    return RepaintBoundary(
      child: ButleryItemRow(
        padded: false,
        // The row is about who was invited, not who invited them.
        leading: _DashedAvatar(
          initial: name != null ? name.characters.first.toUpperCase() : '?',
        ),
        title: name ?? context.l10n.groupInvitationSent,
        titleMaxLines: 1,
        subtitle:
            '${context.l10n.groupInvitationExpires}: ${invitation.expiresInText}',
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              context.l10n.groupInvitedLabel,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            ButleryMenu<String>(
              semanticLabel: context.l10n.socialMoreOptions,
              onSelected: (value) => _handleAction(
                context,
                value,
                invitation,
                name,
                onCancelled,
              ),
              choices: [
                ButleryMenuChoice(
                  value: 'cancel_invitation',
                  icon: ButleryIcons.x,
                  label: context.l10n.groupCancelInvitation,
                  danger: true,
                ),
              ],
            ),
          ],
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
    final shouldCancel = await DestructiveConfirmationDialog.show(
      context,
      title: context.l10n.groupCancelInvitationTitle,
      // Names the invitee; without a readable name the title alone asks.
      message: inviteeName == null
          ? ''
          : context.l10n.groupCancelInvitationMessage(inviteeName),
      primaryActionText: context.l10n.groupCancelInvitationAction,
      secondaryActionText: context.l10n.groupKeepInvitation,
      primaryActionIcon: ButleryIcons.x,
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

/// The invited person's avatar: a dashed circle, since they are not in the
/// group yet.
class _DashedAvatar extends StatelessWidget {
  const _DashedAvatar({required this.initial});

  final String initial;

  static const double _size = 48;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return CustomPaint(
      painter: _DashedCirclePainter(color: cs.onSurfaceVariant),
      child: SizedBox(
        width: _size,
        height: _size,
        child: Center(
          child: Text(
            initial,
            style: AppTextStyles.bodyBold.copyWith(color: cs.onSurfaceVariant),
          ),
        ),
      ),
    );
  }
}

class _DashedCirclePainter extends CustomPainter {
  const _DashedCirclePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final radius = (size.shortestSide - paint.strokeWidth) / 2;
    final center = size.center(Offset.zero);
    const dashCount = 20;
    const sweep = 2 * math.pi / dashCount;
    for (var i = 0; i < dashCount; i++) {
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        i * sweep,
        sweep * 0.55,
        false,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DashedCirclePainter oldDelegate) =>
      oldDelegate.color != color;
}
