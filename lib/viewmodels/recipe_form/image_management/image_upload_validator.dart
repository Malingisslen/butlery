// lib/viewmodels/recipe_form/image_management/image_upload_validator.dart

import 'dart:async';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/upload/upload_models.dart';

/// Validates upload safety and prevents data corruption from race conditions.
/// **Responsibilities:**
/// - Upload safety checks (prevent saving with pending uploads)
/// - Image format and size validation
/// - Concurrent upload prevention
/// - Upload completion monitoring
/// - Cleanup of pending/failed uploads
/// **Used by:** RecipeImageManager for pre-save validation
class ImageUploadValidator {
  /// Maximum image size in bytes (5MB)
  static const int maxImageSizeBytes = 5 * 1024 * 1024;

  /// Supported image formats
  static const List<String> validImageExtensions = [
    '.jpg',
    '.jpeg',
    '.png',
    '.gif',
    '.webp'
  ];

  /// Check if it's safe to save recipe without losing pending uploads
  /// HIGH PRIORITY FIX: Prevent data corruption from race conditions
  UploadSafetyResult checkUploadSafety(
      Map<String, ImageUploadStatus> imageStates) {
    final List<String> pendingImagePaths = [];
    final List<String> failedImagePaths = [];

    // Check comprehensive state tracking
    for (final entry in imageStates.entries) {
      final status = entry.value;
      switch (status.state) {
        case ImageUploadState.pending:
        case ImageUploadState.uploading:
        case ImageUploadState.retrying:
          pendingImagePaths.add(entry.key);
          break;
        case ImageUploadState.failed:
        case ImageUploadState.cancelled:
          failedImagePaths.add(entry.key);
          break;
        case ImageUploadState.completed:
          // Safe to save
          break;
      }
    }

    final isSafe = pendingImagePaths.isEmpty && failedImagePaths.isEmpty;

    AppLogger.info(
        'Upload safety check: Safe=$isSafe, Pending=${pendingImagePaths.length}, Failed=${failedImagePaths.length}');

    return UploadSafetyResult(
      isSafe: isSafe,
      pendingImagePaths: pendingImagePaths,
      failedImagePaths: failedImagePaths,
    );
  }

  /// Wait for all pending uploads to complete or timeout
  /// Returns true if all uploads completed successfully
  Future<bool> waitForUploadsToComplete({
    required Map<String, ImageUploadStatus> imageStates,
    Duration? timeout,
  }) async {
    final timeoutDuration = timeout ?? const Duration(minutes: 2);
    final startTime = DateTime.now();

    AppLogger.info(
        'Waiting for uploads to complete (timeout: ${timeoutDuration.inSeconds}s)');

    while (true) {
      final safetyCheck = checkUploadSafety(imageStates);

      if (safetyCheck.isSafe) {
        AppLogger.info('All uploads completed successfully');
        return true;
      }

      // Check timeout
      if (DateTime.now().difference(startTime) > timeoutDuration) {
        AppLogger.warning('Upload wait timeout reached');
        return false;
      }

      // Wait a bit before checking again
      await Future.delayed(const Duration(milliseconds: 500));
    }
  }

  /// Get list of keys for images that should be removed (not completed)
  /// Used when user chooses to save without pending/failed images
  List<String> getPendingAndFailedImageKeys(
      Map<String, ImageUploadStatus> imageStates) {
    final toRemove = <String>[];

    // Find all non-completed images
    for (final entry in imageStates.entries) {
      final status = entry.value;
      if (status.state != ImageUploadState.completed) {
        toRemove.add(entry.key);
      }
    }

    return toRemove;
  }

  /// Validate image format
  /// Returns true if the image URL has a valid image extension
  bool isValidImageFormat(String imageUrl) {
    final lowercaseUrl = imageUrl.toLowerCase();
    return validImageExtensions.any((ext) => lowercaseUrl.contains(ext));
  }

  /// Validate image size
  /// Returns true if image is under maximum size (5MB)
  Future<bool> isValidImageSize(XFile imageFile) async {
    try {
      final fileSize = await imageFile.length();
      return fileSize <= maxImageSizeBytes;
    } catch (e) {
      AppLogger.error('Fel vid validering av bildstorlek: $e');
      return true; // Continue if we can't validate
    }
  }

  /// Check if image URL is a Firebase Storage URL
  bool isFirebaseUrl(String url) {
    return url.startsWith('https://firebasestorage.googleapis.com/');
  }

  /// Check if image URL is a local file path
  bool isLocalFilePath(String url) {
    return url.startsWith('/') ||
        url.startsWith('file://') ||
        url.contains('blob:'); // Web blob URLs
  }

  /// Validate that image URL is displayable (either local file or uploaded URL)
  bool isDisplayableImage(String url) {
    return isFirebaseUrl(url) || isLocalFilePath(url);
  }

  /// Get validation summary for debugging
  Map<String, dynamic> getValidationSummary(
      Map<String, ImageUploadStatus> imageStates) {
    final safetyResult = checkUploadSafety(imageStates);

    return {
      'isSafe': safetyResult.isSafe,
      'pendingCount': safetyResult.pendingImagePaths.length,
      'failedCount': safetyResult.failedImagePaths.length,
      'completedCount': imageStates.values
          .where((s) => s.state == ImageUploadState.completed)
          .length,
      'totalImages': imageStates.length,
    };
  }
}
