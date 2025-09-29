// lib/viewmodels/recipe_form/recipe_image_manager.dart

import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/widgets/image/image_picker_dialogs.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/services/permission_service.dart' as permission;

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

/// User choice for handling pending uploads during save
enum UploadChoice { wait, saveWithoutPending, cancel }

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

/// Upload notification triggers for background notifications
enum UploadNotificationTrigger {
  allCompleted, // All uploads completed successfully
  majorFailure, // Multiple uploads failed
  significantProgress, // 25%, 50%, 75% completion milestones
  queueCleared, // Upload queue became empty
  retrySuccess, // Failed upload succeeded on retry
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

/// Notification priority levels for upload events
enum NotificationPriority { low, medium, high, critical }

/// Circuit breaker state for preventing cascading failures
class CircuitBreakerState {
  final int failureCount;
  final DateTime? lastFailureTime;
  final bool isOpen;

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
      isOpen: failureCount + 1 >=
          RecipeImageManager._circuitBreakerFailureThreshold,
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

/// Manages image operations for recipe forms
class RecipeImageManager extends ChangeNotifier with StreamManagementMixin {
  final StorageService _storageService;
  final ImagePickerService _imagePickerService;

  // ===== DISPOSAL TRACKING =====
  bool _disposed = false;
  bool get disposed => _disposed;

  // CRITICAL FIX: Thread-safe upload operation coordination
  final Set<_CancellableUploadOperation> _activeUploads =
      <_CancellableUploadOperation>{};
  bool _uploadsCanceled = false;

  // CRITICAL FIX: State synchronization to prevent race conditions
  bool _isStateUpdating = false;
  final List<VoidCallback> _pendingStateUpdates = [];

  // CRITICAL FIX: Notification coordination with disposal protection
  bool _isNotifying = false;
  Timer? _notificationDebounceTimer;

  // HIGH PRIORITY FIX: Comprehensive state tracking to prevent race conditions
  final Map<String, ImageUploadStatus> _imageStates =
      {}; // Complete state tracking system

  // WEB FIX: Store XFile references for blob URL handling
  final Map<String, XFile> _pendingXFiles =
      {}; // Maps blob URL paths to XFile objects

  String? _temporaryRecipeId; // Temporary ID for immediate uploads

  bool _isUploadingImage = false;
  String? _imageUploadError;

  // Enhanced retry system dependencies
  static final Random _random =
      Random(); // Shared Random instance for jitter calculations

  // Circuit breaker for preventing excessive retry attempts
  final Map<ImageUploadErrorType, CircuitBreakerState> _circuitBreakers = {};
  static const Duration _circuitBreakerResetTime = Duration(minutes: 5);
  static const int _circuitBreakerFailureThreshold =
      10; // Open circuit after 10 failures

  // Background notification system
  final Set<UploadNotificationTrigger> _notificationTriggers = {};
  DateTime? _lastNotificationTime;
  static const Duration _notificationCooldown =
      Duration(seconds: 3); // Prevent notification spam

  static const int maxImages = 5;

  RecipeImageManager({
    StorageService? storageService,
    ImagePickerService? imagePickerService,
  })  : _storageService =
            storageService ?? ServiceLocator.get<StorageService>(),
        _imagePickerService =
            imagePickerService ?? ServiceLocator.get<ImagePickerService>();

  // ===== GETTERS =====

  /// Combined list of all images for UI display
  List<String> get imageUrls {
    final List<String> allImages = [];

    for (final status in _imageStates.values) {
      if (status.isDisplayable) {
        allImages.add(status.displayPath);
      }
    }

    return allImages;
  }

  /// Get only valid Firebase URLs for recipe persistence
  List<String> get validImageUrls {
    final List<String> validUrls = [];

    for (final status in _imageStates.values) {
      if (status.isPersistable) {
        validUrls.add(status.url!);
      }
    }

    return validUrls;
  }

  /// Get pending files for background upload during save
  List<File> get pendingImages {
    final List<File> pending = [];

    for (final status in _imageStates.values) {
      if (status.file != null && status.state == ImageUploadState.pending) {
        pending.add(status.file!);
      }
    }

    return pending;
  }

  /// Get uploaded URLs for recipe persistence
  List<String> get uploadedImageUrls => validImageUrls;

  /// Check if any images are currently being uploaded
  bool get isUploadingImage {
    return _isUploadingImage ||
        _imageStates.values
            .any((status) => status.state == ImageUploadState.uploading);
  }

  String? get imageUploadError => _imageUploadError;
  bool get hasImageUploadError => _imageUploadError != null;

  /// Get upload progress for a specific file path
  double getUploadProgress(String filePath) =>
      _imageStates[filePath]?.progress ?? 0.0;

  /// Check if a file is currently uploading
  bool isFileUploading(String filePath) =>
      _imageStates[filePath]?.state == ImageUploadState.uploading;

  bool get canAddMoreImages => totalImageCount < maxImages;
  int get remainingImageSlots => maxImages - totalImageCount;

  /// Total count of all images
  int get totalImageCount => _imageStates.length;

  /// Individual image upload statuses for UI progress display and error handling
  Map<String, ImageUploadStatus> get imageUploadStatuses =>
      Map.unmodifiable(_imageStates);

  /// Get failed uploads for bulk retry management
  Map<String, ImageUploadStatus> get failedUploads {
    return Map.unmodifiable(
      Map.fromEntries(
        _imageStates.entries.where((entry) =>
            entry.value.state == ImageUploadState.failed &&
            entry.value.canRetry),
      ),
    );
  }

  /// Get active uploads for management and monitoring
  Map<String, ImageUploadStatus> get activeUploads {
    return Map.unmodifiable(
      Map.fromEntries(
        _imageStates.entries.where((entry) => entry.value.isActive),
      ),
    );
  }

  /// Check if there are retryable failed uploads
  bool get hasRetryableFailures => failedUploads.isNotEmpty;

  // ===== SETTERS =====

  /// Set uploaded image URLs (for loading existing recipes)
  void setUploadedImageUrls(List<String> imageUrls) {
    _imageStates.clear();

    for (int i = 0; i < imageUrls.length; i++) {
      final url = imageUrls[i];
      _imageStates[url] = ImageUploadStatus(
        url: url,
        state: ImageUploadState.completed,
        progress: 1.0,
      );
    }

    notifyListeners();
  }

  /// Legacy method for backwards compatibility
  void setImageUrls(List<String> imageUrls) {
    setUploadedImageUrls(imageUrls);
  }

  /// Add pending file for immediate display (no upload yet)
  void addPendingImage(File imageFile) {
    if (canAddMoreImages && !_imageStates.containsKey(imageFile.path)) {
      _imageStates[imageFile.path] = ImageUploadStatus(
        file: imageFile,
        state: ImageUploadState.pending,
        progress: 0.0,
      );
      AppLogger.info('📁 Added pending image: ${imageFile.path}');
      notifyListeners();
    }
  }

  /// Add uploaded URL after successful upload
  void addUploadedImageUrl(String imageUrl) {
    if (!_imageStates.containsKey(imageUrl)) {
      _imageStates[imageUrl] = ImageUploadStatus(
        url: imageUrl,
        state: ImageUploadState.completed,
        progress: 1.0,
      );
      AppLogger.info('☁️ Added uploaded image: $imageUrl');
      notifyListeners();
    }
  }

  /// Remove image by path or URL
  void removeImageByPath(String pathOrUrl) {
    if (_imageStates.remove(pathOrUrl) != null) {
      AppLogger.info('🗑️ Removed image: $pathOrUrl');
      notifyListeners();
    }
  }

  /// Legacy method for backwards compatibility
  void removeImageUrl(String imageUrl) {
    removeImageByPath(imageUrl);
  }

  /// Move image to first position
  void moveImageToFirst(String pathOrUrl) {
    final imageStatus = _imageStates.remove(pathOrUrl);
    if (imageStatus != null) {
      // Create new ordered map with moved image first
      final newStates = <String, ImageUploadStatus>{pathOrUrl: imageStatus};
      newStates.addAll(_imageStates);
      _imageStates.clear();
      _imageStates.addAll(newStates);
      notifyListeners();
    }
  }

  /// Reorder images in list
  void reorderImages(int oldIndex, int newIndex) {
    final imageKeys = _imageStates.keys.toList();
    if (oldIndex >= 0 &&
        oldIndex < imageKeys.length &&
        newIndex >= 0 &&
        newIndex < imageKeys.length &&
        oldIndex != newIndex) {
      final movedKey = imageKeys.removeAt(oldIndex);
      imageKeys.insert(newIndex, movedKey);

      // Rebuild map with new order
      final newStates = <String, ImageUploadStatus>{};
      for (final key in imageKeys) {
        newStates[key] = _imageStates[key]!;
      }

      _imageStates.clear();
      _imageStates.addAll(newStates);
      notifyListeners();
    }
  }

  // ===== IMAGE OPERATIONS =====

