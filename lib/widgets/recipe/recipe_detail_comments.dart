// lib/widgets/recipe/recipe_detail_comments.dart

import 'package:flutter/material.dart';
import '../../repositories/firebase/firebase_auth_repository.dart';
import '../../viewmodels/social_recipe_viewmodel.dart';
import '../../widgets/common/social_components.dart';
import '../../theme/app_theme.dart';
import '../../core/injection.dart';
import '../../services/user_service.dart';
import '../../core/utils/snackbar_utils.dart';

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
      decoration: AppTheme.infoBoxDecoration(context),
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
              padding: AppTheme.cardPadding,
              child: Row(
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: AppTheme.iconSizeAction,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppTheme.spacingSm),
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
              padding: AppTheme.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Comments list
                  if (widget.socialViewModel.isLoadingComments)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacingMd),
                        child: Column(
                          children: [
                            AppTheme.smallLoadingIndicator(),
                            AppTheme.smallGap,
                            Text(
                              'Laddar kommentarer...',
                              style: AppTheme.captionStyle,
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (widget.socialViewModel.commentsError != null)
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: AppTheme.smallRadius,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppTheme.errorColor),
                          SizedBox(width: AppTheme.spacingSm),
                          Expanded(
                            child: Text(
                              widget.socialViewModel.commentsError!,
                              style: TextStyle(color: AppTheme.errorColor),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!widget.socialViewModel.hasComments)
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingMd * 2),
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: AppTheme.iconSizeAction,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          AppTheme.mediumGap,
                          Text(
                            'Inga kommentarer än',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          AppTheme.smallGap,
                          Text(
                            'Bli först att kommentera detta recept!',
                            style: AppTheme.captionStyle,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...widget.socialViewModel.topLevelComments.map((comment) =>
                        _buildCommentItem(context, widget.socialViewModel, comment)),

                  AppTheme.mediumGap,

                  // DEBUG INFO + CREATE PROFILE
                  Builder(
                    builder: (context) {
                      final userService = sl<UserService>();
                      final authUser = FirebaseAuthRepository().currentUser;

                      return Container(
                        padding: EdgeInsets.all(AppTheme.spacingSm),
                        color: AppTheme.warningLight,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🔍 DEBUG INFO:',
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

                            AppTheme.smallGap,

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
                                child: Text('Skapa Profil'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  AppTheme.smallGap,

                  // Comment form (for all logged-in users)
                  if (widget.socialViewModel.currentUser != null)
                    _buildCommentForm(context, widget.socialViewModel)
                  else
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: AppTheme.mediumRadius,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            size: AppTheme.iconSizeAction,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          AppTheme.smallGap,
                          Text(
                            'Skapa profil för att kommentera',
                            style: Theme.of(context).textTheme.titleSmall,
                            textAlign: TextAlign.center,
                          ),
                          AppTheme.smallGap,
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
            padding: EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: AppTheme.mediumRadius,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.reply,
                  size: AppTheme.iconSizeInfo,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    'Svarar på kommentar',
                    style: AppTheme.captionStyle.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: socialViewModel.cancelReply,
                  icon: Icon(
                    Icons.close,
                    size: AppTheme.iconSizeInfo,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          AppTheme.smallGap,
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SocialComponents.avatar(
              user: socialViewModel.currentUser,
              displayName: 'Du', // fallback if user is null
              size: ImageSize.small,
            ),
            SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: TextField(
                onChanged: socialViewModel.updateNewCommentText,
                decoration: InputDecoration(
                  hintText: socialViewModel.isReplying
                      ? 'Skriv ditt svar...'
                      : 'Skriv en kommentar...',
                  border: OutlineInputBorder(
                    borderRadius: AppTheme.mediumRadius,
                  ),
                  contentPadding: EdgeInsets.all(AppTheme.spacingSm),
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            SizedBox(width: AppTheme.spacingSm),
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
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: AppTheme.smallLoadingIndicator(),
                    )
                  : Icon(Icons.send),
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
      margin: EdgeInsets.only(bottom: AppTheme.spacingSm),
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
              SizedBox(width: AppTheme.spacingSm),
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
                        SizedBox(width: AppTheme.spacingSm),
                        Text(
                          _formatCommentTime(comment.createdAt),
                          style: AppTheme.captionStyle,
                        ),
                      ],
                    ),
                    AppTheme.tinyGap,
                    Text(
                      comment.text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    AppTheme.tinyGap,
                    Row(
                      children: [
                        // Like button
                        InkWell(
                          onTap: () =>
                              socialViewModel.toggleCommentLike(comment.id),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacingXs,
                              horizontal: AppTheme.spacingSm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  socialViewModel.hasLikedComment(comment)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: AppTheme.iconSizeInfo,
                                  color:
                                      socialViewModel.hasLikedComment(comment)
                                          ? AppTheme.errorColor
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                ),
                                if (comment.likeCount > 0) ...[
                                  SizedBox(width: AppTheme.spacingXs),
                                  Text(
                                    '${comment.likeCount}',
                                    style: AppTheme.captionStyle,
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
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacingXs,
                              horizontal: AppTheme.spacingSm,
                            ),
                            child: Text(
                              'Svara',
                              style: AppTheme.captionStyle.copyWith(
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
                padding: EdgeInsets.only(left: AppTheme.spacingLg),
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