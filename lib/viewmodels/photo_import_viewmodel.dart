// lib/viewmodels/photo_import_viewmodel.dart

import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import '../models/recipe.dart';
import '../services/import/import_manager.dart';

/// ViewModel för foto-OCR import
/// Now using ImportManager for text processing
class PhotoImportViewModel extends ChangeNotifier {
  final ImportManager _importManager;

  // State
  Uint8List? _imageBytes;
  String _ocrText = '';
  bool _isProcessing = false;
  String? _error;
  Recipe? _parsedRecipe;

  PhotoImportViewModel({required ImportManager importManager})
      : _importManager = importManager;

  // API-konfiguration - nu säkert från environment
  String get _ocrApiKey => dotenv.env['OCR_API_KEY'] ?? '';
  String get _ocrApiUrl => dotenv.env['OCR_API_URL'] ?? 'https://api.ocr.space/parse/image';

  // Getters
  Uint8List? get imageBytes => _imageBytes;
  String get ocrText => _ocrText;
  bool get isProcessing => _isProcessing;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get hasImage => _imageBytes != null;
  bool get hasOcrResult => _ocrText.isNotEmpty;
  Recipe? get parsedRecipe => _parsedRecipe;
  bool get hasParsedRecipe => _parsedRecipe != null;

  /// Ta bild från kamera och kör OCR
  Future<void> pickImageFromCamera() async {
    await _pickImageAndProcess(ImageSource.camera);
  }

  /// Välj bild från galleri och kör OCR
  Future<void> pickImageFromGallery() async {
    await _pickImageAndProcess(ImageSource.gallery);
  }

  /// Gemensam metod för att välja bild och köra OCR
  Future<void> _pickImageAndProcess(ImageSource source) async {
    _clearState();
    _setProcessing(true);

    try {
      // Välj bild
      final picker = ImagePicker();
      final XFile? picked = await picker.pickImage(source: source);

      if (picked == null) {
        _setProcessing(false);
        return;
      }

      // Läs bilden
      final bytes = await picked.readAsBytes();
      _imageBytes = bytes;
      notifyListeners();

      // Kör OCR
      final base64Image = base64Encode(bytes);
      String text = await _callOcrApi(base64Image, engine: '2');

      // Om engine 2 misslyckas, prova engine 1
      if (text.isEmpty) {
        text = await _callOcrApi(
          base64Image,
          engine: '1',
          extras: {'detectOrientation': 'true'},
        );
      }

      if (text.isEmpty) {
        throw Exception(
          'Inga resultat tolkades. Kontrollera att bilden innehåller tydlig text.',
        );
      }

      _ocrText = text;
      
      // Process OCR text through ImportManager
      if (text.isNotEmpty) {
        final importResult = await _importManager.autoImport(text);
        if (importResult.isSuccess && importResult.importedRecipes.isNotEmpty) {
          _parsedRecipe = importResult.importedRecipes.first;
        }
      }
      
      _error = null;
    } catch (e) {
      _setError(e.toString());
    } finally {
      _setProcessing(false);
    }
  }

  /// @deprecated Använd pickImageFromCamera() istället
  Future<void> pickImageAndProcess() async {
    await pickImageFromCamera();
  }

  /// Anropa OCR API
  Future<String> _callOcrApi(
    String base64Image, {
    required String engine,
    Map<String, String>? extras,
  }) async {
    final body = <String, String>{
      'base64Image': 'data:image/png;base64,$base64Image',
      'language': 'swe',
      'isOverlayRequired': 'false',
      'OCREngine': engine,
    };

    if (extras != null) {
      body.addAll(extras);
    }

    try {
      final response = await http.post(
        Uri.parse(_ocrApiUrl),
        headers: {
          'apikey': _ocrApiKey,
          'Content-Type': 'application/x-www-form-urlencoded',
        },
        body: body,
      );

      final decoded = jsonDecode(response.body);
      final List<dynamic>? parsed = decoded['ParsedResults'];

      if (parsed != null && parsed.isNotEmpty) {
        return parsed[0]['ParsedText'] as String? ?? '';
      }
    } catch (e) {
      debugPrint('OCR API error: $e');
    }

    return '';
  }

  /// Rensa all state
  void clearAll() {
    _clearState();
    notifyListeners();
  }

  /// Parse current OCR text to recipe
  Future<bool> parseOcrText() async {
    if (_ocrText.isEmpty) return false;

    try {
      _setProcessing(true);
      final result = await _importManager.autoImport(_ocrText);
      
      if (result.isSuccess && result.importedRecipes.isNotEmpty) {
        _parsedRecipe = result.importedRecipes.first;
        return true;
      } else {
        _setError(result.error ?? 'Could not parse recipe from OCR text');
        return false;
      }
    } catch (e) {
      _setError(e.toString());
      return false;
    } finally {
      _setProcessing(false);
    }
  }

  /// Rensa fel
  void clearError() {
    _error = null;
    notifyListeners();
  }

  // Private methods
  void _clearState() {
    _imageBytes = null;
    _ocrText = '';
    _error = null;
    _parsedRecipe = null;
  }

  void _setProcessing(bool value) {
    _isProcessing = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }
}
