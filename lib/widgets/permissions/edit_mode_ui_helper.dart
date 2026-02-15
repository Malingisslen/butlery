// lib/widgets/permissions/edit_mode_ui_helper.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/models/permissions/edit_mode.dart';

/// UI helper class for EditMode enum
/// Separates UI logic from the model layer to maintain clean architecture
class EditModeUIHelper {
  /// Get color for a specific edit mode
  static Color getColor(EditMode mode, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (mode) {
      case EditMode.owner:
      case EditMode.edit:
        return cs.primary;
      case EditMode.collaborative:
        return context.butleryColors.success;
      case EditMode.readOnlyWithFork:
      case EditMode.view:
        return context.butleryColors.warning;
      case EditMode.noAccess:
        return cs.error;
    }
  }

  /// Get icon for a specific edit mode
  static IconData getIcon(EditMode mode) {
    switch (mode) {
      case EditMode.owner:
      case EditMode.edit:
        return Icons.edit;
      case EditMode.collaborative:
        return Icons.people;
      case EditMode.readOnlyWithFork:
      case EditMode.view:
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
      style: AppTextStyles.bodyLarge.copyWith(
        color: getColor(mode, context),
      ),
    );
  }
}
