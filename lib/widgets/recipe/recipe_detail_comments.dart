// lib/widgets/recipe/recipe_detail_comments.dart

import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:butlery/viewmodels/social_recipe_viewmodel.dart';
import 'package:butlery/widgets/recipe/comment_form_widget.dart';
import 'package:butlery/widgets/recipe/comment_item_widget.dart';
import 'package:butlery/widgets/recipe/comment_debug_panel.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Standalone widget for displaying and managing recipe comments
class RecipeDetailComments extends StatefulWidget {
  final SocialRecipeViewModel socialViewModel;
  final String recipeId;
  final VoidCallback? onCommentPosted;
  final bool showDebugSection;

  const RecipeDetailComments({
    super.key,
    required this.socialViewModel,
    required this.recipeId,
    this.onCommentPosted,
    this.showDebugSection = true,
  });

  @override
  State<RecipeDetailComments> createState() => _RecipeDetailCommentsState();
}

class _RecipeDetailCommentsState extends State<RecipeDetailComments> {
  bool _isCommentsExpanded = false;

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
          _buildHeader(context),
          if (_isCommentsExpanded) ...[
            Divider(height: 1, color: Theme.of(context).colorScheme.outline),
            Padding(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildCommentsContent(context),
                  const SizedBox(height: AppDimensions.spacingXl),
                  if (kDebugMode && widget.showDebugSection) ...[
                    CommentDebugPanel(
                      socialViewModel: widget.socialViewModel,
                      onShowMessage: _showSnackBarSafely,
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                  ],
                  _buildCommentFormOrPrompt(context),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return InkWell(
      onTap: () {
        if (mounted) {
          setState(() {
            _isCommentsExpanded = !_isCommentsExpanded;
          });
        }
        if (_isCommentsExpanded && !widget.socialViewModel.hasComments) {
          widget.socialViewModel.refreshComments(widget.recipeId);
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
                style: AppTextStyles.titleMedium.copyWith(
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
            ),
            if (widget.socialViewModel.friends.isNotEmpty)
              Icon(
                _isCommentsExpanded ? Icons.expand_less : Icons.expand_more,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentsContent(BuildContext context) {
    if (widget.socialViewModel.isLoadingComments) {
      return const Center(
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
              Text('Laddar kommentarer...', style: AppTextStyles.bodySmall),
            ],
          ),
        ),
      );
    }

    if (widget.socialViewModel.commentsError != null) {
      return Container(
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
      );
    }

    if (!widget.socialViewModel.hasComments) {
      return Container(
        padding: const EdgeInsets.all(AppDimensions.spacingL * 2),
        child: Column(
          children: [
            Icon(
              Icons.chat_bubble_outline,
              size: AppDimensions.iconSizeAction,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            const Text(
              'Inga kommentarer än',
              style: AppTextStyles.titleMedium,
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
      );
    }

    return Column(
      children: widget.socialViewModel.topLevelComments
          .map((comment) => CommentItemWidget(
                socialViewModel: widget.socialViewModel,
                comment: comment,
              ))
          .toList(),
    );
  }

  Widget _buildCommentFormOrPrompt(BuildContext context) {
    if (widget.socialViewModel.currentUser != null) {
      return CommentFormWidget(
        socialViewModel: widget.socialViewModel,
        recipeId: widget.recipeId,
        onShowMessage: _showSnackBarSafely,
        onCommentPosted: widget.onCommentPosted,
      );
    }

    return Container(
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
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          const Text(
            'Skapa profil för att kommentera',
            style: AppTextStyles.titleSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          FilledButton.icon(
            onPressed: () => Navigator.pushNamed(context, '/profile/edit'),
            icon: const Icon(Icons.person_add),
            label: const Text('Skapa profil'),
          ),
        ],
      ),
    );
  }
}
