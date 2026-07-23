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
import 'package:butlery/models/parsing/parse_metadata.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/import/import_progress_widget.dart';
import 'package:butlery/widgets/import/platform_badge_widget.dart';
import 'package:butlery/widgets/import/assisted_import_dialog.dart';
import 'package:butlery/widgets/common/dialogs/rate_limit_dialog.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/views/smart_import/import_widgets.dart';
import 'package:butlery/views/smart_import/import_result_handler.dart';

/// Main view for unified recipe imports.
class SmartImportView extends StatelessWidget {
  /// URL handed in by the OS share sheet (web-share into the app). When set it
  /// prefills the import field and takes precedence over the clipboard check.
  final String? initialUrl;

  const SmartImportView({super.key, this.initialUrl});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SmartImportViewModel(
        importManager: ServiceLocator.get<ImportManager>(),
      ),
      child: _SmartImportViewContent(initialUrl: initialUrl),
    );
  }
}

class _SmartImportViewContent extends StatefulWidget {
  final String? initialUrl;

  const _SmartImportViewContent({this.initialUrl});

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
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      _focusNode.requestFocus();

      final viewModel = context.read<SmartImportViewModel>();

      // A URL shared into the app (web-share) wins over the clipboard. Prefill
      // the field and sync the VM (programmatic text doesn't fire onChanged).
      final shared = widget.initialUrl;
      if (shared != null && shared.isNotEmpty) {
        _inputController.text = shared;
        viewModel.updateInput(shared);
        return;
      }

      // Auto-check clipboard for recipe URLs
      await viewModel.checkClipboardForUrl();
      if (!mounted) return;
      final url = viewModel.clipboardUrl;
      if (url != null) {
        _showClipboardSuggestion(url, viewModel);
      }
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
    final colorScheme = Theme.of(context).colorScheme;

