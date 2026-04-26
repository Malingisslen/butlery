// lib/widgets/recipe/comment_item_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/recipe/comment_time_formatter.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Widget for displaying individual comment items with threaded replies.
/// Supports likes, replies, and recursive nesting for conversation threads.
class CommentItemWidget extends StatelessWidget {
  final SocialRecipeViewModel socialViewModel;
  final dynamic comment;

  const CommentItemWidget({
    super.key,
    required this.socialViewModel,
    required this.comment,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: Container(
        margin: AppDimensions.paddingOnlyBottom3,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SocialAvatarComponents.avatar(
                  displayName:
                      socialViewModel.getAuthorDisplayName(comment.authorId),
                  imageUrl:
                      socialViewModel.getAuthorAvatarUrl(comment.authorId),
                  size: ImageSize.small,
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            socialViewModel
                                .getAuthorDisplayName(comment.authorId),
                            style: AppTextStyles.labelLarge,
                          ),
                          const SizedBox(width: AppDimensions.spacingS),
                          Text(
                            CommentTimeFormatter.format(comment.createdAt),
                            style: AppTextStyles.bodySmall,
                          ),
                        ],
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        comment.text,
                        style: AppTextStyles.bodyMedium,
                      ),
                      const SizedBox(height: AppDimensions.spacingXs),
                      Row(
                        children: [
                          _buildLikeButton(context),
                          _buildReplyButton(context),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            ..._buildReplies(context),
          ],
        ),
      ),
    );
  }

  Widget _buildLikeButton(BuildContext context) {
    return Semantics(
      label: context.l10n.a11yCommentLikeAction,
      button: true,
      child: InkWell(
        onTap: () => socialViewModel.toggleCommentLike(comment.id),
        child: Padding(
          padding: AppDimensions.paddingSymmetric4x3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                socialViewModel.hasLikedComment(comment.id)
                    ? Icons.favorite
                    : Icons.favorite_border,
                size: AppDimensions.iconSizeM,
                color: socialViewModel.hasLikedComment(comment.id)
                    ? Theme.of(context).colorScheme.error
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              if (comment.likeCount > 0) ...[
                const SizedBox(width: AppDimensions.spacingXs),
                Text(
                  '${comment.likeCount}',
                  style: AppTextStyles.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReplyButton(BuildContext context) {
    return Semantics(
      label: context.l10n.a11yCommentReplyAction,
      button: true,
      child: InkWell(
        onTap: () => socialViewModel.setReplyTo(comment.id),
        child: Padding(
          padding: AppDimensions.paddingSymmetric4x3,
          child: Text(
            context.l10n.commentReply,
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
      ),
    );
  }

  List<Widget> _buildReplies(BuildContext context) {
    return socialViewModel.getReplies(comment.id).map((reply) {
      return Padding(
        padding:
            const EdgeInsetsDirectional.only(start: AppDimensions.spacingL),
        child: CommentItemWidget(
          socialViewModel: socialViewModel,
          comment: reply,
        ),
      );
    }).toList();
  }
}
