// lib/widgets/permissions/edit_mode_ui_helper.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// UI helper class for EditMode enum
/// Separates UI logic from the model layer to maintain clean architecture
class EditModeUIHelper {
  /// Get color for a specific edit mode
  static Color getColor(EditMode mode, BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    switch (mode) {
      case EditMode.owner:
      case EditMode.edit:
        return cs.onSurface;
      case EditMode.collaborative:
        return context.modeColors.success;
      case EditMode.readOnlyWithFork:
      case EditMode.view:
        return context.modeColors.warning;
      case EditMode.noAccess:
        return cs.error;
    }
  }

  /// Get icon for a specific edit mode
  static IconData getIcon(EditMode mode) {
    switch (mode) {
      case EditMode.owner:
      case EditMode.edit:
        return ButleryIcons.pencil;
      case EditMode.collaborative:
        return ButleryIcons.users;
      case EditMode.readOnlyWithFork:
      case EditMode.view:
        return ButleryIcons.eye;
      case EditMode.noAccess:
        return ButleryIcons.block;
    }
  }

  /// Get icon with color for a specific edit mode
  static Icon getIconWithColor(EditMode mode, BuildContext context) {
    return ButleryIcon(
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
