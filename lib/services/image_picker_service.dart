/// Comprehensive image selection service providing cross-platform camera and gallery access with advanced permission management.
/// This service provides sophisticated image selection functionality supporting both single and multiple image
/// selection workflows with comprehensive permission handling, platform-specific optimizations, and detailed
/// validation processes. It implements advanced debugging capabilities, cross-platform compatibility, and
/// robust error handling to ensure reliable image selection across different devices and operating systems.
/// **Architecture Integration:**
/// - Integrates with [ImagePicker] for native platform image selection capabilities
/// - Uses [PermissionHandler] for comprehensive permission management across platforms
/// - Coordinates with [StorageService] for image validation and file system operations
/// - Implements extensive logging through [AppLogger] for debugging and monitoring
/// - Separates UI logic to maintain clean architecture with dedicated dialog components
/// **Image Selection Features:**
/// - **Single Image Selection**: Camera and gallery access with quality optimization and size constraints
/// - **Multiple Image Selection**: Batch image selection with configurable limits and validation
/// - **Cross-Platform Permissions**: Smart permission handling for iOS, Android with version-specific strategies
/// - **Image Optimization**: Configurable quality settings, dimension constraints, and file size management
/// - **Validation Pipeline**: Comprehensive image validation including format, size, and accessibility checks
/// - **Error Recovery**: Robust error handling with detailed logging and graceful fallback strategies
/// **Permission Management:**
/// - **iOS Compatibility**: Photo library access with limited selection support
/// - **Android Optimization**: Version-specific permission strategies (storage vs photos permissions)
/// - **Smart Fallbacks**: Automatic fallback to alternative permission types when primary permissions fail
/// - **Permission Debugging**: Comprehensive permission status monitoring and diagnostic capabilities

import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/image_picker_provider.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Image selection service providing comprehensive camera and gallery access with advanced permission management.
/// This service manages complete image selection workflows including permission handling, image optimization,
/// validation, and cross-platform compatibility. It provides extensive debugging capabilities and robust
/// error handling to ensure reliable image selection functionality across different devices and platforms.
/// **Cross-Platform Architecture:**
/// Implements platform-specific strategies for optimal image selection:
/// - iOS: Photo library access with limited selection support and privacy compliance
/// - Android: Version-aware permission handling (storage vs photos permissions)
/// - Universal: Consistent API surface with platform-optimized implementations
/// **Image Processing Pipeline:**
/// Provides comprehensive image processing including:
/// - Quality optimization with configurable compression settings
/// - Dimension constraints to prevent memory issues with large images
/// - File validation with format checking and accessibility verification
/// - Batch processing support for multiple image selection workflows
/// **Usage Examples:**
/// ```dart
/// final imageService = ImagePickerService();
/// // Single image selection from camera
/// final cameraImage = await imageService.pickImage(ImageSource.camera);
/// // Multiple images from gallery
/// final galleryImages = await imageService.pickMultipleImages(maxImages: 5);
/// // Debug permission status
/// await imageService.debugPermissions();
/// ```
class ImagePickerService extends BaseService {
  @override
  String get serviceName => 'ImagePickerService';

  final ImagePickerProvider _imagePickerProvider;
  final PermissionProvider _permissionProvider;
  final ImageValidator _imageValidator;

  // Store the XFile for web platform
  XFile? _lastPickedXFile;

  ImagePickerService({
    ImagePickerProvider? imagePickerProvider,
    PermissionProvider? permissionProvider,
    ImageValidator? imageValidator,
  })  : _imagePickerProvider =
            imagePickerProvider ?? DefaultImagePickerProvider(),
        _permissionProvider = permissionProvider ?? DefaultPermissionProvider(),
        _imageValidator = imageValidator ?? DefaultImageValidator();

  /// Get the last picked XFile (for web platform)
  XFile? get lastPickedXFile => _lastPickedXFile;

