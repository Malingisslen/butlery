// lib/widgets/messaging/components/system_message_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Widget for displaying system messages in chat.
class SystemMessageWidget extends StatelessWidget {
  final String content;

  const SystemMessageWidget({super.key, required this.content});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingS,
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.paddingM,
            vertical: AppDimensions.paddingS,
          ),
          decoration: BoxDecoration(
            color: cs.outline.withValues(alpha: AppDimensions.opacityVeryLight),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          ),
          child: Text(
            content,
            style: AppTextStyles.labelSmall.copyWith(
              color: cs.onSurfaceVariant,
              fontStyle: FontStyle.italic,
            ),
            textAlign: TextAlign.center,
          ),
        ),
      ),
    );
  }
}

/// Widget for displaying reply preview in message bubble.
class ReplyPreviewWidget extends StatelessWidget {
  final String senderName;
  final String content;
  final bool isFromCurrentUser;

  const ReplyPreviewWidget({
    super.key,
    required this.senderName,
    required this.content,
    required this.isFromCurrentUser,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingS),
      margin: const EdgeInsets.only(bottom: AppDimensions.paddingS),
      decoration: BoxDecoration(
        color: (isFromCurrentUser ? cs.surfaceContainerHighest : cs.secondary)
            .withValues(alpha: AppDimensions.opacityLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        border: Border(
          left: BorderSide(color: cs.secondary, width: 3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            senderName,
            style: AppTextStyles.labelMedium.copyWith(
              color: isFromCurrentUser
                  ? cs.surfaceContainerHighest
                      .withValues(alpha: AppDimensions.opacityVeryDark)
                  : cs.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXxs),
          Text(
            content,
            style: AppTextStyles.labelSmall.copyWith(
              color: isFromCurrentUser
                  ? cs.surfaceContainerHighest
                      .withValues(alpha: AppDimensions.opacityDark)
                  : cs.onSurfaceVariant,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

/// Widget for displaying message avatar.
class MessageAvatarWidget extends StatelessWidget {
  final String displayName;
  final String? avatarUrl;
  final Widget? avatarImage;

  const MessageAvatarWidget({
    super.key,
    required this.displayName,
    this.avatarUrl,
    this.avatarImage,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: cs.secondary.withValues(alpha: AppDimensions.opacityLight),
      ),
      child: avatarImage ?? _buildFallback(cs),
    );
  }

  Widget _buildFallback(ColorScheme cs) {
    return Center(
      child: Text(
        displayName.isNotEmpty ? displayName[0].toUpperCase() : '?',
        style: AppTextStyles.labelMedium.copyWith(color: cs.primary),
      ),
    );
  }
}
