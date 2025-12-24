// lib/widgets/messaging/reply_banner.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Banner shown above chat input when replying to a message.
/// Displays the original message content and sender, with a close button
/// to cancel the reply. Styled to match the app's design system.
/// **Usage:**
/// ```dart
/// if (replyToMessage != null)
///   ReplyBanner(
///     message: replyToMessage,
///     onCancelReply: () => viewModel.clearReplyToMessage(),
///   ),
/// ```
class ReplyBanner extends StatelessWidget {
  final Message message;
  final VoidCallback onCancelReply;

  const ReplyBanner({
    super.key,
    required this.message,
    required this.onCancelReply,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: const BoxDecoration(
        color: AppColors.backgroundLight,
        border: Border(
          left: BorderSide(
            color: AppColors.success,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          // Reply icon
          const Icon(
            Icons.reply,
            size: 20,
            color: AppColors.success,
          ),
          const SizedBox(width: AppDimensions.spacingS),

          // Message preview content
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                // Sender name
                Text(
                  'Svarar till ${message.senderDisplayName}',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.success,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),

                // Original message content
                Text(
                  _getMessagePreview(),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textSecondary,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),

          // Cancel button
          IconButton(
            onPressed: onCancelReply,
            icon: const Icon(Icons.close),
            iconSize: 20,
            color: AppColors.textSecondary,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
            tooltip: 'Avbryt svar',
          ),
        ],
      ),
    );
  }

  String _getMessagePreview() {
    switch (message.type) {
      case MessageType.text:
        return message.content;
      case MessageType.image:
        // Caption is in content for image messages
        return message.content.isNotEmpty ? '📷 ${message.content}' : '📷 Bild';
      case MessageType.recipeShare:
        // Recipe title is in metadata
        final title = message.metadata?['recipeTitle'] as String?;
        return '🍳 ${title ?? "Recept"}';
      default:
        return message.content;
    }
  }
}
