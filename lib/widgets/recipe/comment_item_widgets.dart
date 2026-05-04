// lib/widgets/recipe/comment_item_widgets.dart

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/widgets/common/emoji_reaction_display.dart';
import 'package:butlery/widgets/common/emoji_reaction_picker.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';

/// Widgets for displaying comment items in recipe detail view.
class CommentItemWidgets {
  /// Build a single comment item with header, content, reactions, and actions.
  static Widget buildCommentItem({
    required BuildContext context,
    required RecipeComment comment,
    required String authorDisplayName,
    required String? authorAvatarUrl,
    required String formattedTime,
    required VoidCallback onReply,
    required VoidCallback onToggleLike,
    required VoidCallback? onShowLikes,
    VoidCallback? onDelete,
    VoidCallback? onEdit,
    bool isOwnComment = false,
    bool isLiked = false,
    int depth = 0,
    String? currentUserId,
    void Function(String emoji)? onReactionTap,
  }) {
    return _CommentItemContent(
      comment: comment,
      isLiked: isLiked,
      authorDisplayName: authorDisplayName,
      authorAvatarUrl: authorAvatarUrl,
      formattedTime: formattedTime,
      onReply: onReply,
      onToggleLike: onToggleLike,
      onShowLikes: onShowLikes,
      onDelete: onDelete,
      onEdit: onEdit,
      isOwnComment: isOwnComment,
      depth: depth,
      currentUserId: currentUserId,
      onReactionTap: onReactionTap,
    );
  }

