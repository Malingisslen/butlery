// lib/views/messaging/conversations_list/conversation_actions.dart
//
// The sheets and confirmations behind the Meddelanden page. Each sheet closes
// first (it pops a choice), then the page acts, so results show on the page.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/viewmodels/conversations_viewmodel.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';
import 'package:butlery/views/messaging/conversation_group_detail_view.dart';
import 'package:butlery/views/messaging/create_group_conversation_view.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';
import 'package:butlery/widgets/messaging/messaging_ui_components.dart';
import 'package:butlery/widgets/messaging/new_conversation_dialog.dart';

enum _NewMessageChoice { friend, group }

enum _ConversationAction {
  pin,
  archive,
  markRead,
  groupInfo,
  leaveGroup,
  profile,
  delete,
}

Future<void> showNewMessageSheet(BuildContext context) async {
  final l10n = context.l10n;
  final choice = await showButleryListSheet<_NewMessageChoice>(
    context,
    title: l10n.messagesNewMessage,
    rows: (sheetContext) => [
      ButleryListRow(
        label: l10n.messagesToFriend,
        leading: ButleryIcons.user,
        onTap: () => Navigator.of(sheetContext).pop(_NewMessageChoice.friend),
      ),
      ButleryListRow(
        label: l10n.messagesNewGroup,
        leading: ButleryIcons.users,
        onTap: () => Navigator.of(sheetContext).pop(_NewMessageChoice.group),
      ),
    ],
  );
  if (choice == null || !context.mounted) return;
  switch (choice) {
    case _NewMessageChoice.friend:
      await showDialog<void>(
        context: context,
        builder: (dialogContext) => NewConversationDialog(
          onConversationCreated: (conversationId) {
            Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => ChatViewFacade(conversationId: conversationId),
              ),
            );
          },
        ),
      );
    case _NewMessageChoice.group:
      await Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => const CreateGroupConversationView(),
        ),
      );
  }
}

Future<void> showConversationActions(
  BuildContext context,
  ConversationsViewModel vm,
  Conversation conversation,
) async {
  final l10n = context.l10n;
  final action = await showButleryListSheet<_ConversationAction>(
    context,
    title: conversation.getDisplayTitle(vm.currentUserId.orEmpty()),
    rows: (sheetContext) {
      void pick(_ConversationAction a) => Navigator.of(sheetContext).pop(a);
      return [
        ButleryListRow(
          label: conversation.isPinned
              ? l10n.messagingUnpin
              : l10n.messagingPin,
          // One glyph for both states until design draws the second one
          // (P7-U08 open question); the label carries the state.
          leading: ButleryIcons.pin,
          onTap: () => pick(_ConversationAction.pin),
        ),
        ButleryListRow(
          label: conversation.isArchived
              ? l10n.messagingUnarchive
              : l10n.messagingArchive,
          leading: conversation.isArchived
              ? ButleryIcons.history
              : ButleryIcons.archive,
          onTap: () => pick(_ConversationAction.archive),
        ),
        ButleryListRow(
          label: l10n.messagingMarkAsRead,
          leading: ButleryIcons.check,
          onTap: () => pick(_ConversationAction.markRead),
        ),
        if (conversation.isGroup) ...[
          ButleryListRow(
            label: l10n.messagingGroupInfo,
            leading: ButleryIcons.info,
            onTap: () => pick(_ConversationAction.groupInfo),
          ),
          // Keyed on `groupId`, not `isGroup`: leaving goes through the chat
          // group, so a legacy group conversation without one would throw.
          if (conversation.groupId != null)
            ButleryListRow(
              label: l10n.messagingLeaveGroup,
              leading: ButleryIcons.logOut,
              onTap: () => pick(_ConversationAction.leaveGroup),
            ),
        ] else
          ButleryListRow(
            label: l10n.messagingViewProfile,
            leading: ButleryIcons.user,
            onTap: () => pick(_ConversationAction.profile),
          ),
        // BUT-1838: not offered for a GROUP. Keyed on `groupId`, not
        // `isGroup` — `isGroup` is an ordinary client field and `groupId` is
        // the server-written authority, which is the same distinction the
        // rules and the deletion module use. Deleting the conversation would
        // leave the `chat_groups` document standing with a `conversationId`
        // pointing at nothing — the group would be unusable and no callable
        // recreates a conversation, so it is unrecoverable. "Lämna gruppen"
        // above is what a member actually means here, and it is the path that
        // takes an emptied group down properly.
        if (conversation.groupId == null)
          ButleryListRow.danger(
            label: l10n.messagingDeleteConversation,
            onTap: () => pick(_ConversationAction.delete),
          ),
      ];
    },
  );
  if (action == null || !context.mounted) return;
  switch (action) {
    case _ConversationAction.pin:
      await vm.togglePin(conversation.id);
    case _ConversationAction.archive:
      await vm.toggleArchive(conversation.id);
    case _ConversationAction.markRead:
      await vm.markConversationAsRead(conversation.id);
    case _ConversationAction.groupInfo:
      _navigateToGroupInfo(context, conversation);
    case _ConversationAction.leaveGroup:
      _confirmLeaveGroup(context, vm, conversation);
    case _ConversationAction.profile:
      await _navigateToUserProfile(context, vm, conversation);
    case _ConversationAction.delete:
      _confirmDelete(context, vm, conversation);
  }
}

