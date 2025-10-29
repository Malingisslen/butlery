/// Upload queue management for coordinating multiple concurrent uploads.
///
/// Provides queue state management, status tracking, and query operations
/// for upload coordination across the application.
///
/// **Architecture:** Service Layer - State Management
/// **Responsibility:** Queue coordination, status tracking, upload lifecycle
/// **Used By:** ImageUploadService

// lib/services/upload/upload_queue_manager.dart

import 'dart:io';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/core/utils/logger.dart';

/// Manages upload queue state and provides query operations for upload coordination.
///
/// Core responsibilities:
/// - Queue state management (add, remove, update, clear)
/// - Upload status tracking and queries
/// - State-based filtering (pending, active, completed, failed)
/// - Queue summary and analytics
class UploadQueueManager {
  /// Internal queue state mapping file paths to upload status
  final Map<String, ImageUploadStatus> _queue = {};

  /// Get all uploads in the queue
  Map<String, ImageUploadStatus> get allUploads => Map.unmodifiable(_queue);

  /// Get count of uploads in queue
  int get queueSize => _queue.length;

  /// Check if queue is empty
  bool get isEmpty => _queue.isEmpty;

  /// Check if queue has items
  bool get isNotEmpty => _queue.isNotEmpty;

  // ===== ADD OPERATIONS =====

  /// Add new upload to queue with pending state
  void addUpload({
    required String filePath,
    required File file,
    int maxRetryAttempts = 3,
  }) {
    if (_queue.containsKey(filePath)) {
      AppLogger.warning('🗂️ QUEUE: Upload already exists for $filePath');
      return;
    }

    _queue[filePath] = ImageUploadStatus(
      file: file,
      state: ImageUploadState.pending,
      maxRetryAttempts: maxRetryAttempts,
    );

    AppLogger.info('🗂️ QUEUE: Added upload for $filePath (queue size: ${_queue.length})');
  }

  /// Add completed upload (with URL) to queue
  void addCompletedUpload({
    required String filePath,
    required String url,
  }) {
    _queue[filePath] = ImageUploadStatus(
      url: url,
      state: ImageUploadState.completed,
      progress: 1.0,
    );

    AppLogger.info('🗂️ QUEUE: Added completed upload for $filePath');
  }

  // ===== UPDATE OPERATIONS =====

  /// Update upload status in queue
  void updateStatus(String filePath, ImageUploadStatus newStatus) {
    if (!_queue.containsKey(filePath)) {
      AppLogger.warning('🗂️ QUEUE: Cannot update non-existent upload $filePath');
      return;
    }

    _queue[filePath] = newStatus;
    AppLogger.debug('🗂️ QUEUE: Updated status for $filePath to ${newStatus.state}');
  }

  /// Update upload progress
  void updateProgress({
    required String filePath,
    required double progress,
    int? bytesTransferred,
    int? totalBytes,
    double? uploadSpeed,
    Duration? estimatedTimeRemaining,
  }) {
    final currentStatus = _queue[filePath];
    if (currentStatus == null) return;

    _queue[filePath] = currentStatus.copyWith(
      progress: progress,
      bytesTransferred: bytesTransferred,
      totalBytes: totalBytes,
      uploadSpeedBytesPerSecond: uploadSpeed,
      estimatedTimeRemaining: estimatedTimeRemaining,
    );
  }

  // ===== REMOVE OPERATIONS =====

  /// Remove upload from queue
  ImageUploadStatus? removeUpload(String filePath) {
    final removed = _queue.remove(filePath);
    if (removed != null) {
      AppLogger.info('🗂️ QUEUE: Removed upload for $filePath (queue size: ${_queue.length})');
    }
    return removed;
  }

  /// Clear all uploads from queue
  void clearAll() {
    final count = _queue.length;
    _queue.clear();
    AppLogger.info('🗂️ QUEUE: Cleared all uploads ($count items)');
  }

