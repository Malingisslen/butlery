/// BUT-1023: unit coverage for [StorageUploadException] helper getters.
///
/// These getters drive the upload-service classifier's mapping to
/// `ImageUploadErrorType`, which in turn drives the localized Swedish
/// error copy. A regression in any classifier branch silently degrades
/// "your photo storage is full" to a generic "unknown error."
library;

import 'package:butlery/core/exceptions/storage_upload_exception.dart';
import 'package:test/test.dart';

void main() {
  group('StorageUploadException', () {
    group('constructor', () {
      test('exposes code and message verbatim', () {
        const e = StorageUploadException('quota-exceeded', 'Storage full');
        expect(e.code, equals('quota-exceeded'));
        expect(e.message, equals('Storage full'));
      });

      test('toString includes both code and message', () {
        const e = StorageUploadException('unauthorized', 'No permission');
        expect(e.toString(),
            equals('StorageUploadException(unauthorized): No permission'));
      });
    });

    group('isQuotaExceeded', () {
      test('true for quota-exceeded', () {
        expect(
            const StorageUploadException('quota-exceeded', '').isQuotaExceeded,
            isTrue);
      });

      test('false for any other code', () {
        for (final code in [
          'unauthorized',
          'canceled',
          'cancelled',
          'unauthenticated',
          'network-request-failed',
          'unknown',
          '',
        ]) {
          expect(
            StorageUploadException(code, '').isQuotaExceeded,
            isFalse,
            reason: 'code "$code" should not be classified as quota',
          );
        }
      });
    });

    group('isUnauthorized', () {
      test('true for unauthorized', () {
        expect(const StorageUploadException('unauthorized', '').isUnauthorized,
            isTrue);
      });

      test('true for unauthenticated (covers auth-gap surface)', () {
        expect(
            const StorageUploadException('unauthenticated', '').isUnauthorized,
            isTrue);
      });

      test('false for unrelated codes', () {
        for (final code in [
          'quota-exceeded',
          'canceled',
          'permission-denied',
          'forbidden',
          '',
        ]) {
          expect(
            StorageUploadException(code, '').isUnauthorized,
            isFalse,
            reason: 'code "$code" should not be classified as unauthorized',
          );
        }
      });
    });

    group('isCanceled', () {
      test('true for canceled (US spelling)', () {
        expect(const StorageUploadException('canceled', '').isCanceled, isTrue);
      });

      test('true for cancelled (UK spelling — defensive)', () {
        expect(
            const StorageUploadException('cancelled', '').isCanceled, isTrue);
      });

      test('false for unrelated codes', () {
        for (final code in [
          'quota-exceeded',
          'unauthorized',
          'aborted',
          'timeout',
          '',
        ]) {
          expect(
            StorageUploadException(code, '').isCanceled,
            isFalse,
            reason: 'code "$code" should not be classified as canceled',
          );
        }
      });
    });

    group('isNetworkError', () {
      test('true for retry-limit-exceeded', () {
        expect(
            const StorageUploadException('retry-limit-exceeded', '')
                .isNetworkError,
            isTrue);
      });

      test('true for server-file-wrong-size', () {
        expect(
            const StorageUploadException('server-file-wrong-size', '')
                .isNetworkError,
            isTrue);
      });

      test('true for network-request-failed', () {
        expect(
            const StorageUploadException('network-request-failed', '')
                .isNetworkError,
            isTrue);
      });

      test('false for non-network codes', () {
        for (final code in [
          'quota-exceeded',
          'unauthorized',
          'canceled',
          'unknown',
          '',
        ]) {
          expect(
            StorageUploadException(code, '').isNetworkError,
            isFalse,
            reason: 'code "$code" should not be classified as network',
          );
        }
      });
    });

    group('classification mutual exclusivity', () {
      test('quota-exceeded matches exactly one bucket', () {
        const e = StorageUploadException('quota-exceeded', '');
        expect(
          [e.isQuotaExceeded, e.isUnauthorized, e.isCanceled, e.isNetworkError]
              .where((b) => b)
              .length,
          equals(1),
        );
      });

      test('unauthorized matches exactly one bucket', () {
        const e = StorageUploadException('unauthorized', '');
        expect(
          [e.isQuotaExceeded, e.isUnauthorized, e.isCanceled, e.isNetworkError]
              .where((b) => b)
              .length,
          equals(1),
        );
      });

      test('canceled matches exactly one bucket', () {
        const e = StorageUploadException('canceled', '');
        expect(
          [e.isQuotaExceeded, e.isUnauthorized, e.isCanceled, e.isNetworkError]
              .where((b) => b)
              .length,
          equals(1),
        );
      });

      test('network-request-failed matches exactly one bucket', () {
        const e = StorageUploadException('network-request-failed', '');
        expect(
          [e.isQuotaExceeded, e.isUnauthorized, e.isCanceled, e.isNetworkError]
              .where((b) => b)
              .length,
          equals(1),
        );
      });

      test('unknown code matches zero buckets (caller falls back to generic)',
          () {
        const e = StorageUploadException('some-future-code', '');
        expect(e.isQuotaExceeded, isFalse);
        expect(e.isUnauthorized, isFalse);
        expect(e.isCanceled, isFalse);
        expect(e.isNetworkError, isFalse);
      });
    });
  });
}
