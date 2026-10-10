/// Integration tests for Swedish recipe site parsers (ICA.se, Arla.se,
/// Köket.se, Recept.se) driven through the real [UrlImportStrategy].
///
/// Pages are served by an in-memory HTTP client and the DNS lookup is
/// injected, so nothing touches the network. No `RecipeParserService` is
/// registered, which leaves the site parsers (structured-data tier) to answer
/// the import; the headless-browser tiers are stubbed to find nothing so a
/// page the parsers reject surfaces as a failure instead of as scraper text.
///
/// Priority: HIGH - Critical for Swedish market
@Tags(['integration'])
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';

// Core imports
import 'package:butlery/services/import/models/import_result_v2.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/extraction/site_parsers/site_parser_registry.dart';
import 'package:butlery/services/extraction/site_parsers/ica_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/arla_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/koket_recipe_parser.dart';
import 'package:butlery/services/extraction/site_parsers/recept_recipe_parser.dart';
import 'package:butlery/services/social_media_extractor.dart';

// Test infrastructure
import '../../fixtures/swedish_sites/ica_test_data.dart';
import '../../fixtures/swedish_sites/arla_test_data.dart';
import '../../fixtures/swedish_sites/koket_test_data.dart';
import '../../fixtures/swedish_sites/recept_test_data.dart';
import '../../infrastructure/mocks/import_mocks.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  // Register all fallback values for mocktail
  setUpAll(() {
    ImportMockSetup.registerFallbacks();

    // Register Swedish site parsers for integration tests
    SiteParserRegistry.register(IcaRecipeParser());
    SiteParserRegistry.register(ArlaRecipeParser());
    SiteParserRegistry.register(KoketRecipeParser());
    SiteParserRegistry.register(ReceptRecipeParser());
  });

  group('Swedish Recipe Sites - Integration Tests', () {
    late MockWebScraper mockWebScraper;
    late UrlImportStrategy urlStrategy;
    late Map<String, String> pages;
    late List<Uri> requested;
    late bool networkDown;

    void servePage(String url, String html) => pages[url] = html;

    setUp(() {
      pages = {};
      requested = [];
      networkDown = false;
      mockWebScraper = MockWebScraper();

      when(() => mockWebScraper.fetchRawHtml(any(), any())).thenAnswer(
        (_) async => null,
      );
      when(() => mockWebScraper.performExtraction(any(), any())).thenAnswer(
        (_) async => ExtractionResult(
          success: false,
          error: 'WebScraper not needed for structured data',
          metadata: {},
        ),
      );
      when(() => mockWebScraper.dispose()).thenReturn(null);

      urlStrategy = UrlImportStrategy(
        httpClient: MockClient((request) async {
          requested.add(request.url);
          if (networkDown) throw const SocketException('Network error');
          final html = pages[request.url.toString()];
          if (html == null) return http.Response('Not Found', 404);
          return http.Response(
            html,
            200,
            headers: {'content-type': 'text/html; charset=utf-8'},
          );
        }),
        webScraperFactory: () => mockWebScraper,
        dnsLookup: (_) async => [InternetAddress('8.8.8.8')],
      );
    });

    // ========================================================================
    // ICA.SE - Complete Recipe with Site-Specific Enhancements
    // ========================================================================

    group('ICA.se - Complete Recipe with Enhancements', () {
      test(
        'should extract complete ICA recipe with all site-specific fields',
        () async {
          // Arrange
          final testUrl = 'https://www.ica.se/recept/kottbullar-724853/';
          final icaHtml = IcaTestFixtures.kottbullarComplete;

          servePage(testUrl, icaHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted successfully
          expect(result.isSuccess, isTrue, reason: 'ICA import should succeed');
          expect(
            result.recipe,
            isNotNull,
            reason: 'Recipe should be extracted',
          );

          // Assert - Standard recipe fields
          expect(
            result.recipe!.title,
            equals('Klassiska köttbullar med gräddsås'),
            reason: 'Title should match JSON-LD data',
          );
          expect(
            result.recipe!.description,
            contains('Saftig köttbullar'),
            reason: 'Description should be extracted',
          );

          // Assert - Ingredients parsed (13 ingredients in fixture)
          expect(
            result.recipe!.ingredients,
            hasLength(13),
            reason: 'Should extract all 13 ingredients',
          );
          expect(
            result.recipe!.ingredients,
            contains('500 g nötfärs'),
            reason: 'Should contain main ingredient',
          );
          expect(
            result.recipe!.ingredients,
            contains('1 ägg'),
            reason: 'Should contain egg ingredient',
          );

          // Assert - Instructions parsed (6 steps in fixture)
          expect(
            result.recipe!.instructions,
            hasLength(6),
            reason: 'Should extract all 6 instruction steps',
          );
          expect(
            result.recipe!.instructions.first,
            contains('Blanda köttfärs'),
            reason: 'First instruction should be about mixing ingredients',
          );

          // Assert - Metadata parsed
          expect(
            result.recipe!.portions,
            equals(4),
            reason: 'Should extract 4 portions from recipeYield',
          );
          expect(
            result.recipe!.timeMinutes,
            equals(45),
            reason: 'Should calculate 45 minutes from PT45M',
          );

          // Assert - Site-specific extraction used
          expect(result.metadata, isNotNull);
          expect(
            result.metadata!['extraction_method'],
            equals('site_specific'),
            reason: 'Should use ICA site parser, not generic RecipeScraper',
          );
          expect(
            result.metadata!['site_parser'],
            equals('ica.se'),
            reason: 'Should track which site parser was used',
          );

          // Verify HTTP client was called
          expect(requested, contains(Uri.parse(testUrl)));
        },
      );
    });

    // ========================================================================
    // ICA.SE - Swedish Character Handling
    // ========================================================================

    group('ICA.se - Swedish Text Handling', () {
      test(
        'should preserve Swedish characters (Å, Ä, Ö) in recipe data',
        () async {
          // Arrange
          final testUrl = 'https://www.ica.se/recept/artsoppa/';
          final icaHtml = IcaTestFixtures.recipeWithSwedishChars;

          servePage(testUrl, icaHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Swedish characters preserved
          expect(result.isSuccess, isTrue);
          expect(
            result.recipe!.title,
            equals('Ärtsoppa med fläsk'),
            reason: 'Title should preserve Ä character',
          );
          expect(
            result.recipe!.description,
            contains('torsdagsmiddagen'),
            reason: 'Description should be preserved',
          );

          // Assert - Swedish characters in ingredients
          final ingredients = result.recipe!.ingredients;
          expect(
            ingredients.toString(),
            contains('ärtor'),
            reason: 'Should preserve Ä in ingredient "ärtor"',
          );
          expect(
            ingredients.toString(),
            contains('lök'),
            reason: 'Should preserve Ö in ingredient "lök"',
          );
          expect(
            ingredients.toString(),
            contains('senapsfrön'),
            reason: 'Should preserve Ö in ingredient "senapsfrön"',
          );
        },
      );
    });

    // ========================================================================
    // ICA.SE - Quality Scoring and Rejection
    // ========================================================================

    group('ICA.se - Quality Validation', () {
      test(
        'should reject recipe with insufficient data (quality check)',
        () async {
          // Arrange
          final testUrl = 'https://www.ica.se/recept/minimal/';
          final icaHtml = IcaTestFixtures.recipeMinimalData;

          servePage(testUrl, icaHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe rejected due to low quality (<80% completeness)
          expect(
            result.isSuccess,
            isFalse,
            reason: 'Recipe with only 2 ingredients should fail quality check',
          );
          expect(
            result.errorCode,
            ImportErrorCode.noRecipeContent,
            reason: 'Rejected page should report that no recipe was found',
          );
          expect(result.recipe, isNull);
        },
      );

      test('should accept complete recipe with high quality score', () async {
        // Arrange
        final testUrl = 'https://www.ica.se/recept/laxpasta/';
        final icaHtml = IcaTestFixtures.recipeCompleteMetadata;

        servePage(testUrl, icaHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - High quality recipe accepted (>95% completeness)
        expect(
          result.isSuccess,
          isTrue,
          reason: 'Complete recipe should pass quality check',
        );
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, equals('Krämig laxpasta med spenat'));

        // Assert - All quality indicators present
        expect(
          result.recipe!.ingredients,
          hasLength(greaterThan(3)),
          reason: 'Should have 3+ ingredients',
        );
        expect(
          result.recipe!.instructions,
          hasLength(greaterThan(2)),
          reason: 'Should have 2+ instructions',
        );
        expect(
          result.recipe!.portions,
          isNotNull,
          reason: 'Should have portions',
        );
        expect(
          result.recipe!.timeMinutes,
          isNotNull,
          reason: 'Should have time',
        );
        expect(
          result.recipe!.imageUrls,
          isNotEmpty,
          reason: 'Should have image URL',
        );
      });
    });

    // ========================================================================
    // ICA.SE - CSS Selector Fallback
    // ========================================================================

    group('ICA.se - CSS Fallback When JSON-LD Missing', () {
      test(
        'should extract recipe using CSS selectors when JSON-LD is missing',
        () async {
          // Arrange
          final testUrl = 'https://www.ica.se/recept/kladdkaka/';
          final icaHtml = IcaTestFixtures.recipeWithoutJsonLd;

          servePage(testUrl, icaHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted via CSS fallback
          expect(
            result.isSuccess,
            isTrue,
            reason: 'Should succeed via CSS selector fallback',
          );
          expect(result.recipe, isNotNull);
          expect(
            result.recipe!.title,
            equals('Klassisk kladdkaka'),
            reason: 'Should extract title from CSS selectors',
          );

          // Assert - Ingredients and instructions extracted
          expect(
            result.recipe!.ingredients,
            hasLength(greaterThan(3)),
            reason: 'Should extract ingredients from CSS selectors',
          );
          expect(
            result.recipe!.instructions,
            hasLength(greaterThan(3)),
            reason: 'Should extract instructions from CSS selectors',
          );

          // Assert - Metadata extracted via CSS
          expect(
            result.recipe!.portions,
            isNotNull,
            reason: 'Should extract portions from CSS selectors',
          );
          expect(
            result.recipe!.timeMinutes,
            isNotNull,
            reason: 'Should extract time from CSS selectors',
          );
          expect(
            result.recipe!.imageUrls,
            isNotEmpty,
            reason: 'Should extract image from CSS selectors',
          );
        },
      );

      test('should fall back to CSS when JSON-LD is malformed', () async {
        // Arrange
        final testUrl = 'https://www.ica.se/recept/lasagne/';
        final icaHtml = IcaTestFixtures.recipeWithMalformedJson;

        servePage(testUrl, icaHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Recipe recovered via CSS fallback
        expect(
          result.isSuccess,
          isTrue,
          reason: 'Should recover from malformed JSON-LD via CSS fallback',
        );
        expect(result.recipe!.title, equals('Lasagne al forno'));
        expect(result.recipe!.ingredients, hasLength(greaterThan(3)));
        expect(result.recipe!.instructions, hasLength(3));
      });
    });

    // ========================================================================
    // ICA.SE - ICA-Specific Formatting Cleanup
    // ========================================================================

    group('ICA.se - Formatting Cleanup', () {
      test('should clean ICA-specific formatting quirks', () async {
        // Arrange
        final testUrl = 'https://www.ica.se/recept/tacos/';
        final icaHtml = IcaTestFixtures.recipeWithIcaQuirks;

        servePage(testUrl, icaHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Recipe extracted with cleaned formatting
        expect(result.isSuccess, isTrue);

        // Assert - "ca" and "cirka" removed from portions
        expect(
          result.recipe!.portions,
          equals(4),
          reason: 'Should clean "ca" from portions ("ca 4 portioner" → 4)',
        );

        // Assert - Whitespace trimmed from ingredients
        final ingredients = result.recipe!.ingredients;
        for (final ingredient in ingredients) {
          expect(
            ingredient,
            equals(ingredient.trim()),
            reason: 'Ingredient should not have leading/trailing whitespace',
          );
        }

        // Assert - Specific cleaned ingredients
        expect(
          ingredients.any((ing) => ing.contains('500 g nötfärs')),
          isTrue,
          reason: 'Should have cleaned ingredient "500 g nötfärs"',
        );
        expect(
          ingredients.any((ing) => ing.contains('8 tortillabröd')),
          isTrue,
          reason: 'Should have cleaned ingredient "8 tortillabröd"',
        );
      });

      test('should trim whitespace from instructions', () async {
        // Arrange
        final testUrl = 'https://www.ica.se/recept/tacos/';
        final icaHtml = IcaTestFixtures.recipeWithIcaQuirks;

        servePage(testUrl, icaHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Instructions trimmed
        expect(result.isSuccess, isTrue);
        final instructions = result.recipe!.instructions;

        for (final instruction in instructions) {
          expect(
            instruction,
            equals(instruction.trim()),
            reason: 'Instruction should not have leading/trailing whitespace',
          );
          expect(
            instruction,
            isNot(startsWith(' ')),
            reason: 'Instruction should not start with space',
          );
          expect(
            instruction,
            isNot(endsWith(' ')),
            reason: 'Instruction should not end with space',
          );
        }
      });
    });

    // ========================================================================
    // Error Handling and Edge Cases
    // ========================================================================

    group('Error Handling', () {
      test('should return null for invalid HTML without recipe data', () async {
        // Arrange
        final testUrl = 'https://www.ica.se/products/not-a-recipe';
        const invalidHtml = '<html><body>Not a recipe page</body></html>';

        servePage(testUrl, invalidHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Extraction fails gracefully
        expect(
          result.isSuccess,
          isFalse,
          reason: 'Should fail for invalid HTML without recipe data',
        );
        expect(
          result.errorMessage,
          isNotNull,
          reason: 'Should provide error message',
        );
      });

      test('should handle network errors gracefully', () async {
        // Arrange
        final testUrl = 'https://www.ica.se/recept/network-error/';

        networkDown = true;

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Failure with error message
        expect(
          result.isSuccess,
          isFalse,
          reason: 'Should fail when network request fails',
        );
        expect(result.errorMessage, isNotNull);
      });
    });

    // ========================================================================
    // ARLA.SE - Complete Recipe with Dairy-Specific Enhancements
    // ========================================================================

    group('Arla.se - Complete Recipe with Enhancements', () {
      test(
        'should extract complete Arla recipe with all site-specific fields',
        () async {
          // Arrange
          final testUrl = 'https://www.arla.se/recept/chokladbollar/';
          final arlaHtml = ArlaTestFixtures.chokladbollarComplete;

          servePage(testUrl, arlaHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted successfully
          expect(
            result.isSuccess,
            isTrue,
            reason: 'Arla import should succeed',
          );
          expect(
            result.recipe,
            isNotNull,
            reason: 'Recipe should be extracted',
          );

          // Assert - Standard recipe fields
          expect(
            result.recipe!.title,
            equals('Chokladbollar'),
            reason: 'Title should match JSON-LD data',
          );
          expect(
            result.recipe!.description,
            contains('Klassiska chokladbollar'),
            reason: 'Description should be extracted',
          );

          // Assert - Ingredients parsed (7 ingredients in fixture)
          expect(
            result.recipe!.ingredients,
            hasLength(7),
            reason: 'Should extract all 7 ingredients',
          );
          expect(
            result.recipe!.ingredients,
            contains('100 g smör, rumstempererat'),
            reason: 'Should contain butter ingredient',
          );

          // Assert - Instructions parsed (4 steps in fixture)
          expect(
            result.recipe!.instructions,
            hasLength(4),
            reason: 'Should extract all 4 instruction steps',
          );

          // Assert - Metadata parsed
          expect(
            result.recipe!.portions,
            isNotNull,
            reason: 'Should extract portions',
          );
          expect(
            result.recipe!.timeMinutes,
            equals(15),
            reason: 'Should calculate 15 minutes from PT15M',
          );

          // Assert - Site-specific extraction used
          expect(result.metadata, isNotNull);
          expect(
            result.metadata!['extraction_method'],
            equals('site_specific'),
            reason: 'Should use Arla site parser, not generic RecipeScraper',
          );
          expect(
            result.metadata!['site_parser'],
            equals('arla.se'),
            reason: 'Should track which site parser was used',
          );

          // Verify HTTP client was called
          expect(requested, contains(Uri.parse(testUrl)));
        },
      );

      test('should extract nutritional information from Arla recipe', () async {
        // Arrange
        final testUrl = 'https://www.arla.se/recept/chokladbollar/';
        final arlaHtml = ArlaTestFixtures.chokladbollarComplete;

        servePage(testUrl, arlaHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Nutritional info extracted
        expect(result.isSuccess, isTrue);
        final nutrition = result.recipe!.nutritionInfo;
        expect(nutrition, isNotNull, reason: 'Should extract nutrition');
        expect(nutrition!.calories, 120);
      });

      test(
        'should keep protein, fat and carbohydrates from the Arla nutrition box',
        () async {
          final testUrl = 'https://www.arla.se/recept/chokladbollar/';
          servePage(testUrl, ArlaTestFixtures.chokladbollarComplete);

          final result = await urlStrategy.import(testUrl);

          // The Arla parser reads protein/fat/carbohydrates but emits them
          // under keys NutritionInfo.fromSchemaOrg does not read, so only
          // calories survive.
          final nutrition = result.recipe!.nutritionInfo!;
          expect(nutrition.protein, contains('2'));
          expect(nutrition.fat, contains('6'));
          expect(nutrition.carbs, contains('15'));
        },
        skip:
            'BUT-1513: Arla parser emits nutrition keys (protein, fat, '
            'carbohydrates) that NutritionInfo.fromSchemaOrg ignores',
      );
    });

    // ========================================================================
    // ARLA.SE - Swedish Text Handling
    // ========================================================================

    group('Arla.se - Swedish Text Handling', () {
      test(
        'should preserve Swedish characters (Å, Ä, Ö) in recipe data',
        () async {
          // Arrange
          final testUrl = 'https://www.arla.se/recept/appelpaj/';
          final arlaHtml = ArlaTestFixtures.recipeWithSwedishChars;

          servePage(testUrl, arlaHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Swedish characters preserved
          expect(result.isSuccess, isTrue);
          expect(
            result.recipe!.title,
            equals('Äppelpaj med vaniljsås'),
            reason: 'Title should preserve Ä character',
          );

          // Assert - Swedish characters in ingredients
          final ingredients = result.recipe!.ingredients;
          expect(
            ingredients.toString(),
            contains('äpplen'),
            reason: 'Should preserve Ä in ingredient "äpplen"',
          );
        },
      );
    });

    // ========================================================================
    // ARLA.SE - Quality Validation
    // ========================================================================

    group('Arla.se - Quality Validation', () {
      test(
        'should reject recipe with insufficient data (quality check)',
        () async {
          // Arrange
          final testUrl = 'https://www.arla.se/recept/minimal/';
          final arlaHtml = ArlaTestFixtures.recipeMinimalData;

          servePage(testUrl, arlaHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe rejected due to low quality (<80% completeness)
          expect(
            result.isSuccess,
            isFalse,
            reason: 'Recipe with only 2 ingredients should fail quality check',
          );
          expect(
            result.errorCode,
            ImportErrorCode.noRecipeContent,
            reason: 'Rejected page should report that no recipe was found',
          );
          expect(result.recipe, isNull);
        },
      );

      test('should accept complete recipe with high quality score', () async {
        // Arrange
        final testUrl = 'https://www.arla.se/recept/laxpasta/';
        final arlaHtml = ArlaTestFixtures.recipeCompleteMetadata;

        servePage(testUrl, arlaHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - High quality recipe accepted (>95% completeness)
        expect(
          result.isSuccess,
          isTrue,
          reason: 'Complete recipe should pass quality check',
        );
        expect(result.recipe, isNotNull);
        expect(result.recipe!.title, equals('Krämig laxpasta med spenat'));

        // Assert - All quality indicators present
        expect(
          result.recipe!.ingredients,
          hasLength(greaterThan(3)),
          reason: 'Should have 3+ ingredients',
        );
        expect(
          result.recipe!.instructions,
          hasLength(greaterThan(2)),
          reason: 'Should have 2+ instructions',
        );
        expect(
          result.recipe!.portions,
          isNotNull,
          reason: 'Should have portions',
        );
        expect(
          result.recipe!.timeMinutes,
          isNotNull,
          reason: 'Should have time',
        );
        expect(
          result.recipe!.imageUrls,
          isNotEmpty,
          reason: 'Should have image URL',
        );
      });
    });

    // ========================================================================
    // ARLA.SE - CSS Fallback When JSON-LD Missing
    // ========================================================================

    group('Arla.se - CSS Fallback', () {
      test(
        'should extract recipe using CSS selectors when JSON-LD is missing',
        () async {
          // Arrange
          final testUrl = 'https://www.arla.se/recept/pannkakor/';
          final arlaHtml = ArlaTestFixtures.recipeWithoutJsonLd;

          servePage(testUrl, arlaHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted via CSS fallback
          expect(
            result.isSuccess,
            isTrue,
            reason: 'Should succeed via CSS selector fallback',
          );
          expect(result.recipe, isNotNull);
          expect(
            result.recipe!.title,
            equals('Fluffiga pannkakor'),
            reason: 'Should extract title from CSS selectors',
          );

          // Assert - Ingredients and instructions extracted
          expect(
            result.recipe!.ingredients,
            hasLength(greaterThan(3)),
            reason: 'Should extract ingredients from CSS selectors',
          );
          expect(
            result.recipe!.instructions,
            hasLength(greaterThan(3)),
            reason: 'Should extract instructions from CSS selectors',
          );
        },
      );

      test('should fall back to CSS when JSON-LD is malformed', () async {
        // Arrange
        final testUrl = 'https://www.arla.se/recept/kladdkaka/';
        final arlaHtml = ArlaTestFixtures.recipeWithMalformedJson;

        servePage(testUrl, arlaHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Recipe recovered via CSS fallback
        expect(
          result.isSuccess,
          isTrue,
          reason: 'Should recover from malformed JSON-LD via CSS fallback',
        );
        expect(result.recipe!.title, equals('Kladdkaka med grädde'));
        expect(result.recipe!.ingredients, hasLength(greaterThan(3)));
      });
    });

    // ========================================================================
    // ARLA.SE - Formatting Cleanup
    // ========================================================================

    group('Arla.se - Formatting Cleanup', () {
      test('should clean Arla-specific formatting quirks', () async {
        // Arrange
        final testUrl = 'https://www.arla.se/recept/lasagne/';
        final arlaHtml = ArlaTestFixtures.recipeWithArlaQuirks;

        servePage(testUrl, arlaHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Recipe extracted with cleaned formatting
        expect(result.isSuccess, isTrue);

        // Assert - "ca" and "cirka" removed from portions
        expect(
          result.recipe!.portions,
          equals(6),
          reason: 'Should clean "ca" from portions ("ca 6 portioner" → 6)',
        );

        // Assert - Whitespace trimmed from ingredients
        final ingredients = result.recipe!.ingredients;
        for (final ingredient in ingredients) {
          expect(
            ingredient,
            equals(ingredient.trim()),
            reason: 'Ingredient should not have leading/trailing whitespace',
          );
        }
      });
    });

    // ========================================================================
    // KÖKET.SE - Complete Recipe with Site-Specific Enhancements
    // ========================================================================

    group('Köket.se - Complete Recipe with Enhancements', () {
      test(
        'should extract complete Köket recipe with all site-specific fields',
        () async {
          // Arrange
          final testUrl = 'https://www.koket.se/recept/klassiska-kottbullar/';
          final koketHtml = KoketTestFixtures.kottbullarProfessional;

          servePage(testUrl, koketHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted successfully
          expect(result.isSuccess, isTrue);
          expect(result.recipe, isNotNull);

          // Assert - Basic recipe data
          expect(result.recipe!.title, equals('Klassiska svenska köttbullar'));
          expect(result.recipe!.description, contains('Perfekta köttbullar'));
          expect(result.recipe!.ingredients.length, equals(7));
          expect(result.recipe!.instructions.length, equals(3));
          expect(result.recipe!.portions, equals(4));
          expect(result.recipe!.timeMinutes, equals(45));

          // Assert - Metadata indicates site-specific parser used
          expect(
            result.metadata,
            containsPair('extraction_method', 'site_specific'),
          );
          expect(result.metadata, containsPair('site_parser', 'koket.se'));
        },
      );
    });

    group('Köket.se - User-Generated Content', () {
      test(
        'should handle user-generated recipe with variable quality',
        () async {
          // Arrange
          final testUrl = 'https://www.koket.se/recept/mormors-pannkakor/';
          final koketHtml = KoketTestFixtures.userGeneratedRecipe;

          servePage(testUrl, koketHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted successfully despite UGC variability
          expect(result.isSuccess, isTrue);
          expect(result.recipe!.title, contains('pannkakor'));
        },
      );
    });

    group('Köket.se - Swedish Text Handling', () {
      test('should preserve Swedish characters (Å, Ä, Ö)', () async {
        // Arrange
        final testUrl = 'https://www.koket.se/recept/artsoppa/';
        final koketHtml = KoketTestFixtures.recipeWithSwedishChars;

        servePage(testUrl, koketHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Swedish characters preserved
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.title, equals('Ärtsoppa med fläsk'));

        // Assert - Ingredients with Swedish characters
        expect(result.recipe!.ingredients, contains('500 g gula ärtor'));
        expect(result.recipe!.ingredients, contains('2 rökta fläskben'));
      });
    });

    group('Köket.se - Quality Validation', () {
      test(
        'should accept recipe with complete metadata (high quality)',
        () async {
          // Arrange
          final testUrl = 'https://www.koket.se/recept/laxpasta/';
          final koketHtml = KoketTestFixtures.recipeCompleteMetadata;

          servePage(testUrl, koketHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted with high quality
          expect(result.isSuccess, isTrue);
          expect(result.recipe!.title, equals('Krämig laxpasta'));
          expect(result.recipe!.description, isNotEmpty);
          expect(result.recipe!.ingredients.length, greaterThanOrEqualTo(6));
          expect(result.recipe!.instructions.length, greaterThanOrEqualTo(4));
        },
      );

      test('should reject recipe with minimal data (below threshold)', () async {
        // Arrange
        final testUrl = 'https://www.koket.se/recept/smorgAs/';
        final koketHtml = KoketTestFixtures.recipeMinimalData;

        servePage(testUrl, koketHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Recipe rejected due to low quality (only 2 ingredients, no instructions)
        // Quality = 20% (title) + 26.7% (2/3 ingredients) + 0% (instructions) = 46.7% < 80%
        expect(result.isSuccess, isFalse);
        expect(result.errorCode, ImportErrorCode.noRecipeContent);
        expect(result.recipe, isNull);
      });
    });

    group('Köket.se - CSS Fallback', () {
      test(
        'should extract recipe without JSON-LD using CSS selectors',
        () async {
          // Arrange
          final testUrl = 'https://www.koket.se/recept/kladdkaka/';
          final koketHtml = KoketTestFixtures.recipeWithoutJsonLd;

          servePage(testUrl, koketHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted via CSS fallback
          expect(result.isSuccess, isTrue);
          expect(result.recipe!.title, equals('Saftig kladdkaka'));
          expect(result.recipe!.description, contains('kladdig och god'));
          expect(result.recipe!.ingredients.length, greaterThanOrEqualTo(5));
          expect(result.recipe!.instructions.length, greaterThanOrEqualTo(4));
        },
      );

      test(
        'should fallback to CSS selectors when JSON-LD is malformed',
        () async {
          // Arrange
          final testUrl = 'https://www.koket.se/recept/lasagne/';
          final koketHtml = KoketTestFixtures.recipeWithMalformedJson;

          servePage(testUrl, koketHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted despite malformed JSON
          expect(result.isSuccess, isTrue);
          expect(result.recipe!.title, equals('Italiensk lasagne'));
          expect(result.recipe!.ingredients.length, greaterThanOrEqualTo(4));
        },
      );
    });

    group('Köket.se - Formatting Cleanup', () {
      test(
        'should clean "ca" and "cirka" from portions and ingredients',
        () async {
          // Arrange
          final testUrl = 'https://www.koket.se/recept/tacos/';
          final koketHtml = KoketTestFixtures.recipeWithKoketQuirks;

          servePage(testUrl, koketHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted with cleaned formatting
          expect(result.isSuccess, isTrue);

          // Assert - "ca" and "cirka" removed from portions
          expect(
            result.recipe!.portions,
            equals(4),
            reason:
                'Should clean "cirka" from portions ("cirka 4 portioner" → 4)',
          );

          // Assert - "ca" and "cirka" removed from ingredients
          expect(
            result.recipe!.ingredients,
            contains('500 g köttfärs'),
            reason: 'Should clean "ca " prefix from ingredient',
          );
          expect(
            result.recipe!.ingredients,
            contains('1 dl vatten'),
            reason: 'Should clean "cirka " prefix from ingredient',
          );

          // Assert - Whitespace trimmed
          final ingredients = result.recipe!.ingredients;
          for (final ingredient in ingredients) {
            expect(
              ingredient,
              equals(ingredient.trim()),
              reason: 'Ingredient should not have leading/trailing whitespace',
            );
          }
        },
      );
    });

    // ========================================================================
    // RECEPT.SE - Complete Recipe with Site-Specific Enhancements
    // ========================================================================

    group('Recept.se - Complete Recipe with Enhancements', () {
      test(
        'should extract complete Recept recipe with all site-specific fields',
        () async {
          // Arrange
          final testUrl = 'https://www.recept.se/recept/kanelbullar/';
          final receptHtml = ReceptTestFixtures.kanelbullarComplete;

          servePage(testUrl, receptHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted successfully
          expect(result.isSuccess, isTrue);
          expect(result.recipe, isNotNull);

          // Assert - Basic recipe data
          expect(result.recipe!.title, equals('Klassiska kanelbullar'));
          expect(
            result.recipe!.description,
            contains('Traditionella svenska kanelbullar'),
          );
          expect(result.recipe!.ingredients.length, equals(9));
          expect(result.recipe!.instructions.length, equals(4));
          expect(result.recipe!.portions, equals(25));
          expect(result.recipe!.timeMinutes, equals(45));

          // Assert - Metadata indicates site-specific parser used
          expect(
            result.metadata,
            containsPair('extraction_method', 'site_specific'),
          );
          expect(result.metadata, containsPair('site_parser', 'recept.se'));
        },
      );

      test(
        'should carry the cuisine from a Recept recipe onto the imported recipe',
        () async {
          // Arrange
          final testUrl = 'https://www.recept.se/recept/pasta-carbonara/';
          final receptHtml = ReceptTestFixtures.recipeWithCategoryAndCuisine;

          servePage(testUrl, receptHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Cuisine carried onto the recipe
          expect(result.isSuccess, isTrue);
          expect(result.recipe!.cuisine, 'Italiensk');
        },
      );
    });

    group('Recept.se - Swedish Text Handling', () {
      test('should preserve Swedish characters (Å, Ä, Ö)', () async {
        // Arrange
        final testUrl = 'https://www.recept.se/recept/alggryta/';
        final receptHtml = ReceptTestFixtures.recipeWithSwedishChars;

        servePage(testUrl, receptHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Swedish characters preserved
        expect(result.isSuccess, isTrue);
        expect(result.recipe!.title, equals('Älggryta med svamp och lingon'));

        // Assert - Ingredients with Swedish characters
        expect(
          result.recipe!.ingredients,
          contains('800 g älgkött i tärningar'),
        );
      });
    });

    group('Recept.se - Quality Validation', () {
      test(
        'should accept recipe with complete metadata (high quality)',
        () async {
          // Arrange
          final testUrl = 'https://www.recept.se/recept/grillad-lax/';
          final receptHtml = ReceptTestFixtures.recipeCompleteMetadata;

          servePage(testUrl, receptHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted with high quality
          expect(result.isSuccess, isTrue);
          expect(
            result.recipe!.title,
            equals('Grillad lax med citron och dill'),
          );
          expect(result.recipe!.description, isNotEmpty);
          expect(result.recipe!.ingredients.length, greaterThanOrEqualTo(6));
          expect(result.recipe!.instructions.length, greaterThanOrEqualTo(3));
          expect(result.recipe!.cuisine, isNotNull);
        },
      );

      test('should reject recipe with minimal data (below threshold)', () async {
        // Arrange
        final testUrl = 'https://www.recept.se/recept/toast/';
        final receptHtml = ReceptTestFixtures.recipeMinimalData;

        servePage(testUrl, receptHtml);

        // Act
        final result = await urlStrategy.import(testUrl);

        // Assert - Recipe rejected due to low quality (only 1 ingredient, no instructions)
        expect(result.isSuccess, isFalse);
        expect(result.errorCode, ImportErrorCode.noRecipeContent);
        expect(result.recipe, isNull);
      });
    });

    group('Recept.se - CSS Fallback', () {
      test(
        'should extract recipe without JSON-LD using CSS selectors',
        () async {
          // Arrange
          final testUrl = 'https://www.recept.se/recept/pannkakor/';
          final receptHtml = ReceptTestFixtures.recipeWithoutJsonLd;

          servePage(testUrl, receptHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted via CSS fallback
          expect(result.isSuccess, isTrue);
          expect(result.recipe!.title, equals('Klassiska svenska pannkakor'));
          expect(result.recipe!.description, contains('Tunna och luftiga'));
          expect(result.recipe!.ingredients.length, greaterThanOrEqualTo(5));
          expect(result.recipe!.instructions.length, greaterThanOrEqualTo(4));
        },
      );

      test(
        'should fallback to CSS selectors when JSON-LD is malformed',
        () async {
          // Arrange
          final testUrl = 'https://www.recept.se/recept/kottfarssas/';
          final receptHtml = ReceptTestFixtures.recipeWithMalformedJson;

          servePage(testUrl, receptHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted despite malformed JSON
          expect(result.isSuccess, isTrue);
          expect(result.recipe!.title, equals('Köttfärssås'));
          expect(result.recipe!.ingredients.length, greaterThanOrEqualTo(4));
        },
      );
    });

    group('Recept.se - Formatting Cleanup', () {
      test(
        'should clean "ca" and "cirka" from portions and ingredients',
        () async {
          // Arrange
          final testUrl = 'https://www.recept.se/recept/potatismos/';
          final receptHtml = ReceptTestFixtures.recipeWithReceptQuirks;

          servePage(testUrl, receptHtml);

          // Act
          final result = await urlStrategy.import(testUrl);

          // Assert - Recipe extracted with cleaned formatting
          expect(result.isSuccess, isTrue);

          // Assert - "ca" and "cirka" removed from portions
          expect(
            result.recipe!.portions,
            equals(4),
            reason:
                'Should clean "cirka" from portions ("cirka 4 portioner" → 4)',
          );

          // Assert - "ca" and "cirka" removed from ingredients
          expect(
            result.recipe!.ingredients,
            contains('800 g potatis'),
            reason: 'Should clean "ca " prefix from ingredient',
          );
          expect(
            result.recipe!.ingredients,
            contains('2 dl mjölk'),
            reason: 'Should clean "cirka " prefix from ingredient',
          );

          // Assert - Whitespace trimmed
          final ingredients = result.recipe!.ingredients;
          for (final ingredient in ingredients) {
            expect(
              ingredient,
              equals(ingredient.trim()),
              reason: 'Ingredient should not have leading/trailing whitespace',
            );
          }
        },
      );
    });
  });
}
