// lib/widgets/common/dialogs/recipe_selection/recipe_share_info_bar.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Filtered count, selected count and the matching clear action, shared by
/// the friend and group recipe-sharing dialogs. Takes plain values because
/// the two dialogs are driven by different view models.
class RecipeShareInfoBar extends StatelessWidget {
  final String searchQuery;
  final int filteredCount;
  final int totalCount;
  final bool hasSelectedRecipes;
  final int selectedCount;
  final VoidCallback onClearSelection;
  final VoidCallback onClearSearch;

  const RecipeShareInfoBar({
    super.key,
    required this.searchQuery,
    required this.filteredCount,
    required this.totalCount,
    required this.hasSelectedRecipes,
    required this.selectedCount,
    required this.onClearSelection,
    required this.onClearSearch,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space12),
      child: Row(
        children: [
          if (searchQuery.isNotEmpty)
            Text(
              context.l10n.dialogFilteredRecipeCount(
                filteredCount,
                totalCount,
              ),
              style: AppTextStyles.bodySmall,
            ),
          if (hasSelectedRecipes) ...[
            if (searchQuery.isNotEmpty) const Spacer(),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.space4,
                vertical: AppDimensions.space4,
              ),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.zero,
              ),
              child: Text(
                context.l10n.dialogSelectedCount(selectedCount),
                style: AppTextStyles.labelMedium.copyWith(
                  color: Theme.of(context).colorScheme.onSurface,
                ),
              ),
            ),
          ],
          const Spacer(),
          if (hasSelectedRecipes)
            TextButton(
              onPressed: onClearSelection,
              child: Text(
                context.l10n.dialogClearSelection,
                style: AppTextStyles.labelLarge,
              ),
            )
          else if (searchQuery.isNotEmpty)
            TextButton(
              onPressed: onClearSearch,
              child: Text(
                context.l10n.commonClear,
                style: AppTextStyles.labelLarge,
              ),
            ),
        ],
      ),
    );
  }
}
