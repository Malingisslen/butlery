// lib/widgets/recipe/comment_form_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Form widget for posting new comments or replies on recipes.
/// Handles both top-level comments and threaded replies with visual feedback.
class CommentFormWidget extends StatelessWidget {
  final SocialRecipeViewModel socialViewModel;
  final String recipeId;
  final Function(String message, {bool isError}) onShowMessage;
  final VoidCallback? onCommentPosted;

  const CommentFormWidget({
    super.key,
    required this.socialViewModel,
    required this.recipeId,
    required this.onShowMessage,
    this.onCommentPosted,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (socialViewModel.isReplying) ...[
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingS),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.reply,
                  size: AppDimensions.iconSizeM,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: Text(
                    'Svarar på kommentar',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: socialViewModel.cancelReply,
                  icon: const Icon(
                    Icons.close,
                    size: AppDimensions.iconSizeM,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingM),
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SocialComponents.avatar(
              user: socialViewModel.currentUser,
              displayName: 'Du',
              size: ImageSize.small,
            ),
            const SizedBox(width: AppDimensions.spacingS),
            Expanded(
              child: TextField(
                onChanged: socialViewModel.updateNewCommentText,
                decoration: InputDecoration(
                  hintText: socialViewModel.isReplying
                      ? 'Skriv ditt svar...'
                      : 'Skriv en kommentar...',
                  border: OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusM),
                  ),
                  contentPadding: const EdgeInsets.all(AppDimensions.spacingS),
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingS),
            IconButton(
              onPressed: socialViewModel.newCommentText.trim().isNotEmpty &&
                      !socialViewModel.isPostingComment
                  ? () async {
                      try {
                        await socialViewModel.postComment(recipeId);
                        onShowMessage('Kommentar publicerad!');
                        onCommentPosted?.call();
                      } catch (e) {
                        onShowMessage('Kunde inte publicera kommentar',
                            isError: true);
                      }
                    }
                  : null,
              icon: socialViewModel.isPostingComment
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: SizedBox(
                        width: AppDimensions.iconSizeS,
                        height: AppDimensions.iconSizeS,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                    )
                  : const Icon(Icons.send),
              style: IconButton.styleFrom(
                backgroundColor:
                    socialViewModel.newCommentText.trim().isNotEmpty
                        ? Theme.of(context).colorScheme.primary
                        : null,
                foregroundColor:
                    socialViewModel.newCommentText.trim().isNotEmpty
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
