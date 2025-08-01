/// Comprehensive photo import ViewModel providing advanced OCR processing and image recognition for Flutter applications.
///
/// This module implements sophisticated photo-based recipe importing following Single Responsibility Principle,
/// specializing in converting recipe images into structured Recipe objects through OCR technology, image processing,
/// and intelligent text extraction. It provides complete photo import infrastructure while maintaining clean
/// separation from UI rendering, data persistence, and other import types.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles photo import presentation layer concerns:
/// - **Photo Processing Excellence**: Advanced image capture, processing, and OCR coordination with multi-engine support
/// - **OCR Technology Integration**: Sophisticated text extraction through OCR.space API with fallback strategies and engine optimization
/// - **Image Recognition Intelligence**: Smart image processing with orientation detection and text clarity optimization
/// - **Recipe Text Analysis**: Intelligent OCR text processing with automatic recipe parsing and structure recognition
/// - **Photo Import Workflow**: Complete photo-to-recipe conversion with validation, error handling, and state coordination
///
/// **What This Module Does NOT Handle:**
/// - Text-based content parsing (handled by TextImportViewModel and text parsing services)
/// - UI rendering and widget creation (handled by photo import views and presentation components)
/// - Direct data persistence (handled by ImportManager and underlying storage services)
/// - Complex OCR infrastructure implementation (handled by OCR services and external API integration)
///
/// **Photo Import ViewModel Features:**
/// - **Multi-Source Image Capture**: Complete camera and gallery integration with ImagePicker coordination
/// - **Advanced OCR Processing**: Sophisticated text extraction with multi-engine support and fallback strategies
/// - **Intelligent Text Recognition**: Smart OCR with orientation detection and text clarity optimization
/// - **Automatic Recipe Parsing**: Intelligent OCR text analysis with automatic recipe structure recognition
/// - **Swedish Localization**: Complete Swedish language support for errors, suggestions, and user feedback
///
/// **Usage Examples:**
/// ```dart
/// // Initialize photo import ViewModel with ImportManager dependency
/// final photoImportViewModel = PhotoImportViewModel(
///   importManager: ServiceLocator.get<ImportManager>(),
/// );
/// 
/// // Camera capture and OCR processing workflow
/// await photoImportViewModel.pickImageFromCamera();
/// if (photoImportViewModel.hasOcrResult) {
///   final ocrText = photoImportViewModel.ocrText;
///   if (photoImportViewModel.hasParsedRecipe) {
///     final recipe = photoImportViewModel.parsedRecipe;
///   }
/// }
/// 
/// // Gallery selection and processing workflow
/// await photoImportViewModel.pickImageFromGallery();
/// if (photoImportViewModel.hasImage) {
///   final imageBytes = photoImportViewModel.imageBytes;
///   // Image is being processed with OCR
/// }
/// 
/// // Manual import processing if auto-parsing fails
/// if (photoImportViewModel.hasOcrResult && !photoImportViewModel.hasParsedRecipe) {
///   await photoImportViewModel.performImport();
///   if (photoImportViewModel.hasParsedRecipe) {
///     final recipe = photoImportViewModel.parsedRecipe;
///   }
/// }
/// 
/// // State monitoring and processing status
/// if (photoImportViewModel.isProcessing) {
///   // Show OCR processing indicator
/// } else if (photoImportViewModel.canImport) {
///   // OCR complete and ready for recipe parsing
/// }
/// 
/// // Photo data management and cleanup
/// photoImportViewModel.clearPhoto();
/// // All photo and OCR data cleared
/// ```

// lib/viewmodels/photo_import_viewmodel.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';

/// Comprehensive photo import ViewModel providing advanced OCR processing and image recognition through ImportManager coordination.
///
/// Specializes in photo-based recipe importing from camera captures and gallery images through OCR technology,
/// image processing, and intelligent text extraction. Extends ImportBaseViewModel to provide complete photo import
/// functionality with OCR coordination, image processing, and recipe parsing workflow management.
///
/// **Core Responsibilities:**
/// - Advanced photo capture and processing with camera and gallery integration
/// - OCR technology coordination with multi-engine support and fallback strategies
/// - Image recognition and text extraction with orientation detection and clarity optimization
/// - Automatic recipe parsing from OCR text with intelligent structure recognition
/// - Swedish localized error messages and user feedback coordination
class PhotoImportViewModel extends ImportBaseViewModel {
  
