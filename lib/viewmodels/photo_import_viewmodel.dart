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
  Uint8List? _imageBytes;

  /// Extracted OCR text awaiting parse/review.
  String _ocrText = '';

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
  PhotoImportViewModel({
    required super.importManager,
    AutoSaveManager<PhotoImportDraft>? draftManager,
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

  Uint8List? get imageBytes => _imageBytes;

  String get ocrText => _ocrText;

  bool get hasImage => _imageBytes != null;

  bool get hasOcrResult => _ocrText.isNotEmpty;

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
  Future<void> pickImageFromCamera() async {
    await _pickImageAndProcess(ImageSource.camera);
  }

  /// Selects an image from the gallery and runs the OCR + auto-parse pipeline.
  Future<void> pickImageFromGallery() async {
    await _pickImageAndProcess(ImageSource.gallery);
  }

  /// Re-runs OCR on the current image after a failure — without this the user
  /// is stuck in a navigation trap (failed OCR, no recovery besides re-shoot).
  Future<void> retryOcr() async {
    if (_imageBytes == null) {
      setError(AppLocale.current.errorNoImageToProcess);
      return;
    }

    await executeAsyncVoid(() async {
      clearError();
      await _performOcr(_imageBytes!);
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

    // Also clear OCR cache for testing
    OCRExtractionService.instance.clearAllCache();
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
  /// quality gate → OCR → auto-parse.
  Future<void> _pickImageAndProcess(ImageSource source) async {
    clearImportData();

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

      _imageBytes = bytes;
      notifyListeners();

      // Pre-flight quality assessment (Phase 2 Enhancement)
      final qualityAssessment =
          await OCRExtractionService.instance.assessImageQuality(bytes);
      _lastQualityScore = qualityAssessment.qualityScore;
      _lastRecommendations = qualityAssessment.recommendations;

      // BUT-660: hard-reject before OCR — saves quota on images that cannot
      // yield usable text (bytes too small, resolution too low). The OCR
      // service has a defense-in-depth gate too, but throwing here surfaces
      // the message via the standard error path the UI already renders.
      if (qualityAssessment.isRejected) {
        throw Exception(qualityAssessment.rejectionReason ??
            AppLocale.current.ocrImageRejected);
      }

      // Perform OCR
      await _performOcr(bytes);
    }, errorPrefix: AppLocale.current.errorGeneric);
  }

  /// Multi-provider OCR (OCR.space → Google Vision → Tesseract) followed by
  /// auto-parse. Throws when no text could be extracted.
  Future<void> _performOcr(Uint8List imageBytes) async {
    try {
      // Use the new universal OCR service
      final ocrResult = await OCRExtractionService.instance.extractText(
        imageBytes,
      );

      if (ocrResult.isSuccessful && ocrResult.text.isNotEmpty) {
        _ocrText = ocrResult.text;
        _lastConfidence = ocrResult.confidence;
        notifyListeners();

        // BUT-910: OCR is the expensive step — persist the draft as soon as it
        // succeeds so nav-away/backgrounding can't lose it. Fire-and-forget:
        // a failed save must never block the parse below.
        unawaited(
          persistPhotoDraft(imageBytes: imageBytes, ocrText: ocrResult.text),
        );

        // Auto-parse the OCR text into a recipe
        await _autoParseOcrText(ocrResult.text);
      } else {
        // Handle OCR failure with enhanced error messaging (Phase 2 Enhancement)
        final errorMessage = _buildEnhancedErrorMessage(ocrResult);

        throw Exception(errorMessage);
      }
    } catch (e) {
      rethrow;
    }
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
  Future<bool> saveSelectedRecipes(List<Recipe> recipes) async {
    if (recipes.isEmpty) {
      setError(AppLocale.current.errorNoRecipeToSave);
      return false;
    }
    return executeAsyncVoid(() async {
      for (final recipe in recipes) {
        final result = await importManager.saveImportedRecipe(recipe);
        if (!result.isSuccess) {
          throw Exception(result.errorMessage ?? 'Failed to save recipe');
        }
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
    _lastQualityScore = null;
    _lastRecommendations = null;
    _lastConfidence = null;
    _parsedRecipes.clear();
    super.dispose();
  }
}
