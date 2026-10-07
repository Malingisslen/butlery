// lib/services/offline/sync_result.dart

import 'package:butlery/core/l10n/app_locale.dart';

/// Result of synchronization operation
class SyncResult {
  final bool success;
  final String message;
  final bool isRetry; // If more attempts are needed
  final int? syncedCount;
  final int? failedCount;

  const SyncResult({
    required this.success,
    required this.message,
    required this.isRetry,
    this.syncedCount,
    this.failedCount,
  });

  factory SyncResult.success(String message, {int? syncedCount}) {
    return SyncResult(
      success: true,
      message: message,
      isRetry: false,
      syncedCount: syncedCount,
    );
  }

  factory SyncResult.partialSuccess(
    String message, {
    required int syncedCount,
    required int failedCount,
  }) {
    return SyncResult(
      success: true,
      message: message,
      isRetry: failedCount > 0,
      syncedCount: syncedCount,
      failedCount: failedCount,
    );
  }

  /// "Försök synka nu": [synced] of the [total] changes reached the server.
  factory SyncResult.ofManualPass({required int synced, required int total}) {
    final l = AppLocale.current;
    final remaining = total - synced;
    if (remaining == 0) {
      return SyncResult(
        success: true,
        message: l.syncAllSynced(synced),
        isRetry: false,
      );
    }
    if (synced > 0) {
      return SyncResult(
        success: true,
        message: l.syncPartialSuccess(synced, total, remaining),
        isRetry: true,
      );
    }
    return SyncResult(
      success: false,
      message: l.syncFailedRetryLater,
      isRetry: true,
    );
  }

  factory SyncResult.failure(String message, {bool willRetry = false}) {
    return SyncResult(
      success: false,
      message: message,
      isRetry: willRetry,
    );
  }
}
