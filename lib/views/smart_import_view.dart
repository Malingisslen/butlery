/// Unified Smart Import View for recipe imports.
///
/// A single entry point for all recipe imports supporting:
/// - URL paste (YouTube, TikTok, Instagram, websites)
/// - Text paste (copied recipe text)
/// - Automatic platform detection
/// - Simple 3-step progress (Fetching → Analyzing → Creating)
/// - User-assisted fallback for difficult imports
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';
import 'package:butlery/widgets/import/import_progress_widget.dart';
import 'package:butlery/widgets/import/platform_badge_widget.dart';
import 'package:butlery/widgets/import/assisted_import_dialog.dart';
import 'package:butlery/widgets/common/dialogs/rate_limit_dialog.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';

/// Main view for unified recipe imports.
class SmartImportView extends StatelessWidget {
  const SmartImportView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SmartImportViewModel(
        importManager: ServiceLocator.get<ImportManager>(),
      ),
      child: const _SmartImportViewContent(),
    );
  }
}

class _SmartImportViewContent extends StatefulWidget {
  const _SmartImportViewContent();

  @override
  State<_SmartImportViewContent> createState() =>
      _SmartImportViewContentState();
}

class _SmartImportViewContentState extends State<_SmartImportViewContent> {
  final _inputController = TextEditingController();
  final _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    // Auto-focus the input field
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _focusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _inputController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<SmartImportViewModel>();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Importera recept'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 600),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  return SingleChildScrollView(
                    child: ConstrainedBox(
                      constraints: BoxConstraints(
                        minHeight: constraints.maxHeight,
                      ),
                      child: IntrinsicHeight(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            // Input section
                            _InputSection(
                              controller: _inputController,
                              focusNode: _focusNode,
                              viewModel: viewModel,
                              onChanged: viewModel.updateInput,
                            ),

                            // Platform badge
                            if (viewModel.detection != null &&
                                viewModel.detection!.input.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              PlatformBadgeWidget(
                                  detection: viewModel.detection),
                            ],

                            // Progress indicator
                            if (viewModel.isImporting ||
                                viewModel.phase == ImportPhase.complete) ...[
                              const SizedBox(height: 24),
                              ImportProgressWidget(
                                currentStep: viewModel.currentStep,
                                message: viewModel.progressMessage,
                                isLoading: viewModel.isImporting,
                                isVisible: true,
                              ),
                            ],

                            // Error message
                            if (viewModel.error != null &&
                                viewModel.phase == ImportPhase.error) ...[
                              const SizedBox(height: 16),
                              _ErrorMessage(
                                message: viewModel.error!,
                                colorScheme: colorScheme,
                              ),
                            ],

                            const Spacer(),

                            // Action buttons
                            _ActionSection(
                              viewModel: viewModel,
                              onImport: () => _handleImport(context, viewModel),
                              onManualImport: () =>
                                  _handleManualImport(context, viewModel),
                              onPaste: () => _handlePaste(viewModel),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handlePaste(SmartImportViewModel viewModel) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (clipboardData?.text != null) {
      _inputController.text = clipboardData!.text!;
      viewModel.updateInput(clipboardData.text!);
    }
  }

  Future<void> _handleImport(
    BuildContext context,
    SmartImportViewModel viewModel,
  ) async {
    // Unfocus input
    FocusScope.of(context).unfocus();

    // Start import
    final result = await viewModel.startImport();

    if (!context.mounted) return;

    // Handle result
    switch (result) {
      case ImportSucceeded(:final recipe):
        _navigateToRecipeEditor(context, recipe);

      case ImportNeedsUserHelp():
        await _showAssistedImportDialog(context, viewModel, result);

      case ImportRateLimited(:final rateLimitResult):
        await _showRateLimitDialog(context, viewModel, rateLimitResult);

      case ImportFailed():
        // Error is shown in UI, no additional action needed
        break;
    }
  }

  Future<void> _handleManualImport(
    BuildContext context,
    SmartImportViewModel viewModel,
  ) async {
    if (!viewModel.canImport) return;

    // Show assisted import dialog with the input text
    final recipe = await showAssistedImportDialog(
      context: context,
      extractedText: viewModel.input,
      sourceUrl: viewModel.detection?.isUrl == true ? viewModel.input : null,
    );

    if (!context.mounted || recipe == null) return;

    // Save the recipe
    final result = await viewModel.handleAssistedRecipe(recipe);

    if (!context.mounted) return;

    if (result is ImportSucceeded) {
      _navigateToRecipeEditor(context, result.recipe);
    }
  }

  Future<void> _showAssistedImportDialog(
    BuildContext context,
    SmartImportViewModel viewModel,
    ImportNeedsUserHelp helpResult,
  ) async {
    // Check if this is a "needs screenshot" case (short error message, no real content)
    final text = helpResult.extractedText;
    debugPrint(
        '📋 AssistedImportDialog: extractedText="${text.length > 50 ? '${text.substring(0, 50)}...' : text}" (${text.length} chars)');

    // Detect if this is a short error message rather than actual recipe content
    final isNeedsScreenshot = text.length < 150 &&
        (text.toLowerCase().contains('skärmbild') ||
            text.toLowerCase().contains('screenshot') ||
            text.toLowerCase().contains('undertexter') ||
            text.toLowerCase().contains('transcript') ||
            text.toLowerCase().contains('saknar') ||
            text.isEmpty);

    debugPrint('📋 isNeedsScreenshot: $isNeedsScreenshot');

    if (isNeedsScreenshot) {
      // Show a simple dialog with photo import option
      await _showNeedsScreenshotDialog(context, helpResult);
      return;
    }

    final recipe = await showAssistedImportDialog(
      context: context,
      extractedText: helpResult.extractedText,
      suggestedTitle: helpResult.suggestedTitle,
      thumbnailUrl: helpResult.thumbnailUrl,
      sourceUrl: helpResult.sourceUrl,
      preDetectedIngredientLines: helpResult.likelyIngredientLines,
    );

    if (!context.mounted || recipe == null) return;

    // Save the recipe
    final result = await viewModel.handleAssistedRecipe(recipe);

    if (!context.mounted) return;

    if (result is ImportSucceeded) {
      _navigateToRecipeEditor(context, result.recipe);
    }
  }

  Future<void> _showNeedsScreenshotDialog(
    BuildContext context,
    ImportNeedsUserHelp helpResult,
  ) async {
    debugPrint('📋 Showing needs screenshot dialog');
    final theme = Theme.of(context);

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(Icons.videocam_off,
            size: 48, color: theme.colorScheme.primary),
        title: const Text('Videon saknar text'),
        content: const Text(
          'Den här videon har inga undertexter som vi kan läsa.\n\n'
          'Du kan ta en skärmbild av receptet i videon och importera den istället.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('cancel'),
            child: const Text('Avbryt'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop('photo'),
            icon: const Icon(Icons.photo_camera),
            label: const Text('Fotoimport'),
          ),
        ],
      ),
    );

    debugPrint('📋 Dialog result: $action');

    if (!context.mounted || action != 'photo') return;

    // Navigate to photo import
    Navigator.of(context).pushReplacementNamed(Routes.photoImport);
  }

