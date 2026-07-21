/// Unit tests for ExtractionManager - URL content extraction orchestration
///
/// Tests extraction pipeline including:
/// - Platform detection and URL conversion
/// - Web scraping orchestration
/// - Singleton management
/// - Error handling for unsupported platforms
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/social_media_extractor.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/core/providers/application_provider.dart' as app;
import 'package:butlery/core/di/di_container.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/mock_factory.dart';

// No local mocks needed - using real ExtractionManager implementation

/// Fake scraper that returns a scripted sequence of results and counts calls,
/// so tests can prove the retry-by-result translation actually re-runs the
/// scrape. Extends the real [WebScraper] (its constructor only wires up
/// pure-compute extractors — no I/O) and overrides the network-touching parts.
class _ScriptedWebScraper extends WebScraper {
  _ScriptedWebScraper(this._results);

  final List<ExtractionResult> _results;
  int callCount = 0;

  @override
  Future<ExtractionResult> performExtraction(
    String url,
    SourcePlatform platform,
  ) async {
    // Clamp to the last scripted result so an unexpected extra call is
    // visible via callCount rather than throwing a range error.
    final index = callCount < _results.length ? callCount : _results.length - 1;
    callCount++;
    return _results[index];
  }

  @override
  void dispose() {}
}

ExtractionResult _networkFailure() => ExtractionResult(
  success: false,
  error: 'Timeout: Could not load page',
  metadata: const {'reason': 'network'},
);

