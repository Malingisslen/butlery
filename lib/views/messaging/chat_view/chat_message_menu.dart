import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/emoji_reaction_picker.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';

enum ChatMessageAction { reply, copy, edit, delete, report }

/// What the sheet picked: one of the actions, or a reaction key.
class ChatMessageMenuChoice {
  final ChatMessageAction? action;
  final String? reaction;

  const ChatMessageMenuChoice.action(ChatMessageAction this.action)
    : reaction = null;
  const ChatMessageMenuChoice.reaction(String this.reaction) : action = null;
}

/// The message menu a long press opens. Which rows show follows who wrote the
/// message: only the author edits or deletes, only others report.
Future<ChatMessageMenuChoice?> showChatMessageMenu(
  BuildContext context, {
  required Message message,
  required bool isOwn,
}) {
  final l10n = context.l10n;
  final isText = message.type == MessageType.text;
  return showButleryListSheet<ChatMessageMenuChoice>(
    context,
    title: l10n.chatMessageMenuTitle,
    rows: (sheetContext) {
      void pick(ChatMessageMenuChoice choice) =>
          Navigator.of(sheetContext).pop(choice);
      return [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: AppDimensions.space8),
          child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: EmojiReactionPicker(
              onReactionSelected: (key) =>
                  pick(ChatMessageMenuChoice.reaction(key)),
            ),
          ),
        ),
        ButleryListRow(
          label: l10n.chatMessageReply,
          leading: ButleryIcons.reply,
          onTap: () => pick(
            const ChatMessageMenuChoice.action(
              ChatMessageAction.reply,
            ),
          ),
        ),
        if (isText)
          ButleryListRow(
            label: l10n.chatMessageCopy,
            leading: ButleryIcons.copy,
            onTap: () => pick(
              const ChatMessageMenuChoice.action(
                ChatMessageAction.copy,
              ),
            ),
          ),
        if (isOwn && isText)
          ButleryListRow(
            label: l10n.commonEdit,
            leading: ButleryIcons.pencil,
            onTap: () => pick(
              const ChatMessageMenuChoice.action(
                ChatMessageAction.edit,
              ),
            ),
          ),
        if (isOwn)
          ButleryListRow.danger(
            label: l10n.chatDeleteMessage,
            onTap: () => pick(
              const ChatMessageMenuChoice.action(
                ChatMessageAction.delete,
              ),
            ),
          )
        else
          ButleryListRow(
            label: l10n.reportContent,
            leading: ButleryIcons.flag,
            onTap: () => pick(
              const ChatMessageMenuChoice.action(
                ChatMessageAction.report,
              ),
            ),
          ),
      ];
    },
  );
}
