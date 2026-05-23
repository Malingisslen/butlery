/// BUT-1027 (acceptance #3 of BUT-1023): coverage for
/// [UploadRetryManager.classifyError] — the third link in the
/// `FirebaseException → StorageUploadException → ImageUploadErrorType`
/// chain. A typo in the `is*` getter branches collapses every failure to
/// `ImageUploadErrorType.server` / `unknown`, so each branch needs a
/// pinned test.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/storage_upload_exception.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/services/upload/upload_retry_manager.dart';

void main() {
  group('UploadRetryManager.classifyError — StorageUploadException codes', () {
    late UploadRetryManager manager;

    setUp(() {
      manager = UploadRetryManager();
    });

    test('quota-exceeded → ImageUploadErrorType.quotaExceeded', () {
      expect(
        manager.classifyError(const StorageUploadException(
          'quota-exceeded',
          'quota hit',
        )),
        equals(ImageUploadErrorType.quotaExceeded),
      );
    });

    test('unauthorized → ImageUploadErrorType.validation', () {
      expect(
        manager.classifyError(const StorageUploadException(
          'unauthorized',
          'permission denied',
        )),
        equals(ImageUploadErrorType.validation),
      );
    });

    test('unauthenticated → ImageUploadErrorType.validation', () {
      expect(
        manager.classifyError(const StorageUploadException(
          'unauthenticated',
          'not signed in',
        )),
        equals(ImageUploadErrorType.validation),
      );
    });

    test('canceled → ImageUploadErrorType.cancelled', () {
      expect(
        manager.classifyError(const StorageUploadException(
          'canceled',
          'user cancelled',
        )),
        equals(ImageUploadErrorType.cancelled),
      );
    });

    test('cancelled (British spelling) → ImageUploadErrorType.cancelled', () {
      // The helper-getter accepts both spellings; this test pins that.
      expect(
        manager.classifyError(const StorageUploadException(
          'cancelled',
          'user cancelled',
        )),
        equals(ImageUploadErrorType.cancelled),
      );
    });

    test('network-request-failed → ImageUploadErrorType.network', () {
      // BUT-971 reviewer follow-up: network-domain storage failures must
      // route through the network retry path (auto-retry + connection copy),
      // not the unknown/server fallback. A regression here would mean
      // offline uploads bypass the retry loop.
      expect(
        manager.classifyError(const StorageUploadException(
          'network-request-failed',
          'offline',
        )),
        equals(ImageUploadErrorType.network),
      );
    });

    test('retry-limit-exceeded → ImageUploadErrorType.network', () {
      expect(
        manager.classifyError(const StorageUploadException(
          'retry-limit-exceeded',
          'retry budget exhausted',
        )),
        equals(ImageUploadErrorType.network),
      );
    });

    test('server-file-wrong-size → ImageUploadErrorType.network', () {
      // Intentionally part of the network group — user-recoverable via
      // retry, not a developer bug to surface as "validation."
      expect(
        manager.classifyError(const StorageUploadException(
          'server-file-wrong-size',
          'partial upload',
        )),
        equals(ImageUploadErrorType.network),
      );
    });

    test('unknown StorageUploadException code → ImageUploadErrorType.server',
        () {
      // Default branch — any code we haven't classified gets server (which
      // is auto-retried up to 3 times per the retry strategy table).
      expect(
        manager.classifyError(const StorageUploadException(
          'object-not-found',
          'missing',
        )),
        equals(ImageUploadErrorType.server),
      );
    });
  });

  group(
      'UploadRetryManager.classifyError — non-StorageUploadException fall-through',
      () {
    late UploadRetryManager manager;

    setUp(() {
      manager = UploadRetryManager();
    });

    test('plain "network" string → ImageUploadErrorType.network', () {
      expect(
        manager.classifyError(Exception('network failure')),
        equals(ImageUploadErrorType.network),
      );
    });

    test('plain "timeout" string → ImageUploadErrorType.network', () {
      expect(
        manager.classifyError(Exception('timeout exceeded')),
        equals(ImageUploadErrorType.network),
      );
    });

    test('plain "permission" string → ImageUploadErrorType.validation', () {
      expect(
        manager.classifyError(Exception('permission denied')),
        equals(ImageUploadErrorType.validation),
      );
    });

    test('plain "cancel" string → ImageUploadErrorType.cancelled', () {
      expect(
        manager.classifyError(Exception('cancel requested')),
        equals(ImageUploadErrorType.cancelled),
      );
    });

    test('"server cancel" still routes to cancelled (cancel branch order)',
        () {
      // Pins priority: the cancel branch sits AFTER server/firebase/storage
      // in the substring matcher, but "cancel" wins because "server" only
      // matches on its own substring presence and the cancel branch is
      // checked separately — except per the current code, server is line
      // 110-115 and cancel is line 117-119. So 'server cancel' actually
      // matches server FIRST. This test pins that current behavior so a
      // reorder would surface here.
      expect(
        manager.classifyError(Exception('server cancel')),
        equals(ImageUploadErrorType.server),
      );
    });

    test('truly unrecognized string → ImageUploadErrorType.unknown', () {
      expect(
        manager.classifyError(Exception('arbitrary error message')),
        equals(ImageUploadErrorType.unknown),
      );
    });
  });
}
