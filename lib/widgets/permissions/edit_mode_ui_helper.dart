// lib/widgets/permissions/edit_mode_ui_helper.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// UI helper class for EditMode enum
/// Separates UI logic from the model layer to maintain clean architecture
class EditModeUIHelper {
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
}
