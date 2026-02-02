/// Nuclear Chat App Bar Component - Conversation Header Logic
/// Focused component handling ONLY chat app bar presentation and menu actions
/// that was previously embedded within the massive ChatView architecture.
/// Implements clean conversation header with action coordination.

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/utils/logger.dart';

/// Clean chat app bar with conversation info and menu actions
class ChatAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Conversation? conversation;
  final Function(String) onMenuAction;

  const ChatAppBar({
    super.key,
    this.conversation,
    required this.onMenuAction,
  });

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);

  Future<void> _handleMenuAction(String action) async {
    try {
      AppLogger.debug('Chat app bar menu action: $action');
      await onMenuAction(action);
    } catch (e) {
      AppLogger.error('Failed to handle menu action: $action', e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: _buildTitle(),
      backgroundColor: AppColors.forestGreen,
      foregroundColor: AppColors.cardWhite,
      actions: [
        PopupMenuButton<String>(
          onSelected: _handleMenuAction,
          icon: const Icon(Icons.more_vert),
          itemBuilder: (context) => [
            const PopupMenuItem(
              value: 'info',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.info_outline),
                  SizedBox(width: AppDimensions.spacingS),
                  Flexible(
                    child: Text('Konversationsinfo'),
                  ),
                ],
              ),
            ),
            const PopupMenuItem(
              value: 'mute',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.notifications_off_outlined),
                  SizedBox(width: AppDimensions.spacingS),
                  Flexible(
                    child: Text('Tysta'),
                  ),
                ],
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem(
              value: 'leave',
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.exit_to_app, color: AppColors.error),
                  SizedBox(width: AppDimensions.spacingS),
                  Flexible(
                    child: Text('Lämna konversation'),
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
    if (conversation == null) {
      return const Text('Chatt');
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          conversation?.title ?? '',
          style: AppTextStyles.titleMedium,
        ),
        if (conversation != null && conversation!.participantIds.length > 2)
          Text(
            '${conversation!.participantIds.length} deltagare',
            style: AppTextStyles.labelMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
      ],
    );
  }
}
