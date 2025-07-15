// lib/widgets/common/saved_menu_ui_helper.dart

import 'package:flutter/material.dart';
import '../../constants/icon_constants.dart';
import '../../theme/app_theme.dart';
import '../../viewmodels/menu_viewmodel.dart';

/// UI Helper for SavedMenuInfo
/// Provides UI-specific methods for saved menu information
class SavedMenuUIHelper {
  /// Get color based on attribution color type
  static Color getAttributionColor(SavedMenuInfo menuInfo) {
    switch (menuInfo.attributionColorType) {
      case 'owned':
        return AppTheme.primaryColor;
      case 'modified':
        return AppTheme.accentColor;
      case 'shared':
        return AppTheme.successColor;
      default:
        return AppTheme.textSecondary;
    }
  }

  /// Get icon data from icon type
  static IconData getStatusIconData(SavedMenuInfo menuInfo) {
    switch (menuInfo.statusIcon) {
      case IconType.restaurantMenu:
        return Icons.restaurant_menu;
      case IconType.autoFixHigh:
        return Icons.auto_fix_high;
      case IconType.person:
        return Icons.person;
    }
  }
}