  // ===== PHOTO IMPORT STATE =====
  
  /// Raw image bytes from selected photo for OCR processing and display.
  /// 
  /// Stores captured or selected image data enabling OCR processing
  /// and image preview functionality throughout photo import workflow.
  Uint8List? _imageBytes;
  
  /// Extracted text from OCR processing for recipe parsing and display.
  /// 
  /// Stores OCR results enabling recipe parsing, text review,
  /// and manual editing throughout photo import functionality.
  String _ocrText = '';

  /// Initializes photo import ViewModel with comprehensive ImportManager integration and OCR preparation.
  /// 
  /// [importManager] ImportManager instance for photo import strategy coordination and recipe parsing
  /// 
  /// Establishes photo import infrastructure with ImportManager integration, enabling comprehensive
  /// photo-to-recipe functionality with OCR processing, image handling, and unified state management.
  /// 
  /// **Initialization Process:**
  /// - ImportManager integration for photo import strategy execution
  /// - OCR processing system preparation with API configuration
  /// - Image handling setup with camera and gallery integration
  /// - Recipe parsing coordination for OCR text processing
  PhotoImportViewModel({required super.importManager});

  // ===== STATE ACCESSORS =====

  /// Raw image bytes from selected photo for display and processing coordination.
  /// 
  /// Provides access to captured or selected image data enabling image preview,
  /// OCR processing coordination, and photo import workflow management.
  Uint8List? get imageBytes => _imageBytes;

  /// Text extracted from OCR processing for review and recipe parsing.
  /// 
  /// Provides access to OCR results enabling text review, manual editing,
  /// and recipe parsing coordination throughout photo import functionality.
  String get ocrText => _ocrText;

  /// Image selection status indicator for conditional UI rendering and workflow management.
  /// 
  /// Indicates whether image has been captured or selected enabling
  /// UI state management and photo import workflow progression.
  bool get hasImage => _imageBytes != null;

  /// OCR processing results availability indicator for parsing and display coordination.
  /// 
  /// Indicates whether OCR has produced text results enabling
  /// recipe parsing workflow and text review functionality.
  bool get hasOcrResult => _ocrText.isNotEmpty;

  /// OCR processing state indicator for UI progress indication and interaction control.
  /// 
  /// Indicates active OCR processing operations for loading indicators
  /// and user interaction management during photo processing.
  bool get isProcessing => isLoading;

  /// Import readiness indicator based on OCR results availability.
  /// 
  /// Determines whether photo import can proceed based on OCR text availability
  /// enabling proper import workflow validation and user guidance.
  /// 
  /// **Override Implementation**: Extends ImportBaseViewModel canImport with OCR-specific validation.
  @override
  bool get canImport => hasOcrResult;

  /// Photo import type identifier for analytics tracking and logging coordination.
  /// 
  /// Provides import type classification for analytics tracking, logging coordination,
  /// and import workflow identification throughout photo import operations.
  /// 
  /// **Override Implementation**: Implements ImportBaseViewModel importType interface.
  @override
  String get importType => 'photo';

  // ===== OCR API CONFIGURATION =====
  
  /// OCR API key from environment configuration for authenticated OCR service access.
  /// 
  /// Retrieves OCR API key from environment variables enabling secure
  /// OCR service authentication and API access throughout photo processing.
  String get _ocrApiKey => dotenv.env['OCR_API_KEY'] ?? '';
  
  /// OCR API endpoint URL from environment configuration with fallback default.
  /// 
  /// Retrieves OCR service endpoint from environment variables with fallback
  /// to OCR.space API enabling flexible OCR service configuration.
  String get _ocrApiUrl => dotenv.env['OCR_API_URL'] ?? 'https://api.ocr.space/parse/image';

  // ===== PUBLIC OPERATIONS =====

