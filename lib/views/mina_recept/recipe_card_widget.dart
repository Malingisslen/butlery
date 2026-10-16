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
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/detail_pane.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:butlery/widgets/common/swipe_hint_banner.dart';
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

  void _edit(BuildContext context) {
    Navigator.pushNamed(context, Routes.editRecipe, arguments: recipe);
  }

  Future<void> _confirmDelete(BuildContext context) async {
    final confirmed = await CommonDialogActions.showRecipeDeleteConfirmation(
      context: context,
      recipeName: recipe.title,
    );
    if (confirmed == true) onDelete(recipe);
  }

  // The swipe has a visible twin: the same two actions behind a button.
  Widget _actionsMenu(BuildContext context) {
    return AppIconButton(
      key: ValueKey('recipe-actions-${recipe.id}'),
      icon: ButleryIcons.moreVertical,
      semanticLabel: context.l10n.bulkMoreActions,
      onPressed: () => showButlerySheet<void>(
        context: context,
        builder: (sheetContext) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ButleryListRow(
                label: sheetContext.l10n.commonEdit,
                leading: ButleryIcons.pencil,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _edit(context);
                },
              ),
              ButleryListRow(
                label: sheetContext.l10n.commonDelete,
                leading: ButleryIcons.trash2,
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _confirmDelete(context);
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isSelected = viewModel.selectedIds.contains(recipe.id);
    final isOpenOnRight =
        DetailPaneScope.maybeOf(context)?.isSelected(recipe.id) ?? false;
    final cs = Theme.of(context).colorScheme;

    final showBadges = allergenPrefs.showOnCards;
    // RecipeCard directly rather than through ContentCard, so the card can
    // draw its own selected state (surface.selected with a real border,
    // #flerbar) instead of a tinted layer on top.
    Widget card = RecipeCard(
      key: ValueKey(recipe.id),
      recipe: recipe,
      // The card on the right takes the same drawn state as a ticked one:
      // surface.selected with the ink/paper border.
      isSelected: isSelected || isOpenOnRight,
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
      onTap: viewModel.isSelectionMode
          ? (_) => viewModel.toggleSelection(recipe.id)
          : (_) async {
              await openDetail(
                context,
                Routes.recipeDetail,
                arguments: recipe,
                selectionKey: recipe.id,
              );
            },
      onLongPress: viewModel.isSelectionMode
          ? null
          : (_) => viewModel.enterSelectionMode(recipe.id),
      trailing: viewModel.isSelectionMode || viewModel.isGridView
          ? null
          : _actionsMenu(context),
    );

    if (viewModel.isSelectionMode) {
      final check = Semantics(
        selected: isSelected,
        label: isSelected
            ? context.l10n.a11yRecipeSelected(recipe.title)
            : context.l10n.a11yRecipeNotSelected(recipe.title),
        child: ButleryIcon(
          isSelected ? ButleryIcons.circleCheck : ButleryIcons.circle,
          // text.primary when chosen, border.control when not: ink on
          // light and paper on dark (#flerbar draws the ink check).
          color: isSelected ? cs.onSurface : cs.outline,
          size: AppDimensions.iconSizeM,
        ),
      );
      // A list row has its thumbnail at the left edge, so the check stands
      // beside it; a grid card carries it in the top corner, over the photo.
      card = viewModel.isGridView
          ? Stack(
              fit: StackFit.passthrough,
              children: [
                card,
                Positioned(
                  top: AppDimensions.space8,
                  right: AppDimensions.space8,
                  child: check,
                ),
              ],
            )
          : Row(
              children: [
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppDimensions.space12,
                  ),
                  child: check,
                ),
                Expanded(child: card),
              ],
            );
    }

    if (!viewModel.isSelectionMode) {
      card = Semantics(
        customSemanticsActions: {
          CustomSemanticsAction(label: context.l10n.a11ySwipeEditAction): () =>
              _edit(context),
          CustomSemanticsAction(
            label: context.l10n.a11ySwipeDeleteAction,
          ): () =>
              _confirmDelete(context),
        },
        child: Dismissible(
          key: Key('recipe-${recipe.id}'),
          direction: DismissDirection.horizontal,
          confirmDismiss: (direction) async {
            HapticFeedback.mediumImpact();
            SwipeHintBanner.markUsed(SwipeHintBanner.recipeSwipeSeenKey);
            if (direction == DismissDirection.endToStart) {
              await _confirmDelete(context);
            } else if (direction == DismissDirection.startToEnd) {
              _edit(context);
            }
            return false;
          },
          background: _swipeBackground(
            alignment: AlignmentDirectional.centerStart,
            color: cs.primary,
            icon: ButleryIcons.pencil,
            iconColor: cs.onPrimary,
          ),
          secondaryBackground: _swipeBackground(
            alignment: AlignmentDirectional.centerEnd,
            color: cs.error,
            icon: ButleryIcons.trash2,
            iconColor: cs.onError,
          ),
          // Dismissible lays its child out in a loose Stack, so without this
          // a grid card shrinks to its own text and the corner menu ends up
          // outside it.
          child: SizedBox(width: double.infinity, child: card),
        ),
      );
    }

    if (viewModel.isGridView && !viewModel.isSelectionMode) {
      card = Stack(
        fit: StackFit.passthrough,
        children: [
          card,
          PositionedDirectional(
            top: AppDimensions.space4,
            end: AppDimensions.space4,
            child: Material(
              color: cs.surface,
              shape: const CircleBorder(),
              child: _actionsMenu(context),
            ),
          ),
        ],
      );
    }

    if (index != null) {
      card = Semantics(
        identifier: 'recipe-card-${recipe.id}',
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
          horizontal: AppDimensions.space24,
        ),
        color: color,
        child: ButleryIcon(
          icon,
          color: iconColor,
          size: AppDimensions.iconSize28,
        ),
      ),
    );
  }
}
