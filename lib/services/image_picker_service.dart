/// Comprehensive image selection service providing cross-platform camera and gallery access with advanced permission management.
///
/// This service provides sophisticated image selection functionality supporting both single and multiple image
/// selection workflows with comprehensive permission handling, platform-specific optimizations, and detailed
/// validation processes. It implements advanced debugging capabilities, cross-platform compatibility, and
/// robust error handling to ensure reliable image selection across different devices and operating systems.
///
/// **Architecture Integration:**
/// - Integrates with [ImagePicker] for native platform image selection capabilities
/// - Uses [PermissionHandler] for comprehensive permission management across platforms
/// - Coordinates with [StorageService] for image validation and file system operations
/// - Implements extensive logging through [AppLogger] for debugging and monitoring
/// - Separates UI logic to maintain clean architecture with dedicated dialog components
///
/// **Image Selection Features:**
/// - **Single Image Selection**: Camera and gallery access with quality optimization and size constraints
/// - **Multiple Image Selection**: Batch image selection with configurable limits and validation
/// - **Cross-Platform Permissions**: Smart permission handling for iOS, Android with version-specific strategies
/// - **Image Optimization**: Configurable quality settings, dimension constraints, and file size management
/// - **Validation Pipeline**: Comprehensive image validation including format, size, and accessibility checks
/// - **Error Recovery**: Robust error handling with detailed logging and graceful fallback strategies
///
/// **Permission Management:**
/// - **iOS Compatibility**: Photo library access with limited selection support
/// - **Android Optimization**: Version-specific permission strategies (storage vs photos permissions)
/// - **Smart Fallbacks**: Automatic fallback to alternative permission types when primary permissions fail
/// - **Permission Debugging**: Comprehensive permission status monitoring and diagnostic capabilities

import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/storage_service.dart';
import 'package:butlery/services/image_picker_provider.dart';
import 'package:butlery/core/base/base_service.dart';

