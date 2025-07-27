// lib/widgets/menu/saved_menu_ui_helper.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';

/// UI helper for SavedMenuInfo
/// Maps ViewModel data to UI elements
class SavedMenuUIHelper {
  /// Get Material icon for a SavedMenuInfo
  static IconData getIcon(SavedMenuInfo menuInfo) {
    switch (menuInfo.statusIcon) {
      case 'restaurantMenu':
        return Icons.restaurant_menu;
      case 'autoFixHigh':
        return Icons.auto_fix_high;
      case 'person':
        return Icons.person;
      default:
        return Icons.restaurant_menu; // Default fallback
    }
  }

  /// Get color for a SavedMenuInfo based on type
  static Color getAttributionColor(SavedMenuInfo menuInfo) {
    switch (menuInfo.attributionColorType) {
      case 'owned':
        return AppColors.primaryBlue;
      case 'modified':
        return AppColors.accent;
      case 'shared':
        return AppColors.textMedium;
      default:
        return AppColors.textMedium;
    }
  }
}