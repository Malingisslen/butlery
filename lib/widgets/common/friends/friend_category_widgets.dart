// lib/widgets/common/friends/friend_category_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/friend_category.dart';

// Import focused widget files
import 'package:butlery/widgets/common/friends/category_selection_widgets.dart';
import 'package:butlery/widgets/common/friends/category_display_widgets.dart';
import 'package:butlery/widgets/common/friends/friend_category_manager.dart';

/// FriendCategoryWidgets (Facade)
/// Maintains backward compatibility while delegating to focused widget classes.
/// This facade provides the same interface as the original monolithic widget class
/// while internally using the 3 focused widget classes for better separation of concerns.
/// Focused Widget Classes:
/// - CategorySelectionWidgets: Category selection UI components and interaction widgets
/// - CategoryDisplayWidgets: Category display and presentation components  
/// - FriendCategoryManager: Interactive friend category management with state
class FriendCategoryWidgets {
  // ===== MAIN MANAGER WIDGETS (Delegate to FriendCategoryManager) =====
  
  /// Complete friend category manager for social sharing
  static Widget friendCategoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    bool allowMultipleCategories = true,
    String title = 'Välj vänner',
    String subtitle = 'Välj kategorier eller individuella vänner',
  }) {
    return FriendCategoryManager(
      selectedFriendIds: selectedFriendIds,
      onSelectionChanged: onSelectionChanged,
      allowMultipleCategories: allowMultipleCategories,
      title: title,
      subtitle: subtitle,
    );
  }

  /// Compact variant for smaller spaces
  static Widget compactFriendCategoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    int maxHeight = 300,
  }) {
    return Container(
      constraints: BoxConstraints(maxHeight: maxHeight.toDouble()),
      child: friendCategoryManager(
        selectedFriendIds: selectedFriendIds,
        onSelectionChanged: onSelectionChanged,
        title: 'Välj vänner',
        subtitle: 'Snabbval via kategorier',
      ),
    );
  }

  // ===== CATEGORY SELECTION WIDGETS (Delegate to CategorySelectionWidgets) =====
  
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
    return CategorySelectionWidgets.friendCategorySelector(
      categories: categories,
      selectedCategoryIds: selectedCategoryIds,
      onCategoryToggled: onCategoryToggled,
      allowMultipleSelection: allowMultipleSelection,
      title: title,
      padding: padding,
      showSelectAll: showSelectAll,
      showCreateNew: showCreateNew,
      onCreateNew: onCreateNew,
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
    return CategorySelectionWidgets.friendCategoryChip(
      category: category,
      isSelected: isSelected,
      onTap: onTap,
      showCount: showCount,
      enabled: enabled,
    );
  }

  // ===== CATEGORY DISPLAY WIDGETS (Delegate to CategoryDisplayWidgets) =====
  
  /// Build category list view
  static Widget categoryList({
    required List<FriendCategory> categories,
    required Function(FriendCategory) onCategoryTap,
    bool showMemberCount = true,
    EdgeInsets? padding,
  }) {
    return CategoryDisplayWidgets.categoryList(
      categories: categories,
      onCategoryTap: onCategoryTap,
      showMemberCount: showMemberCount,
      padding: padding,
    );
  }

  /// Build category grid view
  static Widget categoryGrid({
    required List<FriendCategory> categories,
    required Function(FriendCategory) onCategoryTap,
    int crossAxisCount = 2,
    EdgeInsets? padding,
  }) {
    return CategoryDisplayWidgets.categoryGrid(
      categories: categories,
      onCategoryTap: onCategoryTap,
      crossAxisCount: crossAxisCount,
      padding: padding,
    );
  }

  /// Build category statistics widget
  static Widget categoryStatistics({
    required List<FriendCategory> categories,
    EdgeInsets? padding,
  }) {
    return CategoryDisplayWidgets.categoryStatistics(
      categories: categories,
      padding: padding,
    );
  }

  // ===== ADDITIONAL UTILITY METHODS (Delegate to appropriate classes) =====
  
  /// Build horizontal category selector strip
  static Widget horizontalCategorySelector({
    required List<FriendCategory> categories,
    required Set<String> selectedCategoryIds,
    required Function(String) onCategoryToggled,
    double height = 60,
    EdgeInsets? padding,
  }) {
    return CategorySelectionWidgets.horizontalCategorySelector(
      categories: categories,
      selectedCategoryIds: selectedCategoryIds,
      onCategoryToggled: onCategoryToggled,
      height: height,
      padding: padding,
    );
  }

  /// Build category selection summary
  static Widget categorySelectionSummary({
    required Set<String> selectedCategoryIds,
    required List<FriendCategory> categories,
    required VoidCallback onClear,
    EdgeInsets? padding,
  }) {
    return CategorySelectionWidgets.categorySelectionSummary(
      selectedCategoryIds: selectedCategoryIds,
      categories: categories,
      onClear: onClear,
      padding: padding,
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
    return CategorySelectionWidgets.categoryMultiSelectDropdown(
      categories: categories,
      selectedCategoryIds: selectedCategoryIds,
      onCategoryToggled: onCategoryToggled,
      hint: hint,
      width: width,
    );
  }

  /// Build compact category chip for smaller spaces
  static Widget compactCategoryChip({
    required FriendCategory category,
    required bool isSelected,
    required VoidCallback onTap,
    bool enabled = true,
  }) {
    return CategorySelectionWidgets.compactCategoryChip(
      category: category,
      isSelected: isSelected,
      onTap: onTap,
      enabled: enabled,
    );
  }

  /// Build compact category card
  static Widget categoryCard({
    required FriendCategory category,
    required VoidCallback onTap,
    bool showMemberCount = true,
    bool showDescription = true,
    double? width,
    double? height,
  }) {
    return CategoryDisplayWidgets.categoryCard(
      category: category,
      onTap: onTap,
      showMemberCount: showMemberCount,
      showDescription: showDescription,
      width: width,
      height: height,
    );
  }

  /// Build category carousel/horizontal list
  static Widget categoryCarousel({
    required List<FriendCategory> categories,
    required Function(FriendCategory) onCategoryTap,
    double height = 120,
    EdgeInsets? padding,
  }) {
    return CategoryDisplayWidgets.categoryCarousel(
      categories: categories,
      onCategoryTap: onCategoryTap,
      height: height,
      padding: padding,
    );
  }

  /// Build category summary row
  static Widget categorySummaryRow({
    required List<FriendCategory> categories,
    bool showTotalMembers = true,
    EdgeInsets? padding,
  }) {
    return CategoryDisplayWidgets.categorySummaryRow(
      categories: categories,
      showTotalMembers: showTotalMembers,
      padding: padding,
    );
  }

  /// Build empty categories state
  static Widget emptyState({
    String title = 'Inga kategorier',
    String subtitle = 'Skapa din första vänkategori',
    VoidCallback? onCreateCategory,
    EdgeInsets? padding,
  }) {
    return CategoryDisplayWidgets.emptyState(
      title: title,
      subtitle: subtitle,
      onCreateCategory: onCreateCategory,
      padding: padding,
    );
  }
}