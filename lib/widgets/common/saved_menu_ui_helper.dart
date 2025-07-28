// lib/widgets/common/saved_menu_ui_helper.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/viewmodels/menu/menu_state_manager.dart';

/// UI Helper for SavedMenuInfo
/// Provides UI-specific methods for saved menu information
class SavedMenuUIHelper {
  /// Get color based on attribution color type
  static Color getAttributionColor(SavedMenuInfo menuInfo) {
    switch (menuInfo.attributionColorType) {
      case 'owned':
        return AppColors.primaryBlue;
      case 'modified':
        return AppColors.accent;
      case 'shared':
        return AppColors.success;
      default:
        return AppColors.textSecondary;
    }
  }

  /// Get icon data from icon type
  static IconData getStatusIconData(SavedMenuInfo menuInfo) {
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
}