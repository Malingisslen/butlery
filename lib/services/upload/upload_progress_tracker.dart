/// Upload progress tracking with speed calculation and ETA estimation.
/// Provides real-time progress monitoring, upload speed calculation,
/// and estimated time remaining for upload operations.
/// **Architecture:** Service Layer - Progress Coordination
/// **Responsibility:** Progress updates, speed calculation, milestone detection
/// **Used By:** ImageUploadService

// lib/services/upload/upload_progress_tracker.dart

import 'package:clock/clock.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Tracks upload progress with speed calculation and milestone detection.
/// Core responsibilities:
/// - Progress update coordination
/// - Upload speed calculation (bytes per second)
/// - Estimated time remaining calculation
/// - Progress milestone detection (25%, 50%, 75%)
/// - Upload timing and statistics
class UploadProgressTracker {
  /// Track last progress update per upload
  final Map<String, _ProgressMetrics> _progressMetrics = {};

  /// Progress milestones for notifications (25%, 50%, 75%)
  static const List<double> progressMilestones = [0.25, 0.50, 0.75];

  /// Update progress for an upload
  ImageUploadStatus updateProgress({
    required ImageUploadStatus currentStatus,
    required double progress,
    required int fileSize,
  }) {
    final filePath = currentStatus.file?.path ?? currentStatus.url ?? '';
    final now = clock.now();
    final bytesTransferred = (progress * fileSize).round();

    // Get or create progress metrics
    final metrics = _progressMetrics.putIfAbsent(
      filePath,
      () => _ProgressMetrics(
        lastUpdateTime: now,
        lastBytesTransferred: 0,
        startTime: now,
      ),
    );

    // Calculate upload speed and time remaining
    double? uploadSpeed;
    Duration? timeRemaining;

    final timeDiff =
        now.difference(metrics.lastUpdateTime).inMilliseconds / 1000.0;
    final bytesDiff = bytesTransferred - metrics.lastBytesTransferred;

    if (timeDiff > 0 && bytesDiff > 0) {
      uploadSpeed = bytesDiff / timeDiff; // bytes per second

      if (uploadSpeed > 0) {
        final remainingBytes = fileSize - bytesTransferred;
        timeRemaining = Duration(
          seconds: (remainingBytes / uploadSpeed).round(),
        );
      }
    }

    // Update metrics for next calculation
    _progressMetrics[filePath] = _ProgressMetrics(
      lastUpdateTime: now,
      lastBytesTransferred: bytesTransferred,
      startTime: metrics.startTime,
    );

    // Check for milestone crossing
    final previousProgress = currentStatus.progress;
    final milestone = _checkMilestoneCrossed(previousProgress, progress);
    if (milestone != null) {
      AppLogger.info(
        '📊 PROGRESS: Milestone ${(milestone * 100).round()}% reached for $filePath',
      );
    }

    return currentStatus.copyWith(
      progress: progress,
      bytesTransferred: bytesTransferred,
      totalBytes: fileSize,
      uploadSpeedBytesPerSecond: uploadSpeed,
      uploadStartTime: currentStatus.uploadStartTime ?? metrics.startTime,
      estimatedTimeRemaining: timeRemaining,
    );
  }

  /// Start tracking progress for an upload
  void startTracking(String filePath) {
    _progressMetrics[filePath] = _ProgressMetrics(
      lastUpdateTime: clock.now(),
      lastBytesTransferred: 0,
      startTime: clock.now(),
    );
    AppLogger.debug('📊 PROGRESS: Started tracking for $filePath');
  }

  /// Stop tracking progress for an upload
  void stopTracking(String filePath) {
    _progressMetrics.remove(filePath);
    AppLogger.debug('📊 PROGRESS: Stopped tracking for $filePath');
  }

  /// Clear all progress tracking
  void clearAll() {
    _progressMetrics.clear();
    AppLogger.debug('📊 PROGRESS: Cleared all tracking');
  }

  /// Check if a progress milestone was crossed
  /// Returns the milestone value (0.25, 0.50, 0.75) if crossed, null otherwise
  double? _checkMilestoneCrossed(
    double previousProgress,
    double currentProgress,
  ) {
    for (final milestone in progressMilestones) {
      if (previousProgress < milestone && currentProgress >= milestone) {
        return milestone;
      }
    }
    return null;
  }

  /// Check for milestone and return notification event if crossed
  UploadNotificationEvent? checkMilestoneNotification({
    required double previousProgress,
    required double currentProgress,
  }) {
    final milestone = _checkMilestoneCrossed(previousProgress, currentProgress);
    if (milestone == null) return null;

    final percentage = (milestone * 100).round();
    return UploadNotificationEvent(
      trigger: UploadNotificationTrigger.significantProgress,
      title: AppLocale.current.uploadNotificationTitle(percentage),
      message: AppLocale.current.uploadNotificationMessage(percentage),
      priority: NotificationPriority.low,
      data: {'milestone': milestone, 'progress': currentProgress},
      timestamp: clock.now(),
    );
  }

  /// Get upload duration for a file
  Duration? getUploadDuration(String filePath) {
    final metrics = _progressMetrics[filePath];
    if (metrics == null) return null;
    return clock.now().difference(metrics.startTime);
  }

  /// Get average upload speed across all active uploads
  double getAverageUploadSpeed(Map<String, ImageUploadStatus> activeUploads) {
    if (activeUploads.isEmpty) return 0.0;

    double totalSpeed = 0.0;
    int speedCount = 0;

    for (final status in activeUploads.values) {
      if (status.uploadSpeedBytesPerSecond != null) {
        totalSpeed += status.uploadSpeedBytesPerSecond!;
        speedCount++;
      }
    }

    return speedCount > 0 ? totalSpeed / speedCount : 0.0;
  }

  /// Calculate overall progress across multiple uploads
  double calculateOverallProgress(Map<String, ImageUploadStatus> uploads) {
    if (uploads.isEmpty) return 0.0;

    double totalProgress = 0.0;
    for (final status in uploads.values) {
      totalProgress += status.progress;
    }

    return totalProgress / uploads.length;
  }
}

/// Internal class for tracking progress metrics per upload
class _ProgressMetrics {
  final DateTime lastUpdateTime;
  final int lastBytesTransferred;
  final DateTime startTime;

  _ProgressMetrics({
    required this.lastUpdateTime,
    required this.lastBytesTransferred,
    required this.startTime,
  });
}
