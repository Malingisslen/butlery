import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/dialogs/butlery_dialog.dart';

/// True leaves and drops the edits, false keeps editing. Null when the dialog
/// is dismissed from outside, which callers treat as keep editing.
Future<bool?> showUnsavedChangesDialog(BuildContext context) {
  return showButleryDialog<bool>(
    context: context,
    builder: (context) => ButleryDialog(
      title: context.l10n.recipeUnsavedChangesTitle,
      message: context.l10n.confirmUnsavedChanges,
      actions: [
        ActionButtons.secondaryButton(
          context,
          label: context.l10n.recipeContinueEditing,
          onPressed: () => Navigator.of(context).pop(false),
        ),
        ActionButtons.primaryButton(
          context,
          label: context.l10n.recipeLeaveWithoutSaving,
          onPressed: () => Navigator.of(context).pop(true),
        ),
      ],
    ),
  );
}
