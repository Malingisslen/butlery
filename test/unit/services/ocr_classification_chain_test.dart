/// BUT-1022: contract tests for the OCR provider-error classification +
/// photo-import error-message chain.
///
/// The user-visible Swedish error string depends on a metadata-string
/// contract between two private methods:
///   1. [OCRExtractionService._classifyProviderErrors] — maps a
///      `{provider → exception string}` map to one of
///      `{rate_limit, timeout, network, generic}`.
///   2. [PhotoImportViewModel._buildEnhancedErrorMessage] — reads the
///      classification from `OCRResult.metadata['failure_classification']`
///      and picks the matching Swedish string from [AppLocale].
///
/// A typo on either side silently regresses to the generic
/// `errorNoTextExtracted` copy. These tests cover both halves of the
/// contract directly via `@visibleForTesting` accessors, side-stepping the
/// heavy HTTP-mocking + singleton-replacement dance an end-to-end test
/// would require.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/ocr_extraction_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/viewmodels/photo_import_viewmodel.dart';

class _MockImportManager extends Mock implements ImportManager {}

OCRResult _failureWithClassification(
  String? classification, {
  Map<String, dynamic>? extra,
}) {
  return OCRResult.failure(
    method: 'user_recovery',
    error: 'test failure',
    metadata: {
      'failure_classification': ?classification,
      ...?extra,
    },
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // PhotoImportViewModel.<init> kicks off OCRUsageTracker.loadFromPersistence,
  // which calls SharedPreferences.getInstance — without a mock the platform
  // channel throws MissingPluginException after the test completes.
  setUpAll(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('OCRExtractionService.classifyProviderErrorsForTesting', () {
    test('empty error map → generic', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({}),
        equals('generic'),
      );
    });

    test('HTTP 429 → rate_limit', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'ocr_space': 'Exception: OCR.space HTTP error: 429',
        }),
        equals('rate_limit'),
      );
    });

    test('"rate limit" phrase → rate_limit', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'ocr_space': 'Exception: rate limit exceeded',
        }),
        equals('rate_limit'),
      );
    });

    test('"too many requests" → rate_limit', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'google_vision': 'Too many requests for this api key',
        }),
        equals('rate_limit'),
      );
    });

    test('"quota" phrase → rate_limit', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'google_vision': 'Quota exceeded for project',
        }),
        equals('rate_limit'),
      );
    });

    test('TimeoutException → timeout', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'ocr_space': 'TimeoutException after 30 seconds',
        }),
        equals('timeout'),
      );
    });

    test('"timed out" phrase → timeout', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'tesseract': 'Operation timed out',
        }),
        equals('timeout'),
      );
    });

    test('SocketException → network', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'ocr_space': 'SocketException: Failed host lookup',
        }),
        equals('network'),
      );
    });

    test('"failed host lookup" → network', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'google_vision': 'Failed host lookup: vision.googleapis.com',
        }),
        equals('network'),
      );
    });

    test('"connection refused" → network', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'tesseract': 'Connection refused',
        }),
        equals('network'),
      );
    });

    test('generic Exception falls through → generic', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'ocr_space': 'Exception: boom',
        }),
        equals('generic'),
      );
    });

    test(
      'rate_limit wins over timeout when both present (priority guarantee)',
      () {
        // Reason: user-facing remedy differs (wait-then-retry vs check-connection).
        expect(
          OCRExtractionService.classifyProviderErrorsForTesting({
            'ocr_space': 'Exception: rate limit hit',
            'google_vision': 'TimeoutException after 30s',
          }),
          equals('rate_limit'),
        );
      },
    );

    test('timeout wins over network when both present', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'ocr_space': 'TimeoutException',
          'google_vision': 'SocketException',
        }),
        equals('timeout'),
      );
    });

    test('case-insensitive matching', () {
      expect(
        OCRExtractionService.classifyProviderErrorsForTesting({
          'ocr_space': 'RATE LIMIT exceeded',
        }),
        equals('rate_limit'),
      );
    });
  });

  group('PhotoImportViewModel.buildEnhancedErrorMessageForTesting', () {
    late PhotoImportViewModel vm;
    late _MockImportManager mockImportManager;

    setUp(() {
      mockImportManager = _MockImportManager();
      vm = PhotoImportViewModel(importManager: mockImportManager);
    });

    tearDown(() {
      vm.dispose();
    });

    test('rate_limit classification → errorOcrRateLimit copy', () {
      final result = _failureWithClassification('rate_limit');
      final message = vm.buildEnhancedErrorMessageForTesting(result);

      expect(message, contains(AppLocale.current.errorOcrRateLimit));
    });

    test('timeout classification → errorOcrTimeout copy', () {
      final result = _failureWithClassification('timeout');
      final message = vm.buildEnhancedErrorMessageForTesting(result);

      expect(message, contains(AppLocale.current.errorOcrTimeout));
    });

    test(
      'network classification → errorOcrTimeout copy (intentionally shared)',
      () {
        // Reason: per current mapping, network failures use the same Swedish
        // "tjänsten tog för lång tid" copy as timeouts. This test pins that
        // explicit choice so a future split would surface here.
        final result = _failureWithClassification('network');
        final message = vm.buildEnhancedErrorMessageForTesting(result);

        expect(message, contains(AppLocale.current.errorOcrTimeout));
      },
    );

    test('generic classification → errorNoTextExtracted fallback', () {
      final result = _failureWithClassification('generic');
      final message = vm.buildEnhancedErrorMessageForTesting(result);

      expect(message, contains(AppLocale.current.errorNoTextExtracted));
    });

    test('missing classification key → errorNoTextExtracted fallback', () {
      // Defensive: if the metadata key is missing entirely (older OCR
      // result formats, future regressions), the message must still be
      // the user-safe fallback, not a null-deref.
      final result = _failureWithClassification(null);
      final message = vm.buildEnhancedErrorMessageForTesting(result);

      expect(message, contains(AppLocale.current.errorNoTextExtracted));
    });

    test(
      'all providers down (circuit-open) → errorOcrServicesUnavailable copy',
      () {
        // No classification — service-down state wins via circuit-breaker check.
        final result = _failureWithClassification(
          null,
          extra: {
            'circuit_breakers': {
              'ocr_space_state': 'open',
              'google_vision_state': 'open',
              'tesseract_state': 'open',
            },
          },
        );
        final message = vm.buildEnhancedErrorMessageForTesting(result);

        expect(
          message,
          contains(AppLocale.current.errorOcrServicesUnavailable),
        );
      },
    );

    test(
      'low quality score wins over classification (image-fix > retry-blindly)',
      () {
        // Reason: when the image itself is unreadable, the user should fix
        // the image, not blindly retry against a transient rate-limit.
        final result = _failureWithClassification(
          'rate_limit',
          extra: {
            'quality_assessment': 0.3, // < 0.6 threshold
          },
        );
        final message = vm.buildEnhancedErrorMessageForTesting(result);

        // Quality-low branch produces errorImageQualityTooLow(percent), so the
        // rate_limit copy must NOT appear.
        expect(message, isNot(contains(AppLocale.current.errorOcrRateLimit)));
      },
    );

    test('recommendations from metadata are appended', () {
      final result = _failureWithClassification(
        'rate_limit',
        extra: {
          'recommendations': [
            'Använd JPEG eller PNG',
            'Använd högre upplösning',
          ],
        },
      );
      final message = vm.buildEnhancedErrorMessageForTesting(result);

      expect(message, contains('Använd JPEG eller PNG'));
      expect(message, contains('Använd högre upplösning'));
    });
  });
}
