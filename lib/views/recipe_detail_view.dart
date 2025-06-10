// lib/views/recipe_detail_view.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/recipe_service_widget.dart';
import '../theme/app_theme.dart';
import '../widgets/cached_recipe_image.dart';

/// ✨ UPPDATERAD RECEPTDETALJ-VY MED RECIPESERVICE
class RecipeDetailView extends StatefulWidget {
  final Recipe recipe;

  const RecipeDetailView({super.key, required this.recipe});

  @override
  State<RecipeDetailView> createState() => _RecipeDetailViewState();
}

class _RecipeDetailViewState extends State<RecipeDetailView> {
  final RecipeService _recipeService = RecipeService();
  bool _isDeleting = false;

  Future<void> _deleteRecipe() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (context) => AlertDialog(
            title: const Text('Ta bort recept'),
            content: Text(
              'Är du säker på att du vill ta bort "${widget.recipe.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
                child: const Text('Ta bort'),
              ),
            ],
          ),
    );

    if (confirmed != true) return;

    setState(() {
      _isDeleting = true;
    });

    try {
      final result = await _recipeService.deleteRecipe(widget.recipe.id);

      if (!mounted) return;

      if (result.isSuccess) {
        RecipeServiceSnackbar.showSuccess(context, result.message);
        Navigator.pop(context);
      } else {
        RecipeServiceSnackbar.showError(context, result.message);
      }
    } catch (e) {
      if (!mounted) return;
      RecipeServiceSnackbar.showError(
        context,
        'Kunde inte ta bort recept: ${e.toString()}',
      );
    } finally {
      if (mounted) {
        setState(() {
          _isDeleting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return MainLayoutMenu(
      currentIndex: null,
      body: Scaffold(
        appBar: AppBar(
          title: Text(widget.recipe.title),
          actions: [
            // Delete button
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.delete),
              onPressed: _isDeleting ? null : _deleteRecipe,
              tooltip: 'Ta bort recept',
            ),
          ],
        ),
        body: Stack(
          children: [
            // Huvudinnehåll med RecipeService integration
            RecipeServiceWidget(
              builder: (recipes) {
                // Hitta aktuellt recept i listan (kan ha uppdaterats)
                final currentRecipe = recipes.firstWhere(
                  (r) => r.id == widget.recipe.id,
                  orElse: () => widget.recipe, // Fallback till original
                );

                return SingleChildScrollView(
                  padding: AppTheme.screenPadding,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Receptbild
                      if (currentRecipe.imageUrl != null &&
                          currentRecipe.imageUrl!.isNotEmpty)
                        ClipRRect(
                          borderRadius: AppTheme.largeRadius,
                          child: CachedRecipeHeroImage(
                            imageUrl: currentRecipe.imageUrl,
                            height: AppTheme.imageHeightMedium,
                          ),
                        ),
                      AppTheme.mediumGap,

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
                          currentRecipe.mealType,
                          style: Theme.of(
                            context,
                          ).textTheme.labelMedium?.copyWith(
                            color:
                                Theme.of(
                                  context,
                                ).colorScheme.onPrimaryContainer,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      AppTheme.mediumGap,

                      // Beskrivning
                      if (currentRecipe.description.isNotEmpty) ...[
                        Text(
                          currentRecipe.description,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        AppTheme.mediumGap,
                      ],

                      // Metadata (portioner, tid, betyg)
                      Container(
                        width: double.infinity,
                        padding: AppTheme.cardPadding,
                        decoration: BoxDecoration(
                          color:
                              Theme.of(
                                context,
                              ).colorScheme.surfaceContainerHighest,
                          borderRadius: AppTheme.mediumRadius,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildMetadataItem(
                                  Icons.people,
                                  '${currentRecipe.portions ?? '?'} portioner',
                                ),
                                _buildMetadataItem(
                                  Icons.access_time,
                                  '${currentRecipe.timeMinutes ?? '?'} min',
                                ),
                                if (currentRecipe.rating != null)
                                  _buildMetadataItem(
                                    Icons.star,
                                    currentRecipe.rating!.toStringAsFixed(1),
                                  ),
                              ],
                            ),
                            if (currentRecipe.rating != null) ...[
                              AppTheme.smallGap,
                              Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: List.generate(5, (i) {
                                  final r = currentRecipe.rating!;
                                  if (i + 1 <= r) {
                                    return Icon(
                                      Icons.star,
                                      color: AppTheme.starColor,
                                      size: 20,
                                    );
                                  } else if (i + 0.5 <= r) {
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
                      ),
                      AppTheme.largeGap,

                      // Taggar
                      if (currentRecipe.tags != null &&
                          currentRecipe.tags!.isNotEmpty) ...[
                        Text(
                          'Taggar',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                        AppTheme.smallGap,
                        Wrap(
                          spacing: AppTheme.spacingSm,
                          runSpacing: AppTheme.spacingXs,
                          children:
                              currentRecipe.tags!
                                  .map((tag) => AppTheme.tagChip(tag))
                                  .toList(),
                        ),
                        AppTheme.largeGap,
                      ],

                      // Ingredienser
                      Text(
                        'Ingredienser',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      AppTheme.smallGap,
                      Container(
                        width: double.infinity,
                        padding: AppTheme.cardPadding,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          borderRadius: AppTheme.mediumRadius,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children:
                              currentRecipe.ingredients.map((ingredient) {
                                return Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: AppTheme.spacingXxs,
                                  ),
                                  child: Row(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Container(
                                        width: 6,
                                        height: 6,
                                        margin: EdgeInsets.only(
                                          top: 8,
                                          right: AppTheme.spacingSm,
                                        ),
                                        decoration: BoxDecoration(
                                          color:
                                              Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                          shape: BoxShape.circle,
                                        ),
                                      ),
                                      Expanded(
                                        child: Text(
                                          ingredient,
                                          style:
                                              Theme.of(
                                                context,
                                              ).textTheme.bodyMedium,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }).toList(),
                        ),
                      ),
                      AppTheme.largeGap,

                      // Instruktioner
                      Text(
                        'Instruktioner',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      AppTheme.smallGap,
                      ...currentRecipe.instructions.asMap().entries.map((
                        entry,
                      ) {
                        final index = entry.key;
                        final instruction = entry.value;
                        return Container(
                          width: double.infinity,
                          margin: EdgeInsets.only(bottom: AppTheme.spacingSm),
                          padding: AppTheme.cardPadding,
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: Theme.of(context).colorScheme.outline,
                            ),
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
                                      color:
                                          Theme.of(
                                            context,
                                          ).colorScheme.onPrimary,
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
                      AppTheme.extraLargeGap,

                      // Redigera-knapp
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          icon: AppTheme.actionIcon(context, Icons.edit),
                          label: const Text('Redigera recept'),
                          style: AppTheme.primaryButtonStyle,
                          onPressed: () async {
                            final nav = Navigator.of(context);
                            final updated = await nav.pushNamed<bool>(
                              '/redigeraRecept',
                              arguments: currentRecipe,
                            );
                            if (!mounted) return;
                            if (updated == true) {
                              // Receptet har uppdaterats, RecipeService kommer
                              // automatiskt uppdatera UI via Consumer
                            }
                          },
                        ),
                      ),
                      AppTheme.mediumGap,
                    ],
                  ),
                );
              },
            ),

            // Loading overlay när vi tar bort recept
            if (_isDeleting)
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

            // Loading overlay för RecipeService
            RecipeServiceConsumer(
              builder: (context, recipeService, child) {
                if (recipeService.isLoading && !_isDeleting) {
                  return Container(
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
                              'Uppdaterar...',
                              style: AppTheme.subtitleStyle,
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataItem(IconData icon, String text) {
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
}

// Extension för att hitta first element eller null
extension FirstWhereOrNullExtension<T> on Iterable<T> {
  T firstWhere(bool Function(T) test, {T Function()? orElse}) {
    for (final element in this) {
      if (test(element)) return element;
    }
    if (orElse != null) return orElse();
    throw StateError('No element');
  }
}
