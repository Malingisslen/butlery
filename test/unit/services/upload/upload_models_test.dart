/// Unit tests for upload data models.
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/upload/upload_models.dart';

ImageUploadStatus _status({
  File? file,
  String? url,
  ImageUploadState state = ImageUploadState.pending,
  String? error,
  ImageUploadErrorType? errorType,
  double progress = 0.0,
  int retryAttempts = 0,
  int maxRetryAttempts = 3,
  int? totalBytes,
  double? uploadSpeedBytesPerSecond,
  Duration? estimatedTimeRemaining,
}) {
  return ImageUploadStatus(
    file: file,
    url: url,
    state: state,
    error: error,
    errorType: errorType,
    progress: progress,
    retryAttempts: retryAttempts,
    maxRetryAttempts: maxRetryAttempts,
    totalBytes: totalBytes,
    uploadSpeedBytesPerSecond: uploadSpeedBytesPerSecond,
    estimatedTimeRemaining: estimatedTimeRemaining,
  );
}

void main() {
  group('ImageUploadStatus boolean getters', () {
    test('isDisplayable when file or url is set', () {
      expect(_status().isDisplayable, isFalse);
      expect(_status(file: File('x.jpg')).isDisplayable, isTrue);
      expect(_status(url: 'https://x').isDisplayable, isTrue);
    });

    test('isPersistable only when url set AND state==completed', () {
      expect(_status(url: 'u').isPersistable, isFalse);
      expect(
        _status(url: 'u', state: ImageUploadState.completed).isPersistable,
        isTrue,
      );
      expect(
        _status(state: ImageUploadState.completed).isPersistable,
        isFalse, // url missing
      );
    });

    test('hasError when error is non-null', () {
      expect(_status().hasError, isFalse);
      expect(_status(error: 'boom').hasError, isTrue);
    });

    test('canRetry: error + retries < max + not cancelled', () {
      expect(_status(error: 'e', retryAttempts: 0).canRetry, isTrue);
      expect(
        _status(error: 'e', retryAttempts: 3, maxRetryAttempts: 3).canRetry,
        isFalse,
      );
      expect(
        _status(error: 'e', state: ImageUploadState.cancelled).canRetry,
        isFalse,
      );
      expect(_status(retryAttempts: 0).canRetry, isFalse); // no error
    });

    test('isRetrying when state==retrying', () {
      expect(_status(state: ImageUploadState.retrying).isRetrying, isTrue);
      expect(_status(state: ImageUploadState.uploading).isRetrying, isFalse);
    });

    test('isActive covers uploading AND retrying', () {
      expect(_status(state: ImageUploadState.uploading).isActive, isTrue);
      expect(_status(state: ImageUploadState.retrying).isActive, isTrue);
      expect(_status(state: ImageUploadState.pending).isActive, isFalse);
      expect(_status(state: ImageUploadState.completed).isActive, isFalse);
    });
  });

  group('display + accessors', () {
    test('displayPath prefers url over file path', () {
      expect(
        _status(url: 'https://x', file: File('local.jpg')).displayPath,
        'https://x',
      );
    });

    test('displayPath falls back to file path when no url', () {
      expect(
        _status(file: File('/tmp/local.jpg')).displayPath,
        '/tmp/local.jpg',
      );
    });

    test('displayPath empty string when neither set', () {
      expect(_status().displayPath, '');
    });

    test('progressPercentage rounds to int 0-100', () {
      expect(_status(progress: 0).progressPercentage, 0);
      expect(_status(progress: 0.5).progressPercentage, 50);
      expect(_status(progress: 0.999).progressPercentage, 100);
      expect(_status(progress: 1.0).progressPercentage, 100);
    });

    test('fileSizeMB / uploadSpeedMBPerSecond convert from bytes', () {
      expect(_status(totalBytes: 1024 * 1024).fileSizeMB, 1.0);
      expect(_status(totalBytes: 5 * 1024 * 1024).fileSizeMB, 5.0);
      expect(_status().fileSizeMB, isNull);

      expect(
        _status(uploadSpeedBytesPerSecond: 1024 * 1024).uploadSpeedMBPerSecond,
        1.0,
      );
      expect(_status().uploadSpeedMBPerSecond, isNull);
    });
  });

  group('formattedTimeRemaining', () {
    test('null when no estimate', () {
      expect(_status().formattedTimeRemaining, isNull);
    });

    test('"Ns" under 1 minute', () {
      expect(
        _status(
          estimatedTimeRemaining: const Duration(seconds: 45),
        ).formattedTimeRemaining,
        '45s',
      );
    });

    test('"Nm Ms" between 1 minute and 1 hour', () {
      expect(
        _status(
          estimatedTimeRemaining: const Duration(minutes: 2, seconds: 30),
        ).formattedTimeRemaining,
        '2m 30s',
      );
    });

    test('"Nm" exactly when seconds == 0', () {
      expect(
        _status(
          estimatedTimeRemaining: const Duration(minutes: 5),
        ).formattedTimeRemaining,
        '5m',
      );
    });

    test('"Nh Mm" over 1 hour', () {
      expect(
        _status(
          estimatedTimeRemaining: const Duration(hours: 1, minutes: 30),
        ).formattedTimeRemaining,
        '1h 30m',
      );
    });

    test('"Nh" when remainder is 0 minutes', () {
      expect(
        _status(
          estimatedTimeRemaining: const Duration(hours: 2),
        ).formattedTimeRemaining,
        '2h',
      );
    });
  });

  group('copyWith', () {
    test('partial update preserves other fields', () {
      final base = _status(progress: 0.5);
      final copy = base.copyWith(progress: 0.8);
      expect(copy.progress, 0.8);
      expect(copy.state, base.state);
    });

    test('state-only update', () {
      final base = _status();
      expect(
        base.copyWith(state: ImageUploadState.completed).state,
        ImageUploadState.completed,
      );
    });
  });

  group('UploadSafetyResult', () {
    test('hasPendingUploads / hasFailedUploads / totalProblemsCount', () {
      const safe = UploadSafetyResult(isSafe: true);
      expect(safe.hasPendingUploads, isFalse);
      expect(safe.hasFailedUploads, isFalse);
      expect(safe.totalProblemsCount, 0);

      const problem = UploadSafetyResult(
        isSafe: false,
        pendingImagePaths: ['a', 'b'],
        failedImagePaths: ['c'],
      );
      expect(problem.hasPendingUploads, isTrue);
      expect(problem.hasFailedUploads, isTrue);
      expect(problem.totalProblemsCount, 3);
    });
  });

  group('CircuitBreakerState', () {
    test('shouldReset is false when not open', () {
      const state = CircuitBreakerState(
        failureCount: 5,
        isOpen: false,
      );
      expect(state.shouldReset(const Duration(seconds: 30)), isFalse);
    });

    test('shouldReset is false when lastFailureTime is null', () {
      const state = CircuitBreakerState(failureCount: 10, isOpen: true);
      expect(state.shouldReset(const Duration(seconds: 30)), isFalse);
    });

    test('shouldReset true after resetTime elapses', () {
      final start = DateTime.utc(2026, 1, 1);
      final state = CircuitBreakerState(
        failureCount: 10,
        lastFailureTime: start,
        isOpen: true,
      );
      withClock(Clock.fixed(start.add(const Duration(seconds: 31))), () {
        expect(state.shouldReset(const Duration(seconds: 30)), isTrue);
      });
    });

    test(
      'withFailure increments count + stamps time + opens at threshold (10)',
      () {
        withClock(Clock.fixed(DateTime.utc(2026, 1, 1)), () {
          // Below threshold: stays closed
          var s = const CircuitBreakerState(failureCount: 0, isOpen: false);
          s = s.withFailure();
          expect(s.failureCount, 1);
          expect(s.isOpen, isFalse);
          expect(s.lastFailureTime, DateTime.utc(2026, 1, 1));

          // 9th → 10th flip opens
          const nineFailures = CircuitBreakerState(
            failureCount: 9,
            isOpen: false,
          );
          final tenth = nineFailures.withFailure();
          expect(tenth.failureCount, 10);
          expect(tenth.isOpen, isTrue);
        });
      },
    );

    test('reset returns the canonical closed state', () {
      const state = CircuitBreakerState(failureCount: 10, isOpen: true);
      final reset = state.reset();
      expect(reset.failureCount, 0);
      expect(reset.isOpen, isFalse);
      expect(reset.lastFailureTime, isNull);
    });
  });

  group('UploadNotificationEvent', () {
    test('preserves all required fields', () {
      final e = UploadNotificationEvent(
        trigger: UploadNotificationTrigger.allCompleted,
        title: 'Klart',
        message: 'Alla bilder uppladdade',
        priority: NotificationPriority.medium,
        timestamp: DateTime.utc(2026, 1, 1),
      );
      expect(e.trigger, UploadNotificationTrigger.allCompleted);
      expect(e.title, 'Klart');
      expect(e.priority, NotificationPriority.medium);
      expect(e.data, isNull);
    });
  });

  group('RetryStrategy', () {
    test('stores all three fields', () {
      const s = RetryStrategy(
        autoRetry: true,
        maxAttempts: 5,
        description: 'aggressive',
      );
      expect(s.autoRetry, isTrue);
      expect(s.maxAttempts, 5);
      expect(s.description, 'aggressive');
    });
  });
}