  /// Visa image picker dialog och hantera bildval
  Future<void> showImagePickerDialog(BuildContext context,
      {String? recipeId}) async {
    AppLogger.info('🎯 IMAGE_PICKER_FLOW: Starting showImagePickerDialog');

    if (!canAddMoreImages) {
      AppLogger.warning(
          '🎯 IMAGE_PICKER_FLOW: Cannot add more images ($totalImageCount/$maxImages)');
      _setImageUploadError('Du kan bara ha maximalt $maxImages bilder');
      return;
    }

    try {
      _clearImageUploadError();
      AppLogger.info('🎯 IMAGE_PICKER_FLOW: Cleared previous errors');

      // Step 1: Get image source selection (camera/gallery) from dialog
      AppLogger.info(
          '🎯 IMAGE_PICKER_FLOW: Showing ImagePickerDialogs.showImageSourceDialog');
      final imageSource =
          await ImagePickerDialogs.showImageSourceDialog(context);
      AppLogger.info(
          '🎯 IMAGE_PICKER_FLOW: Dialog returned imageSource: $imageSource');

      if (imageSource != null) {
        // Step 2: Use ImagePickerService to actually pick image from selected source
        AppLogger.info(
            '🎯 IMAGE_PICKER_FLOW: Using ImagePickerService to pick image from: ${imageSource.name}');
        final pickedFile = await _imagePickerService.pickImage(imageSource);
        AppLogger.info(
            '🎯 IMAGE_PICKER_FLOW: ImagePickerService returned: $pickedFile');

        if (pickedFile != null) {
          AppLogger.info('🎯 IMAGE_PICKER_FLOW: File path: ${pickedFile.path}');
          // Step 3: Convert File to XFile and process through existing upload pipeline
          final xFile = XFile(pickedFile.path);
          AppLogger.info(
              '🎯 IMAGE_PICKER_FLOW: Created XFile, calling _processImagePickerResult');
          await _processImagePickerResult(xFile, recipeId: recipeId);
          AppLogger.info(
              '🎯 IMAGE_PICKER_FLOW: _processImagePickerResult completed');
        } else {
          AppLogger.warning(
              '🎯 IMAGE_PICKER_FLOW: No image selected from ${imageSource.name}');
          _setImageUploadError('Ingen bild valdes');
        }
      } else {
        AppLogger.info('🎯 IMAGE_PICKER_FLOW: User cancelled dialog');
      }
    } catch (e) {
      AppLogger.error('🎯 IMAGE_PICKER_FLOW: Exception occurred: $e');
      _setImageUploadError('Kunde inte välja bild: $e');
    }

    AppLogger.info('🎯 IMAGE_PICKER_FLOW: showImagePickerDialog completed');
  }

  /// Pick single image from camera directly (no dialog)
  Future<void> pickImageFromCamera(BuildContext context,
      {String? recipeId}) async {
    AppLogger.info('🎯 IMAGE_PICKER_FLOW: Starting pickImageFromCamera');

    if (!canAddMoreImages) {
      AppLogger.warning(
          '🎯 IMAGE_PICKER_FLOW: Cannot add more images ($totalImageCount/$maxImages)');
      _setImageUploadError('Du kan bara ha maximalt $maxImages bilder');
      return;
    }

    try {
      _clearImageUploadError();
      _setUploadingImage(true); // Add loading state
      AppLogger.info(
          '🎯 IMAGE_PICKER_FLOW: Using ImagePickerService to pick image from camera');

      final pickedFile =
          await _imagePickerService.pickImage(ImageSource.camera);
      AppLogger.info(
          '🎯 IMAGE_PICKER_FLOW: ImagePickerService returned: $pickedFile');

      if (pickedFile != null) {
        AppLogger.info('🎯 IMAGE_PICKER_FLOW: File path: ${pickedFile.path}');
        final xFile = XFile(pickedFile.path);
        AppLogger.info(
            '🎯 IMAGE_PICKER_FLOW: Created XFile, calling _processImagePickerResult');
        await _processImagePickerResult(xFile, recipeId: recipeId);
        AppLogger.info(
            '🎯 IMAGE_PICKER_FLOW: _processImagePickerResult completed');
      } else {
        AppLogger.warning(
            '🎯 IMAGE_PICKER_FLOW: No image selected from camera');
        _setImageUploadError('Ingen bild valdes');
      }
    } catch (e) {
      AppLogger.error('🎯 IMAGE_PICKER_FLOW: Exception occurred: $e');
      _setImageUploadError('Kunde inte ta foto: $e');
    } finally {
      _setUploadingImage(false); // Clear loading state
    }

    AppLogger.info('🎯 IMAGE_PICKER_FLOW: pickImageFromCamera completed');
  }

  /// Pick single image from gallery directly (no dialog)
  Future<void> pickImageFromGallery(BuildContext context,
      {String? recipeId}) async {
    AppLogger.info('🎯 IMAGE_PICKER_FLOW: Starting pickImageFromGallery');

    if (!canAddMoreImages) {
      AppLogger.warning(
          '🎯 IMAGE_PICKER_FLOW: Cannot add more images ($totalImageCount/$maxImages)');
      _setImageUploadError('Du kan bara ha maximalt $maxImages bilder');
      return;
    }

    try {
      _clearImageUploadError();
      _setUploadingImage(true); // Add loading state
      AppLogger.info(
          '🎯 IMAGE_PICKER_FLOW: Using ImagePickerService to pick image from gallery');

      final pickedFile =
          await _imagePickerService.pickImage(ImageSource.gallery);
      AppLogger.info(
          '🎯 IMAGE_PICKER_FLOW: ImagePickerService returned: $pickedFile');

      if (pickedFile != null) {
        AppLogger.info('🎯 IMAGE_PICKER_FLOW: File path: ${pickedFile.path}');
        final xFile = XFile(pickedFile.path);
        AppLogger.info(
            '🎯 IMAGE_PICKER_FLOW: Created XFile, calling _processImagePickerResult');
        await _processImagePickerResult(xFile, recipeId: recipeId);
        AppLogger.info(
            '🎯 IMAGE_PICKER_FLOW: _processImagePickerResult completed');
      } else {
        AppLogger.warning(
            '🎯 IMAGE_PICKER_FLOW: No image selected from gallery');
        _setImageUploadError('Ingen bild valdes');
      }
    } catch (e) {
      AppLogger.error('🎯 IMAGE_PICKER_FLOW: Exception occurred: $e');
      _setImageUploadError('Kunde inte välja bild: $e');
    } finally {
      _setUploadingImage(false); // Clear loading state
    }

    AppLogger.info('🎯 IMAGE_PICKER_FLOW: pickImageFromGallery completed');
  }

  /// Pick multiple images from gallery directly (no dialog)
  Future<void> pickMultipleImagesFromGallery(BuildContext context,
      {String? recipeId}) async {
    AppLogger.info(
        '🎯 IMAGE_PICKER_FLOW: Starting pickMultipleImagesFromGallery');

    if (!canAddMoreImages) {
      _setImageUploadError('Du kan bara ha maximalt $maxImages bilder');
      return;
    }

    try {
      _clearImageUploadError();
      _setUploadingImage(true); // Add loading state

      AppLogger.info(
          '🔍 Using ImagePickerService to pick multiple images from gallery');
      final pickedFiles = await _imagePickerService.pickMultipleImages();

      if (pickedFiles.isNotEmpty) {
        AppLogger.info('🎯 Selected ${pickedFiles.length} images from gallery');
        // Convert List<File> to List<XFile> and process
        final xFiles = pickedFiles.map((file) => XFile(file.path)).toList();
        await _processImagePickerResult(xFiles, recipeId: recipeId);
      } else {
        AppLogger.warning('No images selected from gallery');
        _setImageUploadError('Inga bilder valdes');
      }
    } catch (e) {
      AppLogger.error('Fel vid val av flera bilder: $e');
      _setImageUploadError('Kunde inte välja bilder: $e');
    } finally {
      _setUploadingImage(false); // Clear loading state
    }
  }

  /// Legacy method - kept for backwards compatibility
  Future<void> showMultipleImagePickerDialog(BuildContext context,
      {String? recipeId}) async {
    await pickMultipleImagesFromGallery(context, recipeId: recipeId);
  }

  /// Lägg till bild från URL
  Future<void> addImageFromUrl(String imageUrl) async {
    if (!canAddMoreImages) {
      _setImageUploadError('Du kan bara ha maximalt $maxImages bilder');
      return;
    }

    if (imageUrl.trim().isEmpty) {
      _setImageUploadError('Bildlänk får inte vara tom');
      return;
    }

    try {
      _clearImageUploadError();

      // Validera URL format
      final uri = Uri.tryParse(imageUrl.trim());
      if (uri == null || !uri.hasAbsolutePath) {
        _setImageUploadError('Ogiltig bildlänk');
        return;
      }

      // Kontrollera att bilden inte redan finns
      if (imageUrls.contains(imageUrl.trim())) {
        _setImageUploadError('Bilden finns redan');
        return;
      }

      addUploadedImageUrl(imageUrl.trim());
      AppLogger.info('Bild tillagd från URL: $imageUrl');
    } catch (e) {
      AppLogger.error('Fel vid tillägg av bild från URL: $e');
      _setImageUploadError('Kunde inte lägga till bild: $e');
    }
  }

