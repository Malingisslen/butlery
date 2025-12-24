// lib/widgets/import/components/import_dialog_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/assisted_import_viewmodel.dart';

/// Header component for import dialogs with icon, title, and close button.
class ImportDialogHeader extends StatelessWidget {
  final AssistedImportStep currentStep;
  final VoidCallback onClose;

  const ImportDialogHeader({
    super.key,
    required this.currentStep,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 8, 8),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Row(
        children: [
          Icon(
            Icons.edit_note,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Manuell import',
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  _getStepDescription(currentStep),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close),
            onPressed: onClose,
            tooltip: 'Avbryt',
          ),
        ],
      ),
    );
  }

  String _getStepDescription(AssistedImportStep step) {
    switch (step) {
      case AssistedImportStep.selectIngredients:
        return 'Steg 1: Välj ingredienser';
      case AssistedImportStep.selectInstructions:
        return 'Steg 2: Välj instruktioner';
      case AssistedImportStep.reviewEdit:
        return 'Steg 3: Granska och redigera';
    }
  }
}
