/// lib/models/permissions/edit_mode.dart

import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

enum EditMode {
  owner, // Äger receptet - kan alltid redigera original
  collaborative, // Kollaborativ redigering - ändringar synkas
  readOnlyWithFork, // Bara läsning + "Spara min kopia"
  noAccess, // Ingen åtkomst
}

extension EditModeExtension on EditMode {
  bool get canEdit => this == EditMode.owner || this == EditMode.collaborative;
  bool get canFork => this != EditMode.noAccess;
  bool get showForkButton =>
      this == EditMode.readOnlyWithFork || this == EditMode.collaborative;

  String get description {
    switch (this) {
      case EditMode.owner:
        return 'Du äger detta recept';
      case EditMode.collaborative:
        return 'Du redigerar tillsammans med andra';
      case EditMode.readOnlyWithFork:
        return 'Skrivskyddat - du kan spara din egen kopia';
      case EditMode.noAccess:
        return 'Ingen åtkomst';
    }
  }

  Color getColor(BuildContext context) {
    switch (this) {
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

  IconData get icon {
    switch (this) {
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
}
