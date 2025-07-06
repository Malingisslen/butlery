// lib/widgets/recipe_selection_dialog.dart
// ✅ 100% AppTheme migrerad - ANVÄNDER ENDAST BEFINTLIGA APPTHEME PROPERTIES
// 🔄 UPPDATERAD: Migrerad från AppSearchBar till SearchFilterWidget.searchOnly()

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/user_profile.dart';
import '../models/recipe.dart';
import '../viewmodels/recipe_selection_viewmodel.dart';
import '../widgets/common/search_filter_widget.dart'; // ✅ NY IMPORT
import '../theme/app_theme.dart';
import '../core/injection.dart';

/// Dialog för att välja recept att dela med en vän
class RecipeSelectionDialog extends StatelessWidget {
  final UserProfile friend;

  const RecipeSelectionDialog({
    super.key,
    required this.friend,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) =>
          sl<RecipeSelectionViewModel>(param1: friend)..loadRecipes(),
      child: Consumer<RecipeSelectionViewModel>(
        builder: (context, viewModel, child) {
          return AlertDialog(
            title: Text(
              'Dela recept med ${friend.displayName}',
              style: AppTheme
                  .sectionTitleStyle, // ✅ Använder befintlig sectionTitleStyle
            ),
            contentPadding: EdgeInsets.zero,
            content: SizedBox(
              width: double.maxFinite,
              height: MediaQuery.of(context).size.height * 0.6,
              child: _buildContent(context, viewModel),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text('Avbryt', style: AppTheme.buttonTextStyle),
              ),
              if (viewModel.hasSelectedRecipes)
                FilledButton.icon(
                  onPressed: viewModel.isSharing
                      ? null
                      : () => _shareSelectedRecipes(context, viewModel),
                  style: AppTheme.primaryButtonStyle,
                  icon: viewModel.isSharing
                      ? SizedBox(
                          width: AppTheme.iconSizeAction,
                          height: AppTheme.iconSizeAction,
                          child: AppTheme.smallLoadingIndicator(),
                        )
                      : AppTheme.actionIcon(context, Icons.share),
                  label: Text(
                    viewModel.isSharing
                        ? 'Delar...'
                        : 'Dela (${viewModel.selectedCount})',
                    style: AppTheme.buttonTextStyle,
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildContent(
      BuildContext context, RecipeSelectionViewModel viewModel) {
    if (viewModel.isLoading) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AppTheme.mediumLoadingIndicator(),
            AppTheme.mediumGap,
            Text(
              'Laddar recept...',
              style: AppTheme.subtitleStyle,
            ),
          ],
        ),
      );
    }

    if (viewModel.hasError) {
      return Center(
        child: Padding(
          padding: AppTheme.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              AppTheme.errorIcon(context),
              AppTheme.mediumGap,
              Text(
                'Fel',
                style: AppTheme.sectionTitleStyle,
              ),
              AppTheme.smallGap,
              Text(
                viewModel.error!,
                style: AppTheme.bodyStyle,
                textAlign: TextAlign.center,
              ),
              AppTheme.mediumGap,
              ElevatedButton(
                onPressed: viewModel.loadRecipes,
                style: AppTheme.primaryButtonStyle,
                child: Text('Försök igen', style: AppTheme.buttonTextStyle),
              ),
            ],
          ),
        ),
      );
    }

    if (!viewModel.hasRecipes) {
      return Center(
        child: Padding(
          padding: AppTheme.screenPadding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant_menu,
                size: AppTheme.iconSizeHero,
                color: AppTheme.textSecondary,
              ),
              AppTheme.mediumGap,
              Text(
                'Inga recept',
                style: AppTheme.sectionTitleStyle,
              ),
              AppTheme.smallGap,
              Text(
                'Du har inga recept att dela ännu. Skapa ett recept först!',
                style: AppTheme.bodyStyle.copyWith(
                  color: AppTheme.textSecondary,
                ),
                textAlign: TextAlign.center,
              ),
              AppTheme.mediumGap,
              FilledButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pushNamed(context, '/laggTill');
                },
                style: AppTheme.primaryButtonStyle,
                icon: AppTheme.actionIcon(context, Icons.add),
                label: Text('Skapa recept', style: AppTheme.buttonTextStyle),
              ),
            ],
          ),
        ),
      );
    }

    return Column(
      children: [
        // 🔄 UPPDATERAD: SearchFilterWidget.searchOnly() istället för AppSearchBar
        SearchFilterWidget.searchOnly(
          searchQuery: viewModel.searchQuery,
          onSearchChanged: viewModel.updateSearch,
          searchHint: 'Sök recept...',
          padding: EdgeInsets.all(AppTheme.spacingMd),
          showStats: true, // ✨ BONUS: Visa antal resultat
          resultCount: viewModel.hasSearchResults
              ? viewModel.filteredRecipes.length
              : null,
        ),

        // Resultat info och bulk actions
        if (viewModel.searchQuery.isNotEmpty || viewModel.hasSelectedRecipes)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingMd),
            child: Row(
              children: [
                if (viewModel.searchQuery.isNotEmpty)
                  Text(
                    '${viewModel.filteredCount} av ${viewModel.totalCount} recept',
                    style: AppTheme.captionStyle,
                  ),
                if (viewModel.hasSelectedRecipes) ...[
                  if (viewModel.searchQuery.isNotEmpty) const Spacer(),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingXs,
                      vertical: AppTheme.spacingXxs,
                    ),
                    decoration: BoxDecoration(
                      color: AppTheme.primaryColor.withValues(alpha: 0.1),
                      borderRadius: AppTheme.chipRadius,
                    ),
                    child: Text(
                      '${viewModel.selectedCount} valda',
                      style: AppTheme.captionStyle.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                if (viewModel.hasSelectedRecipes)
                  TextButton(
                    onPressed: viewModel.clearSelections,
                    child: Text('Rensa val', style: AppTheme.buttonTextStyle),
                  )
                else if (viewModel.searchQuery.isNotEmpty)
                  TextButton(
                    onPressed: viewModel.clearSearch,
                    child: Text('Rensa', style: AppTheme.buttonTextStyle),
                  ),
              ],
            ),
          ),

        Divider(height: AppTheme.dividerHeight, color: AppTheme.dividerColor),

        // Receptlista
        Expanded(
          child: viewModel.hasSearchResults
              ? ListView.builder(
                  itemCount: viewModel.filteredRecipes.length,
                  itemBuilder: (context, index) {
                    final recipe = viewModel.filteredRecipes[index];
                    return _RecipeListItem(
                      recipe: recipe,
                      isSelected: viewModel.isRecipeSelected(recipe.id),
                      isAlreadyShared:
                          viewModel.isRecipeAlreadyShared(recipe.id),
                      onSelectionChanged: (selected) {
                        viewModel.toggleRecipeSelection(recipe.id);
                      },
                    );
                  },
                )
              : _buildEmptySearchState(context, viewModel),
        ),
      ],
    );
  }

  Widget _buildEmptySearchState(
      BuildContext context, RecipeSelectionViewModel viewModel) {
    return Center(
      child: Padding(
        padding: AppTheme.screenPadding,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.search_off,
              size: AppTheme.iconSizeHero,
              color: AppTheme.textSecondary,
            ),
            AppTheme.mediumGap,
            Text(
              'Inga resultat',
              style: AppTheme.sectionTitleStyle,
            ),
            AppTheme.smallGap,
            Text(
              'Inga recept matchar "${viewModel.searchQuery}"',
              style: AppTheme.bodyStyle.copyWith(
                color: AppTheme.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            AppTheme.mediumGap,
            OutlinedButton(
              onPressed: viewModel.clearSearch,
              style: AppTheme.secondaryButtonStyle,
              child: Text('Rensa sökning', style: AppTheme.buttonTextStyle),
            ),
          ],
        ),
      ),
    );
  }

  /// ✅ FIXAD: Spara shareMessage FÖRE delningen
  Future<void> _shareSelectedRecipes(
      BuildContext context, RecipeSelectionViewModel viewModel) async {
    // ✅ KRITISKT: Spara meddelandet FÖRE delningen (innan clearSelections())
    final shareMessage = viewModel.getShareMessage();

    final success = await viewModel.shareSelectedRecipes();

    if (success && context.mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            shareMessage, // ✅ Använd det sparade meddelandet
            style: AppTheme.bodyStyle.copyWith(
                color: Colors.white), // ✅ Använder befintlig bodyStyle
          ),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 3), // ✅ Hårdkodad duration
        ),
      );
    } else if (!success && context.mounted) {
      // ✅ BONUS: Visa felmeddelande om delningen misslyckas
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            viewModel.error ?? 'Kunde inte dela recept',
            style: AppTheme.bodyStyle.copyWith(
                color: Colors.white), // ✅ Använder befintlig bodyStyle
          ),
          backgroundColor: AppTheme.errorColor,
          duration: const Duration(seconds: 3), // ✅ Hårdkodad duration
        ),
      );
    }
  }
}

