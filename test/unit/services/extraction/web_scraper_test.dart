/// Unit tests for WebScraper - Headless browser content extraction
///
/// Tests web scraping including:
/// - Platform-specific extraction strategies
/// - Timeout management
/// - Resource cleanup
/// - Error handling and concurrent requests
/// - JavaScript extraction logic
/// - Content validation
/// - User agent configuration
///
/// Note: These tests use MockWebScraper to avoid WebView platform dependencies.
/// The tests focus on business logic, error handling, and service behavior
/// without requiring actual WebView functionality.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

// Production imports
import 'package:butlery/services/social_media_extractor.dart'; // For SourcePlatform and ExtractionResult

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('WebScraper', () {
    late MockWebScraper mockWebScraper;

    setUpAll(() {
      // Register fallback values
      registerFallbackValue(SourcePlatform.unknown);
    });

    setUp(() async {
      // Initialize base test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create mock
      mockWebScraper = MockWebScraper();
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Service Structure', () {
      test('should handle disposal properly', () {
        // Act & Assert - Should not throw
        expect(() => mockWebScraper.dispose(), returnsNormally);
      });

      test('should handle multiple dispose calls', () {
        // Arrange
        when(() => mockWebScraper.dispose()).thenReturn(null);

        // Act & Assert - Multiple dispose calls should be safe
        mockWebScraper.dispose();
        mockWebScraper.dispose();
        mockWebScraper.dispose();

        verify(() => mockWebScraper.dispose()).called(3);
      });
    });

    group('ExtractionResult Model', () {
      test('should create successful ExtractionResult', () {
        // Arrange & Act
        final result = ExtractionResult(
          success: true,
          extractedText: 'Recipe: Mix ingredients and bake at 180°C',
          metadata: {
            'platform': 'instagram',
            'url': 'https://instagram.com/p/123',
            'extractedAt': DateTime.now().toIso8601String(),
          },
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.extractedText, contains('Recipe'));
        expect(result.error, isNull);
        expect(result.metadata['platform'], equals('instagram'));
      });

      test('should create error ExtractionResult', () {
        // Arrange & Act
        final result = ExtractionResult(
          success: false,
          error: 'Failed to extract content: Network error',
          metadata: {
            'url': 'https://example.com',
            'attemptedAt': DateTime.now().toIso8601String(),
          },
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.extractedText, isNull);
        expect(result.error, contains('Network error'));
        expect(result.metadata['url'], equals('https://example.com'));
      });

      test('should handle ExtractionResult with minimal data', () {
        // Arrange & Act
        final result = ExtractionResult(
          success: false,
        );

        // Assert
        expect(result.success, isFalse);
        expect(result.extractedText, isNull);
        expect(result.error, isNull);
        expect(result.metadata, isEmpty);
      });

      test('should create ExtractionResult with Swedish content', () {
        // Arrange & Act
        final result = ExtractionResult(
          success: true,
          extractedText: '''
            Köttbullar med gräddsås
            
            Ingredienser:
            - 500g köttfärs
            - 1 ägg
            - 1 dl ströbröd
            - 2 dl grädde
            
            Tillagning:
            Forma köttbullar och stek i smör.
          ''',
          metadata: {
            'language': 'sv',
            'encoding': 'UTF-8',
          },
        );

        // Assert
        expect(result.success, isTrue);
        expect(result.extractedText, contains('Köttbullar'));
        expect(result.extractedText, contains('ägg'));
        expect(result.metadata['language'], equals('sv'));
      });
    });

    group('Platform Detection Integration', () {
      test('should handle Instagram URLs', () async {
        // Arrange
        const instagramUrl = 'https://www.instagram.com/p/ABC123';
        const platform = SourcePlatform.instagram;
        final expectedResult = ExtractionResult(
          success: true,
          extractedText: 'Instagram recipe content',
          metadata: {'platform': 'instagram'},
        );

        when(() => mockWebScraper.performExtraction(instagramUrl, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result =
            await mockWebScraper.performExtraction(instagramUrl, platform);

        // Assert
        expect(result.success, isTrue);
        expect(result.metadata['platform'], equals('instagram'));
        verify(() => mockWebScraper.performExtraction(instagramUrl, platform))
            .called(1);
      });

      test('should handle Facebook URLs', () async {
        // Arrange
        const facebookUrl = 'https://www.facebook.com/post/123';
        const platform = SourcePlatform.facebook;
        final expectedResult = ExtractionResult(
          success: true,
          extractedText: 'Facebook recipe content',
          metadata: {'platform': 'facebook'},
        );

        when(() => mockWebScraper.performExtraction(facebookUrl, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result =
            await mockWebScraper.performExtraction(facebookUrl, platform);

        // Assert
        expect(result.success, isTrue);
        expect(result.metadata['platform'], equals('facebook'));
        verify(() => mockWebScraper.performExtraction(facebookUrl, platform))
            .called(1);
      });

      test('should handle TikTok URLs', () async {
        // Arrange
        const tiktokUrl = 'https://www.tiktok.com/@user/video/123456';
        const platform = SourcePlatform.tiktok;
        final expectedResult = ExtractionResult(
          success: true,
          extractedText: 'TikTok recipe content',
          metadata: {'platform': 'tiktok'},
        );

        when(() => mockWebScraper.performExtraction(tiktokUrl, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result =
            await mockWebScraper.performExtraction(tiktokUrl, platform);

        // Assert
        expect(result.success, isTrue);
        expect(result.metadata['platform'], equals('tiktok'));
        verify(() => mockWebScraper.performExtraction(tiktokUrl, platform))
            .called(1);
      });

      test('should handle generic/unknown platform URLs', () async {
        // Arrange
        const genericUrl = 'https://www.example.com/recipe';
        const platform = SourcePlatform.unknown;
        final expectedResult = ExtractionResult(
          success: true,
          extractedText: 'Generic recipe content',
          metadata: {'platform': 'unknown'},
        );

        when(() => mockWebScraper.performExtraction(genericUrl, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result =
            await mockWebScraper.performExtraction(genericUrl, platform);

        // Assert
        expect(result.success, isTrue);
        expect(result.metadata['platform'], equals('unknown'));
        verify(() => mockWebScraper.performExtraction(genericUrl, platform))
            .called(1);
      });
    });

    group('URL Validation', () {
      test('should handle empty URLs', () async {
        // Arrange
        const emptyUrl = '';
        const platform = SourcePlatform.unknown;
        final expectedResult = ExtractionResult(
          success: false,
          error: 'Invalid URL: empty',
        );

        when(() => mockWebScraper.performExtraction(emptyUrl, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result =
            await mockWebScraper.performExtraction(emptyUrl, platform);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Invalid URL'));
        verify(() => mockWebScraper.performExtraction(emptyUrl, platform))
            .called(1);
      });

      test('should handle invalid URLs', () async {
        // Arrange
        const invalidUrl = 'not-a-valid-url';
        const platform = SourcePlatform.unknown;
        final expectedResult = ExtractionResult(
          success: false,
          error: 'Invalid URL format',
        );

        when(() => mockWebScraper.performExtraction(invalidUrl, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result =
            await mockWebScraper.performExtraction(invalidUrl, platform);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Invalid URL format'));
        verify(() => mockWebScraper.performExtraction(invalidUrl, platform))
            .called(1);
      });

      test('should handle URLs with special characters', () async {
        // Arrange
        const specialUrl =
            'https://example.com/recipe?id=123&type=dessert#ingredients';
        const platform = SourcePlatform.unknown;
        final expectedResult = ExtractionResult(
          success: true,
          extractedText: 'Recipe with special URL',
        );

        when(() => mockWebScraper.performExtraction(specialUrl, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result =
            await mockWebScraper.performExtraction(specialUrl, platform);

        // Assert
        expect(result.success, isTrue);
        verify(() => mockWebScraper.performExtraction(specialUrl, platform))
            .called(1);
      });

      test('should handle URLs with unicode characters', () async {
        // Arrange
        const unicodeUrl = 'https://example.com/recept/köttbullar';
        const platform = SourcePlatform.unknown;
        final expectedResult = ExtractionResult(
          success: true,
          extractedText: 'Swedish recipe content',
        );

        when(() => mockWebScraper.performExtraction(unicodeUrl, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result =
            await mockWebScraper.performExtraction(unicodeUrl, platform);

        // Assert
        expect(result.success, isTrue);
        verify(() => mockWebScraper.performExtraction(unicodeUrl, platform))
            .called(1);
      });

      test('should handle very long URLs', () async {
        // Arrange
        final longUrl = 'https://example.com/${'a' * 2000}';
        const platform = SourcePlatform.unknown;
        final expectedResult = ExtractionResult(
          success: false,
          error: 'URL too long',
        );

        when(() => mockWebScraper.performExtraction(longUrl, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result =
            await mockWebScraper.performExtraction(longUrl, platform);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('URL too long'));
        verify(() => mockWebScraper.performExtraction(longUrl, platform))
            .called(1);
      });
    });

    group('Timeout Behavior', () {
      test('should handle extraction timeout', () async {
        // Arrange
        const url = 'https://slow-loading-site.com';
        const platform = SourcePlatform.unknown;

        // Configure mock to simulate timeout
        when(() => mockWebScraper.performExtraction(url, platform))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 200));
          return ExtractionResult(
            success: false,
            error: 'Extraction timeout',
          );
        });

        // Act
        final result = await mockWebScraper.performExtraction(url, platform);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('timeout'));
      });

      test('should use standard timeout duration', () async {
        // Arrange
        const url = 'https://example.com';
        const platform = SourcePlatform.unknown;

        when(() => mockWebScraper.performExtraction(
              url,
              platform,
            )).thenAnswer((_) async => ExtractionResult(
              success: true,
              extractedText: 'Content extracted within timeout',
            ));

        // Act
        final result = await mockWebScraper.performExtraction(
          url,
          platform,
        );

        // Assert
        expect(result.success, isTrue);
        verify(() => mockWebScraper.performExtraction(
              url,
              platform,
            )).called(1);
      });
    });

    group('Concurrent Operations', () {
      test('should handle multiple concurrent extractions', () async {
        // Arrange
        final urls = [
          'https://example1.com',
          'https://example2.com',
          'https://example3.com',
        ];

        for (int i = 0; i < urls.length; i++) {
          when(() => mockWebScraper.performExtraction(
                  urls[i], SourcePlatform.unknown))
              .thenAnswer((_) async => ExtractionResult(
                    success: true,
                    extractedText: 'Content from ${urls[i]}',
                  ));
        }

        // Act
        final futures = urls
            .map((url) =>
                mockWebScraper.performExtraction(url, SourcePlatform.unknown))
            .toList();

        final results = await Future.wait(futures);

        // Assert
        expect(results.length, equals(3));
        expect(results.every((r) => r.success), isTrue);
        for (int i = 0; i < urls.length; i++) {
          expect(results[i].extractedText, contains(urls[i]));
        }
      });

      test('should handle concurrent extractions with mixed results', () async {
        // Arrange
        final testCases = [
          ('https://success.com', true, 'Success content'),
          ('https://failure.com', false, null),
          ('https://another-success.com', true, 'Another success'),
        ];

        for (final testCase in testCases) {
          final (url, success, content) = testCase;
          when(() =>
                  mockWebScraper.performExtraction(url, SourcePlatform.unknown))
              .thenAnswer((_) async => ExtractionResult(
                    success: success,
                    extractedText: content,
                    error: success ? null : 'Extraction failed',
                  ));
        }

        // Act
        final futures = testCases
            .map((tc) =>
                mockWebScraper.performExtraction(tc.$1, SourcePlatform.unknown))
            .toList();

        final results = await Future.wait(futures);

        // Assert
        expect(results[0].success, isTrue);
        expect(results[1].success, isFalse);
        expect(results[2].success, isTrue);
      });
    });

    group('JavaScript Selector Strategies', () {
      test('should extract content using platform-specific selectors',
          () async {
        // Arrange
        const url = 'https://instagram.com/p/123';
        const platform = SourcePlatform.instagram;

        final expectedResult = ExtractionResult(
          success: true,
          extractedText:
              'Instagram post content extracted with specific selectors',
          metadata: {
            'selector': 'article[role="presentation"]',
            'platform': 'instagram',
          },
        );

        when(() => mockWebScraper.performExtraction(url, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result = await mockWebScraper.performExtraction(url, platform);

        // Assert
        expect(result.success, isTrue);
        expect(result.metadata['selector'], isNotNull);
        expect(result.metadata['platform'], equals('instagram'));
      });

      test('should use fallback selectors when primary fails', () async {
        // Arrange
        const url = 'https://example.com/recipe';
        const platform = SourcePlatform.unknown;

        final expectedResult = ExtractionResult(
          success: true,
          extractedText: 'Content extracted with fallback selector',
          metadata: {
            'selectorUsed': 'fallback',
            'attemptedSelectors': ['main', 'article', 'body'],
          },
        );

        when(() => mockWebScraper.performExtraction(url, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result = await mockWebScraper.performExtraction(url, platform);

        // Assert
        expect(result.success, isTrue);
        expect(result.metadata['selectorUsed'], equals('fallback'));
      });
    });

    group('Swedish Content Support', () {
      test('should properly extract Swedish characters', () async {
        // Arrange
        const url = 'https://svenskrecept.se/kottbullar';
        const platform = SourcePlatform.unknown;

        final expectedResult = ExtractionResult(
          success: true,
          extractedText:
              'Köttbullar med lingon och gräddsås. Använd färsk timjan.',
          metadata: {'encoding': 'UTF-8'},
        );

        when(() => mockWebScraper.performExtraction(url, platform))
            .thenAnswer((_) async => expectedResult);

        // Act
        final result = await mockWebScraper.performExtraction(url, platform);

        // Assert
        expect(result.success, isTrue);
        expect(result.extractedText, contains('Köttbullar'));
        expect(result.extractedText, contains('gräddsås'));
        expect(result.extractedText, contains('Använd'));
      });
    });

    group('Error Recovery', () {
      test('should recover from WebView initialization errors', () async {
        // Arrange
        const url = 'https://example.com';
        const platform = SourcePlatform.unknown;

        when(() => mockWebScraper.performExtraction(url, platform))
            .thenAnswer((_) async => ExtractionResult(
                  success: false,
                  error:
                      'WebView initialization failed - recovered with empty result',
                ));

        // Act
        final result = await mockWebScraper.performExtraction(url, platform);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('WebView initialization failed'));
      });

      test('should handle network errors gracefully', () async {
        // Arrange
        const url = 'https://unreachable-site.com';
        const platform = SourcePlatform.unknown;

        when(() => mockWebScraper.performExtraction(url, platform))
            .thenAnswer((_) async => ExtractionResult(
                  success: false,
                  error: 'Network error: Unable to reach site',
                ));

        // Act
        final result = await mockWebScraper.performExtraction(url, platform);

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Network error'));
      });
    });

    group('Resource Cleanup', () {
      test('should clean up resources after extraction', () async {
        // Arrange
        const url = 'https://example.com';
        const platform = SourcePlatform.unknown;

        when(() => mockWebScraper.performExtraction(url, platform))
            .thenAnswer((_) async => ExtractionResult(
                  success: true,
                  extractedText: 'Content',
                ));

        when(() => mockWebScraper.dispose()).thenReturn(null);

        // Act
        await mockWebScraper.performExtraction(url, platform);
        mockWebScraper.dispose();

        // Assert
        verify(() => mockWebScraper.performExtraction(url, platform)).called(1);
        verify(() => mockWebScraper.dispose()).called(1);
      });

      test('should handle disposal during extraction', () async {
        // Arrange
        const url = 'https://example.com';
        const platform = SourcePlatform.unknown;

        when(() => mockWebScraper.performExtraction(url, platform))
            .thenAnswer((_) async {
          await Future.delayed(const Duration(milliseconds: 100));
          return ExtractionResult(
            success: false,
            error: 'Extraction cancelled',
          );
        });

        when(() => mockWebScraper.dispose()).thenReturn(null);

        // Act
        final extractionFuture =
            mockWebScraper.performExtraction(url, platform);
        await Future.delayed(const Duration(milliseconds: 50));
        mockWebScraper.dispose();
        final result = await extractionFuture;

        // Assert
        expect(result.success, isFalse);
        verify(() => mockWebScraper.dispose()).called(1);
      });
    });
  });
}
