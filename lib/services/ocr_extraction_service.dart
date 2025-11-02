/// OCR service with multi-provider fallback (OCR.space → Google Vision → Tesseract), Swedish optimization, and smart caching.

import 'dart:convert';
import 'dart:math' as math;
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:crypto/crypto.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:butlery/core/base/base_service.dart';

/// OCR processing result with comprehensive metadata and quality metrics
class OCRResult {
  final String text;
  final double confidence;
  final String processingMethod;
  final Map<String, dynamic> metadata;
  final DateTime timestamp;
  final bool isSuccessful;
  final String? errorMessage;

  const OCRResult({
    required this.text,
    required this.confidence,
    required this.processingMethod,
    required this.metadata,
    required this.timestamp,
    this.isSuccessful = true,
    this.errorMessage,
  });

  factory OCRResult.failure({
    required String method,
    required String error,
    Map<String, dynamic>? metadata,
  }) {
    return OCRResult(
      text: '',
      confidence: 0.0,
      processingMethod: method,
      metadata: metadata ?? {},
      timestamp: DateTime.now(),
      isSuccessful: false,
      errorMessage: error,
    );
  }
}

/// Image quality assessment results for OCR optimization
class ImageQualityAssessment {
  final bool isGoodQuality;
  final double qualityScore; // 0.0 - 1.0
  final List<String> issues;
  final List<String> recommendations;

  const ImageQualityAssessment({
    required this.isGoodQuality,
    required this.qualityScore,
    required this.issues,
    required this.recommendations,
  });
}

/// Circuit breaker state for OCR service resilience
enum CircuitBreakerState { closed, open, halfOpen }

class CircuitBreaker {
  final int failureThreshold;
  final Duration timeout;
  final Duration retryTimeout;
  
  int _failureCount = 0;
  DateTime? _lastFailureTime;
  CircuitBreakerState _state = CircuitBreakerState.closed;

  CircuitBreaker({
    this.failureThreshold = 5,
    this.timeout = const Duration(seconds: 30),
    this.retryTimeout = const Duration(minutes: 2),
  });

  bool get canExecute {
    switch (_state) {
      case CircuitBreakerState.closed:
        return true;
      case CircuitBreakerState.open:
        final now = DateTime.now();
        if (_lastFailureTime != null &&
            now.difference(_lastFailureTime!) > retryTimeout) {
          _state = CircuitBreakerState.halfOpen;
          return true;
        }
        return false;
      case CircuitBreakerState.halfOpen:
        return true;
    }
  }

  void recordSuccess() {
    _failureCount = 0;
    _state = CircuitBreakerState.closed;
  }

  void recordFailure() {
    _failureCount++;
    _lastFailureTime = DateTime.now();
    
    if (_failureCount >= failureThreshold) {
      _state = CircuitBreakerState.open;
    }
  }

  CircuitBreakerState get state => _state;
  int get failures => _failureCount;
}

/// Comprehensive OCR extraction service with universal device compatibility
class OCRExtractionService extends BaseService {
  static OCRExtractionService? _instance;
  static OCRExtractionService get instance => _instance ??= OCRExtractionService._();
  
  OCRExtractionService._();
  
  @override
  String get serviceName => 'OCRExtractionService';

  // Circuit breakers
  final CircuitBreaker _ocrSpaceCircuitBreaker = CircuitBreaker();
  final CircuitBreaker _googleVisionCircuitBreaker = CircuitBreaker();
  final CircuitBreaker _tesseractCircuitBreaker = CircuitBreaker();
  final Map<String, OCRResult> _cache = {};
  static const int _maxCacheSize = 100;
  static const Duration _cacheExpiry = Duration(hours: 24);
  static const int _maxImageSize = 10 * 1024 * 1024;
  static const double _minConfidenceThreshold = 0.6;
  String get _ocrApiKey => dotenv.env['OCR_API_KEY'] ?? '';
  String get _ocrApiUrl => dotenv.env['OCR_API_URL'] ?? 'https://api.ocr.space/parse/image';
  String get _googleVisionKey => dotenv.env['GOOGLE_VISION_API_KEY'] ?? '';
  String get _tesseractApiUrl => dotenv.env['TESSERACT_API_URL'] ?? '';

