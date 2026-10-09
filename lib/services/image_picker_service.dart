/// Comprehensive image selection service providing cross-platform camera and gallery access with advanced permission management.
/// This service provides sophisticated image selection functionality supporting both single and multiple image
/// selection workflows with comprehensive permission handling, platform-specific optimizations, and detailed
/// validation processes. It implements advanced debugging capabilities, cross-platform compatibility, and
/// robust error handling to ensure reliable image selection across different devices and operating systems.
/// **Architecture Integration:**
/// - Integrates with [ImagePicker] for native platform image selection capabilities
/// - Uses [PermissionProvider] for comprehensive permission management across platforms
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
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/image_picker_provider.dart';
import 'package:butlery/core/base/base_service.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

export 'package:butlery/core/utils/os_permission_helper.dart'
    show OsPermissionOutcome, OsPermissionOutcomeX;

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
/// Our own explanation before the system prompt for camera or photos
/// (flows-roles-budget.md:100; Skarmar v12 etapp 3 #behkamera). Returns true
/// when the user tapped Tillåt. The OS is asked only then
/// (produktregler.md:682).
typedef MediaRationalePrompt = Future<bool> Function(ImageSource source);

/// What a pick produced, with the permission outcome that decided it
/// (flow 07). Replaces the bare `null` / `[]` that could not tell a
/// cancelled pick from a denied permission.
class ImagePickOutcome {
  const ImagePickOutcome({required this.permission, this.files = const []});

  /// The typed permission outcome for the source that was asked for.
  final OsPermissionOutcome permission;

  /// The picked and validated files. Empty when the user cancelled, the
  /// permission was not usable, or no file passed validation.
  final List<File> files;

  /// The single picked file, when there is one.
  File? get file => files.isEmpty ? null : files.first;

  /// True when the permission, not the user, stopped the pick.
  bool get blockedByPermission => !permission.isUsable;
}

/// Our explanation before the system prompt for camera and photos on the
/// surfaces other than recipe import (avatar, recipe images, comments).
/// Recipe import has its own drawn copy (Skarmar v12 etapp 3 #behkamera).
MediaRationalePrompt mediaRationalePrompt(BuildContext context) =>
    (source) async {
      if (!context.mounted) return false;
      final l10n = context.l10n;
      final camera = source == ImageSource.camera;
      return OsPermissionHelper.presentExplanation(
        context,
        title: camera ? l10n.permCameraTitle : l10n.permPhotosTitle,
        body: camera ? l10n.permCameraBody : l10n.permPhotosBody,
        grantLabel: l10n.permAllow,
        declineLabel: l10n.permNotNow,
        icon: camera ? ButleryIcons.camera : ButleryIcons.image,
      );
    };

