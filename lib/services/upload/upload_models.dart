/// State models and data structures for image upload management.
///
/// Generic upload models used across the image upload service infrastructure.
/// These models support all upload scenarios: recipes, avatars, messaging, etc.
///
/// **Architecture:** Service Layer - Domain Models
/// **Responsibility:** Data structures for upload state, progress, and error tracking
/// **Used By:** ImageUploadService, UploadQueueManager, UploadRetryManager

// lib/services/upload/upload_models.dart

import 'dart:io';

/// Image upload state tracking for race condition prevention
enum ImageUploadState {
  pending,
  uploading,
  completed,
  failed,
  cancelled,
  retrying
}

/// Error classification for targeted handling and recovery
enum ImageUploadErrorType {
  network, // Network connectivity issues
  validation, // File size, format, permission issues
  server, // Firebase/storage server errors
  cancelled, // User cancelled upload
  unknown // Unclassified errors
}

/// User choice for handling pending uploads during save
enum UploadChoice { wait, saveWithoutPending, cancel }

/// Upload notification triggers for background notifications
enum UploadNotificationTrigger {
  allCompleted, // All uploads completed successfully
  majorFailure, // Multiple uploads failed
  significantProgress, // 25%, 50%, 75% completion milestones
  queueCleared, // Upload queue became empty
  retrySuccess, // Failed upload succeeded on retry
}

/// Notification priority levels for upload events
enum NotificationPriority { low, medium, high, critical }

/// Comprehensive image upload status with advanced progress tracking and error recovery
class ImageUploadStatus {
  final File? file;
  final String? url;
  final ImageUploadState state;

  // Enhanced Error Information
  final String? error;
  final ImageUploadErrorType? errorType;
  final DateTime? errorOccurredAt;

  // Detailed Progress Tracking
  final double progress; // 0.0 to 1.0
  final int? bytesTransferred;
  final int? totalBytes;
  final double? uploadSpeedBytesPerSecond;
  final DateTime? uploadStartTime;
  final Duration? estimatedTimeRemaining;

  // Retry Management
  final int retryAttempts;
  final int maxRetryAttempts;
  final DateTime? nextRetryAt;
  final Duration? retryDelay;

  const ImageUploadStatus({
    this.file,
    this.url,
    required this.state,
    this.error,
    this.errorType,
    this.errorOccurredAt,
    this.progress = 0.0,
    this.bytesTransferred,
    this.totalBytes,
    this.uploadSpeedBytesPerSecond,
    this.uploadStartTime,
    this.estimatedTimeRemaining,
    this.retryAttempts = 0,
    this.maxRetryAttempts = 3,
    this.nextRetryAt,
    this.retryDelay,
  });

  // ===== COMPUTED PROPERTIES =====

  bool get isDisplayable => file != null || url != null;
  bool get isPersistable => url != null && state == ImageUploadState.completed;
  bool get hasError => error != null;
  bool get canRetry =>
      hasError &&
      retryAttempts < maxRetryAttempts &&
      state != ImageUploadState.cancelled;
  bool get isRetrying => state == ImageUploadState.retrying;
  bool get isActive =>
      state == ImageUploadState.uploading || state == ImageUploadState.retrying;

  String get displayPath => url ?? file?.path ?? '';

  /// Progress as percentage (0-100)
  int get progressPercentage => (progress * 100).round();

  /// File size in MB for display
  double? get fileSizeMB =>
      totalBytes != null ? totalBytes! / (1024 * 1024) : null;

  /// Upload speed in MB/s for display
  double? get uploadSpeedMBPerSecond => uploadSpeedBytesPerSecond != null
      ? uploadSpeedBytesPerSecond! / (1024 * 1024)
      : null;

