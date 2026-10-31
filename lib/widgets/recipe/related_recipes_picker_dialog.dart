// lib/widgets/recipe/related_recipes_picker_dialog.dart
//
// BUT-1057: Multi-select picker for linking related recipes.
// Reuses the MenuRecipeSelectionDialog pattern (list + search + checkbox).
// Excludes the current recipe from the selectable list (no self-link).

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/list/butlery_item_row.dart';
import 'package:butlery/widgets/common/dialogs/dialog_cancel_button.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';
import 'package:butlery/services/search/recipe_search_matcher.dart';

/// Shows a multi-select dialog to pick recipes to link.
/// Returns `List<Recipe>` on confirm, null on cancel.
class RelatedRecipesPickerDialog extends StatefulWidget {
  /// The id of the recipe being edited — excluded from the picker list.
  final String currentRecipeId;

  /// Recipe ids already linked — excluded from the picker list to avoid
  /// re-linking an already-symmetric pair.
  final Set<String> alreadyLinkedIds;

  const RelatedRecipesPickerDialog({
    super.key,
    required this.currentRecipeId,
    required this.alreadyLinkedIds,
  });

  /// Convenience launcher — mirrors RecipeSelectionDialogs pattern.
  static Future<List<Recipe>?> show(
    BuildContext context, {
    required String currentRecipeId,
    required Set<String> alreadyLinkedIds,
  }) {
    return showButleryDialog<List<Recipe>>(
      context: context,
      builder: (_) => RelatedRecipesPickerDialog(
        currentRecipeId: currentRecipeId,
        alreadyLinkedIds: alreadyLinkedIds,
      ),
    );
  }

  @override
  State<RelatedRecipesPickerDialog> createState() =>
      _RelatedRecipesPickerDialogState();
}

class _RelatedRecipesPickerDialogState
    extends State<RelatedRecipesPickerDialog> {
  final Set<String> _selectedIds = {};
  String _searchQuery = '';
  late final RecipeListViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<RecipeListViewModel>();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _vm,
      child: Consumer<RecipeListViewModel>(
        builder: (context, vm, _) => ButleryDialog(
          title: context.l10n.recipeRelatedPickerTitle,
          scrollable: false,
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildContent(context, vm),
          ),
          actions: [
            const DialogCancelButton(),
            if (_selectedIds.isNotEmpty)
              ButleryDialogPrimary(
                label: '${context.l10n.commonAdd} (${_selectedIds.length})',
                onPressed: () => _confirm(context, vm),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, RecipeListViewModel vm) {
    if (vm.isLoading) {
      return StateWidget.loading(message: context.l10n.loadingRecipes);
    }
    if (vm.hasError) {
      return StateWidget.error(
        message: vm.error!,
        onAction: vm.refresh,
      );
    }

    final excluded = {widget.currentRecipeId, ...widget.alreadyLinkedIds};
    final selectable = vm.recipes
        .where((r) => !excluded.contains(r.id))
        .toList();

    if (selectable.isEmpty) {
      return StateWidget.noRecipes(
        onAction: () => Navigator.pop(context),
      );
    }

    final filtered = RecipeSearchMatcher.filter(selectable, _searchQuery);

    return Column(
      children: [
        SearchFilterWidget.searchOnly(
          searchQuery: _searchQuery,
          onSearchChanged: (q) => setState(() => _searchQuery = q),
          searchHint: context.l10n.dialogSearchRecipesToAdd,
          autofocus: true,
          padding: const EdgeInsets.all(AppDimensions.space16),
          showStats: true,
          resultCount: filtered.length,
        ),
        const ButleryDivider(spacing: 1),
        Expanded(
          child: filtered.isEmpty
              ? StateWidget.noSearchResults(
                  onAction: () => setState(() => _searchQuery = ''),
                )
              : ListView.builder(
                  itemCount: filtered.length,
                  itemBuilder: (context, i) {
                    final recipe = filtered[i];
                    final selected = _selectedIds.contains(recipe.id);
                    return _RecipePickerItem(
                      key: ValueKey(recipe.id),
                      recipe: recipe,
                      isSelected: selected,
                      onSelectionChanged: (v) => setState(() {
                        if (v) {
                          _selectedIds.add(recipe.id);
                        } else {
                          _selectedIds.remove(recipe.id);
                        }
                      }),
                    );
                  },
                ),
        ),
      ],
    );
  }

  void _confirm(BuildContext context, RecipeListViewModel vm) {
    final selected = vm.recipes
        .where((r) => _selectedIds.contains(r.id))
        .toList();
    Navigator.pop(context, selected);
  }
}

class _RecipePickerItem extends StatelessWidget {
  final Recipe recipe;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;

  const _RecipePickerItem({
    super.key,
    required this.recipe,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ButleryItemRow(
      padded: false,
      leading: _buildThumbnail(context),
      title: recipe.title,
      titleMaxLines: 1,
      subtitle: recipe.mealType,
      trailing: ButleryCheckbox(
        value: isSelected,
        onChanged: onSelectionChanged,
      ),
      onTap: () => onSelectionChanged(!isSelected),
    );
  }

  Widget _buildThumbnail(BuildContext context) {
    const size = AppDimensions.iconSizeXl;
    final url = recipe.imageUrls.isNotEmpty ? recipe.imageUrls.first : null;

    if (url != null) {
      return NetworkImageWidget(
        imageUrl: url,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorWidget: _placeholder(context),
      );
    }
    return _placeholder(context);
  }

  Widget _placeholder(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: AppDimensions.iconSizeXl,
      height: AppDimensions.iconSizeXl,
      color: cs.surfaceContainerHighest,
      child: ButleryIcon(
        ButleryIcons.utensils,
        color: cs.onSurface,
        size: AppDimensions.iconSizeM,
      ),
    );
  }
}
