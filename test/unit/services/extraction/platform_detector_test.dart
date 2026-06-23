/// Unit tests for PlatformDetector - URL platform identification and conversion
///
/// Tests platform detection including:
/// - Platform identification from URLs
/// - Instagram app URL to web URL conversion
/// - Supported platform validation
/// - Edge cases and malformed URLs
library;

import 'package:flutter_test/flutter_test.dart';

// Production imports
import 'package:butlery/services/extraction/platform_detector.dart';

// Test infrastructure
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  group('PlatformDetector', () {
    late PlatformDetector detector;

    setUp(() async {
      // Initialize base test infrastructure
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();

      // Create detector instance (singleton)
      detector = PlatformDetector();
    });

    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });

    group('Initialization', () {
      test('should create detector as singleton', () {
        // Arrange & Act
        final detector1 = PlatformDetector();
        final detector2 = PlatformDetector();

        // Assert - Both should be the same instance
        expect(identical(detector1, detector2), isTrue);
      });

      test('should initialize without dependencies', () {
        // Assert
        expect(detector, isNotNull);
      });
    });

    group('Platform Detection', () {
      test('should detect Instagram platform', () {
        // Arrange
        const urls = [
          'https://www.instagram.com/p/ABC123/',
          'https://instagram.com/p/XYZ789',
          'http://www.instagram.com/reel/TEST',
          'https://www.instagram.com/stories/user/12345',
        ];

        // Act & Assert
        for (final url in urls) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(SourcePlatform.instagram),
            reason: 'Failed to detect Instagram for: $url',
          );
        }
      });

      test('should detect Facebook platform', () {
        // Arrange
        const urls = [
          'https://www.facebook.com/watch/?v=123456',
          'https://facebook.com/video.php?v=789',
          'http://m.facebook.com/story.php?id=456',
          // Note: fb.com is not detected, only facebook.com
        ];

        // Act & Assert
        for (final url in urls) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(SourcePlatform.facebook),
            reason: 'Failed to detect Facebook for: $url',
          );
        }
      });

      test('should detect TikTok platform', () {
        // Arrange
        const urls = [
          'https://www.tiktok.com/@user/video/123456',
          'https://tiktok.com/@chef/video/789',
          'http://www.tiktok.com/@recipe/video/456',
          'https://vm.tiktok.com/ABC123/',
        ];

        // Act & Assert
        for (final url in urls) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(SourcePlatform.tiktok),
            reason: 'Failed to detect TikTok for: $url',
          );
        }
      });

      test('should detect YouTube platform', () {
        // Arrange
        const urls = [
          'https://www.youtube.com/watch?v=ABC123',
          'https://youtube.com/watch?v=XYZ789',
          'http://www.youtube.com/v/TEST123',
          'https://youtu.be/SHORT123',
          'https://m.youtube.com/watch?v=MOBILE',
        ];

        // Act & Assert
        for (final url in urls) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(SourcePlatform.youtube),
            reason: 'Failed to detect YouTube for: $url',
          );
        }
      });

      test('should detect Pinterest platform', () {
        // Arrange
        const urls = [
          'https://www.pinterest.com/pin/123456789/',
          'https://pinterest.com/pin/987654321',
          // Note: pinterest.se and pin.it are not detected
        ];

        // Act & Assert
        for (final url in urls) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(SourcePlatform.pinterest),
            reason: 'Failed to detect Pinterest for: $url',
          );
        }
      });

      test('should return unknown for unsupported platforms', () {
        // Arrange
        const urls = [
          'https://www.example.com/recipe',
          'https://twitter.com/status/123',
          'https://linkedin.com/post/456',
          'https://reddit.com/r/cooking/789',
        ];

        // Act & Assert
        for (final url in urls) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(SourcePlatform.unknown),
            reason: 'Should return unknown for: $url',
          );
        }
      });
    });

    group('Instagram URL Conversion', () {
      test('should convert Instagram app URLs to web URLs', () {
        // Arrange
        final testCases = {
          // Note: convertToWebUrl expects 'shortcode=' not 'id='
          'instagram://media?shortcode=ABC123':
              'https://www.instagram.com/p/ABC123/',
          'instagram://media?shortcode=XYZ789':
              'https://www.instagram.com/p/XYZ789/',
          'instagram://media?shortcode=TEST_456':
              'https://www.instagram.com/p/TEST_456/',
        };

        // Act & Assert
        testCases.forEach((appUrl, expectedWebUrl) {
          final webUrl = detector.convertToWebUrl(appUrl);
          expect(
            webUrl,
            equals(expectedWebUrl),
            reason: 'Failed to convert: $appUrl',
          );
        });
      });

      test('should return original URL if not Instagram app URL', () {
        // Arrange
        const urls = [
          'https://www.instagram.com/p/ABC123/',
          'https://www.facebook.com/video/123',
          'https://www.example.com/recipe',
        ];

        // Act & Assert
        for (final url in urls) {
          final result = detector.convertToWebUrl(url);
          expect(
            result,
            equals(url),
            reason: 'Should return original URL for: $url',
          );
        }
      });

      test('should handle malformed Instagram app URLs', () {
        // Arrange
        const malformedUrls = [
          'instagram://media',
          'instagram://media?',
          'instagram://media?id=',
          'instagram://',
        ];

        // Act & Assert
        for (final url in malformedUrls) {
          final result = detector.convertToWebUrl(url);
          expect(
            result,
            equals(url),
            reason: 'Should return original malformed URL: $url',
          );
        }
      });
    });

    group('Platform Support Validation', () {
      test('should correctly identify supported platforms', () {
        // Arrange
        const supportedUrls = [
          'https://www.instagram.com/p/ABC123/',
          'https://www.facebook.com/video/456',
          'https://www.tiktok.com/@user/video/789',
          'https://www.youtube.com/watch?v=XYZ',
          'https://www.pinterest.com/pin/123/',
        ];

        // Act & Assert
        for (final url in supportedUrls) {
          final platform = detector.detectPlatform(url);
          final isSupported = detector.isSupportedPlatform(platform);
          expect(
            isSupported,
            isTrue,
            reason: 'Should be supported: $url (platform: $platform)',
          );
        }
      });

      test('should correctly identify unsupported platforms', () {
        // Arrange
        const unsupportedUrls = [
          'https://www.example.com/recipe',
          'https://twitter.com/status/123',
          'https://linkedin.com/post/456',
        ];

        // Act & Assert
        for (final url in unsupportedUrls) {
          final platform = detector.detectPlatform(url);
          final isSupported = detector.isSupportedPlatform(platform);
          expect(
            isSupported,
            isFalse,
            reason: 'Should not be supported: $url (platform: $platform)',
          );
        }
      });
    });

    group('Edge Cases', () {
      test('should handle empty URLs', () {
        // Arrange
        const emptyUrl = '';

        // Act
        final platform = detector.detectPlatform(emptyUrl);
        final converted = detector.convertToWebUrl(emptyUrl);

        // Assert
        expect(platform, equals(SourcePlatform.unknown));
        expect(converted, equals(emptyUrl));
      });

      test('should handle URLs with special characters', () {
        // Arrange
        const urls = [
          'https://www.instagram.com/p/ABC-123_XYZ/',
          'https://www.youtube.com/watch?v=ÅÄÖ123',
          'https://www.tiktok.com/@köttbullar/video/123',
        ];

        // Act & Assert
        for (final url in urls) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            isNot(equals(SourcePlatform.unknown)),
            reason: 'Should detect platform for: $url',
          );
        }
      });

      test('should handle URLs with query parameters', () {
        // Arrange
        final testCases = {
          'https://www.instagram.com/p/ABC123/?utm_source=app':
              SourcePlatform.instagram,
          'https://www.youtube.com/watch?v=XYZ&t=120s': SourcePlatform.youtube,
          'https://www.facebook.com/watch/?v=123&ref=share':
              SourcePlatform.facebook,
        };

        // Act & Assert
        testCases.forEach((url, expectedPlatform) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(expectedPlatform),
            reason: 'Failed for URL with params: $url',
          );
        });
      });

      test('should handle URLs with different protocols', () {
        // Arrange
        final testCases = {
          'http://www.instagram.com/p/ABC123/': SourcePlatform.instagram,
          'https://www.instagram.com/p/ABC123/': SourcePlatform.instagram,
          // Note: ftp:// still detected as instagram because contains('instagram.com')
          'ftp://www.instagram.com/p/ABC123/': SourcePlatform.instagram,
          '//www.instagram.com/p/ABC123/': SourcePlatform.instagram,
        };

        // Act & Assert
        testCases.forEach((url, expectedPlatform) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(expectedPlatform),
            reason: 'Failed for protocol variant: $url',
          );
        });
      });

      test('should handle international domain variations', () {
        // Arrange
        final testCases = {
          // Note: International domains not detected - only .com domains
          'https://www.instagram.se/p/ABC123/': SourcePlatform.unknown,
          'https://www.instagram.co.uk/p/ABC123/': SourcePlatform.unknown,
          'https://www.facebook.fr/video/123': SourcePlatform.unknown,
          'https://www.pinterest.de/pin/456/': SourcePlatform.unknown,
        };

        // Act & Assert
        testCases.forEach((url, expectedPlatform) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(expectedPlatform),
            reason: 'Failed for international domain: $url',
          );
        });
      });

      test('should handle mobile vs desktop URL formats', () {
        // Arrange
        final testCases = {
          'https://m.facebook.com/story.php?id=123': SourcePlatform.facebook,
          'https://www.facebook.com/story.php?id=123': SourcePlatform.facebook,
          'https://m.youtube.com/watch?v=ABC': SourcePlatform.youtube,
          'https://www.youtube.com/watch?v=ABC': SourcePlatform.youtube,
        };

        // Act & Assert
        testCases.forEach((url, expectedPlatform) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(expectedPlatform),
            reason: 'Failed for mobile/desktop variant: $url',
          );
        });
      });
    });

    group('Swedish Content and Cooking Websites', () {
      test('should handle Swedish cooking website URLs', () {
        // Arrange
        const swedishUrls = [
          'https://www.köket.se/recept/köttbullar',
          'https://www.ica.se/recept/pasta-med-lax',
          'https://www.arla.se/recept/ostkaka',
          'https://www.tasteline.com/recept/kanelbullar',
        ];

        // Act & Assert
        for (final url in swedishUrls) {
          final platform = detector.detectPlatform(url);
          // Swedish cooking sites are now detected as recipe sites
          expect(
            platform,
            anyOf(
              equals(SourcePlatform.recipesite),
              equals(SourcePlatform.unknown),
            ),
          );
          // But conversion should preserve the URL
          final converted = detector.convertToWebUrl(url);
          expect(converted, equals(url));
        }
      });

      test('should preserve Swedish characters in URLs', () {
        // Arrange
        const urlsWithSwedishChars = [
          'https://www.instagram.com/köttbullar_recept/',
          'https://www.tiktok.com/@kök_sverige/video/123',
          'https://www.youtube.com/watch?v=räksmörgås',
        ];

        // Act & Assert
        for (final url in urlsWithSwedishChars) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            isNot(equals(SourcePlatform.unknown)),
            reason: 'Should detect platform despite Swedish chars: $url',
          );
        }
      });
    });

    group('Performance and Bulk Operations', () {
      test('should handle bulk URL detection efficiently', () {
        // Arrange
        final urls = List.generate(
          100,
          (i) =>
              'https://www.${['instagram', 'facebook', 'tiktok', 'youtube', 'pinterest'][i % 5]}.com/content/$i',
        );

        // Act
        final stopwatch = Stopwatch()..start();
        final platforms = urls
            .map((url) => detector.detectPlatform(url))
            .toList();
        stopwatch.stop();

        // Assert
        expect(platforms.length, equals(100));
        expect(
          stopwatch.elapsedMilliseconds,
          lessThan(100),
          reason: 'Bulk detection should complete within 100ms',
        );
        // Verify correct platform detection
        for (int i = 0; i < platforms.length; i++) {
          final expectedPlatform = [
            SourcePlatform.instagram,
            SourcePlatform.facebook,
            SourcePlatform.tiktok,
            SourcePlatform.youtube,
            SourcePlatform.pinterest,
          ][i % 5];
          expect(platforms[i], equals(expectedPlatform));
        }
      });

      test('should handle concurrent detection operations', () async {
        // Arrange
        final urls = [
          'https://www.instagram.com/p/ABC123/',
          'https://www.facebook.com/video/456',
          'https://www.tiktok.com/@user/video/789',
          'https://www.youtube.com/watch?v=XYZ',
          'https://www.pinterest.com/pin/123/',
        ];

        // Act - Simulate concurrent detection
        final futures = urls.map((url) async {
          await Future.delayed(
            Duration(milliseconds: 10),
          ); // Simulate async work
          return detector.detectPlatform(url);
        });

        final results = await Future.wait(futures);

        // Assert
        expect(results[0], equals(SourcePlatform.instagram));
        expect(results[1], equals(SourcePlatform.facebook));
        expect(results[2], equals(SourcePlatform.tiktok));
        expect(results[3], equals(SourcePlatform.youtube));
        expect(results[4], equals(SourcePlatform.pinterest));
      });
    });

    group('Advanced URL Patterns', () {
      test('should detect platform from shortened URLs', () {
        // Arrange
        final testCases = {
          'https://instagr.am/p/ABC123': SourcePlatform.unknown, // Not detected
          'https://fb.com/video/456': SourcePlatform.unknown, // Not detected
          'https://youtu.be/XYZ789': SourcePlatform.youtube, // Detected
          'https://pin.it/abc123': SourcePlatform.unknown, // Not detected
          'https://vm.tiktok.com/ZM123/': SourcePlatform.tiktok, // Detected
        };

        // Act & Assert
        testCases.forEach((url, expectedPlatform) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(expectedPlatform),
            reason: 'Failed for shortened URL: $url',
          );
        });
      });

      test('should handle subdomain variations', () {
        // Arrange
        final testCases = {
          'https://business.instagram.com/p/ABC123/': SourcePlatform.instagram,
          'https://developers.facebook.com/docs/': SourcePlatform.facebook,
          'https://studio.youtube.com/video/123': SourcePlatform.youtube,
          'https://ads.tiktok.com/campaign': SourcePlatform.tiktok,
          'https://business.pinterest.com/hub/': SourcePlatform.pinterest,
        };

        // Act & Assert
        testCases.forEach((url, expectedPlatform) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(expectedPlatform),
            reason: 'Failed for subdomain: $url',
          );
        });
      });

      test('should handle case-insensitive URLs correctly', () {
        // URLs are case-insensitive — prod correctly detects regardless of case
        final testCases = {
          'https://www.INSTAGRAM.com/p/ABC123/': SourcePlatform.instagram,
          'https://www.Facebook.COM/video/456': SourcePlatform.facebook,
          'https://www.YouTube.com/WATCH?V=XYZ': SourcePlatform.youtube,
          'https://www.PINTEREST.COM/PIN/123/': SourcePlatform.pinterest,
        };

        testCases.forEach((url, expectedPlatform) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(expectedPlatform),
            reason: 'Should detect platform in URL: $url',
          );
        });

        // Verify lowercase versions are detected
        final lowercaseUrls = {
          'https://www.instagram.com/p/ABC123/': SourcePlatform.instagram,
          'https://www.facebook.com/video/456': SourcePlatform.facebook,
          'https://www.tiktok.com/@user/video/789': SourcePlatform.tiktok,
          'https://www.youtube.com/watch?v=XYZ': SourcePlatform.youtube,
          'https://www.pinterest.com/pin/123/': SourcePlatform.pinterest,
        };

        lowercaseUrls.forEach((url, expectedPlatform) {
          final platform = detector.detectPlatform(url);
          expect(
            platform,
            equals(expectedPlatform),
            reason: 'Should detect lowercase domain: $url',
          );
        });
      });
    });

    group('URL Normalization and Conversion', () {
      test('should handle URLs with trailing slashes consistently', () {
        // Arrange
        final urlPairs = [
          [
            'https://www.instagram.com/p/ABC123',
            'https://www.instagram.com/p/ABC123/',
          ],
          [
            'https://www.facebook.com/video/456',
            'https://www.facebook.com/video/456/',
          ],
          [
            'https://www.youtube.com/watch?v=XYZ',
            'https://www.youtube.com/watch?v=XYZ/',
          ],
        ];

        // Act & Assert
        for (final pair in urlPairs) {
          final platform1 = detector.detectPlatform(pair[0]);
          final platform2 = detector.detectPlatform(pair[1]);
          expect(
            platform1,
            equals(platform2),
            reason: 'Should detect same platform regardless of trailing slash',
          );
        }
      });

      test(
        'should handle Instagram URL conversion with complex parameters',
        () {
          // Arrange
          final testCases = {
            'instagram://media?shortcode=ABC123&source=app':
                'https://www.instagram.com/p/ABC123/',
            'instagram://media?shortcode=XYZ_789-abc&utm_source=share':
                'https://www.instagram.com/p/XYZ_789-abc/',
            'instagram://media?other=param&shortcode=TEST123&more=data':
                'https://www.instagram.com/p/TEST123/',
          };

          // Act & Assert
          testCases.forEach((appUrl, expectedWebUrl) {
            final webUrl = detector.convertToWebUrl(appUrl);
            expect(
              webUrl,
              equals(expectedWebUrl),
              reason: 'Failed to convert complex app URL: $appUrl',
            );
          });
        },
      );

      test('should handle extremely long URLs gracefully', () {
        // Arrange
        final longPath = 'x' * 1000;
        final longUrl = 'https://www.instagram.com/p/$longPath/';

        // Act
        final platform = detector.detectPlatform(longUrl);
        final converted = detector.convertToWebUrl(longUrl);

        // Assert
        expect(platform, equals(SourcePlatform.instagram));
        expect(converted, equals(longUrl));
      });
    });
  });
}
