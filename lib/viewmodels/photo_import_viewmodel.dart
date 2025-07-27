// lib/viewmodels/photo_import_viewmodel.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:butlery/viewmodels/import_base_viewmodel.dart';

/// ViewModel för foto-OCR import
/// Refactored to use ImportBaseViewModel for consistency and reduced duplication
class PhotoImportViewModel extends ImportBaseViewModel {
  
  // ===== PHOTO-SPECIFIC STATE =====
  
  Uint8List? _imageBytes;
  String _ocrText = '';

  PhotoImportViewModel({required super.importManager});

  // ===== GETTERS =====

  /// Raw image bytes from selected photo
  Uint8List? get imageBytes => _imageBytes;

  /// Text extracted from OCR processing
  String get ocrText => _ocrText;

  /// Whether an image has been selected
  bool get hasImage => _imageBytes != null;

  /// Whether OCR has produced results
  bool get hasOcrResult => _ocrText.isNotEmpty;

  /// Whether processing is currently in progress (alias for isLoading)
  bool get isProcessing => isLoading;

  @override
  bool get canImport => hasOcrResult;

  @override
  String get importType => 'photo';

  // ===== API CONFIGURATION =====
  
  String get _ocrApiKey => dotenv.env['OCR_API_KEY'] ?? '';
  String get _ocrApiUrl => dotenv.env['OCR_API_URL'] ?? 'https://api.ocr.space/parse/image';

  // ===== PUBLIC METHODS =====

  /// Take photo from camera and process with OCR
  Future<void> pickImageFromCamera() async {
    await _pickImageAndProcess(ImageSource.camera);
  }

  /// Select image from gallery and process with OCR
  Future<void> pickImageFromGallery() async {
    await _pickImageAndProcess(ImageSource.gallery);
  }

  /// Clear all photo and OCR data
  void clearPhoto() {
    if (isDisposed) return;
    
    _imageBytes = null;
    _ocrText = '';
    clearImportData();
  }

  @override
  Future<void> performImport() async {
    if (!hasOcrResult) {
      setError('No OCR text available for import');
      return;
    }

    final recipe = await parseTextToRecipe(_ocrText);
    setParsedRecipe(recipe);
  }

  // ===== PRIVATE METHODS =====

  /// Common method for picking image and processing with OCR
  Future<void> _pickImageAndProcess(ImageSource source) async {
    clearImportData();

    await executeAsyncVoid(
      () async {
        // Pick image
        final picker = ImagePicker();
        final XFile? picked = await picker.pickImage(source: source);

        if (picked == null) {
          throw Exception('No image selected');
        }

        // Read image bytes
        final bytes = await picked.readAsBytes();
        _imageBytes = bytes;
        notifyListeners();

        // Perform OCR
        await _performOcr(bytes);
      },
      errorPrefix: 'Failed to process image',
    );
  }

  /// Perform OCR on image bytes
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
        'No text could be extracted. Please ensure the image contains clear, readable text.',
      );
    }

    _ocrText = text;
    notifyListeners();

    // Auto-parse the OCR text into a recipe
    await _autoParseOcrText(text);
  }

  /// Automatically parse OCR text into recipe using ImportManager
  Future<void> _autoParseOcrText(String text) async {
    try {
      final importResult = await importManager.autoImport(text);
      if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
        setParsedRecipe(importResult.importedRecipes.first);
      }
    } catch (e) {
      // Don't throw error for auto-parsing failures
      // User can still manually parse the OCR text
      debugPrint('Auto-parsing failed: $e');
    }
  }

  /// Call OCR API with specified engine and options
  Future<String> _callOcrApi(
    String base64Image, {
    required String engine,
    Map<String, String>? extras,
  }) async {
    if (_ocrApiKey.isEmpty) {
      throw Exception('OCR API key not configured');
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
      throw Exception('OCR API error: ${response.statusCode}');
    }

    final json = jsonDecode(responseBody);
    
    if (json['IsErroredOnProcessing'] == true) {
      final errorMessage = json['ErrorMessage']?.join(', ') ?? 'Unknown OCR error';
      throw Exception('OCR processing error: $errorMessage');
    }

    final parsedResults = json['ParsedResults'] as List?;
    if (parsedResults == null || parsedResults.isEmpty) {
      return '';
    }

    return parsedResults.first['ParsedText'] as String? ?? '';
  }

  // ===== DEBUGGING SUPPORT =====

  @override
  Map<String, dynamic> get debugState => {
    ...super.debugState,
    'hasImage': hasImage,
    'hasOcrResult': hasOcrResult,
    'ocrTextLength': _ocrText.length,
  };

  @override
  void dispose() {
    _imageBytes = null;
    _ocrText = '';
    super.dispose();
  }
}