/// Upload queue summary calculator for image upload analytics and UI display text.

import 'package:clock/clock.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/services/upload/upload_models.dart';

/// Calculates upload queue summaries and formatted display text for UI.
/// Pure calculator class with no state - all methods take parameters.
class UploadQueueSummaryCalculator {
  /// Get enhanced upload queue summary for UI display with analytics
  static Map<String, dynamic> calculateQueueSummary(
    Map<String, ImageUploadStatus> imageStates,
  ) {
    int pending = 0;
    int uploading = 0;
    int retrying = 0;
    int completed = 0;
    int failed = 0;
    int cancelled = 0;
    double totalProgress = 0.0;
    double totalSpeedBytesPerSecond = 0.0;
    int totalBytesTransferred = 0;
    int totalBytes = 0;
    int activeUploadsWithSpeed = 0;
    DateTime? earliestStartTime;

    for (final status in imageStates.values) {
      // Count by state
      switch (status.state) {
        case ImageUploadState.pending:
          pending++;
          break;
        case ImageUploadState.uploading:
          uploading++;
          totalProgress += status.progress;
          break;
        case ImageUploadState.retrying:
          retrying++;
          totalProgress += status.progress;
          break;
        case ImageUploadState.completed:
          completed++;
          totalProgress += 1.0;
          break;
        case ImageUploadState.failed:
          failed++;
          break;
        case ImageUploadState.cancelled:
          cancelled++;
          break;
      }

      // Collect analytics data
      if (status.totalBytes != null) {
        totalBytes += status.totalBytes!;
      }
      if (status.bytesTransferred != null) {
        totalBytesTransferred += status.bytesTransferred!;
      }

      // Collect speed data from active uploads
      if (status.isActive && status.uploadSpeedBytesPerSecond != null) {
        totalSpeedBytesPerSecond += status.uploadSpeedBytesPerSecond!;
        activeUploadsWithSpeed++;
      }

      // Track earliest start time for total elapsed time
      if (status.uploadStartTime != null) {
        if (earliestStartTime == null ||
            status.uploadStartTime!.isBefore(earliestStartTime)) {
          earliestStartTime = status.uploadStartTime;
        }
      }
    }

    final total = imageStates.length;
    final active = uploading + retrying;
    final hasActivity = pending > 0 || active > 0;
    final overallProgress = total > 0 ? totalProgress / total : 1.0;
    final progressPercentage =
        total > 0 ? ((overallProgress) * 100).round() : 100;

    // Calculate analytics
    final averageSpeedBytesPerSecond = activeUploadsWithSpeed > 0
        ? totalSpeedBytesPerSecond / activeUploadsWithSpeed
        : 0.0;

    final totalElapsedTime = earliestStartTime != null
        ? clock.now().difference(earliestStartTime)
        : null;

    Duration? estimatedTimeRemaining;
    if (averageSpeedBytesPerSecond > 0 && totalBytes > totalBytesTransferred) {
      final remainingBytes = totalBytes - totalBytesTransferred;
      final secondsRemaining = remainingBytes / averageSpeedBytesPerSecond;
      estimatedTimeRemaining = Duration(seconds: secondsRemaining.round());
    }

    return {
      // Basic counts
      'total': total,
      'pending': pending,
      'uploading': uploading,
      'retrying': retrying,
      'completed': completed,
      'failed': failed,
      'cancelled': cancelled,
      'active': active,
      'hasActivity': hasActivity,

      // Progress metrics
      'overallProgress': overallProgress,
      'progressPercentage': progressPercentage,

      // Analytics data
      'totalBytes': totalBytes,
      'totalBytesTransferred': totalBytesTransferred,
      'averageSpeedBytesPerSecond': averageSpeedBytesPerSecond,
      'totalElapsedTime': totalElapsedTime,
      'estimatedTimeRemaining': estimatedTimeRemaining,

      // Formatted display data
      'statusText': getEnhancedQueueStatusText(
          pending, active, completed, failed, total, overallProgress,
          cancelled: cancelled),
      'progressText':
          getProgressDisplayText(overallProgress, estimatedTimeRemaining),
      'speedText': getSpeedDisplayText(averageSpeedBytesPerSecond),
      'summaryText':
          getQueueSummaryText(completed, failed, total, totalElapsedTime),
    };
  }