  /// Formatted time remaining (e.g., "2m 30s")
  String? get formattedTimeRemaining {
    if (estimatedTimeRemaining == null) return null;

    final totalSeconds = estimatedTimeRemaining!.inSeconds;
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    } else if (totalSeconds < 3600) {
      final minutes = totalSeconds ~/ 60;
      final seconds = totalSeconds % 60;
      return seconds > 0 ? '${minutes}m ${seconds}s' : '${minutes}m';
    } else {
      final hours = totalSeconds ~/ 3600;
      final minutes = (totalSeconds % 3600) ~/ 60;
      return minutes > 0 ? '${hours}h ${minutes}m' : '${hours}h';
    }
  }

  /// User-friendly Swedish status description
  String get statusDescription {
    switch (state) {
      case ImageUploadState.pending:
        return 'Väntar på uppladdning...';
      case ImageUploadState.uploading:
        if (progressPercentage > 0) {
          return 'Laddar upp ($progressPercentage%)...';
        }
        return 'Förbereder uppladdning...';
      case ImageUploadState.retrying:
        return 'Försöker igen (${retryAttempts + 1}/$maxRetryAttempts)...';
      case ImageUploadState.completed:
        return 'Uppladdning slutförd';
      case ImageUploadState.cancelled:
        return 'Uppladdning avbruten';
      case ImageUploadState.failed:
        return _getFailureDescription();
    }
  }

  String _getFailureDescription() {
    switch (errorType) {
      case ImageUploadErrorType.network:
        return 'Nätverksfel - kontrollera anslutningen';
      case ImageUploadErrorType.validation:
        return 'Bilden kunde inte valideras';
      case ImageUploadErrorType.server:
        return 'Serverfel - försök igen';
      case ImageUploadErrorType.cancelled:
        return 'Uppladdning avbruten';
      case ImageUploadErrorType.unknown:
      case null:
        return 'Uppladdning misslyckades';
    }
  }

  /// Get retry instruction for user
  String? get retryInstruction {
    if (!hasError || !canRetry) return null;

    switch (errorType) {
      case ImageUploadErrorType.network:
        return 'Kontrollera internetanslutningen och tryck för att försöka igen';
      case ImageUploadErrorType.validation:
        return 'Kontrollera att bilden är giltig och inte för stor';
      case ImageUploadErrorType.server:
        return 'Försök igen om en stund';
      case ImageUploadErrorType.cancelled:
        return null; // No retry for cancelled uploads
      case ImageUploadErrorType.unknown:
      case null:
        return 'Tryck för att försöka igen';
    }
  }

  ImageUploadStatus copyWith({
    File? file,
    String? url,
    ImageUploadState? state,
    String? error,
    ImageUploadErrorType? errorType,
    DateTime? errorOccurredAt,
    double? progress,
    int? bytesTransferred,
    int? totalBytes,
    double? uploadSpeedBytesPerSecond,
    DateTime? uploadStartTime,
    Duration? estimatedTimeRemaining,
    int? retryAttempts,
    int? maxRetryAttempts,
    DateTime? nextRetryAt,
    Duration? retryDelay,
  }) {
    return ImageUploadStatus(
      file: file ?? this.file,
      url: url ?? this.url,
      state: state ?? this.state,
      error: error ?? this.error,
      errorType: errorType ?? this.errorType,
      errorOccurredAt: errorOccurredAt ?? this.errorOccurredAt,
      progress: progress ?? this.progress,
      bytesTransferred: bytesTransferred ?? this.bytesTransferred,
      totalBytes: totalBytes ?? this.totalBytes,
      uploadSpeedBytesPerSecond:
          uploadSpeedBytesPerSecond ?? this.uploadSpeedBytesPerSecond,
      uploadStartTime: uploadStartTime ?? this.uploadStartTime,
      estimatedTimeRemaining:
          estimatedTimeRemaining ?? this.estimatedTimeRemaining,
      retryAttempts: retryAttempts ?? this.retryAttempts,
      maxRetryAttempts: maxRetryAttempts ?? this.maxRetryAttempts,
      nextRetryAt: nextRetryAt ?? this.nextRetryAt,
      retryDelay: retryDelay ?? this.retryDelay,
    );
  }
}

/// Upload safety check result for preventing data corruption
class UploadSafetyResult {
  final bool isSafe;
  final List<String> pendingImagePaths;
  final List<String> failedImagePaths;

  const UploadSafetyResult({
    required this.isSafe,
    this.pendingImagePaths = const [],
    this.failedImagePaths = const [],
  });

  bool get hasPendingUploads => pendingImagePaths.isNotEmpty;
  bool get hasFailedUploads => failedImagePaths.isNotEmpty;
  int get totalProblemsCount =>
      pendingImagePaths.length + failedImagePaths.length;
}

/// Configuration for retry behavior per error type
class RetryStrategy {
  final bool autoRetry;
  final int maxAttempts;
  final String description;

  const RetryStrategy({
    required this.autoRetry,
    required this.maxAttempts,
    required this.description,
  });
}

/// Upload notification event data
class UploadNotificationEvent {
  final UploadNotificationTrigger trigger;
  final String title;
  final String message;
  final NotificationPriority priority;
  final Map<String, dynamic>? data;
  final DateTime timestamp;

  const UploadNotificationEvent({
    required this.trigger,
    required this.title,
    required this.message,
    required this.priority,
    this.data,
    required this.timestamp,
  });
}

/// Circuit breaker state for preventing cascading failures
class CircuitBreakerState {
  final int failureCount;
  final DateTime? lastFailureTime;
  final bool isOpen;

  // Circuit breaker threshold
  static const int _failureThreshold = 10;

  const CircuitBreakerState({
    required this.failureCount,
    this.lastFailureTime,
    required this.isOpen,
  });

  /// Check if circuit breaker should reset (close) after timeout
  bool shouldReset(Duration resetTime) {
    if (!isOpen || lastFailureTime == null) return false;
    return DateTime.now().difference(lastFailureTime!) >= resetTime;
  }

  /// Create new state with incremented failure count
  CircuitBreakerState withFailure() {
    return CircuitBreakerState(
      failureCount: failureCount + 1,
      lastFailureTime: DateTime.now(),
      isOpen: failureCount + 1 >= _failureThreshold,
    );
  }

  /// Reset circuit breaker to closed state
  CircuitBreakerState reset() {
    return const CircuitBreakerState(
      failureCount: 0,
      lastFailureTime: null,
      isOpen: false,
    );
  }
}
