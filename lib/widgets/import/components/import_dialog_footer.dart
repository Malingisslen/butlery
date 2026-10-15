// lib/widgets/import/components/import_dialog_footer.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/viewmodels/assisted_import_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

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
      padding: const EdgeInsets.all(AppDimensions.space16),
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
                borderRadius: BorderRadius.circular(
                  AppDimensions.radiusControl,
                ),
              ),
              child: Row(
                children: [
                  ButleryIcon(
                    ButleryIcons.triangleAlert,
                    size: AppDimensions.iconSize18,
                    color: theme.colorScheme.onErrorContainer,
                  ),
                  const SizedBox(width: AppDimensions.space8),
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
            const SizedBox(height: AppDimensions.space12),
          ],
          // Buttons
          Row(
            children: [
              // Back button
              // The FilledButton theme asks for the full row width; beside a
              // Spacer that is an infinite minimum, so the buttons size to
              // their labels here.
              if (canGoBack)
                ButleryTextButton(
                  label: context.l10n.commonBack,
                  icon: ButleryIcons.arrowLeft,
                  onPressed: onBack,
                )
              else
                ButleryTextButton(
                  label: context.l10n.commonCancel,
                  onPressed: onCancel,
                ),
              const Spacer(),
              // Next/Save button
              if (currentStep == AssistedImportStep.reviewEdit)
                ActionButtons.primaryButton(
                  context,
                  label: context.l10n.importSaveRecipe,
                  icon: ButleryIcons.save,
                  onPressed: canProceed ? onSave : null,
                )
              else
                ActionButtons.primaryButton(
                  context,
                  label: context.l10n.commonNext,
                  icon: ButleryIcons.arrowRight,
                  onPressed: canProceed ? onNext : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
