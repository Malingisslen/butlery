// lib/widgets/common/friends/category_selection_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Category Selection Widgets
/// Handles ONLY category selection UI components and interaction widgets.
/// This includes category chips, selectors, and selection utilities.
class CategorySelectionWidgets {
  /// Build friend category selector
  static Widget friendCategorySelector({
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
                      // Select all categories
                      for (final category in categories) {
                        if (!selectedCategoryIds.contains(category.id)) {
                          onCategoryToggled(category.id);
                        }
                      }
                    }
                  },
                  icon: const Icon(Icons.select_all),
                  label: const Text('Välj alla'),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                TextButton.icon(
                  onPressed: () {
                    // Clear all selections
                    for (final categoryId in selectedCategoryIds.toList()) {
                      onCategoryToggled(categoryId);
                    }
                  },
                  icon: const Icon(Icons.clear_all),
                  label: const Text('Rensa alla'),
                ),
              ],
            ),
            const SizedBox(height: AppDimensions.spacingMd),
          ],
          Wrap(
            spacing: AppDimensions.spacingS,
            runSpacing: AppDimensions.spacingS,
            children: categories.map((category) => friendCategoryChip(
              category: category,
              isSelected: selectedCategoryIds.contains(category.id),
              onTap: () => onCategoryToggled(category.id),
            )).toList(),
          ),
          if (showCreateNew && onCreateNew != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Center(
              child: TextButton.icon(
                onPressed: onCreateNew,
                icon: const Icon(Icons.add),
                label: const Text('Skapa ny kategori'),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Build friend category chip
  static Widget friendCategoryChip({
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
            size: 16,
            color: isSelected ? AppColors.textDark : AppColors.textMedium,
          ),
          const SizedBox(width: AppDimensions.spacingXs),
          Text(category.name),
          if (showCount) ...[
            const SizedBox(width: AppDimensions.spacingXs),
            Text(
              '(${category.friendUserIds.length})',
              style: TextStyle(
                fontSize: 12,
                color: isSelected ? AppColors.textDark : AppColors.textMedium,
              ),
            ),
          ],
        ],
      ),
      selected: isSelected,
      onSelected: enabled ? (_) => onTap() : null,
      backgroundColor: AppColors.backgroundBeige,
      selectedColor: AppColors.primaryBlue,
      checkmarkColor: AppColors.textDark,
      labelStyle: TextStyle(
        color: isSelected ? AppColors.textDark : AppColors.textMedium,
      ),
    );
  }

  /// Build compact category chip for smaller spaces
  static Widget compactCategoryChip({
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
              vertical: 1,
            ),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppColors.neutralLight.withValues(alpha: 0.8)
                  : AppColors.primaryBlue.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius8),
            ),
            child: Text(
              '${category.friendCount}',
              style: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.bold,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
        ],
      ),
      selected: isSelected,
      onSelected: enabled ? (_) => onTap() : null,
      selectedColor: AppColors.primaryBlue.withValues(alpha: 0.2),
      checkmarkColor: AppColors.primaryBlue,
      backgroundColor: AppColors.backgroundBeige,
      side: BorderSide(
        color: isSelected ? AppColors.primaryBlue : AppColors.textMedium,
      ),
    );
  }

  /// Build horizontal category selector strip
  static Widget horizontalCategorySelector({
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    double height = 60,
    EdgeInsets? padding,
  }) {
    return Container(
      height: height,
      padding: padding ?? const EdgeInsets.symmetric(vertical: AppDimensions.spacingS),
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingMd),
        itemCount: categories.length,
        separatorBuilder: (context, index) => const SizedBox(width: AppDimensions.spacingS),
        itemBuilder: (context, index) {
          final category = categories[index];
          return compactCategoryChip(
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
    
    final totalFriends = selectedCategories
        .fold<int>(0, (sum, cat) => sum + cat.friendUserIds.length);

    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        border: Border.all(
          color: AppColors.primaryBlue.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingXs),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              borderRadius: BorderRadius.circular(AppDimensions.borderRadius6),
            ),
            child: const Icon(
              Icons.category,
              color: AppColors.neutralLight,
              size: AppDimensions.iconSizeS,
            ),
          ),
          const SizedBox(width: AppDimensions.spacingMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Valda kategorier',
                  style: AppTextStyles.labelMedium.copyWith(
                    color: AppColors.primaryBlue,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '${selectedCategories.length} ${selectedCategories.length == 1 ? 'kategori' : 'kategorier'} ($totalFriends vänner)',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.primaryBlue,
                  ),
                ),
              ],
            ),
          ),
          TextButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.clear, size: 18.0),
            label: const Text('Rensa'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryBlue,
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingS,
                vertical: AppDimensions.spacingXs,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Build category multi-select dropdown
  static Widget categoryMultiSelectDropdown({
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    String hint = 'Välj kategorier',
    double? width,
  }) {
    return Container(
      width: width,
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.textMedium),
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusS),
      ),
      child: ExpansionTile(
        title: Text(
          selectedCategoryIds.isEmpty 
              ? hint 
              : '${selectedCategoryIds.length} kategorier valda',
          style: AppTextStyles.bodyMedium,
        ),
        children: categories.map((category) {
          final isSelected = selectedCategoryIds.contains(category.id);
          return CheckboxListTile(
            value: isSelected,
            onChanged: (_) => onCategoryToggled(category.id),
            title: Text(category.name),
            subtitle: Text('${category.friendUserIds.length} vänner'),
            dense: true,
            activeColor: AppColors.primaryBlue,
          );
        }).toList(),
      ),
    );
  }
}