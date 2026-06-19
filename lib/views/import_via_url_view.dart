// lib/views/import_via_url_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/viewmodels/url_import_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/persistence/auto_save_manager.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Import via URL view with sourceUrl support
class ImportViaUrlView extends StatefulWidget {
  const ImportViaUrlView({super.key});

  @override
  State<ImportViaUrlView> createState() => _ImportViaUrlViewState();
}

class _ImportViaUrlViewState extends State<ImportViaUrlView> {
  late final UrlImportViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<UrlImportViewModel>();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: const _ImportViaUrlViewContent(),
    );
  }
}

class _ImportViaUrlViewContent extends StatefulWidget {
  const _ImportViaUrlViewContent();

  @override
  State<_ImportViaUrlViewContent> createState() =>
      _ImportViaUrlViewContentState();
}

class _ImportViaUrlViewContentState extends State<_ImportViaUrlViewContent> {
  /// BUT-911: single global key. URL-import is one-at-a-time per session;
  /// no per-id multi-instance concern. Persists only the URL (extractedText
  /// and parsedRecipe regenerate cheaply from a fetch+parse on next visit).
  /// BUT-904: persistence is now the shared AutoSaveManager.
  final AutoSaveManager<String> _draftManager = AutoSaveManager<String>(
    storageKey: 'url_import_draft_v1',
    encode: (text) => text,
    decode: (raw) => raw,
    logLabel: 'ImportViaUrlView',
  );

  final TextEditingController _urlController = TextEditingController();
  final TextEditingController _extractedTextController =
      TextEditingController();

  /// Tracks the last extractedText we seeded into the editor so a VM rebuild
  /// (from any notifyListeners) doesn't clobber the user's manual edits. We
  /// only push VM text into the controller when a NEW extraction arrives — the
  /// empty→non-empty (or changed-extraction) transition — never on every build.
  String _seededExtractedText = '';

  @override
  void initState() {
    super.initState();
    _urlController.addListener(_onUrlChanged);
    // BUG-7: read the VM from the Provider — the SAME instance the fetch
    // callbacks (context.read) and build (context.watch) use. A fresh
    // ServiceLocator.get returns a DIFFERENT instance (the VM is registered
    // as a factory), so the extracted-text editor would listen to a VM that
    // never runs the fetch — leaving the field blank and 'continue' a no-op.
    _viewModelForListener = context.read<UrlImportViewModel>();
    _viewModelForListener.addListener(_syncExtractedTextController);
    // Post-frame so the controller is mounted before triggering the
    // listener via .text assignment.
    WidgetsBinding.instance.addPostFrameCallback((_) => _restoreDraft());
  }

  late final UrlImportViewModel _viewModelForListener;

  /// Seed the editable extracted-text field ONCE per fresh extraction. A bare
  /// `..text = viewModel.extractedText` in build() reset the field (and the
  /// cursor) on every rebuild, discarding edits — the editor's whole point is
  /// letting the user revise the text before importing.
  void _syncExtractedTextController() {
    final vmText = _viewModelForListener.extractedText;
    if (vmText != _seededExtractedText) {
      _seededExtractedText = vmText;
      _extractedTextController.text = vmText;
    }
  }

  Future<void> _restoreDraft() async {
    final saved = await _draftManager.load();
    if (saved != null && saved.isNotEmpty && mounted) {
      // Setting .text triggers the listener which syncs the VM.
      _urlController.text = saved;
    }
  }

  @override
  void dispose() {
    _draftManager.dispose();
    _viewModelForListener.removeListener(_syncExtractedTextController);
    _urlController.removeListener(_onUrlChanged);
    _urlController.dispose();
    _extractedTextController.dispose();
    super.dispose();
  }

  void _onUrlChanged() {
    final viewModel = context.read<UrlImportViewModel>();
    viewModel.updateUrl(_urlController.text);
    // Eager save — URLs are short; one prefs write per keystroke is
    // bounded and isolate-fenced.
    _draftManager.save(_urlController.text);
  }