  /// Ladda upp bild från lokal fil
  Future<void> uploadImageFromFile(XFile imageFile, String recipeId) async {
    if (!canAddMoreImages) {
      _setImageUploadError('Du kan bara ha maximalt $maxImages bilder');
      return;
    }

    try {
      _setUploadingImage(true);
      _clearImageUploadError();

      // Convert XFile to File
      final file = File(imageFile.path);

      // Ladda upp bilden
      final imageUrl = await _storageService.uploadRecipeImage(file, recipeId);

      if (imageUrl != null && imageUrl.isNotEmpty) {
        addUploadedImageUrl(imageUrl);
        AppLogger.info('Bild uppladdad: $imageUrl');
      } else {
        _setImageUploadError('Kunde inte ladda upp bild');
      }
    } catch (e) {
      AppLogger.error('Fel vid uppladdning av bild: $e');
      _setImageUploadError('Kunde inte ladda upp bild: $e');
    } finally {
      _setUploadingImage(false);
    }
  }

  /// Ladda upp flera bilder från lokala filer
  Future<void> uploadMultipleImages(
      List<XFile> imageFiles, String recipeId) async {
    if (imageFiles.isEmpty) return;

    final availableSlots = remainingImageSlots;
    final filesToUpload = imageFiles.take(availableSlots).toList();

    String? limitationMessage;
    if (filesToUpload.length < imageFiles.length) {
      limitationMessage =
          'Bara ${filesToUpload.length} av ${imageFiles.length} bilder kunde laddas upp (max $maxImages bilder)';
    }

    try {
      _clearImageUploadError();

      // ULTRATHINK FIX: Use existing background upload system instead of blocking Future.wait
      // This allows immediate completion while uploads continue in background
      for (final xFile in filesToUpload) {
        final file = File(xFile.path);
        await _addPendingImageFromFile(file); // Adds to pending list instantly
        // Background upload already starts automatically in _addPendingImageFromFile
      }

      AppLogger.info(
          'Started background uploads for ${filesToUpload.length} images');

      // Set limitation message if files were limited
      if (limitationMessage != null) {
        _setImageUploadError(limitationMessage);
      }
    } catch (e) {
      AppLogger.error('Fel vid förberedelse av uppladdning: $e');
      _setImageUploadError('Kunde inte förbereda bilder: $e');
    }
    // Note: No finally block setting _setUploadingImage(false) - each individual upload handles its own state
  }

  /// Remove image and cleanup storage
  Future<void> removeImageAndCleanup(String pathOrUrl) async {
    try {
      final imageStatus = _imageStates[pathOrUrl];

      // Remove from state
      removeImageByPath(pathOrUrl);

      // Only delete from Firebase storage if it's an uploaded URL
      if (imageStatus?.url != null && _isUploadedUrl(imageStatus!.url!)) {
        await _storageService.deleteRecipeImage(imageStatus.url!);
        AppLogger.info(
            '☁️ 🗑️ Bild borttagen från Firebase storage: ${imageStatus.url}');
      } else {
        AppLogger.info(
            '📁 🗑️ Pending file removed (no storage cleanup needed): $pathOrUrl');
      }
    } catch (e) {
      AppLogger.error('❌ Fel vid borttagning av bild: $e');
      // Continue anyway, image is removed from the list
    }
  }

  /// Check if a path/URL is an uploaded URL vs a local file path
  bool _isUploadedUrl(String pathOrUrl) {
    return pathOrUrl.startsWith('http') ||
        pathOrUrl.startsWith('gs://') ||
        pathOrUrl.contains('firebase') ||
        pathOrUrl.contains('storage');
  }

  /// Clear all images and cleanup storage
  Future<void> clearAllImages() async {
    final imagesToCleanup = _imageStates.values
        .where((status) => status.url != null && _isUploadedUrl(status.url!))
        .map((status) => status.url!)
        .toList();

    _imageStates.clear();
    notifyListeners();

    // Cleanup uploaded images from storage
    for (final imageUrl in imagesToCleanup) {
      try {
        await _storageService.deleteRecipeImage(imageUrl);
        AppLogger.info('Cleaned up image from storage: $imageUrl');
      } catch (e) {
        AppLogger.error('Fel vid rensning av bild: $e');
      }
    }
  }

  // ===== PRIVATE METHODS =====

  /// Bearbeta resultat från image picker
  /// Process image picker result with instant feedback (no upload yet)
  Future<void> _processImagePickerResult(dynamic result,
      {String? recipeId}) async {
    AppLogger.info(
        '🚀 INSTANT_IMAGES: Processing image picker result (no upload yet)');

    try {
      if (result is XFile) {
        // Single image - handle web blob URLs properly
        await _processSingleXFile(result);
      } else if (result is List<XFile>) {
        // Multiple images - handle each XFile properly
        for (final xFile in result) {
          await _processSingleXFile(xFile);
        }
      } else if (result is String) {
        // URL - this still needs immediate handling as it's already "uploaded"
        await addImageFromUrl(result);
      }
    } catch (e) {
      AppLogger.error('🚀 INSTANT_IMAGES: Error processing result: $e');
      _setImageUploadError('Kunde inte lägga till bild: $e');
    }
  }

  /// Process single XFile with proper web blob URL handling
  Future<void> _processSingleXFile(XFile xFile) async {
    AppLogger.info('🖼️ WEB_FIX: Processing XFile: ${xFile.path}');

    // Check if this is a web blob URL (needs special handling)
    if (xFile.path.startsWith('blob:')) {
      AppLogger.info(
          '🌐 WEB_FIX: Blob URL detected, using XFile directly for display');

      // For web blob URLs, we can't create a File object
      // Instead, add the XFile path directly for display
      await _addPendingImageFromXFile(xFile);
    } else {
      // Mobile platform - normal file path, create File object
      AppLogger.info('📱 MOBILE: Normal file path, creating File object');
      final file = File(xFile.path);
      await _addPendingImageFromFile(file);
    }
  }

  /// Add XFile to pending list for web blob URL handling
  Future<void> _addPendingImageFromXFile(XFile xFile) async {
    if (!canAddMoreImages) {
      _setImageUploadError('Du kan bara ha maximalt $maxImages bilder');
      return;
    }

    final filePath = xFile.path;

    // Validate file size for web
    try {
      final fileSize = await xFile.length();
      const maxSizeInBytes = 5 * 1024 * 1024; // 5MB
      if (fileSize > maxSizeInBytes) {
        _setImageUploadError('Bilden är för stor (max 5MB)');
        return;
      }
    } catch (e) {
      AppLogger.error('🌐 WEB_FIX: Could not validate file size: $e');
    }

    // Store XFile reference for later upload
    _pendingXFiles[filePath] = xFile;

    // Initialize comprehensive state tracking as pending
    _imageStates[filePath] = const ImageUploadStatus(
      // Note: No File object for blob URLs, path will be used for display
      state: ImageUploadState.pending,
      progress: 0.0,
    );

    // Trigger immediate UI update
    _clearImageUploadError();
    _notifyImmediately();

    AppLogger.info('🌐 WEB_FIX: Blob URL image added for display: $filePath');

    // Start background upload immediately with XFile
    final recipeId = _getTemporaryRecipeId();
    _startBackgroundUploadForXFile(xFile, recipeId);
  }

  /// Add file to pending list with validation and comprehensive state tracking
  Future<void> _addPendingImageFromFile(File imageFile) async {
    if (!canAddMoreImages) {
      _setImageUploadError('Du kan bara ha maximalt $maxImages bilder');
      return;
    }

    // Basic validation
    if (!await _validateImageFile(imageFile)) {
      return; // Error already set in validation
    }

    final filePath = imageFile.path;

    // HIGH PRIORITY FIX: Initialize comprehensive state tracking as pending
    _imageStates[filePath] = ImageUploadStatus(
      file: imageFile,
      state: ImageUploadState.pending,
      progress: 0.0,
    );

    // Add to pending list - this is instant!
    addPendingImage(imageFile);
    _clearImageUploadError();

    // CRITICAL FIX: Immediate UI notification for instant feedback
    _notifyImmediately();

    AppLogger.info(
        '⚡ INSTANT_FEEDBACK: Image added with immediate UI update: $filePath');

    // Start background upload immediately with temporary ID
    // Images will be uploaded right away for better performance
    final recipeId = _getTemporaryRecipeId();
    _startBackgroundUploadForFile(imageFile, recipeId);
  }

  /// Get or create temporary recipe ID for immediate upload
  String _getTemporaryRecipeId() {
    // Generate a temporary recipe ID if we don't have one
    // This allows immediate upload without waiting for save
    _temporaryRecipeId ??=
        'temp_${DateTime.now().millisecondsSinceEpoch}_${_random.nextInt(10000)}';
    return _temporaryRecipeId!;
  }

  /// Set the actual recipe ID (called during save)
  void setActualRecipeId(String recipeId) {
    _temporaryRecipeId = recipeId;
  }

