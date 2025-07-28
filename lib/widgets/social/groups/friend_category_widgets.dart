// lib/widgets/social/groups/friend_category_widgets.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/utility_components.dart';

/// Friend category management widgets
///
/// This module provides widgets for managing friend categories and groups,
/// including category selection and friend grouping functionality.
class FriendCategoryWidgets {
  /// Full category manager widget
  static Widget categoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    bool allowMultipleCategories = true,
    String title = 'Välj vänner',
    String subtitle = 'Välj kategorier eller individuella vänner',
  }) {
    return UtilityComponents.friendCategoryManager(
      selectedFriendIds: selectedFriendIds,
      onSelectionChanged: onSelectionChanged,
      allowMultipleCategories: allowMultipleCategories,
      title: title,
      subtitle: subtitle,
    );
  }

  /// Compact category manager for smaller spaces
  static Widget compactCategoryManager({
    required List<String> selectedFriendIds,
    required Function(List<String>) onSelectionChanged,
    int maxHeight = 300,
  }) {
    return UtilityComponents.compactFriendCategoryManager(
      selectedFriendIds: selectedFriendIds,
      onSelectionChanged: onSelectionChanged,
      maxHeight: maxHeight,
    );
  }
}