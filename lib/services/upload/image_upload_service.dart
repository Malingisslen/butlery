/// Generic image upload service with retry, progress tracking, and resilience.
/// Provides reusable upload infrastructure for all image uploads in the application:
/// recipes, avatars, messaging, profile images, etc.
/// **Architecture:** Service Layer - Facade Pattern
/// **Responsibility:** Upload coordination, retry management, progress tracking
/// **Used By:** RecipeImageManager, UserProfileViewModel, MessagingMediaService

// lib/services/upload/image_upload_service.dart

import 'package:clock/clock.dart';
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/services/upload/upload_queue_manager.dart';
import 'package:butlery/services/upload/upload_retry_manager.dart';
import 'package:butlery/services/upload/upload_progress_tracker.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/utils/retry_policy.dart';

/// Result of an upload operation
class UploadResult {
  final bool success;
  final String? url;
  final String? thumbnailUrl;
  final String? error;
  final ImageUploadErrorType? errorType;

  const UploadResult({
    required this.success,
    this.url,
    this.thumbnailUrl,
    this.error,
    this.errorType,
  });

  factory UploadResult.success(String url, {String? thumbnailUrl}) =>
      UploadResult(success: true, url: url, thumbnailUrl: thumbnailUrl);

  factory UploadResult.failure(String error, ImageUploadErrorType errorType) =>
      UploadResult(success: false, error: error, errorType: errorType);
}

/// Generic image upload service with automatic retry, progress tracking, and resilience.
/// Provides reusable upload infrastructure that can be used across the application
/// for recipes, avatars, messaging, and any other image upload needs.
/// **Features:**
/// - Automatic retry with exponential backoff
/// - Circuit breaker to prevent cascading failures
/// - Real-time progress tracking with speed/ETA
/// - Upload queue management
/// - Event stream for UI notifications
/// - Support for single and batch uploads
/// **Usage Example:**
/// ```dart
/// final service = ImageUploadService();
/// // Single upload with progress tracking
/// final result = await service.uploadImage(
///   file: imageFile,
///   userId: userId,
///   onProgress: (status) {
///     print('Progress: ${status.progressPercentage}%');
///   },
/// );
/// if (result.success) {
///   print('Uploaded to: ${result.url}');
/// }
/// ```
class ImageUploadService extends BaseService {
  @override
  String get serviceName => 'ImageUploadService';

  final UploadQueueManager _queueManager;
  final UploadRetryManager _retryManager;
  final UploadProgressTracker _progressTracker;
  final StorageService _storageService;

  /// Stream controller for upload notification events
  final StreamController<UploadNotificationEvent> _notificationController =
      StreamController<UploadNotificationEvent>.broadcast();

  /// Stream of upload notification events for UI subscription
  Stream<UploadNotificationEvent> get notificationStream =>
      _notificationController.stream;

  /// Cancellation tokens for active uploads
  final Map<String, bool> _cancellationTokens = {};

  ImageUploadService({
    UploadQueueManager? queueManager,
    UploadRetryManager? retryManager,
    UploadProgressTracker? progressTracker,
    StorageService? storageService,
  })  : _queueManager = queueManager ?? UploadQueueManager(),
        _retryManager = retryManager ?? UploadRetryManager(),
        _progressTracker = progressTracker ?? UploadProgressTracker(),
        _storageService =
            storageService ?? ServiceLocator.get<StorageService>();

  /// Upload a single image with automatic retry and progress tracking.
  /// Path construction is handled by StorageService — callers should not specify paths.
  Future<UploadResult> uploadImage({
    required File file,
    required String userId,
    int maxRetryAttempts = 3,
    void Function(ImageUploadStatus)? onProgress,
  }) async {
    final filePath = file.path;

    AppLogger.info('🆙 UPLOAD_SERVICE: Starting upload for $filePath');

    // Add to queue
    _queueManager.addUpload(
      filePath: filePath,
      file: file,
      maxRetryAttempts: maxRetryAttempts,
    );

    // Start progress tracking
    _progressTracker.startTracking(filePath);

    // Initialize cancellation token
    _cancellationTokens[filePath] = false;

    try {
      // Execute upload with retry logic
      final result = await _executeUploadWithRetry(
        file: file,
        userId: userId,
        onProgress: onProgress,
      );

      return result;
    } finally {
      // Cleanup
      _progressTracker.stopTracking(filePath);
      _cancellationTokens.remove(filePath);
    }
  }

