// The chat's overflow menu, and the words the page template's bar shows for
// a conversation. The bar itself is ButleryPage's (top_bar_choice_test).

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/butlery_control_focus.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// What the page template's bar shows for a conversation: the name, and the
/// participant count under it for a group.
class ChatBarText {
  const ChatBarText._();

  static String title(BuildContext context, Conversation? conversation) =>
      conversation == null
      ? context.l10n.chatTitle
      : (conversation.title).orEmpty();

  static String? participantLine(
    BuildContext context,
    Conversation? conversation,
  ) => conversation != null && conversation.participantIds.length > 2
      ? context.l10n.chatParticipantCount(conversation.participantIds.length)
      : null;
}

class ChatMenuButton extends StatelessWidget {
  final Conversation? conversation;
  final Function(String) onMenuAction;
  final void Function(Object error)? onError;

  const ChatMenuButton({
    super.key,
    this.conversation,
    required this.onMenuAction,
    this.onError,
  });

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
    return PressFill(
      surface: PressSurface.base,
      child: PopupMenuButton<String>(
        onSelected: _handleMenuAction,
        icon: const ButleryIcon(ButleryIcons.moreVertical),
        itemBuilder: (context) => [
          ButleryMenuItem(
            value: 'info',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const ButleryIcon(ButleryIcons.info),
                const SizedBox(width: AppDimensions.space4),
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
                const ButleryIcon(ButleryIcons.bellOff),
                const SizedBox(width: AppDimensions.space4),
                Flexible(
                  child: Text(
                    conversation?.isMuted == true
                        ? context.l10n.chatUnmute
                        : context.l10n.chatMute,
                  ),
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
                  const ButleryIcon(ButleryIcons.calendar),
                  const SizedBox(width: AppDimensions.space4),
                  Flexible(child: Text(context.l10n.groupMenuChatAction)),
                ],
              ),
            ),
          ButleryMenuItem(
            value: 'block',
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ButleryIcon(ButleryIcons.block, color: cs.error),
                const SizedBox(width: AppDimensions.space4),
                Flexible(
                  child: Text(context.l10n.socialBlock),
                ),
              ],
            ),
          ),
          // Only a chat group can be left; a direct chat has no group to
          // leave, and deleting it lives in the conversation list.
          if (conversation?.groupId != null) ...[
            const PopupMenuDivider(),
            ButleryMenuItem(
              value: 'leave',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ButleryIcon(ButleryIcons.logOut, color: cs.error),
                  const SizedBox(width: AppDimensions.space4),
                  Flexible(
                    child: Text(context.l10n.chatLeaveConversation),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
