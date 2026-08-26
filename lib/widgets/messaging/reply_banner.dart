// lib/widgets/messaging/reply_banner.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

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
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingM,
        vertical: AppDimensions.paddingS,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: BorderSide(
            color: context.butleryColors.success,
            width: 4,
          ),
        ),
      ),
      child: Row(
        children: [
          // Reply icon
          Icon(
            Icons.reply,
            size: AppDimensions.iconSizeM,
            color: context.butleryColors.success,
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
                  context.l10n.messagingReplyingTo(message.senderDisplayName),
                  style: AppTextStyles.metadataEmphasized.copyWith(
                    color: context.butleryColors.success,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppDimensions.spacingXxs),

                // Original message content
                Text(
                  _getMessagePreview(context),
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.onSurfaceVariant,
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
            color: cs.onSurfaceVariant,
            constraints: const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            padding: EdgeInsets.zero,
            tooltip: context.l10n.messagingCancelReply,
          ),
        ],
      ),
    );
  }

  String _getMessagePreview(BuildContext context) {
    switch (message.type) {
      case MessageType.text:
        return message.content;
      case MessageType.image:
        // Caption is in content for image messages
        return message.content.isNotEmpty
            ? '📷 ${message.content}'
            : context.l10n.messagingImagePreview;
      case MessageType.recipeShare:
        // Recipe title is in metadata
        final title = message.metadata?['recipeTitle'] as String?;
        return context.l10n.messagingRecipePreview(
          title ?? context.l10n.recipeRecipe,
        );
      case MessageType.duplicateBlocked:
        // BUT-1904. Named rather than left to the `default` below, which would
        // preview a guard-written row as an empty string — and a client-stamped
        // one as the very text the mark exists to remove.
        //
        // Both routes to a reply target are closed for such a row today — the
        // swipe gesture and the long-press menu both sit below `MessageBubble`'s
        // early return — so this is defence rather than a live path. Do not
        // reduce that to "the swipe is unreachable": the menu is the half that
        // would come back first if the long-press gap is ever fixed.
        return context.l10n.chatDuplicateBlocked;
      default:
        return message.content;
    }
  }
}
