// lib/widgets/menu/menu_comments_section.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/unified/unified_menu_service.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/animations/animated_list_item.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Comment section for saved/shared menus.
/// Replicates the recipe comment pattern but uses CollaborativeMenuOperations backend.
class MenuCommentsSection extends StatefulWidget {
  final String menuId;

  const MenuCommentsSection({
    super.key,
    required this.menuId,
  });

  @override
  State<MenuCommentsSection> createState() => _MenuCommentsSectionState();
}

class _MenuCommentsSectionState extends State<MenuCommentsSection> {
  bool _isExpanded = false;
  bool _isLoading = false;
  bool _isPosting = false;
  String? _error;
  List<Map<String, dynamic>> _comments = [];
  StreamSubscription<List<Map<String, dynamic>>>? _commentsSubscription;
  final TextEditingController _commentController = TextEditingController();
  String? _replyToCommentId;

  late final UnifiedMenuService _menuService;
  late final PermissionService _permissionService;

  @override
  void initState() {
    super.initState();
    _menuService = ServiceLocator.get<UnifiedMenuService>();
    _permissionService = ServiceLocator.get<PermissionService>();
  }

  @override
  void dispose() {
    _commentsSubscription?.cancel();
    _commentController.dispose();
    super.dispose();
  }

  void _startWatching() {
    _commentsSubscription?.cancel();
    setState(() {
      _isLoading = true;
      _error = null;
    });

    _commentsSubscription =
        _menuService.collaborative.getMenuCommentsStream(widget.menuId).listen(
      (comments) {
        if (!mounted) return;
        setState(() {
          _comments = comments;
          _isLoading = false;
        });
      },
      onError: (e) {
        if (!mounted) return;
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      },
    );
  }

  void _stopWatching() {
    _commentsSubscription?.cancel();
    _commentsSubscription = null;
  }

  Future<void> _postComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    if (!_permissionService.isAuthenticated) {
      _showMessage(context.l10n.menuMustBeLoggedInToComment, isError: true);
      return;
    }

    setState(() => _isPosting = true);

    try {
      final success = await _menuService.collaborative.addMenuComment(
        menuId: widget.menuId,
        comment: text,
        replyToCommentId: _replyToCommentId,
      );

      if (!mounted) return;

      if (success) {
        _commentController.clear();
        setState(() => _replyToCommentId = null);
        _showMessage(context.l10n.menuCommentPostedSuccess);
      } else {
        _showMessage(context.l10n.menuCommentPostFailed, isError: true);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(context.l10n.menuCommentPostFailed, isError: true);
    } finally {
      if (mounted) setState(() => _isPosting = false);
    }
  }

  Future<void> _toggleLike(Map<String, dynamic> comment) async {
    if (!_permissionService.isAuthenticated) {
      _showMessage(context.l10n.socialMustBeLoggedInToLike, isError: true);
      return;
    }

    final commentId = comment['id'] as String?;
    if (commentId == null) return;

    try {
      await _menuService.collaborative.toggleCommentLike(
        menuId: widget.menuId,
        commentId: commentId,
      );
    } catch (e) {
      if (!mounted) return;
      _showMessage(context.l10n.socialCouldNotUpdateLike, isError: true);
    }
  }