  /// Start background upload for a single file with comprehensive state tracking
  void _startBackgroundUploadForFile(File imageFile, String recipeId) {
    final filePath = imageFile.path;

    // Don't upload if already uploading
    final currentState = _imageStates[filePath];
    if (currentState?.isActive == true) {
      AppLogger.info('🔄 Already uploading: $filePath');
      return;
    }

    AppLogger.info('🚀 Starting background upload for: $filePath');

    // Get file size for progress tracking
    final fileSize = imageFile.lengthSync();
    final startTime = DateTime.now();

    // Update comprehensive state tracking with enhanced details
    _imageStates[filePath] = ImageUploadStatus(
      file: imageFile,
      state: ImageUploadState.uploading,
      progress: 0.0,
      totalBytes: fileSize,
      uploadStartTime: startTime,
      retryAttempts: currentState?.retryAttempts ?? 0, // Preserve retry count
      maxRetryAttempts: currentState?.maxRetryAttempts ??
          3, // Will be updated based on error type
    );

    notifyListeners();

    // Start upload with enhanced error handling
    _uploadSingleFileWithEnhancedTracking(imageFile, recipeId)
        .then((uploadedUrl) {
      if (_uploadsCanceled || _disposed) {
        AppLogger.info(
            '📦 Upload completed but manager disposed/cancelled: $filePath');
        return;
      }

      if (uploadedUrl != null) {
        AppLogger.info(
            '✅ Background upload completed: $filePath -> $uploadedUrl');

        // Reset circuit breaker on successful upload (half-open -> closed)
        _resetCircuitBreakerOnSuccess();

        // Check if this was a retry success
        final wasRetry = currentState?.retryAttempts != null &&
            currentState!.retryAttempts > 0;
        if (wasRetry) {
          _triggerRetrySuccessNotification(imageFile.path.split('/').last);
        }

        // Update comprehensive state to completed
        _imageStates.remove(filePath); // Remove file path key
        _imageStates[uploadedUrl] = ImageUploadStatus(
          url: uploadedUrl,
          state: ImageUploadState.completed,
          progress: 1.0,
          totalBytes: fileSize,
          bytesTransferred: fileSize,
        );

        // Check for completion notification
        _checkAndTriggerCompletionEvents();
      } else {
        AppLogger.error('❌ Background upload failed: $filePath');
        _handleUploadFailure(filePath, imageFile, 'Upload failed', null);
      }

      if (!_disposed) {
        notifyListeners();
        // Check for completion events after state change
        _checkAndTriggerCompletionEvents();
      }
    }).catchError((error) {
      if (_uploadsCanceled || _disposed) {
        AppLogger.info(
            '📦 Upload error but manager disposed/cancelled: $filePath');
        return;
      }

      AppLogger.error('❌ Background upload error: $error');
      _handleUploadFailure(filePath, imageFile, error.toString(), error);

      if (!_disposed) {
        notifyListeners();
        // Check for completion events after error
        _checkAndTriggerCompletionEvents();
      }
    });
  }

  /// Start background upload for XFile (web blob URL handling)
  void _startBackgroundUploadForXFile(XFile xFile, String recipeId) {
    final filePath = xFile.path;

    // Don't upload if already uploading
    final currentState = _imageStates[filePath];
    if (currentState?.isActive == true) {
      AppLogger.info('🔄 Already uploading XFile: $filePath');
      return;
    }

    AppLogger.info(
        '🌐 WEB_FIX: Starting background upload for XFile: $filePath');

    // Get file size for progress tracking (async for XFile)
    xFile.length().then((fileSize) {
      final startTime = DateTime.now();

      // Update comprehensive state tracking with enhanced details
      _imageStates[filePath] = ImageUploadStatus(
        // Note: No File object for blob URLs
        state: ImageUploadState.uploading,
        progress: 0.0,
        totalBytes: fileSize,
        uploadStartTime: startTime,
        retryAttempts: currentState?.retryAttempts ?? 0,
        maxRetryAttempts: currentState?.maxRetryAttempts ?? 3,
      );

      notifyListeners();

      // Start upload with XFile handling for web
      _uploadXFileWithWebSupport(xFile, recipeId).then((uploadedUrl) {
        if (_uploadsCanceled || _disposed) {
          AppLogger.info(
              '📦 XFile upload completed but manager disposed/cancelled: $filePath');
          return;
        }

        if (uploadedUrl != null) {
          AppLogger.info(
              '✅ Background XFile upload completed: $filePath -> $uploadedUrl');

          // Update comprehensive state to completed
          _imageStates.remove(filePath); // Remove blob URL path key
          _pendingXFiles.remove(filePath); // Clean up XFile reference
          _imageStates[uploadedUrl] = ImageUploadStatus(
            url: uploadedUrl,
            state: ImageUploadState.completed,
            progress: 1.0,
            totalBytes: fileSize,
            bytesTransferred: fileSize,
          );

          // Check for completion notification
          _checkAndTriggerCompletionEvents();
        } else {
          AppLogger.error('❌ Background XFile upload failed: $filePath');
          _handleXFileUploadFailure(filePath, xFile, 'Upload failed', null);
        }

        if (!_disposed) {
          notifyListeners();
          _checkAndTriggerCompletionEvents();
        }
      }).catchError((error) {
        if (_uploadsCanceled || _disposed) {
          AppLogger.info(
              '📦 XFile upload error but manager disposed/cancelled: $filePath');
          return;
        }

        AppLogger.error(
            '💥 Background XFile upload error: $filePath -> $error');
        _handleXFileUploadFailure(filePath, xFile, 'Upload error', error);

        if (!_disposed) {
          notifyListeners();
          _checkAndTriggerCompletionEvents();
        }
      });
    }).catchError((error) {
      AppLogger.error('💥 Could not get XFile size: $filePath -> $error');
      _setImageUploadError('Kunde inte läsa bilddata: $error');
    });
  }

  /// Upload XFile with web platform support (handles blob URLs)
  Future<String?> _uploadXFileWithWebSupport(
      XFile xFile, String recipeId) async {
    try {
      AppLogger.info(
          '🌐 WEB_FIX: Uploading XFile with web support: ${xFile.path}');

      // Read bytes from XFile (works with blob URLs)
      final bytes = await xFile.readAsBytes();
      AppLogger.info('🌐 WEB_FIX: Read ${bytes.length} bytes from XFile');

      // Use uploadImageBytes for web blob URL handling
      final userId =
          ServiceLocator.get<permission.PermissionService>().currentUserId;
      if (userId == null) {
        throw Exception('No authenticated user');
      }

      final uploadedUrl = await _storageService.uploadImageBytes(
        bytes,
        userId,
        xFile.name,
        prefix: 'recipe', // Use recipe prefix for proper path
      );

      AppLogger.info('🌐 WEB_FIX: Upload result: $uploadedUrl');
      return uploadedUrl;
    } catch (e) {
      AppLogger.error('🌐 WEB_FIX: Upload failed: $e');
      return null;
    }
  }

  /// Handle XFile upload failure with error classification
  void _handleXFileUploadFailure(
      String filePath, XFile xFile, String errorMessage, dynamic error) {
    final errorType = _classifyError(error ?? errorMessage);
    final currentStatus = _imageStates[filePath];

    final failedStatus = ImageUploadStatus(
      // Note: No File object for XFile blob URLs
      state: ImageUploadState.failed,
      error: errorMessage,
      errorType: errorType,
      errorOccurredAt: DateTime.now(),
      progress: currentStatus?.progress ?? 0.0,
      retryAttempts: currentStatus?.retryAttempts ?? 0,
      maxRetryAttempts: _getMaxRetryAttempts(errorType),
    );

    _imageStates[filePath] = failedStatus;
    _setImageUploadError('Kunde inte ladda upp bild: $errorMessage');

    AppLogger.error('❌ XFile upload failed: $filePath - $errorMessage');
  }

  /// Handle upload failure with error classification and enhanced retry logic
  void _handleUploadFailure(
      String filePath, File imageFile, String errorMessage, dynamic error) {
    final errorType = _classifyError(error ?? errorMessage);
    final currentStatus = _imageStates[filePath];
    final maxAttempts = _getMaxRetryAttempts(errorType);
    final currentAttempts = currentStatus?.retryAttempts ?? 0;

    final failedStatus = ImageUploadStatus(
      file: imageFile,
      state: ImageUploadState.failed,
      error: errorMessage,
      errorType: errorType,
      errorOccurredAt: DateTime.now(),
      progress: currentStatus?.progress ?? 0.0,
      totalBytes: currentStatus?.totalBytes,
      bytesTransferred: currentStatus?.bytesTransferred,
      retryAttempts: currentAttempts,
      maxRetryAttempts: maxAttempts, // Use configurable max attempts
    );

    _imageStates[filePath] = failedStatus;

    AppLogger.info(
        '🔄 UPLOAD_FAILURE: $filePath failed with ${errorType.name} (attempt ${currentAttempts + 1}/$maxAttempts)');

    // Update circuit breaker state for this error type
    _updateCircuitBreakerOnFailure(errorType);

    // Enhanced auto-retry with circuit breaker logic
    if (failedStatus.canRetry && _shouldAutoRetry(errorType)) {
      final retryDelay = _calculateRetryDelay(currentAttempts);

      AppLogger.info(
          '🔄 RETRY_SCHEDULED: Auto-retrying $filePath in ${retryDelay.inSeconds}s (${currentAttempts + 1}/$maxAttempts)');

      // Schedule retry with enhanced delay calculation
      Future.delayed(retryDelay).then((_) {
        if (!_uploadsCanceled && !_disposed) {
          // Double-check retry conditions before executing
          final latestStatus = _imageStates[filePath];
          if (latestStatus?.canRetry == true &&
              latestStatus?.errorType == errorType) {
            retryFailedUpload(filePath);
          } else {
            AppLogger.info(
                '🔄 RETRY_CANCELLED: Conditions changed for $filePath');
          }
        }
      });
    } else {
      final strategy = _retryStrategies[errorType];
      AppLogger.info(
          '🔄 NO_AUTO_RETRY: $filePath - ${strategy?.description ?? "No retry strategy"}');
    }
  }

