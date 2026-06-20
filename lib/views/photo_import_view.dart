/// Photo import view for OCR-based recipe extraction from images.

// lib/views/photo_import_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:provider/provider.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/recipe/heirloom_draft.dart';
import 'package:butlery/widgets/import/batch_import_preview.dart';
import 'package:butlery/widgets/import/allergen_setup_banner.dart';
import 'package:butlery/services/import/heirloom_bridge.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/services/tagging/allergen_mismatch.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/content_cards/text_display_card.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/views/photo_import/heirloom_section.dart';
import 'package:butlery/widgets/import/confidence_indicator.dart';
import 'package:butlery/views/photo_import/image_preview.dart';
import 'package:butlery/views/photo_import/photo_page_strip.dart';

/// Photo import view with OCR processing for recipe extraction.
class PhotoImportView extends StatefulWidget {
  const PhotoImportView({super.key});

  @override
  State<PhotoImportView> createState() => _PhotoImportViewState();
}

class _PhotoImportViewState extends State<PhotoImportView> {
  late final PhotoImportViewModel _viewModel;

  // BUT-1201: ensures the OCR-complete announcement fires once per extraction,
  // not on every VM notification while the result is on screen.
  bool _announcedOcr = false;

  @override
  void initState() {
    super.initState();
    _viewModel = ServiceLocator.get<PhotoImportViewModel>();
    _viewModel.addListener(_announceOcrCompletion);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _maybeOfferDraftRestore();
    });
  }

  /// BUT-910: when a previous session left an OCR draft behind (nav-away or
  /// backgrounding after a completed extraction), offer to continue with it.
  /// The dialog forces a choice — declining drops the draft so it doesn't
  /// re-prompt forever.
  Future<void> _maybeOfferDraftRestore() async {
    if (_viewModel.hasImage || _viewModel.hasOcrResult) return;
    final draft = await _viewModel.loadPersistedDraft();
    if (draft == null || !mounted) return;
    final restore = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        icon: Icon(
          Icons.restore,
          color: Theme.of(context).colorScheme.primary,
          size: AppDimensions.iconSizeL,
        ),
        title: Text(context.l10n.draftRecovery),
        content: Text(context.l10n.photoDraftRecoverySubtitle),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.l10n.draftStartFresh),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).pop(true),
            icon: const Icon(Icons.restore, size: AppDimensions.iconSizeS),
            label: Text(context.l10n.draftRestore),
          ),
        ],
      ),
    );
    if (restore == true) {
      await _viewModel.restoreDraft();
    } else if (restore == false) {
      // Only an explicit "start fresh" discards. A system back-press pops the
      // dialog with null — the draft survives and re-offers next visit, so a
      // reflexive back can't destroy the artefact this feature protects.
      await _viewModel.discardPersistedDraft();
    }
  }

  /// BUT-1201: announce the extracting→review transition to screen readers.
  /// The visual appearance of the interpreted-text card isn't read otherwise.
  void _announceOcrCompletion() {
    if (_viewModel.hasOcrResult && !_viewModel.isProcessing) {
      if (!_announcedOcr && mounted) {
        _announcedOcr = true;
        SemanticsService.announce(
          context.l10n.a11yOcrComplete,
          TextDirection.ltr,
        );
      }
    } else {
      // Reset so a subsequent extraction (retry / new photo) announces again.
      _announcedOcr = false;
    }
  }

  @override
  void dispose() {
    _viewModel.removeListener(_announceOcrCompletion);
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _viewModel,
      child: const _PhotoImportViewContent(),
    );
  }
}

class _PhotoImportViewContent extends StatelessWidget {
  const _PhotoImportViewContent();

