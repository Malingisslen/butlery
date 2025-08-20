import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

/// Abstraction for image picking functionality to enable dependency injection and testing
abstract class ImagePickerProvider {
  /// Pick a single image from the specified source
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  });
  
  /// Pick multiple images from gallery
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  });
}

/// Abstraction for permission handling to enable dependency injection and testing
abstract class PermissionProvider {
  /// Check permission status
  Future<PermissionStatus> checkPermission(Permission permission);
  
  /// Request permission
  Future<PermissionStatus> requestPermission(Permission permission);
}

/// Default implementation using ImagePicker
class DefaultImagePickerProvider implements ImagePickerProvider {
  final ImagePicker _picker;
  
  DefaultImagePickerProvider({ImagePicker? picker}) 
    : _picker = picker ?? ImagePicker();
  
  @override
  Future<XFile?> pickImage({
    required ImageSource source,
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    return await _picker.pickImage(
      source: source,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }
  
  @override
  Future<List<XFile>> pickMultiImage({
    double? maxWidth,
    double? maxHeight,
    int? imageQuality,
  }) async {
    return await _picker.pickMultiImage(
      maxWidth: maxWidth,
      maxHeight: maxHeight,
      imageQuality: imageQuality,
    );
  }
}

/// Default implementation for permission handling
class DefaultPermissionProvider implements PermissionProvider {
  @override
  Future<PermissionStatus> checkPermission(Permission permission) async {
    return await permission.status;
  }
  
  @override
  Future<PermissionStatus> requestPermission(Permission permission) async {
    return await permission.request();
  }
}

/// Abstraction for file validation
abstract class ImageValidator {
  /// Check if a file is a valid image
  bool isValidImageFile(File file);
}

/// Default implementation using StorageService
class DefaultImageValidator implements ImageValidator {
  @override
  bool isValidImageFile(File file) {
    // Import will be fixed in the refactored service
    // For now, just check file extension
    final validExtensions = ['.jpg', '.jpeg', '.png', '.gif', '.webp'];
    final extension = file.path.toLowerCase();
    return validExtensions.any((ext) => extension.endsWith(ext));
  }
}