/// ✅ FINAL: RecipeListItem - 100% AppTheme, endast befintliga properties
class _RecipeListItem extends StatelessWidget {
  final Recipe recipe;
  final bool isSelected;
  final bool isAlreadyShared;
  final ValueChanged<bool> onSelectionChanged;

  const _RecipeListItem({
    required this.recipe,
    required this.isSelected,
    required this.isAlreadyShared,
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
      title: Row(
        children: [
          Expanded(
            child: Text(
              recipe.title,
              style: isAlreadyShared
                  ? AppTheme.cardTitleStyle.copyWith(
                      color: AppTheme
                          .sharedRecipeTextColor) // ✅ Använder befintlig sharedRecipeTextColor
                  : AppTheme.cardTitleStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // ✅ "Delad" chip med befintlig AppTheme styling
          if (isAlreadyShared)
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: AppTheme.spacingXs,
                vertical: AppTheme.spacingXxs,
              ),
              decoration: AppTheme
                  .sharedChipDecoration, // ✅ Använder befintlig decoration
              child: Text(
                'Delad',
                style: AppTheme
                    .sharedChipTextStyle, // ✅ Använder befintlig textStyle
              ),
            ),
        ],
      ),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            recipe.mealType,
            style: isAlreadyShared
                ? AppTheme.captionStyle.copyWith(
                    color: AppTheme.sharedRecipeTextColor,
                    fontWeight: FontWeight.w600,
                  )
                : AppTheme.captionStyle.copyWith(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
          ),
          if (recipe.description.isNotEmpty)
            Text(
              recipe.description,
              style: isAlreadyShared
                  ? AppTheme.captionStyle
                      .copyWith(color: AppTheme.sharedRecipeTextColor)
                  : AppTheme.captionStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          AppTheme.tinyGap,
          // Extra info med AppTheme styling
          Row(
            children: [
              if (recipe.timeMinutes != null) ...[
                Icon(
                  Icons.access_time,
                  size: AppTheme.iconSizeInfo,
                  color: isAlreadyShared
                      ? AppTheme.sharedRecipeIconColor
                      : AppTheme.textSecondary,
                ),
                AppTheme.tinyGap,
                Text(
                  '${recipe.timeMinutes} min',
                  style: isAlreadyShared
                      ? AppTheme.captionStyle.copyWith(
                          color: AppTheme.sharedRecipeIconColor,
                          fontSize: 11,
                        )
                      : AppTheme.captionStyle.copyWith(fontSize: 11),
                ),
              ],
              if (recipe.portions != null) ...[
                if (recipe.timeMinutes != null) ...[
                  AppTheme.smallGap,
                  Text(
                    '•',
                    style: isAlreadyShared
                        ? AppTheme.captionStyle
                            .copyWith(color: AppTheme.sharedRecipeIconColor)
                        : AppTheme.captionStyle,
                  ),
                  AppTheme.smallGap,
                ],
                Icon(
                  Icons.people,
                  size: AppTheme.iconSizeInfo,
                  color: isAlreadyShared
                      ? AppTheme.sharedRecipeIconColor
                      : AppTheme.textSecondary,
                ),
                AppTheme.tinyGap,
                Text(
                  '${recipe.portions} port',
                  style: isAlreadyShared
                      ? AppTheme.captionStyle.copyWith(
                          color: AppTheme.sharedRecipeIconColor,
                          fontSize: 11,
                        )
                      : AppTheme.captionStyle.copyWith(fontSize: 11),
                ),
              ],
            ],
          ),
        ],
      ),
      trailing: Checkbox(
        value: isSelected,
        onChanged: (value) => onSelectionChanged(value ?? false),
        activeColor: isAlreadyShared
            ? AppTheme.sharedRecipeTextColor
            : AppTheme.primaryColor,
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
        color: isAlreadyShared
            ? AppTheme.sharedRecipeBackgroundColor
            : AppTheme.primaryColor.withValues(alpha: 0.1),
        borderRadius: AppTheme.mediumRadius,
      ),
      child: Icon(
        Icons.restaurant_menu,
        color: isAlreadyShared
            ? AppTheme.sharedRecipeIconColor
            : AppTheme.primaryColor,
        size: AppTheme.iconSizeAction,
      ),
    );
  }
}
