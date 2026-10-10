/// End-to-end tests for the import system: the URL, photo and text strategies
/// and the manager's strategy fallback.
///
/// Everything external is replaced: pages come from an in-memory HTTP client
/// with an injected DNS lookup, OCR answers come from a stubbed HTTP client,
/// and the headless browser is a mock. No test touches the network.
///
/// The URL strategy runs without a `RecipeParserService`, so the structured
/// data, scraper-text and HTML-text tiers are the ones under test.
///
/// Priority: HIGH - Critical workflows
@Tags(['integration'])
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:butlery/services/social_media_extractor.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/photo_import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/services/parsing/parse_event_logger.dart';
import 'package:butlery/services/unified/types/recipe_types.dart';

import '../../fixtures/import_test_data.dart';
import '../../fixtures/ocr_test_data.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/import_mocks.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class _SilentEventLogger extends Mock implements ParseEventLogger {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    ImportMockSetup.registerFallbacks();
    registerFallbackValue(RecipeFactory.build());
  });

  group('Import System - End-to-End Integration Tests', () {
    late MockWebScraper mockWebScraper;
    late MockPersonalRecipeOperations mockPersonalOps;
    late Map<String, String> pages;
    late List<Uri> requested;
    late bool networkDown;

    late ImportManager importManager;
    late TextImportStrategy textStrategy;
    late UrlImportStrategy urlStrategy;
    late PhotoImportStrategy photoStrategy;
    late OCRExtractionService ocrService;
    late MockHttpClient ocrClient;

    void servePage(String url, String html) => pages[url] = html;

    void stubOcrText(String text) {
      final response = MockStreamedResponse();
      when(() => response.statusCode).thenReturn(200);
      when(() => response.stream).thenAnswer(
        (_) => http.ByteStream.fromBytes(
          utf8.encode(
            jsonEncode({
              'ParsedResults': [
                {'ParsedText': text},
              ],
              'IsErroredOnProcessing': false,
            }),
          ),
        ),
      );
      when(() => ocrClient.send(any())).thenAnswer((_) async => response);
    }

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      pages = {};
      requested = [];
      networkDown = false;

      mockWebScraper = MockWebScraper();
      mockPersonalOps = MockPersonalRecipeOperations();
      ocrClient = MockHttpClient();

      when(() => mockWebScraper.fetchRawHtml(any(), any())).thenAnswer(
        (_) async => null,
      );
      when(() => mockWebScraper.performExtraction(any(), any())).thenAnswer(
        (_) async => ExtractionResult(
          success: false,
          error: 'WebScraper found nothing',
          metadata: {},
        ),
      );
      when(() => mockWebScraper.dispose()).thenReturn(null);

      ocrService = OCRExtractionService.createForTesting(
        testHttpClient: ocrClient,
        testOcrApiKey: 'test-ocr-key',
      );

      textStrategy = TextImportStrategy();
      urlStrategy = UrlImportStrategy(
        httpClient: MockClient((request) async {
          requested.add(request.url);
          if (networkDown) throw const SocketException('Network error');
          final page = pages[request.url.toString()];
          if (page == null) return http.Response('Not Found', 404);
          return http.Response(
            page,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
        webScraperFactory: () => mockWebScraper,
        dnsLookup: (_) async => [InternetAddress('8.8.8.8')],
      );
      photoStrategy = PhotoImportStrategy(
        ocrService: ocrService,
        textStrategy: textStrategy,
      );

      importManager = ImportManager.withStrategies(
        mockPersonalOps,
        [urlStrategy, textStrategy, photoStrategy],
        eventLogger: _SilentEventLogger(),
      );

      when(() => mockPersonalOps.addUnifiedRecipe(any())).thenAnswer(
        (_) async => RecipeOperationResult.success('Recipe saved successfully'),
      );
    });

    tearDown(() async {
      await ocrService.dispose();
      OCRExtractionService.resetForTesting();
    });

    group('Scenario 1: URL with JSON-LD', () {
      test('should extract recipe from URL with schema.org JSON-LD', () async {
        const testUrl = 'https://example.com/recipe/kottbullar';
        servePage(testUrl, ImportHTMLFixtures.jsonLdRecipeHtml);

        final result = await urlStrategy.import(testUrl);

        expect(result.isSuccess, isTrue, reason: 'Import should succeed');
        expect(result.recipe!.title, equals('Köttbullar med gräddsås'));
        expect(result.recipe!.ingredients, contains('500 g köttfärs'));
        expect(result.recipe!.instructions, isNotEmpty);
        expect(
          result.recipe!.portions,
          equals(4),
          reason: 'Portions should be extracted from recipeYield',
        );
        expect(
          result.recipe!.timeMinutes,
          equals(40),
          reason: 'Total time should be read from PT40M',
        );
        expect(result.recipe!.sourceUrl, testUrl);

        expect(result.metadata!['data_format'], equals('Recipe'));
        expect(result.metadata!['extraction_method'], equals('schema.org'));
        expect(result.metadata!['successfulTier'], 'StructuredExtraction');
        expect(requested, contains(Uri.parse(testUrl)));
      });

      test('should keep prep and cook time apart (ISO 8601)', () async {
        const testUrl = 'https://example.com/recipe/timing';
        servePage(testUrl, ImportHTMLFixtures.jsonLdRecipeHtml);

        final result = await urlStrategy.import(testUrl);

        // The fixture says PT15M prep and PT25M cook: asymmetric values so a
        // swap or a lost field shows up.
        expect(result.recipe!.core.prepTimeMinutes, equals(15));
        expect(result.recipe!.core.cookTimeMinutes, equals(25));
      });
    });

    group('Scenario 2: URL without structured data', () {
      test(
        'should parse the HTML text when no structured data exists',
        () async {
          const testUrl = 'https://example.com/recipe/plain';
          servePage(testUrl, ImportHTMLFixtures.plainHtmlRecipe);

          final result = await urlStrategy.import(testUrl);

          expect(result.isSuccess, isTrue);
          expect(result.recipe!.title, isNotEmpty);
          expect(result.recipe!.ingredients, isNotEmpty);
          expect(result.metadata!['extraction_method'], 'html_text_parse');
          expect(result.metadata!['successfulTier'], 'HtmlTextParse');
          expect(
            result.warnings,
            contains('Extracted from HTML text - quality may vary'),
            reason: 'The user should be told this was not structured data',
          );
        },
      );

      test(
        'should parse the headless browser text when the page is unreachable',
        () async {
          // No page is served, so the HTTP fetch is a 404 and only the
          // headless browser can answer.
          const testUrl = 'https://example.com/recipe/js-rendered';
          when(
            () => mockWebScraper.performExtraction(any(), any()),
          ).thenAnswer(
            (_) async => ExtractionResult(
              success: true,
              extractedText: ImportTextFixtures.wellStructuredRecipe,
              metadata: {'extraction_method': 'webscraper_mock'},
            ),
          );

          final result = await urlStrategy.import(testUrl);

          expect(result.isSuccess, isTrue);
          expect(result.recipe!.title, equals('Köttbullar med gräddsås'));
          expect(result.recipe!.sourceUrl, testUrl);
          expect(result.metadata!['extraction_method'], 'text_fallback');
          expect(result.metadata!['successfulTier'], 'WebScraper');
          expect(
            result.warnings,
            contains('No structured data found - parsed as plain text'),
          );
        },
      );

      test(
        'should fail with an unreachable cause when the network is down',
        () async {
          networkDown = true;

          final result = await urlStrategy.import(
            'https://example.com/recipe/x',
          );

          expect(result.isSuccess, isFalse);
          expect(result.errorCode, ImportErrorCode.urlNotAccessible);
          expect(result.recipe, isNull);
        },
      );
    });

    group('Scenario 3: Photo with OCR extraction', () {
      test(
        'should extract recipe from photo via OCR with high confidence',
        () async {
          stubOcrText(ImportOCRFixtures.highConfidenceSwedishRecipe);

          final result = await photoStrategy.import(
            'photo',
            options: {'imageBytes': OCRTestImages.mediumQuality},
          );

          expect(result.isSuccess, isTrue, reason: '${result.errorMessage}');
          expect(result.recipe!.title, equals('Köttbullar med gräddsås'));
          expect(result.recipe!.ingredients, contains('500 g köttfärs'));
          expect(result.recipe!.ingredients, contains('1 ägg'));
          expect(result.metadata!['ocr_method'], 'ocr_space');
          expect(
            result.metadata!['ocr_confidence'],
            greaterThan(0.8),
            reason: 'Clean OCR text should score above 80%',
          );
          expect(
            result.warnings?.where((w) => w.contains('OCR confidence')),
            isEmpty,
            reason: 'High confidence should not warn about the OCR quality',
          );
        },
      );

      test('should warn when the OCR text is garbled', () async {
        stubOcrText(ImportOCRFixtures.lowConfidenceOCRText);

        final result = await photoStrategy.import(
          'photo',
          options: {'imageBytes': OCRTestImages.mediumQuality},
        );

        expect(result.isSuccess, isTrue, reason: '${result.errorMessage}');
        expect(
          result.metadata!['ocr_confidence'],
          lessThan(0.85),
          reason: 'Garbled text must not be reported as high confidence',
        );
        expect(
          result.warnings!.any((w) => w.contains('OCR confidence')),
          isTrue,
          reason: 'Low OCR confidence must be surfaced to the user',
        );
      });
    });

    group('Scenario 4: Direct text import', () {
      test('should parse well-structured Swedish recipe text', () async {
        final result = await textStrategy.import(
          ImportTextFixtures.wellStructuredRecipe,
        );

        expect(result.isSuccess, isTrue);
        expect(result.recipe!.title, equals('Köttbullar med gräddsås'));
        expect(result.recipe!.portions, equals(4));
        expect(result.recipe!.timeMinutes, equals(40));
        expect(result.recipe!.mealType, equals('Middag'));
        expect(result.recipe!.ingredients, contains('500 g köttfärs'));
        expect(
          result.recipe!.instructions.any(
            (inst) => inst.contains('Blanda köttfärs'),
          ),
          isTrue,
        );
      });

      test(
        'should strip emojis and hashtags from a social media post',
        () async {
          final result = await textStrategy.import(
            ImportTextFixtures.socialMediaRecipe,
          );

          expect(result.isSuccess, isTrue);
          expect(
            result.recipe!.ingredients,
            containsAll(['400 g spagetti', '150 g bacon']),
            reason: 'Emojis and the bracketed note must not reach the rows',
          );
          final everything = [
            ...result.recipe!.ingredients,
            ...result.recipe!.instructions,
          ].join('\n');
          expect(everything, isNot(contains('🍝')));
          expect(everything, isNot(contains('#carbonara')));
        },
      );

      test(
        'should keep the shouted title of a social media post',
        () async {
          final result = await textStrategy.import(
            ImportTextFixtures.socialMediaRecipe,
          );

          expect(result.recipe!.title, contains('CARBONARA'));
          expect(result.recipe!.title, isNot(contains('🍝')));
        },
        skip:
            'BUT-1513: an all-caps first line is read as a section label, so '
            'the post gets an empty title and the warning "Recipe name seems '
            'too short or empty"',
      );

      test(
        'should still produce a recipe from poorly structured text',
        () async {
          final result = await textStrategy.import(
            ImportTextFixtures.poorlyStructuredRecipe,
          );

          expect(result.isSuccess, isTrue);
          expect(result.recipe!.title, contains('pannkakor'));
        },
      );

      test('should keep approximate and ranged ingredient lines', () async {
        final result = await textStrategy.import(
          ImportTextFixtures.recipeWithApproximations,
        );

        expect(result.isSuccess, isTrue);
        expect(result.recipe!.ingredients.length, greaterThan(3));
      });
    });

    group('Scenario 5: Auto-detection and fallback', () {
      test(
        'should auto-detect a URL, parse it and leave saving to the caller',
        () async {
          const testUrl = 'https://example.com/recipe/auto';
          servePage(testUrl, ImportHTMLFixtures.jsonLdRecipeHtml);

          final ImportManagerResult result = await importManager.autoImport(
            testUrl,
          );

          expect(result.isSuccess, isTrue);
          expect(result.strategy, equals('URL Import'));
          expect(result.recipe!.title, equals('Köttbullar med gräddsås'));
          verifyNever(() => mockPersonalOps.addUnifiedRecipe(any()));

          final saved = await importManager.saveImportedRecipe(result.recipe!);

          expect(saved.isSuccess, isTrue);
          verify(
            () => mockPersonalOps.addUnifiedRecipe(result.recipe!),
          ).called(1);
        },
      );

      test(
        'should carry the URL strategy failure cause when the page is gone',
        () async {
          const testUrl = 'https://invalid-url-that-404s.com/recipe';

          final ImportManagerResult result = await importManager.autoImport(
            testUrl,
          );

          expect(result.isSuccess, isFalse);
          expect(result.strategy, 'URL Import');
          expect(result.errorCode, ImportErrorCode.urlNotAccessible);
          verifyNever(() => mockPersonalOps.addUnifiedRecipe(any()));
        },
      );

      test('should import pasted text through the text strategy', () async {
        final ImportManagerResult result = await importManager.autoImport(
          ImportTextFixtures.wellStructuredRecipe,
        );

        expect(result.isSuccess, isTrue);
        expect(result.strategy, equals('Text Import'));
        expect(result.recipe!.title, equals('Köttbullar med gräddsås'));
        expect(
          requested,
          isEmpty,
          reason: 'Pasted text must not trigger any page fetch',
        );
      });

      test(
        'should preserve ingredients and steps through the manager',
        () async {
          const testInput = '''
Recipe from social media:

Pannkakor 🥞
3dl mjöl, 6dl mjölk, 3 ägg
Vispa ihop och stek!

#pannkakor #frukost
''';

          final ImportManagerResult result = await importManager.autoImport(
            testInput,
          );

          expect(result.isSuccess, isTrue, reason: '${result.errorMessage}');
          expect(result.recipe!.ingredients, isNotEmpty);
          expect(result.recipe!.instructions, isNotEmpty);
          expect(result.metadata!['strategy'], 'Text Import');
        },
      );
    });

    group('Edge Cases', () {
      test('should reject empty text', () async {
        final result = await textStrategy.import('');

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, isNotNull);
      });

      test('should reject a photo import without image bytes', () async {
        final result = await photoStrategy.import('photo');

        expect(result.isSuccess, isFalse);
        expect(result.errorMessage, contains('imageBytes'));
      });
    });
  });
}
