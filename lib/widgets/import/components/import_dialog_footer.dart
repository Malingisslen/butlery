// lib/widgets/import/components/import_dialog_footer.dart

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/assisted_import_viewmodel.dart';

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
      padding: const EdgeInsets.all(16),
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
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.warning_amber,
                    size: 18,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: 8),
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
            const SizedBox(height: 12),
          ],
          // Buttons
          Row(
            children: [
              // Back button
              if (canGoBack)
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back),
                  label: const Text('Tillbaka'),
                )
              else
                TextButton(
                  onPressed: onCancel,
                  child: const Text('Avbryt'),
                ),
              const Spacer(),
              // Next/Save button
              if (currentStep == AssistedImportStep.reviewEdit)
                FilledButton.icon(
                  onPressed: canProceed ? onSave : null,
                  icon: const Icon(Icons.save),
                  label: const Text('Spara recept'),
                )
              else
                FilledButton.icon(
                  onPressed: canProceed ? onNext : null,
                  icon: const Icon(Icons.arrow_forward),
                  label: const Text('Nästa'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
