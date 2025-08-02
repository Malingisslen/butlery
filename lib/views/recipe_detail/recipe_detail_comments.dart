// lib/views/recipe_detail/recipe_detail_comments.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/user_service.dart';

/// Recipe detail comments widget
///
/// This widget provides a complete comments system for recipe details including:
/// - Expandable/collapsible comments section
/// - Comment form for posting new comments
/// - Reply functionality
/// - Like/unlike functionality
/// - Loading and error states
class RecipeDetailComments extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback? onCommentPosted;

  const RecipeDetailComments({
    super.key,
    required this.recipe,
    this.onCommentPosted,
  });

  @override
  State<RecipeDetailComments> createState() => _RecipeDetailCommentsState();
}

class _RecipeDetailCommentsState extends State<RecipeDetailComments> {
  final TextEditingController _commentController = TextEditingController();
  bool _isCommentsExpanded = false;
  String? _replyingToCommentId;
  String? _replyingToUserName;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SocialRecipeViewModel>(
      builder: (context, socialViewModel, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Comments header with expand/collapse
            InkWell(
              onTap: () {
                if (mounted) {
                  setState(() {
                    _isCommentsExpanded = !_isCommentsExpanded;
                  });
                }
              },
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(AppDimensions.paddingL),
                decoration: BoxDecoration(
                  color: AppColors.cardWhite,
                  borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
                  border: Border.all(color: AppColors.divider),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.comment_outlined,
                      color: AppColors.primaryBlue,
                      size: AppDimensions.iconSizeAction,
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Kommentarer',
                            style: AppTextStyles.titleMedium,
                          ),
                          if (socialViewModel.comments.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingXs),
                            Text(
                              '${socialViewModel.comments.length} kommentarer',
                              style: AppTextStyles.titleMedium,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      _isCommentsExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppColors.textMedium,
                      size: AppDimensions.iconSizeAction,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded comments section
            if (_isCommentsExpanded) ...[
              const SizedBox(height: AppDimensions.spacingM),
              _buildCommentsSection(socialViewModel),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCommentsSection(SocialRecipeViewModel socialViewModel) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Comment form
          _buildCommentForm(socialViewModel),
          
          // Comments list
          if (socialViewModel.isLoadingComments)
            StateWidget.loading(message: 'Laddar kommentarer...')
          else if (socialViewModel.commentsError != null)
            StateWidget.error(
              message: socialViewModel.commentsError!,
            )
          else if (socialViewModel.comments.isEmpty)
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: StateWidget.empty(
                title: 'Inga kommentarer än',
                subtitle: 'Var först med att kommentera detta recept!',
                icon: Icons.comment_outlined,
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: socialViewModel.comments.length,
              separatorBuilder: (context, index) => const Divider(
                height: AppDimensions.borderWidthThin,
                color: AppColors.divider,
              ),
              itemBuilder: (context, index) {
                final comment = socialViewModel.comments[index];
                return _buildCommentItem(
                  comment,
                  socialViewModel,
                  isReply: false,
                );
              },
            ),

          // Debug info (if enabled)
          if (true) ...[
            const Divider(color: AppColors.divider),
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Info',
                    style: AppTextStyles.bodySmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXs),
                  Text(
                    'Recipe ID: ${widget.recipe.id}',
                    style: AppTextStyles.bodySmall,
                  ),
                  Text(
                    'Comments: ${socialViewModel.comments.length}',
                    style: AppTextStyles.bodySmall,
                  ),
                  Text(
                    'Loading: ${socialViewModel.isLoadingComments}',
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildCommentForm(SocialRecipeViewModel socialViewModel) {
    final currentUser = FirebaseAuthRepository().currentUser;
    
    if (currentUser == null) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: Column(
          children: [
            const Text(
              'Du måste vara inloggad för att kommentera',
              style: AppTextStyles.bodyLarge,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            FilledButton(
              onPressed: () {
                // Navigate to login
                Navigator.pushNamed(context, '/login');
              },
              child: const Text('Logga in'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        children: [
          // Reply indicator
          if (_replyingToCommentId != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.reply,
                    color: AppColors.primaryBlue,
                    size: AppDimensions.iconSizeM,
                  ),
                  const SizedBox(width: AppDimensions.spacingM),
                  Text(
                    'Svarar $_replyingToUserName',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          _replyingToCommentId = null;
                          _replyingToUserName = null;
                        });
                      }
                    },
                    icon: const Icon(
                      Icons.close,
                      color: AppColors.primaryBlue,
                      size: AppDimensions.iconSizeM,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
          ],

          // Comment input
          Row(
            children: [
              SocialComponents.avatar(
                user: null,
                size: ImageSize.small,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: _replyingToCommentId != null
                        ? 'Skriv ditt svar...'
                        : 'Skriv en kommentar...',
                    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textTertiary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                    ),
                    contentPadding: const EdgeInsets.all(AppDimensions.paddingM),
                  ),
                  style: AppTextStyles.bodyLarge,
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingM),
              IconButton(
                onPressed: socialViewModel.isPostingComment
                    ? null
                    : () => _postComment(socialViewModel),
                icon: socialViewModel.isPostingComment
                    ? const SizedBox(
                        width: AppDimensions.iconSizeAction,
                        height: AppDimensions.iconSizeAction,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.primaryBlue,
                        ),
                      )
                    : const Icon(
                        Icons.send,
                        color: AppColors.primaryBlue,
                        size: AppDimensions.iconSizeAction,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommentItem(
    dynamic comment,
    SocialRecipeViewModel socialViewModel, {
    bool isReply = false,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment header
          Row(
            children: [
              SocialComponents.avatar(
                user: comment.author,
                size: ImageSize.small,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.author?.displayName ?? 'Anonym',
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatCommentTime(comment.timestamp),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              if (!isReply) ...[
                // Reply button
                IconButton(
                  onPressed: () {
                    if (mounted) {
                      setState(() {
                        _replyingToCommentId = comment.id;
                        _replyingToUserName = comment.author?.displayName ?? 'Anonym';
                      });
                    }
                  },
                  icon: const Icon(
                    Icons.reply,
                    color: AppColors.textMedium,
                    size: AppDimensions.iconSizeM,
                  ),
                ),
              ],
              // Like button
              IconButton(
                onPressed: () => _toggleLike(comment, socialViewModel),
                icon: Icon(
                  comment.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: comment.isLiked ? AppColors.error : AppColors.textMedium,
                  size: AppDimensions.iconSizeM,
                ),
              ),
            ],
          ),
          
          const SizedBox(height: AppDimensions.spacingM),
          
          // Comment content
          Text(
            comment.content,
            style: AppTextStyles.bodyLarge,
          ),
          
          // Like count
          if (comment.likeCount > 0) ...[
            const SizedBox(height: AppDimensions.spacingM),
            Text(
              '${comment.likeCount} ${comment.likeCount == 1 ? 'gilla-markering' : 'gilla-markeringar'}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMedium,
              ),
            ),
          ],
          
          // Replies
          if (comment.replies != null && comment.replies.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingM),
            Container(
              margin: const EdgeInsets.only(left: AppDimensions.spacingL),
              child: Column(
                children: comment.replies.map<Widget>((reply) {
                  return Column(
                    children: [
                      _buildCommentItem(reply, socialViewModel, isReply: true),
                      if (reply != comment.replies.last)
                        const Divider(
                          height: AppDimensions.borderWidthThin,
                          color: AppColors.divider,
                        ),
                    ],
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Post a comment or reply
  Future<void> _postComment(SocialRecipeViewModel socialViewModel) async {
    final commentText = _commentController.text.trim();
    if (commentText.isEmpty) {
      return;
    }

    final userService = ServiceLocator.get<UserService>();
    final currentUser = FirebaseAuthRepository().currentUser;

    if (currentUser == null) {
      _showSnackBarSafely(
        'Du måste vara inloggad för att kommentera',
        backgroundColor: AppColors.error,
      );
      return;
    }

    try {
      // Get user profile
      final userProfile = await userService.getUserProfile(currentUser.uid);
      if (userProfile == null) {
        _showSnackBarSafely(
          'Kunde inte hämta användardata',
          backgroundColor: AppColors.error,
        );
        return;
      }

      // Post comment or reply
      if (_replyingToCommentId != null) {
        await socialViewModel.postComment(widget.recipe.id);
      } else {
        await socialViewModel.postComment(widget.recipe.id);
      }

      // Clear form
      _commentController.clear();
      if (mounted) {
        setState(() {
          _replyingToCommentId = null;
          _replyingToUserName = null;
        });
      }

      _showSnackBarSafely(
        'Kommentar postad',
        backgroundColor: AppColors.success,
      );

      // Callback
      widget.onCommentPosted?.call();
    } catch (e) {
      _showSnackBarSafely(
        'Kunde inte posta kommentar',
        backgroundColor: AppColors.error,
      );
    }
  }

  /// Toggle like on comment
  Future<void> _toggleLike(
    dynamic comment,
    SocialRecipeViewModel socialViewModel,
  ) async {
    final currentUser = FirebaseAuthRepository().currentUser;
    if (currentUser == null) {
      _showSnackBarSafely(
        'Du måste vara inloggad för att gilla kommentarer',
        backgroundColor: AppColors.error,
      );
      return;
    }

    try {
      await socialViewModel.toggleCommentLike(comment.id);
    } catch (e) {
      _showSnackBarSafely(
        'Kunde inte uppdatera gilla-markering',
        backgroundColor: AppColors.error,
      );
    }
  }

  /// Format comment time for display
  String _formatCommentTime(DateTime timestamp) {
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

  /// Show snackbar safely with context check
  void _showSnackBarSafely(
    String message, {
    Color? backgroundColor,
    Duration duration = const Duration(seconds: 2),
  }) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor ?? AppColors.success,
          duration: duration,
        ),
      );
    }
  }
}