  /// Execute upload with automatic retry on failure
  Future<UploadResult> _executeUploadWithRetry({
    required File file,
    required String userId,
    void Function(ImageUploadStatus)? onProgress,
  }) async {
    final filePath = file.path;
    var currentStatus = _queueManager.getStatus(filePath);

    if (currentStatus == null) {
      return UploadResult.failure(
        'Upload not in queue',
        ImageUploadErrorType.unknown,
      );
    }

    // Retry loop
    while (true) {
      // Refetch current status at start of each iteration
      currentStatus = _queueManager.getStatus(filePath);
      if (currentStatus == null) {
        return UploadResult.failure(
          'Upload removed from queue',
          ImageUploadErrorType.unknown,
        );
      }

      // Check cancellation
      if (_cancellationTokens[filePath] == true) {
        AppLogger.info('🆙 UPLOAD_SERVICE: Upload cancelled for $filePath');
        _updateStatus(filePath, ImageUploadState.cancelled);
        return UploadResult.failure(
          'Upload cancelled',
          ImageUploadErrorType.cancelled,
        );
      }

      // If retrying, wait for retry delay
      if (currentStatus.state == ImageUploadState.retrying) {
        await _retryManager.waitForRetryDelay(
          currentStatus.retryDelay ?? Duration.zero,
        );
      }

      // Update status to uploading
      currentStatus = currentStatus.copyWith(
        state: ImageUploadState.uploading,
        uploadStartTime: clock.now(),
      );
      _queueManager.updateStatus(filePath, currentStatus);

      // Attempt upload
      try {
        final uploadResult = await _attemptUpload(
          file: file,
          userId: userId,
          onProgress: (progress) {
            final updatedStatus = _progressTracker.updateProgress(
              currentStatus: _queueManager.getStatus(filePath)!,
              progress: progress,
              fileSize: file.lengthSync(),
            );
            _queueManager.updateStatus(filePath, updatedStatus);
            onProgress?.call(updatedStatus);
          },
        );

        // Success!
        _handleUploadSuccess(filePath, uploadResult.imageUrl);
        return UploadResult.success(
          uploadResult.imageUrl,
          thumbnailUrl: uploadResult.thumbnailUrl,
        );
      } catch (error) {
        // Classify error and handle failure
        final errorType = _retryManager.classifyError(error);
        final shouldRetry = _handleUploadFailure(
          filePath: filePath,
          error: error,
          errorType: errorType,
        );

        if (!shouldRetry) {
          // No more retries, return failure
          return UploadResult.failure(error.toString(), errorType);
        }

        // Prepare for retry
        currentStatus = _queueManager.getStatus(filePath);
        if (currentStatus == null) {
          return UploadResult.failure(
            'Upload removed from queue',
            ImageUploadErrorType.unknown,
          );
        }
      }
    }
  }

  /// Attempt single upload to storage, returning both image URL and thumbnail URL
  Future<ImageUploadResult> _attemptUpload({
    required File file,
    required String userId,
    required void Function(double) onProgress,
  }) async {
    final result = await _storageService.uploadImageFile(
      file,
      userId,
      onProgress: onProgress,
    );

    if (result == null) {
      throw Exception('Storage service returned null URL');
    }

    return result;
  }

  /// Handle successful upload
  void _handleUploadSuccess(String filePath, String url) {
    final status = _queueManager.getStatus(filePath);
    if (status == null) return;

    final completedStatus = status.copyWith(
      url: url,
      state: ImageUploadState.completed,
      progress: 1.0,
    );

    _queueManager.updateStatus(filePath, completedStatus);
    _retryManager.recordSuccess();

    AppLogger.success('✅ UPLOAD_SERVICE: Upload completed for $filePath');

    // Send notification
    _sendNotificationEvent(UploadNotificationEvent(
      trigger: UploadNotificationTrigger.retrySuccess,
      title: AppLocale.current.uploadNotificationComplete,
      message: AppLocale.current.uploadNotificationCompleteBody,
      priority: NotificationPriority.low,
      data: {'filePath': filePath, 'url': url},
      timestamp: clock.now(),
    ));
  }