  /// Remove uploads by state
  void removeByState(ImageUploadState state) {
    final toRemove = _queue.entries
        .where((entry) => entry.value.state == state)
        .map((entry) => entry.key)
        .toList();

    for (final key in toRemove) {
      _queue.remove(key);
    }

    AppLogger.info('🗂️ QUEUE: Removed ${toRemove.length} uploads in state ${state.name}');
  }

  // ===== QUERY OPERATIONS =====

  /// Get upload status by file path
  ImageUploadStatus? getStatus(String filePath) => _queue[filePath];

  /// Check if upload exists in queue
  bool containsUpload(String filePath) => _queue.containsKey(filePath);

  /// Get all uploads by state
  Map<String, ImageUploadStatus> getByState(ImageUploadState state) {
    return Map.fromEntries(
      _queue.entries.where((entry) => entry.value.state == state),
    );
  }

  /// Get pending uploads
  Map<String, ImageUploadStatus> get pendingUploads =>
      getByState(ImageUploadState.pending);

  /// Get uploading (active) uploads
  Map<String, ImageUploadStatus> get activeUploads {
    return Map.fromEntries(
      _queue.entries.where((entry) =>
          entry.value.state == ImageUploadState.uploading ||
          entry.value.state == ImageUploadState.retrying),
    );
  }

  /// Get completed uploads
  Map<String, ImageUploadStatus> get completedUploads =>
      getByState(ImageUploadState.completed);

  /// Get failed uploads that can be retried
  Map<String, ImageUploadStatus> get retriableFailedUploads {
    return Map.fromEntries(
      _queue.entries.where((entry) =>
          entry.value.state == ImageUploadState.failed &&
          entry.value.canRetry),
    );
  }

  /// Get all failed uploads (retryable or not)
  Map<String, ImageUploadStatus> get failedUploads =>
      getByState(ImageUploadState.failed);

  /// Get cancelled uploads
  Map<String, ImageUploadStatus> get cancelledUploads =>
      getByState(ImageUploadState.cancelled);

  /// Get valid (displayable) uploads
  Map<String, ImageUploadStatus> get validUploads {
    return Map.fromEntries(
      _queue.entries.where((entry) => entry.value.isDisplayable),
    );
  }

  /// Get persistable uploads (completed with URL)
  List<String> get persistableUrls {
    return _queue.values
        .where((status) => status.isPersistable)
        .map((status) => status.url!)
        .toList();
  }

  // ===== SUMMARY & ANALYTICS =====

  /// Get queue summary for UI display
  Map<String, dynamic> getSummary() {
    final pending = pendingUploads.length;
    final uploading = activeUploads.length;
    final completed = completedUploads.length;
    final failed = failedUploads.length;
    final total = _queue.length;

    return {
      'pending': pending,
      'uploading': uploading,
      'active': uploading, // Alias for uploading
      'completed': completed,
      'failed': failed,
      'total': total,
      'hasActive': uploading > 0,
      'hasRetryable': retriableFailedUploads.isNotEmpty,
      'completionRate': total > 0 ? (completed / total * 100).round() : 0,
    };
  }

  /// Get detailed analytics
  Map<String, dynamic> getAnalytics() {
    final summary = getSummary();

    // Calculate overall progress
    double totalProgress = 0.0;
    for (final status in _queue.values) {
      totalProgress += status.progress;
    }
    final overallProgress = _queue.isNotEmpty ? totalProgress / _queue.length : 0.0;

    // Calculate average upload speed
    double totalSpeed = 0.0;
    int speedCount = 0;
    for (final status in activeUploads.values) {
      if (status.uploadSpeedBytesPerSecond != null) {
        totalSpeed += status.uploadSpeedBytesPerSecond!;
        speedCount++;
      }
    }
    final avgSpeed = speedCount > 0 ? totalSpeed / speedCount : 0.0;

    return {
      ...summary,
      'overallProgress': overallProgress,
      'overallProgressPercentage': (overallProgress * 100).round(),
      'averageSpeedBytesPerSecond': avgSpeed,
      'averageSpeedMBPerSecond': avgSpeed / (1024 * 1024),
    };
  }
}