    return PopScope(
      canPop: !viewModel.isImporting,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && viewModel.isImporting) {
          SnackBarUtils.showWarning(
            context,
            context.l10n.importWaitForCompletion,
          );
        }
      },
      child: Scaffold(
        appBar: AdaptiveAppBar(
          title: context.l10n.importRecipeTitle,
          centerTitle: true,
        ),
        body: GestureDetector(
          onTap: () => FocusScope.of(context).unfocus(),
          behavior: HitTestBehavior.translucent,
          child: SafeArea(
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 600),
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingMd),
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
                                // Pending import retry banner
                                if (viewModel.hasPendingImport &&
                                    viewModel.isOnline)
                                  PendingImportBanner(
                                    onRetry: viewModel.retryPendingImport,
                                    onDismiss: viewModel.dismissPendingImport,
                                  ),

                                // Input section
                                ImportInputSection(
                                  controller: _inputController,
                                  focusNode: _focusNode,
                                  viewModel: viewModel,
                                  onChanged: viewModel.updateInput,
                                ),

                                // Platform badge
                                if (viewModel.detection != null &&
                                    viewModel.detection!.input.isNotEmpty) ...[
                                  const SizedBox(
                                    height: AppDimensions.spacingL,
                                  ),
                                  PlatformBadgeWidget(
                                    detection: viewModel.detection,
                                  ),
                                ],

                                // Progress indicator
                                if (viewModel.isImporting ||
                                    viewModel.phase ==
                                        ImportPhase.complete) ...[
                                  const SizedBox(
                                    height: AppDimensions.spacingLg,
                                  ),
                                  ImportProgressWidget(
                                    currentStep: viewModel.currentStep,
                                    message: viewModel.progressMessage,
                                    isLoading: viewModel.isImporting,
                                    isVisible: true,
                                    elapsed: viewModel.isImporting
                                        ? viewModel.elapsed
                                        : null,
                                  ),
                                ],

                                // Error message
                                if (viewModel.error != null &&
                                    viewModel.phase == ImportPhase.error) ...[
                                  const SizedBox(
                                    height: AppDimensions.spacingMd,
                                  ),
                                  ImportErrorMessage(
                                    message: viewModel.error!,
                                    colorScheme: colorScheme,
                                    onPasteText: () => _handlePaste(viewModel),
                                    onManualAdd: () => Navigator.pushNamed(
                                      context,
                                      Routes.manualEntry,
                                    ),
                                  ),
                                ],

                                const Spacer(),

                                // Action buttons
                                ImportActionSection(
                                  viewModel: viewModel,
                                  onImport: () =>
                                      _handleImport(context, viewModel),
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
        ),
      ),
    );
  }

  void _showClipboardSuggestion(String url, SmartImportViewModel viewModel) {
    SnackBarUtils.showInfo(
      context,
      context.l10n.importClipboardUrlDetected,
      actionLabel: context.l10n.importClipboardUseUrl,
      onAction: () {
        if (!mounted) return;
        _inputController.text = url;
        viewModel.updateInput(url);
        viewModel.clearClipboardSuggestion();
      },
      duration: SnackBarConfig.normalDuration,
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
    FocusScope.of(context).unfocus();

    final result = await viewModel.startImport();

    if (!context.mounted) return;

    switch (result) {
      case ImportSucceeded(:final recipe):
        final proceed = await ImportResultHandler.checkForDuplicates(
          context,
          recipe,
        );
        if (proceed && context.mounted) {
          ImportResultHandler.navigateToRecipeEditor(context, recipe);
        }

      case ImportNeedsUserHelp():
        await _showAssistedImportDialog(context, viewModel, result);

      case ImportRateLimited(:final rateLimitResult):
        await _showRateLimitDialog(context, viewModel, rateLimitResult);

      case ImportFailed():
        // Error is shown in UI — no additional action needed
        break;
    }
  }

  Future<void> _handleManualImport(
    BuildContext context,
    SmartImportViewModel viewModel,
  ) async {
    if (!viewModel.canImport) return;

    final isUrl = viewModel.detection?.isUrl == true;
    final recipe = await showAssistedImportDialog(
      context: context,
      extractedText: viewModel.input,
      sourceUrl: isUrl ? viewModel.input : null,
      source: isUrl ? ImportSource.url : ImportSource.text,
    );

    if (!context.mounted || recipe == null) return;

    final result = await viewModel.handleAssistedRecipe(recipe);

    if (!context.mounted) return;

    if (result is ImportSucceeded) {
      ImportResultHandler.navigateToRecipeEditor(context, result.recipe);
    }
  }

  Future<void> _showAssistedImportDialog(
    BuildContext context,
    SmartImportViewModel viewModel,
    ImportNeedsUserHelp helpResult,
  ) async {
    final text = helpResult.extractedText;

    // Detect if this is a short error message rather than actual recipe content
    final isNeedsScreenshot =
        text.length < 150 &&
        (text.toLowerCase().contains('skärmbild') ||
            text.toLowerCase().contains('screenshot') ||
            text.toLowerCase().contains('undertexter') ||
            text.toLowerCase().contains('transcript') ||
            text.toLowerCase().contains('saknar') ||
            text.isEmpty);

    if (isNeedsScreenshot) {
      await _showNeedsScreenshotDialog(context, helpResult);
      return;
    }

    final recipe = await showAssistedImportDialog(
      context: context,
      extractedText: helpResult.extractedText,
      suggestedTitle: helpResult.suggestedTitle,
      thumbnailUrl: helpResult.thumbnailUrl,
      sourceUrl: helpResult.sourceUrl,
      // The needs-help fallback fires from the URL/video/social pipeline: a
      // present sourceUrl means a URL-origin import; its absence means the
      // extracted text came from a non-URL strategy (e.g. pasted text).
      source: helpResult.sourceUrl != null
          ? ImportSource.url
          : ImportSource.text,
      preDetectedIngredientLines: helpResult.likelyIngredientLines,
    );

    if (!context.mounted || recipe == null) return;

    final result = await viewModel.handleAssistedRecipe(recipe);

    if (!context.mounted) return;

    if (result is ImportSucceeded) {
      ImportResultHandler.navigateToRecipeEditor(context, result.recipe);
    }
  }

  Future<void> _showNeedsScreenshotDialog(
    BuildContext context,
    ImportNeedsUserHelp helpResult,
  ) async {
    final theme = Theme.of(context);

    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: Icon(
          Icons.videocam_off,
          size: 48,
          color: theme.colorScheme.primary,
        ),
        title: Text(context.l10n.importVideoNoText),
        content: Text(
          context.l10n.importVideoNoTextDescription,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('cancel'),
            child: Text(context.l10n.commonCancel),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogContext).pop('photo'),
            icon: const Icon(Icons.photo_camera),
            label: Text(context.l10n.importPhotoImport),
          ),
        ],
      ),
    );

    if (!context.mounted || action != 'photo') return;

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
        final result = await viewModel.retryWithoutLlm();
        if (context.mounted && result is ImportSucceeded) {
          ImportResultHandler.navigateToRecipeEditor(context, result.recipe);
        }

      case FallbackAction.useUserAssisted:
        await _handleManualImport(context, viewModel);

      case FallbackAction.retryLater:
      case FallbackAction.useCache:
        // User chose to retry later or use cache — nothing to do
        break;
    }
  }
}