  Future<void> _showRateLimitDialog(
    BuildContext context,
    SmartImportViewModel viewModel,
    rateLimitResult,
  ) async {
    final action = await RateLimitDialog.show(
      context,
      rateLimitResult: rateLimitResult,
      onTryWithoutAi: () {},
      onManualImport: () {},
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case FallbackAction.skipLlm:
        // Retry without LLM
        final result = await viewModel.retryWithoutLlm();
        if (context.mounted && result is ImportSucceeded) {
          _navigateToRecipeEditor(context, result.recipe);
        }

      case FallbackAction.useUserAssisted:
        // Show manual import dialog
        await _handleManualImport(context, viewModel);

      case FallbackAction.retryLater:
      case FallbackAction.useCache:
        // User chose to retry later or use cache, just close
        break;
    }
  }

  void _navigateToRecipeEditor(BuildContext context, Recipe recipe) {
    // Navigate to recipe editor with the imported recipe
    Navigator.of(context).pushReplacementNamed(
      Routes.skrivSjalv,
      arguments: {
        'initialRecipe': recipe,
        'isTemplate': true,
      },
    );
  }
}

/// Input section with text field and paste button.
class _InputSection extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final SmartImportViewModel viewModel;
  final ValueChanged<String> onChanged;

  const _InputSection({
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
        hintText: 'Klistra in länk eller text här...',
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.6),
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: theme.colorScheme.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(
            color: theme.colorScheme.primary,
            width: 2,
          ),
        ),
        filled: true,
        fillColor: theme.colorScheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.all(16),
        suffixIcon: controller.text.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.clear),
                onPressed: () {
                  controller.clear();
                  viewModel.clearInput();
                },
                tooltip: 'Rensa',
              )
            : null,
      ),
      textCapitalization: TextCapitalization.none,
      keyboardType: TextInputType.multiline,
    );
  }
}

/// Error message display.
class _ErrorMessage extends StatelessWidget {
  final String message;
  final ColorScheme colorScheme;

  const _ErrorMessage({
    required this.message,
    required this.colorScheme,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Icon(
            Icons.error_outline,
            color: colorScheme.onErrorContainer,
            size: 20,
          ),
          const SizedBox(width: 12),
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
    );
  }
}

/// Action buttons section.
class _ActionSection extends StatelessWidget {
  final SmartImportViewModel viewModel;
  final VoidCallback onImport;
  final VoidCallback onManualImport;
  final VoidCallback onPaste;

  const _ActionSection({
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
            label: const Text('Klistra in från urklipp'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
          ),
          const SizedBox(height: 12),
        ],

        // Import button
        FilledButton.icon(
          onPressed:
              viewModel.canImport && !viewModel.isImporting ? onImport : null,
          icon: viewModel.isImporting
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(
                      theme.colorScheme.onPrimary,
                    ),
                  ),
                )
              : const Icon(Icons.download),
          label: Text(viewModel.isImporting ? 'Importerar...' : 'Importera'),
          style: FilledButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 14),
          ),
        ),

        const SizedBox(height: 8),

        // Manual import link
        TextButton(
          onPressed: viewModel.canImport && !viewModel.isImporting
              ? onManualImport
              : null,
          child: const Text('Importera manuellt'),
        ),
      ],
    );
  }
}