  void _showImageSourceDialog(BuildContext context) {
    final viewModel = context.read<PhotoImportViewModel>();

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppDimensions.borderRadiusL),
        ),
      ),
      builder: (BuildContext context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  context.l10n.importChooseImageSource,
                  style: AppTextStyles.headlineSmall,
                ),
                const SizedBox(height: AppDimensions.spacingXl),

                // Kamera-alternativ
                ListTile(
                  leading: Icon(
                    Icons.camera_alt,
                    color: Theme.of(context).colorScheme.primary,
                    size: AppDimensions.iconSizeL,
                  ),
                  title: Text(context.l10n.importTakePhoto),
                  subtitle: Text(context.l10n.importTakePhotoSubtitle),
                  onTap: () {
                    Navigator.pop(context);
                    viewModel.pickImageFromCamera();
                  },
                ),

                // Galleri-alternativ
                ListTile(
                  leading: Icon(
                    Icons.photo_library,
                    color: Theme.of(context).colorScheme.primary,
                    size: AppDimensions.iconSizeL,
                  ),
                  title: Text(context.l10n.importChooseFromGallery),
                  subtitle: Text(context.l10n.importChooseFromGallerySubtitle),
                  onTap: () {
                    Navigator.pop(context);
                    viewModel.pickImageFromGallery();
                  },
                ),

                const SizedBox(height: AppDimensions.spacingXl),
              ],
            ),
          ),
        );
      },
    );
  }

  void _navigateToTextImport(
    BuildContext context,
    PhotoImportViewModel viewModel,
  ) {
    if (viewModel.hasOcrResult) {
      _stashHeirloomDraftIfActive(viewModel);
      // BUT-928: carry the OCR confidence across the handoff so the badge
      // the user saw on the preview step doesn't vanish on the next screen.
      Navigator.pushNamed(
        context,
        '/franSocialaMedier',
        arguments: {
          'text': viewModel.ocrText,
          'ocrConfidence': viewModel.confidence,
        },
      );
    }
  }

  /// Multi-recipe page → let the user tick which recipes to add, reusing the
  /// existing [BatchImportPreview] picker (same pattern as file import), then
  /// save the selection.
  Future<void> _navigateToMultiRecipePicker(
    BuildContext context,
    PhotoImportViewModel viewModel,
  ) async {
    final selected = await Navigator.push<List<Recipe>>(
      context,
      MaterialPageRoute(
        builder: (_) => BatchImportPreview(recipes: viewModel.parsedRecipes),
      ),
    );
    if (!context.mounted || selected == null || selected.isEmpty) return;

    final ok = await viewModel.saveSelectedRecipes(selected);
    if (!context.mounted) return;
    final failed = viewModel.lastSaveFailureCount;
    final saved = selected.length - failed;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok
              ? context.l10n.importComplete(saved, failed)
              : context.l10n.errorGeneric,
        ),
      ),
    );
    if (ok) {
      // BUT-1200: non-blocking allergen-setup prompt when any saved recipe
      // CONTAINS an allergen the user hasn't configured. Reuses the
      // deterministic Phase-1 tags ImportManager attached during parse — no new
      // LLM/network — and the app-level ScaffoldMessenger so it survives the
      // pop below. Mirrors SmartImportView._navigateToRecipeEditor; one prompt
      // covers the whole batch rather than firing per recipe.
      final prefs = ServiceLocator.get<UserService>().allergenPreferences;
      if (AllergenMismatch.anyUnconfigured(selected, prefs)) {
        AllergenSetupBanner.show(context);
      }
      viewModel.clearPhoto();
      Navigator.of(context).maybePop();
    }
  }

  /// BUT-953: capture the heirloom form into the bridge so the save flow on
  /// `/franSocialaMedier` can upload + attach metadata to the parsed recipe.
  /// No-op when heirloom is off or no image is present.
  void _stashHeirloomDraftIfActive(PhotoImportViewModel viewModel) {
    if (!viewModel.isHeirloom || !viewModel.hasImage) return;
    final bytes = viewModel.imageBytes;
    if (bytes == null) return;
    final bridge = ServiceLocator.get<HeirloomBridge>();
    bridge.setDraft(HeirloomDraft(
      imageBytes: bytes,
      writerName: viewModel.heirloomWriterName.isEmpty
          ? null
          : viewModel.heirloomWriterName,
      year: viewModel.heirloomYear,
      note: viewModel.heirloomNote.isEmpty ? null : viewModel.heirloomNote,
    ));
  }

  /// Navigation escape route for OCR failures (Issue #029).
  void _navigateToManualEntry(
    BuildContext context,
    PhotoImportViewModel viewModel,
  ) {
    _stashHeirloomDraftIfActive(viewModel);
    // Navigate even without OCR success - critical escape route
    Navigator.pushNamed(
      context,
      '/franSocialaMedier',
      arguments: {
        'text': viewModel.ocrText.isEmpty ? '' : viewModel.ocrText,
        // BUT-928: only meaningful when OCR actually produced text.
        'ocrConfidence':
            viewModel.ocrText.isEmpty ? null : viewModel.confidence,
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final viewModel = context.watch<PhotoImportViewModel>();

    return LayoutComponents.mainMenu(
      currentIndex: null,
      title: context.l10n.importFromPhoto,
      body: SafeArea(
        // RESPONSIVE: Center and constrain content on large screens
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
            child: SingleChildScrollView(
              padding: AppDimensions.responsiveContentPadding(context),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Information om funktionen
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(AppDimensions.paddingL),
                    decoration: BoxDecoration(
                      color: cs.surfaceContainerLow,
                      borderRadius: BorderRadius.circular(
                        AppDimensions.borderRadiusM,
                      ),
                      border: Border.all(color: cs.outlineVariant),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.info_outline,
                          size: AppDimensions.iconSizeM,
                          color: cs.primary,
                        ),
                        const SizedBox(width: AppDimensions.spacingS),
                        Expanded(
                          child: Text(
                            context.l10n.importPhotoDescription,
                            style: AppTextStyles.bodySmall,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),

                  UtilityComponents.primaryButton(
                    context,
                    label: viewModel.hasImage
                        ? context.l10n.importChooseNewImage
                        : context.l10n.importChooseImage,
                    icon: Icons.add_photo_alternate,
                    onPressed: viewModel.isProcessing
                        ? null
                        : () => _showImageSourceDialog(context),
                    isExpanded: true,
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),

                  // Bildvisning
                  ImagePreview(viewModel: viewModel),
                  const SizedBox(height: AppDimensions.spacingXl),

                  // BUT-903: multi-page strip — thumbnails of every photo
                  // combined into one recipe, plus the "add page" tile. Renders
                  // nothing until at least one image exists.
                  if (viewModel.hasImage) ...[
                    PhotoPageStrip(viewModel: viewModel),
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],

                  // BUT-410: heirloom toggle + form, only when an image exists.
                  // Kept between the preview and OCR-quality warnings so the
                  // user sees it as a property of the chosen photo.
                  if (viewModel.hasImage) ...[
                    HeirloomSection(viewModel: viewModel),
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],

                  // Quality warning (Phase 2 Enhancement)
                  if (viewModel.hasImage &&
                      viewModel.qualityScore != null &&
                      viewModel.qualityScore! < 0.6 &&
                      !viewModel.hasError) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(AppDimensions.paddingM),
                      decoration: BoxDecoration(
                        color: context.butleryColors.warning
                            .withValues(alpha: AppDimensions.opacityVeryLight),
                        borderRadius: BorderRadius.circular(
                          AppDimensions.borderRadiusM,
                        ),
                        border: Border.all(
                          color: context.butleryColors.warning.withValues(
                              alpha: AppDimensions.opacityMediumLight),
                          width: AppDimensions.borderWidthStandard,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.warning_amber_rounded,
                                color: context.butleryColors.warning,
                                size: AppDimensions.iconSizeM,
                              ),
                              const SizedBox(width: AppDimensions.spacingS),
                              Expanded(
                                child: Text(
                                  context.l10n.importImageQualityLow(
                                      (viewModel.qualityScore! * 100).toInt()),
                                  style: AppTextStyles.titleSmall.copyWith(
                                    color: context
                                        .butleryColors.onWarningContainer,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          if (viewModel.recommendations != null &&
                              viewModel.recommendations!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingSm),
                            Text(
                              context.l10n.importImprovementSuggestions,
                              style: AppTextStyles.badgeLarge.copyWith(
                                color: context.butleryColors.onWarningContainer,
                              ),
                            ),
                            const SizedBox(height: AppDimensions.spacingXs),
                            ...viewModel.recommendations!.map(
                              (rec) => Padding(
                                padding: const EdgeInsets.only(
                                  bottom: AppDimensions.spacingXxs,
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '• ',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: context
                                            .butleryColors.onWarningContainer,
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(
                                        rec,
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: context
                                              .butleryColors.onWarningContainer,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                          const SizedBox(height: AppDimensions.spacingSm),
                          Text(
                            context.l10n.importOcrMayFail,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: context.butleryColors.onWarningContainer,
                              fontStyle: FontStyle.italic,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],

                  // Error container with recovery options
                  if (viewModel.hasError) ...[
                    StateWidget.error(
                      message: viewModel.error!,
                      onAction: viewModel.canRetryOcr
                          ? null // Don't show clear button when retry is available
                          : () => viewModel.clearError(),
                    ),
                    const SizedBox(height: AppDimensions.spacingM),

                    // Error recovery buttons (only shown when image is available)
                    if (viewModel.hasImage) ...[
                      // Retry OCR button
                      UtilityComponents.primaryButton(
                        context,
                        label: context.l10n.commonRetry,
                        icon: Icons.refresh,
                        onPressed: viewModel.isProcessing
                            ? null
                            : () => viewModel.retryOcr(),
                        isExpanded: true,
                      ),
                      const SizedBox(height: AppDimensions.spacingM),

                      // Continue without OCR button (escape route)
                      UtilityComponents.secondaryButton(
                        context,
                        label: context.l10n.importContinueWithoutOcr,
                        icon: Icons.edit,
                        onPressed: viewModel.isProcessing
                            ? null
                            : () => _navigateToManualEntry(context, viewModel),
                        isExpanded: true,
                      ),
                    ],

                    const SizedBox(height: AppDimensions.spacingXl),
                  ],

                  // OCR-resultat
                  if (viewModel.hasOcrResult) ...[
                    Row(
                      children: [
                        Text(
                          context.l10n.importInterpretedText,
                          style: AppTextStyles.headlineSmall,
                        ),
                        const SizedBox(width: AppDimensions.spacingM),
                        // Confidence indicator (Phase 2 Enhancement)
                        if (viewModel.confidence != null)
                          ConfidenceIndicator(
                            confidence: viewModel.confidence!,
                          ),
                      ],
                    ),
                    const SizedBox(height: AppDimensions.spacingM),
                    TextDisplayCard(text: viewModel.ocrText),
                    const SizedBox(height: AppDimensions.spacingXl),
                    if (viewModel.hasMultipleRecipes)
                      UtilityComponents.primaryButton(
                        context,
                        label: context.l10n.importMultipleRecipesFound(
                          viewModel.parsedRecipes.length,
                        ),
                        icon: Icons.library_books,
                        onPressed: () =>
                            _navigateToMultiRecipePicker(context, viewModel),
                        isExpanded: true,
                      )
                    else
                      UtilityComponents.primaryButton(
                        context,
                        label: context.l10n.importProceedToEdit,
                        icon: Icons.arrow_forward,
                        onPressed: () =>
                            _navigateToTextImport(context, viewModel),
                        isExpanded: true,
                      ),
                    // Add bottom padding for safe scrolling
                    const SizedBox(height: AppDimensions.spacingXl),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
