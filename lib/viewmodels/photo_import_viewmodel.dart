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
import 'package:butlery/viewmodels/import_base_viewmodel.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Comprehensive photo import ViewModel providing advanced OCR processing and image recognition through ImportManager coordination.
/// Specializes in photo-based recipe importing from camera captures and gallery images through OCR technology,
/// image processing, and intelligent text extraction. Extends ImportBaseViewModel to provide complete photo import
/// functionality with OCR coordination, image processing, and recipe parsing workflow management.
/// **Core Responsibilities:**
/// - Advanced photo capture and processing with camera and gallery integration
/// - OCR technology coordination with multi-engine support and fallback strategies
/// - Image recognition and text extraction with orientation detection and clarity optimization
/// - Automatic recipe parsing from OCR text with intelligent structure recognition
/// - Swedish localized error messages and user feedback coordination
class PhotoImportViewModel extends ImportBaseViewModel {
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

  // ── BUT-410 heirloom form state ─────────────────────────────────────────
  // Kept separate from OCR state because heirloom is an opt-in overlay on
  // the same photo — toggling it shouldn't reset OCR progress and vice versa.

  /// Whether the user has flagged this scan as an heirloom ("Farmors lapp").
  bool _isHeirloom = false;

  /// Writer attribution — bound to the writerName TextField. Max 100 chars
  /// (enforced both at the field level and in HeirloomMetadata's ctor).
  String _heirloomWriterName = '';

  /// Year input parsed from the year TextField. Null until the user types
  /// a valid 1800..currentYear value; parseable invalid values stay null.
  int? _heirloomYear;

  /// Short origin note — max 200 chars.
  String _heirloomNote = '';

  /// True when the device has no internet connection and the heirloom
  /// upload is queued. Used by the view to show the offline banner.
  bool _isOfflineQueued = false;

  /// Initializes photo import ViewModel with comprehensive ImportManager integration and OCR preparation.
  /// [importManager] ImportManager instance for photo import strategy coordination and recipe parsing
  /// Establishes photo import infrastructure with ImportManager integration, enabling comprehensive
  /// photo-to-recipe functionality with OCR processing, image handling, and unified state management.
  /// **Initialization Process:**
  /// - ImportManager integration for photo import strategy execution
  /// - Universal OCR service preparation with multi-provider support
  /// - Image handling setup with camera and gallery integration
  /// - Recipe parsing coordination for OCR text processing
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

  /// Raw image bytes from selected photo for display and processing coordination.
  /// Provides access to captured or selected image data enabling image preview,
  /// OCR processing coordination, and photo import workflow management.
  Uint8List? get imageBytes => _imageBytes;

  /// Text extracted from OCR processing for review and recipe parsing.
  /// Provides access to OCR results enabling text review, manual editing,
  /// and recipe parsing coordination throughout photo import functionality.
  String get ocrText => _ocrText;

  /// Image selection status indicator for conditional UI rendering and workflow management.
  /// Indicates whether image has been captured or selected enabling
  /// UI state management and photo import workflow progression.
  bool get hasImage => _imageBytes != null;

  /// OCR processing results availability indicator for parsing and display coordination.
  /// Indicates whether OCR has produced text results enabling
  /// recipe parsing workflow and text review functionality.
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

  /// Captures photo from camera and processes with comprehensive OCR coordination.
  /// Performs camera photo capture with automatic OCR processing including
  /// image optimization, text extraction, and automatic recipe parsing coordination
  /// with comprehensive error handling and state management.
  /// **Camera Capture Process:**
  /// - Camera interface activation through ImagePicker
  /// - Image capture and bytes processing
  /// - Automatic OCR processing with multi-engine support
  /// - Intelligent recipe parsing from extracted text
  /// - State coordination and UI notification
  /// **Usage Example:**
  /// ```dart
  /// await photoImportViewModel.pickImageFromCamera();
  /// if (photoImportViewModel.hasOcrResult) {
  ///   final extractedText = photoImportViewModel.ocrText;
  /// }
  /// ```
  Future<void> pickImageFromCamera() async {
    await _pickImageAndProcess(ImageSource.camera);
  }

  /// Selects image from gallery and processes with comprehensive OCR coordination.
  /// Performs gallery image selection with automatic OCR processing including
  /// image optimization, text extraction, and automatic recipe parsing coordination
  /// with comprehensive error handling and state management.
  /// **Gallery Selection Process:**
  /// - Gallery interface activation through ImagePicker
  /// - Image selection and bytes processing
  /// - Automatic OCR processing with multi-engine support
  /// - Intelligent recipe parsing from extracted text
  /// - State coordination and UI notification
  /// **Usage Example:**
  /// ```dart
  /// await photoImportViewModel.pickImageFromGallery();
  /// if (photoImportViewModel.hasImage) {
  ///   // Image selected and OCR processing initiated
  /// }
  /// ```
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

  // ── BUT-410 heirloom getters/setters ────────────────────────────────────

  /// Whether the user has marked this scan as an heirloom recipe.
  bool get isHeirloom => _isHeirloom;

  /// Writer attribution, as currently typed. Empty string = not provided.
  String get heirloomWriterName => _heirloomWriterName;

  /// Year parsed from the year field, or null if empty/invalid.
  int? get heirloomYear => _heirloomYear;

  /// Short origin note, as currently typed.
  String get heirloomNote => _heirloomNote;