  /// Selects a single image from camera or gallery with comprehensive validation and optimization.
  /// This method provides complete single image selection functionality with advanced permission handling,
  /// image optimization, and comprehensive validation pipeline. It implements detailed logging throughout
  /// the selection process to enable debugging and monitoring of image selection workflows.
  /// [source] Image source (camera or gallery) for image selection
  /// Returns selected and validated [File] or `null` if selection fails or is cancelled
  /// **Selection Process:**
  /// 1. **Permission Validation**: Checks and requests appropriate permissions for the selected source
  /// 2. **Image Selection**: Uses native image picker with optimized quality and dimension settings
  /// 3. **File Validation**: Verifies file existence, accessibility, and format validity
  /// 4. **Quality Optimization**: Applies configurable quality settings (80% quality, max 1600x1600 by default — BUT-992)
  /// 5. **Size Verification**: Validates file size and provides detailed logging information
  /// **Image Optimization Settings (BUT-992):**
  /// - Maximum dimensions: 1600x1600 pixels (still exceeds the OCR pipeline's 2048px resize)
  /// - Quality setting: 80% — saves ~2-3MB per upload vs the previous 90/2400 defaults
  /// - Format validation: Ensures selected images are in supported formats
  /// **Error Handling:**
  /// - Comprehensive error logging with detailed stack traces
  /// - Graceful handling of permission denials and user cancellations
  /// - File system validation with detailed diagnostic information
  /// - Integration with StorageService for advanced image validation
  Future<File?> pickImage(
    ImageSource source, {
    bool enableCrop = false,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    try {
      AppLogger.debug(
          '🔍 IMAGE_PICKER: Starting image selection from: ${source.name}');
      AppLogger.info('🔍 Starting image selection from: ${source.name}');

      // Check permissions
      AppLogger.debug('🔍 IMAGE_PICKER: Checking permissions...');
      final hasPermission = await _checkAndRequestPermission(source);
      AppLogger.debug('🔑 IMAGE_PICKER: Permission result: $hasPermission');
      AppLogger.info('🔑 Permission result: $hasPermission');

      if (!hasPermission) {
        AppLogger.warning(
            '❌ IMAGE_PICKER: Permission denied for ${source.name}');
        AppLogger.warning('❌ Permission denied for ${source.name}');
        return null;
      }

      AppLogger.debug('📱 IMAGE_PICKER: Calling image picker provider...');
      AppLogger.info('📱 Calling image picker...');
      // BUT-992: defaults tuned for upload cost — 1600px @ JPEG-80 still
      // exceeds the OCR pipeline's downstream 2048px @ 85 resize, so the
      // post-upload step becomes a no-op for most photos while every photo
      // saves ~2-3MB on the upload itself. Callers needing higher fidelity
      // can still override.
      final XFile? pickedFile = await _imagePickerProvider.pickImage(
        source: source,
        maxWidth: maxWidth ?? 1600,
        maxHeight: maxHeight ?? 1600,
        imageQuality: imageQuality ?? 80,
      );

      if (pickedFile == null) {
        AppLogger.info(
            '❌ IMAGE_PICKER: No image selected (user cancelled or error)');
        AppLogger.info('❌ No image selected (user cancelled)');
        return null;
      }

      AppLogger.info('✅ IMAGE_PICKER: Image selected: ${pickedFile.path}');
      AppLogger.info('✅ Image selected: ${pickedFile.path}');

      // Store the XFile for web platform
      _lastPickedXFile = pickedFile;

      // On web, we work with XFile directly instead of File
      if (kIsWeb) {
        AppLogger.debug(
            '🌐 IMAGE_PICKER: Web platform - returning placeholder File with blob URL');
        // For web, return a File with the blob URL
        // The actual upload will need to read bytes from the XFile
        return File(pickedFile.path); // This is a blob URL on web
      }

      // On mobile platforms, proceed with normal File handling
      final file = File(pickedFile.path);

      // Check that the file exists
      final exists = await file.exists();
      AppLogger.info('📁 File exists: $exists');

      if (!exists) {
        AppLogger.error('❌ File does not exist on disk');
        return null;
      }

      // Check file size
      final size = await file.length();
      AppLogger.info('📊 File size: $size bytes (${_formatBytes(size)})');

      // Validate the file
      final isValid = _imageValidator.isValidImageFile(file);
      AppLogger.info('✅ File is valid: $isValid');

      if (!isValid) {
        AppLogger.error('❌ Invalid image file: ${file.path}');
        return null;
      }

      AppLogger.success('🎉 Image selection successful!');

      // Crop if requested (mobile only — web returns early above)
      if (enableCrop) {
        final cropped = await cropImage(file);
        return cropped ?? file;
      }

      return file;
    } catch (e, stackTrace) {
      AppLogger.error('💥 Error during image selection: $e');
      AppLogger.error('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Selects multiple images from gallery with batch validation and configurable limits.
  /// This method provides comprehensive multiple image selection functionality with intelligent batch
  /// processing, configurable image limits, and comprehensive validation for each selected image.
  /// It implements advanced error handling and detailed logging for complex multi-image workflows.
  /// [maxImages] Maximum number of images to select (defaults to 5 for performance)
  /// Returns list of validated [File] objects, empty list if selection fails or is cancelled
  /// **Batch Selection Process:**
  /// 1. **Gallery Permission**: Validates gallery access permissions with smart fallback strategies
  /// 2. **Multi-Image Selection**: Uses native multi-image picker with optimization settings
  /// 3. **Limit Enforcement**: Intelligently limits selection to specified maximum count
  /// 4. **Batch Validation**: Validates each image individually with detailed progress logging
  /// 5. **Quality Filtering**: Filters out invalid or corrupted images from the final result set
  /// **Performance Optimization:**
  /// - Default limit of 5 images to prevent memory pressure and UI performance issues
  /// - Individual file validation with early rejection of invalid images
  /// - Efficient batch processing with detailed progress reporting
  /// - Intelligent limit enforcement that preserves user selection order
  /// **Validation Pipeline:**
  /// - File existence verification for each selected image
  /// - Format validation using StorageService integration
  /// - Size analysis and reporting for memory management
  /// - Detailed logging for each step of the validation process
  Future<List<File>> pickMultipleImages({int maxImages = 5}) async {
    try {
      AppLogger.info('🔍 Starting multiple image selection (max: $maxImages)');

      // Check gallery permission
      final hasPermission = await _checkAndRequestPermission(
        ImageSource.gallery,
      );
      AppLogger.info('🔑 Gallery permission: $hasPermission');

      if (!hasPermission) {
        AppLogger.warning('❌ Gallery permission denied');
        return [];
      }

      AppLogger.info('📱 Calling multiple image picker...');

      // BUT-992: same defaults as the single-pick path above.
      final List<XFile> pickedFiles = await _imagePickerProvider.pickMultiImage(
        maxWidth: 1600,
        maxHeight: 1600,
        imageQuality: 80,
      );

      if (pickedFiles.isEmpty) {
        AppLogger.info('❌ No images selected');
        return [];
      }

      AppLogger.info('📸 ${pickedFiles.length} images selected from picker');

      // Limit number of images
      final limitedFiles = pickedFiles.take(maxImages).toList();

      if (pickedFiles.length > maxImages) {
        AppLogger.info(
          '✂️ Limiting from ${pickedFiles.length} to $maxImages images',
        );
      }

      // Convert to File and validate
      final files = <File>[];
      for (int i = 0; i < limitedFiles.length; i++) {
        final xFile = limitedFiles[i];
        AppLogger.info('🔍 Processing image ${i + 1}: ${xFile.path}');

        final file = File(xFile.path);

        // Check that the file exists
        final exists = await file.exists();
        if (!exists) {
          AppLogger.warning('⚠️ File ${i + 1} does not exist: ${file.path}');
          continue;
        }

        // Check file size
        final size = await file.length();
        AppLogger.info('📊 Image ${i + 1} size: ${_formatBytes(size)}');

        if (_imageValidator.isValidImageFile(file)) {
          files.add(file);
          AppLogger.info('✅ Image ${i + 1} approved');
        } else {
          AppLogger.warning('❌ Image ${i + 1} is invalid: ${file.path}');
        }
      }

      AppLogger.success('🎉 ${files.length} valid images selected');
      return files;
    } catch (e, stackTrace) {
      AppLogger.error('💥 Error during multiple image selection: $e');
      AppLogger.error('📍 Stack trace: $stackTrace');
      return [];
    }
  }

  /// Crop and optionally rotate an image. Returns cropped file or null if cancelled.
  /// Uses square aspect ratio for recipe thumbnails with 90-degree rotation support.
  Future<File?> cropImage(File imageFile) async {
    try {
      if (kIsWeb) {
        // image_cropper has limited web support; skip cropping on web
        AppLogger.debug('Crop not supported on web, returning original');
        return imageFile;
      }

      final croppedFile = await ImageCropper().cropImage(
        sourcePath: imageFile.path,
        aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
        // BUT-992: match the picker's new JPEG-80 default.
        compressQuality: 80,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: AppLocale.current.imageCropTitle,
            lockAspectRatio: false,
            hideBottomControls: false,
          ),
          IOSUiSettings(
            title: AppLocale.current.imageCropTitle,
            aspectRatioLockEnabled: false,
            rotateButtonsHidden: false,
          ),
        ],
      );

      if (croppedFile == null) {
        AppLogger.info('Image crop cancelled by user');
        return null;
      }

      AppLogger.success('Image cropped: ${croppedFile.path}');
      return File(croppedFile.path);
    } catch (e) {
      AppLogger.error('Image crop failed: $e');
      return imageFile;
    }
  }

  /// Check and request permissions with debug logging
  Future<bool> _checkAndRequestPermission(ImageSource source) async {
    try {
      // Check if we're on web platform - permissions are handled by browser
      if (kIsWeb) {
        AppLogger.debug(
            '🌐 PERMISSION: Running on web - permissions handled by browser');
        return true;
      }

      if (source == ImageSource.camera) {
        AppLogger.debug('🔍 PERMISSION: Checking camera permission...');
        AppLogger.info('🔍 Checking camera permission...');
        final status =
            await _permissionProvider.checkPermission(Permission.camera);
        AppLogger.debug('📷 PERMISSION: Camera status: ${status.name}');
        AppLogger.info('📷 Camera permission status: ${status.name}');

        if (status.isDenied) {
          AppLogger.debug('🔑 PERMISSION: Requesting camera permission...');
          AppLogger.info('🔑 Requesting camera permission...');
          final result =
              await _permissionProvider.requestPermission(Permission.camera);
          AppLogger.debug(
              '📷 PERMISSION: Camera request result: ${result.name}');
          AppLogger.info('📷 Camera permission result: ${result.name}');
          return result.isGranted;
        }
        return status.isGranted;
      } else {
        // For gallery - handle both photos and storage permissions smartly
        AppLogger.debug('🔍 PERMISSION: Checking gallery permission...');
        AppLogger.info('🔍 Checking gallery permission...');
        final status =
            await _permissionProvider.checkPermission(Permission.photos);
        AppLogger.debug('🖼️ PERMISSION: Gallery status: ${status.name}');
        AppLogger.info('🖼️ Gallery permission status: ${status.name}');

        // LIMITED is OK for gallery - user has selected certain photos
        if (status.isGranted || status.isLimited) {
          return true;
        }

        if (status.isDenied) {
          AppLogger.info('🔑 Requesting gallery permission...');
          final result =
              await _permissionProvider.requestPermission(Permission.photos);
          AppLogger.info('🖼️ Gallery permission result: ${result.name}');

          // LIMITED is also OK
          if (result.isGranted || result.isLimited) {
            return true;
          }
        }

        // If photos permission is permanently denied, try storage (older Android)
        if (status.isPermanentlyDenied) {
          final storageStatus =
              await _permissionProvider.checkPermission(Permission.storage);

          if (storageStatus.isDenied) {
            final storageResult =
                await _permissionProvider.requestPermission(Permission.storage);
            return storageResult.isGranted;
          }
          return storageStatus.isGranted;
        }

        return false;
      }
    } catch (e) {
      AppLogger.error('💥 Error during permission check: $e');
      return false;
    }
  }

  /// Format bytes to human-readable text
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Debug method for testing permissions manually
  Future<void> debugPermissions() async {
    AppLogger.info('🔍 DEBUG: Checking all permissions...');

    // Camera
    final cameraStatus =
        await _permissionProvider.checkPermission(Permission.camera);
    AppLogger.info('📷 Camera: ${cameraStatus.name}');

    // Photos
    final photosStatus =
        await _permissionProvider.checkPermission(Permission.photos);
    AppLogger.info('🖼️ Photos: ${photosStatus.name}');

    // Storage (older Android)
    final storageStatus =
        await _permissionProvider.checkPermission(Permission.storage);
    AppLogger.info('💾 Storage: ${storageStatus.name}');

    // Media (newer Android)
    final mediaStatus =
        await _permissionProvider.checkPermission(Permission.mediaLibrary);
    AppLogger.info('📱 Media: ${mediaStatus.name}');
  }
}