  /// Initialize OCR service
  @override
  Future<void> initialize() async {
    try {
      debugPrint('✅ [OCR] Service initialized - Providers: OCR.space, Google Vision, Tesseract');
      if (_ocrApiKey.isEmpty) debugPrint('⚠️ [OCR] OCR.space API key not configured');
      if (_googleVisionKey.isEmpty) debugPrint('⚠️ [OCR] Google Vision API key not configured');
      if (_tesseractApiUrl.isEmpty) debugPrint('⚠️ [OCR] Tesseract API URL not configured');
    } catch (e) {
      debugPrint('❌ [OCR] Init failed: $e');
      rethrow;
    }
  }

  /// Extract text from image using multi-tier OCR strategy
  Future<OCRResult> extractText(Uint8List imageBytes) async {
    final imageHash = _generateImageHash(imageBytes);
    
    final cachedResult = _getCachedResult(imageHash);
    if (cachedResult != null) return cachedResult;
    final qualityAssessment = await _assessImageQuality(imageBytes);
    if (!qualityAssessment.isGoodQuality) {
      debugPrint('⚠️ [OCR] Poor quality: ${qualityAssessment.issues.join(', ')}');
    }
    final preprocessedImage = await _preprocessImage(imageBytes, qualityAssessment);
    OCRResult result;

    if (_ocrSpaceCircuitBreaker.canExecute && _ocrApiKey.isNotEmpty) {
      try {
        result = await _extractWithOCRSpace(preprocessedImage);
        if (result.isSuccessful && result.confidence >= _minConfidenceThreshold) {
          _ocrSpaceCircuitBreaker.recordSuccess();
          _cacheResult(imageHash, result);
          return result;
        }
      } catch (e) {
        _ocrSpaceCircuitBreaker.recordFailure();
      }
    }

    if (_googleVisionCircuitBreaker.canExecute && _googleVisionKey.isNotEmpty) {
      try {
        result = await _extractWithGoogleVision(preprocessedImage);
        if (result.isSuccessful && result.confidence >= _minConfidenceThreshold) {
          _googleVisionCircuitBreaker.recordSuccess();
          _cacheResult(imageHash, result);
          return result;
        }
      } catch (e) {
        _googleVisionCircuitBreaker.recordFailure();
      }
    }

    if (_tesseractCircuitBreaker.canExecute && _tesseractApiUrl.isNotEmpty) {
      try {
        result = await _extractWithTesseract(preprocessedImage);
        if (result.isSuccessful && result.confidence >= _minConfidenceThreshold) {
          _tesseractCircuitBreaker.recordSuccess();
          _cacheResult(imageHash, result);
          return result;
        }
      } catch (e) {
        _tesseractCircuitBreaker.recordFailure();
      }
    }

    final failureResult = OCRResult.failure(
      method: 'user_recovery',
      error: 'OCR failed. Try: better lighting, clearer image, or manual input',
      metadata: {
        'quality_assessment': qualityAssessment.qualityScore,
        'recommendations': qualityAssessment.recommendations,
        'circuit_breakers': {
          'ocr_space_state': _ocrSpaceCircuitBreaker.state.name,
          'google_vision_state': _googleVisionCircuitBreaker.state.name,
          'tesseract_state': _tesseractCircuitBreaker.state.name,
        }
      },
    );

    _cacheResult(imageHash, failureResult);
    return failureResult;
  }

  /// Extract text using OCR.space API (Primary - Universal compatibility)
  Future<OCRResult> _extractWithOCRSpace(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    
    final request = http.MultipartRequest('POST', Uri.parse(_ocrApiUrl));
    request.fields['apikey'] = _ocrApiKey;
    request.fields['OCREngine'] = '2'; // Best for Swedish text
    request.fields['base64Image'] = 'data:image/jpeg;base64,$base64Image';
    request.fields['language'] = 'eng'; // English works well for Swedish text
    request.fields['detectOrientation'] = 'true';
    request.fields['scale'] = 'true';
    request.fields['isTable'] = 'false';

    final response = await request.send().timeout(const Duration(seconds: 30));
    final responseBody = await response.stream.bytesToString();

    if (response.statusCode == 200) {
      final json = jsonDecode(responseBody);
      
      if (json['IsErroredOnProcessing'] == false) {
        final parsedResults = json['ParsedResults'] as List?;
        final extractedText = parsedResults?.first['ParsedText'] as String? ?? '';
        
        return OCRResult(
          text: extractedText,
          confidence: _calculateConfidenceFromText(extractedText),
          processingMethod: 'ocr_space',
          metadata: {
            'engine': '2',
            'language': 'swedish',
            'processing_time': DateTime.now().millisecondsSinceEpoch,
            'response_size': responseBody.length,
          },
          timestamp: DateTime.now(),
        );
      } else {
        // API responded with success but processing failed
        final errorMessages = json['ErrorMessage'] as List?;
        final errorDetails = errorMessages?.join(', ') ?? 'OCR processing failed';
        throw Exception('OCR.space processing error: $errorDetails');
      }
    }

    throw Exception('OCR.space HTTP error: ${response.statusCode}');
  }

