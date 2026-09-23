/// Nuclear Chat App Bar Component - Conversation Header Logic
/// Focused component handling ONLY chat app bar presentation and menu actions
/// that was previously embedded within the massive ChatView architecture.
/// Implements clean conversation header with action coordination.

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/theme/app_dimensions.dart';
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

  /// Whether the bar shows the participant count under the title.
  bool get _hasCount =>
      conversation != null && conversation!.participantIds.length > 2;

  /// The subpage bar's own ceiling (ButleryTopBar.preferredSize), with or
  /// without the count line.
  @override
  Size get preferredSize => ButleryTopBar.undersida(
    title: '',
    secondaryLine: _hasCount ? '' : null,
  ).preferredSize;

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
    // The chat is a subpage on both platforms: back arrow and the
    // conversation's name, with the participant count as the line under it
    // (Komponentark v1 §01 pattern 2; Skarmar v12 del 2 'Chatt'; B-45).
    return ButleryTopBar.undersida(
      title: conversation == null
          ? context.l10n.chatTitle
          : (conversation?.title).orEmpty(),
      secondaryLine: _hasCount
          ? context.l10n.chatParticipantCount(
              conversation!.participantIds.length,
            )
          : null,
      secondaryLineIsLive: false,
      actions: [
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            ButleryMenuItem(
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
            ButleryMenuItem(
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
              ButleryMenuItem(
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
            ButleryMenuItem(
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
            ButleryMenuItem(
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
}
