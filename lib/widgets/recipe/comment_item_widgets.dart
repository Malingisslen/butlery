// lib/widgets/recipe/comment_item_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/utils/contextual_time_formatter.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/linkified_text.dart';
import 'package:butlery/widgets/common/butlery_tap_target.dart';
import 'package:butlery/widgets/common/emoji_reaction_display.dart';
import 'package:butlery/widgets/common/emoji_reaction_picker.dart';
import 'package:butlery/widgets/recipe/comment_image_attachments.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/social/report_content_dialog.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';

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
  ///
  /// [repliesFor] answers for a reply's own replies, so a reply to a reply is
  /// shown. Below [maxDepth] the thread stops indenting but keeps going, so a
  /// deep answer is never dropped.
  static Widget buildCommentWithReplies({
    required BuildContext context,
    required RecipeComment comment,
    required List<RecipeComment> replies,
    required Widget Function(RecipeComment comment, int depth) commentBuilder,
    List<RecipeComment> Function(String commentId)? repliesFor,
    int depth = 0,
    int maxDepth = 3,
  }) {
    final cs = Theme.of(context).colorScheme;
    final children = [
      for (final reply in replies)
        buildCommentWithReplies(
          context: context,
          comment: reply,
          replies: repliesFor?.call(reply.id) ?? const [],
          commentBuilder: commentBuilder,
          repliesFor: repliesFor,
          depth: depth + 1,
          maxDepth: maxDepth,
        ),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        commentBuilder(comment, depth),
        if (children.isNotEmpty)
          depth >= maxDepth
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: children,
                )
              : Padding(
                  padding: const EdgeInsetsDirectional.only(
                    start: AppDimensions.space16,
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: Border(
                        left: BorderSide(
                          color: cs.outlineVariant,
                          width: 2,
                        ),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: children,
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
          const ButleryDivider(),
          // List of users who liked
          Flexible(
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: likedByUserIds.length,
              itemBuilder: (context, index) {
                final userId = likedByUserIds[index];
                final displayName = getDisplayName(userId);
                final avatarUrl = getAvatarUrl(userId);

                return ButleryItemRow(
                  key: ValueKey(userId),
                  padded: false,
                  leading: AvatarCircle(
                    displayName: displayName,
                    imageUrl: avatarUrl,
                    announceName: true,
                  ),
                  title: displayName,
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  /// Format comment time for display: relative for a week, then the date.
  static String formatCommentTime(BuildContext context, DateTime timestamp) =>
      ContextualTimeFormatter.compact(
        timestamp,
        localeName: Localizations.localeOf(context).toString(),
      );
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
            offset: const Offset(0, -AppDimensions.space4),
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
                    color: cs.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusControl,
                    ),
                  )
                : null,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Comment header
                Row(
                  children: [
                    AvatarCircle(
                      displayName: widget.authorDisplayName,
                      imageUrl: widget.authorAvatarUrl,
                      size: AvatarCircleSize.inline,
                      announceName: true,
                    ),
                    const SizedBox(width: AppDimensions.space8),
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
                    AppIconButton(
                      icon: ButleryIcons.reply,
                      semanticLabel: context.l10n.a11yReplyToComment,
                      onPressed: widget.onReply,
                      color: cs.onSurfaceVariant,
                      iconSize: AppDimensions.iconSizeM,
                    ),
                    // Like button
                    AppIconButton(
                      icon: widget.isLiked
                          ? ButleryIcons.favourite
                          : ButleryIcons.favouriteOutline,
                      semanticLabel: widget.isLiked
                          ? context.l10n.a11yUnlikeComment
                          : context.l10n.a11yLikeComment,
                      onPressed: widget.onToggleLike,
                      // Red is deliberate (BUT-1213): red = social like,
                      // green (cs.primary) = personal favourite.
                      color: widget.isLiked ? cs.error : cs.onSurfaceVariant,
                      iconSize: AppDimensions.iconSizeM,
                    ),
                    if (widget.isOwnComment && widget.onEdit != null)
                      AppIconButton(
                        icon: ButleryIcons.pencil,
                        semanticLabel: context.l10n.a11yEditComment,
                        onPressed: widget.onEdit,
                        color: cs.onSurfaceVariant,
                        iconSize: AppDimensions.iconSizeM,
                      ),
                    if (widget.isOwnComment && widget.onDelete != null)
                      AppIconButton(
                        icon: ButleryIcons.trash2,
                        semanticLabel: context.l10n.a11yDeleteComment,
                        onPressed: widget.onDelete,
                        color: cs.onSurfaceVariant,
                        iconSize: AppDimensions.iconSizeM,
                      ),
                    // Report button — visible for comments by other users
                    if (!widget.isOwnComment)
                      AppIconButton(
                        icon: ButleryIcons.flag,
                        semanticLabel: context.l10n.a11yReportComment,
                        onPressed: () => ReportContentDialog.show(
                          context: context,
                          contentType: ContentType.comment,
                          contentId: widget.comment.id,
                          contentOwnerId: widget.comment.authorId,
                        ),
                        color: cs.onSurfaceVariant,
                        iconSize: AppDimensions.iconSizeM,
                      ),
                  ],
                ),

                const SizedBox(height: AppDimensions.space4),

                // Comment content — BUT-962: linkify HTTP/HTTPS URLs.
                LinkifiedText.from(
                  comment.text,
                  style: AppTextStyles.bodyLarge,
                ),

                // BUT-1049: image attachments above the reactions strip.
                if (comment.imageUrls.isNotEmpty) ...[
                  const SizedBox(height: AppDimensions.space4),
                  CommentImageAttachments(imageUrls: comment.imageUrls),
                ],

                // Emoji reaction display or hint
                if (widget.currentUserId != null &&
                    widget.onReactionTap != null) ...[
                  if (comment.reactions.values.any(
                    (list) => list.isNotEmpty,
                  )) ...[
                    const SizedBox(height: AppDimensions.space4),
                    EmojiReactionDisplay(
                      reactions: comment.reactions,
                      currentUserId: widget.currentUserId!,
                      onReactionTap: widget.onReactionTap!,
                    ),
                  ] else ...[
                    const SizedBox(height: AppDimensions.space4),
                    ButleryTapTarget(
                      semanticLabel: context.l10n.a11yReactToComment,
                      onTap: _showReactionPicker,
                      child: ExcludeSemantics(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            ButleryIcon(
                              ButleryIcons.reactionAdd,
                              size: AppDimensions.iconSizeS,
                              color: cs.onSurfaceVariant,
                            ),
                            const SizedBox(width: AppDimensions.space4),
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
                  const SizedBox(height: AppDimensions.space4),
                  Semantics(
                    label: context.l10n.a11yShowCommentLikes,
                    container: true,
                    button: true,
                    child: GestureDetector(
                      onTap: widget.onShowLikes,
                      child: Text(
                        context.l10n.socialLikeCount(comment.likeCount),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: cs.onSurface,
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