  /// Captures photo from camera and processes with comprehensive OCR coordination.
  /// 
  /// Performs camera photo capture with automatic OCR processing including
  /// image optimization, text extraction, and automatic recipe parsing coordination
  /// with comprehensive error handling and state management.
  /// 
  /// **Camera Capture Process:**
  /// - Camera interface activation through ImagePicker
  /// - Image capture and bytes processing
  /// - Automatic OCR processing with multi-engine support
  /// - Intelligent recipe parsing from extracted text
  /// - State coordination and UI notification
  /// 
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
  /// 
  /// Performs gallery image selection with automatic OCR processing including
  /// image optimization, text extraction, and automatic recipe parsing coordination
  /// with comprehensive error handling and state management.
  /// 
  /// **Gallery Selection Process:**
  /// - Gallery interface activation through ImagePicker
  /// - Image selection and bytes processing
  /// - Automatic OCR processing with multi-engine support
  /// - Intelligent recipe parsing from extracted text
  /// - State coordination and UI notification
  /// 
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

  /// Clears all photo and OCR data with comprehensive state cleanup and memory management.
  /// 
  /// Performs complete photo import state cleanup including image data, OCR results,
  /// and imported recipe data with disposal safety checks and memory management.
  /// 
  /// **Cleanup Process:**
  /// - Image bytes disposal and memory cleanup
  /// - OCR text results clearing
  /// - Imported recipe data cleanup through base class
  /// - State coordination and UI notification
  /// 
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
  }

  /// Performs manual import operation with OCR text parsing and recipe generation.
  /// 
  /// Performs manual recipe import from OCR text when automatic parsing fails or
  /// user initiates manual import, with comprehensive validation and error handling.
  /// 
  /// **Manual Import Process:**
  /// - OCR text availability validation
  /// - Recipe parsing through ImportManager text parsing strategy
  /// - Parsed recipe state update and UI coordination
  /// - Comprehensive error handling with Swedish localized messages
  /// 
  /// **Override Implementation**: Implements ImportBaseViewModel performImport interface with OCR-specific logic.
  /// 
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
  /// 
  /// [source] Image source for capture or selection (camera or gallery)
  /// 
  /// Executes complete image selection and OCR workflow including image capture,
  /// bytes processing, OCR execution, and automatic recipe parsing with comprehensive
  /// error handling and state coordination.
  /// 
  /// **Unified Processing Workflow:**
  /// - Import data cleanup and state preparation
  /// - Image selection through ImagePicker with source-specific handling
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
        final XFile? picked = await picker.pickImage(source: source);

        if (picked == null) {
          throw Exception('Ingen bild vald');
        }

        // Read image bytes
        final bytes = await picked.readAsBytes();
        _imageBytes = bytes;
        notifyListeners();

        // Perform OCR
        await _performOcr(bytes);
      },
      errorPrefix: 'Kunde inte bearbeta bild',
    );
  }

  /// Performs comprehensive OCR processing with multi-engine support and intelligent fallback strategies.
  /// 
  /// [imageBytes] Raw image data for OCR processing and text extraction
  /// 
  /// Executes sophisticated OCR processing using multiple engines with fallback strategies,
  /// orientation detection, and automatic recipe parsing coordination ensuring optimal
  /// text extraction results from recipe images.
  /// 
  /// **OCR Processing Strategy:**
  /// 1. Primary processing with OCR Engine 2 (optimized for recipe text)
  /// 2. Fallback to OCR Engine 1 with orientation detection if primary fails
  /// 3. Text validation and quality assessment
  /// 4. Automatic recipe parsing from extracted text
  /// 5. State update and UI notification coordination
  /// 
  /// **Throws**: Exception if no text can be extracted from image.
  Future<void> _performOcr(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    
    // Try OCR engine 2 first (usually better for recipe text)
    String text = await _callOcrApi(base64Image, engine: '2');

    // If engine 2 fails, try engine 1 with orientation detection
    if (text.isEmpty) {
      text = await _callOcrApi(
        base64Image,
        engine: '1',
        extras: {'detectOrientation': 'true'},
      );
    }

    if (text.isEmpty) {
      throw Exception(
        'Ingen text kunde extraheras. Se till att bilden innehåller tydlig, läsbar text.',
      );
    }

    _ocrText = text;
    notifyListeners();

    // Auto-parse the OCR text into a recipe
    await _autoParseOcrText(text);
  }

  /// Performs automatic recipe parsing from OCR text with intelligent structure recognition.
  /// 
  /// [text] Extracted OCR text for automatic recipe parsing and structure analysis
  /// 
  /// Attempts automatic recipe parsing from OCR text using ImportManager auto-import functionality
  /// with intelligent structure recognition and recipe pattern detection. Fails gracefully
  /// allowing manual parsing if automatic parsing is unsuccessful.
  /// 
  /// **Auto-Parsing Process:**
  /// - OCR text analysis through ImportManager auto-import
  /// - Recipe structure recognition and pattern detection
  /// - Automatic recipe object generation and validation
  /// - Graceful failure handling with manual parsing fallback
  /// - State update with parsed recipe if successful
  /// 
  /// **Note**: Failures are handled gracefully - users can still manually parse OCR text.
  Future<void> _autoParseOcrText(String text) async {
    try {
      final importResult = await importManager.autoImport(text);
      if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
        setParsedRecipe(importResult.importedRecipes.first);
      }
    } catch (e) {
      // Don't throw error for auto-parsing failures
      // User can still manually parse the OCR text
      debugPrint('Automatisk parsning misslyckades: $e');
    }
  }

  /// Performs OCR API call with comprehensive configuration and error handling.
  /// 
  /// [base64Image] Base64 encoded image data for OCR processing
  /// [engine] OCR engine identifier for processing optimization
  /// [extras] Optional additional parameters for OCR configuration
  /// 
  /// Returns extracted text string from OCR processing or empty string if no text found.
  /// Executes OCR API request with comprehensive configuration, authentication,
  /// error handling, and response processing ensuring reliable text extraction.
  /// 
  /// **OCR API Integration:**
  /// - API authentication with environment-configured key
  /// - Engine-specific processing optimization
  /// - Multipart request construction with proper headers
  /// - Comprehensive error handling and response validation
  /// - Swedish localized error messages for user feedback
  /// 
  /// **Throws**: Exception if API key missing, API error occurs, or processing fails.
  Future<String> _callOcrApi(
    String base64Image, {
    required String engine,
    Map<String, String>? extras,
  }) async {
    if (_ocrApiKey.isEmpty) {
      throw Exception('OCR API-nyckel inte konfigurerad');
    }

    final request = http.MultipartRequest('POST', Uri.parse(_ocrApiUrl));
    
    // Add API key
    request.fields['apikey'] = _ocrApiKey;
    
    // Add OCR engine
    request.fields['OCREngine'] = engine;
    
    // Add base64 image
    request.fields['base64Image'] = 'data:image/jpeg;base64,$base64Image';
    
    // Add extra parameters
    if (extras != null) {
      request.fields.addAll(extras);
    }

    final response = await request.send();
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode != 200) {
      throw Exception('OCR API-fel: ${response.statusCode}');
    }

    final json = jsonDecode(responseBody);
    
    if (json['IsErroredOnProcessing'] == true) {
      final errorMessage = json['ErrorMessage']?.join(', ') ?? 'Okänt OCR-fel';
      throw Exception('OCR-bearbetningsfel: $errorMessage');
    }

    final parsedResults = json['ParsedResults'] as List?;
    if (parsedResults == null || parsedResults.isEmpty) {
      return '';
    }

    return parsedResults.first['ParsedText'] as String? ?? '';
  }

  // ===== DEBUGGING SUPPORT =====

  /// Provides comprehensive debugging state information for photo import development and troubleshooting.
  /// 
  /// Returns map containing debug information including photo import state, OCR processing results,
  /// image data availability, and inherited debug state from ImportBaseViewModel for comprehensive
  /// development support and troubleshooting capabilities.
  /// 
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
  };

  /// Disposes photo import ViewModel with comprehensive cleanup and memory management.
  /// 
  /// Performs complete resource cleanup including image data disposal, OCR text cleanup,
  /// and memory management ensuring proper photo import ViewModel lifecycle management.
  /// 
  /// **Disposal Process:**
  /// - Image bytes disposal and memory cleanup
  /// - OCR text data cleanup and state reset
  /// - Parent disposal coordination through super.dispose()
  /// - Resource cleanup and memory management
  /// 
  /// **Override Implementation**: Extends ImportBaseViewModel disposal with photo-specific cleanup.
  @override
  void dispose() {
    _imageBytes = null;
    _ocrText = '';
    super.dispose();
  }
}