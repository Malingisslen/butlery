// lib/viewmodels/recipe_form/image_management/image_upload_coordinator.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/core/utils/error_sanitizer.dart';
import 'package:butlery/core/utils/logger.dart';

/// Coordinates bulk image upload operations with thread-safe cancellation support.
/// **Responsibilities:**
/// - Bulk upload coordination with progress tracking
/// - Cancellable upload operations with proper resource management
/// - Retry coordination for failed uploads
/// - Upload queue management and status tracking
/// **Thread Safety:**
/// - Safe disposal handling for long-running operations
/// - Cancellation support for in-flight uploads
/// - Proper cleanup of pending operations
/// **Dependencies:**
/// - StorageService: Image upload backend
/// - ImageUploadStatus: State tracking models
class ImageUploadCoordinator {
  final StorageService _storageService;

  // Active upload tracking
  final Set<_CancellableUploadOperation> _activeUploads = {};

  /// Maps imageUrl → thumbnailUrl from the most recent upload batch.
  /// Cleared at the start of each upload batch.
  final Map<String, String> _thumbnailUrls = {};
  Map<String, String> get thumbnailUrls => Map.unmodifiable(_thumbnailUrls);

  // Callbacks for state synchronization
  final void Function() _notifyListeners;
  final void Function(String error) _setError;
  final void Function() _checkCompletionEvents;

  ImageUploadCoordinator({
    required StorageService storageService,
    required VoidCallback notifyListeners,
    required void Function(String) setError,
    required VoidCallback checkCompletionEvents,
  }) : _storageService = storageService,
       _notifyListeners = notifyListeners,
       _setError = setError,
       _checkCompletionEvents = checkCompletionEvents;

  /// CRITICAL FIX: Thread-safe bulk upload with cancellation support and progress tracking.
  /// Uploads all pending images in parallel with coordinated progress reporting,
  /// proper cancellation handling, and disposal safety for long-running operations.
  /// Returns list of successfully uploaded Firebase Storage URLs.
  /// Empty list returned if uploads canceled, disposed, or no pending images.
  /// **Upload Process:**
  /// - Create cancellable operation group for coordinated cancellation
  /// - Start parallel uploads with individual progress tracking
  /// - Wait for all uploads with proper error isolation
  /// - Return only successful URLs, filtering failed operations
  Future<List<String>> uploadPendingImagesInBackground(
    List<File> pendingImages,
    String recipeId, {
    required Map<String, ImageUploadStatus> imageStates,
    required bool Function() isDisposedNow,
    required bool Function() isUploadsCanceledNow,
    Function(int completed, int total)? onProgress,
  }) async {
    // BUT-1129: closures re-read live caller state on every check so a
    // mid-flight soft-cancel (caller flips its `_disposed` / `_uploadsCanceled`
    // bool without calling `dispose()`) actually short-circuits in-flight work.
    if (isDisposedNow() || isUploadsCanceledNow()) {
      AppLogger.info(
        '☁️ Upload canceled - manager disposed or uploads canceled',
      );
      return [];
    }

    if (pendingImages.isEmpty) {
      AppLogger.info('☁️ No pending images to upload');
      return [];
    }

    AppLogger.info(
      '🚀 Starting thread-safe upload of ${pendingImages.length} pending images',
    );
    _thumbnailUrls.clear();
    final List<String> uploadedUrls = [];
    int completed = 0;
    final total = pendingImages.length;

    final operationGroup = _UploadOperationGroup();

    try {
      final uploadOperations = pendingImages.map((file) {
        final operation = _CancellableUploadOperation(
          file: file,
          recipeId: recipeId,
          onProgress: () {
            completed++;
            onProgress?.call(completed, total);
          },
          uploadFunction: (file, recipeId) => _uploadSingleImageWithTracking(
            file,
            recipeId,
            imageStates,
            isDisposedNow: isDisposedNow,
            isUploadsCanceledNow: isUploadsCanceledNow,
            onComplete: () {},
          ),
        );

        operationGroup.addOperation(operation);
        _activeUploads.add(operation);
        return operation;
      }).toList();

      final uploadFutures = uploadOperations.map((op) => op.start());
      final results = await Future.wait(uploadFutures, eagerError: false);
      final successfulUrls = results
          .where((url) => url != null)
          .cast<String>()
          .toList();

      AppLogger.info(
        '✅ Completed ${successfulUrls.length}/$total uploads successfully',
      );
      return successfulUrls;
    } catch (e) {
      // BUT-1128: surface the actual cause (network / auth / timeout / quota)
      // via the sanitizer instead of collapsing every fatal-batch failure to
      // "Ett fel uppstod". The per-file path already records typed errors;
      // this is the global sink and was the only lossy one.
      AppLogger.error('❌ Fatal error during upload: $e');
      _setError(sanitizeErrorForUser(e));
      return uploadedUrls;
    } finally {
      operationGroup.dispose();
      _notifyListeners();
    }
  }

