import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/offline/sync_result.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  group('SyncResult', () {
    setUp(() async {
      await BaseUnitTest.setupUnit();
    });

    tearDown(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Factory Methods', () {
      test('should create success result with synced count', () {
        // Arrange & Act
        final result = SyncResult.success(
          'Successfully synced',
          syncedCount: 5,
        );

        // Assert
        expect(result.success, true);
        expect(result.message, 'Successfully synced');
        expect(result.isRetry, false);
        expect(result.syncedCount, 5);
        expect(result.failedCount, null);
      });

      test('should create success result without count', () {
        // Arrange & Act
        final result = SyncResult.success('All changes synced');

        // Assert
        expect(result.success, true);
        expect(result.message, 'All changes synced');
        expect(result.isRetry, false);
        expect(result.syncedCount, null);
        expect(result.failedCount, null);
      });

      test('should create partial success result with retry flag', () {
        // Arrange & Act
        final result = SyncResult.partialSuccess(
          'Partially synced',
          syncedCount: 3,
          failedCount: 2,
        );

        // Assert
        expect(result.success, true);
        expect(result.message, 'Partially synced');
        expect(result.isRetry, true); // Should retry due to failures
        expect(result.syncedCount, 3);
        expect(result.failedCount, 2);
      });

      test('should create failure result with retry option', () {
        // Arrange & Act
        final result = SyncResult.failure(
          'Network error',
          willRetry: true,
        );

        // Assert
        expect(result.success, false);
        expect(result.message, 'Network error');
        expect(result.isRetry, true);
        expect(result.syncedCount, null);
        expect(result.failedCount, null);
      });

      test('should create failure result without retry', () {
        // Arrange & Act
        final result = SyncResult.failure(
          'Authentication failed',
          willRetry: false,
        );

        // Assert
        expect(result.success, false);
        expect(result.message, 'Authentication failed');
        expect(result.isRetry, false);
        expect(result.syncedCount, null);
        expect(result.failedCount, null);
      });
    });

    group('Result State Validation', () {
      test('should correctly indicate complete success', () {
        // Arrange & Act
        final result =
            SyncResult.success('All 10 items synced', syncedCount: 10);

        // Assert
        expect(result.success, true);
        expect(result.isRetry, false);
        expect(result.syncedCount, 10);
        expect(result.failedCount, null);
      });

      test('should correctly indicate partial success needs retry', () {
        // Arrange & Act
        final result = SyncResult.partialSuccess(
          '5 of 8 items synced',
          syncedCount: 5,
          failedCount: 3,
        );

        // Assert
        expect(result.success, true); // Partial success is still success
        expect(result.isRetry, true); // But needs retry for failed items
        expect(result.syncedCount, 5);
        expect(result.failedCount, 3);
      });

      test('should correctly indicate recoverable failure', () {
        // Arrange & Act
        final result = SyncResult.failure(
          'Temporary network issue',
          willRetry: true,
        );

        // Assert
        expect(result.success, false);
        expect(result.isRetry, true);
        expect(result.message, 'Temporary network issue');
      });

      test('should correctly indicate non-recoverable failure', () {
        // Arrange & Act
        final result = SyncResult.failure(
          'User not authenticated',
          willRetry: false,
        );

        // Assert
        expect(result.success, false);
        expect(result.isRetry, false);
        expect(result.message, 'User not authenticated');
      });
    });

    group('Edge Cases', () {
      test('should handle zero synced count in partial success', () {
        // Arrange & Act
        final result = SyncResult.partialSuccess(
          'No items synced',
          syncedCount: 0,
          failedCount: 5,
        );

        // Assert
        expect(result.success, true); // Still marked as success (partial)
        expect(result.isRetry, true); // All failed, needs retry
        expect(result.syncedCount, 0);
        expect(result.failedCount, 5);
      });

      test('should handle all synced in partial success', () {
        // Arrange & Act
        final result = SyncResult.partialSuccess(
          'All items synced',
          syncedCount: 5,
          failedCount: 0,
        );

        // Assert
        expect(result.success, true);
        expect(result.isRetry, false); // No failures, no retry needed
        expect(result.syncedCount, 5);
        expect(result.failedCount, 0);
      });

      test('should create result with custom constructor', () {
        // Arrange & Act
        const result = SyncResult(
          success: true,
          message: 'Custom sync result',
          isRetry: false,
          syncedCount: 7,
          failedCount: 1,
        );

        // Assert
        expect(result.success, true);
        expect(result.message, 'Custom sync result');
        expect(result.isRetry, false);
        expect(result.syncedCount, 7);
        expect(result.failedCount, 1);
      });
    });
  });
}
