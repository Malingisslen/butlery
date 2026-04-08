import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/widgets/image/image_picker_dialogs.dart';
import 'package:butlery/widgets/recipe/upload_choice_dialog.dart'
    as upload_dialog;
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/upload_constants.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/services/permission_service.dart' as permission;
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/viewmodels/recipe_form/image_management/image_upload_validator.dart';
import 'package:butlery/viewmodels/recipe_form/image_management/image_upload_notification_manager.dart';
import 'package:butlery/viewmodels/recipe_form/image_management/image_upload_coordinator.dart';
import 'package:butlery/viewmodels/recipe_form/image_management/upload_queue_summary_calculator.dart';
import 'package:butlery/viewmodels/recipe_form/image_management/xfile_upload_handler.dart';
import 'package:butlery/core/l10n/app_locale.dart';

// Re-export ImageDisplayInfo for backwards compatibility
export 'package:butlery/viewmodels/recipe_form/image_management/image_display_info.dart';

/// Manages recipe-specific multi-image operations for recipe forms.
///
/// Delegates upload execution to ImageUploadService and
/// delete operations to StorageService.
class RecipeImageManager extends ChangeNotifier with StreamManagementMixin {
  final ImageUploadService _uploadService;
  final StorageService _storageService;
  final ImagePickerService _imagePickerService;

  late final ImageUploadValidator _validator;
  late final ImageUploadNotificationManager _notificationManager;
  late final ImageUploadCoordinator _coordinator;
  late final XFileUploadHandler _xfileHandler;

  bool _disposed = false;
  bool get disposed => _disposed;

  //Thread-safe upload operation coordination
  bool _uploadsCanceled = false;

  //State synchronization to prevent race conditions
  bool _isStateUpdating = false;
  final List<VoidCallback> _pendingStateUpdates = [];

  //Notification coordination with disposal protection
  bool _isNotifying = false;
  Timer? _notificationDebounceTimer;

  //Comprehensive state tracking to prevent race conditions
  final Map<String, ImageUploadStatus> _imageStates = {};

  String? _temporaryRecipeId; // Temporary ID for immediate uploads

  bool _isUploadingImage = false;
  String? _imageUploadError;

  // Random instance for temporary recipe ID generation
  static final Random _random = Random.secure();

  static const int maxImages = 5;

  RecipeImageManager({
    ImageUploadService? uploadService,
    StorageService? storageService,
    ImagePickerService? imagePickerService,
  })  : _uploadService =
            uploadService ?? ServiceLocator.get<ImageUploadService>(),
        _storageService =
            storageService ?? ServiceLocator.get<StorageService>(),
        _imagePickerService =
            imagePickerService ?? ServiceLocator.get<ImagePickerService>() {
    // Initialize specialized managers
    _validator = ImageUploadValidator();
    _notificationManager = ImageUploadNotificationManager();
    _xfileHandler = XFileUploadHandler(uploadService: _uploadService);
    _coordinator = ImageUploadCoordinator(
      storageService: _storageService,
      notifyListeners: _safeNotifyListeners,
      setError: _setImageUploadError,
      checkCompletionEvents: _checkAndTriggerCompletionEvents,
    );
  }

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