  /// Extract text using Google Vision API (Secondary fallback)
  Future<OCRResult> _extractWithGoogleVision(Uint8List imageBytes) async {
    final base64Image = base64Encode(imageBytes);
    
    final requestBody = jsonEncode({
      'requests': [
        {
          'image': {'content': base64Image},
          'features': [
            {'type': 'TEXT_DETECTION', 'maxResults': 1}
          ],
          'imageContext': {
            'languageHints': ['sv', 'en'] // Swedish and English
          }
        }
      ]
    });

    final response = await http.post(
      Uri.parse('https://vision.googleapis.com/v1/images:annotate?key=$_googleVisionKey'),
      headers: {'Content-Type': 'application/json'},
      body: requestBody,
    ).timeout(const Duration(seconds: 30));

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      final responses = json['responses'] as List?;
      
      if (responses != null && responses.isNotEmpty) {
        final textAnnotations = responses.first['textAnnotations'] as List?;
        
        if (textAnnotations != null && textAnnotations.isNotEmpty) {
          final extractedText = textAnnotations.first['description'] as String? ?? '';
          
          return OCRResult(
            text: extractedText,
            confidence: _calculateConfidenceFromText(extractedText),
            processingMethod: 'google_vision',
            metadata: {
              'language_hints': ['sv', 'en'],
              'processing_time': DateTime.now().millisecondsSinceEpoch,
              'annotations_count': textAnnotations.length,
            },
            timestamp: DateTime.now(),
          );
        }
      }
    }

