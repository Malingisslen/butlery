// lib/widgets/messaging/conversation_list_item.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// List item widget for displaying conversation in conversations list.
/// Supports swipe gestures for pin/archive and long-press context menu.
class ConversationListItem extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPin;
  final VoidCallback? onArchive;
  final bool showOnlineStatus;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.currentUserId,
    this.onTap,
    this.onLongPress,
    this.onPin,
    this.onArchive,
    this.showOnlineStatus = false,
  });

  bool get _hasUnreadMessages => conversation.hasUnreadMessages(currentUserId);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return RepaintBoundary(
      child: Dismissible(
        key: Key('conversation-${conversation.id}'),
        direction: DismissDirection.horizontal,
        confirmDismiss: (direction) async {
          if (direction == DismissDirection.endToStart) {
            // Left swipe = archive/unarchive
            onArchive?.call();
          } else if (direction == DismissDirection.startToEnd) {
            // Right swipe = pin/unpin toggle
            onPin?.call();
          }
          // Service handles list update via stream, don't dismiss
          return false;
        },
        background: Container(
          alignment: AlignmentDirectional.centerStart,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
          ),
          color: context.butleryColors.info,
          child: Icon(
            conversation.isPinned ? Icons.push_pin_outlined : Icons.push_pin,
            color: context.butleryColors.onInfo,
          ),
        ),
        secondaryBackground: Container(
          alignment: AlignmentDirectional.centerEnd,
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
          ),
          color: context.butleryColors.warning,
          child: Icon(
            conversation.isArchived ? Icons.unarchive : Icons.archive,
            color: context.butleryColors.onWarning,
          ),
        ),
        child: Semantics(
          label: context.l10n.a11yConversationOpen(
            conversation.getDisplayTitle(currentUserId),
          ),
          button: true,
          child: InkWell(
            onTap: onTap,
            onLongPress: onLongPress,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingM,
                vertical: AppDimensions.paddingS,
              ),
              child: Row(
                children: [
                  _buildAvatar(context),
                  const SizedBox(width: AppDimensions.paddingM),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Title row with optional pin icon and timestamp
                        Row(
                          children: [
                            if (conversation.isPinned)
                              Padding(
                                padding: const EdgeInsetsDirectional.only(
                                  end: AppDimensions.spacingXs,
                                ),
                                child: Icon(
                                  Icons.push_pin,
                                  size: AppDimensions.iconSize14,
                                  color: cs.outlineVariant,
                                ),
                              ),
                            Expanded(
                              child: Text(
                                conversation.getDisplayTitle(currentUserId),
                                style: _hasUnreadMessages
                                    ? AppTextStyles.bodyBold.copyWith(
                                        color: cs.onSurface,
                                      )
                                    : AppTextStyles.bodyMedium.copyWith(
                                        color: cs.onSurface,
                                      ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppDimensions.paddingS),
                            Text(
                              conversation.formattedLastActivity,
                              style: _hasUnreadMessages
                                  ? AppTextStyles.labelSmall.copyWith(
                                      color: cs.primary,
                                    )
                                  : AppTextStyles.labelSmall.copyWith(
                                      color: cs.onSurfaceVariant,
                                      fontWeight: FontWeight.normal,
                                    ),
                            ),
                          ],
                        ),
                        const SizedBox(height: AppDimensions.spacingXxs),
                        // Last message and unread indicator row
                        Row(
                          children: [
                            Expanded(
                              child: Text(
                                _getLastMessagePreview(context),
                                style: _hasUnreadMessages
                                    ? AppTextStyles.labelSmall.copyWith(
                                        color: cs.onSurface,
                                      )
                                    : AppTextStyles.labelSmall.copyWith(
                                        color: cs.onSurfaceVariant,
                                      ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (_hasUnreadMessages) ...[
                              const SizedBox(width: AppDimensions.paddingS),
                              _buildUnreadIndicator(context),
                            ],
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: cs.inversePrimary.withValues(
              alpha: AppDimensions.opacityLight,
            ),
          ),
          child: conversation.isGroup
              ? _buildGroupAvatar(context)
              : _buildDirectConversationAvatar(context),
        ),

        // Online status indicator (only for direct conversations)
        if (!conversation.isGroup && showOnlineStatus)
          Positioned(
            bottom: AppDimensions.spacingXxs,
            right: AppDimensions.spacingXxs,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: context.butleryColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: Theme.of(context).colorScheme.surface,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGroupAvatar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.primary.withValues(alpha: AppDimensions.opacityVeryLight),
      ),
      child: Icon(
        Icons.group,
        color: cs.primary,
        size: AppDimensions.iconSizeL,
      ),
    );
  }

  Widget _buildDirectConversationAvatar(BuildContext context) {
    final avatarUrl = conversation.getDisplayAvatarUrl(currentUserId);
    final displayName = conversation.getDisplayTitle(currentUserId);

    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return SimpleImageWidget(
        imageUrl: avatarUrl,
        config: ImageConfig.avatar(
          size: ImageSize.custom,
        ),
        placeholder: _buildAvatarFallback(context, displayName),
      );
    }

    return _buildAvatarFallback(context, displayName);
  }

  Widget _buildAvatarFallback(BuildContext context, String displayName) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: AppTextStyles.sectionHeader.copyWith(
          color: cs.primary,
        ),
      ),
    );
  }

  Widget _buildUnreadIndicator(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: AppDimensions.spacingSm,
      height: AppDimensions.spacingSm,
      decoration: BoxDecoration(
        color: cs.primary,
        shape: BoxShape.circle,
      ),
    );
  }

  String _getLastMessagePreview(BuildContext context) {
    if (conversation.lastMessage == null) {
      return conversation.isGroup
          ? context.l10n.conversationGroupCreated
          : context.l10n.conversationSayHi;
    }

    final message = conversation.lastMessage!;

    // For system messages, just show the content
    if (message.isSystemMessage) {
      return message.content;
    }

    // For direct conversations, don't show sender name if it's from current user
    if (!conversation.isGroup) {
      if (message.isFromCurrentUser(currentUserId)) {
        return '${context.l10n.conversationYouPrefix} ${message.displayContent}';
      } else {
        return message.displayContent;
      }
    }

    // For group conversations, show sender name unless it's from current user
    if (message.isFromCurrentUser(currentUserId)) {
      return '${context.l10n.conversationYouPrefix} ${message.displayContent}';
    } else {
      return '${message.senderDisplayName}: ${message.displayContent}';
    }
  }
}