  /// Enhanced retry strategy configuration for different error types
  static const Map<ImageUploadErrorType, RetryStrategy> _retryStrategies = {
    ImageUploadErrorType.network: RetryStrategy(
        autoRetry: true,
        maxAttempts: 5, // More attempts for network issues
        description: 'Nätverksproblem - försöker igen automatiskt'),
    ImageUploadErrorType.server: RetryStrategy(
        autoRetry: true,
        maxAttempts: 3, // Standard attempts for server errors
        description: 'Serverproblem - försöker igen automatiskt'),
    ImageUploadErrorType.validation: RetryStrategy(
        autoRetry: false,
        maxAttempts: 1, // No auto-retry for validation errors
        description: 'Bilden är ogiltig - kontrollera storlek och format'),
    ImageUploadErrorType.cancelled: RetryStrategy(
        autoRetry: false,
        maxAttempts: 0, // No retry for cancelled uploads
        description: 'Uppladdning avbruten av användaren'),
    ImageUploadErrorType.unknown: RetryStrategy(
        autoRetry: false,
        maxAttempts: 2, // Limited retry for unknown errors
        description: 'Okänt fel - försök igen manuellt'),
  };

  /// Determine if error type should trigger automatic retry with enhanced strategy and circuit breaker
  bool _shouldAutoRetry(ImageUploadErrorType errorType) {
    final strategy = _retryStrategies[errorType];
    if (strategy == null || !strategy.autoRetry) return false;

    // Check circuit breaker state
    final circuitBreakerState = _getCircuitBreakerState(errorType);

    // Reset circuit breaker if timeout has passed
    if (circuitBreakerState.shouldReset(_circuitBreakerResetTime)) {
      _circuitBreakers[errorType] = circuitBreakerState.reset();
      AppLogger.info(
          '🔄 CIRCUIT_BREAKER: Reset ${errorType.name} circuit breaker after timeout');
    }

    // Check if circuit is open (too many failures)
    if (_circuitBreakers[errorType]?.isOpen == true) {
      AppLogger.warning(
          '🔄 CIRCUIT_BREAKER: ${errorType.name} circuit is OPEN - blocking auto-retry');
      return false;
    }

    AppLogger.info(
        '🔄 RETRY_STRATEGY: ${errorType.name} -> ${strategy.description} (auto: ${strategy.autoRetry}, circuit: CLOSED)');
    return true;
  }

  /// Get circuit breaker state for error type, creating if needed
  CircuitBreakerState _getCircuitBreakerState(ImageUploadErrorType errorType) {
    return _circuitBreakers[errorType] ??
        const CircuitBreakerState(
          failureCount: 0,
          isOpen: false,
        );
  }

  /// Update circuit breaker state after failure
  void _updateCircuitBreakerOnFailure(ImageUploadErrorType errorType) {
    final currentState = _getCircuitBreakerState(errorType);
    final newState = currentState.withFailure();
    _circuitBreakers[errorType] = newState;

    if (newState.isOpen && !currentState.isOpen) {
      AppLogger.warning(
          '🔄 CIRCUIT_BREAKER: ${errorType.name} circuit OPENED after ${newState.failureCount} failures');
    }
  }

  /// Reset circuit breakers on successful upload (recovery)
  void _resetCircuitBreakerOnSuccess() {
    final hadOpenCircuits =
        _circuitBreakers.values.any((state) => state.isOpen);

    if (hadOpenCircuits) {
      // Reset all circuit breakers on success to allow normal operation
      _circuitBreakers.clear();
      AppLogger.info(
          '🔄 CIRCUIT_BREAKER: All circuits RESET on successful upload');
    }
  }

  /// Get maximum retry attempts for specific error type
  int _getMaxRetryAttempts(ImageUploadErrorType errorType) {
    return _retryStrategies[errorType]?.maxAttempts ?? 3;
  }

  // ===== BULK UPLOAD MANAGEMENT =====

  /// Retry all failed uploads that can be retried
  Future<void> retryAllFailedUploads() async {
    final failedItems = failedUploads;
    if (failedItems.isEmpty) {
      AppLogger.info('🔄 BULK_RETRY: No retryable failed uploads found');
      return;
    }

    AppLogger.info(
        '🔄 BULK_RETRY: Starting bulk retry for ${failedItems.length} failed uploads');

    // Retry each failed upload
    final retryFutures = failedItems.keys.map((pathOrUrl) =>
        retryFailedUpload(pathOrUrl).catchError((error) {
          AppLogger.error('🔄 BULK_RETRY: Error retrying $pathOrUrl: $error');
        }));

    await Future.wait(retryFutures);
    AppLogger.info('🔄 BULK_RETRY: Bulk retry completed');
  }

  /// Cancel all active uploads
  void cancelAllActiveUploads() {
    final activeItems = activeUploads;
    if (activeItems.isEmpty) {
      AppLogger.info('🔄 BULK_CANCEL: No active uploads to cancel');
      return;
    }

    AppLogger.info(
        '🔄 BULK_CANCEL: Cancelling ${activeItems.length} active uploads');

    for (final pathOrUrl in activeItems.keys) {
      removeImageAndCleanup(pathOrUrl);
    }
  }

  /// Clear all failed uploads (remove from state)
  void clearAllFailedUploads() {
    final failedItems = failedUploads;
    if (failedItems.isEmpty) {
      AppLogger.info('🔄 BULK_CLEAR: No failed uploads to clear');
      return;
    }

    AppLogger.info(
        '🔄 BULK_CLEAR: Clearing ${failedItems.length} failed uploads');

    for (final pathOrUrl in failedItems.keys) {
      _imageStates.remove(pathOrUrl);
    }

    notifyListeners();
    _checkAndTriggerCompletionEvents();
  }

  /// Get upload management summary for UI display
  Map<String, dynamic> get uploadManagementSummary {
    final failed = failedUploads.length;
    final active = activeUploads.length;
    final total = _imageStates.length;
    final completed = _imageStates.values
        .where((s) => s.state == ImageUploadState.completed)
        .length;

    return {
      'failed': failed,
      'active': active,
      'completed': completed,
      'total': total,
      'hasRetryableFailures': failed > 0,
      'hasActiveUploads': active > 0,
      'canBulkRetry': failed > 1, // Show bulk retry only for multiple failures
      'canBulkCancel': active > 1, // Show bulk cancel only for multiple active
    };
  }

  // ===== BACKGROUND NOTIFICATION SYSTEM =====

  /// Stream controller for upload notification events
  static final StreamController<UploadNotificationEvent>
      _notificationController =
      StreamController<UploadNotificationEvent>.broadcast();

  /// Stream of upload notification events for UI subscription
  static Stream<UploadNotificationEvent> get notificationStream =>
      _notificationController.stream;

  /// Check if notification cooldown allows new notification
  bool _canSendNotification() {
    if (_lastNotificationTime == null) return true;
    return DateTime.now().difference(_lastNotificationTime!) >=
        _notificationCooldown;
  }

  /// Send upload notification event
  void _sendNotificationEvent(UploadNotificationEvent event) {
    if (!_canSendNotification()) {
      AppLogger.debug(
          '🔔 NOTIFICATION: Skipping notification due to cooldown: ${event.trigger.name}');
      return;
    }

    _lastNotificationTime = DateTime.now();
    _notificationTriggers.add(event.trigger);
    _notificationController.add(event);

    AppLogger.info(
        '🔔 NOTIFICATION: Sent ${event.trigger.name} notification: ${event.message}');
  }

  /// Check and trigger progress milestone notifications
  void _checkProgressMilestones(
      double previousProgress, double currentProgress) {
    const milestones = [0.25, 0.50, 0.75];

    for (final milestone in milestones) {
      if (previousProgress < milestone && currentProgress >= milestone) {
        final percentage = (milestone * 100).round();
        _sendNotificationEvent(UploadNotificationEvent(
          trigger: UploadNotificationTrigger.significantProgress,
          title: 'Uppladdning $percentage% klar',
          message: 'Bilduppladdning gör framsteg - $percentage% slutförd',
          priority: NotificationPriority.low,
          data: {'milestone': milestone, 'progress': currentProgress},
          timestamp: DateTime.now(),
        ));
        break; // Only send one milestone notification at a time
      }
    }
  }

  /// Trigger completion notification
  void _triggerCompletionNotification(int totalImages) {
    if (_notificationTriggers
        .contains(UploadNotificationTrigger.allCompleted)) {
      return; // Already sent
    }

    final imageText = totalImages == 1 ? 'bild' : 'bilder';
    _sendNotificationEvent(UploadNotificationEvent(
      trigger: UploadNotificationTrigger.allCompleted,
      title: 'Uppladdning slutförd!',
      message: 'Alla $totalImages $imageText har laddats upp framgångsrikt',
      priority: NotificationPriority.medium,
      data: {'totalImages': totalImages},
      timestamp: DateTime.now(),
    ));
  }

