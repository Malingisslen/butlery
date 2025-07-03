// lib/views/realtime/components/category_section.dart

import 'package:flutter/material.dart';
import '../../../viewmodels/realtime_menu_viewmodel.dart';
import '../../../models/recipe.dart';
import '../../../widgets/content_card.dart';
import '../handlers/recipe_interaction_handler.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Category Section - SINGLE RESPONSIBILITY för en kategoris UI layout
/// Purpose: BARA hantera UI för en kategori i menyn, delegera interactions till handler

/// Komponent för en kategori i menyn (ersätter DaySection)
class CategorySection extends StatelessWidget {
  final RealtimeMenuViewModel viewModel;
  final RecipeInteractionHandler recipeHandler;
  final String categoryName;
  final bool isSelected;

  const CategorySection({
    super.key,
    required this.viewModel,
    required this.recipeHandler,
    required this.categoryName,
    required this.isSelected,
  });

  @override
  Widget build(BuildContext context) {
    final recipes = viewModel.menuWithOptimisticChanges[categoryName] ?? [];

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: isSelected ? 4 : 1,
        child: Column(
          children: [
            // Category header
            _buildCategoryHeader(context, recipes),

            // Category content (expandable)
            AnimatedCrossFade(
              duration: const Duration(milliseconds: 300),
              crossFadeState: isSelected
                  ? CrossFadeState.showSecond
                  : CrossFadeState.showFirst,
              firstChild: const SizedBox.shrink(),
              secondChild: _buildCategoryContent(context, recipes),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryHeader(BuildContext context, List<Recipe> recipes) {
    return InkWell(
      onTap: () => viewModel.selectCategory(isSelected ? null : categoryName),
      child: Container(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            // Category icon
            _getCategoryIcon(categoryName),
            const SizedBox(width: 12),

            // Category name
            Expanded(
              child: Text(
                categoryName.toUpperCase(),
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: isSelected
                          ? Theme.of(context).colorScheme.primary
                          : null,
                    ),
              ),
            ),

            // Recipe count
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 8,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: recipes.isEmpty
                    ? Colors.grey.withValues()
                    : Theme.of(context).colorScheme.primary.withValues(),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                '${recipes.length}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                  color: recipes.isEmpty
                      ? Colors.grey
                      : Theme.of(context).colorScheme.primary,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Expand icon
            Icon(
              isSelected ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
              color: isSelected ? Theme.of(context).colorScheme.primary : null,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryContent(BuildContext context, List<Recipe> recipes) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Recipes list
          if (recipes.isNotEmpty) ...[
            ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: recipes.length,
              onReorder: (oldIndex, newIndex) {
                recipeHandler.handleRecipeReorder(
                    categoryName, oldIndex, newIndex);
              },
              itemBuilder: (context, index) {
                final recipe = recipes[index];
                return _buildRecipeItem(context, recipe, index);
              },
            ),
            const SizedBox(height: 12),
          ],

          // Action buttons row
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              // Add recipe button
              if (viewModel.canEdit)
                OutlinedButton.icon(
                  onPressed: () =>
                      recipeHandler.showAddRecipeDialog(categoryName),
                  icon: const Icon(Icons.add),
                  label: Text(
                    recipes.isEmpty ? 'Lägg till recept' : 'Lägg till fler',
                  ),
                ),

              // Regenerate category button (AI-funktion)
              if (viewModel.canEdit && recipes.isNotEmpty)
                OutlinedButton.icon(
                  onPressed: () =>
                      recipeHandler.showRegenerateCategoryDialog(categoryName),
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerera'),
                ),

              // Clear category button
              if (recipes.isNotEmpty && viewModel.canEdit)
                TextButton.icon(
                  onPressed: () =>
                      recipeHandler.confirmClearCategory(categoryName),
                  icon: const Icon(Icons.clear_all, color: Colors.red),
                  label: const Text(
                    'Rensa',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRecipeItem(BuildContext context, Recipe recipe, int index) {
    return Container(
      key: ValueKey('${recipe.id}_$index'),
      margin: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('dismiss_${recipe.id}_$index'),
        direction: viewModel.canEdit
            ? DismissDirection.endToStart
            : DismissDirection.none,
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 16),
          decoration: BoxDecoration(
            color: Colors.red,
            borderRadius: BorderRadius.circular(8),
          ),
          child: const Icon(
            Icons.delete,
            color: Colors.white,
          ),
        ),
        confirmDismiss: (direction) async {
          return await recipeHandler.confirmRemoveRecipe(recipe.title);
        },
        onDismissed: (direction) {
          viewModel.removeRecipeFromCategory(categoryName, index);
        },
        child: ContentCard.recipe(
          recipe: recipe,
          onTap: () => recipeHandler.showRecipeDetails(recipe),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Move recipe button
              if (viewModel.canEdit &&
                  (viewModel.currentMenu?.categories.length ?? 0) > 1)
                IconButton(
                  icon: const Icon(Icons.move_up, size: 20),
                  onPressed: () => recipeHandler.showMoveRecipeDialog(
                    categoryName,
                    index,
                    recipe,
                  ),
                  tooltip: 'Flytta till annan kategori',
                ),

              // Drag handle
              if (viewModel.canEdit)
                ReorderableDragStartListener(
                  index: index,
                  child: const Icon(
                    Icons.drag_handle,
                    color: Colors.grey,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  /// Få ikon för kategori
  Widget _getCategoryIcon(String categoryName) {
    IconData iconData;
    Color? color;

    switch (categoryName.toLowerCase()) {
      case 'middag':
        iconData = Icons.dinner_dining;
        color = Colors.orange;
        break;
      case 'lunch':
        iconData = Icons.lunch_dining;
        color = Colors.green;
        break;
      case 'frukost':
        iconData = Icons.breakfast_dining;
        color = Colors.amber;
        break;
      case 'mellanmål':
        iconData = Icons.cookie;
        color = Colors.brown;
        break;
      case 'dessert':
        iconData = Icons.cake;
        color = Colors.pink;
        break;
      case 'bakningar':
        iconData = Icons.bakery_dining;
        color = Colors.deepOrange;
        break;
      default:
        iconData = Icons.restaurant;
        color = Colors.grey;
    }

    return Icon(
      iconData,
      color: color,
      size: 24,
    );
  }
}
