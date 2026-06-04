/// Photo import ViewModel with OCR processing for converting recipe images to Recipe objects.
/// **Features:** Camera/gallery capture, OCR.space API, multi-engine text extraction, auto-parsing, Swedish localization.
/// ```dart
/// final vm = PhotoImportViewModel(importManager: ServiceLocator.get<ImportManager>());
/// await vm.pickImageFromCamera();
/// if (vm.hasOcrResult && vm.hasParsedRecipe) { final recipe = vm.parsedRecipe; }
/// // Manual import processing if auto-parsing fails
/// if (photoImportViewModel.hasOcrResult && !photoImportViewModel.hasParsedRecipe) {
///   await photoImportViewModel.performImport();
///   if (photoImportViewModel.hasParsedRecipe) {
///     final recipe = photoImportViewModel.parsedRecipe;
///   }
/// }
/// // State monitoring and processing status
/// if (photoImportViewModel.isProcessing) {
///   // Show OCR processing indicator
/// } else if (photoImportViewModel.canImport) {
///   // OCR complete and ready for recipe parsing
/// }
/// // Photo data management and cleanup
/// photoImportViewModel.clearPhoto();
/// // All photo and OCR data cleared
/// ```

// lib/viewmodels/photo_import_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/viewmodels/photo_import/photo_import_heirloom_form_mixin.dart';
import 'package:butlery/viewmodels/photo_import/ocr_error_message_builder.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Photo-import ViewModel: camera/gallery capture → multi-provider OCR →
/// auto-parse to a Recipe. Extends [ImportBaseViewModel] for the shared
/// import lifecycle; heirloom form state lives in
/// [PhotoImportHeirloomFormMixin].
class PhotoImportViewModel extends ImportBaseViewModel
    with PhotoImportHeirloomFormMixin {
  /// Raw image bytes from selected photo for OCR processing and display.
  /// Stores captured or selected image data enabling OCR processing
  /// and image preview functionality throughout photo import workflow.
  Uint8List? _imageBytes;

  /// Extracted text from OCR processing for recipe parsing and display.
  /// Stores OCR results enabling recipe parsing, text review,
  /// and manual editing throughout photo import functionality.
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

  PhotoImportViewModel({required super.importManager}) {
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

  /// Retries OCR processing on the currently selected image after a previous failure.
  /// Enables users to retry OCR extraction without losing their photo, fixing the navigation trap
  /// where users become stuck after OCR failures with no recovery options.
  /// **Retry Process:**
  /// - Validates that image data is available for retry
  /// - Clears previous error state for fresh attempt
  /// - Re-runs OCR processing on existing image bytes
  /// - Provides user feedback through state management
  /// **Usage Example:**
  /// ```dart
  /// if (photoImportViewModel.hasError && photoImportViewModel.hasImage) {
  ///   await photoImportViewModel.retryOcr();
  /// }
  /// ```
  /// **Throws**: Exception if no image data is available for retry.
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

  /// Indicates whether OCR retry is possible based on image availability.
  /// Used by the UI to determine whether to show retry button, providing
  /// clear user feedback about available recovery options.
  /// Returns true if image data exists and retry is possible, false otherwise.
  bool get canRetryOcr => _imageBytes != null;

  // BUT-410 heirloom getters/setters live in PhotoImportHeirloomFormMixin.

  /// Clears all photo and OCR data with comprehensive state cleanup and memory management.
  /// Performs complete photo import state cleanup including image data, OCR results,
  /// quality metrics, and imported recipe data with disposal safety checks and memory management.
  /// **Cleanup Process:**
  /// - Image bytes disposal and memory cleanup
  /// - OCR text results clearing
  /// - OCR quality data and confidence scores clearing (Phase 2 Enhancement)
  /// - Imported recipe data cleanup through base class
  /// - State coordination and UI notification
  /// **Usage Example:**
  /// ```dart
  /// photoImportViewModel.clearPhoto();
  /// // All photo and OCR data cleared, ready for new import
  /// ```
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

    // Also clear OCR cache for testing
    OCRExtractionService.instance.clearAllCache();
  }

  /// Alias for clearPhoto() to provide consistent API naming conventions.
  /// This method provides alternative naming for clearing all photo import data
  /// maintaining backward compatibility and consistent API patterns across ViewModels.
  /// Delegates to clearPhoto() for actual implementation.
  /// **Override Implementation**: Overrides ImportBaseViewModel clearAll() with photo-specific cleanup.
  /// **Usage Example:**
  /// ```dart
  /// photoImportViewModel.clearAll(); // Alternative to clearPhoto()
  /// ```
  @override
  void clearAll() => clearPhoto();

  /// Performs manual import operation with OCR text parsing and recipe generation.
  /// Performs manual recipe import from OCR text when automatic parsing fails or
  /// user initiates manual import, with comprehensive validation and error handling.
  /// **Manual Import Process:**
  /// - OCR text availability validation
  /// - Recipe parsing through ImportManager text parsing strategy
  /// - Parsed recipe state update and UI coordination
  /// - Comprehensive error handling with Swedish localized messages
  /// **Override Implementation**: Implements ImportBaseViewModel performImport interface with OCR-specific logic.
  /// **Usage Example:**
  /// ```dart
  /// if (photoImportViewModel.hasOcrResult) {
  ///   await photoImportViewModel.performImport();
  ///   if (photoImportViewModel.hasParsedRecipe) {
  ///     final recipe = photoImportViewModel.parsedRecipe;
  ///   }
  /// }
  /// ```
  @override
  Future<void> performImport() async {
    if (!hasOcrResult) {
      setError(AppLocale.current.errorPleaseEnterText);
      return;
    }

    final recipe = await parseTextToRecipe(_ocrText);
    preserveOrSetParsedRecipe(recipe);
  }

  /// Performs unified image selection and OCR processing with comprehensive workflow coordination.
  /// [source] Image source for capture or selection (camera or gallery)
  /// Executes complete image selection and OCR workflow including image capture,
  /// bytes processing, validation, OCR execution, and automatic recipe parsing
  /// with comprehensive error handling and state coordination.
  /// **Unified Processing Workflow:**
  /// - Import data cleanup and state preparation
  /// - Image selection through ImagePicker with source-specific handling
  /// - Image validation (size, format) before processing
  /// - Image bytes reading and state update
  /// - OCR processing with multi-engine support
  /// - Automatic recipe parsing from extracted text
  /// - Comprehensive error handling with Swedish localized messages
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

  /// Performs comprehensive OCR processing using universal multi-provider OCR service.
  /// [imageBytes] Raw image data for OCR processing and text extraction
  /// Executes sophisticated OCR processing using the universal OCR service with
  /// multi-provider fallback strategy, image quality assessment, and automatic
  /// recipe parsing coordination ensuring optimal text extraction on all devices.
  /// **Universal OCR Processing Strategy:**
  /// 1. Image quality assessment and preprocessing
  /// 2. Multi-provider OCR processing (OCR.space → Google Vision → Tesseract)
  /// 3. Circuit breaker patterns for service resilience
  /// 4. Swedish language optimization and confidence scoring
  /// 5. Automatic recipe parsing from extracted text
  /// 6. Comprehensive error handling with user guidance
  /// **Throws**: Exception if no text can be extracted from image.
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

  /// Performs automatic recipe parsing from OCR text WITHOUT saving to storage.
  /// [text] Extracted OCR text for automatic recipe parsing and structure analysis
  /// Attempts automatic recipe parsing from OCR text using ImportManager parse-only functionality
  /// with intelligent structure recognition and recipe pattern detection. Creates recipe objects
  /// in memory only without persisting to storage, preventing unwanted auto-saving.
  /// **Parse-Only Process:**
  /// - OCR text analysis through ImportManager autoParseOnly
  /// - Recipe structure recognition and pattern detection
  /// - Automatic recipe object generation in memory only
  /// - Graceful failure handling with manual parsing fallback
  /// - State update with parsed recipe if successful
  /// - NO SAVING TO STORAGE - recipe exists in memory only
  /// **Note**: Failures are handled gracefully - users can still manually parse OCR text.
  /// Recipes are NOT saved automatically and require explicit user action to save.
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

  /// Provides comprehensive debugging state information for photo import development and troubleshooting.
  /// Returns map containing debug information including photo import state, OCR processing results,
  /// image data availability, and inherited debug state from ImportBaseViewModel for comprehensive
  /// development support and troubleshooting capabilities.
  /// **Debug Information Includes:**
  /// - Image selection and processing status
  /// - OCR results availability and text length metrics
  /// - Photo import specific state and processing indicators
  /// - Inherited ImportBaseViewModel debug state information
  /// - OCR processing status and image handling debugging information
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

  /// Disposes photo import ViewModel with comprehensive cleanup and memory management.
  /// Performs complete resource cleanup including image data disposal, OCR text cleanup,
  /// quality metrics, and memory management ensuring proper photo import ViewModel lifecycle management.
  /// **Disposal Process:**
  /// - Image bytes disposal and memory cleanup
  /// - OCR text data cleanup and state reset
  /// - OCR quality data and confidence scores cleanup (Phase 2 Enhancement)
  /// - Parent disposal coordination through super.dispose()
  /// - Resource cleanup and memory management
  /// **Override Implementation**: Extends ImportBaseViewModel disposal with photo-specific cleanup.
  @override
  void dispose() {
    _imageBytes = null;
    _ocrText = '';
    _lastQualityScore = null;
    _lastRecommendations = null;
    _lastConfidence = null;
    _parsedRecipes.clear();
    super.dispose();
  }
}
