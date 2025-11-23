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
  // ===== PHOTO IMPORT STATE =====

  /// Raw image bytes from selected photo for OCR processing and display.
  /// Stores captured or selected image data enabling OCR processing
  /// and image preview functionality throughout photo import workflow.
  Uint8List? _imageBytes;

  /// Extracted text from OCR processing for recipe parsing and display.
  /// Stores OCR results enabling recipe parsing, text review,
  /// and manual editing throughout photo import functionality.
  String _ocrText = '';

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
      debugPrint('✅ [PhotoImport] OCR service initialized successfully');
    } catch (e) {
      debugPrint('❌ [PhotoImport] Failed to initialize OCR service: $e');
    }
  }

  // ===== STATE ACCESSORS =====

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

  // ===== OCR SERVICE INTEGRATION =====

  // ===== PUBLIC OPERATIONS =====

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
      setError('Ingen bild att behandla');
      return;
    }

    await executeAsyncVoid(
      () async {
        clearError();
        await _performOcr(_imageBytes!);
      },
      errorPrefix: 'Kunde inte försöka OCR igen',
    );
  }

  /// Indicates whether OCR retry is possible based on image availability.
  /// Used by the UI to determine whether to show retry button, providing
  /// clear user feedback about available recovery options.
  /// Returns true if image data exists and retry is possible, false otherwise.
  bool get canRetryOcr => _imageBytes != null;

  /// Clears all photo and OCR data with comprehensive state cleanup and memory management.
  /// Performs complete photo import state cleanup including image data, OCR results,
  /// and imported recipe data with disposal safety checks and memory management.
  /// **Cleanup Process:**
  /// - Image bytes disposal and memory cleanup
  /// - OCR text results clearing
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
      setError('Ingen OCR-text tillgänglig för import');
      return;
    }

    final recipe = await parseTextToRecipe(_ocrText);
    setParsedRecipe(recipe);
  }

  // ===== PRIVATE OPERATIONS =====

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

    await executeAsyncVoid(
      () async {
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
          throw Exception('Ingen bild vald');
        }

        // Validate image format
        final fileName = picked.name.toLowerCase();
        if (!fileName.endsWith('.jpg') &&
            !fileName.endsWith('.jpeg') &&
            !fileName.endsWith('.png')) {
          throw Exception(
            'Bildformatet stöds inte. Använd JPEG eller PNG-format.',
          );
        }

        // Read image bytes
        final bytes = await picked.readAsBytes();

        // Validate image size (max 15MB after compression)
        final sizeInMB = bytes.length / (1024 * 1024);
        if (sizeInMB > 15) {
          throw Exception(
            'Bilden är för stor (${sizeInMB.toStringAsFixed(1)} MB). '
            'Använd en mindre bild eller komprimera den.',
          );
        }

        debugPrint(
            '🔍 [PhotoImport] Image validated: ${sizeInMB.toStringAsFixed(2)} MB, format: ${fileName.split('.').last}');

        _imageBytes = bytes;
        notifyListeners();

        // Perform OCR
        await _performOcr(bytes);
      },
      errorPrefix: 'Kunde inte bearbeta bild',
    );
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
    final imageSizeKB = imageBytes.length / 1024;
    debugPrint(
        '🔍 [PhotoImport] Starting universal OCR processing: ${imageSizeKB.toStringAsFixed(1)} KB');

    try {
      // Use the new universal OCR service
      final ocrResult =
          await OCRExtractionService.instance.extractText(imageBytes);

      debugPrint(
          '🔍 [PhotoImport] OCR completed - Method: ${ocrResult.processingMethod}, Confidence: ${ocrResult.confidence.toStringAsFixed(2)}');

      if (ocrResult.isSuccessful && ocrResult.text.isNotEmpty) {
        debugPrint(
            '✅ [PhotoImport] OCR succeeded, extracted ${ocrResult.text.length} characters');

        _ocrText = ocrResult.text;
        notifyListeners();

        // Auto-parse the OCR text into a recipe
        await _autoParseOcrText(ocrResult.text);
      } else {
        // Handle OCR failure with user-friendly message
        final errorMessage = ocrResult.errorMessage ??
            'Ingen text kunde extraheras från bilden. Kontrollera att:\n'
                '• Bilden innehåller tydlig, läsbar text\n'
                '• Texten är i god kontrast mot bakgrunden\n'
                '• Bilden inte är för suddig eller mörk';

        debugPrint('❌ [PhotoImport] OCR failed: $errorMessage');
        throw Exception(errorMessage);
      }
    } catch (e) {
      debugPrint('❌ [PhotoImport] OCR processing error: $e');
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
      debugPrint('Automatisk parsning misslyckades: $e');
    }
  }

  // ===== DEBUGGING SUPPORT =====

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
  /// and memory management ensuring proper photo import ViewModel lifecycle management.
  /// **Disposal Process:**
  /// - Image bytes disposal and memory cleanup
  /// - OCR text data cleanup and state reset
  /// - Parent disposal coordination through super.dispose()
  /// - Resource cleanup and memory management
  /// **Override Implementation**: Extends ImportBaseViewModel disposal with photo-specific cleanup.
  @override
  void dispose() {
    _imageBytes = null;
    _ocrText = '';
    super.dispose();
  }
}
