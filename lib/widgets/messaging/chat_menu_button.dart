// The chat's overflow menu, and the words the page template's bar shows for
// a conversation. The bar itself is ButleryPage's (top_bar_choice_test).

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';

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
    final l10n = context.l10n;
    final isGroup = conversation?.groupId != null;
    return ButleryMenu<String>(
      semanticLabel: l10n.socialMoreOptions,
      onSelected: _handleMenuAction,
      choices: [
        ButleryMenuChoice(
          value: 'info',
          label: l10n.chatConversationInfo,
          icon: ButleryIcons.info,
        ),
        ButleryMenuChoice(
          value: 'mute',
          label: conversation?.isMuted == true
              ? l10n.chatUnmute
              : l10n.chatMute,
          icon: ButleryIcons.bellOff,
        ),
        // The group's weekly menu only exists for a group conversation —
        // the plan is keyed by the CONVERSATION id (`messaging_service`
        // writes `groupId: conversation.id`), and a DM has no plan.
        if (isGroup)
          ButleryMenuChoice(
            value: 'weekly_menu',
            label: l10n.groupMenuChatAction,
            icon: ButleryIcons.calendar,
          ),
        ButleryMenuChoice(
          value: 'block',
          label: l10n.socialBlock,
          icon: ButleryIcons.block,
          danger: true,
        ),
        // Only a chat group can be left; a direct chat has no group to
        // leave, and deleting it lives in the conversation list.
        if (isGroup)
          ButleryMenuChoice(
            value: 'leave',
            label: l10n.chatLeaveConversation,
            icon: ButleryIcons.logOut,
            danger: true,
          ),
      ],
    );
  }
}
