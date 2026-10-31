/// Unit tests for InputDetector — URL vs text detection and platform identification.
library;

import 'package:flutter_test/flutter_test.dart';
import '../../../test_support/base_unit_test.dart';
import 'package:butlery/services/import/input_detector.dart';

void main() {
  group('InputDetector', () {
    late InputDetector detector;

    setUp(() async {
      await BaseUnitTest.setupUnit();
      detector = InputDetector();
    });
    tearDown(() => BaseUnitTest.resetMocks());

    group('empty and text input', () {
      test('empty string returns text/unknown', () {
        final result = detector.detect('');
        expect(result.isText, isTrue);
        expect(result.platform, Platform.unknown);
      });

      test('whitespace returns text/unknown', () {
        final result = detector.detect('   ');
        expect(result.isText, isTrue);
        expect(result.platform, Platform.unknown);
      });

      test('plain text returns text/unknown', () {
        final result = detector.detect('just some recipe text');
        expect(result.isText, isTrue);
        expect(result.platform, Platform.unknown);
      });
    });

    group('YouTube detection', () {
      test('youtube.com URL detected', () {
        final result = detector.detect(
          'https://www.youtube.com/watch?v=abc123',
        );
        expect(result.isUrl, isTrue);
        expect(result.isYouTube, isTrue);
      });

      test('youtu.be short URL detected', () {
        final result = detector.detect('https://youtu.be/abc123');
        expect(result.isUrl, isTrue);
        expect(result.isYouTube, isTrue);
      });
    });

    group('TikTok detection', () {
      test('tiktok.com URL detected', () {
        final result = detector.detect(
          'https://www.tiktok.com/@user/video/123',
        );
        expect(result.isUrl, isTrue);
        expect(result.isTikTok, isTrue);
      });

      test('vm.tiktok.com short URL detected', () {
        final result = detector.detect('https://vm.tiktok.com/abc123');
        expect(result.isUrl, isTrue);
        expect(result.isTikTok, isTrue);
      });
    });

    group('Instagram detection', () {
      test('instagram.com URL detected', () {
        final result = detector.detect('https://www.instagram.com/p/abc123');
        expect(result.isUrl, isTrue);
        expect(result.isInstagram, isTrue);
      });
    });

    group('generic website', () {
      test('regular URL detected as website', () {
        final result = detector.detect('https://www.example.com/recipe/123');
        expect(result.isUrl, isTrue);
        expect(result.isWebsite, isTrue);
      });

      test('bare domain auto-prepends https', () {
        final result = detector.detect('example.com/recipe');
        expect(result.isUrl, isTrue);
        expect(result.isWebsite, isTrue);
      });
    });

    group('edge cases', () {
      test('text with spaces is not a URL', () {
        final result = detector.detect('not a valid url with spaces');
        expect(result.isText, isTrue);
      });

      test('result preserves input', () {
        final result = detector.detect('https://example.com');
        expect(result.input, 'https://example.com');
      });

      test('URL result has non-null uri', () {
        final result = detector.detect('https://example.com');
        expect(result.uri, isNotNull);
      });

      for (final amount in [
        '1.5 dl mjölk',
        '2.5dl mjöl',
        '0.5 tsk salt',
        '2.5dl',
      ]) {
        test('"$amount" is recipe text, not a link', () {
          expect(detector.detect(amount).isText, isTrue);
          expect(InputDetector.looksLikeDomain(amount), isFalse);
        });
      }

      test('a link without its scheme still counts, with path and query', () {
        expect(InputDetector.looksLikeDomain('ica.se/recept/x?y=1'), isTrue);
        expect(InputDetector.looksLikeDomain('vm.tiktok.com/ZM123/'), isTrue);
      });
    });
  });
}