  Future<void> _fetchPage() async {
    final viewModel = context.read<UrlImportViewModel>();
    // BUT-947: a pasted list of URLs takes the batch path; a single URL keeps
    // the original single-fetch flow untouched.
    if (viewModel.isMultiUrl) {
      await viewModel.fetchMultipleUrls();
      return;
    }
    await viewModel.fetchFromUrl();
    // BUT-1273: when a single URL doesn't yield a recipe it may be a listing
    // page — probe for harvestable recipe links so we can offer batch
    // expansion. Gated on the miss so normal recipe imports never pay a second
    // network round-trip.
    if (!viewModel.hasExtractedText) {
      await viewModel.detectIndexPage();
    }
  }

  Future<void> _expandIndexPage() async {
    final viewModel = context.read<UrlImportViewModel>();
    await viewModel.expandIndexPage();
  }

  Future<void> _navigateToTextImport() async {
    final viewModel = context.read<UrlImportViewModel>();
    if (viewModel.hasExtractedText) {
      // Use edited text from controller instead of original extracted text
      final editedText = _extractedTextController.text.trim();
      if (editedText.isNotEmpty) {
        // User has explicitly committed past the URL stage — drop the draft
        // so next URL-import visit starts blank.
        await _draftManager.clear();
        if (!mounted) return;
        Navigator.pushNamed(
          context,
          '/franSocialaMedier',
          arguments: {
            'text': editedText,
            'sourceUrl': viewModel.sourceUrl,
          },
        );
      }
    }
  }