    throw Exception('Google Vision API processing failed: ${response.statusCode}');
  }

  /// Extract text using Tesseract API (Tertiary fallback)
  Future<OCRResult> _extractWithTesseract(Uint8List imageBytes) async {
    // This would connect to a hosted Tesseract service
    // For now, return a basic implementation
    
    final base64Image = base64Encode(imageBytes);
    
    final requestBody = jsonEncode({
      'image': base64Image,
      'language': 'swe+eng', // Swedish + English
      'options': {
        'psm': '6', // Uniform block of text
        'oem': '3', // Default OCR engine mode
      }
    });

    try {
      final response = await http.post(
        Uri.parse(_tesseractApiUrl),
        headers: {'Content-Type': 'application/json'},
        body: requestBody,
      ).timeout(const Duration(seconds: 45));

      if (response.statusCode == 200) {
        final json = jsonDecode(response.body);
        final extractedText = json['text'] as String? ?? '';
        
        return OCRResult(
          text: extractedText,
          confidence: _calculateConfidenceFromText(extractedText),
          processingMethod: 'tesseract',
          metadata: {
            'language': 'swe+eng',
            'psm': '6',
            'processing_time': DateTime.now().millisecondsSinceEpoch,
          },
          timestamp: DateTime.now(),
        );
      }
    } catch (e) {
      // Optional fallback
    }
    throw Exception('Tesseract API processing failed or not configured');
  }

  /// Assess image quality for OCR optimization
  Future<ImageQualityAssessment> _assessImageQuality(Uint8List imageBytes) async {
    final issues = <String>[], recommendations = <String>[];
    double qualityScore = 1.0;
    if (imageBytes.length > _maxImageSize) { issues.add('Bilden är för stor'); recommendations.add('Komprimera bilden'); qualityScore -= 0.2; }
    if (imageBytes.length < 50 * 1024) { issues.add('Bilden är för liten'); recommendations.add('Använd högre upplösning'); qualityScore -= 0.3; }
    if (!_isValidImageFormat(imageBytes)) { issues.add('Bildformat stöds inte optimalt'); recommendations.add('Använd JPEG eller PNG'); qualityScore -= 0.1; }
    return ImageQualityAssessment(
      isGoodQuality: qualityScore >= 0.6 && issues.isEmpty,
      qualityScore: math.max(0.0, qualityScore),
      issues: issues,
      recommendations: recommendations,
    );
  }

  /// Preprocess image for optimal OCR results
  Future<Uint8List> _preprocessImage(Uint8List imageBytes, ImageQualityAssessment assessment) async {
    // Future: orientation correction, contrast enhancement, noise reduction
    return imageBytes;
  }

  /// Calculate confidence score from extracted text (universal method)
  double _calculateConfidenceFromText(String text) {
    if (text.isEmpty) return 0.0;
    
    final textLength = text.trim().length;
    final lineCount = text.split('\n').where((line) => line.trim().isNotEmpty).length;
    
    if (textLength == 0) return 0.0;
    if (textLength < 10) return 0.3;
    if (textLength < 30) return 0.5;
    if (textLength < 100) return 0.7;
    
    const baseConfidence = 0.8;
    final structureBonus = math.min(0.2, lineCount * 0.03);
    
    const keywords = ['ingrediens', 'tillsätt', 'vispa', 'stek', 'portioner', 'minut'];
    final keywordMatches = keywords.where((k) => text.toLowerCase().contains(k)).length;
    final keywordBonus = math.min(0.15, keywordMatches * 0.03);
    return math.min(1.0, baseConfidence + structureBonus + keywordBonus);
  }

  /// Generate hash for image caching
  String _generateImageHash(Uint8List imageBytes) {
    final digest = sha256.convert(imageBytes);
    return digest.toString();
  }

  /// Get cached OCR result if available and not expired
  OCRResult? _getCachedResult(String imageHash) {
    final cached = _cache[imageHash];
    if (cached != null) {
      final age = DateTime.now().difference(cached.timestamp);
      if (age <= _cacheExpiry) {
        return cached;
      } else {
        _cache.remove(imageHash);
      }
    }
    return null;
  }

  /// Cache OCR result with size management
  void _cacheResult(String imageHash, OCRResult result) {
    if (_cache.length >= _maxCacheSize) {
      final sortedEntries = _cache.entries.toList()
        ..sort((a, b) => a.value.timestamp.compareTo(b.value.timestamp));
      for (final entry in sortedEntries.take(_maxCacheSize ~/ 4)) {
        _cache.remove(entry.key);
      }
    }
    _cache[imageHash] = result;
  }

  /// Basic image format validation
  bool _isValidImageFormat(Uint8List bytes) {
    if (bytes.length < 4) return false;

    // Check JPEG
    if (bytes[0] == 0xFF && bytes[1] == 0xD8) {
      return true;
    }
    
    // Check PNG
    if (bytes[0] == 0x89 && 
        bytes[1] == 0x50 && 
        bytes[2] == 0x4E && 
        bytes[3] == 0x47) {
      return true;
    }
    
    return false;
  }

  /// Get comprehensive OCR service status
  Map<String, dynamic> getServiceStatus() {
    return {
      'timestamp': DateTime.now().toIso8601String(),
      'cache_size': _cache.length,
      'circuit_breakers': {
        'ocr_space': {'state': _ocrSpaceCircuitBreaker.state.name, 'failures': _ocrSpaceCircuitBreaker.failures, 'can_execute': _ocrSpaceCircuitBreaker.canExecute},
        'google_vision': {'state': _googleVisionCircuitBreaker.state.name, 'failures': _googleVisionCircuitBreaker.failures, 'can_execute': _googleVisionCircuitBreaker.canExecute},
        'tesseract': {'state': _tesseractCircuitBreaker.state.name, 'failures': _tesseractCircuitBreaker.failures, 'can_execute': _tesseractCircuitBreaker.canExecute},
      },
      'device_compatibility': 'universal_ios_android',
      'api_keys_configured': {
        'ocr_space': _ocrApiKey.isNotEmpty,
        'google_vision': _googleVisionKey.isNotEmpty,
        'tesseract': _tesseractApiUrl.isNotEmpty,
      },
      'configuration': {
        'max_image_size_mb': _maxImageSize / (1024 * 1024),
        'min_confidence_threshold': _minConfidenceThreshold,
        'cache_expiry_hours': _cacheExpiry.inHours,
        'max_cache_size': _maxCacheSize,
      },
    };
  }

  /// Clear OCR cache

  /// Clear cache for testing
  static void clearCacheForTesting() => instance.clearAllCache();

  /// Dispose OCR service
  @override
  Future<void> dispose() async {
    _cache.clear();
  }
}