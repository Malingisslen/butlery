// lib/widgets/common/dialogs/recipe_selection/menu_recipe_selection_dialog.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_list_viewmodel.dart';
import 'package:butlery/widgets/common/search_filter_widget.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';

/// Dialog for selecting recipes for menu categories
class MenuRecipeSelectionDialog extends StatefulWidget {
  final String categoryName;

  const MenuRecipeSelectionDialog({
    super.key,
    required this.categoryName,
  });

  @override
  State<MenuRecipeSelectionDialog> createState() => _MenuRecipeSelectionDialogState();
}

class _MenuRecipeSelectionDialogState extends State<MenuRecipeSelectionDialog> {
  final Set<String> _selectedRecipeIds = {};
  String _searchQuery = '';

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => ServiceLocator.get<RecipeListViewModel>(),
      child: Consumer<RecipeListViewModel>(
        builder: (context, viewModel, child) {
          return AlertDialog(
            title: Text('Lägg till recept i ${widget.categoryName}'),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildContent(context, viewModel),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Avbryt'),
              ),
              if (_selectedRecipeIds.isNotEmpty)
                FilledButton.icon(
                  onPressed: () => _addSelectedRecipes(context, viewModel),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: AppColors.neutralLight,
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.paddingL,
                      vertical: AppDimensions.paddingM,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
                    ),
                  ),
                  icon: const Icon(Icons.add),
                  label: Text('Lägg till (${_selectedRecipeIds.length})'),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(BuildContext context, RecipeListViewModel viewModel) {
    if (viewModel.isLoading) {
      return StateWidget.loading(message: 'Laddar recept...');
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
          Navigator.pushNamed(context, '/laggTill');
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
            setState(() {
              _searchQuery = query;
            });
          },
          searchHint: 'Sök recept att lägga till...',
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
                    setState(() {
                      _searchQuery = '';
                    });
                  },
                )
              : ListView.builder(
                  itemCount: filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final unifiedRecipe = filteredRecipes[index];
                    final isSelected = _selectedRecipeIds.contains(unifiedRecipe.id);

                    return MenuRecipeListItem(
                      recipe: unifiedRecipe,
                      isSelected: isSelected,
                      onSelectionChanged: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedRecipeIds.add(unifiedRecipe.id);
                          } else {
                            _selectedRecipeIds.remove(unifiedRecipe.id);
                          }
                        });
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
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
            ),
            child: Text(
              '${_selectedRecipeIds.length} valda',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const Spacer(),
          TextButton(
            onPressed: () {
              setState(() {
                _selectedRecipeIds.clear();
              });
            },
            child: const Text('Rensa val'),
          ),
        ],
      ),
    );
  }

  void _addSelectedRecipes(BuildContext context, RecipeListViewModel viewModel) {
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
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: recipe.imageUrls.isNotEmpty
            ? Image.network(
                recipe.imageUrls.first,
                width: AppDimensions.iconSizeDisplay,
                height: AppDimensions.iconSizeDisplay,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
      title: Text(
        recipe.title,
        style: AppTextStyles.titleMedium,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: _buildSubtitle(),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) => onSelectionChanged(value ?? false),
        activeColor: AppColors.primaryBlue,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS)),
      ),
      onTap: () => onSelectionChanged(!isSelected),
    );
  }

  Widget _buildSubtitle() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          recipe.mealType,
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.w600,
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
              const Icon(
                Icons.access_time,
                size: AppDimensions.iconSizeM,
                color: AppColors.textSecondary,
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
                const Text('•', style: AppTextStyles.bodySmall),
                const SizedBox(width: AppDimensions.spacingS),
              ],
              const Icon(
                Icons.people,
                size: AppDimensions.iconSizeM,
                color: AppColors.textSecondary,
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

  Widget _buildPlaceholder() {
    return Container(
      width: AppDimensions.iconSizeDisplay,
      height: AppDimensions.iconSizeDisplay,
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: const Icon(
        Icons.restaurant_menu,
        color: AppColors.primaryBlue,
        size: AppDimensions.iconSizeAction,
      ),
    );
  }
}