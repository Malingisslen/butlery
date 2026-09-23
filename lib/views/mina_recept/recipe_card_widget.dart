/// Recipe card widget extracted from `mina_recept_view.dart` per BUT-441.
/// Encapsulates the full per-recipe rendering: ContentCard wrap, selection
/// overlay, swipe-to-edit / swipe-to-delete (with confirmation), and the
/// per-card a11y semantics. Stateless — all behavior driven by callbacks.
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/widgets/recipe/recipe_card.dart';

/// Renders one recipe card with selection / swipe behavior intact.
///
/// `onDelete` is invoked AFTER the user confirms the delete dialog — the
/// caller wires the actual delete + undo SnackBar (preserved in the parent
/// view so it can use that view's `mounted` and surrounding flow context).
class MinaReceptRecipeCard extends StatelessWidget {
  const MinaReceptRecipeCard({
    super.key,
    required this.viewModel,
    required this.recipe,
    required this.allergenPrefs,
    required this.onDelete,
    this.index,
  });

  final RecipeListViewModel viewModel;
  final Recipe recipe;
  final UserAllergenPreferences allergenPrefs;
  final void Function(Recipe recipe) onDelete;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final isSelected = viewModel.selectedIds.contains(recipe.id);
    final cs = Theme.of(context).colorScheme;

    final showBadges = allergenPrefs.showOnCards;
    // RecipeCard directly rather than through ContentCard, so the card can
    // draw its own selected state (surface.selected with a real border,
    // #flerbar) instead of a tinted layer on top.
    Widget card = RecipeCard(
      key: ValueKey(recipe.id),
      recipe: recipe,
      isSelected: isSelected,
      showTags: true,
      style: viewModel.isGridView
          ? RecipeCardStyle.grid
          : RecipeCardStyle.detailed,
      userAllergenPrefs: showBadges ? allergenPrefs.trackedAllergens : null,
      userDietaryPrefs: showBadges ? allergenPrefs.trackedDietary : null,
      showAllergenBadges: showBadges,
      showDietaryBadges: showBadges,
      matchPercent: viewModel.pantryOnly
          ? viewModel.pantryMatches[recipe.id]
          : null,
      pooledStats: viewModel.pooledStats[recipe.id],
      onFavoriteToggle: viewModel.isSelectionMode
          ? null
          : (_) => viewModel.toggleFavorite(recipe.id),
      onTap: viewModel.isSelectionMode
          ? (_) => viewModel.toggleSelection(recipe.id)
          : (_) async {
              await Navigator.pushNamed(
                context,
                Routes.recipeDetail,
                arguments: recipe,
              );
            },
      onLongPress: viewModel.isSelectionMode
          ? null
          : (_) => viewModel.enterSelectionMode(recipe.id),
    );

    if (viewModel.isSelectionMode) {
      card = Stack(
        children: [
          card,
          Positioned(
            top: AppDimensions.spacingSm,
            left: AppDimensions.spacingSm,
            child: Semantics(
              selected: isSelected,
              label: isSelected
                  ? context.l10n.a11yRecipeSelected(recipe.title)
                  : context.l10n.a11yRecipeNotSelected(recipe.title),
              child: Icon(
                isSelected ? Icons.check_circle : Icons.circle_outlined,
                // text.primary when chosen, border.control when not: ink on
                // light and paper on dark (#flerbar draws the ink check).
                color: isSelected ? cs.onSurface : cs.outline,
                size: AppDimensions.iconSizeM,
              ),
            ),
          ),
        ],
      );
    }

    if (!viewModel.isSelectionMode) {
      card = Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(
            label: context.l10n.a11ySwipeEditAction,
          ): () => Navigator.pushNamed(
            context,
            Routes.editRecipe,
            arguments: recipe,
          ),
          CustomSemanticsAction(
            label: context.l10n.a11ySwipeDeleteAction,
          ): () async {
            final confirmed =
                await CommonDialogActions.showRecipeDeleteConfirmation(
                  context: context,
                  recipeName: recipe.title,
                );
            if (confirmed == true) {
              onDelete(recipe);
            }
          },
        },
        child: Dismissible(
          key: Key('recipe-${recipe.id}'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            HapticFeedback.mediumImpact();
            if (direction == DismissDirection.endToStart) {
              final confirmed =
                  await CommonDialogActions.showRecipeDeleteConfirmation(
                    context: context,
                    recipeName: recipe.title,
                  );
              if (confirmed == true) {
                onDelete(recipe);
              }
              return false;
            } else if (direction == DismissDirection.startToEnd) {
              Navigator.pushNamed(
                context,
                Routes.editRecipe,
                arguments: recipe,
              );
              return false;
            }
            return false;
          },
          background: _swipeBackground(
            alignment: AlignmentDirectional.centerStart,
            color: cs.primary,
            icon: Icons.edit,
            iconColor: cs.onPrimary,
          ),
          secondaryBackground: _swipeBackground(
            alignment: AlignmentDirectional.centerEnd,
            color: cs.error,
            icon: Icons.delete,
            iconColor: cs.onError,
          ),
          child: card,
        ),
      );
    }

    if (index != null) {
      card = Semantics(
        identifier: 'recipe-card-$index',
        button: true,
        child: card,
      );
    }

    return card;
  }

  /// Identical-shape `Dismissible` background panel — extracted so the
  /// edit / delete pair stays visibly symmetric and so any future drift
  /// (e.g. padding change) only happens in one place.
  Widget _swipeBackground({
    required AlignmentGeometry alignment,
    required Color color,
    required IconData icon,
    required Color iconColor,
  }) {
    return ExcludeSemantics(
      child: Container(
        alignment: alignment,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingLg,
        ),
        color: color,
        child: Icon(icon, color: iconColor, size: AppDimensions.iconSize28),
      ),
    );
  }
}
