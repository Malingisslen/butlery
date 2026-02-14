// lib/widgets/import/components/import_dialog_header.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/assisted_import_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';

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
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingXl,
        AppDimensions.spacingMd,
        AppDimensions.spacingSm,
        AppDimensions.spacingSm,
      ),
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
          const SizedBox(width: AppDimensions.width12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  context.l10n.importManualTitle,
                  style: theme.textTheme.titleLarge,
                ),
                Text(
                  _getStepDescription(context, currentStep),
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
            tooltip: context.l10n.commonCancel,
          ),
        ],
      ),
    );
  }

  String _getStepDescription(BuildContext context, AssistedImportStep step) {
    switch (step) {
      case AssistedImportStep.selectIngredients:
        return context.l10n.importStep1SelectIngredients;
      case AssistedImportStep.selectInstructions:
        return context.l10n.importStep2SelectInstructions;
      case AssistedImportStep.reviewEdit:
        return context.l10n.importStep3ReviewEdit;
    }
  }
}
