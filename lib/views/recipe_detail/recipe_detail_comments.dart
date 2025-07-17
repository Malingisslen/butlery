// lib/views/recipe_detail/recipe_detail_comments.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../repositories/firebase/firebase_auth_repository.dart';
import '../../models/recipe.dart';
import '../../viewmodels/social_recipe_viewmodel.dart';
import '../../widgets/common/social_components.dart';
import '../../widgets/common/state_widget.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../services/user_service.dart';

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
                setState(() {
                  _isCommentsExpanded = !_isCommentsExpanded;
                });
              },
              child: Container(
                width: double.infinity,
                padding: AppTheme.cardPadding,
                decoration: BoxDecoration(
                  color: AppTheme.cardColor,
                  borderRadius: AppTheme.cardBorderRadius,
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.comment_outlined,
                      color: AppTheme.primaryColor,
                      size: AppTheme.iconSizeAction,
                    ),
                    AppTheme.smallHorizontalGap,
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Kommentarer',
                            style: AppTheme.cardTitleStyle,
                          ),
                          if (socialViewModel.comments.isNotEmpty) ...[
                            AppTheme.tinyGap,
                            Text(
                              '${socialViewModel.comments.length} kommentarer',
                              style: AppTheme.subtitleStyle,
                            ),
                          ],
                        ],
                      ),
                    ),
                    Icon(
                      _isCommentsExpanded
                          ? Icons.keyboard_arrow_up
                          : Icons.keyboard_arrow_down,
                      color: AppTheme.textSecondary,
                      size: AppTheme.iconSizeAction,
                    ),
                  ],
                ),
              ),
            ),

            // Expanded comments section
            if (_isCommentsExpanded) ...[
              AppTheme.smallGap,
              _buildCommentsSection(socialViewModel),
            ],
          ],
        );
      },
    );
  }

  Widget _buildCommentsSection(SocialRecipeViewModel socialViewModel) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: AppTheme.cardBorderRadius,
        border: Border.all(color: AppTheme.dividerColor),
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
              padding: AppTheme.cardPadding,
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
              separatorBuilder: (context, index) => Divider(
                height: AppTheme.dividerHeight,
                color: AppTheme.dividerColor,
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
            Divider(color: AppTheme.dividerColor),
            Container(
              padding: AppTheme.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Debug Info',
                    style: AppTheme.captionStyle.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  AppTheme.tinyGap,
                  Text(
                    'Recipe ID: ${widget.recipe.id}',
                    style: AppTheme.captionStyle,
                  ),
                  Text(
                    'Comments: ${socialViewModel.comments.length}',
                    style: AppTheme.captionStyle,
                  ),
                  Text(
                    'Loading: ${socialViewModel.isLoadingComments}',
                    style: AppTheme.captionStyle,
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
        padding: AppTheme.cardPadding,
        child: Column(
          children: [
            Text(
              'Du måste vara inloggad för att kommentera',
              style: AppTheme.bodyStyle,
              textAlign: TextAlign.center,
            ),
            AppTheme.smallGap,
            FilledButton(
              onPressed: () {
                // Navigate to login
                Navigator.pushNamed(context, '/login');
              },
              child: Text('Logga in'),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: AppTheme.cardPadding,
      child: Column(
        children: [
          // Reply indicator
          if (_replyingToCommentId != null) ...[
            Container(
              width: double.infinity,
              padding: AppTheme.cardPadding,
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.1),
                borderRadius: AppTheme.mediumRadius,
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.reply,
                    color: AppTheme.primaryColor,
                    size: AppTheme.iconSizeInfo,
                  ),
                  AppTheme.smallHorizontalGap,
                  Text(
                    'Svarar $_replyingToUserName',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.primaryColor,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      setState(() {
                        _replyingToCommentId = null;
                        _replyingToUserName = null;
                      });
                    },
                    icon: Icon(
                      Icons.close,
                      color: AppTheme.primaryColor,
                      size: AppTheme.iconSizeInfo,
                    ),
                  ),
                ],
              ),
            ),
            AppTheme.smallGap,
          ],

          // Comment input
          Row(
            children: [
              SocialComponents.avatar(
                user: null,
                size: ImageSize.small,
              ),
              AppTheme.smallHorizontalGap,
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: _replyingToCommentId != null
                        ? 'Skriv ditt svar...'
                        : 'Skriv en kommentar...',
                    hintStyle: AppTheme.inputHintStyle,
                    border: OutlineInputBorder(
                      borderRadius: AppTheme.mediumRadius,
                    ),
                    contentPadding: AppTheme.inputPadding,
                  ),
                  style: AppTheme.bodyStyle,
                  maxLines: 3,
                  minLines: 1,
                ),
              ),
              AppTheme.smallHorizontalGap,
              IconButton(
                onPressed: socialViewModel.isPostingComment
                    ? null
                    : () => _postComment(socialViewModel),
                icon: socialViewModel.isPostingComment
                    ? SizedBox(
                        width: AppTheme.iconSizeAction,
                        height: AppTheme.iconSizeAction,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.primaryColor,
                        ),
                      )
                    : Icon(
                        Icons.send,
                        color: AppTheme.primaryColor,
                        size: AppTheme.iconSizeAction,
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
      padding: AppTheme.cardPadding,
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
              AppTheme.smallHorizontalGap,
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      comment.author?.displayName ?? 'Anonym',
                      style: AppTheme.captionStyle.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatCommentTime(comment.timestamp),
                      style: AppTheme.captionStyle,
                    ),
                  ],
                ),
              ),
              if (!isReply) ...[
                // Reply button
                IconButton(
                  onPressed: () {
                    setState(() {
                      _replyingToCommentId = comment.id;
                      _replyingToUserName = comment.author?.displayName ?? 'Anonym';
                    });
                  },
                  icon: Icon(
                    Icons.reply,
                    color: AppTheme.textSecondary,
                    size: AppTheme.iconSizeInfo,
                  ),
                ),
              ],
              // Like button
              IconButton(
                onPressed: () => _toggleLike(comment, socialViewModel),
                icon: Icon(
                  comment.isLiked ? Icons.favorite : Icons.favorite_border,
                  color: comment.isLiked ? AppTheme.errorColor : AppTheme.textSecondary,
                  size: AppTheme.iconSizeInfo,
                ),
              ),
            ],
          ),
          
          AppTheme.smallGap,
          
          // Comment content
          Text(
            comment.content,
            style: AppTheme.bodyStyle,
          ),
          
          // Like count
          if (comment.likeCount > 0) ...[
            AppTheme.smallGap,
            Text(
              '${comment.likeCount} ${comment.likeCount == 1 ? 'gilla-markering' : 'gilla-markeringar'}',
              style: AppTheme.captionStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
            ),
          ],
          
          // Replies
          if (comment.replies != null && comment.replies.isNotEmpty) ...[
            AppTheme.smallGap,
            Container(
              margin: EdgeInsets.only(left: AppTheme.spacingMd),
              child: Column(
                children: comment.replies.map<Widget>((reply) {
                  return Column(
                    children: [
                      _buildCommentItem(reply, socialViewModel, isReply: true),
                      if (reply != comment.replies.last)
                        Divider(
                          height: AppTheme.dividerHeight,
                          color: AppTheme.dividerColor,
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
    if (commentText.isEmpty) return;

    final userService = sl<UserService>();
    final currentUser = FirebaseAuthRepository().currentUser;

    if (currentUser == null) {
      _showSnackBarSafely(
        'Du måste vara inloggad för att kommentera',
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    try {
      // Get user profile
      final userProfile = await userService.getUserProfile(currentUser.uid);
      if (userProfile == null) {
        _showSnackBarSafely(
          'Kunde inte hämta användardata',
          backgroundColor: AppTheme.errorColor,
        );
        return;
      }

      // Post comment or reply
      if (_replyingToCommentId != null) {
        await socialViewModel.postComment();
      } else {
        await socialViewModel.postComment();
      }

      // Clear form
      _commentController.clear();
      setState(() {
        _replyingToCommentId = null;
        _replyingToUserName = null;
      });

      _showSnackBarSafely(
        'Kommentar postad',
        backgroundColor: AppTheme.successColor,
      );

      // Callback
      widget.onCommentPosted?.call();
    } catch (e) {
      _showSnackBarSafely(
        'Kunde inte posta kommentar',
        backgroundColor: AppTheme.errorColor,
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
        backgroundColor: AppTheme.errorColor,
      );
      return;
    }

    try {
      await socialViewModel.toggleCommentLike(comment.id);
    } catch (e) {
      _showSnackBarSafely(
        'Kunde inte uppdatera gilla-markering',
        backgroundColor: AppTheme.errorColor,
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
          backgroundColor: backgroundColor ?? AppTheme.successColor,
          duration: duration,
        ),
      );
    }
  }
}