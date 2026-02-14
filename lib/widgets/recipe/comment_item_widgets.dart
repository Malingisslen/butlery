// lib/widgets/recipe/comment_item_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Widgets for displaying comment items in recipe detail view.
class CommentItemWidgets {
  /// Build a single comment item with header, content, and actions.
  static Widget buildCommentItem({
    required BuildContext context,
    required dynamic comment,
    required String authorDisplayName,
    required String? authorAvatarUrl,
    required String formattedTime,
    required VoidCallback onReply,
    required VoidCallback onToggleLike,
    required VoidCallback? onShowLikes,
    VoidCallback? onDelete,
    bool isOwnComment = false,
    int depth = 0,
  }) {
    final isReply = depth > 0;

    return Container(
      padding: AppDimensions.paddingAll12,
      decoration: isReply
          ? BoxDecoration(
              color: AppColors.surface
                  .withValues(alpha: AppDimensions.opacityHalf),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment header
          Row(
            children: [
              SocialAvatarComponents.avatar(
                displayName: authorDisplayName,
                imageUrl: authorAvatarUrl,
                size: ImageSize.small,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      authorDisplayName,
                      style: AppTextStyles.labelLarge,
                    ),
                    Text(
                      formattedTime,
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              // Reply button
              Semantics(
                label: context.l10n.a11yReplyToComment,
                button: true,
                child: IconButton(
                  onPressed: onReply,
                  icon: const Icon(
                    Icons.reply,
                    color: AppColors.textMedium,
                    size: AppDimensions.iconSizeM,
                  ),
                ),
              ),
              // Like button
              Semantics(
                label: comment.isLiked
                    ? context.l10n.a11yUnlikeComment
                    : context.l10n.a11yLikeComment,
                button: true,
                child: IconButton(
                  onPressed: onToggleLike,
                  icon: Icon(
                    comment.isLiked ? Icons.favorite : Icons.favorite_border,
                    color: comment.isLiked
                        ? AppColors.error
                        : AppColors.textMedium,
                    size: AppDimensions.iconSizeM,
                  ),
                ),
              ),
              // Delete button — only visible for the comment author
              if (isOwnComment && onDelete != null)
                IconButton(
                  onPressed: onDelete,
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.textMedium,
                    size: AppDimensions.iconSizeM,
                  ),
                ),
            ],
          ),

          const SizedBox(height: AppDimensions.spacingS),

          // Comment content
          Text(
            comment.text,
            style: AppTextStyles.bodyLarge,
          ),

          // Like count (tappable to show who liked)
          if (comment.likeCount > 0) ...[
            const SizedBox(height: AppDimensions.spacingS),
            GestureDetector(
              onTap: onShowLikes,
              child: Text(
                context.l10n.socialLikeCount(comment.likeCount),
                style: AppTextStyles.metadataEmphasized.copyWith(
                  color: AppColors.primary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build comment with threaded replies.
  static Widget buildCommentWithReplies({
    required dynamic comment,
    required List<dynamic> replies,
    required Widget Function(dynamic comment, int depth) commentBuilder,
    int depth = 0,
    int maxDepth = 3,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current comment
        commentBuilder(comment, depth),
        // Replies (recursive, indented, with visual threading)
        if (replies.isNotEmpty && depth < maxDepth)
          Padding(
            padding: const EdgeInsetsDirectional.only(
                start: AppDimensions.paddingXl),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.textMedium
                        .withValues(alpha: AppDimensions.opacityMediumLight),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: replies
                    .map((reply) => commentBuilder(reply, depth + 1))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  /// Build the likes dialog showing who liked a comment.
  static Widget buildLikesDialog({
    required BuildContext context,
    required int likeCount,
    required List<String> likedByUserIds,
    required String Function(String userId) getDisplayName,
    required String? Function(String userId) getAvatarUrl,
  }) {
    return Container(
      padding: AppDimensions.paddingAll16,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Padding(
            padding: AppDimensions.paddingOnlyBottom12,
            child: Text(
              context.l10n.socialLikesHeader(likeCount),
              style: AppTextStyles.headlineSmall,
            ),
          ),
          // Divider
          const Divider(),
          // List of users who liked
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: likedByUserIds.length,
              itemBuilder: (context, index) {
                final userId = likedByUserIds[index];
                final displayName = getDisplayName(userId);
                final avatarUrl = getAvatarUrl(userId);

                return ListTile(
                  key: ValueKey(userId),
                  leading: SocialAvatarComponents.avatar(
                    displayName: displayName,
                    imageUrl: avatarUrl,
                    size: ImageSize.small,
                  ),
                  title: Text(
                    displayName,
                    style: AppTextStyles.contentTitle,
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Format comment time for display.
  static String formatCommentTime(BuildContext context, DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return context.l10n.commonNow;
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${timestamp.day}/${timestamp.month}';
    }
  }
}