  /// Handle upload failure and determine if retry should happen
  /// Returns true if should retry, false otherwise
  bool _handleUploadFailure({
    required String filePath,
    required dynamic error,
    required ImageUploadErrorType errorType,
  }) {
    final status = _queueManager.getStatus(filePath);
    if (status == null) return false;

    // Record failure in circuit breaker
    _retryManager.recordFailure(errorType);

    // Update status with error
    final failedStatus = status.copyWith(
      state: ImageUploadState.failed,
      error: error.toString(),
      errorType: errorType,
      errorOccurredAt: clock.now(),
    );
    _queueManager.updateStatus(filePath, failedStatus);

    AppLogger.error(
      '❌ UPLOAD_SERVICE: Upload failed for $filePath (${errorType.name}): $error',
    );

    // Check if should retry
    final shouldRetry = _retryManager.shouldRetry(failedStatus);

    if (shouldRetry) {
      // Prepare for retry
      final retryStatus = _retryManager.prepareRetry(failedStatus);
      _queueManager.updateStatus(filePath, retryStatus);

      AppLogger.info(
        '🔄 UPLOAD_SERVICE: Will retry upload for $filePath (attempt ${retryStatus.retryAttempts}/${retryStatus.maxRetryAttempts})',
      );

      return true;
    } else {
      AppLogger.warning(
        '❌ UPLOAD_SERVICE: No more retries for $filePath',
      );

      // Send failure notification
      _sendNotificationEvent(UploadNotificationEvent(
        trigger: UploadNotificationTrigger.majorFailure,
        title: AppLocale.current.uploadNotificationFailed,
        message: AppLocale.current.uploadNotificationFailedBody,
        priority: NotificationPriority.high,
        data: {'filePath': filePath, 'error': error.toString()},
        timestamp: clock.now(),
      ));

      return false;
    }
  }

  /// Update upload status
  void _updateStatus(String filePath, ImageUploadState newState) {
    final status = _queueManager.getStatus(filePath);
    if (status != null) {
      _queueManager.updateStatus(filePath, status.copyWith(state: newState));
    }
  }

  /// Get upload status for a file
  ImageUploadStatus? getUploadStatus(String filePath) =>
      _queueManager.getStatus(filePath);

  /// Get all uploads in queue
  Map<String, ImageUploadStatus> getAllUploads() => _queueManager.allUploads;

  /// Get queue summary
  Map<String, dynamic> getQueueSummary() => _queueManager.getSummary();

  /// Cancel upload
  void cancelUpload(String filePath) {
    _cancellationTokens[filePath] = true;
    AppLogger.info('🆙 UPLOAD_SERVICE: Cancellation requested for $filePath');
  }

  /// Upload image from raw bytes with specified storage prefix.
  /// Use for web uploads (where dart:io File doesn't work) and avatar uploads.
  Future<UploadResult> uploadImageFromBytes({
    required Uint8List bytes,
    required String userId,
    required String fileName,
    String prefix = 'recipe',
  }) async {
    AppLogger.info(
        '🆙 UPLOAD_SERVICE: Starting $prefix bytes upload for $fileName');

    try {
      if (bytes.isEmpty) {
        return UploadResult.failure(
          'Image bytes are empty',
          ImageUploadErrorType.unknown,
        );
      }

      // Bytes upload is idempotent — same userId+fileName+prefix maps to the
      // same storage path, so retrying overwrites rather than duplicating.
      // Wrap with withRetry so transient network glitches don't bubble up to
      // the UI as hard failures (the File-based path uses UploadRetryManager
      // for the same reason, but this path bypasses that machinery).
      final url = await withRetry<String?>(
        () => _storageService.uploadImageBytes(
          bytes,
          userId,
          fileName,
          prefix: prefix,
        ),
        maxAttempts: 3,
      );

      if (url == null) {
        return UploadResult.failure(
          'Storage service returned null URL',
          ImageUploadErrorType.unknown,
        );
      }

      AppLogger.success('✅ $prefix image uploaded: $url');
      return UploadResult.success(url);
    } catch (e) {
      AppLogger.error('❌ $prefix image upload failed: $e');
      return UploadResult.failure(
        e.toString(),
        ImageUploadErrorType.unknown,
      );
    }
  }

  /// Retry failed upload
  Future<UploadResult> retryUpload({
    required String filePath,
    required String userId,
    void Function(ImageUploadStatus)? onProgress,
  }) async {
    final status = _queueManager.getStatus(filePath);
    if (status == null || status.file == null) {
      return UploadResult.failure(
        'Upload not found in queue',
        ImageUploadErrorType.unknown,
      );
    }

    return await uploadImage(
      file: status.file!,
      userId: userId,
      maxRetryAttempts: status.maxRetryAttempts,
      onProgress: onProgress,
    );
  }

  /// Clear completed uploads from queue
  void clearCompleted() {
    _queueManager.removeByState(ImageUploadState.completed);
  }

  /// Clear all uploads
  void clearAll() {
    _queueManager.clearAll();
    _progressTracker.clearAll();
    _cancellationTokens.clear();
  }

  /// Send notification event
  void _sendNotificationEvent(UploadNotificationEvent event) {
    _notificationController.add(event);
  }

  /// Dispose resources
  @override
  Future<void> onDispose() async {
    _notificationController.close();
  }
}
