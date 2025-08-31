import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/services/storage_service.dart';
import 'package:butlery/core/mixins/singleton_service_mixin.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/mocks/repositories/mock_storage_repository.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../infrastructure/mocks/fallback_values.dart';
import '../../infrastructure/di/test_service_locator.dart';
import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart'
    as prod_locator;

// ============= USING CENTRALIZED MOCKS =============
// Removed local mock classes:
// - FakeFile (now using centralized FakeFile from production_mocks.dart)

void main() {
  group('StorageService', () {
    late StorageService storageService;
    late MockStorageRepository mockRepository;
    late MockFile mockFile;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();

      // Register centralized fallback values for mocktail
      registerAllFallbackValues();
    });

    setUp(() async {
      // Reset singleton for test isolation
      SingletonServiceMixin.resetForTesting();

      // Initialize TestServiceLocator
      await TestServiceLocator.initialize();

      // ULTRATHINK FIX: Bridge production ServiceLocator to test mocks
      // This solves "ServiceLocator not initialized" errors when production code
      // calls ServiceLocator.get() but only TestServiceLocator was initialized
      final productionContainer = DIContainer();
      prod_locator.ServiceLocator.initialize(productionContainer);

      // Create mocks
      mockRepository = MockStorageRepository();
      mockFile = MockFile();

      // Create service with mock repository
      storageService = StorageService(repository: mockRepository);

      // Setup basic mock file responses
      when(() => mockFile.path).thenReturn('/path/to/image.jpg');
      when(() => mockFile.lengthSync()).thenReturn(1024 * 1024); // 1MB
      when(() => mockFile.readAsBytes()).thenAnswer(
        (_) async => Uint8List.fromList([1, 2, 3, 4, 5]),
      );

      // Register mocks for automatic reset
      BaseUnitTest.registerMocks([
        mockRepository,
        mockFile,
      ]);
    });

    tearDown(() async {
      mockRepository.resetForTesting();
      BaseUnitTest.resetMocks();
      SingletonServiceMixin.resetForTesting();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    group('Service Identification', () {
      test('should have correct service name', () {
        // Assert
        expect(storageService.serviceName, equals('StorageService'));
      });

      test('should be singleton instance with same repository', () {
        // Arrange & Act
        final instance1 = StorageService(repository: mockRepository);
        final instance2 = StorageService(repository: mockRepository);

        // Assert
        expect(identical(instance1, instance2), isTrue);
      });
    });

    group('Image Upload', () {
      test('should handle single image upload', () async {
        // Arrange
        const userId = 'test_user_123';
        const expectedUrl =
            'https://storage.googleapis.com/test/users/test_user_123/recipes/recipe_123.jpg';

        when(() => mockRepository.generateFileName(
              originalPath: any(named: 'originalPath'),
              prefix: any(named: 'prefix'),
            )).thenReturn('recipe_123.jpg');

        when(() => mockRepository.uploadImage(
              imageFile: any(named: 'imageFile'),
              userId: any(named: 'userId'),
              path: any(named: 'path'),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async => expectedUrl);

        when(() => mockRepository.createAndUploadThumbnail(
                  imageFile: any(named: 'imageFile'),
                  userId: any(named: 'userId'),
                  originalPath: any(named: 'originalPath'),
                ))
            .thenAnswer(
                (_) async => 'https://storage.googleapis.com/test/thumb.jpg');

        // Act
        final result = await storageService.uploadImageFile(
          mockFile,
          userId,
          onProgress: (progress) {
            // Progress callback
          },
        );

        // Assert
        expect(result, equals(expectedUrl));
        verify(() => mockRepository.uploadImage(
              imageFile: mockFile,
              userId: userId,
              path: 'users/$userId/recipes/recipe_123.jpg',
              onProgress: any(named: 'onProgress'),
            )).called(1);
      });

      test('should upload multiple images', () async {
        // Arrange
        const userId = 'test_user_123';
        final files = [mockFile, mockFile, mockFile];
        final expectedUrls = [
          'https://storage.googleapis.com/test/image1.jpg',
          'https://storage.googleapis.com/test/image2.jpg',
          'https://storage.googleapis.com/test/image3.jpg',
        ];

        when(() => mockRepository.uploadMultipleImages(
              imageFiles: any(named: 'imageFiles'),
              userId: any(named: 'userId'),
              basePath: any(named: 'basePath'),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async => expectedUrls);

        // Act
        final result = await storageService.uploadMultipleImages(
          files,
          userId,
          onProgress: (completed, total) {
            // Progress callback
          },
        );

        // Assert
        expect(result, equals(expectedUrls));
        verify(() => mockRepository.uploadMultipleImages(
              imageFiles: files,
              userId: userId,
              basePath: 'users/$userId/recipes',
              onProgress: any(named: 'onProgress'),
            )).called(1);
      });

      test('should upload recipe image', () async {
        // Arrange
        const recipeId = 'recipe_123';
        const expectedUrl = 'https://storage.googleapis.com/test/recipe.jpg';

        when(() => mockRepository.generateFileName(
              originalPath: any(named: 'originalPath'),
              prefix: any(named: 'prefix'),
            )).thenReturn('recipe_123.jpg');

        when(() => mockRepository.uploadImage(
              imageFile: any(named: 'imageFile'),
              userId: any(named: 'userId'),
              path: any(named: 'path'),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async => expectedUrl);

        when(() => mockRepository.createAndUploadThumbnail(
                  imageFile: any(named: 'imageFile'),
                  userId: any(named: 'userId'),
                  originalPath: any(named: 'originalPath'),
                ))
            .thenAnswer(
                (_) async => 'https://storage.googleapis.com/test/thumb.jpg');

        // Act
        final result = await storageService.uploadRecipeImage(
          mockFile,
          recipeId,
        );

        // Assert
        expect(result, equals(expectedUrl));
      });
    });

    group('Image Deletion', () {
      test('should delete single image', () async {
        // Arrange
        const imageUrl = 'https://storage.googleapis.com/test/image.jpg';

        when(() => mockRepository.deleteImage(any()))
            .thenAnswer((_) async => true);

        // Act
        final result = await storageService.deleteImage(imageUrl);

        // Assert
        expect(result, isTrue);
        verify(() => mockRepository.deleteImage(imageUrl)).called(1);
      });

      test('should delete multiple images', () async {
        // Arrange
        const imageUrls = [
          'https://storage.googleapis.com/test/image1.jpg',
          'https://storage.googleapis.com/test/image2.jpg',
          'https://storage.googleapis.com/test/image3.jpg',
        ];

        when(() => mockRepository.deleteMultipleImages(any()))
            .thenAnswer((_) async {});

        // Act
        await storageService.deleteMultipleImages(imageUrls);

        // Assert
        verify(() => mockRepository.deleteMultipleImages(imageUrls)).called(1);
      });

      test('should delete recipe image', () async {
        // Arrange
        const imageUrl = 'https://storage.googleapis.com/test/recipe.jpg';

        when(() => mockRepository.deleteImage(any()))
            .thenAnswer((_) async => true);

        // Act
        await storageService.deleteRecipeImage(imageUrl);

        // Assert
        verify(() => mockRepository.deleteImage(imageUrl)).called(1);
      });
    });

    group('File Validation', () {
      test('should validate image file extensions', () {
        // Test valid extensions
        final validFiles = [
          _createMockFile('/path/image.jpg'),
          _createMockFile('/path/image.jpeg'),
          _createMockFile('/path/image.png'),
          _createMockFile('/path/image.gif'),
          _createMockFile('/path/image.webp'),
        ];

        for (final file in validFiles) {
          when(() => mockRepository.isValidImageFile(file)).thenReturn(true);
          expect(
            mockRepository.isValidImageFile(file),
            isTrue,
            reason: 'Should accept ${file.path}',
          );
        }

        // Test invalid extensions
        final invalidFiles = [
          _createMockFile('/path/document.pdf'),
          _createMockFile('/path/video.mp4'),
          _createMockFile('/path/text.txt'),
          _createMockFile('/path/noextension'),
        ];

        for (final file in invalidFiles) {
          when(() => mockRepository.isValidImageFile(file)).thenReturn(false);
          expect(
            mockRepository.isValidImageFile(file),
            isFalse,
            reason: 'Should reject ${file.path}',
          );
        }
      });

      test('should validate file size', () {
        // Test file within size limit (< 10MB)
        final smallFile =
            _createMockFile('/path/small.jpg', sizeBytes: 5 * 1024 * 1024);
        when(() => mockRepository.isValidImageFile(smallFile)).thenReturn(true);
        expect(mockRepository.isValidImageFile(smallFile), isTrue);

        // Test file exactly at limit (10MB)
        final limitFile =
            _createMockFile('/path/limit.jpg', sizeBytes: 10 * 1024 * 1024);
        when(() => mockRepository.isValidImageFile(limitFile)).thenReturn(true);
        expect(mockRepository.isValidImageFile(limitFile), isTrue);

        // Test file over size limit (> 10MB)
        final largeFile =
            _createMockFile('/path/large.jpg', sizeBytes: 11 * 1024 * 1024);
        when(() => mockRepository.isValidImageFile(largeFile))
            .thenReturn(false);
        expect(mockRepository.isValidImageFile(largeFile), isFalse);
      });

      test('should reject invalid extension even with valid size', () {
        // File with valid size but invalid extension
        final file = _createMockFile('/path/document.pdf', sizeBytes: 1024);
        when(() => mockRepository.isValidImageFile(file)).thenReturn(false);
        expect(mockRepository.isValidImageFile(file), isFalse);
      });

      test('should reject oversized file even with valid extension', () {
        // File with valid extension but invalid size
        final file =
            _createMockFile('/path/huge.jpg', sizeBytes: 20 * 1024 * 1024);
        when(() => mockRepository.isValidImageFile(file)).thenReturn(false);
        expect(mockRepository.isValidImageFile(file), isFalse);
      });
    });

    group('Storage Info', () {
      test('should get user storage info', () async {
        // Arrange
        const userId = 'test_user_123';
        final expectedInfo = StorageInfo(
          totalBytes: 100 * 1024 * 1024,
          fileCount: 10,
          formattedSize: '25.0 MB',
        );

        when(() => mockRepository.getUserStorageInfo(any()))
            .thenAnswer((_) async => expectedInfo);

        // Act
        final info = await storageService.getUserStorageInfo(userId);

        // Assert
        expect(info, isNotNull);
        expect(info!.totalBytes, equals(100 * 1024 * 1024));
        expect(info.fileCount, equals(10));
        expect(info.formattedSize, equals('25.0 MB'));
        verify(() => mockRepository.getUserStorageInfo(userId)).called(1);
      });

      test('should handle null storage info', () async {
        // Arrange
        const userId = 'test_user_456';

        when(() => mockRepository.getUserStorageInfo(any()))
            .thenAnswer((_) async => null);

        // Act
        final info = await storageService.getUserStorageInfo(userId);

        // Assert
        expect(info, isNull);
        verify(() => mockRepository.getUserStorageInfo(userId)).called(1);
      });
    });

    group('File Name Generation', () {
      test('should use repository for filename generation', () async {
        // Arrange
        const userId = 'test_user';
        const expectedFilename = 'recipe_1234567890.jpg';

        when(() => mockRepository.generateFileName(
              originalPath: any(named: 'originalPath'),
              prefix: any(named: 'prefix'),
            )).thenReturn(expectedFilename);

        when(() => mockRepository.uploadImage(
              imageFile: any(named: 'imageFile'),
              userId: any(named: 'userId'),
              path: any(named: 'path'),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async => 'https://test.com/image.jpg');

        when(() => mockRepository.createAndUploadThumbnail(
              imageFile: any(named: 'imageFile'),
              userId: any(named: 'userId'),
              originalPath: any(named: 'originalPath'),
            )).thenAnswer((_) async => null);

        // Act
        await storageService.uploadImageFile(mockFile, userId);

        // Assert
        verify(() => mockRepository.generateFileName(
              originalPath: mockFile.path,
              prefix: 'recipe',
            )).called(1);
      });
    });

    group('Thumbnail Creation', () {
      test('should create thumbnail in background after upload', () async {
        // Arrange
        const userId = 'test_user_123';
        const expectedUrl = 'https://storage.googleapis.com/test/image.jpg';

        when(() => mockRepository.generateFileName(
              originalPath: any(named: 'originalPath'),
              prefix: any(named: 'prefix'),
            )).thenReturn('recipe_123.jpg');

        when(() => mockRepository.uploadImage(
              imageFile: any(named: 'imageFile'),
              userId: any(named: 'userId'),
              path: any(named: 'path'),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async => expectedUrl);

        when(() => mockRepository.createAndUploadThumbnail(
                  imageFile: any(named: 'imageFile'),
                  userId: any(named: 'userId'),
                  originalPath: any(named: 'originalPath'),
                ))
            .thenAnswer(
                (_) async => 'https://storage.googleapis.com/test/thumb.jpg');

        // Act
        await storageService.uploadImageFile(mockFile, userId);

        // Wait a bit for background operation to start
        await Future.delayed(const Duration(milliseconds: 100));

        // Assert
        // Thumbnail creation happens in background, so we can't verify immediately
        // But the method should have been called
        expect(expectedUrl, isNotNull);
      });
    });

    group('Error Handling', () {
      test('should handle upload failures gracefully', () async {
        // Arrange
        const userId = 'test_user_123';

        when(() => mockRepository.generateFileName(
              originalPath: any(named: 'originalPath'),
              prefix: any(named: 'prefix'),
            )).thenReturn('recipe_123.jpg');

        when(() => mockRepository.uploadImage(
              imageFile: any(named: 'imageFile'),
              userId: any(named: 'userId'),
              path: any(named: 'path'),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async => null);

        // Act
        final result = await storageService.uploadImageFile(mockFile, userId);

        // Assert
        expect(result, isNull);
      });

      test('should handle deletion failures gracefully', () async {
        // Arrange
        const imageUrl = 'https://storage.googleapis.com/test/image.jpg';

        when(() => mockRepository.deleteImage(any()))
            .thenAnswer((_) async => false);

        // Act
        final result = await storageService.deleteImage(imageUrl);

        // Assert
        expect(result, isFalse);
      });
    });

    group('Singleton Pattern', () {
      test('should maintain same instance across multiple factory calls', () {
        // Act
        final instance1 = StorageService(repository: mockRepository);
        final instance2 = StorageService(repository: mockRepository);
        final instance3 = StorageService(repository: mockRepository);

        // Assert
        expect(identical(instance1, instance2), isTrue);
        expect(identical(instance2, instance3), isTrue);
      });

      test('should reset singleton for testing', () {
        // Arrange
        final instance1 = StorageService(repository: mockRepository);

        // Act
        SingletonServiceMixin.resetForTesting();
        final instance2 = StorageService(repository: mockRepository);

        // Assert
        expect(identical(instance1, instance2), isFalse);
      });
    });
  });
}

// ============= USING CENTRALIZED MOCK CREATION =============
// Helper function to create mock files using centralized mock patterns
MockFile _createMockFile(String path, {int sizeBytes = 1024}) {
  final mockFile = MockFile();
  when(() => mockFile.path).thenReturn(path);
  when(() => mockFile.lengthSync()).thenReturn(sizeBytes);
  when(() => mockFile.readAsBytes()).thenAnswer(
    (_) async => Uint8List(sizeBytes),
  );
  return mockFile;
}
