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
    required dynamic comment,
    required String authorDisplayName,
    required String? authorAvatarUrl,
    required String formattedTime,
    required VoidCallback onReply,
    required VoidCallback onToggleLike,
    required VoidCallback? onShowLikes,
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
                label: 'Svara på kommentar',
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
                    ? 'Ta bort gilla-markering'
                    : 'Gilla kommentar',
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
                '${comment.likeCount} ${comment.likeCount == 1 ? 'gilla-markering' : 'gilla-markeringar'}',
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
              'Gilla-markeringar ($likeCount)',
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
  static String formatCommentTime(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'nu';
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
