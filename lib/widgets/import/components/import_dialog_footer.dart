// lib/widgets/import/components/import_dialog_footer.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/assisted_import_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';

/// Footer component for import dialogs with validation and navigation buttons.
class ImportDialogFooter extends StatelessWidget {
  final String? validationError;
  final bool canGoBack;
  final bool canProceed;
  final AssistedImportStep currentStep;
  final VoidCallback onBack;
  final VoidCallback onCancel;
  final VoidCallback onNext;
  final VoidCallback onSave;

  const ImportDialogFooter({
    super.key,
    this.validationError,
    required this.canGoBack,
    required this.canProceed,
    required this.currentStep,
    required this.onBack,
    required this.onCancel,
    required this.onNext,
    required this.onSave,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: theme.colorScheme.outlineVariant),
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Validation error
          if (validationError != null) ...[
            Container(
              padding: AppDimensions.paddingSymmetric12x8,
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius:
                    BorderRadius.circular(AppDimensions.borderRadiusM),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: AppDimensions.iconSize18,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Expanded(
                    child: Text(
                      validationError!,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onErrorContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppDimensions.paddingM),
          ],
          // Buttons
          Row(
            children: [
              // Back button
              if (canGoBack)
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: Text(context.l10n.commonBack),
                )
              else
                TextButton(
                  onPressed: onCancel,
                  child: Text(context.l10n.commonCancel),
                ),
              const Spacer(),
              // Next/Save button
              if (currentStep == AssistedImportStep.reviewEdit)
                FilledButton.icon(
                  onPressed: canProceed ? onSave : null,
                  icon: const Icon(Icons.save),
                  label: Text(context.l10n.importSaveRecipe),
                )
              else
                FilledButton.icon(
                  onPressed: canProceed ? onNext : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: Text(context.l10n.commonNext),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
