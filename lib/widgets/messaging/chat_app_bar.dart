/// Nuclear Chat App Bar Component - Conversation Header Logic
/// Focused component handling ONLY chat app bar presentation and menu actions
/// that was previously embedded within the massive ChatView architecture.
/// Implements clean conversation header with action coordination.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/logger.dart';

/// Clean chat app bar with conversation info and menu actions
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Conversation? conversation;
  final Function(String) onMenuAction;
  final void Function(Object error)? onError;

  const ChatAppBar({
    super.key,
    this.conversation,
    required this.onMenuAction,
    this.onError,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _handleMenuAction(String action) async {
    try {
      AppLogger.debug('Chat app bar menu action: $action');
      await onMenuAction(action);
    } catch (e) {
      AppLogger.error('Failed to handle menu action: $action', e);
      onError?.call(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return AppBar(
      title: _buildTitle(),
      backgroundColor: cs.primary,
      foregroundColor: cs.surfaceContainerHighest,
      actions: [
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            PopupMenuItem(
              value: 'info',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.info_outline),
                  const SizedBox(width: AppDimensions.spacingS),
                  Flexible(
                    child: Text(context.l10n.chatConversationInfo),
                  ),
                ],
              ),
            ),
            PopupMenuItem(
              value: 'mute',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.notifications_off_outlined),
                  const SizedBox(width: AppDimensions.spacingS),
                  Flexible(
                    child: Text(context.l10n.chatMute),
                  ),
                ],
              ),
            ),
            // The group's weekly menu only exists for a group conversation —
            // the plan is keyed by the CONVERSATION id (`messaging_service`
            // writes `groupId: conversation.id`), and a DM has no plan.
            if (conversation?.groupId != null)
              PopupMenuItem(
                value: 'weekly_menu',
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.calendar_month_outlined),
                    const SizedBox(width: AppDimensions.spacingS),
                    Flexible(child: Text(context.l10n.groupMenuChatAction)),
                  ],
                ),
              ),
            PopupMenuItem(
              value: 'block',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.block, color: cs.error),
                  const SizedBox(width: AppDimensions.spacingS),
                  Flexible(
                    child: Text(context.l10n.socialBlock),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'leave',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.exit_to_app, color: cs.error),
                  const SizedBox(width: AppDimensions.spacingS),
                  Flexible(
                    child: Text(context.l10n.chatLeaveConversation),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTitle() {
    return Builder(
      builder: (context) {
        final cs = Theme.of(context).colorScheme;
        if (conversation == null) {
          return Text(context.l10n.chatTitle);
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              (conversation?.title).orEmpty(),
              style: AppTextStyles.titleMedium,
            ),
            if (conversation != null && conversation!.participantIds.length > 2)
              Text(
                context.l10n.chatParticipantCount(
                  conversation!.participantIds.length,
                ),
                style: AppTextStyles.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
          ],
        );
      },
    );
  }
}