/// Explains a permission answer that stopped a pick, on the surfaces other
/// than recipe import (flow 07): a permanent no says so with "Öppna
/// inställningar"; a device block says so without a button; a plain no is a
/// silent skip — tapping the control again asks again
/// (produktregler.md:683). These surfaces offer no invented alternative
/// (Q-P6-E15; produktregler.md:535).
void explainMediaPermission(
  BuildContext context,
  OsPermissionOutcome outcome,
  ImageSource source,
) {
  if (!context.mounted) return;
  final l10n = context.l10n;
  final camera = source == ImageSource.camera;
  switch (outcome) {
    case OsPermissionOutcome.permanentlyDenied:
      final messenger = ScaffoldMessenger.maybeOf(context);
      messenger?.showSnackBar(
        SnackBar(
          content: Text(
            camera
                ? l10n.permCameraPermanentlyDenied
                : l10n.permPhotosPermanentlyDenied,
          ),
          behavior: SnackBarBehavior.floating,
          action: SnackBarAction(
            label: l10n.permOpenSettings,
            onPressed: () => OsPermissionHelper.openSettings(),
          ),
        ),
      );
    case OsPermissionOutcome.restricted:
      OsPermissionHelper.presentRestricted(
        context,
        camera ? l10n.permCameraRestricted : l10n.permPhotosRestricted,
      );
    case OsPermissionOutcome.granted:
    case OsPermissionOutcome.limited:
    case OsPermissionOutcome.denied:
      break;
  }
}

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
  }) : _imagePickerProvider =
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
    final outcome = await pickImageWithOutcome(
      source,
      enableCrop: enableCrop,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
    return outcome.file;
  }

  /// [pickImage] with the typed permission outcome (flow 07). With a
  /// [rationale], our explanation comes before the system prompt and the OS
  /// is asked only after Tillåt (produktregler.md:682). Without one, the
  /// system prompt comes directly, as before.
  Future<ImagePickOutcome> pickImageWithOutcome(
    ImageSource source, {
    MediaRationalePrompt? rationale,
    bool enableCrop = false,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    var permission = OsPermissionOutcome.denied;
    try {
      AppLogger.debug(
        '🔍 IMAGE_PICKER: Starting image selection from: ${source.name}',
      );
      AppLogger.info('🔍 Starting image selection from: ${source.name}');

      // Check permissions
      AppLogger.debug('🔍 IMAGE_PICKER: Checking permissions...');
      permission = await resolvePermission(source, rationale: rationale);
      AppLogger.info('🔑 Permission result: ${permission.name}');

      if (!permission.isUsable) {
        AppLogger.warning('❌ Permission not usable for ${source.name}');
        return ImagePickOutcome(permission: permission);
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
          '❌ IMAGE_PICKER: No image selected (user cancelled or error)',
        );
        AppLogger.info('❌ No image selected (user cancelled)');
        return ImagePickOutcome(permission: permission);
      }

      AppLogger.info('✅ IMAGE_PICKER: Image selected: ${pickedFile.path}');
      AppLogger.info('✅ Image selected: ${pickedFile.path}');

      // Store the XFile for web platform
      _lastPickedXFile = pickedFile;

      // On web, we work with XFile directly instead of File
      if (kIsWeb) {
        AppLogger.debug(
          '🌐 IMAGE_PICKER: Web platform - returning placeholder File with blob URL',
        );
        // For web, return a File with the blob URL
        // The actual upload will need to read bytes from the XFile
        return ImagePickOutcome(
          permission: permission,
          files: [File(pickedFile.path)], // A blob URL on web
        );
      }

      // On mobile platforms, proceed with normal File handling
      final file = File(pickedFile.path);

      // Check that the file exists
      final exists = await file.exists();
      AppLogger.info('📁 File exists: $exists');

      if (!exists) {
        AppLogger.error('❌ File does not exist on disk');
        return ImagePickOutcome(permission: permission);
      }

      // Check file size
      final size = await file.length();
      AppLogger.info('📊 File size: $size bytes (${_formatBytes(size)})');

      // Validate the file
      final isValid = _imageValidator.isValidImageFile(file);
      AppLogger.info('✅ File is valid: $isValid');

      if (!isValid) {
        AppLogger.error('❌ Invalid image file: ${file.path}');
        return ImagePickOutcome(permission: permission);
      }

      AppLogger.success('🎉 Image selection successful!');

      // Crop if requested (mobile only — web returns early above)
      if (enableCrop) {
        final cropped = await cropImage(file);
        return ImagePickOutcome(
          permission: permission,
          files: [cropped ?? file],
        );
      }

      return ImagePickOutcome(permission: permission, files: [file]);
    } catch (e, stackTrace) {
      AppLogger.error('💥 Error during image selection: $e');
      AppLogger.error('📍 Stack trace: $stackTrace');
      return ImagePickOutcome(permission: permission);
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
    final outcome = await pickMultipleImagesWithOutcome(maxImages: maxImages);
    return outcome.files;
  }

  /// [pickMultipleImages] with the typed permission outcome (flow 07); see
  /// [pickImageWithOutcome] for [rationale].
  Future<ImagePickOutcome> pickMultipleImagesWithOutcome({
    int maxImages = 5,
    MediaRationalePrompt? rationale,
  }) async {
    var permission = OsPermissionOutcome.denied;
    try {
      AppLogger.info('🔍 Starting multiple image selection (max: $maxImages)');

      // Check gallery permission
      permission = await resolvePermission(
        ImageSource.gallery,
        rationale: rationale,
      );
      AppLogger.info('🔑 Gallery permission: ${permission.name}');

      if (!permission.isUsable) {
        AppLogger.warning('❌ Gallery permission not usable');
        return ImagePickOutcome(permission: permission);
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
        return ImagePickOutcome(permission: permission);
      }

      AppLogger.info('📸 ${pickedFiles.length} images selected from picker');

      // Limit number of images
      final limitedFiles = pickedFiles.take(maxImages).toList();

      if (pickedFiles.length > maxImages) {
        AppLogger.info(
          '✂️ Limiting from ${pickedFiles.length} to $maxImages images',
        );
      }

      // Same as the single-pick path: on web each path is a blob URL, and the
      // file checks below throw there, which the catch turned into an empty
      // pick that looked like a cancel.
      if (kIsWeb) {
        return ImagePickOutcome(
          permission: permission,
          files: [for (final xFile in limitedFiles) File(xFile.path)],
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
      return ImagePickOutcome(permission: permission, files: files);
    } catch (e, stackTrace) {
      AppLogger.error('💥 Error during multiple image selection: $e');
      AppLogger.error('📍 Stack trace: $stackTrace');
      return ImagePickOutcome(permission: permission);
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

  /// Resolves the camera or photo-library permission to a typed outcome
  /// (flow 07, flows-roles-budget.md:98-106; produktregler.md:680-687).
  ///
  /// With a [rationale], our explanation comes first and the OS is asked only
  /// after Tillåt; "Inte nu" returns [OsPermissionOutcome.denied] without
  /// touching the OS budget. A permanent no is never re-asked here, and a
  /// device-blocked permission is [OsPermissionOutcome.restricted].
  /// [skipRationale] is for an explicit "Fråga igen".
  Future<OsPermissionOutcome> resolvePermission(
    ImageSource source, {
    MediaRationalePrompt? rationale,
    bool skipRationale = false,
  }) async {
    try {
      // Web: the browser owns the prompt.
      if (kIsWeb) return OsPermissionOutcome.granted;

      final permission = source == ImageSource.camera
          ? Permission.camera
          : Permission.photos;
      final status = OsPermissionHelper.outcomeOf(
        await _permissionProvider.checkPermission(permission),
      );
      AppLogger.info('🔍 ${permission.toString()} status: ${status.name}');

      if (status.isUsable || status == OsPermissionOutcome.restricted) {
        return status;
      }

      if (status == OsPermissionOutcome.permanentlyDenied) {
        // Older Android keeps the gallery behind the storage permission.
        if (source == ImageSource.gallery) {
          return _resolveLegacyStorage();
        }
        return status;
      }

      if (rationale != null && !skipRationale) {
        final wantsToGrant = await rationale(source);
        if (!wantsToGrant) return OsPermissionOutcome.denied;
      }
      final result = OsPermissionHelper.outcomeOf(
        await _permissionProvider.requestPermission(permission),
      );
      AppLogger.info('🔑 ${permission.toString()} result: ${result.name}');
      return result;
    } catch (e) {
      AppLogger.error('💥 Error during permission check: $e');
      return OsPermissionOutcome.denied;
    }
  }

  /// The storage route behind a permanent photos no. Our explanation is not
  /// shown here: the user has already said no to photos, and a second no is
  /// a silent skip with no repeated explanation (produktregler.md:683). On
  /// Android 13+ storage reads as denied and a request is refused without a
  /// dialog, so this falls through to the permanent-no notice.
  Future<OsPermissionOutcome> _resolveLegacyStorage() async {
    final storage = OsPermissionHelper.outcomeOf(
      await _permissionProvider.checkPermission(Permission.storage),
    );
    if (storage.isUsable) return storage;
    if (storage != OsPermissionOutcome.denied) {
      // Photos permanently denied and no storage route either.
      return OsPermissionOutcome.permanentlyDenied;
    }
    final result = OsPermissionHelper.outcomeOf(
      await _permissionProvider.requestPermission(Permission.storage),
    );
    return result.isUsable ? result : OsPermissionOutcome.permanentlyDenied;
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
    final cameraStatus = await _permissionProvider.checkPermission(
      Permission.camera,
    );
    AppLogger.info('📷 Camera: ${cameraStatus.name}');

    // Photos
    final photosStatus = await _permissionProvider.checkPermission(
      Permission.photos,
    );
    AppLogger.info('🖼️ Photos: ${photosStatus.name}');

    // Storage (older Android)
    final storageStatus = await _permissionProvider.checkPermission(
      Permission.storage,
    );
    AppLogger.info('💾 Storage: ${storageStatus.name}');

    // Media (newer Android)
    final mediaStatus = await _permissionProvider.checkPermission(
      Permission.mediaLibrary,
    );
    AppLogger.info('📱 Media: ${mediaStatus.name}');
  }
}