  /// Trigger major failure notification
  void _triggerMajorFailureNotification(int failedCount, int totalCount) {
    if (_notificationTriggers
        .contains(UploadNotificationTrigger.majorFailure)) {
      return; // Already sent
    }

    if (failedCount >= 2 || (totalCount > 1 && failedCount >= totalCount / 2)) {
      _sendNotificationEvent(UploadNotificationEvent(
        trigger: UploadNotificationTrigger.majorFailure,
        title: 'Uppladdningsproblem',
        message:
            '$failedCount av $totalCount bilder misslyckades - kontrollera din internetanslutning',
        priority: NotificationPriority.high,
        data: {'failedCount': failedCount, 'totalCount': totalCount},
        timestamp: DateTime.now(),
      ));
    }
  }

  /// Trigger retry success notification
  void _triggerRetrySuccessNotification(String fileName) {
    _sendNotificationEvent(UploadNotificationEvent(
      trigger: UploadNotificationTrigger.retrySuccess,
      title: 'Återförsök lyckades',
      message: 'Bilden laddades upp efter återförsök',
      priority: NotificationPriority.low,
      data: {'fileName': fileName},
      timestamp: DateTime.now(),
    ));
  }

  /// Trigger queue cleared notification
  void _triggerQueueClearedNotification() {
    if (_imageStates.isEmpty && _notificationTriggers.isNotEmpty) {
      _sendNotificationEvent(UploadNotificationEvent(
        trigger: UploadNotificationTrigger.queueCleared,
        title: 'Uppladdningskö rensad',
        message: 'Alla uppladdningar har hanterats',
        priority: NotificationPriority.low,
        data: {},
        timestamp: DateTime.now(),
      ));
      _notificationTriggers.clear(); // Reset triggers
    }
  }

  /// Check and trigger completion events based on current state
  void _checkAndTriggerCompletionEvents() {
    final summary = uploadQueueSummary;
    final total = summary['total'] as int;
    final completed = summary['completed'] as int;
    final failed = summary['failed'] as int;
    final active = summary['active'] as int;

    // Trigger completion notification if all uploads are done
    if (total > 0 && completed == total && active == 0) {
      _triggerCompletionNotification(total);
    }

    // Trigger major failure notification if significant failures
    if (failed > 0) {
      _triggerMajorFailureNotification(failed, total);
    }

    // Trigger queue cleared if everything is finished and queue is empty
    if (total == 0 || (active == 0 && completed + failed == total)) {
      _triggerQueueClearedNotification();
    }
  }

  /// Upload a single file with enhanced progress tracking and speed calculation
  Future<String?> _uploadSingleFileWithEnhancedTracking(
      File imageFile, String recipeId) async {
    final filePath = imageFile.path;
    final fileSize = imageFile.lengthSync();
    DateTime? lastProgressUpdate;
    int? lastBytesTransferred;

    try {
      // Perform actual upload with enhanced progress tracking
      final uploadedUrl = await _storageService.uploadRecipeImage(
        imageFile,
        recipeId,
        onProgress: (progress) {
          if (_uploadsCanceled || _disposed) return;

          final currentStatus = _imageStates[filePath];
          if (currentStatus == null) return;

          final now = DateTime.now();
          final bytesTransferred = (progress * fileSize).round();
          final previousProgress = currentStatus.progress;

          // Check for progress milestones before updating state
          _checkProgressMilestones(previousProgress, progress);

          // Calculate upload speed and time remaining
          double? uploadSpeed;
          Duration? timeRemaining;

          if (lastProgressUpdate != null && lastBytesTransferred != null) {
            final timeDiff =
                now.difference(lastProgressUpdate!).inMilliseconds / 1000.0;
            final bytesDiff = bytesTransferred - lastBytesTransferred!;

            if (timeDiff > 0) {
              uploadSpeed = bytesDiff / timeDiff; // bytes per second

              if (uploadSpeed > 0) {
                final remainingBytes = fileSize - bytesTransferred;
                timeRemaining =
                    Duration(seconds: (remainingBytes / uploadSpeed).round());
              }
            }
          }

          // Update comprehensive state with detailed progress
          _imageStates[filePath] = currentStatus.copyWith(
            progress: progress,
            bytesTransferred: bytesTransferred,
            uploadSpeedBytesPerSecond: uploadSpeed,
            estimatedTimeRemaining: timeRemaining,
          );

          lastProgressUpdate = now;
          lastBytesTransferred = bytesTransferred;

          if (!_disposed) {
            notifyListeners();
          }
        },
      );

      return uploadedUrl;
    } catch (e) {
      AppLogger.error('Upload failed for $filePath: $e');
      return null;
    }
  }

  /// Validate image file before adding to pending list
  Future<bool> _validateImageFile(File imageFile) async {
    try {
      // Check if file exists
      if (!await imageFile.exists()) {
        _setImageUploadError('Bildfilen hittades inte');
        return false;
      }

      // Check file size (before compression)
      final fileSize = await imageFile.length();
      const maxSizeInBytes =
          20 * 1024 * 1024; // 20MB (generous limit before compression)
      if (fileSize > maxSizeInBytes) {
        _setImageUploadError('Bilden är för stor (max 20MB)');
        return false;
      }

      return true;
    } catch (e) {
      _setImageUploadError('Kunde inte validera bild: $e');
      return false;
    }
  }

  // CRITICAL FIX: Thread-safe state update methods
  void _setUploadingImage(bool uploading) {
    _safeUpdateState(() {
      _isUploadingImage = uploading;
    });
    _safeNotifyListeners();
  }

  void _setImageUploadError(String error) {
    _safeSetImageUploadError(error);
  }

  void _safeSetImageUploadError(String error) {
    _safeUpdateState(() {
      _imageUploadError = error;
    });
    _safeNotifyListeners();
  }

  void _clearImageUploadError() {
    _safeUpdateState(() {
      _imageUploadError = null;
    });
    _safeNotifyListeners();
  }

  /// CRITICAL FIX: Thread-safe state update coordination
  void _safeUpdateState(VoidCallback updateFunction) {
    if (_disposed) return;

    if (_isStateUpdating) {
      // Queue the update for when current update completes
      _pendingStateUpdates.add(updateFunction);
      return;
    }

    _isStateUpdating = true;
    try {
      updateFunction();

      // Process any pending updates
      while (_pendingStateUpdates.isNotEmpty && !_disposed) {
        final nextUpdate = _pendingStateUpdates.removeAt(0);
        nextUpdate();
      }
    } finally {
      _isStateUpdating = false;
    }
  }

  /// CRITICAL FIX: Thread-safe notification with disposal protection and debouncing
  void _safeNotifyListeners({bool immediate = false}) {
    if (_disposed || _isNotifying) return;

    if (immediate) {
      // CRITICAL FIX: Immediate notification for instant UI feedback (e.g., adding images)
      _doSafeNotification();
    } else {
      // Cancel previous debounce timer
      _notificationDebounceTimer?.cancel();

      // Debounce notifications to prevent excessive updates
      _notificationDebounceTimer = Timer(const Duration(milliseconds: 50), () {
        _doSafeNotification();
      });
    }
  }

  /// Perform the actual notification with protection
  void _doSafeNotification() {
    if (!_disposed && !_isNotifying) {
      _isNotifying = true;
      try {
        notifyListeners();
        AppLogger.debug(
            '🔔 UI notification sent - images: ${imageUrls.length}, pending: ${pendingImages.length}');
      } catch (e) {
        AppLogger.debug('Notification skipped due to disposal: $e');
      } finally {
        _isNotifying = false;
      }
    }
  }

  /// CRITICAL FIX: Immediate notification for instant UI feedback
  void _notifyImmediately() {
    _safeNotifyListeners(immediate: true);
  }

  // ===== UPLOAD SAFETY CHECKS =====

  /// Check if it's safe to save recipe without losing pending uploads
  /// HIGH PRIORITY FIX: Prevent data corruption from race conditions
  UploadSafetyResult ensureUploadSafety() {
    final List<String> pendingImagePaths = [];
    final List<String> failedImagePaths = [];

    // Check comprehensive state tracking
    for (final entry in _imageStates.entries) {
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

  /// Show dialog to user about pending uploads during save
  /// Returns user choice for how to handle pending uploads
  Future<UploadChoice?> showUploadChoiceDialog(
      BuildContext context, UploadSafetyResult safetyResult) async {
    if (safetyResult.isSafe) {
      return UploadChoice.wait; // No issues, proceed normally
    }

    final hasFailedUploads = safetyResult.hasFailedUploads;
    final hasPendingUploads = safetyResult.hasPendingUploads;

    String dialogTitle;
    String dialogContent;
    final List<Widget> actions = [];

    if (hasFailedUploads && hasPendingUploads) {
      dialogTitle = 'Bilduppladdning pågår';
      dialogContent =
          'Några bilder kunde inte laddas upp (${safetyResult.failedImagePaths.length}) och andra laddas fortfarande upp (${safetyResult.pendingImagePaths.length}).\n\nVad vill du göra?';
    } else if (hasFailedUploads) {
      dialogTitle = 'Bilduppladdning misslyckades';
      dialogContent =
          '${safetyResult.failedImagePaths.length} bilder kunde inte laddas upp.\n\nVad vill du göra?';
    } else {
      dialogTitle = 'Bilduppladdning pågår';
      dialogContent =
          '${safetyResult.pendingImagePaths.length} bilder laddas fortfarande upp.\n\nVad vill du göra?';
    }

    // Add common actions
    actions.addAll([
      TextButton(
        onPressed: () => Navigator.of(context).pop(UploadChoice.cancel),
        child: const Text('Avbryt'),
      ),
      if (hasPendingUploads)
        TextButton(
          onPressed: () => Navigator.of(context).pop(UploadChoice.wait),
          child: const Text('Vänta på uppladdning'),
        ),
      TextButton(
        onPressed: () =>
            Navigator.of(context).pop(UploadChoice.saveWithoutPending),
        style: TextButton.styleFrom(foregroundColor: Colors.orange),
        child: Text(hasFailedUploads
            ? 'Spara utan misslyckade bilder'
            : 'Spara utan väntande bilder'),
      ),
    ]);

    return showDialog<UploadChoice>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(dialogTitle),
        content: Text(dialogContent),
        actions: actions,
      ),
    );
  }