  /// True while an heirloom upload is pending because the device is offline.
  bool get isOfflineQueued => _isOfflineQueued;

  set isHeirloom(bool value) {
    if (isDisposed || _isHeirloom == value) return;
    _isHeirloom = value;
    notifyListeners();
  }

  set heirloomWriterName(String value) {
    if (isDisposed) return;
    // Guard against very long paste-ins — HeirloomMetadata enforces 100 at
    // construction time, but we truncate here so the field stays usable.
    final trimmed = value.length > 100 ? value.substring(0, 100) : value;
    if (_heirloomWriterName == trimmed) return;
    _heirloomWriterName = trimmed;
    notifyListeners();
  }

  set heirloomYear(int? value) {
    if (isDisposed || _heirloomYear == value) return;
    _heirloomYear = value;
    notifyListeners();
  }

  set heirloomNote(String value) {
    if (isDisposed) return;
    final trimmed = value.length > 200 ? value.substring(0, 200) : value;
    if (_heirloomNote == trimmed) return;
    _heirloomNote = trimmed;
    notifyListeners();
  }

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
    // Heirloom form clears with the photo — they belong to the same capture.
    _isHeirloom = false;
    _heirloomWriterName = '';
    _heirloomYear = null;
    _heirloomNote = '';
    _isOfflineQueued = false;
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
      final importResult = await importManager.autoParseOnly(text);
      if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
        setParsedRecipe(importResult.importedRecipes.first);
      }
    } catch (e) {
      // Don't throw error for auto-parsing failures
      // User can still manually parse the OCR text
    }
  }

  /// Builds enhanced error message from OCR failure with quality data and actionable guidance (Phase 2 Enhancement).
  /// [result] OCR processing result containing failure metadata, quality scores, and recommendations
  /// Extracts rich quality data from OCRResult metadata and constructs specific, actionable error messages
  /// in Swedish based on actual failure reasons rather than generic fallback messages.
  /// **Enhanced Error Message Strategy:**
  /// - Quality-based messaging: Low quality score → specific quality issues
  /// - Circuit breaker awareness: All providers down → service availability guidance
  /// - Recommendation surfacing: Display actionable suggestions from quality assessment
  /// - Progressive guidance: Multiple recovery options from retry to manual entry
  /// **Metadata Extracted:**
  /// - quality_assessment: Image quality score (0.0-1.0)
  /// - recommendations: List of actionable quality improvements
  /// - circuit_breakers: Provider availability status (OCR.space, Google Vision, Tesseract)
  /// BUT-1022: testing seam — the metadata-string contract between
  /// `OCRExtractionService._classifyProviderErrors` and this method is
  /// load-bearing for the Swedish error copy the user sees. Direct unit
  /// coverage avoids needing to mock the singleton OCR service.
  @visibleForTesting
  String buildEnhancedErrorMessageForTesting(OCRResult result) =>
      _buildEnhancedErrorMessage(result);

  String _buildEnhancedErrorMessage(OCRResult result) {
    // Store quality data for UI access
    _lastQualityScore = result.metadata['quality_assessment'] as double?;
    _lastRecommendations =
        (result.metadata['recommendations'] as List?)?.cast<String>();
    _lastConfidence = result.confidence;

    // Extract circuit breaker states
    final circuitBreakers =
        result.metadata['circuit_breakers'] as Map<String, dynamic>?;
    final allProvidersDown = circuitBreakers != null &&
        circuitBreakers['ocr_space_state'] == 'open' &&
        circuitBreakers['google_vision_state'] == 'open' &&
        circuitBreakers['tesseract_state'] == 'open';

    // Build specific error message based on failure reasons
    final messageParts = <String>[];

    // BUT-963: typed failure classification from the OCR service. Wins over
    // the "no text extracted" generic fallback when the providers actually
    // threw a recognizable error (rate limit, timeout, network). Quality
    // gate still wins over classification — if the image was unreadable to
    // begin with, the user should fix the image, not retry blindly.
    final classification = result.metadata['failure_classification'] as String?;

    if (_lastQualityScore != null && _lastQualityScore! < 0.6) {
      final l = AppLocale.current;
      messageParts.add(
        l.errorImageQualityTooLow((_lastQualityScore! * 100).toInt()),
      );
    } else if (classification == 'rate_limit') {
      messageParts.add(AppLocale.current.errorOcrRateLimit);
    } else if (classification == 'timeout' || classification == 'network') {
      messageParts.add(AppLocale.current.errorOcrTimeout);
    } else if (allProvidersDown) {
      messageParts.add(
        AppLocale.current.errorOcrServicesUnavailable,
      );
    } else {
      messageParts.add(AppLocale.current.errorNoTextExtracted);
    }

    // Add specific recommendations if available
    if (_lastRecommendations != null && _lastRecommendations!.isNotEmpty) {
      messageParts.add('\n\n${AppLocale.current.labelImprovementSuggestions}');
      for (final recommendation in _lastRecommendations!) {
        messageParts.add('• $recommendation');
      }
    } else {
      // Generic quality tips if no specific recommendations
      messageParts.add(
        '\n\n${AppLocale.current.ocrQualityTips}',
      );
    }

    // Add recovery options
    messageParts.add(
      '\n\n${AppLocale.current.ocrRetryOrManual}',
    );

    return messageParts.join('\n');
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
    super.dispose();
  }
}
