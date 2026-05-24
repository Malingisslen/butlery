// lib/widgets/common/dialogs/recipe_selection/menu_recipe_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/image/simple_image_widget.dart';

/// Dialog for selecting recipes for menu categories
class MenuRecipeSelectionDialog extends StatefulWidget {
  final String categoryName;

  const MenuRecipeSelectionDialog({
    super.key,
    required this.categoryName,
  });

  @override
  State<MenuRecipeSelectionDialog> createState() =>
      _MenuRecipeSelectionDialogState();
}

class _MenuRecipeSelectionDialogState extends State<MenuRecipeSelectionDialog> {
  final Set<String> _selectedRecipeIds = {};
  String _searchQuery = '';
  late final RecipeListViewModel _recipeListViewModel;

  @override
  void initState() {
    super.initState();
    _recipeListViewModel = ServiceLocator.get<RecipeListViewModel>();
  }

  @override
  void dispose() {
    _recipeListViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _recipeListViewModel,
      child: Consumer<RecipeListViewModel>(
        builder: (context, viewModel, child) {
          return AlertDialog(
            title: Text(
                context.l10n.dialogAddRecipesToCategory(widget.categoryName)),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildContent(context, viewModel),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(context.l10n.commonCancel),
              ),
              if (_selectedRecipeIds.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => _addSelectedRecipes(context, viewModel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Theme.of(context).colorScheme.primary,
                    foregroundColor:
                        Theme.of(context).colorScheme.surfaceContainerHighest,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingL,
                      vertical: AppDimensions.paddingM,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppDimensions.borderRadiusM),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text(
                      '${context.l10n.commonAdd} (${_selectedRecipeIds.length})'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, RecipeListViewModel viewModel) {
    if (viewModel.isLoading) {
      return StateWidget.loading(message: context.l10n.dialogLoadingRecipes);
    }

    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error!,
        onAction: viewModel.refresh,
      );
    }

    if (viewModel.recipes.isEmpty) {
      return StateWidget.noRecipes(
        onAction: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, Routes.addRecipe);
        },
      );
    }

    final filteredRecipes = _searchQuery.isEmpty
        ? viewModel.recipes
        : viewModel.recipes.where((recipe) {
            return recipe.title
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                recipe.mealType
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase()) ||
                recipe.description
                    .toLowerCase()
                    .contains(_searchQuery.toLowerCase());
          }).toList();

    return Column(
      children: [
        SearchFilterWidget.searchOnly(
          searchQuery: _searchQuery,
          onSearchChanged: (query) {
            if (mounted) {
              setState(() {
                _searchQuery = query;
              });
            }
          },
          searchHint: context.l10n.dialogSearchRecipesToAdd,
          autofocus: true,
          padding: const EdgeInsets.all(AppDimensions.spacingL),
          showStats: true,
          resultCount: filteredRecipes.length,
        ),
        if (_selectedRecipeIds.isNotEmpty) _buildInfo(),
        const Divider(height: 1),
        Expanded(
          child: filteredRecipes.isEmpty && _searchQuery.isNotEmpty
              ? StateWidget.noSearchResults(
                  onAction: () {
                    if (mounted) {
                      setState(() {
                        _searchQuery = '';
                      });
                    }
                  },
                )
              : ListView.builder(
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final unifiedRecipe = filteredRecipes[index];
                    final isSelected =
                        _selectedRecipeIds.contains(unifiedRecipe.id);

                    return MenuRecipeListItem(
                      key: ValueKey(unifiedRecipe.id),
                      recipe: unifiedRecipe,
                      isSelected: isSelected,
                      onSelectionChanged: (selected) {
                        if (mounted) {
                          setState(() {
                            if (selected) {
                              _selectedRecipeIds.add(unifiedRecipe.id);
                            } else {
                              _selectedRecipeIds.remove(unifiedRecipe.id);
                            }
                          });
                        }
                      },
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildInfo() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingL),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingXs,
              vertical: AppDimensions.spacingXxs,
            ),
            decoration: BoxDecoration(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: AppDimensions.opacityVeryLight),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: Text(
              context.l10n.dialogSelectedCount(_selectedRecipeIds.length),
              style: AppTextStyles.metadataEmphasized.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              if (mounted) {
                setState(() {
                  _selectedRecipeIds.clear();
                });
              }
            },
            child: Text(context.l10n.dialogClearSelection),
          ),
        ],
      ),
    );
  }

  void _addSelectedRecipes(
      BuildContext context, RecipeListViewModel viewModel) {
    final selectedUnifiedRecipes = viewModel.recipes
        .where((recipe) => _selectedRecipeIds.contains(recipe.id))
        .toList();

    Navigator.pop(context, selectedUnifiedRecipes);
  }
}

/// Recipe list item for menu category selection
class MenuRecipeListItem extends StatelessWidget {
  final Recipe recipe;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;

  const MenuRecipeListItem({
    super.key,
    required this.recipe,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: AppDimensions.listItemPadding,
      leading: recipe.imageUrls.isNotEmpty
          ? NetworkImageWidget(
              imageUrl: recipe.imageUrls.first,
              width: AppDimensions.iconSizeDisplay,
              height: AppDimensions.iconSizeDisplay,
              fit: BoxFit.contain,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
              errorWidget: _buildPlaceholder(context),
            )
          : _buildPlaceholder(context),
      title: Text(
        recipe.title,
        style: AppTextStyles.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildSubtitle(context),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) => onSelectionChanged(value ?? false),
        activeColor: Theme.of(context).colorScheme.primary,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS)),
      ),
      onTap: () => onSelectionChanged(!isSelected),
    );
  }

  Widget _buildSubtitle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.mealType,
          style: AppTextStyles.metadataEmphasized.copyWith(
            color: cs.primary,
          ),
        ),
        if (recipe.description.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.spacingXs),
          Text(
            recipe.description,
            style: AppTextStyles.bodySmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: AppDimensions.spacingXs),
        Row(
          children: [
            if (recipe.timeMinutes != null) ...[
              Icon(
                Icons.access_time,
                size: AppDimensions.iconSizeM,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimensions.spacingXxs),
              Text(
                '${recipe.timeMinutes} min',
                style: AppTextStyles.labelSmall,
              ),
            ],
            if (recipe.portions != null) ...[
              if (recipe.timeMinutes != null) ...[
                const SizedBox(width: AppDimensions.spacingS),
                Text('•', style: AppTextStyles.bodySmall),
                const SizedBox(width: AppDimensions.spacingS),
              ],
              Icon(
                Icons.people,
                size: AppDimensions.iconSizeM,
                color: cs.onSurfaceVariant,
              ),
              const SizedBox(width: AppDimensions.spacingXxs),
              Text(
                '${recipe.portions} port',
                style: AppTextStyles.labelSmall,
              ),
            ],
          ],
        ),
      ],
    );
  }

  Widget _buildPlaceholder(BuildContext context) {
    return Container(
      width: AppDimensions.iconSizeDisplay,
      height: AppDimensions.iconSizeDisplay,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: AppDimensions.opacityVeryLight),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Icon(
        Icons.restaurant_menu,
        color: Theme.of(context).colorScheme.primary,
        size: AppDimensions.iconSizeAction,
      ),
    );
  }

  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources    super.dispose();
  }
}
