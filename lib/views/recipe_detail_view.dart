// lib/views/recipe_detail_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../viewmodels/recipe_detail_viewmodel.dart';
import '../widgets/main_layout_menu.dart';
import '../theme/app_theme.dart';
import '../widgets/cached_recipe_image.dart';
import '../core/injection.dart';

/// ✨ UPPDATERAD RECEPTDETALJ-VY MED RECIPEDETAILVIEWMODEL
class RecipeDetailView extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailView({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<RecipeDetailViewModel>(param1: recipe),
      child: const _RecipeDetailViewContent(),
    );
  }
}

class _RecipeDetailViewContent extends StatelessWidget {
  const _RecipeDetailViewContent();

  Future<void> _deleteRecipe(BuildContext context) async {
    final viewModel = context.read<RecipeDetailViewModel>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Ta bort recept'),
            content: Text(
              'Är du säker på att du vill ta bort "${viewModel.recipe.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
                child: const Text('Ta bort'),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      final success = await viewModel.deleteRecipe();

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recept borttaget'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.error ?? 'Kunde inte ta bort recept'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeDetailViewModel>();

    return MainLayoutMenu(
      currentIndex: null,
      body: Scaffold(
        appBar: AppBar(
          title: Text(viewModel.recipe.title),
          actions: [
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.delete),
              onPressed:
                  viewModel.isDeleting ? null : () => _deleteRecipe(context),
              tooltip: 'Ta bort recept',
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: AppTheme.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Receptbild
                  if (viewModel.hasImage)
                    ClipRRect(
                      borderRadius: AppTheme.largeRadius,
                      child: CachedRecipeHeroImage(
                        imageUrl: viewModel.recipe.imageUrl,
                        height: AppTheme.imageHeightMedium,
                      ),
                    ),
                  if (viewModel.hasImage) AppTheme.mediumGap,

                  // Måltidstyp
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSm,
                      vertical: AppTheme.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: AppTheme.chipRadius,
                    ),
                    child: Text(
                      viewModel.recipe.mealType,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AppTheme.mediumGap,

                  // Beskrivning
                  if (viewModel.recipe.description.isNotEmpty) ...[
                    Text(
                      viewModel.recipe.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    AppTheme.mediumGap,
                  ],

                  // Metadata
                  _buildMetadata(context, viewModel),
                  AppTheme.largeGap,

                  // Taggar
                  if (viewModel.hasTags) ...[
                    Text(
                      'Taggar',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    AppTheme.smallGap,
                    Wrap(
                      spacing: AppTheme.spacingSm,
                      runSpacing: AppTheme.spacingXs,
                      children:
                          viewModel.recipe.tags!
                              .map((tag) => AppTheme.tagChip(tag))
                              .toList(),
                    ),
                    AppTheme.largeGap,
                  ],

                  // Ingredienser
                  _buildIngredients(context, viewModel),
                  AppTheme.largeGap,

                  // Instruktioner
                  _buildInstructions(context, viewModel),
                  AppTheme.extraLargeGap,

                  // Redigera-knapp
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: AppTheme.actionIcon(context, Icons.edit),
                      label: const Text('Redigera recept'),
                      style: AppTheme.primaryButtonStyle,
                      onPressed: () async {
                        final updated = await Navigator.pushNamed<bool>(
                          context,
                          '/redigeraRecept',
                          arguments: viewModel.recipe,
                        );
                        // ViewModel lyssnar på RecipeService för uppdateringar
                      },
                    ),
                  ),
                  AppTheme.mediumGap,
                ],
              ),
            ),

            // Loading overlay
            if (viewModel.isDeleting)
              Container(
                color: Colors.black26,
                child: Center(
                  child: Container(
                    padding: AppTheme.cardPadding,
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: AppTheme.largeRadius,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppTheme.mediumLoadingIndicator(),
                        AppTheme.smallGap,
                        Text(
                          'Tar bort recept...',
                          style: AppTheme.subtitleStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, RecipeDetailViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: AppTheme.cardPadding,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetadataItem(
                context,
                Icons.people,
                '${viewModel.portionsDisplay} portioner',
              ),
              _buildMetadataItem(
                context,
                Icons.access_time,
                '${viewModel.timeDisplay} min',
              ),
              if (viewModel.hasRating)
                _buildMetadataItem(
                  context,
                  Icons.star,
                  viewModel.ratingDisplay,
                ),
            ],
          ),
          if (viewModel.hasRating) ...[
            AppTheme.smallGap,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final rating = viewModel.recipe.rating!;
                if (i + 1 <= rating) {
                  return Icon(Icons.star, color: AppTheme.starColor, size: 20);
                } else if (i + 0.5 <= rating) {
                  return Icon(
                    Icons.star_half,
                    color: AppTheme.starColor,
                    size: 20,
                  );
                }
                return Icon(
                  Icons.star_border,
                  color: AppTheme.starColor,
                  size: 20,
                );
              }),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildMetadataItem(BuildContext context, IconData icon, String text) {
    return Column(
      children: [
        Icon(
          icon,
          size: AppTheme.iconSizeAction,
          color: Theme.of(context).colorScheme.primary,
        ),
        AppTheme.tinyGap,
        Text(
          text,
          style: AppTheme.captionStyle.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildIngredients(
    BuildContext context,
    RecipeDetailViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Ingredienser', style: Theme.of(context).textTheme.headlineSmall),
        AppTheme.smallGap,
        Container(
          width: double.infinity,
          padding: AppTheme.cardPadding,
          decoration: BoxDecoration(
            border: Border.all(color: Theme.of(context).colorScheme.outline),
            borderRadius: AppTheme.mediumRadius,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children:
                viewModel.recipe.ingredients.map((ingredient) {
                  return Padding(
                    padding: EdgeInsets.symmetric(
                      vertical: AppTheme.spacingXxs,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          margin: EdgeInsets.only(
                            top: 8,
                            right: AppTheme.spacingSm,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                        Expanded(
                          child: Text(
                            ingredient,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  );
                }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildInstructions(
    BuildContext context,
    RecipeDetailViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Instruktioner', style: Theme.of(context).textTheme.headlineSmall),
        AppTheme.smallGap,
        ...viewModel.recipe.instructions.asMap().entries.map((entry) {
          final index = entry.key;
          final instruction = entry.value;
          return Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: AppTheme.spacingSm),
            padding: AppTheme.cardPadding,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: AppTheme.mediumRadius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    instruction,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}
