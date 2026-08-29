/// Menu-tab entry point to a group's weekly menu (BUT-1971).
///
/// Malin picked "båda" for where the screen is reached from: the group chat,
/// where the group is already known, and here, where it is not.
///
/// The icon is always shown; the group list is fetched on TAP. A user with no
/// groups is told so, which is cheaper than subscribing to conversations on
/// every visit to the menu tab.
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/services/messaging_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/views/group_weekly_menu_view.dart';

class GroupMenuEntryButton extends StatelessWidget {
  const GroupMenuEntryButton({super.key});

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: Icon(
        Icons.groups_outlined,
        color: Theme.of(context).colorScheme.onPrimary,
      ),
      tooltip: context.l10n.groupMenuChatAction,
      onPressed: () => unawaited(_open(context)),
    );
  }

  Future<void> _open(BuildContext context) async {
    final userId = ServiceLocator.get<PermissionService>().currentUserId;
    if (userId == null) return;

    final List<Conversation> conversations;
    try {
      conversations = await ServiceLocator.get<MessagingService>()
          .getMyConversations()
          .first
          // Bounded: a stream that never emits would leave the tap producing
          // nothing at all — no spinner, no message — which is the same
          // "buttons do nothing" failure this screen was built to avoid.
          .timeout(const Duration(seconds: 10));
    } catch (e) {
      // `_open` is fired through `unawaited`, so without this a stream error
      // becomes an unhandled async error and the tap does nothing visible.
      AppLogger.error('Could not list conversations for the group menu', e);
      if (context.mounted) {
        SnackBarUtils.showError(
          context,
          context.l10n.groupMenuGroupsLoadFailed,
        );
      }
      return;
    }
    final groups = conversations.where((c) => c.groupId != null).toList();
    if (!context.mounted) return;

    if (groups.isEmpty) {
      // Informational, not a failure: nothing went wrong, the user simply has
      // no group chats yet.
      SnackBarUtils.showInfo(context, context.l10n.groupMenuNoGroups);
      return;
    }

    final chosen = groups.length == 1
        ? groups.first
        : await _pickGroup(context, groups);
    if (chosen == null || !context.mounted) return;

    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => GroupWeeklyMenuView(
          // The plan is keyed by the CONVERSATION id — `closePoll` writes
          // `groupId: conversation.id`, not the chat-group id.
          groupId: chosen.id,
          groupName: chosen.title ?? context.l10n.groupMenuUntitledGroup,
          currentUserId: userId,
          // No `onStartPoll`: a poll is started in the chat, and this route did
          // not come from one. The empty state then renders its text without a
          // button rather than offering one that goes nowhere.
        ),
      ),
    );
  }

  Future<Conversation?> _pickGroup(
    BuildContext context,
    List<Conversation> groups,
  ) {
    return showModalBottomSheet<Conversation>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              title: Text(
                sheetContext.l10n.groupMenuPickGroupTitle,
                style: Theme.of(sheetContext).textTheme.titleMedium,
              ),
            ),
            for (final group in groups)
              ListTile(
                leading: const Icon(Icons.groups_outlined),
                title: Text(
                  group.title ?? sheetContext.l10n.groupMenuUntitledGroup,
                ),
                onTap: () => Navigator.of(sheetContext).pop(group),
              ),
          ],
        ),
      ),
    );
  }
}
