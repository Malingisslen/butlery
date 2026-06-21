import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/social_media_extractor.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

// Fake ExtractionManager whose extractFromUrl is controlled by the test.
// Subclasses the concrete class so BaseService's serviceName / onDispose are
// already satisfied — no @override body on a Mock (which would silently block
// when() stubs per the DO-NOT-WRITE patterns).
class _FakeExtractionManager extends ExtractionManager {
  final ExtractionResult Function(String url) _handler;

  _FakeExtractionManager(this._handler);

  @override
  Future<ExtractionResult> extractFromUrl(String url) async => _handler(url);
}

// ExtractionManager that throws unconditionally — drives the null-coalescing
// fallback inside SocialMediaExtractor.extractFromUrl.
class _ThrowingExtractionManager extends ExtractionManager {
  @override
  Future<ExtractionResult> extractFromUrl(String url) =>
      throw Exception('network timeout');
}

void main() {
  late SocialMediaExtractor service;

  setUpAll(() async {
    // Initialize base test infrastructure for consistency
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    service = SocialMediaExtractor();
  });

  tearDown(() async {
    await service.dispose();
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('SocialMediaExtractor', () {
    group('Initialization', () {
      test('should create service instance', () {
        expect(service, isA<SocialMediaExtractor>());
      });

      test('should create independent instances', () {
        final instance1 = SocialMediaExtractor();
        final instance2 = SocialMediaExtractor();

        // Should create independent instances (no singleton pattern)
        expect(identical(instance1, instance2), isFalse);
      });

      test('should have extraction manager initialized', () {
        // Service creates ExtractionManager internally
        expect(service, isNotNull);
      });
    });

    group('extractFromUrl', () {
      test('should extract from Instagram URL', () async {
        final result =
            await service.extractFromUrl('https://instagram.com/p/recipe123');

        // Result will be actual extraction result from manager
        expect(result, isA<ExtractionResult>());
      });

      test('should extract from Facebook URL', () async {
        final result = await service
            .extractFromUrl('https://facebook.com/video/cooking123');

        expect(result, isA<ExtractionResult>());
      });

      test('should extract from TikTok URL', () async {
        final result =
            await service.extractFromUrl('https://tiktok.com/@chef/video/123');

        expect(result, isA<ExtractionResult>());
      });

      test('should extract from YouTube URL', () async {
        final result = await service
            .extractFromUrl('https://youtube.com/watch?v=cooking123');

        expect(result, isA<ExtractionResult>());
      });

      test('should extract from Pinterest URL', () async {
        final result =
            await service.extractFromUrl('https://pinterest.com/pin/recipe123');

        expect(result, isA<ExtractionResult>());
      });

      test('should extract from cooking website', () async {
        final result =
            await service.extractFromUrl('https://allrecipes.com/recipe/123');

        expect(result, isA<ExtractionResult>());
      });

      test('should handle invalid URL', () async {
        final result = await service.extractFromUrl('not-a-valid-url');

        expect(result, isA<ExtractionResult>());
      });

      test('should handle empty URL', () async {
        final result = await service.extractFromUrl('');

        expect(result, isA<ExtractionResult>());
      });

      test('should handle null-like URL strings', () async {
        final result = await service.extractFromUrl('null');

        expect(result, isA<ExtractionResult>());
      });

      test('should not throw on extraction errors', () async {
        await expectLater(
          service.extractFromUrl('https://example.com/error'),
          completes,
        );
      });
    });

    group('ExtractionResult', () {
      test('should create successful result', () {
        final result = ExtractionResult(
          success: true,
          extractedText: 'Recipe content',
          metadata: {'platform': 'instagram'},
        );

        expect(result.success, isTrue);
        expect(result.extractedText, equals('Recipe content'));
        expect(result.error, isNull);
        expect(result.metadata['platform'], equals('instagram'));
      });

      test('should create failed result', () {
        final result = ExtractionResult(
          success: false,
          error: 'Failed to extract',
          metadata: {'platform': 'unknown'},
        );

        expect(result.success, isFalse);
        expect(result.extractedText, isNull);
        expect(result.error, equals('Failed to extract'));
        expect(result.metadata['platform'], equals('unknown'));
      });

      test('should handle empty metadata', () {
        final result = ExtractionResult(
          success: true,
          extractedText: 'Content',
        );

        expect(result.metadata, isEmpty);
      });

      test('should handle null extracted text', () {
        final result = ExtractionResult(
          success: false,
          error: 'No content found',
        );

        expect(result.extractedText, isNull);
      });

      test('should handle null error message', () {
        final result = ExtractionResult(
          success: true,
          extractedText: 'Content',
        );

        expect(result.error, isNull);
      });
    });

    group('URL Variations', () {
      test('should handle Instagram post URL', () async {
        final result =
            await service.extractFromUrl('https://www.instagram.com/p/ABC123/');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle Instagram reel URL', () async {
        final result = await service
            .extractFromUrl('https://www.instagram.com/reel/ABC123/');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle Facebook mobile URL', () async {
        final result = await service
            .extractFromUrl('https://m.facebook.com/video.php?v=123');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle YouTube short URL', () async {
        final result = await service.extractFromUrl('https://youtu.be/ABC123');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle TikTok mobile URL', () async {
        final result =
            await service.extractFromUrl('https://m.tiktok.com/v/123.html');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle URL with query parameters', () async {
        final result = await service
            .extractFromUrl('https://example.com/recipe?id=123&lang=en');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle URL with hash fragment', () async {
        final result = await service
            .extractFromUrl('https://example.com/recipe#ingredients');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle URL with special characters', () async {
        final result =
            await service.extractFromUrl('https://example.com/recipe/äöü');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle very long URL', () async {
        final longPath = 'a' * 1000;
        final longUrl = 'https://example.com/$longPath';
        final result = await service.extractFromUrl(longUrl);
        expect(result, isA<ExtractionResult>());
      });
    });

    group('Error Scenarios', () {
      test('should handle network timeout', () async {
        final result =
            await service.extractFromUrl('https://timeout.example.com');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle 404 not found', () async {
        final result = await service.extractFromUrl('https://example.com/404');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle unsupported platform', () async {
        final result =
            await service.extractFromUrl('https://unsupported-platform.com');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle malformed URL', () async {
        final result = await service.extractFromUrl('htp://missing-t.com');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle URL without protocol', () async {
        final result = await service.extractFromUrl('example.com/recipe');
        expect(result, isA<ExtractionResult>());
      });
    });

    group('Concurrent Operations', () {
      test('should handle concurrent extractions', () async {
        final future1 = service.extractFromUrl('https://instagram.com/p/1');
        final future2 = service.extractFromUrl('https://facebook.com/v/2');
        final future3 = service.extractFromUrl('https://tiktok.com/v/3');

        final results = await Future.wait([future1, future2, future3]);

        expect(results, hasLength(3));
        expect(results[0], isA<ExtractionResult>());
        expect(results[1], isA<ExtractionResult>());
        expect(results[2], isA<ExtractionResult>());
      });

      test('should handle rapid sequential extractions', () async {
        final results = <ExtractionResult>[];

        for (int i = 0; i < 5; i++) {
          final result = await service.extractFromUrl('https://example.com/$i');
          results.add(result);
        }

        expect(results, hasLength(5));
        for (final result in results) {
          expect(result, isA<ExtractionResult>());
        }
      });
    });

    group('dispose', () {
      test('should not throw when disposing', () async {
        await expectLater(service.dispose(), completes);
      });

      test('should handle multiple dispose calls', () async {
        await service.dispose();
        await expectLater(service.dispose(), completes);
      });

      test('should work after extraction', () async {
        await service.extractFromUrl('https://example.com');
        await expectLater(service.dispose(), completes);
      });
    });

    group('Edge Cases', () {
      test('should handle whitespace in URL', () async {
        final result =
            await service.extractFromUrl('  https://example.com/recipe  ');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle URL with newlines', () async {
        final result =
            await service.extractFromUrl('https://example.com\n/recipe');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle localhost URL', () async {
        final result =
            await service.extractFromUrl('http://localhost:3000/recipe');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle IP address URL', () async {
        final result =
            await service.extractFromUrl('http://192.168.1.1/recipe');
        expect(result, isA<ExtractionResult>());
      });

      test('should handle file:// protocol', () async {
        final result = await service.extractFromUrl('file:///C:/recipe.html');
        expect(result, isA<ExtractionResult>());
      });
    });

    // BUT-1336 — Criterion 2: failure-path carries success==false + non-null error.
    // The existing tests above only assert isA<ExtractionResult>; they never check
    // the failure contract that receive_share_view depends on.
    group('extractFromUrl failure path (BUT-1336)', () {
      // Intent: extractFromUrl returns success==false and a non-null error string
      // when the ExtractionManager itself reports failure. Would fail if the facade
      // forwarded success:true from the manager or dropped the error field.
      test(
          'forwards success==false and non-null error from a failing ExtractionManager',
          () async {
        const errorMessage =
            'Unknown platform for URL: https://unsupported.example.com';
        final extractor = SocialMediaExtractor(
          manager: _FakeExtractionManager(
            (_) => ExtractionResult(
              success: false,
              error: errorMessage,
            ),
          ),
        );
        addTearDown(extractor.dispose);

        final result =
            await extractor.extractFromUrl('https://unsupported.example.com');

        expect(result.success, isFalse,
            reason:
                'A manager-reported failure must propagate as success==false');
        expect(result.error, isNotNull,
            reason:
                'The error string must not be dropped — receive_share_view reads result.error');
        expect(result.error, contains('Unknown platform'),
            reason: 'The exact error text from the manager must be forwarded');
      });

      // Intent: when the ExtractionManager throws (e.g. network timeout), extractFromUrl
      // still returns a structured failure — success==false, non-null error — rather than
      // propagating the exception. Would fail if the null-coalescing fallback were removed
      // or the fallback were changed to success:true.
      test(
          'returns success==false with non-null error when ExtractionManager throws',
          () async {
        final extractor = SocialMediaExtractor(
          manager: _ThrowingExtractionManager(),
        );
        addTearDown(extractor.dispose);

        final result =
            await extractor.extractFromUrl('https://instagram.com/p/ABC123');

        expect(result.success, isFalse,
            reason:
                'An unexpected exception inside the manager must not propagate as success');
        expect(result.error, isNotNull,
            reason:
                'The fallback path must populate error so receive_share_view can display it');
      });

      // Intent: documents the metadata['reason'] gap — receive_share_view reads
      // result.metadata['reason'] as String? for analytics, but ExtractionResult
      // never populates that key. This test characterizes the current (broken) contract
      // so a future fix can flip the assertion. See BUT-1336 follow-up.
      //
      // CHARACTERIZATION TEST — flip when fixed:
      //   expect(result.metadata['reason'], isNotNull);
      test(
          'CHARACTERIZATION: metadata does not contain a reason key (BUT-1336 gap — receive_share_view reads it)',
          () async {
        const errorMessage = 'Platform not supported';
        final extractor = SocialMediaExtractor(
          manager: _FakeExtractionManager(
            (_) => ExtractionResult(
              success: false,
              error: errorMessage,
            ),
          ),
        );
        addTearDown(extractor.dispose);

        final result =
            await extractor.extractFromUrl('https://unsupported.example.com');

        // receive_share_view does:
        //   result.metadata['reason'] as String?
        // This is always null because ExtractionResult never populates 'reason'.
        // When fixed (i.e. ExtractionResult or ExtractionManager populates
        // metadata['reason']), flip this to `isNotNull`.
        expect(
          result.metadata['reason'],
          isNull,
          reason:
              'BUT-1336: metadata[reason] is never written; receive_share_view always '
              'passes null to logExtractionError. Fix: populate metadata[reason] in '
              'ExtractionResult or ExtractionManager and flip this assertion.',
        );
      });
    });
  });
}
