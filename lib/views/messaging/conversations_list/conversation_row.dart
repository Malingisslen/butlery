// lib/views/messaging/conversations_list/conversation_row.dart
library;

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/messaging/conversation_list_item.dart';

/// A conversation tile with its visible ⋯ button. The button is the primary
/// way to the actions; long-press stays as a shortcut to the same menu.
class ConversationRow extends StatelessWidget {
  const ConversationRow({
    required this.conversation,
    required this.currentUserId,
    required this.onOpen,
    required this.onActions,
    required this.onPin,
    required this.onArchive,
    super.key,
  });

  final Conversation conversation;
  final String currentUserId;
  final VoidCallback onOpen;
  final VoidCallback onActions;
  final VoidCallback onPin;
  final VoidCallback onArchive;

  @override
  Widget build(BuildContext context) {
    final name = conversation.getDisplayTitle(currentUserId);
    return Row(
      children: [
        Expanded(
          child: ConversationListItem(
            conversation: conversation,
            currentUserId: currentUserId,
            onTap: onOpen,
            // BUT-948 exception: long-press opens the conversation action menu
            // (contextual), not multi-select — messaging convention.
            onLongPress: onActions,
            onPin: onPin,
            onArchive: onArchive,
          ),
        ),
        AppIconButton(
          onPressed: onActions,
          semanticLabel: context.l10n.messagesMoreOptionsFor(name),
          icon: ButleryIcons.moreVertical,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ],
    );
  }
}
