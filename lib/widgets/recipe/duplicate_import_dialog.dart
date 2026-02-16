import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/recipe_unified.dart';

/// Result of the duplicate import dialog.
enum DuplicateImportChoice {
  viewExisting,
  importAnyway,
  cancel,
}

/// Shows a dialog when a duplicate recipe is detected during import.
/// Returns the user's choice: view existing, import anyway, or cancel.
Future<DuplicateImportChoice?> showDuplicateImportDialog({
  required BuildContext context,
  required Recipe existingRecipe,
}) {
  return showDialog<DuplicateImportChoice>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(context.l10n.duplicateImportTitle),
      content: Text(
        context.l10n.duplicateImportMessage(existingRecipe.title),
      ),
      actions: [
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(DuplicateImportChoice.cancel),
          child: Text(context.l10n.commonCancel),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(DuplicateImportChoice.viewExisting),
          child: Text(context.l10n.duplicateImportViewExisting),
        ),
        TextButton(
          onPressed: () =>
              Navigator.of(context).pop(DuplicateImportChoice.importAnyway),
          child: Text(context.l10n.duplicateImportAnyway),
        ),
      ],
    ),
  );
}
