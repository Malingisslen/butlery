// lib/widgets/common/friends/category_selection_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
// AppColors import removed - using theme-aware colors
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Category Selection Widgets
/// Handles ONLY category selection UI components and interaction widgets.
/// This includes category chips, selectors, and selection utilities.
class CategorySelectionWidgets {
  /// Build friend category selector
  static Widget friendCategorySelector(
    BuildContext context, {
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    bool allowMultipleSelection = true,
    String? title,
    EdgeInsets? padding,
    bool showSelectAll = true,
    bool showCreateNew = true,
    VoidCallback? onCreateNew,
  }) {
    return Padding(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingL),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null) ...[
            Text(
              title,
              style: AppTextStyles.sectionTitleStyle,
            ),
            const SizedBox(height: AppDimensions.spacingMd),
          ],
          if (showSelectAll) ...[
            Row(
              children: [
                TextButton.icon(
                  onPressed: () {
                    if (allowMultipleSelection) {
                      for (final category in categories) {
                        if (!selectedCategoryIds.contains(category.id)) {
                          onCategoryToggled(category.id);
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.select_all),
                  label: Text(context.l10n.commonSelectAll),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                TextButton.icon(
                  onPressed: () {
                    for (final categoryId in selectedCategoryIds.toList()) {
                      onCategoryToggled(categoryId);
                    }
                  },
                  icon: const Icon(Icons.clear_all),
                  label: Text(context.l10n.commonClearAll),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
          ],
          Wrap(
            spacing: AppDimensions.spacingS,
            runSpacing: AppDimensions.spacingS,
            children: categories
                .map(
                  (category) => friendCategoryChip(
                    context,
                    category: category,
                    isSelected: selectedCategoryIds.contains(category.id),
                    onTap: () => onCategoryToggled(category.id),
                  ),
                )
                .toList(),
          ),
          if (showCreateNew && onCreateNew != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Center(
              child: TextButton.icon(
                onPressed: onCreateNew,
                icon: const Icon(Icons.add),
                label: Text(context.l10n.friendCreateNewCategory),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build friend category chip
  static Widget friendCategoryChip(
    BuildContext context, {
    required FriendCategory category,
    required bool isSelected,
    required VoidCallback onTap,
    bool showCount = true,
    bool enabled = true,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            category.emoji != null ? Icons.emoji_emotions : Icons.group,
            size: AppDimensions.iconSizeS,
            color: isSelected
                ? Theme.of(context).colorScheme.onSurface
                : Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(category.name),
          if (showCount) ...[
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              '(${category.friendUserIds.length})',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: isSelected
                    ? Theme.of(context).colorScheme.onSurface
                    : Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: enabled ? (_) => onTap() : null,
      backgroundColor: Theme.of(context).colorScheme.surface,
      selectedColor: Theme.of(context).colorScheme.primary,
      checkmarkColor: Theme.of(context).colorScheme.onSurface,
      labelStyle: Theme.of(context).textTheme.bodyMedium?.copyWith(
        color: isSelected
            ? Theme.of(context).colorScheme.onSurface
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Build compact category chip for smaller spaces
  static Widget compactCategoryChip(
    BuildContext context, {
    required FriendCategory category,
    required bool isSelected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return FilterChip(
      label: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (category.emoji != null && category.emoji!.isNotEmpty) ...[
            Text(category.emoji!),
            const SizedBox(width: AppDimensions.spacingXs),
          ],
          Text(category.name),
          const SizedBox(width: AppDimensions.spacingXs),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.spacingXs,
              vertical: AppDimensions.borderWidthStandard,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? Theme.of(context).colorScheme.surfaceContainerHighest
                        .withValues(alpha: AppDimensions.opacityVeryDark)
                  : Theme.of(context).colorScheme.primary.withValues(
                      alpha: AppDimensions.opacityVeryLight,
                    ),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
            ),
            child: Text(
              '${category.friendCount}',
              style: AppTextStyles.badge.copyWith(
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: enabled ? (_) => onTap() : null,
      selectedColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: AppDimensions.opacityLight),
      checkmarkColor: Theme.of(context).colorScheme.primary,
      backgroundColor: Theme.of(context).colorScheme.surface,
      side: BorderSide(
        color: isSelected
            ? Theme.of(context).colorScheme.primary
            : Theme.of(context).colorScheme.onSurfaceVariant,
      ),
    );
  }

  /// Build horizontal category selector strip
  static Widget horizontalCategorySelector(
    BuildContext context, {
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    double height = 60,
    EdgeInsets? padding,
  }) {
    return Container(
      height: height,
      padding:
          padding ??
          const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.spacingMd,
        ),
        itemCount: categories.length,
        separatorBuilder: (context, index) =>
            const SizedBox(width: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          final category = categories[index];
          return compactCategoryChip(
            context,
            category: category,
            isSelected: selectedCategoryIds.contains(category.id),
            onTap: () => onCategoryToggled(category.id),
          );
        },
      ),
    );
  }

  /// Build category selection summary
  static Widget categorySelectionSummary({
    required Set<String> selectedCategoryIds,
    required List<FriendCategory> categories,
    required VoidCallback onClear,
    EdgeInsets? padding,
  }) {
    if (selectedCategoryIds.isEmpty) return const SizedBox.shrink();

    final selectedCategories = categories
        .where((cat) => selectedCategoryIds.contains(cat.id))
        .toList();

    final totalFriends = selectedCategories.fold<int>(
      0,
      (sum, cat) => sum + cat.friendUserIds.length,
    );

    return Builder(
      builder: (context) => Container(
        padding: padding ?? const EdgeInsets.all(AppDimensions.spacingMd),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(
            alpha: AppDimensions.opacityVeryLight,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          border: Border.all(
            color: Theme.of(context).colorScheme.primary.withValues(
              alpha: AppDimensions.opacityMediumLight,
            ),
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingXs),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.primary,
                borderRadius: BorderRadius.circular(
                  AppDimensions.borderRadius6,
                ),
              ),
              child: Icon(
                Icons.category,
                color: Theme.of(context).colorScheme.surfaceContainerHighest,
                size: AppDimensions.iconSizeS,
              ),
            ),
            const SizedBox(width: AppDimensions.spacingMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    context.l10n.friendSelectedCategories,
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                  Text(
                    context.l10n.friendSelectedCategoriesSummary(
                      selectedCategories.length,
                      totalFriends,
                    ),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onClear,
              icon: const Icon(Icons.clear, size: AppDimensions.iconSize18),
              label: Text(context.l10n.commonClear),
              style: TextButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.primary,
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingS,
                  vertical: AppDimensions.spacingXs,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Build category multi-select dropdown
  static Widget categoryMultiSelectDropdown({
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    String? hint,
    double? width,
  }) {
    return Builder(
      builder: (context) => Container(
        width: width,
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
        ),
        child: ExpansionTile(
          title: Text(
            selectedCategoryIds.isEmpty
                ? (hint ?? context.l10n.friendSelectCategories)
                : context.l10n.friendCategoriesSelected(
                    selectedCategoryIds.length,
                  ),
            style: AppTextStyles.bodyMedium,
          ),
          children: categories.map((category) {
            final isSelected = selectedCategoryIds.contains(category.id);
            return CheckboxListTile(
              value: isSelected,
              onChanged: (_) => onCategoryToggled(category.id),
              title: Text(category.name),
              subtitle: Text(
                context.l10n.friendFriendsCount(category.friendUserIds.length),
              ),
              dense: true,
              activeColor: Theme.of(context).colorScheme.primary,
            );
          }).toList(),
        ),
      ),
    );
  }
}
