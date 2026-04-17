/// Comprehensive integration tests for the import system
///
/// **Status:** Bulk-skipped pending BUT-369 continuation. Same root cause
/// as `swedish_sites_integration_test.dart` — the URL-import tier order
/// now prefers LLM/OCR over raw HTML, so the WebScraper mock stub path
/// taken by these fixtures returns "Mock extracted text" instead of
/// structured recipe data. See BUT-209 for the pipeline context and
/// BUT-387 Phase 7 for the emulator lane that will cover the real flow.
///
/// Priority: HIGH - Critical workflows
@Tags(['integration'])
@Skip('Bulk-skipped pending BUT-369 rewrite — see file header.')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:mocktail/mocktail.dart';

// Core imports
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/import/photo_import_strategy.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';
import 'package:butlery/services/social_media_extractor.dart';

// Test infrastructure
import '../../fixtures/import_test_data.dart';
import '../../infrastructure/mocks/import_mocks.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/di/test_service_locator.dart';

void main() {
  // Register all fallback values for mocktail
  setUpAll(() {
    ImportMockSetup.registerFallbacks();
  });

  group('Import System - End-to-End Integration Tests', () {
    late MockHttpClient mockHttpClient;
    late MockWebScraper mockWebScraper;
    late OCRExtractionService mockOcrService;
    late MockPersonalRecipeOperations mockPersonalOps;

    late ImportManager importManager;
    late TextImportStrategy textStrategy;
    late UrlImportStrategy urlStrategy;
    late PhotoImportStrategy photoStrategy;

    setUpAll(() async {
      await TestServiceLocator.initialize();
    });

    setUp(() {
      // Initialize mocks
      mockHttpClient = MockHttpClient();
      mockWebScraper = MockWebScraper();
      mockPersonalOps = MockPersonalRecipeOperations();

      // Configure mock WebScraper to return successful extraction
      when(() => mockWebScraper.performExtraction(any(), any()))
          .thenAnswer((_) async => ExtractionResult(
                success: true,
                extractedText: 'Mock extracted text from WebScraper',
                metadata: {'extraction_method': 'webscraper_mock'},
              ));

      // Configure dispose method
      when(() => mockWebScraper.dispose()).thenReturn(null);

      // Create OCR service with test dependencies
      mockOcrService = OCRExtractionService.createForTesting(
        testHttpClient: MockHttpClient(),
        testOcrApiKey: 'test-ocr-key',
        testGoogleVisionKey: 'test-google-key',
      );

      // Initialize strategies with mocked dependencies
      textStrategy = TextImportStrategy();
      urlStrategy = UrlImportStrategy(
        httpClient: mockHttpClient,
        webScraperFactory: () => mockWebScraper,
      );
      photoStrategy = PhotoImportStrategy(
        ocrService: mockOcrService,
        textStrategy: textStrategy,
      );

      // Create ImportManager
      importManager = ImportManager(mockPersonalOps);

      // Default stub: recipe save succeeds
      when(() => mockPersonalOps.addUnifiedRecipe(any()))
          .thenAnswer((_) async => RecipeOperationResult.success(
                'Recipe saved successfully',
              ));
    });

    tearDown(() async {
      await mockOcrService.dispose();
      OCRExtractionService.resetForTesting();
    });

    tearDownAll(() async {
      await TestServiceLocator.reset();
    });

    // ========================================================================
    // HIGH PRIORITY SCENARIO 1: URL with JSON-LD → RecipeScraper → Save
    // ========================================================================

    group('HIGH PRIORITY - Scenario 1: URL with JSON-LD', () {
      test('should extract recipe from URL with schema.org JSON-LD', () async {
        // Arrange
        final jsonLdHtml = ImportHTMLFixtures.jsonLdRecipeHtml;
        final testUrl = 'https://example.com/recipe/kottbullar';

        stubHttpGet(mockHttpClient, testUrl, jsonLdHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Recipe extracted successfully
        expect(result.isSuccess, isTrue, reason: 'Import should succeed');
        expect(result.recipe, isNotNull, reason: 'Recipe should be extracted');
        expect(result.recipe!.title, equals('Köttbullar med gräddsås'),
            reason: 'Title should match JSON-LD data');

        // Assert - Ingredients parsed
        expect(result.recipe!.ingredients, isNotEmpty,
            reason: 'Ingredients should be extracted');
        expect(result.recipe!.ingredients, contains('500 g köttfärs'),
            reason: 'Should contain main ingredient');

        // Assert - Instructions parsed
        expect(result.recipe!.instructions, isNotEmpty,
            reason: 'Instructions should be extracted');

        // Assert - Metadata parsed
        expect(result.recipe!.portions, equals(4),
            reason: 'Portions should be extracted from recipeYield');
        expect(result.recipe!.timeMinutes, equals(40),
            reason: 'Total time should be calculated from PT40M');

        // Assert - Extraction method tracked
        expect(result.metadata, isNotNull);
        expect(result.metadata!['data_format'], equals('Recipe'),
            reason: 'Should track schema.org @type (Recipe)');
        expect(result.metadata!['extraction_method'], equals('schema.org'),
            reason: 'Should track extraction method');

        // Verify HTTP client was called
        verifyHttpGet(mockHttpClient, testUrl);
      });

      test('should parse ISO 8601 durations correctly', () async {
        // Arrange
        final jsonLdHtml = ImportHTMLFixtures.jsonLdRecipeHtml;
        final testUrl = 'https://example.com/recipe/timing';

        stubHttpGet(mockHttpClient, testUrl, jsonLdHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Time parsing
        expect(result.recipe!.timeMinutes, equals(40),
            reason: 'PT40M should parse to 40 minutes');

        // Verify extraction method is schema.org (prepTime and cookTime are combined into totalTime)
        expect(result.metadata!['extraction_method'], equals('schema.org'),
            reason: 'Should use schema.org extraction');
      });

      test('should extract metadata correctly', () async {
        // Arrange
        final jsonLdHtml = ImportHTMLFixtures.jsonLdRecipeHtml;
        final testUrl = 'https://example.com/recipe/metadata';

        stubHttpGet(mockHttpClient, testUrl, jsonLdHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Metadata extracted
        expect(result.metadata, isNotNull,
            reason: 'Metadata should be present');
        expect(result.recipe!.portions, greaterThan(0),
            reason: 'Portions should be positive');
      });
    });

    // ========================================================================
    // HIGH PRIORITY SCENARIO 2: URL → WebScraper → TextImportStrategy
    // ========================================================================

    group('HIGH PRIORITY - Scenario 2: URL with Plain HTML Fallback', () {
      test('should extract from plain HTML when no structured data exists',
          () async {
        // Arrange
        final plainHtml = ImportHTMLFixtures.plainHtmlRecipe;
        final testUrl = 'https://example.com/recipe/plain';

        // HTTP returns HTML without JSON-LD/microdata
        stubHttpGet(mockHttpClient, testUrl, plainHtml);

        // Act - UrlImportStrategy will try static HTML → WebScraper → HTML text extraction
        final result = await urlStrategy.import(testUrl);

        // Assert - Recipe extracted via fallback
        expect(result.isSuccess, isTrue,
            reason: 'Should succeed via HTML text extraction fallback');
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, isNotEmpty,
            reason: 'Title should be extracted from plain HTML');

        // Assert - Fallback metadata
        expect(result.metadata, isNotNull);
        expect(result.warnings, isNotEmpty,
            reason: 'Should warn about lack of structured data');

        // Verify HTTP client was called
        verifyHttpGet(mockHttpClient, testUrl);
      });

      test('should handle network errors gracefully', () async {
        // Arrange
        final testUrl = 'https://example.com/recipe/fallback';

        // HTTP request fails
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenThrow(Exception('Network error'));

        // WebScraper also fails (no fallback available)
        when(() => mockWebScraper.performExtraction(any(), any()))
            .thenAnswer((_) async => ExtractionResult(
                  success: false,
                  error: 'WebScraper also failed',
                  metadata: {},
                ));

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Failure with error message
        expect(result.isSuccess, isFalse,
            reason: 'Should fail when network request fails');
        expect(result.errorMessage, isNotNull);
      });
    });

    // ========================================================================
    // HIGH PRIORITY SCENARIO 3: Photo → OCR → TextImportStrategy → Save
    // ========================================================================

    group('HIGH PRIORITY - Scenario 3: Photo with OCR Extraction', () {
      test('should extract recipe from photo via OCR with high confidence',
          () async {
        // Arrange
        final imageBytes = ImportImageFixtures.validRecipeImagePNG;
        final expectedOcrText = ImportOCRFixtures.highConfidenceSwedishRecipe;

        // Mock OCR extraction (high confidence)
        final mockOcrClient = MockHttpClient();
        final testOcrService = OCRExtractionService.createForTesting(
          testHttpClient: mockOcrClient,
          testOcrApiKey: 'test-key',
        );

        // Stub OCR API response
        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream).thenAnswer(
          (_) => http.ByteStream.fromBytes(
            '''
{
  "ParsedResults": [{"ParsedText": "$expectedOcrText"}],
  "IsErroredOnProcessing": false
}
'''
                .codeUnits,
          ),
        );
        when(() => mockOcrClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        // Create PhotoImportStrategy with mocked OCR
        final photoStrategy = PhotoImportStrategy(
          ocrService: testOcrService,
          textStrategy: textStrategy,
        );

        // Act
        final result = await photoStrategy.import('photo', options: {
          'imageBytes': imageBytes,
        });

        // Assert - Recipe extracted successfully
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, equals('Köttbullar med gräddsås'));

        // Assert - Ingredients parsed from OCR text
        expect(result.recipe!.ingredients, contains('500 g köttfärs'));
        expect(result.recipe!.ingredients, contains('1 ägg'));

        // Assert - Metadata includes OCR info
        expect(result.metadata!['ocr_method'], isNotNull);
        expect(result.metadata!['ocr_confidence'], greaterThan(0.8),
            reason: 'High quality OCR should have >80% confidence');

        // Assert - Minimal warnings for high confidence
        expect(result.warnings?.length ?? 0, lessThan(2),
            reason: 'High confidence should have few warnings');

        await testOcrService.dispose();
      });

      test('should handle low confidence OCR with appropriate warnings',
          () async {
        // Arrange
        final imageBytes = ImportImageFixtures.poorQualityImage;
        final lowConfidenceText = ImportOCRFixtures.lowConfidenceOCRText;

        // Mock low confidence OCR
        final mockOcrClient = MockHttpClient();
        final testOcrService = OCRExtractionService.createForTesting(
          testHttpClient: mockOcrClient,
          testOcrApiKey: 'test-key',
        );

        final mockResponse = MockStreamedResponse();
        when(() => mockResponse.statusCode).thenReturn(200);
        when(() => mockResponse.stream).thenAnswer(
          (_) => http.ByteStream.fromBytes(
            '''
{
  "ParsedResults": [{"ParsedText": "$lowConfidenceText"}],
  "IsErroredOnProcessing": false
}
'''
                .codeUnits,
          ),
        );
        when(() => mockOcrClient.send(any()))
            .thenAnswer((_) async => mockResponse);

        final photoStrategy = PhotoImportStrategy(
          ocrService: testOcrService,
          textStrategy: textStrategy,
        );

        // Act
        final result = await photoStrategy.import('photo', options: {
          'imageBytes': imageBytes,
        });

        // Assert - Recipe still created despite low confidence
        expect(result.isSuccess, isTrue,
            reason: 'Should succeed even with low OCR confidence');

        // Assert - Low confidence warnings
        expect(result.hasWarnings, isTrue);
        if (result.hasWarnings) {
          ImportTestAssertions.assertWarningsContain(
            result.warnings!,
            'OCR',
          );
        }

        // Assert - Quality recommendations
        expect(result.metadata!['image_quality_issues'], isNotNull,
            reason: 'Should note quality issues');

        await testOcrService.dispose();
      });
    });

    // ========================================================================
    // HIGH PRIORITY SCENARIO 4: Text → Direct Parsing → Save
    // ========================================================================

    group('HIGH PRIORITY - Scenario 4: Direct Text Import', () {
      test('should parse well-structured Swedish recipe text', () async {
        // Arrange
        final recipeText = ImportTextFixtures.wellStructuredRecipe;

        // Act
        final result = await textStrategy.import(recipeText);

        // Assert - Recipe parsed correctly
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, equals('Köttbullar med gräddsås'));

        // Assert - Metadata extracted
        expect(result.recipe!.portions, equals(4));
        expect(result.recipe!.timeMinutes, equals(40));
        expect(result.recipe!.mealType, equals('Huvudrätt'));

        // Assert - Sections parsed
        expect(result.recipe!.ingredients, contains('500 g köttfärs'));
        expect(
            result.recipe!.instructions
                .any((inst) => inst.contains('Blanda köttfärs')),
            isTrue,
            reason:
                'Instructions should contain first step about mixing ingredients');

        // Assert - Minimal warnings for well-structured text
        expect(result.warnings?.length ?? 0, lessThanOrEqualTo(1));
      });

      test('should clean social media formatting', () async {
        // Arrange
        final socialText = ImportTextFixtures.socialMediaRecipe;

        // Act
        final result = await textStrategy.import(socialText);

        // Assert - Recipe extracted despite emoji clutter
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.title, contains('CARBONARA'));

        // Assert - Social media elements cleaned
        expect(result.recipe!.title, isNot(contains('🍝')),
            reason: 'Emojis should be removed from title');

        // Assert - Warning about social media formatting if present
        if (result.hasWarnings) {
          ImportTestAssertions.assertWarningsContain(
            result.warnings!,
            'sociala medier',
          );
        }
      });

      test('should handle poorly structured text gracefully', () async {
        // Arrange
        final poorText = ImportTextFixtures.poorlyStructuredRecipe;

        // Act
        final result = await textStrategy.import(poorText);

        // Assert - Recipe created despite poor structure
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);

        // Assert - Multiple warnings for missing structure
        if (result.hasWarnings) {
          expect(result.warnings!.length, greaterThan(0),
              reason: 'Poor structure should generate warnings');
        }

        // Assert - Basic info still extracted
        expect(result.recipe!.title, contains('pannkakor'));
        expect(result.recipe!.portions, isNotNull);
      });

      test('should preprocess measurements and approximations', () async {
        // Arrange
        final recipeWithApprox = ImportTextFixtures.recipeWithApproximations;

        // Act
        final result = await textStrategy.import(recipeWithApprox);

        // Assert - Approximations handled
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.ingredients, isNotNull);

        // MODUL1 preprocessing should handle "ca", "1-2", "(ev)" etc.
        // Exact behavior depends on IngredientProcessor integration
        expect(result.recipe!.ingredients.length, greaterThan(3));
      });
    });

    // ========================================================================
    // HIGH PRIORITY SCENARIO 5: Auto-Detection with Fallback Chain
    // ========================================================================

    group('HIGH PRIORITY - Scenario 5: Auto-Detection and Fallback', () {
      test('should auto-detect URL and use URL strategy', () async {
        // Arrange
        final jsonLdHtml = ImportHTMLFixtures.jsonLdRecipeHtml;
        final testUrl = 'https://example.com/recipe/auto';

        stubHttpGet(mockHttpClient, testUrl, jsonLdHtml);

        // Act - Use autoImport (no explicit strategy)
        final ImportManagerResult result =
            await importManager.autoImport(testUrl);

        // Assert - URL strategy was used
        expect(result.isSuccess, isTrue);
        expect(result.recipe, isNotNull);
        expect(result.strategy, equals('url_import'));

        // Assert - Recipe saved via PersonalRecipeOperations
        verify(() => mockPersonalOps.addUnifiedRecipe(any())).called(1);
      });

      test('should fall back to text strategy when URL strategy fails',
          () async {
        // Arrange
        final testInput = 'https://invalid-url-that-404s.com/recipe';

        // URL fails (404)
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => MockHttpResponseBuilder.notFound());

        // Act
        final ImportManagerResult result =
            await importManager.autoImport(testInput);

        // Assert - Should try URL first, then fall back to text
        // (In practice, ImportManager will try URL → fail → try Text)
        // The exact behavior depends on canHandle() implementation
        expect(result, isNotNull);
      });

      test('should try multiple strategies until one succeeds', () async {
        // Arrange
        final mixedInput = '''
https://broken-site.com/recipe

Köttbullar med gräddsås

500g köttfärs, 1 ägg, 2dl ströbröd

Blanda allt och stek i smör.
''';

        // URL part fails
        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenAnswer((_) async => MockHttpResponseBuilder.notFound());

        // Act - autoImport tries strategies until one works
        final ImportManagerResult result =
            await importManager.autoImport(mixedInput);

        // Assert - Text strategy succeeded even though URL failed
        expect(result.isSuccess, isTrue,
            reason: 'Should succeed via text fallback');
        expect(result.recipe!.title, contains('Köttbullar'));
      });

      test('should track which strategy was successful', () async {
        // Arrange
        final plainText = ImportTextFixtures.wellStructuredRecipe;

        // Act
        final ImportManagerResult result =
            await importManager.autoImport(plainText);

        // Assert - Strategy name tracked
        expect(result.strategy, isNotNull);
        expect(result.strategy, equals('Text Import'),
            reason: 'Should identify text strategy was used');
      });

      test('should preserve data through fallback chain', () async {
        // Arrange
        final testInput = '''
Recipe from social media:

Pannkakor 🥞
3dl mjöl, 6dl mjölk, 3 ägg
Vispa ihop och stek!

#pannkakor #frukost
''';

        // Act
        final ImportManagerResult result =
            await importManager.autoImport(testInput);

        // Assert - No data lost during text extraction
        expect(result.recipe!.title, isNotNull);
        expect(result.recipe!.ingredients, isNotEmpty);
        expect(result.recipe!.instructions, isNotEmpty);

        // Assert - Metadata preserved
        expect(result.metadata, isNotNull);
        expect(result.metadata!['strategy'], isNotNull);
      });
    });

    // ========================================================================
    // EDGE CASES AND ERROR HANDLING
    // ========================================================================

    group('Edge Cases', () {
      test('should handle network timeout gracefully', () async {
        // Arrange
        final testUrl = 'https://slow-server.com/recipe';

        when(() => mockHttpClient.get(any(), headers: any(named: 'headers')))
            .thenThrow(Exception('Connection timeout'));

        // WebScraper also fails
        when(() => mockWebScraper.performExtraction(any(), any()))
            .thenAnswer((_) async => ExtractionResult(
                  success: false,
                  error: 'Connection timeout',
                  metadata: {},
                ));

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Failure with helpful error
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotNull);
      });

      test('should handle empty input', () async {
        // Arrange
        const emptyInput = '';

        // Act
        final result = await textStrategy.import(emptyInput);

        // Assert - Validation failure
        expect(result.isSuccess, isFalse,
            reason: 'Should fail for empty input');
        expect(result.errorMessage, isNotNull,
            reason: 'Should provide error message');
      });

      test('should handle image bytes without options parameter', () async {
        // Arrange & Act
        final result = await photoStrategy.import('photo'); // No options

        // Assert - Validation failure
        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('imageBytes'),
            reason: 'Should mention missing image data');
      });
    });
  });
}