  /// BUT-947: turn a successful multi-URL batch into recipes. The extracted
  /// text of every fetched URL is concatenated (blank-line separated) and handed
  /// to the paste step, whose multi-recipe splitter segments it back into N
  /// recipes surfaced in the shared picker. sourceUrl is omitted: a batch spans
  /// several URLs, so no single attribution applies.
  Future<void> _navigateToBatchTextImport() async {
    final viewModel = context.read<UrlImportViewModel>();
    final combined = viewModel.successfulBatchText;
    if (combined.isEmpty) return;
    await _draftManager.clear();
    if (!mounted) return;
    Navigator.pushNamed(
      context,
      '/franSocialaMedier',
      arguments: {'text': combined},
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UrlImportViewModel>();

    return LayoutComponents.mainMenu(
      currentIndex: null,
      title: context.l10n.importViaUrl,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.translucent,
        child: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: LayoutComponents.valueFor(
                  context: context,
                  mobile: double.infinity,
                  tablet: 700,
                  desktop: 800,
                ),
              ),
              child: Padding(
                padding: AppDimensions.responsiveContentPadding(context),
                child: Column(
                  children: [
                    // URL input — multi-line so a user can paste several
                    // recipe URLs (one per line). A single URL still works.
                    StyledInput(
                      controller: _urlController,
                      enabled: !viewModel.isLoading,
                      label: viewModel.isMultiUrl
                          ? context.l10n.importMultipleUrlsLabel
                          : context.l10n.importPasteRecipeUrl,
                      hint: context.l10n.importMultipleUrlsHint,
                      keyboardType: TextInputType.multiline,
                      maxLines: 4,
                      minLines: 1,
                      textInputAction: TextInputAction.newline,
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Fetch button
                    ActionButtons.primaryButton(
                      context,
                      label: context.l10n.importFetchText,
                      onPressed: viewModel.canFetch && !viewModel.isLoading
                          ? _fetchPage
                          : null,
                      isLoading: viewModel.isLoading,
                      loadingText: context.l10n.importFetching,
                      isExpanded: true,
                    ),

                    // Error visning
                    if (viewModel.hasError) ...[
                      const SizedBox(height: AppDimensions.spacingXl),
                      StateWidget.error(
                        message: viewModel.error!,
                      ),
                    ],

                    // BUT-947: per-URL progress for a pasted list of URLs, plus
                    // the "Importera N recept" action once any URL succeeded.
                    if (viewModel.urlResults.isNotEmpty) ...[
                      const SizedBox(height: AppDimensions.spacingXl),
                      _UrlBatchResults(viewModel: viewModel),
                      if (viewModel.hasAnyUrlSuccess) ...[
                        const SizedBox(height: AppDimensions.spacingXl),
                        ActionButtons.primaryButton(
                          context,
                          label: context.l10n.importUrlBatchImport(
                              viewModel.successfulUrlCount),
                          onPressed: viewModel.isLoading
                              ? null
                              : _navigateToBatchTextImport,
                          isExpanded: true,
                        ),
                      ],
                    ],

                    // BUT-1273: opt-in recipe-index expansion. Shown only when a
                    // single-URL fetch detected a listing page; the user must tap
                    // to import — nothing fans out automatically.
                    if (viewModel.urlResults.isEmpty &&
                        viewModel.isIndexPageCandidate) ...[
                      const SizedBox(height: AppDimensions.spacingXl),
                      StateWidget.info(
                        message: context.l10n.importIndexPageDetected,
                      ),
                      const SizedBox(height: AppDimensions.spacingM),
                      ActionButtons.primaryButton(
                        context,
                        label: context.l10n.importIndexPageExpand(
                            viewModel.indexPageLinks.length),
                        onPressed:
                            viewModel.isLoading ? null : _expandIndexPage,
                        isExpanded: true,
                      ),
                    ],

                    // Extraherad text (editable) — single-URL flow only.
                    if (viewModel.urlResults.isEmpty &&
                        viewModel.hasExtractedText) ...[
                      const SizedBox(height: AppDimensions.spacingXl),
                      Text(context.l10n.importExtractedText,
                          style: AppTextStyles.headlineSmall),
                      const SizedBox(height: AppDimensions.spacingS),
                      Expanded(
                        child: StyledInput(
                          controller: _extractedTextController,
                          maxLines: null,
                          minLines: 10,
                          label: context.l10n.importEditTextBeforeImport,
                          hint: context.l10n.importEditTextHint,
                          keyboardType: TextInputType.multiline,
                        ),
                      ),
                      const SizedBox(height: AppDimensions.spacingXl),
                      ActionButtons.primaryButton(
                        context,
                        label: context.l10n.importProceedToPaste,
                        onPressed: _navigateToTextImport,
                        isExpanded: true,
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// BUT-947: renders one progress row per URL in a multi-URL import batch,
/// with a per-URL retry affordance on failures and a "{n} of {m} fetched"
/// summary so partial success is visible at a glance.
class _UrlBatchResults extends StatelessWidget {
  const _UrlBatchResults({required this.viewModel});

  final UrlImportViewModel viewModel;

  @override
  Widget build(BuildContext context) {
    final results = viewModel.urlResults;
    final successCount = results.where((r) => r.isSuccess).length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.importUrlBatchProgress(successCount, results.length),
          style: AppTextStyles.headlineSmall,
        ),
        const SizedBox(height: AppDimensions.spacingS),
        Flexible(
          child: ListView.separated(
            shrinkWrap: true,
            itemCount: results.length,
            separatorBuilder: (_, __) =>
                const SizedBox(height: AppDimensions.spacingS),
            itemBuilder: (context, index) {
              final result = results[index];
              return _UrlResultRow(
                result: result,
                onRetry: () => viewModel.retryUrl(index),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _UrlResultRow extends StatelessWidget {
  const _UrlResultRow({required this.result, required this.onRetry});

  final UrlImportResult result;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _statusIcon(context),
        const SizedBox(width: AppDimensions.spacingS),
        Expanded(
          child: Text(
            result.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodyMedium,
          ),
        ),
        if (result.isFailure)
          TextButton(
            onPressed: onRetry,
            child: Text(context.l10n.commonRetry),
          ),
      ],
    );
  }

  Widget _statusIcon(BuildContext context) {
    switch (result.status) {
      case UrlFetchStatus.loading:
        return const SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case UrlFetchStatus.success:
        return Icon(Icons.check_circle,
            color: context.butleryColors.success, size: 20);
      case UrlFetchStatus.failure:
        return Icon(Icons.error,
            color: Theme.of(context).colorScheme.error, size: 20);
      case UrlFetchStatus.pending:
        return const Icon(Icons.schedule,
            color: AppColors.greenMuted, size: 20);
    }
  }
}