  /// CRITICAL FIX: Upload single image with proper disposal tracking and state management.
  /// Uploads single image to Firebase Storage with comprehensive state tracking,
  /// cancellation checks, and disposal safety throughout the upload lifecycle.
  /// Returns Firebase Storage URL if successful, null if failed or canceled.
  /// **Upload Lifecycle:**
  /// - Pre-upload cancellation check
  /// - State update to uploading with listener notification
  /// - Actual upload to Firebase Storage
  /// - Post-upload cancellation check
  /// - Success: Update state with URL, trigger completion callback
  /// - Failure: Update state with error, log failure details
  Future<String?> _uploadSingleImageWithTracking(
    File file,
    String recipeId,
    Map<String, ImageUploadStatus> imageStates, {
    required bool Function() isDisposedNow,
    required bool Function() isUploadsCanceledNow,
    VoidCallback? onComplete,
  }) async {
    final filePath = file.path;

    try {
      // CRITICAL FIX: Check cancellation before each operation
      if (isDisposedNow() || isUploadsCanceledNow()) {
        AppLogger.info('☁️ Upload canceled for ${file.path}');
        return null;
      }

      // Update state to uploading
      if (imageStates.containsKey(filePath)) {
        imageStates[filePath] = imageStates[filePath]!.copyWith(
          state: ImageUploadState.uploading,
        );

        if (!isDisposedNow()) {
          _notifyListeners();
        }
      }

      // CRITICAL FIX: Check cancellation before actual upload
      if (isDisposedNow() || isUploadsCanceledNow()) {
        AppLogger.info(
          '☁️ Upload canceled during state update for ${file.path}',
        );
        return null;
      }

      final result = await _storageService.uploadRecipeImage(file, recipeId);

      // CRITICAL FIX: Check cancellation after upload completes
      if (isDisposedNow() || isUploadsCanceledNow()) {
        AppLogger.info(
          '☁️ Upload canceled after completion for ${file.path} - ignoring result',
        );
        return null;
      }

      final imageUrl = result?.imageUrl;
      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Track thumbnail URL if available
        if (result?.thumbnailUrl != null) {
          _thumbnailUrls[imageUrl] = result!.thumbnailUrl!;
        }

        // Update state to completed with URL
        imageStates.remove(filePath);
        imageStates[imageUrl] = ImageUploadStatus(
          url: imageUrl,
          state: ImageUploadState.completed,
          progress: 1.0,
        );

        onComplete?.call();

        AppLogger.info('✅ Uploaded ${file.path} -> $imageUrl');
        return imageUrl;
      } else {
        // Update state to failed
        if (imageStates.containsKey(filePath)) {
          imageStates[filePath] = imageStates[filePath]!.copyWith(
            state: ImageUploadState.failed,
            error: 'Upload failed',
          );
        }

        AppLogger.error('❌ Failed to upload ${file.path}');
        return null;
      }
    } catch (e) {
      // Update state to failed with error
      if (imageStates.containsKey(filePath) &&
          !isDisposedNow() &&
          !isUploadsCanceledNow()) {
        imageStates[filePath] = imageStates[filePath]!.copyWith(
          state: ImageUploadState.failed,
          error: e.toString(),
        );
      }

      AppLogger.error('❌ Error uploading ${file.path}: $e');
      return null;
    }
  }

  /// Retry all failed uploads that can be retried with bulk coordination.
  /// Iterates through all failed uploads with retry capability and attempts
  /// re-upload with proper error isolation to prevent cascading failures.
  Future<void> retryAllFailedUploads({
    required Map<String, ImageUploadStatus> failedUploads,
    required Future<void> Function(String) retryFailedUpload,
  }) async {
    if (failedUploads.isEmpty) {
      AppLogger.info('🔄 BULK_RETRY: No retryable failed uploads found');
      return;
    }

    AppLogger.info(
      '🔄 BULK_RETRY: Starting bulk retry for ${failedUploads.length} failed uploads',
    );

    // Retry each failed upload
    final retryFutures = failedUploads.keys.map(
      (pathOrUrl) => retryFailedUpload(pathOrUrl).catchError((error) {
        AppLogger.error('🔄 BULK_RETRY: Error retrying $pathOrUrl: $error');
      }),
    );

    await Future.wait(retryFutures);
    AppLogger.info('🔄 BULK_RETRY: Bulk retry completed');
  }

  /// Cancel all active uploads with coordinated cleanup.
  /// Stops all in-progress uploads and removes them from tracking state
  /// with proper notification of cancellation to UI layer.
  void cancelAllActiveUploads({
    required Map<String, ImageUploadStatus> activeUploads,
    required void Function(String) removeImageAndCleanup,
  }) {
    if (activeUploads.isEmpty) {
      AppLogger.info('🔄 BULK_CANCEL: No active uploads to cancel');
      return;
    }

    AppLogger.info(
      '🔄 BULK_CANCEL: Cancelling ${activeUploads.length} active uploads',
    );

    for (final pathOrUrl in activeUploads.keys) {
      removeImageAndCleanup(pathOrUrl);
    }
  }

  /// Clear all failed uploads from state with notification coordination.
  /// Removes all failed upload entries from state and triggers completion
  /// event checks to update UI with cleaned state.
  void clearAllFailedUploads({
    required Map<String, ImageUploadStatus> imageStates,
    required Map<String, ImageUploadStatus> failedUploads,
  }) {
    if (failedUploads.isEmpty) {
      AppLogger.info('🔄 BULK_CLEAR: No failed uploads to clear');
      return;
    }

    AppLogger.info(
      '🔄 BULK_CLEAR: Clearing ${failedUploads.length} failed uploads',
    );

    for (final pathOrUrl in failedUploads.keys) {
      imageStates.remove(pathOrUrl);
    }

    _notifyListeners();
    _checkCompletionEvents();
  }

  /// Get upload management summary for UI display with comprehensive statistics.
  /// Returns map containing:
  /// - failed: Count of failed uploads
  /// - active: Count of active uploads
  /// - completed: Count of completed uploads
  /// - total: Total upload count
  /// - hasRetryableFailures: Whether retryable failures exist
  /// - hasActiveUploads: Whether active uploads exist
  /// - canBulkRetry: Whether bulk retry UI should be shown
  /// - canBulkCancel: Whether bulk cancel UI should be shown
  Map<String, dynamic> getUploadManagementSummary({
    required Map<String, ImageUploadStatus> imageStates,
    required Map<String, ImageUploadStatus> failedUploads,
    required Map<String, ImageUploadStatus> activeUploads,
  }) {
    final failed = failedUploads.length;
    final active = activeUploads.length;
    final total = imageStates.length;
    final completed = imageStates.values
        .where((s) => s.state == ImageUploadState.completed)
        .length;

    return {
      'failed': failed,
      'active': active,
      'completed': completed,
      'total': total,
      'hasRetryableFailures': failed > 0,
      'hasActiveUploads': active > 0,
      // BUT-1127: show bulk retry whenever there's something to retry.
      'canBulkRetry': failed >= 1,
      // BUT-1127: show bulk cancel whenever there's something in-flight to cancel.
      'canBulkCancel': active >= 1,
    };
  }

  /// Dispose coordinator and cancel all active upload operations.
  /// Cancels all in-flight uploads and clears tracking state for proper cleanup.
  void dispose() {
    // Cancel all active operations
    for (final operation in _activeUploads) {
      operation.cancel();
    }
    _activeUploads.clear();
  }
}

