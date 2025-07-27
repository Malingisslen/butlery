// lib/widgets/recipe/recipe_detail_comments.dart

import 'package:flutter/material.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/injection.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Standalone widget for displaying and managing recipe comments
class RecipeDetailComments extends StatefulWidget {
  final SocialRecipeViewModel socialViewModel;
  final VoidCallback? onCommentPosted;

  const RecipeDetailComments({
    super.key,
    required this.socialViewModel,
    this.onCommentPosted,
  });

  @override
  State<RecipeDetailComments> createState() => _RecipeDetailCommentsState();
}

class _RecipeDetailCommentsState extends State<RecipeDetailComments> {
  bool _isCommentsExpanded = false;

  // Helper method for safe snackbar display
  void _showSnackBarSafely(String message, {bool isError = false}) {
    if (mounted) {
      if (isError) {
        SnackBarUtils.showError(context, message);
      } else {
        SnackBarUtils.showSuccess(context, message);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: AppColors.backgroundTint,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header with expand/collapse
          InkWell(
            onTap: () {
              setState(() {
                _isCommentsExpanded = !_isCommentsExpanded;
              });

              // Load comments when expanding for the first time
              if (_isCommentsExpanded && !widget.socialViewModel.hasComments) {
                widget.socialViewModel.refreshComments();
              }
            },
            child: Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Row(
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: AppDimensions.iconSizeAction,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Text(
                      widget.socialViewModel.hasComments
                          ? 'Kommentarer (${widget.socialViewModel.comments.length})'
                          : 'Kommentarer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  if (widget.socialViewModel.friends.isNotEmpty)
                    Icon(
                      _isCommentsExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),

          // Expandable comment content
          if (_isCommentsExpanded) ...[
            Divider(height: 1, color: Theme.of(context).colorScheme.outline),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Comments list
                  if (widget.socialViewModel.isLoadingComments)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppDimensions.spacingL),
                        child: Column(
                          children: [
                            SizedBox(
                              width: AppDimensions.iconSizeS,
                              height: AppDimensions.iconSizeS,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                            SizedBox(height: AppDimensions.spacingM),
                            Text(
                              'Laddar kommentarer...',
                              style: AppTextStyles.bodySmall,
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (widget.socialViewModel.commentsError != null)
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingL),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: AppColors.error),
                          const SizedBox(width: AppDimensions.spacingS),
                          Expanded(
                            child: Text(
                              widget.socialViewModel.commentsError!,
                              style: const TextStyle(color: AppColors.error),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!widget.socialViewModel.hasComments)
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingL * 2),
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: AppDimensions.iconSizeAction,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),
                          Text(
                            'Inga kommentarer än',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.spacingM),
                          const Text(
                            'Bli först att kommentera detta recept!',
                            style: AppTextStyles.bodySmall,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...widget.socialViewModel.topLevelComments.map((comment) =>
                        _buildCommentItem(context, widget.socialViewModel, comment)),

                  const SizedBox(height: AppDimensions.spacingXl),

                  // DEBUG INFO + CREATE PROFILE
                  Builder(
                    builder: (context) {
                      final userService = sl<UserService>();
                      final authUser = FirebaseAuthRepository().currentUser;

                      return Container(
                        padding: const EdgeInsets.all(AppDimensions.spacingS),
                        color: AppColors.warning.withValues(alpha: 0.1),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('🔍 DEBUG INFO:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                                'SocialViewModel.currentUser: ${widget.socialViewModel.currentUser?.displayName ?? "NULL"}'),
                            Text(
                                'UserService.currentUserProfile: ${userService.currentUserProfile?.displayName ?? "NULL"}'),
                            Text(
                                'FirebaseAuth.currentUser: ${authUser?.email ?? "NULL"}'),
                            Text(
                                'UserService loading: ${userService.isLoading}'),
                            Text(
                                'UserService error: ${userService.error ?? "none"}'),

                            const SizedBox(height: AppDimensions.spacingM),

                            // Create profile button
                            if (authUser != null &&
                                userService.currentUserProfile == null)
                              ElevatedButton(
                                onPressed: () async {
                                  final displayName = authUser.displayName ??
                                      authUser.email!.split('@')[0];

                                  final profile =
                                      await userService.createOrUpdateProfile(
                                    displayName: displayName,
                                    isSearchable: true,
                                    allowEmailSearch: false,
                                  );

                                  if (profile != null) {
                                    _showSnackBarSafely(
                                        'Profil skapad! Starta om appen.');
                                  }
                                },
                                child: const Text('Skapa Profil'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: AppDimensions.spacingM),

                  // Comment form (for all logged-in users)
                  if (widget.socialViewModel.currentUser != null)
                    _buildCommentForm(context, widget.socialViewModel)
                  else
                    Container(
                      padding: const EdgeInsets.all(AppDimensions.spacingL),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            size: AppDimensions.iconSizeAction,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: AppDimensions.spacingM),
                          Text(
                            'Skapa profil för att kommentera',
                            style: Theme.of(context).textTheme.titleSmall,
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AppDimensions.spacingM),
                          FilledButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/profile/edit'),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Skapa profil'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Builds the comment form for posting new comments
  Widget _buildCommentForm(
      BuildContext context, SocialRecipeViewModel socialViewModel) {
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
              displayName: 'Du', // fallback if user is null
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
                    borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
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
                      final success = await socialViewModel.postComment();
                      if (success) {
                        _showSnackBarSafely('Kommentar publicerad!');
                        widget.onCommentPosted?.call();
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

  /// Builds individual comment items with replies
  Widget _buildCommentItem(
    BuildContext context,
    SocialRecipeViewModel socialViewModel,
    dynamic comment,
  ) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingS),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SocialComponents.avatar(
                displayName: socialViewModel.getAuthorDisplayName(comment),
                imageUrl: socialViewModel.getAuthorAvatarUrl(comment),
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
                          socialViewModel.getAuthorDisplayName(comment),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        const SizedBox(width: AppDimensions.spacingS),
                        Text(
                          _formatCommentTime(comment.createdAt),
                          style: AppTextStyles.bodySmall,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      comment.text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Row(
                      children: [
                        // Like button
                        InkWell(
                          onTap: () =>
                              socialViewModel.toggleCommentLike(comment.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDimensions.spacingXs,
                              horizontal: AppDimensions.spacingS,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  socialViewModel.hasLikedComment(comment)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: AppDimensions.iconSizeM,
                                  color:
                                      socialViewModel.hasLikedComment(comment)
                                          ? AppColors.error
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
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
                        // Reply button
                        InkWell(
                          onTap: () => socialViewModel.setReplyTo(comment.id),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              vertical: AppDimensions.spacingXs,
                              horizontal: AppDimensions.spacingS,
                            ),
                            child: Text(
                              'Svara',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Replies to the comment
          ...socialViewModel.getReplies(comment.id).map((reply) => Padding(
                padding: const EdgeInsets.only(left: AppDimensions.spacingL),
                child: _buildCommentItem(context, socialViewModel, reply),
              )),
        ],
      ),
    );
  }

  /// Formats comment timestamp for display
  String _formatCommentTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}