  /// Build comment with threaded replies.
  static Widget buildCommentWithReplies({
    required BuildContext context,
    required RecipeComment comment,
    required List<RecipeComment> replies,
    required Widget Function(RecipeComment comment, int depth) commentBuilder,
    int depth = 0,
    int maxDepth = 3,
  }) {
    final cs = Theme.of(context).colorScheme;
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
                    color: cs.onSurfaceVariant
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
    final now = clock.now();
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

/// Stateful widget for comment item to manage reaction picker overlay.
class _CommentItemContent extends StatefulWidget {
  final RecipeComment comment;
  final bool isLiked;
  final String authorDisplayName;
  final String? authorAvatarUrl;
  final String formattedTime;
  final VoidCallback onReply;
  final VoidCallback onToggleLike;
  final VoidCallback? onShowLikes;
  final VoidCallback? onDelete;
  final VoidCallback? onEdit;
  final bool isOwnComment;
  final int depth;
  final String? currentUserId;
  final void Function(String emoji)? onReactionTap;

  const _CommentItemContent({
    required this.comment,
    this.isLiked = false,
    required this.authorDisplayName,
    required this.authorAvatarUrl,
    required this.formattedTime,
    required this.onReply,
    required this.onToggleLike,
    required this.onShowLikes,
    this.onDelete,
    this.onEdit,
    this.isOwnComment = false,
    this.depth = 0,
    this.currentUserId,
    this.onReactionTap,
  });

  @override
  State<_CommentItemContent> createState() => _CommentItemContentState();
}

class _CommentItemContentState extends State<_CommentItemContent> {
  final LayerLink _layerLink = LayerLink();
  OverlayEntry? _reactionPickerOverlay;

  @override
  void dispose() {
    _removeOverlay();
    super.dispose();
  }

  void _removeOverlay() {
    _reactionPickerOverlay?.remove();
    _reactionPickerOverlay = null;
  }

  void _showReactionPicker() {
    if (widget.onReactionTap == null || widget.currentUserId == null) return;
    _removeOverlay();

    _reactionPickerOverlay = OverlayEntry(
      builder: (context) => Stack(
        children: [
          // Dismiss on tap outside — invisible scrim, kept out of the
          // a11y tree so screen readers focus the picker itself.
          Positioned.fill(
            child: ExcludeSemantics(
              child: GestureDetector(
                onTap: _removeOverlay,
                behavior: HitTestBehavior.opaque,
                child: const SizedBox.expand(),
              ),
            ),
          ),
          // Position the picker above the comment
          CompositedTransformFollower(
            link: _layerLink,
            targetAnchor: Alignment.topLeft,
            followerAnchor: Alignment.bottomLeft,
            offset: const Offset(0, -AppDimensions.spacingXs),
            child: EmojiReactionPicker(
              onReactionSelected: (emoji) {
                _removeOverlay();
                widget.onReactionTap?.call(emoji);
              },
            ),
          ),
        ],
      ),
    );

    Overlay.of(context).insert(_reactionPickerOverlay!);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final isReply = widget.depth > 0;
    final comment = widget.comment;

    return CompositedTransformTarget(
      link: _layerLink,
      // Long-press surfaces a reaction picker. Drop `button: true` so the
      // wrapper doesn't swallow the inner reply/like/edit/delete buttons —
      // a labeled container is enough for screen readers to announce the
      // long-press affordance.
      child: Semantics(
        label: context.l10n.a11yLongPressCommentForReactions,
        container: true,
        child: GestureDetector(
          onLongPress: _showReactionPicker,
          child: Container(
            padding: AppDimensions.paddingAll12,
            decoration: isReply
                ? BoxDecoration(
                    color:
                        cs.surface.withValues(alpha: AppDimensions.opacityHalf),
                    borderRadius:
                        BorderRadius.circular(AppDimensions.borderRadiusM),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment header
                Row(
                  children: [
                    SocialAvatarComponents.avatar(
                      displayName: widget.authorDisplayName,
                      imageUrl: widget.authorAvatarUrl,
                      size: ImageSize.small,
                    ),
                    const SizedBox(width: AppDimensions.spacingM),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.authorDisplayName,
                            style: AppTextStyles.labelLarge,
                          ),
                          Text(
                            widget.formattedTime,
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
                        onPressed: widget.onReply,
                        icon: Icon(
                          Icons.reply,
                          color: cs.onSurfaceVariant,
                          size: AppDimensions.iconSizeM,
                        ),
                      ),
                    ),
                    // Like button
                    Semantics(
                      label: widget.isLiked
                          ? context.l10n.a11yUnlikeComment
                          : context.l10n.a11yLikeComment,
                      button: true,
                      child: IconButton(
                        onPressed: widget.onToggleLike,
                        icon: Icon(
                          widget.isLiked
                              ? Icons.favorite
                              : Icons.favorite_border,
                          color:
                              widget.isLiked ? cs.error : cs.onSurfaceVariant,
                          size: AppDimensions.iconSizeM,
                        ),
                      ),
                    ),
                    if (widget.isOwnComment && widget.onEdit != null)
                      IconButton(
                        onPressed: widget.onEdit,
                        icon: Icon(
                          Icons.edit_outlined,
                          color: cs.onSurfaceVariant,
                          size: AppDimensions.iconSizeM,
                        ),
                      ),
                    if (widget.isOwnComment && widget.onDelete != null)
                      IconButton(
                        onPressed: widget.onDelete,
                        icon: Icon(
                          Icons.delete_outline,
                          color: cs.onSurfaceVariant,
                          size: AppDimensions.iconSizeM,
                        ),
                      ),
                    // Report button — visible for comments by other users
                    if (!widget.isOwnComment)
                      IconButton(
                        onPressed: () => ReportContentDialog.show(
                          context: context,
                          contentType: ContentType.comment,
                          contentId: widget.comment.id,
                          contentOwnerId: widget.comment.authorId,
                        ),
                        icon: Icon(
                          Icons.flag_outlined,
                          color: cs.onSurfaceVariant,
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

                // Emoji reaction display or hint
                if (widget.currentUserId != null &&
                    widget.onReactionTap != null) ...[
                  if (comment.reactions.values
                      .any((list) => list.isNotEmpty)) ...[
                    const SizedBox(height: AppDimensions.spacingS),
                    EmojiReactionDisplay(
                      reactions: comment.reactions,
                      currentUserId: widget.currentUserId!,
                      onReactionTap: widget.onReactionTap!,
                    ),
                  ] else ...[
                    const SizedBox(height: AppDimensions.spacingS),
                    Semantics(
                      label: context.l10n.a11yReactToComment,
                      button: true,
                      child: GestureDetector(
                        onTap: _showReactionPicker,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              Icons.add_reaction_outlined,
                              size: AppDimensions.iconSizeS,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppDimensions.spacingXs),
                            Text(
                              context.l10n.commentReact,
                              style: AppTextStyles.bodySmall.copyWith(
                                color: cs.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ],

                // Like count (tappable to show who liked)
                if (comment.likeCount > 0) ...[
                  const SizedBox(height: AppDimensions.spacingS),
                  Semantics(
                    label: context.l10n.a11yShowCommentLikes(comment.likeCount),
                    button: true,
                    child: GestureDetector(
                      onTap: widget.onShowLikes,
                      child: Text(
                        context.l10n.socialLikeCount(comment.likeCount),
                        style: AppTextStyles.metadataEmphasized.copyWith(
                          color: cs.primary,
                          decoration: TextDecoration.underline,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
