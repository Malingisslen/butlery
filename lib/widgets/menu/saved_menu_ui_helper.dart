// lib/widgets/menu/saved_menu_ui_helper.dart

import 'package:flutter/material.dart';
import '../../constants/icon_constants.dart';
import '../../viewmodels/menu_viewmodel.dart';

/// UI helper for SavedMenuInfo
/// Maps ViewModel data to UI elements
class SavedMenuUIHelper {
  /// Get Material icon for a SavedMenuInfo
  static IconData getIcon(SavedMenuInfo menuInfo) {
    switch (menuInfo.statusIcon) {
      case IconType.restaurantMenu:
        return Icons.restaurant_menu;
      case IconType.autoFixHigh:
        return Icons.auto_fix_high;
      case IconType.person:
        return Icons.person;
    }
  }

  /// Get color for a SavedMenuInfo based on type
  static Color getAttributionColor(SavedMenuInfo menuInfo) {
    switch (menuInfo.attributionColorType) {
      case 'owned':
        return const Color(0xFF4A7C93);
      case 'modified':
        return const Color(0xFF60A5FA);
      case 'shared':
        return const Color(0xFF6B7280);
      default:
        return const Color(0xFF6B7280);
    }
  }
}