/// Image selection service providing comprehensive camera and gallery access with advanced permission management.
///
/// This service manages complete image selection workflows including permission handling, image optimization,
/// validation, and cross-platform compatibility. It provides extensive debugging capabilities and robust
/// error handling to ensure reliable image selection functionality across different devices and platforms.
///
/// **Cross-Platform Architecture:**
/// Implements platform-specific strategies for optimal image selection:
/// - iOS: Photo library access with limited selection support and privacy compliance
/// - Android: Version-aware permission handling (storage vs photos permissions)
/// - Universal: Consistent API surface with platform-optimized implementations
///
/// **Image Processing Pipeline:**
/// Provides comprehensive image processing including:
/// - Quality optimization with configurable compression settings
/// - Dimension constraints to prevent memory issues with large images
/// - File validation with format checking and accessibility verification
/// - Batch processing support for multiple image selection workflows
///
/// **Usage Examples:**
/// ```dart
/// final imageService = ImagePickerService();
/// 
/// // Single image selection from camera
/// final cameraImage = await imageService.pickImage(ImageSource.camera);
/// 
/// // Multiple images from gallery
/// final galleryImages = await imageService.pickMultipleImages(maxImages: 5);
/// 
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
  }) : _imagePickerProvider = imagePickerProvider ?? DefaultImagePickerProvider(),
       _permissionProvider = permissionProvider ?? DefaultPermissionProvider(),
       _imageValidator = imageValidator ?? DefaultImageValidator();
       
  /// Get the last picked XFile (for web platform)
  XFile? get lastPickedXFile => _lastPickedXFile;

  /// Selects a single image from camera or gallery with comprehensive validation and optimization.
  ///
  /// This method provides complete single image selection functionality with advanced permission handling,
  /// image optimization, and comprehensive validation pipeline. It implements detailed logging throughout
  /// the selection process to enable debugging and monitoring of image selection workflows.
  ///
  /// [source] Image source (camera or gallery) for image selection
  /// Returns selected and validated [File] or `null` if selection fails or is cancelled
  ///
  /// **Selection Process:**
  /// 1. **Permission Validation**: Checks and requests appropriate permissions for the selected source
  /// 2. **Image Selection**: Uses native image picker with optimized quality and dimension settings
  /// 3. **File Validation**: Verifies file existence, accessibility, and format validity
  /// 4. **Quality Optimization**: Applies configurable quality settings (90% quality, max 2400x2400)
  /// 5. **Size Verification**: Validates file size and provides detailed logging information
  ///
  /// **Image Optimization Settings:**
  /// - Maximum dimensions: 2400x2400 pixels to prevent memory issues
  /// - Quality setting: 90% for optimal balance between quality and file size
  /// - Format validation: Ensures selected images are in supported formats
  ///
  /// **Error Handling:**
  /// - Comprehensive error logging with detailed stack traces
  /// - Graceful handling of permission denials and user cancellations
  /// - File system validation with detailed diagnostic information
  /// - Integration with StorageService for advanced image validation
  Future<File?> pickImage(ImageSource source) async {
    try {
      AppLogger.debug('🔍 IMAGE_PICKER: Starting image selection from: ${source.name}');
      AppLogger.info('🔍 Startar bildval från: ${source.name}');

      // Kontrollera permissions
      AppLogger.debug('🔍 IMAGE_PICKER: Checking permissions...');
      final hasPermission = await _checkAndRequestPermission(source);
      AppLogger.debug('🔑 IMAGE_PICKER: Permission result: $hasPermission');
      AppLogger.info('🔑 Permission resultat: $hasPermission');

      if (!hasPermission) {
        AppLogger.warning('❌ IMAGE_PICKER: Permission denied for ${source.name}');
        AppLogger.warning('❌ Permission nekad för ${source.name}');
        return null;
      }

      AppLogger.debug('📱 IMAGE_PICKER: Calling image picker provider...');
      AppLogger.info('📱 Anropar image picker...');
      final XFile? pickedFile = await _imagePickerProvider.pickImage(
        source: source,
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );

      if (pickedFile == null) {
        AppLogger.info('❌ IMAGE_PICKER: No image selected (user cancelled or error)');
        AppLogger.info('❌ Ingen bild vald (användaren avbröt)');
        return null;
      }

      AppLogger.info('✅ IMAGE_PICKER: Image selected: ${pickedFile.path}');
      AppLogger.info('✅ Bild vald: ${pickedFile.path}');
      
      // Store the XFile for web platform
      _lastPickedXFile = pickedFile;

      // On web, we work with XFile directly instead of File
      if (kIsWeb) {
        AppLogger.debug('🌐 IMAGE_PICKER: Web platform - returning placeholder File with blob URL');
        // For web, return a File with the blob URL
        // The actual upload will need to read bytes from the XFile
        return File(pickedFile.path); // This is a blob URL on web
      }

      // On mobile platforms, proceed with normal File handling
      final file = File(pickedFile.path);

      // Kontrollera att filen existerar
      final exists = await file.exists();
      AppLogger.info('📁 Fil existerar: $exists');

      if (!exists) {
        AppLogger.error('❌ Filen existerar inte på disk');
        return null;
      }

      // Kontrollera filstorlek
      final size = await file.length();
      AppLogger.info('📊 Filstorlek: $size bytes (${_formatBytes(size)})');

      // Validera filen
      final isValid = _imageValidator.isValidImageFile(file);
      AppLogger.info('✅ Fil är giltig: $isValid');

      if (!isValid) {
        AppLogger.error('❌ Ogiltig bildfil: ${file.path}');
        return null;
      }

      AppLogger.success('🎉 Bildval framgångsrikt!');
      return file;
    } catch (e, stackTrace) {
      AppLogger.error('💥 Fel vid bildval: $e');
      AppLogger.error('📍 Stack trace: $stackTrace');
      return null;
    }
  }

  /// Selects multiple images from gallery with batch validation and configurable limits.
  ///
  /// This method provides comprehensive multiple image selection functionality with intelligent batch
  /// processing, configurable image limits, and comprehensive validation for each selected image.
  /// It implements advanced error handling and detailed logging for complex multi-image workflows.
  ///
  /// [maxImages] Maximum number of images to select (defaults to 5 for performance)
  /// Returns list of validated [File] objects, empty list if selection fails or is cancelled
  ///
  /// **Batch Selection Process:**
  /// 1. **Gallery Permission**: Validates gallery access permissions with smart fallback strategies
  /// 2. **Multi-Image Selection**: Uses native multi-image picker with optimization settings
  /// 3. **Limit Enforcement**: Intelligently limits selection to specified maximum count
  /// 4. **Batch Validation**: Validates each image individually with detailed progress logging
  /// 5. **Quality Filtering**: Filters out invalid or corrupted images from the final result set
  ///
  /// **Performance Optimization:**
  /// - Default limit of 5 images to prevent memory pressure and UI performance issues
  /// - Individual file validation with early rejection of invalid images
  /// - Efficient batch processing with detailed progress reporting
  /// - Intelligent limit enforcement that preserves user selection order
  ///
  /// **Validation Pipeline:**
  /// - File existence verification for each selected image
  /// - Format validation using StorageService integration
  /// - Size analysis and reporting for memory management
  /// - Detailed logging for each step of the validation process
  Future<List<File>> pickMultipleImages({int maxImages = 5}) async {
    try {
      AppLogger.info('🔍 Startar val av flera bilder (max: $maxImages)');

      // Kontrollera gallery permission
      final hasPermission = await _checkAndRequestPermission(
        ImageSource.gallery,
      );
      AppLogger.info('🔑 Gallery permission: $hasPermission');

      if (!hasPermission) {
        AppLogger.warning('❌ Gallery permission nekad');
        return [];
      }

      AppLogger.info('📱 Anropar multiple image picker...');

      final List<XFile> pickedFiles = await _imagePickerProvider.pickMultiImage(
        maxWidth: 2400,
        maxHeight: 2400,
        imageQuality: 90,
      );

      if (pickedFiles.isEmpty) {
        AppLogger.info('❌ Inga bilder valda');
        return [];
      }

      AppLogger.info('📸 ${pickedFiles.length} bilder valda från picker');

      // Begränsa antal bilder
      final limitedFiles = pickedFiles.take(maxImages).toList();

      if (pickedFiles.length > maxImages) {
        AppLogger.info(
          '✂️ Begränsar från ${pickedFiles.length} till $maxImages bilder',
        );
      }

      // Konvertera till File och validera
      final files = <File>[];
      for (int i = 0; i < limitedFiles.length; i++) {
        final xFile = limitedFiles[i];
        AppLogger.info('🔍 Bearbetar bild ${i + 1}: ${xFile.path}');

        final file = File(xFile.path);

        // Kontrollera att filen existerar
        final exists = await file.exists();
        if (!exists) {
          AppLogger.warning('⚠️ Fil ${i + 1} existerar inte: ${file.path}');
          continue;
        }

        // Kontrollera filstorlek
        final size = await file.length();
        AppLogger.info('📊 Bild ${i + 1} storlek: ${_formatBytes(size)}');

        if (_imageValidator.isValidImageFile(file)) {
          files.add(file);
          AppLogger.info('✅ Bild ${i + 1} godkänd');
        } else {
          AppLogger.warning('❌ Bild ${i + 1} är ogiltig: ${file.path}');
        }
      }

      AppLogger.success('🎉 ${files.length} giltiga bilder valda');
      return files;
    } catch (e, stackTrace) {
      AppLogger.error('💥 Fel vid val av flera bilder: $e');
      AppLogger.error('📍 Stack trace: $stackTrace');
      return [];
    }
  }

  /// Kontrollera och begär permissions MED DEBUG
  Future<bool> _checkAndRequestPermission(ImageSource source) async {
    try {
      // Check if we're on web platform - permissions are handled by browser
      if (kIsWeb) {
        AppLogger.debug('🌐 PERMISSION: Running on web - permissions handled by browser');
        return true;
      }
      
      if (source == ImageSource.camera) {
        AppLogger.debug('🔍 PERMISSION: Checking camera permission...');
        AppLogger.info('🔍 Kontrollerar kamera-permission...');
        final status = await _permissionProvider.checkPermission(Permission.camera);
        AppLogger.debug('📷 PERMISSION: Camera status: ${status.name}');
        AppLogger.info('📷 Kamera permission status: ${status.name}');

        if (status.isDenied) {
          AppLogger.debug('🔑 PERMISSION: Requesting camera permission...');
          AppLogger.info('🔑 Begär kamera-permission...');
          final result = await _permissionProvider.requestPermission(Permission.camera);
          AppLogger.debug('📷 PERMISSION: Camera request result: ${result.name}');
          AppLogger.info('📷 Kamera permission resultat: ${result.name}');
          return result.isGranted;
        }
        return status.isGranted;
      } else {
        // För galleri - hantera både photos och storage permissions smart
        AppLogger.debug('🔍 PERMISSION: Checking gallery permission...');
        AppLogger.info('🔍 Kontrollerar galleri-permission...');
        final status = await _permissionProvider.checkPermission(Permission.photos);
        AppLogger.debug('🖼️ PERMISSION: Gallery status: ${status.name}');
        AppLogger.info('🖼️ Galleri permission status: ${status.name}');

        // LIMITED är OK för galleri - användaren har valt vissa bilder
        if (status.isGranted || status.isLimited) {
          return true;
        }

        if (status.isDenied) {
          AppLogger.info('🔑 Begär galleri-permission...');
          final result = await _permissionProvider.requestPermission(Permission.photos);
          AppLogger.info('🖼️ Galleri permission resultat: ${result.name}');

          // LIMITED är också OK
          if (result.isGranted || result.isLimited) {
            return true;
          }
        }

        // Om photos permission är permanently denied, testa storage (äldre Android)
        if (status.isPermanentlyDenied) {
          final storageStatus = await _permissionProvider.checkPermission(Permission.storage);

          if (storageStatus.isDenied) {
            final storageResult = await _permissionProvider.requestPermission(Permission.storage);
            return storageResult.isGranted;
          }
          return storageStatus.isGranted;
        }

        return false;
      }
    } catch (e) {
      AppLogger.error('💥 Fel vid permission-kontroll: $e');
      return false;
    }
  }

  /// Formatera bytes till läsbar text
  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  /// Debug-metod för att testa permissions manuellt
  Future<void> debugPermissions() async {
    AppLogger.info('🔍 DEBUG: Kontrollerar alla permissions...');

    // Kamera
    final cameraStatus = await _permissionProvider.checkPermission(Permission.camera);
    AppLogger.info('📷 Kamera: ${cameraStatus.name}');

    // Photos
    final photosStatus = await _permissionProvider.checkPermission(Permission.photos);
    AppLogger.info('🖼️ Photos: ${photosStatus.name}');

    // Storage (äldre Android)
    final storageStatus = await _permissionProvider.checkPermission(Permission.storage);
    AppLogger.info('💾 Storage: ${storageStatus.name}');

    // Media (nyare Android)
    final mediaStatus = await _permissionProvider.checkPermission(Permission.mediaLibrary);
    AppLogger.info('📱 Media: ${mediaStatus.name}');
  }
}