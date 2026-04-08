// lib/viewmodels/recipe_form/image_management/xfile_upload_handler.dart

import 'dart:io';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:butlery/core/constants/upload_constants.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/permission_service.dart' as permission;
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';

/// Handles XFile processing and web blob URL uploads.
/// Extracted from RecipeImageManager for better separation of concerns.
///
/// **Responsibilities:**
/// - Process XFile objects from image picker
/// - Handle web blob URLs that can't be converted to File
/// - Upload XFiles with web platform support
/// - Manage XFile references for pending uploads
///
/// **Web Platform Support:**
/// - Blob URLs (blob:http://...) require special handling
/// - XFile must be stored for later upload (no File conversion)
/// - File size validation works via XFile.length()
class XFileUploadHandler {
  final ImageUploadService _uploadService;
  final Map<String, XFile> _pendingXFiles = {};

  XFileUploadHandler({
    ImageUploadService? uploadService,
  }) : _uploadService =
            uploadService ?? ServiceLocator.get<ImageUploadService>();

  /// Unmodifiable view of pending XFiles for state queries
  Map<String, XFile> get pendingXFiles => Map.unmodifiable(_pendingXFiles);

  /// Get pending XFile by path
  XFile? getPendingXFile(String path) => _pendingXFiles[path];

  /// Check if path has pending XFile
  bool hasPendingXFile(String path) => _pendingXFiles.containsKey(path);

  /// Remove pending XFile reference
  void removePendingXFile(String path) {
    _pendingXFiles.remove(path);
  }

  /// Clear all pending XFile references
  void clearPendingXFiles() {
    _pendingXFiles.clear();
  }

  /// Process single XFile with proper web blob URL handling.
  /// Returns processing result with file path and whether it's a blob URL.
  Future<XFileProcessResult> processSingleXFile(XFile xFile) async {
    AppLogger.info('🖼️ WEB_FIX: Processing XFile: ${xFile.path}');

    // Check if this is a web blob URL (needs special handling)
    if (xFile.path.startsWith('blob:')) {
      AppLogger.info(
          '🌐 WEB_FIX: Blob URL detected, using XFile directly for display');
      return XFileProcessResult(
        filePath: xFile.path,
        isBlobUrl: true,
        xFile: xFile,
      );
    } else {
      // Mobile platform - normal file path, create File object
      AppLogger.info('📱 MOBILE: Normal file path, creating File object');
      return XFileProcessResult(
        filePath: xFile.path,
        isBlobUrl: false,
        file: File(xFile.path),
      );
    }
  }

  /// Validate XFile size for web platform.
  /// Returns null if valid, error message if invalid.
  Future<String?> validateXFileSize(XFile xFile,
      {int maxSizeBytes = UploadConstants.maxRecipeImageBytes}) async {
    try {
      final fileSize = await xFile.length();
      if (fileSize > maxSizeBytes) {
        final maxSizeMB = maxSizeBytes / (1024 * 1024);
        return AppLocale.current
            .imageUploadTooLarge(maxSizeMB.toStringAsFixed(0));
      }
      return null;
    } catch (e) {
      AppLogger.error('🌐 WEB_FIX: Could not validate file size: $e');
      return null; // Allow upload attempt if size check fails
    }
  }

  /// Create pending status for XFile (blob URL).
  /// Stores XFile reference for later upload.
  ImageUploadStatus createPendingXFileStatus(XFile xFile) {
    final filePath = xFile.path;

    // Store XFile reference for later upload
    _pendingXFiles[filePath] = xFile;

    return const ImageUploadStatus(
      state: ImageUploadState.pending,
      progress: 0.0,
    );
  }

  /// Create uploading status for XFile with file size.
  Future<ImageUploadStatus> createUploadingXFileStatus(
    XFile xFile, {
    int retryAttempts = 0,
    int maxRetryAttempts = 3,
  }) async {
    final fileSize = await xFile.length();
    final startTime = DateTime.now();

    return ImageUploadStatus(
      state: ImageUploadState.uploading,
      progress: 0.0,
      totalBytes: fileSize,
      uploadStartTime: startTime,
      retryAttempts: retryAttempts,
      maxRetryAttempts: maxRetryAttempts,
    );
  }

  /// Create completed status after successful XFile upload.
  ImageUploadStatus createCompletedXFileStatus(
    String uploadedUrl, {
    int? totalBytes,
  }) {
    return ImageUploadStatus(
      url: uploadedUrl,
      state: ImageUploadState.completed,
      progress: 1.0,
      totalBytes: totalBytes,
      bytesTransferred: totalBytes,
    );
  }

  /// Create failed status for XFile upload.
  ImageUploadStatus createFailedXFileStatus(
    String errorMessage, {
    double progress = 0.0,
  }) {
    return ImageUploadStatus(
      state: ImageUploadState.failed,
      error: errorMessage,
      errorOccurredAt: DateTime.now(),
      progress: progress,
    );
  }

  /// Upload XFile with web platform support (handles blob URLs).
  /// Returns uploaded URL if successful, null if failed.
  Future<String?> uploadXFile(XFile xFile, String recipeId) async {
    try {
      AppLogger.info(
          '🌐 WEB_FIX: Uploading XFile with web support: ${xFile.path}');

      // Get authenticated user ID
      final userId =
          ServiceLocator.get<permission.PermissionService>().currentUserId;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      // Web: blob URLs can't be read by dart:io File — use XFile.readAsBytes()
      if (kIsWeb || xFile.path.startsWith('blob:')) {
        final bytes = await xFile.readAsBytes();
        final result = await _uploadService.uploadImageFromBytes(
          bytes: bytes,
          userId: userId,
          fileName: xFile.name,
        );
        AppLogger.info('🌐 WEB_FIX: Web upload result: ${result.url}');
        return result.success ? result.url : null;
      }

      // Mobile: use File-based upload
      final file = File(xFile.path);
      final result = await _uploadService.uploadImage(
        file: file,
        userId: userId,
      );

      AppLogger.info('🌐 WEB_FIX: Upload result: ${result.url}');
      return result.success ? result.url : null;
    } catch (e) {
      AppLogger.error('🌐 WEB_FIX: Upload failed: $e');
      return null;
    }
  }

  /// Get XFile size in bytes.
  Future<int> getXFileSize(XFile xFile) async {
    return await xFile.length();
  }
}

/// Result of processing a single XFile.
class XFileProcessResult {
  final String filePath;
  final bool isBlobUrl;
  final XFile? xFile;
  final File? file;

  const XFileProcessResult({
    required this.filePath,
    required this.isBlobUrl,
    this.xFile,
    this.file,
  });
}