  /// Wait for all pending uploads to complete or timeout
  /// Returns true if all uploads completed successfully
  Future<bool> waitForUploadsToComplete({Duration? timeout}) async {
    final timeoutDuration = timeout ?? const Duration(minutes: 2);
    final startTime = DateTime.now();

    AppLogger.info(
        'Waiting for uploads to complete (timeout: ${timeoutDuration.inSeconds}s)');

    while (true) {
      final safetyCheck = ensureUploadSafety();

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

  /// Remove pending and failed images from state (called when user chooses to save without them)
  void removePendingAndFailedImages() {
    final toRemove = <String>[];

    // Find all non-completed images
    for (final entry in _imageStates.entries) {
      final status = entry.value;
      if (status.state != ImageUploadState.completed) {
        toRemove.add(entry.key);
      }
    }

    // Remove from state tracking
    for (final path in toRemove) {
      _imageStates.remove(path);
      AppLogger.info('Removed pending/failed image from state: $path');
    }

    notifyListeners();
  }

  // ===== UPLOAD OPERATIONS =====

  /// CRITICAL FIX: Thread-safe upload all pending images with cancellation support
  Future<List<String>> uploadPendingImagesInBackground(String recipeId,
      {Function(int completed, int total)? onProgress}) async {
    // CRITICAL FIX: Atomic disposal and cancellation check
    if (_disposed || _uploadsCanceled) {
      AppLogger.info(
          '☁️ Upload canceled - manager disposed or uploads canceled');
      return [];
    }

    final pendingImages = this.pendingImages;

    if (pendingImages.isEmpty) {
      AppLogger.info('☁️ No pending images to upload');
      return [];
    }

    AppLogger.info(
        '🚀 Starting thread-safe upload of ${pendingImages.length} pending images');
    final List<String> uploadedUrls = [];
    int completed = 0;
    final total = pendingImages.length;

    // CRITICAL FIX: Create operation group for coordinated cancellation
    final operationGroup = _UploadOperationGroup();

    try {
      // CRITICAL FIX: Create cancellable upload operations with proper tracking
      final uploadOperations = pendingImages.map((file) {
        final operation = _CancellableUploadOperation(
          file: file,
          recipeId: recipeId,
          onProgress: () {
            completed++;
            onProgress?.call(completed, total);
          },
          uploadFunction: (file, recipeId) =>
              _uploadSingleImageWithTracking(file, recipeId, () {}),
        );

        // Add to operation group and active uploads
        operationGroup.addOperation(operation);
        _activeUploads.add(operation);

        return operation;
      }).toList();

      // CRITICAL FIX: Start all operations with cancellation coordination
      final uploadFutures = uploadOperations.map((op) => op.start());

      // Wait for all uploads to complete or be cancelled
      final results = await Future.wait(uploadFutures, eagerError: false);
      final successfulUrls =
          results.where((url) => url != null).cast<String>().toList();

      AppLogger.info(
          '✅ Completed ${successfulUrls.length}/$total uploads successfully');

      return successfulUrls;
    } catch (e) {
      AppLogger.error('❌ Fatal error during upload: $e');
      _safeSetImageUploadError('Kunde inte ladda upp bilder: $e');
      return uploadedUrls;
    } finally {
      // CRITICAL FIX: Clean up operation group and notify safely
      operationGroup.dispose();
      _safeNotifyListeners();
    }
  }

  /// CRITICAL FIX: Upload single image with proper disposal tracking
  Future<String?> _uploadSingleImageWithTracking(
      File file, String recipeId, VoidCallback? onComplete) async {
    final filePath = file.path;

    try {
      // CRITICAL FIX: Check cancellation before each operation
      if (_disposed || _uploadsCanceled) {
        AppLogger.info('☁️ Upload canceled for ${file.path}');
        return null;
      }

      // Update state to uploading
      if (_imageStates.containsKey(filePath)) {
        _imageStates[filePath] =
            _imageStates[filePath]!.copyWith(state: ImageUploadState.uploading);

        if (!disposed) {
          notifyListeners();
        }
      }

      // CRITICAL FIX: Check cancellation before actual upload
      if (_disposed || _uploadsCanceled) {
        AppLogger.info(
            '☁️ Upload canceled during state update for ${file.path}');
        return null;
      }

      final imageUrl = await _storageService.uploadRecipeImage(file, recipeId);

      // CRITICAL FIX: Check cancellation after upload completes
      if (_disposed || _uploadsCanceled) {
        AppLogger.info(
            '☁️ Upload canceled after completion for ${file.path} - ignoring result');
        return null;
      }

      if (imageUrl != null && imageUrl.isNotEmpty) {
        // Update state to completed with URL
        _imageStates.remove(filePath);
        _imageStates[imageUrl] = ImageUploadStatus(
          url: imageUrl,
          state: ImageUploadState.completed,
          progress: 1.0,
        );

        onComplete?.call();

        AppLogger.info('✅ Uploaded ${file.path} -> $imageUrl');
        return imageUrl;
      } else {
        // Update state to failed
        if (_imageStates.containsKey(filePath)) {
          _imageStates[filePath] = _imageStates[filePath]!
              .copyWith(state: ImageUploadState.failed, error: 'Upload failed');
        }

        AppLogger.error('❌ Failed to upload ${file.path}');
        return null;
      }
    } catch (e) {
      // Update state to failed with error
      if (_imageStates.containsKey(filePath) &&
          !_disposed &&
          !_uploadsCanceled) {
        _imageStates[filePath] = _imageStates[filePath]!
            .copyWith(state: ImageUploadState.failed, error: e.toString());
      }

      AppLogger.error('❌ Error uploading ${file.path}: $e');
      return null;
    }
  }

  /// Get upload progress information
  Map<String, dynamic> get uploadProgress {
    final total = _imageStates.length;
    final completed = _imageStates.values
        .where((s) => s.state == ImageUploadState.completed)
        .length;
    final uploading = _imageStates.values
        .where((s) => s.state == ImageUploadState.uploading)
        .length;
    final pending = _imageStates.values
        .where((s) => s.state == ImageUploadState.pending)
        .length;

    return {
      'total': total,
      'completed': completed,
      'uploading': uploading,
      'pending': pending,
      'progressPercent': total > 0 ? (completed / total * 100).round() : 100,
    };
  }

  // ===== VALIDATION =====

  /// Validera bildformat
  bool isValidImageFormat(String imageUrl) {
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final lowercaseUrl = imageUrl.toLowerCase();
    return validExtensions.any((ext) => lowercaseUrl.contains(ext));
  }

  /// Validera bildstorlek (om tillgänglig)
  Future<bool> isValidImageSize(XFile imageFile) async {
    try {
      final fileSize = await imageFile.length();
      const maxSizeInBytes = 5 * 1024 * 1024; // 5MB
      return fileSize <= maxSizeInBytes;
    } catch (e) {
      AppLogger.error('Fel vid validering av bildstorlek: $e');
      return true; // Fortsätt om vi inte kan validera
    }
  }

  // ===== ERROR CLASSIFICATION & RETRY MANAGEMENT =====

  /// Classify error type from exception for targeted handling
  ImageUploadErrorType _classifyError(dynamic error) {
    final errorString = error.toString().toLowerCase();

    if (errorString.contains('network') ||
        errorString.contains('connection') ||
        errorString.contains('timeout') ||
        errorString.contains('unreachable')) {
      return ImageUploadErrorType.network;
    }

    if (errorString.contains('permission') ||
        errorString.contains('unauthorized') ||
        errorString.contains('forbidden') ||
        errorString.contains('size') ||
        errorString.contains('format') ||
        errorString.contains('validation')) {
      return ImageUploadErrorType.validation;
    }

    if (errorString.contains('server') ||
        errorString.contains('firebase') ||
        errorString.contains('storage') ||
        errorString.contains('internal')) {
      return ImageUploadErrorType.server;
    }

    if (errorString.contains('cancel')) {
      return ImageUploadErrorType.cancelled;
    }

    return ImageUploadErrorType.unknown;
  }

  /// Calculate retry delay with enhanced exponential backoff and intelligent jitter
  Duration _calculateRetryDelay(int attemptNumber) {
    // Enhanced exponential backoff with cap: 1s, 2s, 4s, 8s, 16s (max 30s)
    final exponent = min(attemptNumber, 4); // Cap at 16 seconds base delay
    final baseDelaySeconds = 1 * (1 << exponent);
    final maxDelaySeconds = min(baseDelaySeconds, 30); // Hard cap at 30 seconds

    // Enhanced jitter using full jitter algorithm (0% to 100% of base delay)
    // This is more effective at preventing thundering herd than additive jitter
    final jitterFactor = _random.nextDouble(); // 0.0 to 1.0
    final jitteredDelay = (maxDelaySeconds * jitterFactor).round();

    final finalDelay =
        Duration(seconds: max(jitteredDelay, 1)); // Minimum 1 second

    AppLogger.info(
        '🔄 RETRY_BACKOFF: Attempt $attemptNumber -> ${finalDelay.inSeconds}s delay (base: ${maxDelaySeconds}s, jitter: ${jitterFactor.toStringAsFixed(2)})');

    return finalDelay;
  }

  /// Retry failed upload with exponential backoff
  Future<void> retryFailedUpload(String filePath) async {
    final status = _imageStates[filePath];
    if (status == null || !status.canRetry) {
      AppLogger.warning(
          'Cannot retry upload for $filePath - status: ${status?.state}');
      return;
    }

    AppLogger.info(
        '🔄 Retrying upload for: $filePath (attempt ${status.retryAttempts + 1}/${status.maxRetryAttempts})');

    // Update status to retrying
    _imageStates[filePath] = status.copyWith(
      state: ImageUploadState.retrying,
      retryAttempts: status.retryAttempts + 1,
      retryDelay: _calculateRetryDelay(status.retryAttempts),
      nextRetryAt:
          DateTime.now().add(_calculateRetryDelay(status.retryAttempts)),
    );

    notifyListeners();

    // Wait for retry delay
    await Future.delayed(status.retryDelay ?? Duration.zero);

    // Check if still should retry (might have been cancelled)
    final currentStatus = _imageStates[filePath];
    if (currentStatus?.state != ImageUploadState.retrying || _uploadsCanceled) {
      return;
    }

    // Start the retry upload
    final recipeId = _getTemporaryRecipeId();
    if (status.file != null) {
      _startBackgroundUploadForFile(status.file!, recipeId);
    }
  }

  /// Get enhanced upload queue summary for UI display with analytics
  Map<String, dynamic> get uploadQueueSummary {
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

    for (final status in _imageStates.values) {
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

    final total = _imageStates.length;
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
        ? DateTime.now().difference(earliestStartTime)
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
      'statusText': _getEnhancedQueueStatusText(
          pending, active, completed, failed, total, overallProgress),
      'progressText':
          _getProgressDisplayText(overallProgress, estimatedTimeRemaining),
      'speedText': _getSpeedDisplayText(averageSpeedBytesPerSecond),
      'summaryText':
          _getQueueSummaryText(completed, failed, total, totalElapsedTime),
    };
  }

  /// Enhanced queue status text with progress information
  String _getEnhancedQueueStatusText(int pending, int active, int completed,
      int failed, int total, double overallProgress) {
    if (total == 0) return '';

    final progressPercent = (overallProgress * 100).round();

    if (active > 0) {
      if (pending > 0) {
        return 'Laddar upp $active bilder ($progressPercent% klart, $pending väntar)';
      } else {
        return 'Laddar upp $active bilder ($progressPercent% klart)';
      }
    } else if (pending > 0) {
      return 'Väntar på att ladda upp $pending bilder...';
    } else if (failed > 0 && completed > 0) {
      return '$completed av $total bilder uppladdade, $failed misslyckades';
    } else if (failed > 0) {
      return '$failed av $total bilder misslyckades - tryck för att försöka igen';
    } else if (completed == total && total > 0) {
      return 'Alla $total bilder uppladdade framgångsrikt';
    } else {
      return '';
    }
  }

  /// Get progress display text with time estimates
  String _getProgressDisplayText(double progress, Duration? timeRemaining) {
    final progressPercent = (progress * 100).round();

    if (timeRemaining != null) {
      final timeText = _formatDuration(timeRemaining);
      return '$progressPercent% klart - $timeText kvar';
    } else if (progress < 1.0) {
      return '$progressPercent% klart';
    } else {
      return 'Uppladdning slutförd';
    }
  }

  /// Get speed display text for upload analytics
  String _getSpeedDisplayText(double bytesPerSecond) {
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
  String _getQueueSummaryText(
      int completed, int failed, int total, Duration? elapsedTime) {
    if (total == 0) return '';

    final successRate = total > 0 ? ((completed / total) * 100).round() : 0;

    if (completed == total && failed == 0) {
      final timeText =
          elapsedTime != null ? ' på ${_formatDuration(elapsedTime)}' : '';
      return 'Alla bilder uppladdade$timeText (100% framgång)';
    } else if (completed > 0 || failed > 0) {
      final completionText = '$completed av $total slutförda';
      final failureText = failed > 0 ? ', $failed misslyckades' : '';
      final rateText = ' ($successRate% framgång)';

      return '$completionText$failureText$rateText';
    } else {
      return 'Förbereder uppladdning...';
    }
  }

  /// Format duration for display (e.g., "2m 30s", "45s", "1h 15m")
  String _formatDuration(Duration duration) {
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

  /// CRITICAL FIX: Thread-safe cancel all active uploads with proper coordination
  void cancelAllUploads() {
    _uploadsCanceled = true;
    AppLogger.info(
        '🛑 Thread-safe canceling ${_activeUploads.length} active uploads');

    // CRITICAL FIX: Cancel all active operations properly
    final operationsToCancel = _activeUploads.toList();
    for (final operation in operationsToCancel) {
      operation.cancel();
    }

    // Clear active uploads set
    _activeUploads.clear();

    // CRITICAL FIX: Thread-safe state update for cancelled uploads
    _safeUpdateState(() {
      final activeUploads =
          _imageStates.entries.where((entry) => entry.value.isActive).toList();

      for (final entry in activeUploads) {
        _imageStates[entry.key] = entry.value.copyWith(
          state: ImageUploadState.cancelled,
          error: 'Upload cancelled by user',
          errorType: ImageUploadErrorType.cancelled,
          errorOccurredAt: DateTime.now(),
        );
      }
    });

    _safeNotifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;

    AppLogger.info('🔄 Starting thread-safe disposal of RecipeImageManager');

    // CRITICAL FIX: Cancel all active uploads FIRST with proper coordination
    cancelAllUploads();

    // CRITICAL FIX: Cancel notification timers
    _notificationDebounceTimer?.cancel();
    _notificationDebounceTimer = null;

    // Clear pending state updates
    _pendingStateUpdates.clear();

    // Cancel all timers and stream subscriptions
    disposeStreamResources(); // From StreamManagementMixin

    AppLogger.info('✅ Thread-safe disposal of RecipeImageManager completed');
    super.dispose();
  }
}

// ===== IMAGE DISPLAY INFO CLASS =====

/// CRITICAL FIX: Comprehensive image display information for immediate UI feedback
class ImageDisplayInfo {
  final String displayPath;
  final ImageUploadState state;
  final double progress;
  final bool isPending;
  final bool isUploading;
  final bool isCompleted;
  final bool hasError;
  final String? errorMessage;
  final String progressText;
  final bool canRetry;

  const ImageDisplayInfo({
    required this.displayPath,
    required this.state,
    required this.progress,
    required this.isPending,
    required this.isUploading,
    required this.isCompleted,
    required this.hasError,
    this.errorMessage,
    required this.progressText,
    required this.canRetry,
  });

  /// Get color indicator for upload state
  Color getStateColor() {
    switch (state) {
      case ImageUploadState.pending:
        return Colors.blue;
      case ImageUploadState.uploading:
        return Colors.orange;
      case ImageUploadState.retrying:
        return Colors.amber;
      case ImageUploadState.completed:
        return Colors.green;
      case ImageUploadState.failed:
        return Colors.red;
      case ImageUploadState.cancelled:
        return AppColors.textMedium;
    }
  }

  /// Get icon for upload state
  IconData getStateIcon() {
    switch (state) {
      case ImageUploadState.pending:
        return Icons.schedule;
      case ImageUploadState.uploading:
        return Icons.cloud_upload;
      case ImageUploadState.retrying:
        return Icons.refresh;
      case ImageUploadState.completed:
        return Icons.cloud_done;
      case ImageUploadState.failed:
        return Icons.error;
      case ImageUploadState.cancelled:
        return Icons.cancel;
    }
  }
}

// ===== THREAD-SAFE UPLOAD OPERATION CLASSES =====

/// CRITICAL FIX: Cancellable upload operation with proper resource management
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

  /// Start the upload operation
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

  /// Cancel the upload operation
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

/// CRITICAL FIX: Upload operation group for coordinated cancellation
class _UploadOperationGroup {
  final List<_CancellableUploadOperation> _operations = [];
  bool _isDisposed = false;

  void addOperation(_CancellableUploadOperation operation) {
    if (_isDisposed) return;
    _operations.add(operation);
  }

  void cancelAll() {
    for (final operation in _operations) {
      operation.cancel();
    }
  }

  void dispose() {
    _isDisposed = true;
    cancelAll();
    _operations.clear();
  }

  int get activeCount =>
      _operations.where((op) => !op.isCompleted && !op.isCancelled).length;
  int get completedCount => _operations.where((op) => op.isCompleted).length;
  int get cancelledCount => _operations.where((op) => op.isCancelled).length;
}