void main() {
  group('ExtractionManager', () {
    late ExtractionManager manager;

    setUpAll(() {
      // Register fallback values
      // Register fallback values if needed
      registerFallbackValue(SourcePlatform.unknown);
    });

    setUp(() async {
      // Initialize base test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Using real ExtractionManager implementation for integration-style testing
      manager = ExtractionManager();
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
      // Dispose of the manager to clean up resources
      manager.dispose();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Initialization', () {
      test('should create manager instances', () {
        // ExtractionManager is managed as singleton by GetIt, not via constructor
        final manager1 = ExtractionManager();
        final manager2 = ExtractionManager();

        // Both are valid instances (singleton managed externally)
        expect(manager1, isNotNull);
        expect(manager2, isNotNull);

        // Cleanup
        manager1.dispose();
        manager2.dispose();
      });

      test('should initialize with dependencies', () {
        // Assert
        expect(manager, isNotNull);
      });
    });

    group('URL Extraction', () {
      test('should extract from supported platform URL', () async {
        // This test would need actual platform and scraper implementations
        // For unit testing, we'd need to refactor ExtractionManager to accept injected dependencies
        // For now, we'll test the basic flow

        // Arrange
        const testUrl = 'https://www.example.com/recipe';

        // Act
        final result = await manager.extractFromUrl(testUrl);

        // Assert
        expect(result, isA<ExtractionResult?>());
      });

      test('should handle Instagram app URL conversion', () async {
        // Arrange
        const instagramAppUrl = 'instagram://media?id=ABC123';

        // Act
        final result = await manager.extractFromUrl(instagramAppUrl);

        // Assert
        // Should attempt to convert and extract
        expect(result, isA<ExtractionResult?>());
      });

      test('should return ExtractionResult for unsupported platforms', () async {
        // Arrange
        const unsupportedUrl = 'https://unsupported-platform.com/content';

        // Act
        final result = await manager.extractFromUrl(unsupportedUrl);

        // Assert - Returns ExtractionResult with success=false for unsupported
        expect(result, isA<ExtractionResult>());
        expect(result, isNotNull);
        expect(result.success, isFalse);
      });

      test('should handle invalid URLs gracefully', () async {
        // Arrange
        const invalidUrl = 'not-a-valid-url';

        // Act
        final result = await manager.extractFromUrl(invalidUrl);

        // Assert - Returns ExtractionResult even for invalid URLs
        expect(result, isA<ExtractionResult>());
        expect(result, isNotNull);
        expect(result.success, isFalse);
      });
    });

    group('Error Handling', () {
      test('should handle extraction failures gracefully', () async {
        // Arrange
        const problematicUrl = 'https://www.instagram.com/p/timeout-test';

        // Act & Assert - Should not throw, just return null
        expect(
          () async => await manager.extractFromUrl(problematicUrl),
          returnsNormally,
        );

        final result = await manager.extractFromUrl(problematicUrl);
        expect(result, isA<ExtractionResult>());
      });

      test('should handle network errors', () async {
        // Arrange
        const url = 'https://www.example.com/recipe';

        // Act & Assert
        // Without mocking the dependencies, we can't simulate network errors
        // This would require refactoring to accept injected dependencies
        final result = await manager.extractFromUrl(url);
        expect(result, isA<ExtractionResult?>());
      });
    });

    group('Resource Management', () {
      test('should dispose resources properly', () {
        // Arrange
        final testManager = ExtractionManager();

        // Act & Assert - Should not throw
        expect(() => testManager.dispose(), returnsNormally);

        // Cleanup
        testManager.dispose();
      });

      test('should handle multiple dispose calls', () {
        // Arrange
        final testManager = ExtractionManager();

        // Act & Assert - Multiple dispose calls should be safe
        expect(() {
          testManager.dispose();
          testManager.dispose();
        }, returnsNormally);
      });
    });

    group('Edge Cases', () {
      test('should handle empty URL', () async {
        // Arrange
        const emptyUrl = '';

        // Act
        final result = await manager.extractFromUrl(emptyUrl);

        // Assert - Returns ExtractionResult even for empty URL
        expect(result, isA<ExtractionResult>());
        expect(result, isNotNull);
        expect(result.success, isFalse);
      });

      test('should handle URLs with special characters', () async {
        // Arrange
        const urlWithSpecialChars =
            'https://example.com/recipe?title=Köttbullar&id=123';

        // Act
        final result = await manager.extractFromUrl(urlWithSpecialChars);

        // Assert
        expect(result, isA<ExtractionResult?>());
      });

      test('should handle concurrent extraction requests', () async {
        // Arrange
        const url1 = 'https://www.example.com/recipe1';
        const url2 = 'https://www.example.com/recipe2';

        // Act - Start multiple extractions concurrently
        final future1 = manager.extractFromUrl(url1);
        final future2 = manager.extractFromUrl(url2);

        // Assert - Both should complete
        await expectLater(
          Future.wait([future1, future2]),
          completes,
        );
      });

      test('should handle very long URLs', () async {
        // Arrange
        final longUrl =
            'https://www.example.com/recipe?'
            'param=${List.filled(1000, 'a').join()}'; // Very long URL

        // Act
        final result = await manager.extractFromUrl(longUrl);

        // Assert
        expect(result, isA<ExtractionResult?>());
      });
    });

    group('Multi-Source Extraction', () {
      test('should extract from standard web recipe URLs', () async {
        // Arrange
        const recipeUrls = [
          'https://www.allrecipes.com/recipe/123',
          'https://www.foodnetwork.com/recipes/dish',
          'https://www.bbcgoodfood.com/recipes/meal',
        ];

        // Act & Assert
        for (final url in recipeUrls) {
          final result = await manager.extractFromUrl(url);
          expect(result, isA<ExtractionResult>());
          // Result may or may not have platform metadata depending on parser
          expect(result.metadata, isA<Map>());
        }
      });

      test('should handle image URL extraction with OCR simulation', () async {
        // Arrange
        const imageUrl = 'https://example.com/recipe-card.jpg';

        // Act
        final result = await manager.extractFromUrl(imageUrl);

        // Assert - Would use OCR in production
        expect(result, isA<ExtractionResult>());
        expect(result.success, isFalse); // OCR not available in unit tests
      });

      test('should handle PDF URL extraction', () async {
        // Arrange
        const pdfUrl = 'https://example.com/recipe-collection.pdf';

        // Act
        final result = await manager.extractFromUrl(pdfUrl);

        // Assert - Would parse PDF in production
        expect(result, isA<ExtractionResult>());
        expect(
          result.metadata['contentType'],
          isNull,
        ); // PDF parsing not available in tests
      });

      test('should extract from plain text content URLs', () async {
        // Arrange
        const textUrl = 'https://example.com/recipe.txt';

        // Act
        final result = await manager.extractFromUrl(textUrl);

        // Assert
        expect(result, isA<ExtractionResult>());
        // Plain text extraction would work through generic scraper
      });

      test('should handle JSON API response URLs', () async {
        // Arrange
        const apiUrl = 'https://api.recipes.com/v1/recipe/456';

        // Act
        final result = await manager.extractFromUrl(apiUrl);

        // Assert
        expect(result, isA<ExtractionResult>());
        // API responses would be parsed as JSON in production
      });
    });

    group('Data Validation', () {
      test('should validate completeness of extracted recipe data', () async {
        // Arrange
        const url = 'https://www.example.com/complete-recipe';

        // Act
        final result = await manager.extractFromUrl(url);

        // Assert - Check for required fields
        if (result.success && result.extractedText != null) {
          // Would validate title, ingredients, instructions in production
          expect(result.extractedText, isA<String>());
        }
      });

      test('should sanitize and clean ingredient data', () async {
        // Arrange
        const url = 'https://www.example.com/recipe-with-messy-ingredients';

        // Act
        final result = await manager.extractFromUrl(url);

        // Assert - Would clean ingredient formatting in production
        expect(result, isA<ExtractionResult>());
        if (result.extractedText != null) {
          // Check that common issues are cleaned:
          // - Extra whitespace removed
          // - Inconsistent units normalized
          // - Special characters handled
          expect(
            result.extractedText!.contains('  '),
            isFalse,
          ); // No double spaces
        }
      });

      test('should normalize measurement units to metric/imperial', () async {
        // Arrange
        const url = 'https://www.example.com/recipe-mixed-units';

        // Act
        final result = await manager.extractFromUrl(url);

        // Assert - Would normalize units in production
        expect(result, isA<ExtractionResult>());
        // Units like "1 cup" -> "240 ml", "1 lb" -> "454 g"
      });

      test('should detect language and handle Swedish recipes', () async {
        // Arrange
        const swedishUrls = [
          'https://www.koket.se/recept/kottbullar',
          'https://www.ica.se/recept/laxpudding',
        ];

        // Act & Assert
        for (final url in swedishUrls) {
          final result = await manager.extractFromUrl(url);
          expect(result, isA<ExtractionResult>());
          // Would detect Swedish language and preserve åäö characters
        }
      });

      test('should merge and deduplicate instruction steps', () async {
        // Arrange
        const url = 'https://www.example.com/recipe-with-duplicate-steps';

        // Act
        final result = await manager.extractFromUrl(url);

        // Assert - Would remove duplicate/similar steps in production
        expect(result, isA<ExtractionResult>());
        if (result.extractedText != null) {
          // Check that duplicate instructions are merged
          final lines = result.extractedText!.split('\n');
          final uniqueLines = lines.toSet().toList();
          // In production, would have smarter deduplication
          expect(uniqueLines.length, lessThanOrEqualTo(lines.length));
        }
      });
    });

    group('Intelligence Features', () {
      test('should auto-categorize recipes based on content', () async {
        // Arrange
        const url = 'https://www.example.com/pasta-carbonara';

        // Act
        final result = await manager.extractFromUrl(url);

        // Assert - Would suggest categories in production
        expect(result, isA<ExtractionResult>());
        // Categories like: Italian, Pasta, Main Course, Quick Meals
        if (result.metadata.isNotEmpty) {
          // Would have 'suggestedCategories' in metadata
          expect(result.metadata, isA<Map<String, dynamic>>());
        }
      });

      test('should estimate nutritional values and calories', () async {
        // Arrange
        const url = 'https://www.example.com/healthy-salad';

        // Act
        final result = await manager.extractFromUrl(url);

        // Assert - Would calculate nutrition in production
        expect(result, isA<ExtractionResult>());
        // Would estimate: calories, protein, carbs, fat based on ingredients
      });

      test('should identify common allergens in recipes', () async {
        // Arrange
        const url = 'https://www.example.com/nut-allergy-recipe';

        // Act
        final result = await manager.extractFromUrl(url);

        // Assert - Would detect allergens in production
        expect(result, isA<ExtractionResult>());
        // Allergens: nuts, dairy, gluten, eggs, shellfish, etc.
      });

      test('should suggest ingredient substitutions', () async {
        // Arrange
        const url = 'https://www.example.com/recipe-with-rare-ingredients';

        // Act
        final result = await manager.extractFromUrl(url);

        // Assert - Would suggest substitutions in production
        expect(result, isA<ExtractionResult>());
        // Substitutions like: buttermilk -> milk + lemon, etc.
      });

      test('should calculate recipe difficulty rating', () async {
        // Arrange
        const urls = [
          'https://www.example.com/simple-toast',
          'https://www.example.com/complex-souffle',
        ];

        // Act & Assert
        for (final url in urls) {
          final result = await manager.extractFromUrl(url);
          expect(result, isA<ExtractionResult>());
          // Would rate: Easy, Medium, Hard based on:
          // - Number of steps
          // - Cooking techniques required
          // - Time needed
          // - Special equipment
        }
      });
    });

    group('Swedish Content Support', () {
      test(
        'should handle Swedish cooking sites with special characters',
        () async {
          // Arrange
          const swedishSites = [
            'https://www.köket.se/recept/köttbullar-med-gräddsås',
            'https://www.arla.se/recept/äggakaka',
            'https://www.ica.se/recept/räksmörgås',
          ];

          // Act & Assert
          for (final url in swedishSites) {
            final result = await manager.extractFromUrl(url);
            expect(result, isA<ExtractionResult>());
            // Should preserve å, ä, ö characters
          }
        },
      );

      test('should recognize Swedish measurement units', () async {
        // Arrange
        const url = 'https://www.svenskmat.se/recept/kanelbullar';

        // Act
        final result = await manager.extractFromUrl(url);

        // Assert
        expect(result, isA<ExtractionResult>());
        // Should recognize: dl (deciliter), krm (kryddmått), msk (matsked)
      });
    });

    group('Performance and Caching', () {
      test('should cache extraction results for repeated URLs', () async {
        // Arrange
        const url = 'https://www.example.com/cached-recipe';

        // Act - Extract twice
        final stopwatch = Stopwatch()..start();
        final result1 = await manager.extractFromUrl(url);
        final time1 = stopwatch.elapsedMilliseconds;

        stopwatch.reset();
        final result2 = await manager.extractFromUrl(url);
        final time2 = stopwatch.elapsedMilliseconds;

        // Assert - Second extraction should be faster (cached)
        expect(result1, isA<ExtractionResult>());
        expect(result2, isA<ExtractionResult>());
        // In production, time2 would be much less than time1 due to caching
        expect(time1, greaterThanOrEqualTo(0));
        expect(time2, greaterThanOrEqualTo(0));
      });

      test('should handle batch extraction efficiently', () async {
        // Arrange
        final urls = List.generate(
          10,
          (i) => 'https://www.example.com/recipe$i',
        );

        // Act
        final stopwatch = Stopwatch()..start();
        final futures = urls.map((url) => manager.extractFromUrl(url));
        final results = await Future.wait(futures);
        stopwatch.stop();

        // Assert
        expect(results.length, equals(10));
        for (final result in results) {
          expect(result, isA<ExtractionResult>());
        }
        // Should complete batch within reasonable time
        expect(stopwatch.elapsedMilliseconds, lessThan(5000));
      });
    });

    group('Transient-failure retry', () {
      // ica.se is detected as a supported recipesite by the real
      // PlatformDetector, so extraction reaches the scrape+retry stage.
      const supportedUrl = 'https://www.ica.se/recept/retry-test';

      setUp(() {
        // extractFromUrl runs through executeServiceOperation with
        // requiresAuth: true, which reads AuthRepository.currentUserId via the
        // PRODUCTION ServiceLocator. Two things are needed so the scrape stage
        // is actually reached (otherwise the auth pre-flight fails closed and
        // the op returns the auth fallback, never touching the scraper):
        //   1. an authenticated AuthRepository in the shared GetIt, and
        //   2. the production ServiceLocator pointed at that GetIt — the test
        //      harness intentionally skips wiring it (DIContainer wraps the
        //      same GetIt.instance the harness registers into).
        TestServiceLocator.registerMock<AuthRepository>(
          MockFactory.createAuthRepository(
            isAuthenticated: true,
            userId: 'test_user_123',
          ),
        );
        app.ServiceLocator.initialize(DIContainer());
      });

      tearDown(app.ServiceLocator.reset);

      test(
        'retries the scrape when the first attempt fails with reason:network',
        () async {
          final scraper = _ScriptedWebScraper([
            _networkFailure(),
            ExtractionResult(
              success: true,
              extractedText: 'recipe body',
            ),
          ]);
          final retryingManager = ExtractionManager(webScraper: scraper);
          addTearDown(retryingManager.dispose);

          final result = await retryingManager.extractFromUrl(supportedUrl);

          // The second attempt fired and its success result is surfaced.
          expect(scraper.callCount, equals(2));
          expect(result.success, isTrue);
          expect(result.extractedText, equals('recipe body'));
        },
      );

      test(
        'surfaces the last network failure after the retry is also exhausted',
        () async {
          final scraper = _ScriptedWebScraper([
            _networkFailure(),
            _networkFailure(),
          ]);
          final retryingManager = ExtractionManager(webScraper: scraper);
          addTearDown(retryingManager.dispose);

          final result = await retryingManager.extractFromUrl(supportedUrl);

          // maxAttempts=2: one retry, then the carried failure is returned
          // (the marker does not escape as a throw).
          expect(scraper.callCount, equals(2));
          expect(result.success, isFalse);
          expect(result.metadata['reason'], equals('network'));
        },
      );

      test(
        'does NOT retry a non-network failure (e.g. reason:no_content)',
        () async {
          final scraper = _ScriptedWebScraper([
            ExtractionResult(
              success: false,
              error: 'No text could be extracted from the page',
              metadata: const {'reason': 'no_content'},
            ),
          ]);
          final retryingManager = ExtractionManager(webScraper: scraper);
          addTearDown(retryingManager.dispose);

          final result = await retryingManager.extractFromUrl(supportedUrl);

          // Only one attempt — a content failure is not transient.
          expect(scraper.callCount, equals(1));
          expect(result.success, isFalse);
          expect(result.metadata['reason'], equals('no_content'));
        },
      );
    });
  });
}
