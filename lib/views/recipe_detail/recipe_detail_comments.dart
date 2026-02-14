// lib/views/recipe_detail/recipe_detail_comments.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/recipe/comment_form_widget.dart';
import 'package:butlery/widgets/recipe/comment_item_widgets.dart';
import 'package:butlery/services/unified/operations/modules/comment_likes_system.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/animations/animated_list_item.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';

/// Recipe detail comments widget with expandable section.
/// Uses extracted widgets from [CommentFormWidget] and [CommentItemWidgets].
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
  bool _isExpanded = false;
  bool _isInitialized = false;
  SocialRecipeViewModel? _socialViewModel;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initializeComments());
  }

  Future<void> _initializeComments() async {
    if (!mounted || _isInitialized) return;
    setState(() => _isInitialized = true);

    final vm = Provider.of<SocialRecipeViewModel>(context, listen: false);
    await vm.initialize();
    await vm.refreshComments(widget.recipe.id);
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
            _buildHeader(vm),
            if (_isExpanded) ...[
              const SizedBox(height: AppDimensions.spacingM),
              _buildCommentsSection(vm),
            ],
          ],
        );
      },
    );
  }

  Widget _buildHeader(SocialRecipeViewModel vm) {
    return InkWell(
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
          color: AppColors.cardWhite,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
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
                  Text(context.l10n.socialComments,
                      style: AppTextStyles.titleMedium),
                  if (vm.comments.isNotEmpty) ...[
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      context.l10n.socialCommentsCount(vm.comments.length),
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

  Widget _buildCommentsSection(SocialRecipeViewModel vm) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.cardWhite,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          // Comment form - uses extracted widget
          if (vm.currentUser == null)
            _buildLoginPrompt()
          else
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              child: CommentFormWidget(
                socialViewModel: vm,
                recipeId: widget.recipe.id,
                onShowMessage: _showMessage,
                onCommentPosted: widget.onCommentPosted,
              ),
            ),
          // Comments list
          _buildCommentsList(vm),
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
            onPressed: () => Navigator.pushNamed(context, '/login'),
            child: Text(context.l10n.authLogIn),
          ),
        ],
      ),
    );
  }

  Widget _buildCommentsList(SocialRecipeViewModel vm) {
    if (vm.isLoadingComments) {
      return StateWidget.loading(message: context.l10n.socialLoadingComments);
    }
    if (vm.commentsError != null) {
      return StateWidget.error(message: vm.commentsError!);
    }
    if (vm.comments.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingL),
        child: StateWidget.empty(
          title: context.l10n.socialNoCommentsYet,
          subtitle: context.l10n.socialBeFirstToComment,
          icon: Icons.comment_outlined,
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.paddingS),
      itemCount: vm.topLevelComments.length,
      separatorBuilder: (_, __) => const Divider(
        height: AppDimensions.borderWidthThin,
        color: AppColors.divider,
      ),
      itemBuilder: (context, index) {
        final comment = vm.topLevelComments[index];
        return AnimatedListItem(
          index: index,
          child: _buildCommentWithReplies(comment, vm),
        );
      },
    );
  }

  Widget _buildCommentWithReplies(dynamic comment, SocialRecipeViewModel vm) {
    final replies = vm.getReplies(comment.id);
    final currentUserId = vm.currentUser?.uid;

    return CommentItemWidgets.buildCommentWithReplies(
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
          isOwnComment: isOwn,
          onDelete: isOwn ? () => _deleteComment(c, vm) : null,
          depth: depth,
        );
      },
    );
  }

  Future<void> _deleteComment(dynamic comment, SocialRecipeViewModel vm) async {
    final confirmed = await CommonDialogActions.showDeleteConfirmation(
      context: context,
      itemName: comment.text.length > 40
          ? '${comment.text.substring(0, 40)}...'
          : comment.text,
      itemType: 'kommentar',
      icon: Icons.comment_outlined,
    );
    if (confirmed != true || !mounted) return;

    try {
      await vm.deleteComment(widget.recipe.id, comment.id);
    } catch (e) {
      if (!mounted) return;
      _showMessage('Kunde inte ta bort kommentaren', isError: true);
    }
  }

  Future<void> _toggleLike(dynamic comment, SocialRecipeViewModel vm) async {
    if (vm.currentUser == null) {
      _showMessage(context.l10n.socialMustBeLoggedInToLike, isError: true);
      return;
    }
    try {
      await vm.toggleCommentLike(comment.id);
    } catch (e) {
      _showMessage(context.l10n.socialCouldNotUpdateLike, isError: true);
    }
  }

  Future<void> _showLikesDialog(
      dynamic comment, SocialRecipeViewModel vm) async {
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? AppColors.error : AppColors.success,
      ),
    );
  }
}
