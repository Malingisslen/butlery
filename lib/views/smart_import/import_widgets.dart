// Sub-widgets extracted from smart_import_view.dart to keep the parent under
// the 620-line baseline. Pure presentational — no logic changes.

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Banner shown when a previous import is pending retry.
class PendingImportBanner extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback onDismiss;

  const PendingImportBanner({
    super.key,
    required this.onRetry,
    required this.onDismiss,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: AppDimensions.spacingMd),
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      color: cs.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.importPendingRetryPrompt,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              TextButton(
                onPressed: onDismiss,
                child: Text(context.l10n.importPendingDismiss),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              FilledButton(
                onPressed: onRetry,
                child: Text(context.l10n.importPendingRetry),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Text input section with clear button.
class ImportInputSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final SmartImportViewModel viewModel;
  final ValueChanged<String> onChanged;

  const ImportInputSection({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.viewModel,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      onChanged: onChanged,
      enabled: !viewModel.isImporting,
      maxLines: 5,
      minLines: 3,
      decoration: InputDecoration(
        hintText: context.l10n.importPasteLinkOrText,
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(
            alpha: AppDimensions.opacityMediumDark,
          ),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusL),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.all(AppDimensions.spacingMd),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  viewModel.clearInput();
                },
                tooltip: context.l10n.commonClear,
              )
            : null,
      ),
      textCapitalization: TextCapitalization.none,
      keyboardType: TextInputType.multiline,
    );
  }
}

/// Error container with optional fallback action buttons.
class ImportErrorMessage extends StatelessWidget {
  final String message;
  final ColorScheme colorScheme;
  final VoidCallback? onPasteText;
  final VoidCallback? onManualAdd;

  const ImportErrorMessage({
    super.key,
    required this.message,
    required this.colorScheme,
    this.onPasteText,
    this.onManualAdd,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.error_outline,
                color: colorScheme.onErrorContainer,
                size: AppDimensions.iconSizeM,
              ),
              const SizedBox(width: AppDimensions.spacingL),
              Expanded(
                child: Text(
                  message,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colorScheme.onErrorContainer,
                  ),
                ),
              ),
            ],
          ),
          if (onPasteText != null || onManualAdd != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Wrap(
              spacing: AppDimensions.spacingSm,
              children: [
                if (onPasteText != null)
                  TextButton.icon(
                    onPressed: onPasteText,
                    icon: const Icon(
                      Icons.content_paste,
                      size: AppDimensions.iconSizeS,
                    ),
                    label: Text(context.l10n.importPasteText),
                  ),
                if (onManualAdd != null)
                  TextButton.icon(
                    onPressed: onManualAdd,
                    icon: const Icon(Icons.edit, size: AppDimensions.iconSizeS),
                    label: Text(context.l10n.importAddManually),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Import / paste / manual-import action buttons.
class ImportActionSection extends StatelessWidget {
  final SmartImportViewModel viewModel;
  final VoidCallback onImport;
  final VoidCallback onManualImport;
  final VoidCallback onPaste;

  const ImportActionSection({
    super.key,
    required this.viewModel,
    required this.onImport,
    required this.onManualImport,
    required this.onPaste,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Paste button (shown when input is empty)
        if (viewModel.input.isEmpty) ...[
          OutlinedButton.icon(
            onPressed: onPaste,
            icon: const Icon(Icons.content_paste),
            label: Text(context.l10n.importPasteFromClipboard),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                vertical: AppDimensions.spacingModerate,
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingL),
        ],

        // Import button.
        // BUT-403: `btn-import-url` identifier for browser a11y tree.
        Semantics(
          identifier: 'btn-import-url',
          button: true,
          enabled: viewModel.canImport && !viewModel.isImporting,
          label: context.l10n.importImport,
          child: FilledButton.icon(
            key: const ValueKey('test-smart-import-url'),
            onPressed: viewModel.canImport && !viewModel.isImporting
                ? onImport
                : null,
            icon: viewModel.isImporting
                ? LoadingIndicator(
                    size: 18,
                    strokeWidth: 2,
                    color: theme.colorScheme.onPrimary,
                  )
                : const Icon(Icons.download),
            label: Text(
              viewModel.isImporting
                  ? context.l10n.importImporting
                  : context.l10n.importImport,
            ),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
        ),

        const SizedBox(height: AppDimensions.spacingSm),

        // Manual import link
        TextButton(
          onPressed: viewModel.canImport && !viewModel.isImporting
              ? onManualImport
              : null,
          child: Text(context.l10n.importManually),
        ),
      ],
    );
  }
}
