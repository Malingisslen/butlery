// lib/views/social/shared_with_me/shared_recipe_card.dart

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/views/social/shared_with_me/shared_content_actions.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/social/shared_card_header.dart';

/// SharedRecipeCard - Card for displaying shared recipes
/// Displays shared recipe information with action buttons.
class SharedRecipeCard {
  static Widget build(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) {
    final isRead = viewModel.recipeViewModel.isRecipeViewed(sharedRecipe);
    final isImported = viewModel.recipeViewModel.isRecipeImported(sharedRecipe);

    return Material(
      elevation:
          isRead ? AppDimensions.elevationLow : AppDimensions.elevationMedium,
      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      child: Semantics(
        label: context.l10n.a11ySharedRecipe(sharedRecipe.recipeTitle),
        button: true,
        child: InkWell(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          onTap: () {
            if (!isRead) {
              viewModel.recipeViewModel.markAsViewed(sharedRecipe);
            }
            // Use contentSnapshot which provides minimal recipe from denormalized fields
            Navigator.pushNamed(
              context,
              Routes.receptDetalj,
              arguments: sharedRecipe.contentSnapshot,
            );
          },
          child: Container(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              border: !isRead
                  ? Border.all(
                      color: Theme.of(context).colorScheme.primary,
                      width: 2,
                    )
                  : null,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header med delningsinfo
                SharedCardHeader(
                  displayName: sharedRecipe.sharedByDisplayName,
                  timestampText:
                      timeago.format(sharedRecipe.sharedAt, locale: 'sv'),
                  isRead: isRead,
                  onDismiss: () => SharedContentActions.dismissRecipe(
                    context,
                    viewModel,
                    sharedRecipe,
                  ),
                  onUnshare: () => SharedContentActions.unshareRecipe(
                    context,
                    sharedRecipe,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingS),

                // Recept content - uses denormalized fields for V2 efficiency
                _buildRecipeContent(context, sharedRecipe),

                // Message from the sharer
                if (sharedRecipe.shareMessage?.isNotEmpty == true) ...[
                  const SizedBox(height: AppDimensions.spacingS),
                  _buildShareMessage(context, sharedRecipe.shareMessage!),
                ],

                const SizedBox(height: AppDimensions.spacingS),

                // Action buttons
                _buildActionButtons(
                  context,
                  viewModel,
                  sharedRecipe,
                  isRead,
                  isImported,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build recipe content using denormalized fields for V2 efficiency.
  /// No need to access full snapshot for list display.
  static Widget _buildRecipeContent(
      BuildContext context, SharedRecipe sharedRecipe) {
    final hasImage = sharedRecipe.recipeImageUrl != null;
    final cookTimeText = sharedRecipe.recipeTimeMinutes != null
        ? '${sharedRecipe.recipeTimeMinutes} min'
        : '? min';

    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center, // Center image with content
      children: [
        if (hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                image: DecorationImage(
                  image: NetworkImage(sharedRecipe.recipeImageUrl!),
                  fit: BoxFit.cover,
                ),
              ),
            ),
          ),
        if (!hasImage)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            child: Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainer,
              ),
              child: Icon(
                Icons.restaurant,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                size: AppDimensions.iconSizeM,
              ),
            ),
          ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                sharedRecipe.recipeTitle,
                style: AppTextStyles.titleMedium,
              ),
              if (sharedRecipe.recipeDescription?.isNotEmpty == true) ...[
                const SizedBox(height: AppDimensions.spacingXs),
                Text(
                  sharedRecipe.recipeDescription!,
                  style: AppTextStyles.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: AppDimensions.spacingXs),
              Row(
                children: [
                  Icon(
                    Icons.restaurant,
                    size: AppDimensions.iconSizeS,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    context.l10n
                        .recipePortionsCount(sharedRecipe.recipePortions ?? 0),
                    style: AppTextStyles.bodySmall,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Icon(
                    Icons.access_time,
                    size: AppDimensions.iconSizeS,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    cookTimeText,
                    style: AppTextStyles.bodySmall,
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }

  static Widget _buildShareMessage(BuildContext context, String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Text(
        '"$message"',
        style: AppTextStyles.bodySmall.copyWith(
          fontStyle: FontStyle.italic,
        ),
      ),
    );
  }

  static Widget _buildActionButtons(
    BuildContext context,
    SharedContentCoordinatorViewModel viewModel,
    SharedRecipe sharedRecipe,
    bool isRead,
    bool isImported,
  ) {
    return Row(
      children: [
        Expanded(
          child: SocialBuilderComponents.socialActionButton(
            text: context.l10n.commonView,
            onPressed: () {
              if (!isRead) {
                viewModel.recipeViewModel.markAsViewed(sharedRecipe);
              }
              Navigator.pushNamed(
                context,
                Routes.receptDetalj,
                arguments: sharedRecipe.contentSnapshot,
              );
            },
            icon: Icons.visibility,
            outlined: true,
            compact: true,
          ),
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: SocialBuilderComponents.socialActionButton(
            text: isImported
                ? context.l10n.sharedImported
                : context.l10n.sharedImport,
            onPressed: () {
              if (!isImported && !viewModel.recipeViewModel.isOperating) {
                SharedContentActions.importRecipe(
                  context,
                  viewModel,
                  sharedRecipe,
                );
              }
            },
            icon: isImported
                ? Icons.check
                : viewModel.recipeViewModel.isOperating
                    ? null // Loading handled by facade
                    : Icons.download,
            loading: viewModel.recipeViewModel.isOperating,
            compact: true,
          ),
        ),
      ],
    );
  }
}
