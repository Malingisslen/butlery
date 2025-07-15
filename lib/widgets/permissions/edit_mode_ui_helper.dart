// lib/widgets/permissions/edit_mode_ui_helper.dart

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import '../../models/permissions/edit_mode.dart';

/// UI helper class for EditMode enum
/// Separates UI logic from the model layer to maintain clean architecture
class EditModeUIHelper {
  /// Get color for a specific edit mode
  static Color getColor(EditMode mode, BuildContext context) {
    switch (mode) {
      case EditMode.owner:
        return AppTheme.primaryColor;
      case EditMode.collaborative:
        return AppTheme.successColor;
      case EditMode.readOnlyWithFork:
        return AppTheme.warningColor;
      case EditMode.noAccess:
        return AppTheme.errorColor;
    }
  }

  /// Get icon for a specific edit mode
  static IconData getIcon(EditMode mode) {
    switch (mode) {
      case EditMode.owner:
        return Icons.edit;
      case EditMode.collaborative:
        return Icons.people;
      case EditMode.readOnlyWithFork:
        return Icons.visibility;
      case EditMode.noAccess:
        return Icons.block;
    }
  }

  /// Get icon with color for a specific edit mode
  static Icon getIconWithColor(EditMode mode, BuildContext context) {
    return Icon(
      getIcon(mode),
      color: getColor(mode, context),
    );
  }

  /// Get styled text for edit mode description
  static Widget getStyledDescription(EditMode mode, BuildContext context) {
    return Text(
      mode.description,
      style: AppTheme.bodyStyle.copyWith(
        color: getColor(mode, context),
      ),
    );
  }
}