void _confirmLeaveGroup(
  BuildContext context,
  ConversationsViewModel vm,
  Conversation conversation,
) {
  final l10n = context.l10n;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.messagingLeaveGroup),
      content: Text(
        l10n.messagingConfirmLeaveGroup(conversation.title.orEmpty()),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            final success = await vm.leaveGroup(conversation.id);
            if (context.mounted) {
              if (success) {
                SnackBarUtils.showSuccess(context, l10n.messagingLeftGroup);
              } else {
                SnackBarUtils.showFailure(
                  context,
                  what: vm.error ?? l10n.groupLeaveFailed,
                );
              }
            }
          },
          child: ErrorText(l10n.messagingLeave),
        ),
      ],
    ),
  );
}

void _confirmDelete(
  BuildContext context,
  ConversationsViewModel vm,
  Conversation conversation,
) {
  final l10n = context.l10n;

  showDialog<void>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: Text(l10n.messagingDeleteConversation),
      content: Text(l10n.messagingDeleteConversationConfirm),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogContext).pop(),
          child: Text(l10n.commonCancel),
        ),
        TextButton(
          onPressed: () async {
            Navigator.of(dialogContext).pop();
            final success = await vm.deleteConversation(conversation.id);
            if (context.mounted) {
              if (success) {
                SnackBarUtils.showSuccess(
                  context,
                  l10n.messagingConversationDeleted(
                    conversation.title.orEmpty(),
                  ),
                );
              } else {
                SnackBarUtils.showFailure(
                  context,
                  what: l10n.conversationDeleteFailed,
                );
              }
            }
          },
          child: ErrorText(l10n.commonDelete),
        ),
      ],
    ),
  );
}

// Pushes the CHAT group screen directly, the same way the in-chat
// "conversation info" action does (`ChatActionHandler`). Deliberately not the
// `Routes.groupDetail` named route: that one belongs to SOCIAL groups
// (`views/social/group_detail_view.dart`), and its generator does
// `settings.arguments as String?` while this call site passed a Map — so it
// threw a TypeError on EVERY tap and the social screen was never actually
// reached. The "wrong screen" the ticket describes was unreachable
// (BUT-1857).
void _navigateToGroupInfo(BuildContext context, Conversation conversation) {
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) =>
          ConversationGroupDetailView(conversationId: conversation.id),
    ),
  );
}

Future<void> _navigateToUserProfile(
  BuildContext context,
  ConversationsViewModel vm,
  Conversation conversation,
) async {
  final l10n = context.l10n;

  try {
    final otherParticipantId = conversation.participantIds.firstWhere(
      (id) => id != vm.currentUserId,
      orElse: () => conversation.participantIds.firstOrNull.orEmpty(),
    );

    final friendsService = ServiceLocator.get<UnifiedFriendsService>();

    // Try friends list first, fall back to UserService for non-friend DM partners
    final profile =
        friendsService.friendByUid(otherParticipantId) ??
        await ServiceLocator.get<UserService>().getUserProfile(
          otherParticipantId,
        );

    if (profile == null) throw Exception('Profile not found');

    if (!context.mounted) return;

    Navigator.pushNamed(context, Routes.friendProfile, arguments: profile);
  } catch (e) {
    if (context.mounted) {
      AppLogger.error('Failed to open profile', e);
      SnackBarUtils.showFailure(context, what: l10n.profileOpenFailed);
    }
  }
}