  /// Enhanced queue status text with progress information.
  ///
  /// BUT-1102: `cancelled` is now threaded through so an all-cancelled queue
  /// surfaces a dedicated message instead of rendering blank UI. Optional
  /// for source compatibility with older call sites that didn't pass it.
  static String getEnhancedQueueStatusText(int pending, int active,
      int completed, int failed, int total, double overallProgress,
      {int cancelled = 0}) {
    if (total == 0) return '';

    final progressPercent = (overallProgress * 100).round();

    final l = AppLocale.current;
    if (active > 0) {
      if (pending > 0) {
        return l.uploadStatusUploading(active, progressPercent, pending);
      } else {
        return l.uploadStatusUploadingNoPending(active, progressPercent);
      }
    } else if (pending > 0) {
      return l.uploadStatusWaiting(pending);
    } else if (failed > 0 && completed > 0) {
      return l.uploadStatusPartialFailure(completed, total, failed);
    } else if (failed > 0) {
      return l.uploadStatusAllFailed(failed, total);
    } else if (completed == total && total > 0) {
      return l.uploadStatusAllSuccess(total);
    } else if (cancelled > 0 &&
        active == 0 &&
        pending == 0 &&
        failed == 0 &&
        completed == 0) {
      // BUT-1102: all-cancelled — UI was blank prior to this branch.
      return l.uploadStatusAllCancelled(cancelled);
    } else {
      return '';
    }
  }

  /// Get progress display text with time estimates
  static String getProgressDisplayText(
      double progress, Duration? timeRemaining) {
    final progressPercent = (progress * 100).round();

    final l = AppLocale.current;
    if (timeRemaining != null) {
      final timeText = formatDuration(timeRemaining);
      return l.uploadProgressWithTime(progressPercent, timeText);
    } else if (progress < 1.0) {
      return l.uploadProgressPercent(progressPercent);
    } else {
      return l.uploadComplete;
    }
  }

  /// Get speed display text for upload analytics
  static String getSpeedDisplayText(double bytesPerSecond) {
    if (bytesPerSecond <= 0) return '';

    final mbPerSecond = bytesPerSecond / (1024 * 1024);
    if (mbPerSecond >= 1.0) {
      return '${mbPerSecond.toStringAsFixed(1)} MB/s';
    } else {
      final kbPerSecond = bytesPerSecond / 1024;
      return '${kbPerSecond.toStringAsFixed(0)} KB/s';
    }
  }

  /// Get queue summary text with completion analytics
  static String getQueueSummaryText(
      int completed, int failed, int total, Duration? elapsedTime) {
    if (total == 0) return '';

    final successRate = total > 0 ? ((completed / total) * 100).round() : 0;

    final l = AppLocale.current;
    if (completed == total && failed == 0) {
      final timeText = elapsedTime != null
          ? l.uploadTimeIn(formatDuration(elapsedTime))
          : '';
      return l.uploadAllSuccessWithTime(timeText);
    } else if (completed > 0 || failed > 0) {
      final completionText = l.uploadCompletionOf(completed, total);
      final failureText = failed > 0 ? l.uploadFailureCount(failed) : '';
      final rateText = l.uploadSuccessRate(successRate);

      return '$completionText$failureText$rateText';
    } else {
      return l.uploadPreparing;
    }
  }

  /// Format duration for display (e.g., "2m 30s", "45s", "1h 15m")
  static String formatDuration(Duration duration) {
    final totalSeconds = duration.inSeconds;

    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    } else if (totalSeconds < 3600) {
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    } else {
      final hours = totalSeconds ~/ 3600;
      final remainingMinutes = (totalSeconds % 3600) ~/ 60;
      return remainingMinutes > 0
          ? '${hours}h ${remainingMinutes}m'
          : '${hours}h';
    }
  }
}
