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

/// Consolidated state class for RecipeDetailComments to reduce setState calls
class CommentsState {
  final bool isCommentsExpanded;
  final String? replyingToCommentId;
  final String? replyingToUserName;
  final bool isInitialized;

  const CommentsState({
    this.isCommentsExpanded = false,
    this.replyingToCommentId,
    this.replyingToUserName,
    this.isInitialized = false,
  });

  CommentsState copyWith({
    bool? isCommentsExpanded,
    String? replyingToCommentId,
    String? replyingToUserName,
    bool? isInitialized,
  }) {
    return CommentsState(
      isCommentsExpanded: isCommentsExpanded ?? this.isCommentsExpanded,
      replyingToCommentId: replyingToCommentId,
      replyingToUserName: replyingToUserName,
      isInitialized: isInitialized ?? this.isInitialized,
    );
  }
}

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
  CommentsState _state = const CommentsState();

  @override
  void initState() {
    super.initState();
    // Initialize comments when widget mounts
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initializeComments();
    });
  }

  /// Initialize SocialRecipeViewModel and load comments
  Future<void> _initializeComments() async {
    if (!mounted || _state.isInitialized) return;

    setState(() {
      _state = _state.copyWith(isInitialized: true);
    });
    final socialViewModel =
        Provider.of<SocialRecipeViewModel>(context, listen: false);

    // Initialize viewmodel with current user and friends
    await socialViewModel.initialize();

    // Load comments for this recipe
    await socialViewModel.refreshComments(widget.recipe.id);
  }

  SocialRecipeViewModel? _socialViewModel;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Save reference to ViewModel for safe disposal
    _socialViewModel ??= Provider.of<SocialRecipeViewModel>(context, listen: false);
  }

  @override
  void dispose() {
    // Stop watching comments before disposing (use saved reference)
    _socialViewModel?.stopWatchingComments();
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
                    _state = _state.copyWith(isCommentsExpanded: !_state.isCommentsExpanded);
                  });

                  // Start or stop real-time comment streaming based on expansion
                  if (_state.isCommentsExpanded) {
                    // Start watching for real-time updates
                    socialViewModel.startWatchingComments(widget.recipe.id);
                  } else {
                    // Stop watching to save resources
                    socialViewModel.stopWatchingComments();
                  }
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
                      _state.isCommentsExpanded
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
            if (_state.isCommentsExpanded) ...[
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
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.paddingS,
              ),
              itemCount: socialViewModel.topLevelComments.length,
              separatorBuilder: (context, index) => const Divider(
                height: AppDimensions.borderWidthThin,
                color: AppColors.divider,
              ),
              itemBuilder: (context, index) {
                final comment = socialViewModel.topLevelComments[index];
                return _buildCommentWithReplies(
                  comment,
                  socialViewModel,
                );
              },
            ),
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
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      child: Column(
        children: [
          // Reply indicator
          if (_state.replyingToCommentId != null) ...[
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
                    'Svarar ${_state.replyingToUserName}',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.primaryBlue,
                    ),
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      if (mounted) {
                        setState(() {
                          _state = _state.copyWith(
                            replyingToCommentId: null,
                            replyingToUserName: null,
                          );
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
              Expanded(
                child: TextField(
                  controller: _commentController,
                  decoration: InputDecoration(
                    hintText: _state.replyingToCommentId != null
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

  /// Get author display name from authorId
  String _getAuthorDisplayName(
    String authorId,
    SocialRecipeViewModel socialViewModel,
  ) {
    // Check if current user
    if (socialViewModel.currentUser?.uid == authorId) {
      return socialViewModel.currentUser?.displayName ?? 'Du';
    }

    // Look up in friends list
    try {
      final friend = socialViewModel.friends.firstWhere(
        (f) => f.uid == authorId,
      );
      return friend.displayName;
    } catch (e) {
      return 'Användare';
    }
  }

  /// Get author avatar URL from authorId
  String? _getAuthorAvatarUrl(
    String authorId,
    SocialRecipeViewModel socialViewModel,
  ) {
    // Check if current user
    if (socialViewModel.currentUser?.uid == authorId) {
      return socialViewModel.currentUser?.avatarUrl;
    }

    // Look up in friends list
    try {
      final friend = socialViewModel.friends.firstWhere(
        (f) => f.uid == authorId,
      );
      return friend.avatarUrl;
    } catch (e) {
      return null;
    }
  }

  Widget _buildCommentWithReplies(
    dynamic comment,
    SocialRecipeViewModel socialViewModel, {
    int depth = 0,
    int maxDepth = 3,
  }) {
    final replies = socialViewModel.getReplies(comment.id);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Current comment
        _buildCommentItem(
          comment,
          socialViewModel,
          depth: depth,
        ),
        // Replies (recursive, indented, with visual threading)
        if (replies.isNotEmpty && depth < maxDepth)
          Padding(
            padding: const EdgeInsets.only(left: AppDimensions.paddingXl),
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(
                    color: AppColors.textMedium.withValues(alpha: 0.3),
                    width: 2,
                  ),
                ),
              ),
              child: Column(
                children: replies.map((reply) => _buildCommentWithReplies(
                  reply,
                  socialViewModel,
                  depth: depth + 1,
                  maxDepth: maxDepth,
                )).toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentItem(
    dynamic comment,
    SocialRecipeViewModel socialViewModel, {
    int depth = 0,
  }) {
    final isReply = depth > 0;

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: isReply
          ? BoxDecoration(
              color: AppColors.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Comment header
          Row(
            children: [
              SocialComponents.avatar(
                displayName: _getAuthorDisplayName(
                  comment.authorId,
                  socialViewModel,
                ),
                imageUrl: _getAuthorAvatarUrl(
                  comment.authorId,
                  socialViewModel,
                ),
                size: ImageSize.small,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _getAuthorDisplayName(
                        comment.authorId,
                        socialViewModel,
                      ),
                      style: AppTextStyles.bodySmall.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    Text(
                      _formatCommentTime(comment.createdAt),
                      style: AppTextStyles.bodySmall,
                    ),
                  ],
                ),
              ),
              // Reply button (now enabled for all comments)
              IconButton(
                onPressed: () {
                  if (mounted) {
                    setState(() {
                      _state = _state.copyWith(
                        replyingToCommentId: comment.id,
                        replyingToUserName: _getAuthorDisplayName(
                          comment.authorId,
                          socialViewModel,
                        ),
                      );
                    });
                  }
                },
                icon: const Icon(
                  Icons.reply,
                  color: AppColors.textMedium,
                  size: AppDimensions.iconSizeM,
                ),
              ),
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
              onTap: () => _showLikesDialog(comment, socialViewModel),
              child: Text(
                '${comment.likeCount} ${comment.likeCount == 1 ? 'gilla-markering' : 'gilla-markeringar'}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w500,
                  decoration: TextDecoration.underline,
                ),
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

    final currentUser = FirebaseAuthRepository().currentUser;
    if (currentUser == null) {
      _showSnackBarSafely(
        'Du måste vara inloggad för att kommentera',
        backgroundColor: AppColors.error,
      );
      return;
    }

    try {
      // CRITICAL FIX: Transfer text from controller to viewmodel
      socialViewModel.updateNewCommentText(commentText);

      // Set reply context if replying to a comment
      if (_state.replyingToCommentId != null) {
        socialViewModel.setReplyTo(_state.replyingToCommentId!);
      }

      // Post comment through viewmodel (now has the text!)
      await socialViewModel.postComment(widget.recipe.id);

      // Clear form and cancel reply in ViewModel
      _commentController.clear();
      socialViewModel.cancelReply();
      if (mounted) {
        setState(() {
          _state = _state.copyWith(
            replyingToCommentId: null,
            replyingToUserName: null,
          );
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
        'Kunde inte posta kommentar: $e',
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

  /// Show dialog with list of users who liked a comment
  void _showLikesDialog(dynamic comment, SocialRecipeViewModel socialViewModel) {
    if (!mounted) return;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Padding(
                padding: const EdgeInsets.only(bottom: AppDimensions.paddingM),
                child: Text(
                  'Gilla-markeringar (${comment.likeCount})',
                  style: AppTextStyles.headlineSmall,
                ),
              ),
              // Divider
              const Divider(),
              // List of users who liked
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: comment.likedByUserIds?.length ?? 0,
                  itemBuilder: (context, index) {
                    final userId = comment.likedByUserIds[index];
                    final displayName = _getAuthorDisplayName(userId, socialViewModel);
                    final avatarUrl = _getAuthorAvatarUrl(userId, socialViewModel);

                    return ListTile(
                      key: ValueKey(userId),
                      leading: SocialComponents.avatar(
                        displayName: displayName,
                        imageUrl: avatarUrl,
                        size: ImageSize.small,
                      ),
                      title: Text(
                        displayName,
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
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