  /// Get the first available thumbnail URL from uploaded images.
  /// Used to set `thumbnailUrl` on the recipe model during save.
  String? get firstThumbnailUrl {
    final thumbs = _coordinator.thumbnailUrls;
    if (thumbs.isEmpty) return null;
    // Return thumbnail for the first valid image URL (primary image)
    for (final url in validImageUrls) {
      if (thumbs.containsKey(url)) return thumbs[url];
    }
    return thumbs.values.first;
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
      AppLogger.info('ðŸ“ Added pending image: ${imageFile.path}');
      notifyListeners();
    }
  }

  /// Add uploaded URL after successful upload
  void addUploadedImageUrl(String imageUrl) {
    if (!canAddMoreImages) return;
    if (!_imageStates.containsKey(imageUrl)) {
      _imageStates[imageUrl] = ImageUploadStatus(
        url: imageUrl,
        state: ImageUploadState.completed,
        progress: 1.0,
      );
      AppLogger.info('â˜ï¸ Added uploaded image: $imageUrl');
      notifyListeners();
    }
  }

  /// Remove image by path or URL
  void removeImageByPath(String pathOrUrl) {
    if (_imageStates.remove(pathOrUrl) != null) {
      AppLogger.info('ðŸ—‘ï¸ Removed image: $pathOrUrl');
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

  /// Visa image picker dialog och hantera bildval
  Future<void> showImagePickerDialog(BuildContext context,
      {String? recipeId}) async {
    if (!canAddMoreImages) {
      _setImageUploadError(AppLocale.current.errorGeneric);
      return;
    }

    try {
      _clearImageUploadError();
      final imageSource =
          await ImagePickerDialogs.showImageSourceDialog(context);

      if (imageSource != null) {
        final pickedFile =
            await _imagePickerService.pickImage(imageSource, enableCrop: true);

        if (pickedFile != null) {
          final xFile = XFile(pickedFile.path);
          await _processImagePickerResult(xFile, recipeId: recipeId);
        } else {
          _setImageUploadError(AppLocale.current.errorGeneric);
        }
      }
    } catch (e) {
      AppLogger.error('Image picker error: $e');
      _setImageUploadError(AppLocale.current.errorGeneric);
    }
  }

  /// Pick single image from camera directly (no dialog)
  Future<void> pickImageFromCamera(BuildContext context,
      {String? recipeId}) async {
    if (!canAddMoreImages) {
      _setImageUploadError(AppLocale.current.errorGeneric);
      return;
    }

    try {
      _clearImageUploadError();
      _setUploadingImage(true);

      final pickedFile = await _imagePickerService.pickImage(ImageSource.camera,
          enableCrop: true);

      if (pickedFile != null) {
        final xFile = XFile(pickedFile.path);
        await _processImagePickerResult(xFile, recipeId: recipeId);
      } else {
        _setImageUploadError(AppLocale.current.errorGeneric);
      }
    } catch (e) {
      AppLogger.error('Camera picker error: $e');
      _setImageUploadError(AppLocale.current.errorGeneric);
    } finally {
      _setUploadingImage(false);
    }
  }

  /// Pick single image from gallery directly (no dialog)
  Future<void> pickImageFromGallery(BuildContext context,
      {String? recipeId}) async {
    if (!canAddMoreImages) {
      _setImageUploadError(AppLocale.current.errorGeneric);
      return;
    }

    try {
      _clearImageUploadError();
      _setUploadingImage(true);

      final pickedFile = await _imagePickerService
          .pickImage(ImageSource.gallery, enableCrop: true);

      if (pickedFile != null) {
        final xFile = XFile(pickedFile.path);
        await _processImagePickerResult(xFile, recipeId: recipeId);
      } else {
        _setImageUploadError(AppLocale.current.errorGeneric);
      }
    } catch (e) {
      AppLogger.error('Gallery picker error: $e');
      _setImageUploadError(AppLocale.current.errorGeneric);
    } finally {
      _setUploadingImage(false);
    }
  }

  /// Pick multiple images from gallery directly (no dialog)
  Future<void> pickMultipleImagesFromGallery(BuildContext context,
      {String? recipeId}) async {
    if (!canAddMoreImages) {
      _setImageUploadError(AppLocale.current.errorGeneric);
      return;
    }

    try {
      _clearImageUploadError();
      _setUploadingImage(true);

      final pickedFiles = await _imagePickerService.pickMultipleImages();

      if (pickedFiles.isNotEmpty) {
        final xFiles = pickedFiles.map((file) => XFile(file.path)).toList();
        await _processImagePickerResult(xFiles, recipeId: recipeId);
      } else {
        _setImageUploadError(AppLocale.current.errorGeneric);
      }
    } catch (e) {
      AppLogger.error('Multiple image picker error: $e');
      _setImageUploadError(AppLocale.current.errorGeneric);
    } finally {
      _setUploadingImage(false);
    }
  }

  /// Legacy method - kept for backwards compatibility
  Future<void> showMultipleImagePickerDialog(BuildContext context,
      {String? recipeId}) async {
    await pickMultipleImagesFromGallery(context, recipeId: recipeId);
  }

  /// LÃ¤gg till bild frÃ¥n URL
  Future<void> addImageFromUrl(String imageUrl) async {
    if (!canAddMoreImages) {
      _setImageUploadError(AppLocale.current.errorGeneric);
      return;
    }

    if (imageUrl.trim().isEmpty) {
      _setImageUploadError(AppLocale.current.errorFillRequiredFields);
      return;
    }

    try {
      _clearImageUploadError();

      // Validera URL format
      final uri = Uri.tryParse(imageUrl.trim());
      if (uri == null || !uri.hasAbsolutePath) {
        _setImageUploadError(AppLocale.current.errorGeneric);
        return;
      }

      // Kontrollera att bilden inte redan finns
      if (imageUrls.contains(imageUrl.trim())) {
        _setImageUploadError(AppLocale.current.errorGeneric);
        return;
      }

      addUploadedImageUrl(imageUrl.trim());
      AppLogger.info('Bild tillagd frÃ¥n URL: $imageUrl');
    } catch (e) {
      AppLogger.error('Fel vid tillÃ¤gg av bild frÃ¥n URL: $e');
      _setImageUploadError(AppLocale.current.errorGeneric);
    }
  }

  /// Ladda upp bild frÃ¥n lokal fil
  Future<void> uploadImageFromFile(XFile imageFile, String recipeId) async {
    if (!canAddMoreImages) {
      _setImageUploadError(AppLocale.current.errorGeneric);
      return;
    }

    try {
      _setUploadingImage(true);
      _clearImageUploadError();

      // Convert XFile to File
      final file = File(imageFile.path);

      // Get authenticated user ID
      final permissionService =
          ServiceLocator.get<permission.PermissionService>();
      final userId = permissionService.currentUserId;

      if (userId == null) {
        _setImageUploadError(AppLocale.current.errorNoUserLoggedIn);
        return;
      }

      // Upload using ImageUploadService (path constructed by StorageService)
      final result = await _uploadService.uploadImage(
        file: file,
        userId: userId,
      );

      if (result.success && result.url != null) {
        addUploadedImageUrl(result.url!);
        AppLogger.info('Bild uppladdad: ${result.url}');
      } else {
        _setImageUploadError(result.error ?? AppLocale.current.errorGeneric);
      }
    } catch (e) {
      AppLogger.error('Fel vid uppladdning av bild: $e');
      _setImageUploadError(AppLocale.current.errorGeneric);
    } finally {
      _setUploadingImage(false);
    }
  }

  /// Ladda upp flera bilder frÃ¥n lokala filer
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

      // Use background upload system instead of blocking Future.wait
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
      AppLogger.error('Fel vid fÃ¶rberedelse av uppladdning: $e');
      _setImageUploadError(AppLocale.current.errorGeneric);
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
            'â˜ï¸ ðŸ—‘ï¸ Bild borttagen frÃ¥n Firebase storage: ${imageStatus.url}');
      } else {
        AppLogger.info(
            'ðŸ“ ðŸ—‘ï¸ Pending file removed (no storage cleanup needed): $pathOrUrl');
      }
    } catch (e) {
      AppLogger.error('âŒ Fel vid borttagning av bild: $e');
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

  /// Bearbeta resultat frÃ¥n image picker
  /// Process image picker result with instant feedback (no upload yet)
  Future<void> _processImagePickerResult(dynamic result,
      {String? recipeId}) async {
    AppLogger.info(
        'ðŸš€ INSTANT_IMAGES: Processing image picker result (no upload yet)');

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
      AppLogger.error('ðŸš€ INSTANT_IMAGES: Error processing result: $e');
      _setImageUploadError(AppLocale.current.errorGeneric);
    }
  }

  /// Process single XFile with proper web blob URL handling.
  /// Delegates platform detection to XFileUploadHandler.
  Future<void> _processSingleXFile(XFile xFile) async {
    final result = await _xfileHandler.processSingleXFile(xFile);
    if (result.isBlobUrl) {
      await _addPendingImageFromXFile(xFile);
    } else {
      await _addPendingImageFromFile(result.file!);
    }
  }

  /// Add XFile to pending list for web blob URL handling.
  /// Delegates validation and status creation to XFileUploadHandler.
  Future<void> _addPendingImageFromXFile(XFile xFile) async {
    if (!canAddMoreImages) {
      _setImageUploadError(AppLocale.current.errorGeneric);
      return;
    }

    final filePath = xFile.path;

    // Validate file size via handler
    final sizeError = await _xfileHandler.validateXFileSize(xFile);
    if (sizeError != null) {
      _setImageUploadError(AppLocale.current.errorGeneric);
      return;
    }

    // Validate magic bytes match a supported image format
    if (!await _validator.isValidImageContent(xFile)) {
      _setImageUploadError(AppLocale.current.errorGeneric);
      return;
    }

    // Create pending status (handler stores XFile reference internally)
    _imageStates[filePath] = _xfileHandler.createPendingXFileStatus(xFile);

    // Trigger immediate UI update
    _clearImageUploadError();
    _notifyImmediately();

    AppLogger.info('WEB_FIX: Blob URL image added for display: $filePath');

    // Start background upload immediately with XFile
    final recipeId = _getTemporaryRecipeId();
    _startBackgroundUploadForXFile(xFile, recipeId);
  }

  /// Add file to pending list with validation and comprehensive state tracking
  Future<void> _addPendingImageFromFile(File imageFile) async {
    if (!canAddMoreImages) {
      _setImageUploadError(AppLocale.current.errorGeneric);
      return;
    }

    // Basic validation
    if (!await _validateImageFile(imageFile)) {
      return; // Error already set in validation
    }

    final filePath = imageFile.path;

    //Initialize comprehensive state tracking as pending
    _imageStates[filePath] = ImageUploadStatus(
      file: imageFile,
      state: ImageUploadState.pending,
      progress: 0.0,
    );

    // Add to pending list - this is instant!
    addPendingImage(imageFile);
    _clearImageUploadError();

    //Immediate UI notification for instant feedback
    _notifyImmediately();

    AppLogger.info(
        'âš¡ INSTANT_FEEDBACK: Image added with immediate UI update: $filePath');

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

  /// Start background upload for a single file
  ///Simplified to delegate to ImageUploadService.
  /// The service handles progress tracking, retry logic, circuit breaker, and notifications.
  void _startBackgroundUploadForFile(File imageFile, String recipeId) {
    final filePath = imageFile.path;

    // Don't upload if already uploading
    final currentState = _imageStates[filePath];
    if (currentState?.isActive == true) {
      AppLogger.info('ðŸ”„ Already uploading: $filePath');
      return;
    }

    AppLogger.info('ðŸš€ Starting background upload for: $filePath');

    // Start upload - service handles all progress tracking, retry, circuit breaker
    _uploadSingleFileWithEnhancedTracking(imageFile, recipeId)
        .then((uploadedUrl) {
      //Always update state first, even if disposed/cancelled
      // This prevents the spinner from getting stuck when upload completes
      // during disposal (race condition fix)
      if (uploadedUrl != null) {
        AppLogger.info(
            '✅ Background upload completed: $filePath -> $uploadedUrl');

        // Update local state to completed (service already updated via onProgress)
        _imageStates.remove(filePath); // Remove file path key
        _imageStates[uploadedUrl] = ImageUploadStatus(
          url: uploadedUrl,
          state: ImageUploadState.completed,
          progress: 1.0,
        );
      } else {
        AppLogger.error('âŒ Background upload failed: $filePath');
        // Service already handled retry/circuit breaker, just update local state
        final failedStatus = _imageStates[filePath];
        if (failedStatus != null) {
          _imageStates[filePath] = failedStatus.copyWith(
            state: ImageUploadState.failed,
            error: 'Upload failed',
          );
        }
      }

      // Only notify listeners if not disposed (notifications can be skipped, state update cannot)
      if (!_disposed && !_uploadsCanceled) {
        notifyListeners();
        _checkAndTriggerCompletionEvents();
      } else {
        AppLogger.info(
            '📦 Upload completed but manager disposed/cancelled, skipping notifications: $filePath');
      }
    }).catchError((error) {
      //Always update state first, even if disposed/cancelled
      AppLogger.error('❌ Background upload error: $error');

      // Service already handled retry/circuit breaker, just update local state
      final failedStatus = _imageStates[filePath];
      if (failedStatus != null) {
        _imageStates[filePath] = failedStatus.copyWith(
          state: ImageUploadState.failed,
          error: error.toString(),
        );
      }

      // Only notify listeners if not disposed
      if (!_disposed && !_uploadsCanceled) {
        notifyListeners();
        _checkAndTriggerCompletionEvents();
      } else {
        AppLogger.info(
            '📦 Upload error but manager disposed/cancelled, skipping notifications: $filePath');
      }
    });
  }

  /// Start background upload for XFile (web blob URL handling).
  /// Delegates status creation and upload to XFileUploadHandler.
  void _startBackgroundUploadForXFile(XFile xFile, String recipeId) {
    final filePath = xFile.path;

    // Don't upload if already uploading
    final currentState = _imageStates[filePath];
    if (currentState?.isActive == true) {
      AppLogger.info('Already uploading XFile: $filePath');
      return;
    }

    AppLogger.info('WEB_FIX: Starting background upload for XFile: $filePath');

    // Create uploading status via handler (async for file size)
    _xfileHandler
        .createUploadingXFileStatus(
      xFile,
      retryAttempts: currentState?.retryAttempts ?? 0,
      maxRetryAttempts: currentState?.maxRetryAttempts ?? 3,
    )
        .then((uploadingStatus) {
      _imageStates[filePath] = uploadingStatus;
      notifyListeners();

      // Upload via handler
      _xfileHandler.uploadXFile(xFile, recipeId).then((uploadedUrl) {
        // Always update state first, even if disposed/cancelled
        if (uploadedUrl != null) {
          AppLogger.info(
              'Background XFile upload completed: $filePath -> $uploadedUrl');
          _imageStates.remove(filePath);
          _xfileHandler.removePendingXFile(filePath);
          _imageStates[uploadedUrl] = _xfileHandler.createCompletedXFileStatus(
            uploadedUrl,
            totalBytes: uploadingStatus.totalBytes,
          );
        } else {
          AppLogger.error('Background XFile upload failed: $filePath');
          _imageStates[filePath] = _xfileHandler.createFailedXFileStatus(
            'Upload failed',
            progress: _imageStates[filePath]?.progress ?? 0.0,
          );
          _setImageUploadError(AppLocale.current.errorGeneric);
        }

        if (!_disposed && !_uploadsCanceled) {
          notifyListeners();
          _checkAndTriggerCompletionEvents();
        }
      }).catchError((error) {
        AppLogger.error('Background XFile upload error: $filePath -> $error');
        _imageStates[filePath] = _xfileHandler.createFailedXFileStatus(
          'Upload error',
          progress: _imageStates[filePath]?.progress ?? 0.0,
        );
        _setImageUploadError(AppLocale.current.errorGeneric);

        if (!_disposed && !_uploadsCanceled) {
          notifyListeners();
          _checkAndTriggerCompletionEvents();
        }
      });
    }).catchError((error) {
      AppLogger.error('Could not get XFile size: $filePath -> $error');
      _setImageUploadError(AppLocale.current.errorGeneric);
    });
  }

  /// Retry all failed uploads that can be retried
  Future<void> retryAllFailedUploads() async {
    await _coordinator.retryAllFailedUploads(
      failedUploads: failedUploads,
      retryFailedUpload: retryFailedUpload,
    );
  }

  /// Cancel all active uploads
  void cancelAllActiveUploads() {
    _coordinator.cancelAllActiveUploads(
      activeUploads: activeUploads,
      removeImageAndCleanup: removeImageAndCleanup,
    );
  }

  /// Clear all failed uploads (remove from state)
  void clearAllFailedUploads() {
    _coordinator.clearAllFailedUploads(
      imageStates: _imageStates,
      failedUploads: failedUploads,
    );
  }

  /// Get upload management summary for UI display
  Map<String, dynamic> get uploadManagementSummary {
    return _coordinator.getUploadManagementSummary(
      imageStates: _imageStates,
      failedUploads: failedUploads,
      activeUploads: activeUploads,
    );
  }

  /// Stream of upload notification events for UI subscription
  static Stream<UploadNotificationEvent> get notificationStream =>
      ImageUploadNotificationManager.notificationStream;

  /// Check and trigger completion events based on current state
  void _checkAndTriggerCompletionEvents() {
    final summary = uploadQueueSummary;
    final total = summary['total'] as int;
    final completed = summary['completed'] as int;
    final failed = summary['failed'] as int;
    final active = summary['active'] as int;

    // Determine dominant error type from failed uploads
    ImageUploadErrorType? dominantErrorType;
    if (failed > 0) {
      final errorTypes = _imageStates.values
          .where(
              (s) => s.state == ImageUploadState.failed && s.errorType != null)
          .map((s) => s.errorType!)
          .toList();
      if (errorTypes.isNotEmpty) {
        // Pick the most common error type
        final counts = <ImageUploadErrorType, int>{};
        for (final t in errorTypes) {
          counts[t] = (counts[t] ?? 0) + 1;
        }
        dominantErrorType =
            counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
      }
    }

    _notificationManager.checkAndTriggerNotifications(
      total: total,
      completed: completed,
      failed: failed,
      active: active,
      dominantErrorType: dominantErrorType,
    );
  }

  /// Upload a single file with enhanced progress tracking and speed calculation
  ///Now uses ImageUploadService which provides automatic progress tracking,
  /// speed calculation, ETA, retry logic, and circuit breaker protection.
  Future<String?> _uploadSingleFileWithEnhancedTracking(
      File imageFile, String recipeId) async {
    final filePath = imageFile.path;

    try {
      // Get authenticated user ID
      final permissionService =
          ServiceLocator.get<permission.PermissionService>();
      final userId = permissionService.currentUserId;

      if (userId == null) {
        AppLogger.error('No authenticated user for upload');
        return null;
      }

      // Upload using ImageUploadService (handles progress, retry, circuit breaker automatically)
      final result = await _uploadService.uploadImage(
        file: imageFile,
        userId: userId,
        onProgress: (status) {
          if (_uploadsCanceled || _disposed) return;

          // Update local state with service-provided progress
          _imageStates[filePath] = status;

          if (!_disposed) {
            notifyListeners();
          }
        },
      );

      return result.success ? result.url : null;
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
        _setImageUploadError(AppLocale.current.errorGeneric);
        return false;
      }

      // Check file size (before compression)
      final fileSize = await imageFile.length();
      const maxSizeInBytes = UploadConstants.maxPreCompressionBytes;
      if (fileSize > maxSizeInBytes) {
        _setImageUploadError(AppLocale.current.errorGeneric);
        return false;
      }

      // Validate magic bytes match a supported image format
      final xFile = XFile(imageFile.path);
      if (!await _validator.isValidImageContent(xFile)) {
        _setImageUploadError(AppLocale.current.errorGeneric);
        return false;
      }

      return true;
    } catch (e) {
      _setImageUploadError(AppLocale.current.errorCouldNotValidateImage);
      return false;
    }
  }

  //Thread-safe state update methods
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

  ///Thread-safe state update coordination
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

  ///Thread-safe notification with disposal protection and debouncing
  void _safeNotifyListeners({bool immediate = false}) {
    if (_disposed || _isNotifying) return;

    if (immediate) {
      //Immediate notification for instant UI feedback (e.g., adding images)
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
            'ðŸ”” UI notification sent - images: ${imageUrls.length}, pending: ${pendingImages.length}');
      } catch (e) {
        AppLogger.debug('Notification skipped due to disposal: $e');
      } finally {
        _isNotifying = false;
      }
    }
  }

  ///Immediate notification for instant UI feedback
  void _notifyImmediately() {
    _safeNotifyListeners(immediate: true);
  }

  /// Check if it's safe to save recipe without losing pending uploads
  ///Prevent data corruption from race conditions
  UploadSafetyResult ensureUploadSafety() {
    return _validator.checkUploadSafety(_imageStates);
  }

  /// Show dialog to user about pending uploads during save
  /// Returns user choice for how to handle pending uploads
  /// Show upload choice dialog for handling pending/failed uploads.
  ///Delegates to upload_choice_dialog widget for UI rendering.
  /// Maintains separation of concerns (ViewModel should not build widgets).
  Future<UploadChoice?> showUploadChoiceDialog(
      BuildContext context, UploadSafetyResult safetyResult) async {
    return upload_dialog.showUploadChoiceDialog(
      context: context,
      safetyResult: safetyResult,
    );
  }

  /// Wait for all pending uploads to complete or timeout
  /// Returns true if all uploads completed successfully
  Future<bool> waitForUploadsToComplete({Duration? timeout}) async {
    return _validator.waitForUploadsToComplete(
      imageStates: _imageStates,
      timeout: timeout,
    );
  }

  /// Remove pending and failed images from state (called when user chooses to save without them)
  void removePendingAndFailedImages() {
    final toRemove = _validator.getPendingAndFailedImageKeys(_imageStates);

    // Remove from state tracking
    for (final path in toRemove) {
      _imageStates.remove(path);
      AppLogger.info('Removed pending/failed image from state: $path');
    }

    notifyListeners();
  }

  ///Thread-safe upload all pending images with cancellation support
  Future<List<String>> uploadPendingImagesInBackground(String recipeId,
      {Function(int completed, int total)? onProgress}) async {
    return _coordinator.uploadPendingImagesInBackground(
      pendingImages,
      recipeId,
      imageStates: _imageStates,
      disposed: _disposed,
      uploadsCanceled: _uploadsCanceled,
      onProgress: onProgress,
    );
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

  /// Validera bildformat
  bool isValidImageFormat(String imageUrl) {
    return _validator.isValidImageFormat(imageUrl);
  }

  /// Validera bildstorlek (om tillgÃ¤nglig)
  Future<bool> isValidImageSize(XFile imageFile) async {
    return _validator.isValidImageSize(imageFile);
  }

  /// Retry failed upload
  ///Simplified to restart upload via ImageUploadService
  /// Service handles retry delays, exponential backoff, and circuit breaker
  Future<void> retryFailedUpload(String filePath) async {
    final status = _imageStates[filePath];
    if (status == null) {
      AppLogger.warning('Cannot retry upload for $filePath - status not found');
      return;
    }

    AppLogger.info('ðŸ”„ Manual retry initiated for: $filePath');

    // Restart the upload - service handles all retry logic
    final recipeId = _getTemporaryRecipeId();
    if (status.file != null) {
      _startBackgroundUploadForFile(status.file!, recipeId);
    }
  }

  /// Get enhanced upload queue summary for UI display with analytics
  Map<String, dynamic> get uploadQueueSummary =>
      UploadQueueSummaryCalculator.calculateQueueSummary(_imageStates);

  ///Thread-safe cancel all active uploads with proper coordination
  void cancelAllUploads() {
    _uploadsCanceled = true;
    AppLogger.info('ðŸ›‘ Thread-safe canceling active uploads');

    //Thread-safe state update for cancelled uploads
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

    AppLogger.info('ðŸ”„ Starting thread-safe disposal of RecipeImageManager');

    //Cancel all active uploads FIRST with proper coordination
    cancelAllUploads();

    //Cancel notification timers
    _notificationDebounceTimer?.cancel();
    _notificationDebounceTimer = null;

    // Clear pending state updates
    _pendingStateUpdates.clear();

    // Dispose specialized managers
    _coordinator.dispose();

    // Cancel all timers and stream subscriptions
    disposeStreamResources(); // From StreamManagementMixin

    AppLogger.info('âœ… Thread-safe disposal of RecipeImageManager completed');
    super.dispose();
  }
}
