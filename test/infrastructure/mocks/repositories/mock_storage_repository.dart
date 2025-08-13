import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/interfaces/storage_repository.dart';

/// Mock implementation of StorageRepository for testing
///
/// This mock follows the architecture pattern: NO concrete implementations.
/// All methods are handled by Mock to allow proper stubbing with when().
/// Only configuration state and getters are implemented.
class MockStorageRepository extends Mock implements StorageRepository {
  // Configuration state for test tracking
  final Map<String, String> _uploadedFiles = {};
  final Set<String> _deletedFiles = {};

  // Test helper getters for verification
  Map<String, String> get uploadedFiles => Map.unmodifiable(_uploadedFiles);
  Set<String> get deletedFiles => Set.unmodifiable(_deletedFiles);

  // Configuration methods for tests
  void trackUpload(String path, String url) {
    _uploadedFiles[path] = url;
  }

  void trackDeletion(String url) {
    _deletedFiles.add(url);
  }

  // Reset method for test cleanup
  void resetForTesting() {
    _uploadedFiles.clear();
    _deletedFiles.clear();
  }

  // NO method implementations - Mock handles all these methods:
  // - uploadImage()
  // - uploadImageData()
  // - uploadMultipleImages()
  // - deleteImage()
  // - deleteMultipleImages()
  // - generateFileName()
  // - isValidImageFile()
  // - getUserStorageInfo()
  // - createAndUploadThumbnail()
  // - deleteThumbnail()
  // - getReference()
  // - createReference()
  // - compressImage()
  // - formatBytes()
  //
  // These can all be stubbed with when() in tests
}