/// CRITICAL FIX: Cancellable upload operation with proper resource management.
/// Wraps individual upload operations with cancellation support, completion tracking,
/// and proper cleanup for thread-safe bulk upload coordination.
class _CancellableUploadOperation {
  final File file;
  final String recipeId;
  final VoidCallback? onProgress;
  final Future<String?> Function(File, String) uploadFunction;

  bool _isCancelled = false;
  bool _isCompleted = false;
  Completer<String?>? _completer;

  _CancellableUploadOperation({
    required this.file,
    required this.recipeId,
    this.onProgress,
    required this.uploadFunction,
  });

  /// Start the upload operation with cancellation support.
  /// Returns uploaded URL if successful, null if cancelled or failed.
  Future<String?> start() async {
    if (_isCancelled) {
      return null;
    }

    _completer = Completer<String?>();

    try {
      // Start the actual upload
      final result = await uploadFunction(file, recipeId);

      if (_isCancelled) {
        _completer!.complete(null);
        return null;
      }

      _isCompleted = true;
      onProgress?.call();
      _completer!.complete(result);
      return result;
    } catch (e) {
      if (!_isCancelled && !_completer!.isCompleted) {
        _completer!.complete(null);
      }
      return null;
    }
  }

  /// Cancel the upload operation with safe cleanup.
  /// Marks operation as cancelled and completes completer if still pending.
  void cancel() {
    if (_isCompleted) return;

    _isCancelled = true;
    if (_completer != null && !_completer!.isCompleted) {
      _completer!.complete(null);
    }
  }

  bool get isCancelled => _isCancelled;
  bool get isCompleted => _isCompleted;
}

/// CRITICAL FIX: Upload operation group for coordinated cancellation.
/// Manages multiple upload operations as a single unit with coordinated
/// cancellation and disposal for proper bulk upload resource management.
class _UploadOperationGroup {
  final List<_CancellableUploadOperation> _operations = [];
  bool _isDisposed = false;

  /// Add operation to group for coordinated management.
  void addOperation(_CancellableUploadOperation operation) {
    if (_isDisposed) return;
    _operations.add(operation);
  }

  /// Cancel all operations in the group.
  void cancelAll() {
    for (final operation in _operations) {
      operation.cancel();
    }
  }

  /// Dispose group and cancel all pending operations.
  void dispose() {
    _isDisposed = true;
    cancelAll();
    _operations.clear();
  }

  /// Get count of active (not completed, not cancelled) operations.
  int get activeCount =>
      _operations.where((op) => !op.isCompleted && !op.isCancelled).length;

  /// Get count of completed operations.
  int get completedCount => _operations.where((op) => op.isCompleted).length;

  /// Get count of cancelled operations.
  int get cancelledCount => _operations.where((op) => op.isCancelled).length;
}
