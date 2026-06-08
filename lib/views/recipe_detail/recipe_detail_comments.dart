// lib/views/recipe_detail/recipe_detail_comments.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_comment.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/recipe/comment_form_widget.dart';
import 'package:butlery/widgets/recipe/comment_item_widgets.dart';
import 'package:butlery/services/unified/operations/modules/comment_likes_system.dart';
import 'package:butlery/services/unified/operations/modules/comment_reactions_system.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/animations/animated_list_item.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/views/recipe_detail/comment_visibility.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';

/// Recipe detail comments widget with expandable section.
/// Uses extracted widgets from [CommentFormWidget] and [CommentItemWidgets].
class RecipeDetailComments extends StatefulWidget {
  final Recipe recipe;
  final VoidCallback? onCommentPosted;
  final bool initiallyExpanded;

  const RecipeDetailComments({
    super.key,
    required this.recipe,
    this.onCommentPosted,
    this.initiallyExpanded = false,
  });

  @override
  State<RecipeDetailComments> createState() => _RecipeDetailCommentsState();
}

class _RecipeDetailCommentsState extends State<RecipeDetailComments> {
  bool _isExpanded = false;
  bool _isInitialized = false;
  SocialRecipeViewModel? _socialViewModel;

  @override
  void initState() {
    super.initState();
    _isExpanded = widget.initiallyExpanded;
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeComments());
  }

  Future<void> _initializeComments() async {
    if (!mounted || _isInitialized) return;
    setState(() => _isInitialized = true);

    final vm = Provider.of<SocialRecipeViewModel>(context, listen: false);
    await vm.initialize();
    // Always load comments for header preview snippet
    await vm.refreshComments(widget.recipe.id);
    if (_isExpanded && mounted) {
      vm.startWatchingComments(widget.recipe.id);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _socialViewModel ??=
        Provider.of<SocialRecipeViewModel>(context, listen: false);
  }

  @override
  void dispose() {
    _socialViewModel?.stopWatchingComments();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<SocialRecipeViewModel>(
      builder: (context, vm, child) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context, vm),
            if (_isExpanded) ...[
              const SizedBox(height: AppDimensions.spacingM),
              _buildCommentsSection(context, vm),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(BuildContext context, SocialRecipeViewModel vm) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      label: context.l10n.a11yCommentsToggle,
      button: true,
      toggled: _isExpanded,
      child: InkWell(
        onTap: () {
          if (!mounted) return;
          setState(() => _isExpanded = !_isExpanded);
          if (_isExpanded) {
            vm.startWatchingComments(widget.recipe.id);
          } else {
            vm.stopWatchingComments();
          }
        },
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
            border: Border.all(color: cs.outlineVariant),
          ),
          child: Row(
            children: [
              Icon(
                Icons.comment_outlined,
                color: cs.primary,
                size: AppDimensions.iconSizeAction,
              ),
              const SizedBox(width: AppDimensions.spacingM),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Semantics(
                      header: true,
                      child: Text(context.l10n.socialComments,
                          style: AppTextStyles.titleMedium),
                    ),
                    if ((vm.commentCount ?? 0) > 0) ...[
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        context.l10n.socialCommentsCount(vm.commentCount!),
                        style: AppTextStyles.titleMedium,
                      ),
                    ],
                    // Preview snippet when collapsed
                    if (!_isExpanded && vm.topLevelComments.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spacingXs),
                      Text(
                        vm.topLevelComments.first.text,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              Icon(
                _isExpanded
                    ? Icons.keyboard_arrow_up
                    : Icons.keyboard_arrow_down,
                color: cs.onSurfaceVariant,
                size: AppDimensions.iconSizeAction,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// BUT-914 / BUT-1211: resolves the comment audience to display names.
  /// Returns the [resolved] names (members whose display name is known) and the
  /// TRUE [total] audience size — including members whose name didn't resolve —
  /// so neither the inline label nor the dialog can under-state who sees the
  /// comment. Empty total for non-collaborative recipes (no shared audience).
  ({List<String> resolved, int total}) _resolveCommentAudience(
      SocialRecipeViewModel vm) {
    final audienceIds = commentVisibilityAudience(
        widget.recipe, (vm.currentUser?.uid).orEmpty());

    final friendNames = <String, String>{};
    try {
      for (final f in ServiceLocator.get<UnifiedFriendsService>().friendsList) {
        friendNames[f.uid] = f.displayName;
      }
    } catch (_) {
      // Friends unavailable — the owner-name fallback below still resolves.
    }

    return resolveCommentAudienceNames(
      audienceIds,
      friendNames,
      ownerId: widget.recipe.socialData?.ownerId,
      ownerName: widget.recipe.socialData?.ownerDisplayName,
    );
  }

  /// BUT-914: names who will see a comment (collaborative recipe members) so
  /// the author isn't guessing. Hidden for non-collaborative recipes (no shared
  /// audience to label) and when no member name resolves (avoids a misleading
  /// partial). Audience is the privacy-correct set from [commentVisibilityAudience].
  ///
  /// BUT-1211: the line is tappable → a dialog listing the COMPLETE audience
  /// (every resolved name, not the inline +N truncation).
  Widget _buildVisibilityLine(BuildContext context, SocialRecipeViewModel vm) {
    final audience = _resolveCommentAudience(vm);
    if (audience.total <= 0) return const SizedBox.shrink();

    // Privacy invariant lives in formatCommentAudience: it never under-states
    // the audience (true total is always disclosed; unresolved members count
    // toward "+N" or a count-only fallback — never silently hidden).
    final audienceStr = formatCommentAudience(
      audience.resolved,
      audience.total,
      countLabel: context.l10n.recipeCommentVisiblePeople,
    );
    if (audienceStr == null) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingXs),
      child: Semantics(
        label: context.l10n.recipeCommentVisibleTo(audienceStr),
        button: true,
        child: InkWell(
          onTap: () => _showAudienceDialog(context, vm),
          child: Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: AppDimensions.iconSizeS, color: cs.onSurfaceVariant),
              const SizedBox(width: AppDimensions.spacingXxs),
              Flexible(
                child: Text(
                  context.l10n.recipeCommentVisibleTo(audienceStr),
                  style: AppTextStyles.bodySmall
                      .copyWith(color: cs.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// BUT-1211: lists the COMPLETE comment audience (all resolved names, not the
  /// inline +N truncation) so the author can verify exactly who can see their
  /// comment. Members whose name didn't resolve are shown as a trailing count —
  /// never hidden, preserving the same privacy invariant as the inline label.
  Future<void> _showAudienceDialog(
      BuildContext context, SocialRecipeViewModel vm) async {
    final audience = _resolveCommentAudience(vm);
    if (audience.total <= 0) return;
    final unresolved = audience.total - audience.resolved.length;

    await showDialog<void>(
      context: context,
      builder: (ctx) {
        final cs = Theme.of(ctx).colorScheme;
        return AlertDialog(
          title: Row(
            children: [
              Icon(Icons.visibility_outlined,
                  size: AppDimensions.iconSizeS, color: cs.onSurfaceVariant),
              const SizedBox(width: AppDimensions.spacingXs),
              Text(ctx.l10n.recipeCommentAudienceTitle),
            ],
          ),
          // No name resolved → disclose the count only (never hide the audience).
          // A collaborative recipe can have many members, so the name list
          // scrolls rather than overflowing the dialog.
          content: audience.resolved.isEmpty
              ? Text(
                  ctx.l10n.recipeCommentVisiblePeople(audience.total),
                  style: AppTextStyles.bodyMedium,
                )
              : SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (final name in audience.resolved)
                        Padding(
                          padding: const EdgeInsets.only(
                              bottom: AppDimensions.spacingXs),
                          child: Row(
                            children: [
                              Icon(Icons.person_outline,
                                  size: AppDimensions.iconSizeS,
                                  color: cs.onSurfaceVariant),
                              const SizedBox(width: AppDimensions.spacingM),
                              Flexible(
                                child:
                                    Text(name, style: AppTextStyles.bodyMedium),
                              ),
                            ],
                          ),
                        ),
                      if (unresolved > 0)
                        Padding(
                          padding: const EdgeInsets.only(
                              top: AppDimensions.spacingXxs),
                          child: Text(
                            ctx.l10n.recipeCommentAudienceOthers(unresolved),
                            style: AppTextStyles.bodySmall
                                .copyWith(color: cs.onSurfaceVariant),
                          ),
                        ),
                    ],
                  ),
                ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(ctx.l10n.commonClose),
            ),
          ],
        );
      },
    );
  }

  Widget _buildCommentsSection(BuildContext context, SocialRecipeViewModel vm) {
    final cs = Theme.of(context).colorScheme;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        children: [
          // Comment form - uses extracted widget
          if (vm.currentUser == null)
            _buildLoginPrompt()
          else
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildVisibilityLine(context, vm),
                  CommentFormWidget(
                    socialViewModel: vm,
                    recipeId: widget.recipe.id,
                    onShowMessage: _showMessage,
                    onCommentPosted: widget.onCommentPosted,
                  ),
                ],
              ),
            ),
          // Comments list
          _buildCommentsList(context, vm),
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
            context.l10n.socialMustBeLoggedInToComment,
            style: AppTextStyles.bodyLarge,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          FilledButton(
            onPressed: () => Navigator.pushNamed(context, Routes.auth),
            child: Text(context.l10n.authLogIn),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList(BuildContext context, SocialRecipeViewModel vm) {
    final cs = Theme.of(context).colorScheme;

    if (vm.isLoadingComments) {
      return StateWidget.loading(message: context.l10n.socialLoadingComments);
    }
    if (vm.commentsError != null) {
      return StateWidget.error(
        message: vm.commentsError!,
        onAction: () => vm.refreshComments(widget.recipe.id),
      );
    }
    if (vm.comments.isEmpty) {
      // BUT-986: branded mushroom illustration; title + subtitle come from
      // the variant config.
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: StateWidget.noComments(),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      itemCount: vm.topLevelComments.length,
      separatorBuilder: (_, __) => Divider(
        height: AppDimensions.borderWidthThin,
        color: cs.outlineVariant,
      ),
      itemBuilder: (context, index) {
        final comment = vm.topLevelComments[index];
        return AnimatedListItem(
          key: ValueKey(comment.id),
          index: index,
          child: _buildCommentWithReplies(comment, vm),
        );
      },
    );
  }

  Widget _buildCommentWithReplies(
      RecipeComment comment, SocialRecipeViewModel vm) {
    final replies = vm.getReplies(comment.id);
    final currentUserId = vm.currentUser?.uid;

    return CommentItemWidgets.buildCommentWithReplies(
      context: context,
      comment: comment,
      replies: replies,
      commentBuilder: (c, depth) {
        final isOwn = currentUserId != null && c.authorId == currentUserId;
        return CommentItemWidgets.buildCommentItem(
          context: context,
          comment: c,
          authorDisplayName: vm.getAuthorDisplayName(c.authorId),
          authorAvatarUrl: vm.getAuthorAvatarUrl(c.authorId),
          formattedTime:
              CommentItemWidgets.formatCommentTime(context, c.createdAt),
          onReply: () => vm.setReplyTo(c.id),
          onToggleLike: () => _toggleLike(c, vm),
          onShowLikes: c.likeCount > 0 ? () => _showLikesDialog(c, vm) : null,
          isLiked: vm.hasLikedComment(c.id),
          isOwnComment: isOwn,
          onDelete: isOwn ? () => _deleteComment(c, vm) : null,
          onEdit: isOwn ? () => _editComment(c, vm) : null,
          depth: depth,
          currentUserId: currentUserId,
          onReactionTap: currentUserId != null
              ? (emoji) => _toggleReaction(c, vm, emoji)
              : null,
        );
      },
    );
  }

  Future<void> _deleteComment(
      RecipeComment comment, SocialRecipeViewModel vm) async {
    final confirmed = await CommonDialogActions.showDeleteConfirmation(
      context: context,
      itemName: comment.text.length > 40
          ? '${comment.text.substring(0, 40)}...'
          : comment.text,
      itemType: 'kommentar',
      icon: Icons.comment_outlined,
    );
    if (confirmed != true || !mounted) return;

    // BUT-943: 7-second snackbar undo. Defer the actual service call until
    // the snackbar closes — undo tap short-circuits, timeout commits the
    // delete. Comment stays visible during the window (no optimistic
    // removal), which doubles as a "deleting…" indicator without extra UI.
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    var undone = false;
    final controller = messenger.showSnackBar(
      SnackBar(
        content: Text(context.l10n.commentDeletedUndoMessage),
        duration: const Duration(seconds: 7),
        action: SnackBarAction(
          label: context.l10n.commonUndo,
          onPressed: () => undone = true,
        ),
      ),
    );
    await controller.closed;
    if (undone || !mounted) return;

    try {
      await vm.deleteComment(widget.recipe.id, comment.id);
    } catch (e) {
      if (!mounted) return;
      _showMessage(context.l10n.commentDeleteError, isError: true);
    }
  }

  Future<void> _editComment(
      RecipeComment comment, SocialRecipeViewModel vm) async {
    final controller = TextEditingController(text: comment.text);
    final newText = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(context.l10n.commentEditHint),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 4,
          decoration: InputDecoration(
            // BUT-896: persistent label so screen-reader users still
            // have field identity once the placeholder disappears.
            labelText: context.l10n.commentLabel,
            hintText: context.l10n.commentEditHint,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(context.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, controller.text.trim()),
            child: Text(context.l10n.commonSave),
          ),
        ],
      ),
    );
    controller.dispose();
    if (newText == null || newText.isEmpty || newText == comment.text) return;
    if (!mounted) return;

    try {
      await vm.editComment(widget.recipe.id, comment.id, newText);
      if (mounted) {
        _showMessage(context.l10n.commentEdited);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(context.l10n.commentEditError, isError: true);
    }
  }

  Future<void> _toggleLike(
      RecipeComment comment, SocialRecipeViewModel vm) async {
    if (vm.currentUser == null) {
      _showMessage(context.l10n.socialMustBeLoggedInToLike, isError: true);
      return;
    }
    try {
      await vm.toggleCommentLike(comment.id);
    } catch (e) {
      if (mounted) {
        _showMessage(context.l10n.socialCouldNotUpdateLike, isError: true);
      }
    }
  }

  Future<void> _toggleReaction(
      RecipeComment comment, SocialRecipeViewModel vm, String emoji) async {
    if (vm.currentUser == null) return;
    try {
      final success = await CommentReactionsSystem.toggleCommentReaction(
        commentId: comment.id,
        recipeId: widget.recipe.id,
        userId: vm.currentUser!.uid,
        emoji: emoji,
      );
      if (success && mounted) {
        // Refresh comments to pick up the updated reactions
        await vm.refreshComments(widget.recipe.id);
      }
    } catch (e) {
      if (!mounted) return;
      _showMessage(context.l10n.reactionUpdateError, isError: true);
    }
  }

  Future<void> _showLikesDialog(
      RecipeComment comment, SocialRecipeViewModel vm) async {
    if (!mounted) return;

    // Fetch likers from subcollection
    final likerIds = await CommentLikesSystem.getCommentLikers(
      commentId: comment.id,
      limit: 100,
    );

    if (!mounted) return;
    showModalBottomSheet(
      context: context,
      builder: (_) => CommentItemWidgets.buildLikesDialog(
        context: context,
        likeCount: comment.likeCount,
        likedByUserIds: likerIds,
        getDisplayName: vm.getAuthorDisplayName,
        getAvatarUrl: vm.getAuthorAvatarUrl,
      ),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    if (!mounted) return;
    final cs = Theme.of(context).colorScheme;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? cs.error : context.butleryColors.success,
      ),
    );
  }
}
