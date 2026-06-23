// lib/viewmodels/photo_import_viewmodel.dart

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_heirloom_form_mixin.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_draft_mixin.dart';
import 'package:butlery/viewmodels/photo_import/ocr_error_message_builder.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/services/persistence/auto_save_manager.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Photo-import ViewModel: camera/gallery capture → multi-provider OCR →
/// auto-parse to a Recipe. Extends [ImportBaseViewModel] for the shared
/// import lifecycle; heirloom form state lives in
/// [PhotoImportHeirloomFormMixin].
class PhotoImportViewModel extends ImportBaseViewModel
    with PhotoImportHeirloomFormMixin, PhotoImportDraftMixin {
  /// Raw image bytes from the selected photo (OCR input + preview).
  /// In multi-page mode (BUT-903) this mirrors the FIRST page so every existing
  /// single-image consumer — preview thumbnail, heirloom scan, draft staging —
  /// keeps working unchanged. The full ordered set lives in [_pages].
  Uint8List? _imageBytes;

  /// Extracted OCR text awaiting parse/review. In multi-page mode this is the
  /// per-page OCR text concatenated in page order, so the single downstream
  /// parse sees the whole recipe spread as one document.
  String _ocrText = '';

  /// BUT-903: ordered photo pages (max [maxPages]) combined into ONE recipe.
  /// A long recipe split across several cookbook pages OCRs each page then
  /// concatenates the text in this order before a single parse. The single-page
  /// flow is simply the `length == 1` case — [_imageBytes]/[_ocrText] stay the
  /// live combined state so no existing consumer changes.
  final List<_PhotoPage> _pages = [];

  /// Last OCR quality score from image assessment (0.0-1.0).
  /// Enables quality-based error messaging and user guidance on image quality.
  double? _lastQualityScore;

  /// Last OCR quality recommendations from image assessment.
  /// Provides actionable suggestions for improving OCR success (lighting, focus, etc.).
  List<String>? _lastRecommendations;

  /// Last OCR confidence score from successful extraction (0.0-1.0).
  /// Indicates reliability of extracted text for user confidence and retry decisions.
  double? _lastConfidence;

  /// All recipes detected on the page. A cookbook spread can hold several;
  /// when >1 the view shows a picker instead of the single "edit" CTA. For a
  /// single recipe this holds one item AND [parsedRecipe] is set, so every
  /// existing single-recipe consumer behaves exactly as before.
  final List<Recipe> _parsedRecipes = [];

  // BUT-410 heirloom form state lives in PhotoImportHeirloomFormMixin.

  /// [draftManager] is a test seam (BUT-910) — production passes nothing.
  /// BUT-610: [connectivity] default-resolves from ServiceLocator so existing
  /// callers are unchanged; tests inject an offline double.
  PhotoImportViewModel({
    required super.importManager,
    AutoSaveManager<PhotoImportDraft>? draftManager,
    // BUT-1360: connectivity + the isOnline getter now live on
    // ImportBaseViewModel; forward the injection to super (no local copy).
    super.connectivity,
  }) {
    initDraftPersistence(manager: draftManager);
    _initializeOCRService();
  }

  /// Initialize OCR service for universal device compatibility
  Future<void> _initializeOCRService() async {
    try {
      await OCRExtractionService.instance.initialize();
    } catch (e) {
      // OCR service initialization failed - will be handled when OCR is attempted
    }
  }

  /// BUT-903: hard cap on combinable pages. A single recipe rarely spans more
  /// than a few cookbook pages; the cap also bounds OCR quota per import.
  static const int maxPages = 5;

  Uint8List? get imageBytes => _imageBytes;

  String get ocrText => _ocrText;

  bool get hasImage => _imageBytes != null;

  bool get hasOcrResult => _ocrText.isNotEmpty;

  /// BUT-903: the ordered image bytes for every added page (for the page-strip
  /// thumbnails). One entry per page; index 0 is the first/cover page.
  List<Uint8List> get pageImages =>
      List.unmodifiable(_pages.map((p) => p.bytes));

  /// Number of pages currently combined into the import.
  int get pageCount => _pages.length;

  /// True once a second page exists — the view shows the page strip + reorder
  /// affordances only then, keeping the single-photo flow visually unchanged.
  bool get hasMultiplePages => _pages.length > 1;

  /// False once the page cap is reached, so the "add page" CTA can disable.
  bool get canAddPage => _pages.length < maxPages;

  /// Last OCR quality score for error messaging and user guidance (Phase 2 Enhancement).
  /// Returns quality score from image assessment (0.0-1.0) enabling quality-based
  /// error messages and recommendations display in UI.
  double? get qualityScore => _lastQualityScore;

  /// Last OCR quality recommendations for user guidance (Phase 2 Enhancement).
  /// Returns actionable suggestions from quality assessment for improving OCR success.
  List<String>? get recommendations => _lastRecommendations;

  /// Last OCR confidence score for user confidence indication (Phase 2 Enhancement).
  /// Returns confidence of extracted text (0.0-1.0) enabling reliability display in UI.
  double? get confidence => _lastConfidence;

  /// All recipes detected on the current page (≥1 when parsing succeeded).
  List<Recipe> get parsedRecipes => List.unmodifiable(_parsedRecipes);

  /// True when the page held more than one recipe → show the picker.
  bool get hasMultipleRecipes => _parsedRecipes.length > 1;

  /// BUT-1171: test-only seams that populate the REAL backing fields the
  /// production import pipeline reads (`_ocrText`, `_imageBytes`). The former
  /// test double shadowed these with separate fields plus getter overrides, so
  /// `performImport` / `saveImportedRecipe` ran against empty production state —
  /// a leak that masked the genuine save path and held three tests permanently
  /// red. Tests now set the real fields, exercising the production code.
  @visibleForTesting
  void setOcrTextForTesting(String text) {
    _ocrText = text;
    notifyListeners();
  }

  @visibleForTesting
  void setImageBytesForTesting(Uint8List? bytes) {
    _imageBytes = bytes;
    notifyListeners();
  }

  /// Drives the real multi-recipe auto-parse path (normally fired inside the
  /// OCR pipeline) so tests can verify single vs. multi routing without a
  /// camera/OCR round-trip.
  @visibleForTesting
  Future<void> parseOcrTextForTesting(String text) => _autoParseOcrText(text);

  /// BUT-903: append a page with pre-extracted OCR text (skipping the
  /// camera/OCR round-trip) and run the real combine+parse path, so tests can
  /// exercise multi-page ordering, removal, reordering, and the cap without a
  /// platform image picker. Mirrors what [_ocrAndAppendPage] does after a
  /// successful OCR.
  @visibleForTesting
  Future<void> addPageForTesting(Uint8List bytes, String text) async {
    if (!canAddPage) return;
    _pages.add(_PhotoPage(bytes: bytes, text: text));
    await _recombineAndParse();
  }

  /// OCR processing state indicator for UI progress indication and interaction control.
  /// Indicates active OCR processing operations for loading indicators
  /// and user interaction management during photo processing.
  bool get isProcessing => isLoading;

  /// Import readiness indicator based on OCR results availability.
  /// Determines whether photo import can proceed based on OCR text availability
  /// enabling proper import workflow validation and user guidance.
  /// **Override Implementation**: Extends ImportBaseViewModel canImport with OCR-specific validation.
  @override
  bool get canImport => hasOcrResult;

  /// Photo import type identifier for analytics tracking and logging coordination.
  /// Provides import type classification for analytics tracking, logging coordination,
  /// and import workflow identification throughout photo import operations.
  /// **Override Implementation**: Implements ImportBaseViewModel importType interface.
  @override
  String get importType => 'photo';

  /// Captures a photo from the camera and runs the OCR + auto-parse pipeline.
  /// Starts a fresh import — replaces any existing pages.
  Future<void> pickImageFromCamera() async {
    await _pickImageAndProcess(ImageSource.camera);
  }

  /// Selects an image from the gallery and runs the OCR + auto-parse pipeline.
  /// Starts a fresh import — replaces any existing pages.
  Future<void> pickImageFromGallery() async {
    await _pickImageAndProcess(ImageSource.gallery);
  }

  /// BUT-903: append a camera photo as the next page of the SAME recipe, then
  /// re-OCR-combine + re-parse. No-op (with an error) once the cap is hit.
  Future<void> addPageFromCamera() async {
    await _pickImageAndProcess(ImageSource.camera, addAsPage: true);
  }

  /// BUT-903: append a gallery photo as the next page of the same recipe.
  Future<void> addPageFromGallery() async {
    await _pickImageAndProcess(ImageSource.gallery, addAsPage: true);
  }

  /// BUT-903: drop the page at [index] and recombine. Removing the last page
  /// clears the whole import (same as [clearPhoto]).
  Future<void> removePage(int index) async {
    if (isDisposed || index < 0 || index >= _pages.length) return;
    _pages.removeAt(index);
    if (_pages.isEmpty) {
      clearPhoto();
      return;
    }
    await _recombineAndParse();
  }

  /// BUT-903: move the page at [oldIndex] to [newIndex] (drag-to-reorder) and
  /// recombine — page order is the OCR concatenation order, so reordering can
  /// fix an out-of-sequence capture without re-shooting.
  Future<void> reorderPage(int oldIndex, int newIndex) async {
    if (isDisposed) return;
    if (oldIndex < 0 || oldIndex >= _pages.length) return;
    var target = newIndex;
    // ReorderableListView reports an index past the end when dropping last.
    if (target > oldIndex) target -= 1;
    target = target.clamp(0, _pages.length - 1);
    if (target == oldIndex) return;
    final page = _pages.removeAt(oldIndex);
    _pages.insert(target, page);
    await _recombineAndParse();
  }

  /// Re-runs OCR on the current image after a failure — without this the user
  /// is stuck in a navigation trap (failed OCR, no recovery besides re-shoot).
  Future<void> retryOcr() async {
    if (_imageBytes == null) {
      setError(AppLocale.current.errorNoImageToProcess);
      return;
    }

    // BUT-610: same offline pre-check — a retry re-runs the OCR cloud cascade.
    if (!isOnline) {
      setError(AppLocale.current.importOfflineMessage);
      return;
    }

    await executeAsyncVoid(() async {
      clearError();
      // Re-OCR the cover image as a fresh single page. A retry follows a failed
      // first-page OCR (the failing page was never appended), so the page set
      // restarts from this image.
      _pages.clear();
      await _ocrAndAppendPage(_imageBytes!);
    }, errorPrefix: AppLocale.current.errorGeneric);
  }

  /// Whether the retry button should show (image still in memory).
  bool get canRetryOcr => _imageBytes != null;

  // BUT-410 heirloom getters/setters live in PhotoImportHeirloomFormMixin.

  /// Clears all photo + OCR state. Call sites are explicit user actions only
  /// (preview X button, post-save cleanup) — see the draft note below.
  void clearPhoto() {
    if (isDisposed) return;

    _imageBytes = null;
    _ocrText = '';
    _pages.clear();
    _lastQualityScore = null;
    _lastRecommendations = null;
    _lastConfidence = null;
    _parsedRecipes.clear();
    // Heirloom form clears with the photo — they belong to the same capture.
    clearHeirloomForm();
    clearImportData();

    // BUT-910: both clearPhoto call sites are explicit user actions (the
    // preview's X button, post-save cleanup) — the persisted draft goes too.
    // Nav-away does NOT come through here, so drafts survive navigation.
    unawaited(discardPersistedDraft());

    // NB: the OCR result cache is intentionally NOT cleared here. It is keyed by
    // image content, so persisting it across photo clears lets a re-import of
    // the same image hit the cache instead of re-spending OCR provider quota
    // (CLAUDE.md cost principles). Tests that need a clean cache call
    // OCRExtractionService.clearCacheForTesting() in their teardown.
  }

  /// BUT-910: restores the persisted draft into live state — staged image (when
  /// available; web and purged-temp degrade to text-only), OCR text, and a
  /// fresh auto-parse so the parsed-recipe state matches what the user saw.
  /// Returns false when there is no draft to restore.
  Future<bool> restoreDraft() async {
    final draft = await loadPersistedDraft();
    if (draft == null || isDisposed) return false;
    final bytes = await readDraftImage(draft);
    if (isDisposed) return false;
    _imageBytes = bytes;
    _ocrText = draft.ocrText;
    // BUT-903: the draft schema stages one image + the combined OCR text, so a
    // restore rebuilds a single-page set. The user can add more pages on top.
    _pages
      ..clear()
      ..add(_PhotoPage(bytes: bytes ?? Uint8List(0), text: draft.ocrText));
    notifyListeners();
    await _autoParseOcrText(_ocrText);
    return true;
  }

  @override
  void clearAll() => clearPhoto();

  /// Manual parse of the OCR text — the fallback when auto-parse failed or
  /// the user re-triggers import explicitly.
  @override
  Future<void> performImport() async {
    if (!hasOcrResult) {
      setError(AppLocale.current.errorPleaseEnterText);
      return;
    }

    final recipe = await parseTextToRecipe(_ocrText);
    preserveOrSetParsedRecipe(recipe);
  }

  /// Shared camera/gallery pipeline: pick → validate (format, ≤15MB) →
  /// quality gate → OCR → combine → auto-parse.
  ///
  /// [addAsPage] = false starts a fresh import (replaces all pages); true
  /// (BUT-903) appends the picked image as the next page of the current recipe
  /// and re-runs the combine+parse over every page in order.
  Future<void> _pickImageAndProcess(
    ImageSource source, {
    bool addAsPage = false,
  }) async {
    // BUT-610: offline pre-check — OCR runs a multi-provider cloud cascade
    // (OCR.space → Google Vision → Tesseract) that spins 30–90s on provider
    // timeouts when offline. Fail fast before opening the picker.
    if (!isOnline) {
      setError(AppLocale.current.importOfflineMessage);
      return;
    }
    if (addAsPage && !canAddPage) {
      setError(AppLocale.current.importPhotoPagesMaxReached(maxPages));
      return;
    }
    if (!addAsPage) {
      clearImportData();
      _pages.clear();
    }

    await executeAsyncVoid(() async {
      // Pick image
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(
        source: source,
        maxWidth: 2048, // Limit width to reduce file size
        maxHeight: 2048, // Limit height to reduce file size
        imageQuality:
            85, // Compress image to reduce file size while maintaining OCR quality
      );

      if (picked == null) {
        throw Exception(AppLocale.current.errorNoImageSelected);
      }

      // Validate image format
      final fileName = picked.name.toLowerCase();
      if (!fileName.endsWith('.jpg') &&
          !fileName.endsWith('.jpeg') &&
          !fileName.endsWith('.png')) {
        throw Exception(
          AppLocale.current.errorImageFormatUnsupported,
        );
      }

      // Read image bytes
      final bytes = await picked.readAsBytes();

      // Validate image size (max 15MB after compression)
      final sizeInMB = bytes.length / (1024 * 1024);
      if (sizeInMB > 15) {
        throw Exception(
          AppLocale.current.errorImageTooLarge(sizeInMB.toStringAsFixed(1)),
        );
      }

      // Reflect the new image immediately: first page drives the live preview.
      if (!addAsPage || _pages.isEmpty) {
        _imageBytes = bytes;
      }
      notifyListeners();

      // Pre-flight quality assessment (Phase 2 Enhancement)
      final qualityAssessment = await OCRExtractionService.instance
          .assessImageQuality(bytes);
      _lastQualityScore = qualityAssessment.qualityScore;
      _lastRecommendations = qualityAssessment.recommendations;

      // BUT-660: hard-reject before OCR — saves quota on images that cannot
      // yield usable text (bytes too small, resolution too low). The OCR
      // service has a defense-in-depth gate too, but throwing here surfaces
      // the message via the standard error path the UI already renders.
      if (qualityAssessment.isRejected) {
        throw Exception(
          qualityAssessment.rejectionReason ??
              AppLocale.current.ocrImageRejected,
        );
      }

      // OCR just this page, append it, then combine + parse the whole set.
      await _ocrAndAppendPage(bytes);
    }, errorPrefix: AppLocale.current.errorGeneric);
  }

  /// BUT-903: multi-provider OCR (OCR.space → Google Vision → Tesseract) on a
  /// single page, append it to [_pages] in capture order, then recombine the
  /// per-page text and auto-parse the whole recipe. Throws when this page
  /// yields no text — a blank page must surface rather than silently extend the
  /// recipe with nothing.
  Future<void> _ocrAndAppendPage(Uint8List imageBytes) async {
    final ocrResult = await OCRExtractionService.instance.extractText(
      imageBytes,
    );

    if (!ocrResult.isSuccessful || ocrResult.text.isEmpty) {
      // Enhanced error messaging (Phase 2 Enhancement) — also drives the
      // quality-field getters via its side effects.
      throw Exception(_buildEnhancedErrorMessage(ocrResult));
    }

    _pages.add(_PhotoPage(bytes: imageBytes, text: ocrResult.text));
    _lastConfidence = ocrResult.confidence;
    await _recombineAndParse();
  }

  /// BUT-903: rebuild the combined OCR text from every page in order, keep the
  /// first page as the live preview/heirloom image, persist the draft, then run
  /// ONE auto-parse over the joined text. Shared by add/remove/reorder so all
  /// page mutations converge on the same combine+parse path.
  Future<void> _recombineAndParse() async {
    if (_pages.isEmpty) return;
    _imageBytes = _pages.first.bytes;
    // Blank-line separator so the parser/splitter treats page boundaries the
    // same as the blank lines that already delimit sections within a page.
    _ocrText = _pages.map((p) => p.text).join('\n\n');
    notifyListeners();

    // BUT-910: OCR is the expensive step — persist as soon as combined text
    // exists so nav-away can't lose it. Fire-and-forget; persist the first
    // page's bytes (the draft schema stages one image) alongside the full text.
    unawaited(
      persistPhotoDraft(imageBytes: _imageBytes!, ocrText: _ocrText),
    );

    await _autoParseOcrText(_ocrText);
  }

  /// Parse-only auto-parse: recipes exist in memory until the user explicitly
  /// saves (no silent persistence). Failures degrade to the manual-parse path.
  Future<void> _autoParseOcrText(String text) async {
    try {
      final result = await importManager.autoParseMulti(text);
      final recipes = result.successfulRecipes;
      _parsedRecipes
        ..clear()
        ..addAll(recipes);
      if (recipes.length == 1) {
        // Single recipe → keep the existing single-recipe behaviour exactly:
        // setParsedRecipe drives every current getter/consumer unchanged.
        setParsedRecipe(recipes.first);
      } else if (recipes.length > 1) {
        notifyListeners();
      }
    } catch (e) {
      // Don't throw error for auto-parsing failures
      // User can still manually parse the OCR text
    }
  }

  /// Save the recipes the user ticked in the multi-recipe picker. Uses the
  /// import-layer save per recipe; heirloom attachment is intentionally NOT
  /// applied here — a multi-recipe page is not a single heirloom scan.
  int _lastSaveFailureCount = 0;

  /// How many recipes failed in the most recent [saveSelectedRecipes] batch.
  /// Lets the view show a partial-failure summary ("X saved, Y failed").
  int get lastSaveFailureCount => _lastSaveFailureCount;

  Future<bool> saveSelectedRecipes(List<Recipe> recipes) async {
    if (recipes.isEmpty) {
      setError(AppLocale.current.errorNoRecipeToSave);
      return false;
    }
    return executeAsyncVoid(() async {
      // Save every recipe, continuing past individual failures so one bad
      // recipe doesn't drop the rest. Only a total failure is a hard error;
      // a partial one keeps the saved recipes and reports the failed count.
      _lastSaveFailureCount = 0;
      for (final recipe in recipes) {
        final result = await importManager.saveImportedRecipe(recipe);
        if (!result.isSuccess) _lastSaveFailureCount++;
      }
      if (_lastSaveFailureCount == recipes.length) {
        throw Exception(AppLocale.current.errorGeneric);
      }
    });
  }

  /// BUT-1022: testing seam — the metadata→Swedish-copy contract is load-bearing
  /// for the error the user sees, so it gets direct unit coverage without mocking
  /// the OCR singleton. Build logic lives in [OcrErrorMessageBuilder].
  @visibleForTesting
  String buildEnhancedErrorMessageForTesting(OCRResult result) =>
      _buildEnhancedErrorMessage(result);

  /// BUT-1154: message construction moved to [OcrErrorMessageBuilder]; the VM
  /// keeps the quality-field side effects that the `qualityScore` /
  /// `recommendations` / `confidence` getters expose.
  String _buildEnhancedErrorMessage(OCRResult result) {
    final built = OcrErrorMessageBuilder.build(result);
    _lastQualityScore = built.qualityScore;
    _lastRecommendations = built.recommendations;
    _lastConfidence = built.confidence;
    return built.message;
  }

  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'hasImage': hasImage,
    'hasOcrResult': hasOcrResult,
    'pageCount': pageCount,
    'ocrTextLength': _ocrText.length,
    'isProcessing': isProcessing,
    'imageBytesSize': _imageBytes?.length ?? 0,
    'ocrServiceStatus': OCRExtractionService.instance.getServiceStatus(),
  };

  @override
  void dispose() {
    // BUT-910: dispose the manager, do NOT discard the draft — surviving
    // disposal (the view disposes this VM on nav-away) is the feature.
    disposeDraftPersistence();
    _imageBytes = null;
    _ocrText = '';
    _pages.clear();
    _lastQualityScore = null;
    _lastRecommendations = null;
    _lastConfidence = null;
    _parsedRecipes.clear();
    super.dispose();
  }
}

/// BUT-903: one captured page of a multi-page photo import — the raw bytes and
/// the OCR text extracted from just that page. Pages are concatenated in list
/// order to form the combined recipe text.
class _PhotoPage {
  final Uint8List bytes;
  final String text;

  const _PhotoPage({required this.bytes, required this.text});
}
