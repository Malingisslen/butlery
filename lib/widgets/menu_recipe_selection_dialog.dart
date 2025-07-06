// lib/widgets/menu_recipe_selection_dialog.dart

/// 🔍 AI INFO BLOCK:
/// Component: MenuRecipeSelectionDialog - Recipe selection for menu categories
/// File: lib/widgets/menu_recipe_selection_dialog.dart
/// Quick Guide: Dialog for selecting recipes to add to menu categories
/// Dependencies IN: Recipe model, ViewModels, AppTheme, StateWidget, SearchFilterWidget
/// Dependencies OUT: RealtimeMenuViewModel, recipe handlers
/// Data flow: Category name → Recipe selection → Add to category
/// State management: StatefulWidget with local selection state
/// Purpose: Separate dialog for menu category recipe selection (not friend sharing)
/// Common issues: Different from RecipeSelectionDialog (friend sharing)
/// Test coverage: Unit tests for selection logic
/// Performance: Efficient with search and filtering
/// Analytics: Track recipe additions to categories
/// Code smells: Clean separation from friend sharing dialog
/// Connected to: RealtimeMenuViewModel, recipe_interaction_handler
/// Used in phases: Menu management and category building

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/recipe.dart';
import '../viewmodels/recipe_list_viewmodel.dart';
import '../widgets/common/search_filter_widget.dart'; // ✅ NY IMPORT
import '../widgets/common/state_widget.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// Dialog för att välja recept att lägga till i meny-kategori
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
  String _searchQuery = ''; // ✅ ERSATT: TextEditingController med String

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<RecipeListViewModel>(),
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
                  style: AppTheme.primaryButtonStyle,
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
    // Loading state
    if (viewModel.isLoading) {
      return StateWidget.loading(message: 'Laddar recept...');
    }

    // Error state
    if (viewModel.hasError) {
      return StateWidget.error(
        message: viewModel.error!,
        onAction: viewModel.refresh,
      );
    }

    // Empty state
    if (viewModel.recipes.isEmpty) {
      return StateWidget.noRecipes(
        onAction: () {
          Navigator.pop(context);
          Navigator.pushNamed(context, '/laggTill');
        },
      );
    }

    // Filter recipes based on search
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
        // ✅ NY: SearchFilterWidget för dialog-search
        SearchFilterWidget.searchOnly(
          searchQuery: _searchQuery,
          onSearchChanged: (query) {
            setState(() {
              _searchQuery = query;
            });
          },
          searchHint: 'Sök recept att lägga till...',
          autofocus: true,
          padding: EdgeInsets.all(AppTheme.spacingMd),
          showStats: true,
          resultCount: filteredRecipes.length,
        ),

        // Results info and actions
        if (_selectedRecipeIds.isNotEmpty)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingXs,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.primaryColor.withValues(alpha: 0.1),
                    borderRadius: AppTheme.chipRadius,
                  ),
                  child: Text(
                    '${_selectedRecipeIds.length} valda',
                    style: AppTheme.captionStyle.copyWith(
                      color: AppTheme.primaryColor,
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
          ),

        const Divider(height: 1),

        // Recipe list
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
                    final recipe = filteredRecipes[index];
                    final isSelected = _selectedRecipeIds.contains(recipe.id);

                    return _MenuRecipeListItem(
                      recipe: recipe,
                      isSelected: isSelected,
                      onSelectionChanged: (selected) {
                        setState(() {
                          if (selected) {
                            _selectedRecipeIds.add(recipe.id);
                          } else {
                            _selectedRecipeIds.remove(recipe.id);
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

  void _addSelectedRecipes(
      BuildContext context, RecipeListViewModel viewModel) {
    final selectedRecipes = viewModel.recipes
        .where((recipe) => _selectedRecipeIds.contains(recipe.id))
        .toList();

    Navigator.pop(context, selectedRecipes);
  }
}

/// List item för meny-recept-val
class _MenuRecipeListItem extends StatelessWidget {
  final Recipe recipe;
  final bool isSelected;
  final ValueChanged<bool> onSelectionChanged;

  const _MenuRecipeListItem({
    required this.recipe,
    required this.isSelected,
    required this.onSelectionChanged,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: AppTheme.listItemPadding,
      leading: ClipRRect(
        borderRadius: AppTheme.mediumRadius,
        child: recipe.imageUrls.isNotEmpty
            ? Image.network(
                recipe.imageUrls.first,
                width: AppTheme.iconSizeDisplay,
                height: AppTheme.iconSizeDisplay,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    _buildPlaceholder(),
              )
            : _buildPlaceholder(),
      ),
      title: Text(
        recipe.title,
        style: AppTheme.cardTitleStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.mealType,
            style: AppTheme.captionStyle.copyWith(
              color: AppTheme.primaryColor,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (recipe.description.isNotEmpty) ...[
            AppTheme.tinyGap,
            Text(
              recipe.description,
              style: AppTheme.captionStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          AppTheme.tinyGap,
          Row(
            children: [
              if (recipe.timeMinutes != null) ...[
                Icon(
                  Icons.access_time,
                  size: AppTheme.iconSizeInfo,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: AppTheme.spacingXxs),
                Text(
                  '${recipe.timeMinutes} min',
                  style: AppTheme.captionStyle.copyWith(fontSize: 11),
                ),
              ],
              if (recipe.portions != null) ...[
                if (recipe.timeMinutes != null) ...[
                  SizedBox(width: AppTheme.spacingSm),
                  Text(
                    '•',
                    style: AppTheme.captionStyle,
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                ],
                Icon(
                  Icons.people,
                  size: AppTheme.iconSizeInfo,
                  color: AppTheme.textSecondary,
                ),
                SizedBox(width: AppTheme.spacingXxs),
                Text(
                  '${recipe.portions} port',
                  style: AppTheme.captionStyle.copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) => onSelectionChanged(value ?? false),
        activeColor: AppTheme.primaryColor,
        shape: RoundedRectangleBorder(
          borderRadius: AppTheme.chipRadius,
        ),
      ),
      onTap: () => onSelectionChanged(!isSelected),
    );
  }

  Widget _buildPlaceholder() {
    return Container(
      width: AppTheme.iconSizeDisplay,
      height: AppTheme.iconSizeDisplay,
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Icon(
        Icons.restaurant_menu,
        color: AppTheme.primaryColor,
        size: AppTheme.iconSizeAction,
      ),
    );
  }
}
