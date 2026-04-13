/// Unit tests for PhotoImportStrategy - Photo-based recipe imports with OCR
///
/// Tests OCR-based recipe import including:
/// - Image byte validation and handling
/// - OCR text extraction (multi-provider fallback)
/// - Text-to-recipe parsing integration
/// - Confidence threshold warnings
/// - Swedish recipe content optimization
/// - Metadata tracking (OCR method, confidence, image size)
/// - Error handling (invalid images, OCR failures, parsing errors)
/// - Multi-provider fallback (OCR.space → Google Vision → Tesseract)
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/import/photo_import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/models/recipe_unified.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Mock classes
class MockOCRExtractionService extends Mock implements OCRExtractionService {}

class MockTextImportStrategy extends Mock implements TextImportStrategy {}

void main() {
  group('PhotoImportStrategy', () {
    late PhotoImportStrategy strategy;
    late MockOCRExtractionService mockOcrService;
    late MockTextImportStrategy mockTextStrategy;
    late Uint8List testImageBytes;

    setUp(() async {
      // Initialize base test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mocks
      mockOcrService = MockOCRExtractionService();
      mockTextStrategy = MockTextImportStrategy();

      // Register mocks
      BaseUnitTest.registerMocks([mockOcrService, mockTextStrategy]);

      // Create test image data (fake PNG header)
      testImageBytes = Uint8List.fromList([
        0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, // PNG signature
        ...List.generate(100, (i) => i % 256), // Fake image data
      ]);

      // Create strategy with mocks
      strategy = PhotoImportStrategy(
        ocrService: mockOcrService,
        textStrategy: mockTextStrategy,
      );

      // Setup default mock behaviors
      when(() => mockOcrService.initialize()).thenAnswer((_) async => {});
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should create strategy with correct metadata', () {
        // Assert
        expect(strategy, isNotNull);
        expect(strategy.strategyName, equals('Photo Import'));
        expect(strategy.description, contains('OCR'));
        expect(strategy.description, contains('photo'));
        expect(strategy.inputExample, isNotEmpty);
      });

      test('should have validation mixin capabilities', () {
        // Assert - Strategy should have ImportValidationMixin
        expect(strategy.isValidRecipeName('Test Recipe'), isTrue);
        expect(strategy.isValidRecipeName(''), isFalse);
      });
    });

    group('Input Validation', () {
      test('should accept "photo" input', () {
        // Act & Assert
        expect(strategy.canHandle('photo'), isTrue);
        expect(strategy.validateInput('photo'), isTrue);
      });

      test('should accept "Photo" input (case insensitive)', () {
        // Act & Assert
        expect(strategy.canHandle('Photo'), isTrue);
        expect(strategy.canHandle('PHOTO'), isTrue);
      });

      test('should accept any non-empty string', () {
        // Arrange
        const inputs = [
          'image_import',
          'camera_capture',
          'gallery_photo',
        ];

        // Act & Assert
        for (final input in inputs) {
          expect(strategy.canHandle(input), isTrue,
              reason: 'Should handle: $input');
        }
      });

      test('should reject empty input', () {
        // Act & Assert
        expect(strategy.canHandle(''), isFalse);
        expect(strategy.canHandle('  '), isFalse);
      });
    });

    group('Image Bytes Extraction', () {
      test('should return failure when no options provided', () async {
        // Act
        final result = await strategy.import('photo');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('No image data'));
        expect(result.metadata?['error_type'], equals('missing_image_data'));
      });

      test('should return failure when options empty', () async {
        // Act
        final result = await strategy.import('photo', options: {});

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('No image data'));
      });

      test('should extract imageBytes from options', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Test recipe text',
            confidence: 0.9,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(
                  _createTestRecipe(),
                ));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockOcrService.extractText(testImageBytes)).called(1);
      });

      test('should handle base64 encoded image (fallback)', () async {
        // Arrange
        final base64Image =
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==';

        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Test recipe',
            confidence: 0.85,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'base64Image': base64Image,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        verify(() => mockOcrService.extractText(any())).called(1);
      });

      test('should return failure for empty imageBytes', () async {
        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': Uint8List(0),
        });

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('empty'));
      });
    });

    group('OCR Processing', () {
      test('should successfully extract text from image', () async {
        // Arrange
        final expectedText =
            'Köttbullar\n500g köttfärs\nBlanda och forma bullar';

        when(() => mockOcrService.extractText(testImageBytes)).thenAnswer(
          (_) async => _createOCRResult(
            text: expectedText,
            confidence: 0.92,
            processingMethod: 'ocr_space',
            isSuccessful: true,
            metadata: {'language': 'sv'},
          ),
        );

        when(() => mockTextStrategy.import(expectedText,
                options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.metadata?['ocr_method'], equals('ocr_space'));
        expect(result.metadata?['ocr_confidence'], equals(0.92));
        verify(() => mockOcrService.initialize()).called(1);
        verify(() => mockOcrService.extractText(testImageBytes)).called(1);
        verify(() => mockTextStrategy.import(expectedText,
            options: any(named: 'options'))).called(1);
      });

      test('should handle OCR failure', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: '',
            confidence: 0.0,
            processingMethod: 'ocr_space',
            isSuccessful: false,
            errorMessage: 'OCR service unavailable',
          ),
        );

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('OCR service unavailable'));
      });

      test('should handle empty OCR result', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: '',
            confidence: 0.5,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('No text could be extracted'));
      });

      test('should track Google Vision fallback', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.88,
            processingMethod: 'google_vision',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.metadata?['ocr_method'], equals('google_vision'));
        expect(result.warnings, contains(contains('google_vision')));
      });

      test('should track Tesseract fallback', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.75,
            processingMethod: 'tesseract',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.metadata?['ocr_method'], equals('tesseract'));
        expect(result.warnings, contains(contains('tesseract')));
      });
    });

    group('Confidence Threshold Warnings', () {
      test('should not warn for high confidence (>= 85%)', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.90,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.metadata?['ocr_confidence_level'], equals('high'));
        final hasConfidenceWarning = result.warnings?.any(
              (w) => w.toLowerCase().contains('confidence'),
            ) ??
            false;
        expect(hasConfidenceWarning, isFalse);
      });

      test('should warn for medium confidence (70-85%)', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.78,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.metadata?['ocr_confidence_level'], equals('medium'));
        expect(result.warnings, contains(contains('Medium OCR confidence')));
        expect(result.warnings, contains(contains('78%')));
      });

      test('should warn for low confidence (50-70%)', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.62,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.metadata?['ocr_confidence_level'], equals('low'));
        expect(result.warnings, contains(contains('Low OCR confidence')));
        expect(result.warnings, contains(contains('62%')));
        expect(result.warnings, contains(contains('Tip:')));
      });

      test('should warn for very low confidence (< 50%)', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.35,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.metadata?['ocr_confidence_level'], equals('very_low'));
        expect(result.warnings, contains(contains('Very low OCR confidence')));
        expect(result.warnings, contains(contains('35%')));
      });
    });

    group('Recipe Parsing Integration', () {
      test('should successfully parse OCR text to recipe', () async {
        // Arrange
        final ocrText = 'Pannkakor\n3 ägg\n6 dl mjölk\nVispa och stek';

        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: ocrText,
            confidence: 0.88,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        final testRecipe = _createTestRecipe(
          title: 'Pannkakor',
          ingredients: ['3 ägg', '6 dl mjölk'],
          instructions: ['Vispa', 'Stek'],
        );

        when(() => mockTextStrategy.import(ocrText,
                options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(testRecipe));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, equals('Pannkakor'));
        expect(result.recipe!.ingredients, hasLength(2));
        expect(result.recipe!.instructions, hasLength(2));
      });

      test('should handle text parsing failure', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Some non-recipe text',
            confidence: 0.90,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.failure(
                  'No recipe structure detected',
                ));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('Could not parse recipe'));
      });

      test('should preserve text parsing warnings', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.88,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(
                  _createTestRecipe(),
                  warnings: [
                    'Missing portion information',
                    'Incomplete instructions'
                  ],
                ));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.warnings, contains('Missing portion information'));
        expect(result.warnings, contains('Incomplete instructions'));
      });
    });

    group('Metadata Tracking', () {
      test('should track image size', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.88,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.metadata?['image_size_bytes'],
            equals(testImageBytes.length));
        expect(result.metadata?['image_size_kb'], isNotNull);
      });

      test('should track source type when provided', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.88,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
          'sourceType': 'camera',
        });

        // Assert
        expect(result.metadata?['source_type'], equals('camera'));
      });

      test('should track extracted text length', () async {
        // Arrange
        final longText = 'Recipe text ' * 100;

        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: longText,
            confidence: 0.88,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(
            result.metadata?['extracted_text_length'], equals(longText.length));
      });

      test('should mark as Swedish optimized', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.88,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.metadata?['swedish_optimized'], isTrue);
      });

      test('should preserve OCR metadata', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.88,
            processingMethod: 'ocr_space',
            isSuccessful: true,
            metadata: {
              'language': 'sv',
              'engine': 'engine2',
              'processing_time_ms': 1234,
            },
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.metadata?['ocr_details'], isNotNull);
        expect(result.metadata?['ocr_details']['language'], equals('sv'));
      });
    });

    group('Error Handling', () {
      test('should handle OCR service exception', () async {
        // Arrange
        when(() => mockOcrService.extractText(any()))
            .thenThrow(Exception('Network error'));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotEmpty);
        expect(result.errorMessage, contains('Network error'));
      });

      test('should handle text parsing exception', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.88,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenThrow(Exception('Parsing error'));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotEmpty);
      });

      test('should provide helpful error for missing image', () async {
        // Act
        final result = await strategy.import('photo');

        // Assert
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('No image data provided'));
        expect(result.errorMessage, contains('options parameter'));
      });
    });

    group('Edge Cases', () {
      test('should handle very large images', () async {
        // Arrange
        final largeImage = Uint8List(5 * 1024 * 1024); // 5MB

        when(() => mockOcrService.extractText(largeImage)).thenAnswer(
          (_) async => _createOCRResult(
            text: 'Recipe text',
            confidence: 0.88,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() =>
                mockTextStrategy.import(any(), options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': largeImage,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        expect(result.metadata?['image_size_bytes'], equals(5 * 1024 * 1024));
      });

      test('should handle very long OCR text', () async {
        // Arrange
        final longText = 'Recipe instruction. ' * 1000; // Very long text

        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: longText,
            confidence: 0.88,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        when(() => mockTextStrategy.import(longText,
                options: any(named: 'options')))
            .thenAnswer((_) async => ImportResult.success(_createTestRecipe()));

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isTrue);
        expect(
            result.metadata?['extracted_text_length'], equals(longText.length));
      });

      test('should handle whitespace-only OCR result', () async {
        // Arrange
        when(() => mockOcrService.extractText(any())).thenAnswer(
          (_) async => _createOCRResult(
            text: '   \n\n   ',
            confidence: 0.50,
            processingMethod: 'ocr_space',
            isSuccessful: true,
          ),
        );

        // Act
        final result = await strategy.import('photo', options: {
          'imageBytes': testImageBytes,
        });

        // Assert
        expect(result.isSuccess, isFalse);
        // Note: TextImportStrategy will fail on whitespace-only text
      });
    });
  });
}

// Helper function to create test recipes
Recipe _createTestRecipe({
  String? title,
  List<String>? ingredients,
  List<String>? instructions,
}) {
  return Recipe(
    core: RecipeCore(
      title: title ?? 'Test Recipe',
      description: 'Test description',
      ingredients: ingredients ?? ['Test ingredient 1', 'Test ingredient 2'],
      instructions:
          instructions ?? ['Test instruction 1', 'Test instruction 2'],
      mealType: 'Lunch',
    ),
    type: RecipeType.personal,
  );
}

// Helper function to create OCRResult for testing
OCRResult _createOCRResult({
  required String text,
  required double confidence,
  String processingMethod = 'ocr_space',
  bool isSuccessful = true,
  String? errorMessage,
  Map<String, dynamic>? metadata,
}) {
  return OCRResult(
    text: text,
    confidence: confidence,
    processingMethod: processingMethod,
    metadata: metadata ?? {},
    timestamp: DateTime.now(),
    isSuccessful: isSuccessful,
    errorMessage: errorMessage,
  );
}