  Future<void> _deleteComment(Map<String, dynamic> comment) async {
    final commentText = comment['text'] as String? ?? '';
    final displayText = commentText.length > 40
        ? '${commentText.substring(0, 40)}...'
        : commentText;

    final confirmed = await CommonDialogActions.showDeleteConfirmation(
      context: context,
      itemName: displayText,
      itemType: 'kommentar',
      icon: Icons.comment_outlined,
    );
    if (confirmed != true || !mounted) return;

    try {
      // Comment deletion uses the same toggle mechanism or a separate delete
      // For now, show error as backend doesn't have a dedicated delete method
      _showMessage(context.l10n.menuCommentDeleteFailed, isError: true);
    } catch (e) {
      if (!mounted) return;
      _showMessage(context.l10n.menuCommentDeleteFailed, isError: true);
    }
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        if (_isExpanded) ...[
          const SizedBox(height: AppDimensions.spacingM),
          _buildCommentsBody(),
        ],
      ],
    );
  }

  Widget _buildHeader() {
    return InkWell(
      onTap: () {
        if (!mounted) return;
        setState(() => _isExpanded = !_isExpanded);
        if (_isExpanded) {
          _startWatching();
        } else {
          _stopWatching();
        }
      },
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        decoration: BoxDecoration(
          color: AppColors.cardWhite,
          border: Border.all(color: AppColors.divider),
        ),
        child: Row(
          children: [
            const Icon(
              Icons.comment_outlined,
              color: AppColors.forestGreen,
              size: AppDimensions.iconSizeAction,
            ),
            const SizedBox(width: AppDimensions.spacingM),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.menuCommentsTitle,
                    style: AppTextStyles.titleMedium,
                  ),
                  if (_comments.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      context.l10n.menuCommentsCount(_comments.length),
                      style: AppTextStyles.titleMedium,
                    ),
                  ],
                ],
              ),
            ),
            Icon(
              _isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: AppColors.textMedium,
              size: AppDimensions.iconSizeAction,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsBody() {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Comment form
          if (!_permissionService.isAuthenticated)
            _buildLoginPrompt()
          else
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: _buildCommentForm(),
            ),
          // Comments list
          _buildCommentsList(),
        ],
      ),
    );
  }

  Widget _buildLoginPrompt() {
    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingL),
      child: Column(
        children: [
          Text(
            context.l10n.menuMustBeLoggedInToComment,
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            child: Text(context.l10n.authLogIn),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentForm() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Reply indicator
        if (_replyToCommentId != null) ...[
          Container(
            padding: AppDimensions.paddingAll3,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
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
                    context.l10n.commentReplyingTo,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: () => setState(() => _replyToCommentId = null),
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
        // Input row
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: TextField(
                controller: _commentController,
                decoration: InputDecoration(
                  hintText: context.l10n.menuWriteComment,
                  border: const OutlineInputBorder(),
                  contentPadding: AppDimensions.paddingAll3,
                ),
                maxLines: 3,
                minLines: 1,
                onChanged: (_) => setState(() {}),
              ),
            ),
            const SizedBox(width: AppDimensions.spacingS),
            IconButton(
              onPressed:
                  _commentController.text.trim().isNotEmpty && !_isPosting
                      ? _postComment
                      : null,
              icon: _isPosting
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send),
              style: IconButton.styleFrom(
                backgroundColor: _commentController.text.trim().isNotEmpty
                    ? Theme.of(context).colorScheme.primary
                    : null,
                foregroundColor: _commentController.text.trim().isNotEmpty
                    ? Theme.of(context).colorScheme.onPrimary
                    : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildCommentsList() {
    if (_isLoading) {
      return StateWidget.loading(message: context.l10n.menuLoadingComments);
    }
    if (_error != null) {
      return StateWidget.error(message: _error!);
    }
    if (_comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: StateWidget.empty(
          title: context.l10n.menuNoCommentsYet,
          subtitle: context.l10n.menuBeFirstToComment,
          icon: Icons.comment_outlined,
        ),
      );
    }

    // Separate top-level and reply comments
    final topLevel =
        _comments.where((c) => c['replyToCommentId'] == null).toList();

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      itemCount: topLevel.length,
      separatorBuilder: (_, __) => const Divider(
        height: AppDimensions.borderWidthThin,
        color: AppColors.divider,
      ),
      itemBuilder: (context, index) {
        final comment = topLevel[index];
        return AnimatedListItem(
          index: index,
          child: _buildCommentWithReplies(comment),
        );
      },
    );
  }

  Widget _buildCommentWithReplies(Map<String, dynamic> comment) {
    final commentId = comment['id'] as String?;
    final replies =
        _comments.where((c) => c['replyToCommentId'] == commentId).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildCommentItem(comment, depth: 0),
        if (replies.isNotEmpty)
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
                    .map((reply) => _buildCommentItem(reply, depth: 1))
                    .toList(),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildCommentItem(Map<String, dynamic> comment, {int depth = 0}) {
    final authorId = comment['authorId'] as String? ?? '';
    final authorName = comment['authorDisplayName'] as String? ?? 'Unknown';
    final text = comment['text'] as String? ?? '';
    final createdAt = comment['createdAt'] as DateTime?;
    final likeCount = comment['likeCount'] as int? ?? 0;
    final isLiked = comment['isLiked'] as bool? ?? false;
    final commentId = comment['id'] as String?;
    final currentUserId = _permissionService.currentUserId;
    final isOwnComment = currentUserId != null && authorId == currentUserId;
    final isReply = depth > 0;

    return Container(
      padding: AppDimensions.paddingAll12,
      decoration: isReply
          ? BoxDecoration(
              color: AppColors.surface
                  .withValues(alpha: AppDimensions.opacityHalf),
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(authorName, style: AppTextStyles.labelLarge),
                    if (createdAt != null)
                      Text(
                        _formatTime(createdAt),
                        style: AppTextStyles.bodySmall,
                      ),
                  ],
                ),
              ),
              // Reply button
              if (commentId != null)
                Semantics(
                  label: context.l10n.a11yReplyToComment,
                  button: true,
                  child: IconButton(
                    onPressed: () =>
                        setState(() => _replyToCommentId = commentId),
                    icon: const Icon(
                      Icons.reply,
                      color: AppColors.textMedium,
                      size: AppDimensions.iconSizeM,
                    ),
                  ),
                ),
              // Like button
              Semantics(
                label: isLiked
                    ? context.l10n.a11yUnlikeComment
                    : context.l10n.a11yLikeComment,
                button: true,
                child: IconButton(
                  onPressed: () => _toggleLike(comment),
                  icon: Icon(
                    isLiked ? Icons.favorite : Icons.favorite_border,
                    color: isLiked ? AppColors.error : AppColors.textMedium,
                    size: AppDimensions.iconSizeM,
                  ),
                ),
              ),
              // Delete button for own comments
              if (isOwnComment)
                IconButton(
                  onPressed: () => _deleteComment(comment),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: AppColors.textMedium,
                    size: AppDimensions.iconSizeM,
                  ),
                ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingS),
          // Comment text
          Text(text, style: AppTextStyles.bodyLarge),
          // Like count
          if (likeCount > 0) ...[
            const SizedBox(height: AppDimensions.spacingS),
            Text(
              context.l10n.socialLikeCount(likeCount),
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: AppColors.primary,
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _formatTime(DateTime timestamp) {
    final now = DateTime.now();
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
