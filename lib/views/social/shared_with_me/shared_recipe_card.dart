// lib/views/social/shared_with_me/shared_recipe_card.dart

import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;
import '../../../theme/app_dimensions.dart';
import '../../../viewmodels/shared_content_viewmodel.dart';
import '../../../models/shared_recipe.dart';
import '../../../widgets/common/social_components.dart';
import 'shared_content_actions.dart';

/// SharedRecipeCard - Card for displaying shared recipes
///
/// Displays shared recipe information with action buttons.
class SharedRecipeCard {
  static Widget build(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedRecipe sharedRecipe,
  ) {
    final recipe = sharedRecipe.recipeSnapshot;
    final isRead = viewModel.isRecipeRead(sharedRecipe);
    final isImported = viewModel.isRecipeImported(sharedRecipe);

    return Card(
      elevation: isRead ? 1 : 3,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        onTap: () {
          if (!isRead) {
            viewModel.markRecipeAsRead(sharedRecipe);
          }
          Navigator.pushNamed(
            context,
            '/receptDetalj',
            arguments: recipe,
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
              _buildHeader(context, viewModel, sharedRecipe, isRead),
              SizedBox(height: AppDimensions.spacingS),

              // Recept content
              _buildRecipeContent(context, recipe),

              // Message från delaren
              if (sharedRecipe.shareMessage?.isNotEmpty == true) ...[
                SizedBox(height: AppDimensions.spacingS),
                _buildShareMessage(context, sharedRecipe.shareMessage!),
              ],

              SizedBox(height: AppDimensions.spacingS),

              // Action buttons
              _buildActionButtons(
                context,
                viewModel,
                sharedRecipe,
                recipe,
                isRead,
                isImported,
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildHeader(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedRecipe sharedRecipe,
    bool isRead,
  ) {
    return Row(
      children: [
        SocialComponents.avatar(
          size: ImageSize.small,
          displayName: sharedRecipe.sharedByDisplayName,
        ),
        SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Delat av ${sharedRecipe.sharedByDisplayName}',
                style: Theme.of(context)
                    .textTheme
                    .bodySmall
                    ?.copyWith(
                      fontWeight: isRead
                          ? FontWeight.normal
                          : FontWeight.w600,
                      color: Theme.of(context).colorScheme.primary,
                    ),
              ),
              Text(
                timeago.format(sharedRecipe.sharedAt, locale: 'sv'),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                    ),
              ),
            ],
          ),
        ),
        // Dismiss knapp
        Container(
          decoration: BoxDecoration(
            color: Theme.of(context)
                .colorScheme
                .errorContainer
                .withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            border: Border.all(
              color: Theme.of(context)
                  .colorScheme
                  .outline
                  .withValues(alpha: 0.2),
            ),
          ),
          child: IconButton(
            onPressed: () => SharedContentActions.dismissRecipe(
              context,
              viewModel,
              sharedRecipe,
            ),
            icon: Icon(
              Icons.close,
              size: AppDimensions.iconSizeM,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            tooltip: 'Dölj från min lista',
            padding: EdgeInsets.all(AppDimensions.spacingXs),
            constraints: BoxConstraints(
              minWidth: AppDimensions.iconSizeAction + AppDimensions.spacingS,
              minHeight: AppDimensions.iconSizeAction + AppDimensions.spacingS,
            ),
          ),
        ),
        if (!isRead)
          Container(
            width: 8,
            height: 8,
            margin: EdgeInsets.only(left: AppDimensions.spacingXs),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
            ),
          ),
      ],
    );
  }

  static Widget _buildRecipeContent(BuildContext context, dynamic recipe) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (recipe.hasImages)
          ClipRRect(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            child: Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
                image: recipe.primaryImageUrl != null
                    ? DecorationImage(
                        image: NetworkImage(recipe.primaryImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                color: recipe.primaryImageUrl == null
                    ? Theme.of(context).colorScheme.surfaceContainer
                    : null,
              ),
              child: recipe.primaryImageUrl == null
                  ? Icon(
                      Icons.restaurant,
                      color: Theme.of(context)
                          .colorScheme
                          .onSurfaceVariant,
                      size: AppDimensions.iconSizeM,
                    )
                  : null,
            ),
          ),
        SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                recipe.title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              if (recipe.description.isNotEmpty) ...[
                SizedBox(height: AppDimensions.spacingXs),
                Text(
                  recipe.description,
                  style: Theme.of(context).textTheme.bodySmall,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: AppDimensions.spacingXs),
              Row(
                children: [
                  Icon(
                    Icons.restaurant,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    '${recipe.portions ?? '?'} portioner',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                  SizedBox(width: AppDimensions.spacingS),
                  Icon(
                    Icons.access_time,
                    size: 16,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                  SizedBox(width: AppDimensions.spacingXs),
                  Text(
                    recipe.cookTimeText,
                    style: Theme.of(context).textTheme.bodySmall,
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
      padding: EdgeInsets.all(AppDimensions.spacingS),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: Text(
        '"$message"',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }

  static Widget _buildActionButtons(
    BuildContext context,
    SharedContentViewModel viewModel,
    SharedRecipe sharedRecipe,
    dynamic recipe,
    bool isRead,
    bool isImported,
  ) {
    return Row(
      children: [
        Expanded(
          child: OutlinedButton.icon(
            onPressed: () {
              if (!isRead) {
                viewModel.markRecipeAsRead(sharedRecipe);
              }
              Navigator.pushNamed(
                context,
                '/receptDetalj',
                arguments: recipe,
              );
            },
            icon: const Icon(Icons.visibility, size: 18),
            label: const Text('Visa'),
          ),
        ),
        SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: FilledButton.icon(
            onPressed: isImported || viewModel.isImporting
                ? null
                : () => SharedContentActions.importRecipe(
                      context,
                      viewModel,
                      sharedRecipe,
                    ),
            icon: isImported
                ? const Icon(Icons.check, size: 18)
                : viewModel.isImporting
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.download, size: 18),
            label: Text(
              isImported ? 'Importerat' : 'Importera',
            ),
          ),
        ),
      ],
    );
  }
}