// lib/services/offline/sync_result.dart

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

  factory SyncResult.failure(String message, {bool willRetry = false}) {
    return SyncResult(
      success: false,
      message: message,
      isRetry: willRetry,
    );
  }
}