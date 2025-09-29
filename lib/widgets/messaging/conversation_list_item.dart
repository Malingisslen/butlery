// lib/widgets/messaging/conversation_list_item.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/conversation.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/image/image_config.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// List item widget for displaying conversation in conversations list
/// 
/// Provides comprehensive conversation preview including:
/// - User/group avatar with appropriate fallbacks
/// - Conversation title and last message preview
/// - Timestamp of last activity
/// - Unread message indicator
/// - Online status for direct conversations
/// - Proper Swedish localization
class ConversationListItem extends StatelessWidget {
  final Conversation conversation;
  final String currentUserId;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool showOnlineStatus;

  const ConversationListItem({
    super.key,
    required this.conversation,
    required this.currentUserId,
    this.onTap,
    this.onLongPress,
    this.showOnlineStatus = false,
  });

  bool get _hasUnreadMessages => conversation.hasUnreadMessages(currentUserId);

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingM,
          vertical: AppDimensions.paddingS,
        ),
        child: Row(
          children: [
            // Avatar
            _buildAvatar(),
            
            const SizedBox(width: AppDimensions.paddingM),
            
            // Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Title and timestamp row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          conversation.getDisplayTitle(currentUserId),
                          style: _hasUnreadMessages
                              ? AppTextStyles.bodyMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textDark,
                                )
                              : AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.textDark,
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      const SizedBox(width: AppDimensions.paddingS),
                      
                      Text(
                        conversation.formattedLastActivity,
                        style: AppTextStyles.labelSmall.copyWith(
                          color: _hasUnreadMessages
                              ? AppColors.primaryBlue
                              : AppColors.textMedium,
                          fontWeight: _hasUnreadMessages
                              ? FontWeight.w500
                              : FontWeight.normal,
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: AppDimensions.spacing2),
                  
                  // Last message and unread indicator row
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _getLastMessagePreview(),
                          style: _hasUnreadMessages
                              ? AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textDark,
                                  fontWeight: FontWeight.w500,
                                )
                              : AppTextStyles.labelSmall.copyWith(
                                  color: AppColors.textMedium,
                                ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      
                      if (_hasUnreadMessages) ...[
                        const SizedBox(width: AppDimensions.paddingS),
                        _buildUnreadIndicator(),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    return Stack(
      children: [
        Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: AppColors.accent.withValues(alpha: 0.2),
          ),
          child: conversation.isGroup
              ? _buildGroupAvatar()
              : _buildDirectConversationAvatar(),
        ),
        
        // Online status indicator (only for direct conversations)
        if (!conversation.isGroup && showOnlineStatus)
          Positioned(
            bottom: AppDimensions.spacing2,
            right: AppDimensions.spacing2,
            child: Container(
              width: 16,
              height: 16,
              decoration: BoxDecoration(
                color: AppColors.success,
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.cardWhite,
                  width: 2,
                ),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildGroupAvatar() {
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
      ),
      child: const Icon(
        Icons.group,
        color: AppColors.primaryBlue,
        size: AppDimensions.iconSizeL,
      ),
    );
  }

  Widget _buildDirectConversationAvatar() {
    final avatarUrl = conversation.getDisplayAvatarUrl(currentUserId);
    final displayName = conversation.getDisplayTitle(currentUserId);
    
    if (avatarUrl != null && avatarUrl.isNotEmpty) {
      return SimpleImageWidget(
        imageUrl: avatarUrl,
        config: ImageConfig.avatar(
          size: ImageSize.custom,
        ),
        placeholder: _buildAvatarFallback(displayName),
      );
    }
    
    return _buildAvatarFallback(displayName);
  }

  Widget _buildAvatarFallback(String displayName) {
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: AppTextStyles.headlineSmall.copyWith(
          color: AppColors.primaryBlue,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Widget _buildUnreadIndicator() {
    return Container(
      width: AppDimensions.spacingSm,
      height: AppDimensions.spacingSm,
      decoration: const BoxDecoration(
        color: AppColors.primaryBlue,
        shape: BoxShape.circle,
      ),
    );
  }

  String _getLastMessagePreview() {
    if (conversation.lastMessage == null) {
      return conversation.isGroup 
          ? 'Grupp skapad'
          : 'Säg hej!';
    }

    final message = conversation.lastMessage!;
    
    // For system messages, just show the content
    if (message.isSystemMessage) {
      return message.content;
    }

    // For direct conversations, don't show sender name if it's from current user
    if (!conversation.isGroup) {
      if (message.isFromCurrentUser(currentUserId)) {
        return 'Du: ${message.displayContent}';
      } else {
        return message.displayContent;
      }
    }

    // For group conversations, show sender name unless it's from current user
    if (message.isFromCurrentUser(currentUserId)) {
      return 'Du: ${message.displayContent}';
    } else {
      return '${message.senderDisplayName}: ${message.displayContent}';
    }
  }
}