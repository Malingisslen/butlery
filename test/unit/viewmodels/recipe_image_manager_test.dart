// test/unit/viewmodels/recipe_image_manager_test.dart

import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_image_manager.dart';
import 'package:butlery/services/storage_service.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// ULTRATHINK CONVERSION COMPLETE: Local mock classes removed - using centralized mocks

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('RecipeImageManager - Ultrathink Enhanced Tests', () {
    late RecipeImageManager imageManager;
    late StorageService
        mockStorageService; // Using interface type for centralized mock

    // Test data
    const testRecipeId = 'recipe_123';
    const testImageUrl1 = 'https://example.com/image1.jpg';
    const testImageUrl2 = 'https://example.com/image2.png';
    const testImageUrl3 = 'https://firebase.com/storage/image3.jpg';
    const testImageUrl4 = 'https://storage.googleapis.com/image4.png';
    const testImageUrl5 = 'https://example.com/image5.webp';
    final testImageUrls = [testImageUrl1, testImageUrl2, testImageUrl3];

    setUpAll(() async {
      await TestServiceLocator.initialize();

      // Register fallback values for mocktail
      registerFallbackValue(MockFactory.createXFile('/test/path'));
      registerFallbackValue(File('/test/path'));
    });

    setUp(() {
      // Create mocks using centralized versions
      mockStorageService = MockFactory.createStorageService();

      // Configure default storage service behavior - success scenarios
      when(() => mockStorageService.uploadRecipeImage(
                any(),
                any(),
                onProgress: any(named: 'onProgress'),
              ))
          .thenAnswer(
              (_) async => 'https://storage.firebase.com/uploaded_image.jpg');

      when(() => mockStorageService.deleteRecipeImage(any()))
          .thenAnswer((_) async {});

      imageManager = RecipeImageManager(
        storageService: mockStorageService,
        imagePickerService: MockFactory.createImagePickerService(),
      );
    });

    tearDown(() async {
      // Only dispose if not already disposed (to avoid FlutterError in disposal tests)
      try {
        imageManager.dispose();
      } catch (e) {
        // Already disposed, ignore FlutterError
      }
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await TestServiceLocator.reset();
    });

    group('Initialization and Basic Properties', () {
      test('should initialize with empty image list and correct defaults', () {
        // Assert
        expect(imageManager.imageUrls, isEmpty);
        expect(imageManager.isUploadingImage, isFalse);
        expect(imageManager.imageUploadError, isNull);
        expect(imageManager.hasImageUploadError, isFalse);
        expect(imageManager.canAddMoreImages, isTrue);
        expect(imageManager.remainingImageSlots, equals(5)); // maxImages = 5
      });

      test('should handle custom storage service injection', () {
        // Arrange
        final customStorageService = MockFactory.createStorageService();

        // Act
        final customManager =
            RecipeImageManager(storageService: customStorageService);

        // Assert
        expect(customManager, isNotNull);
        expect(customManager.imageUrls, isEmpty);

        // Cleanup
        customManager.dispose();
      });
    });

    group('Image URL List Management', () {
      test('should set image URLs correctly', () {
        // Arrange
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act
        imageManager.setImageUrls(testImageUrls);

        // Assert
        expect(imageManager.imageUrls, equals(testImageUrls));
        expect(imageManager.imageUrls.length, equals(3));
        expect(imageManager.canAddMoreImages, isTrue);
        expect(imageManager.remainingImageSlots, equals(2));
        expect(notificationCount, equals(1)); // Should notify listeners
      });

      test('should create defensive copy of image URLs', () {
        // Arrange
        final originalList = List<String>.from(testImageUrls);

        // Act
        imageManager.setImageUrls(originalList);
        originalList.add('modified_url');

        // Assert - imageManager should not be affected by external modification
        expect(imageManager.imageUrls, equals(testImageUrls));
        expect(imageManager.imageUrls.length, equals(3));
      });

      test('should add single image URL correctly', () {
        // Arrange
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act
        imageManager.addUploadedImageUrl(testImageUrl1);

        // Assert
        expect(imageManager.imageUrls, contains(testImageUrl1));
        expect(imageManager.imageUrls.length, equals(1));
        expect(imageManager.remainingImageSlots, equals(4));
        expect(notificationCount, equals(1));
      });

      test('should not add duplicate image URLs', () {
        // Arrange
        imageManager.addUploadedImageUrl(testImageUrl1);
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act - try to add same URL again
        imageManager.addUploadedImageUrl(testImageUrl1);

        // Assert
        expect(imageManager.imageUrls.length, equals(1));
        expect(notificationCount, equals(0)); // Should not notify for duplicate
      });

      test('should not add more than max images', () {
        // Arrange - add max images (5)
        imageManager.setImageUrls([
          testImageUrl1,
          testImageUrl2,
          testImageUrl3,
          testImageUrl4,
          testImageUrl5
        ]);
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act - try to add 6th image
        imageManager.addUploadedImageUrl('https://example.com/image6.jpg');

        // Assert
        expect(imageManager.imageUrls.length, equals(5));
        expect(imageManager.canAddMoreImages, isFalse);
        expect(imageManager.remainingImageSlots, equals(0));
        expect(notificationCount, equals(0)); // Should not notify when at max
      });

      test('should remove image URL correctly', () {
        // Arrange
        imageManager.setImageUrls(testImageUrls);
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act
        imageManager.removeImageUrl(testImageUrl2);

        // Assert
        expect(imageManager.imageUrls, isNot(contains(testImageUrl2)));
        expect(imageManager.imageUrls.length, equals(2));
        expect(imageManager.canAddMoreImages, isTrue);
        expect(imageManager.remainingImageSlots, equals(3));
        expect(notificationCount, equals(1));
      });

      test('should handle removing non-existent image URL', () {
        // Arrange
        imageManager.setImageUrls(testImageUrls);
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act
        imageManager.removeImageUrl('https://nonexistent.com/image.jpg');

        // Assert
        expect(imageManager.imageUrls.length, equals(3)); // No change
        expect(notificationCount,
            equals(1)); // List.remove still triggers notification
      });

      test('should move image to first position correctly', () {
        // Arrange
        imageManager.setImageUrls(testImageUrls);
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act - move second image to first
        imageManager.moveImageToFirst(testImageUrl2);

        // Assert
        expect(imageManager.imageUrls.first, equals(testImageUrl2));
        expect(imageManager.imageUrls.length, equals(3));
        expect(notificationCount, equals(1));
      });

      test('should handle moving non-existent image to first', () {
        // Arrange
        imageManager.setImageUrls(testImageUrls);
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act
        imageManager.moveImageToFirst('https://nonexistent.com/image.jpg');

        // Assert
        expect(imageManager.imageUrls, equals(testImageUrls)); // No change
        expect(
            notificationCount, equals(0)); // Should not notify for non-existent
      });

      test('should reorder images correctly', () {
        // Arrange
        imageManager.setImageUrls(testImageUrls);
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act - move from index 0 to index 2
        imageManager.reorderImages(0, 2);

        // Assert
        expect(imageManager.imageUrls[2],
            equals(testImageUrl1)); // First moved to last
        expect(imageManager.imageUrls.length, equals(3));
        expect(notificationCount, equals(1));
      });

      test('should handle invalid reorder indices', () {
        // Arrange
        imageManager.setImageUrls(testImageUrls);
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act - invalid indices
        imageManager.reorderImages(-1, 2);
        imageManager.reorderImages(0, 10);
        imageManager.reorderImages(10, 0);

        // Assert
        expect(imageManager.imageUrls, equals(testImageUrls)); // No change
        expect(notificationCount,
            equals(0)); // Should not notify for invalid indices
      });
    });

    group('Image Upload from URL', () {
      test('should add image from URL successfully', () async {
        // Arrange
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act
        await imageManager.addImageFromUrl(testImageUrl1);

        // Assert
        expect(imageManager.imageUrls, contains(testImageUrl1));
        expect(imageManager.imageUploadError, isNull);
        expect(notificationCount, greaterThan(0)); // Should notify for changes
      });

      test('should trim whitespace from URL', () async {
        // Arrange
        const urlWithSpaces = '  $testImageUrl1  ';

        // Act
        await imageManager.addImageFromUrl(urlWithSpaces);

        // Assert
        expect(imageManager.imageUrls, contains(testImageUrl1));
        expect(imageManager.imageUrls, isNot(contains(urlWithSpaces)));
      });

      test('should reject empty URL', () async {
        // Act
        await imageManager.addImageFromUrl('');

        // Assert
        expect(imageManager.imageUrls, isEmpty);
        expect(imageManager.imageUploadError,
            equals('Bildlänk får inte vara tom'));
        expect(imageManager.hasImageUploadError, isTrue);
      });

      test('should reject whitespace-only URL', () async {
        // Act
        await imageManager.addImageFromUrl('   ');

        // Assert
        expect(imageManager.imageUrls, isEmpty);
        expect(imageManager.imageUploadError,
            equals('Bildlänk får inte vara tom'));
      });

      test('should reject invalid URL format', () async {
        // Act
        await imageManager.addImageFromUrl('invalid-url');

        // Assert
        expect(imageManager.imageUrls, isEmpty);
        expect(imageManager.imageUploadError, equals('Ogiltig bildlänk'));
      });

      test('should reject duplicate URL', () async {
        // Arrange
        await imageManager.addImageFromUrl(testImageUrl1);

        // Act - try to add same URL again
        await imageManager.addImageFromUrl(testImageUrl1);

        // Assert
        expect(imageManager.imageUrls.length, equals(1));
        expect(imageManager.imageUploadError, equals('Bilden finns redan'));
      });

      test('should reject URL when at max images', () async {
        // Arrange - add max images (5)
        imageManager.setImageUrls([
          testImageUrl1,
          testImageUrl2,
          testImageUrl3,
          testImageUrl4,
          testImageUrl5
        ]);

        // Act - try to add 6th image
        await imageManager.addImageFromUrl('https://example.com/image6.jpg');

        // Assert
        expect(imageManager.imageUrls.length, equals(5));
        expect(imageManager.imageUploadError,
            equals('Du kan bara ha maximalt 5 bilder'));
      });

      test('should handle URL parsing exceptions gracefully', () async {
        // Arrange - create a URL that might cause parsing issues
        const problematicUrl = 'https://example.com/image with spaces.jpg';

        // Act
        await imageManager.addImageFromUrl(problematicUrl);

        // Assert - should either succeed or fail gracefully
        expect(
            imageManager.hasImageUploadError ||
                imageManager.imageUrls.isNotEmpty,
            isTrue);
      });
    });

    group('File Upload Operations', () {
      test('should upload single image file successfully', () async {
        // Arrange
        final testFile = MockFactory.createXFile('/test/image.jpg');
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act
        await imageManager.uploadImageFromFile(testFile, testRecipeId);

        // Assert
        expect(imageManager.imageUrls.length, equals(1));
        expect(imageManager.imageUrls.first,
            equals('https://storage.firebase.com/uploaded_image.jpg'));
        expect(imageManager.isUploadingImage, isFalse);
        expect(imageManager.imageUploadError, isNull);
        expect(notificationCount, greaterThan(0));

        verify(() => mockStorageService.uploadRecipeImage(
              any(),
              testRecipeId,
              onProgress: any(named: 'onProgress'),
            )).called(1);
      });

      test('should handle upload state correctly during file upload', () async {
        // Arrange
        final testFile = MockFactory.createXFile('/test/image.jpg');
        final completer = Completer<String?>();
        when(() => mockStorageService.uploadRecipeImage(
              any(),
              any(),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) => completer.future);

        final uploadingStates = <bool>[];
        imageManager.addListener(
            () => uploadingStates.add(imageManager.isUploadingImage));

        // Act
        final uploadFuture =
            imageManager.uploadImageFromFile(testFile, testRecipeId);

        // Assert - should be uploading
        expect(imageManager.isUploadingImage, isTrue);

        // Complete the upload
        completer.complete('https://uploaded.jpg');
        await uploadFuture;

        // Assert - should not be uploading anymore
        expect(imageManager.isUploadingImage, isFalse);
        expect(uploadingStates, contains(true));
        expect(uploadingStates, contains(false));
      });

      test('should reject file upload when at max images', () async {
        // Arrange
        imageManager.setImageUrls([
          testImageUrl1,
          testImageUrl2,
          testImageUrl3,
          testImageUrl4,
          testImageUrl5
        ]);
        final testFile = MockFactory.createXFile('/test/image.jpg');

        // Act
        await imageManager.uploadImageFromFile(testFile, testRecipeId);

        // Assert
        expect(imageManager.imageUrls.length, equals(5)); // No change
        expect(imageManager.imageUploadError,
            equals('Du kan bara ha maximalt 5 bilder'));
        verifyNever(() => mockStorageService.uploadRecipeImage(
              any(),
              any(),
              onProgress: any(named: 'onProgress'),
            ));
      });

      test('should handle upload failure gracefully', () async {
        // Arrange
        final testFile = MockFactory.createXFile('/test/image.jpg');
        when(() => mockStorageService.uploadRecipeImage(
              any(),
              any(),
              onProgress: any(named: 'onProgress'),
            )).thenThrow(Exception('Storage error'));

        // Act
        await imageManager.uploadImageFromFile(testFile, testRecipeId);

        // Assert
        expect(imageManager.imageUrls, isEmpty);
        expect(imageManager.isUploadingImage, isFalse);
        expect(imageManager.imageUploadError,
            contains('Kunde inte ladda upp bild'));
      });

      test('should handle null upload result', () async {
        // Arrange
        final testFile = MockFactory.createXFile('/test/image.jpg');
        when(() => mockStorageService.uploadRecipeImage(
              any(),
              any(),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async => null);

        // Act
        await imageManager.uploadImageFromFile(testFile, testRecipeId);

        // Assert
        expect(imageManager.imageUrls, isEmpty);
        expect(
            imageManager.imageUploadError, equals('Kunde inte ladda upp bild'));
      });

      test('should handle empty upload result', () async {
        // Arrange
        final testFile = MockFactory.createXFile('/test/image.jpg');
        when(() => mockStorageService.uploadRecipeImage(
              any(),
              any(),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async => '');

        // Act
        await imageManager.uploadImageFromFile(testFile, testRecipeId);

        // Assert
        expect(imageManager.imageUrls, isEmpty);
        expect(
            imageManager.imageUploadError, equals('Kunde inte ladda upp bild'));
      });
    });

    group('Multiple File Upload Operations', () {
      test('should upload multiple images successfully', () async {
        // Arrange
        final testFiles = [
          MockFactory.createXFile('/test/image1.jpg'),
          MockFactory.createXFile('/test/image2.png'),
          MockFactory.createXFile('/test/image3.webp'),
        ];

        // Configure mock to return different URLs
        var callCount = 0;
        when(() => mockStorageService.uploadRecipeImage(
                  any(),
                  any(),
                  onProgress: any(named: 'onProgress'),
                ))
            .thenAnswer((_) async =>
                'https://storage.firebase.com/uploaded_image${++callCount}.jpg');

        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act
        await imageManager.uploadMultipleImages(testFiles, testRecipeId);

        // Assert
        expect(imageManager.imageUrls.length, equals(3));
        expect(imageManager.isUploadingImage, isFalse);
        expect(imageManager.imageUploadError, isNull);
        expect(notificationCount, greaterThan(0));

        verify(() => mockStorageService.uploadRecipeImage(
              any(),
              testRecipeId,
              onProgress: any(named: 'onProgress'),
            )).called(3);
      });

      test('should handle empty file list', () async {
        // Act
        await imageManager.uploadMultipleImages([], testRecipeId);

        // Assert
        expect(imageManager.imageUrls, isEmpty);
        verifyNever(() => mockStorageService.uploadRecipeImage(
              any(),
              any(),
              onProgress: any(named: 'onProgress'),
            ));
      });

      test('should limit uploads when exceeding available slots', () async {
        // Arrange - already have 3 images, only 2 slots left
        imageManager
            .setImageUrls([testImageUrl1, testImageUrl2, testImageUrl3]);
        final testFiles = [
          MockFactory.createXFile('/test/image1.jpg'),
          MockFactory.createXFile('/test/image2.png'),
          MockFactory.createXFile('/test/image3.webp'),
          MockFactory.createXFile('/test/image4.jpg'), // Should be excluded
        ];

        var callCount = 0;
        when(() => mockStorageService.uploadRecipeImage(
              any(),
              any(),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async => 'https://uploaded${++callCount}.jpg');

        // Act
        await imageManager.uploadMultipleImages(testFiles, testRecipeId);

        // Assert
        expect(imageManager.imageUrls.length,
            equals(5)); // 3 original + 2 uploaded
        expect(imageManager.imageUploadError,
            contains('Bara 2 av 4 bilder kunde laddas upp'));

        verify(() => mockStorageService.uploadRecipeImage(
              any(),
              testRecipeId,
              onProgress: any(named: 'onProgress'),
            )).called(2); // Only 2 uploads, not 4
      });

      test('should handle partial upload failures', () async {
        // Arrange
        final testFiles = [
          MockFactory.createXFile('/test/image1.jpg'),
          MockFactory.createXFile('/test/image2.png'),
          MockFactory.createXFile('/test/image3.webp'),
        ];

        // Configure mock to succeed for some, fail for others
        var callCount = 0;
        when(() => mockStorageService.uploadRecipeImage(
              any(),
              any(),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) async {
          callCount++;
          if (callCount == 2) return null; // Second upload fails
          return 'https://uploaded$callCount.jpg';
        });

        // Act
        await imageManager.uploadMultipleImages(testFiles, testRecipeId);

        // Assert
        expect(imageManager.imageUrls.length,
            equals(2)); // Only successful uploads
        expect(imageManager.isUploadingImage, isFalse);
      });

      test('should handle complete upload failure', () async {
        // Arrange
        final testFiles = [
          MockFactory.createXFile('/test/image1.jpg'),
          MockFactory.createXFile('/test/image2.png'),
        ];

        when(() => mockStorageService.uploadRecipeImage(
              any(),
              any(),
              onProgress: any(named: 'onProgress'),
            )).thenThrow(Exception('Storage error'));

        // Act
        await imageManager.uploadMultipleImages(testFiles, testRecipeId);

        // Assert
        expect(imageManager.imageUrls, isEmpty);
        expect(imageManager.isUploadingImage, isFalse);
        expect(imageManager.imageUploadError,
            contains('Kunde inte ladda upp bilder'));
      });
    });

    group('Image Cleanup and Storage Management', () {
      test('should remove image and cleanup storage for uploaded images',
          () async {
        // Arrange
        const firebaseImageUrl = 'https://firebase.com/storage/image.jpg';
        imageManager.addUploadedImageUrl(firebaseImageUrl);

        // Act
        await imageManager.removeImageAndCleanup(firebaseImageUrl);

        // Assert
        expect(imageManager.imageUrls, isNot(contains(firebaseImageUrl)));
        verify(() => mockStorageService.deleteRecipeImage(firebaseImageUrl))
            .called(1);
      });

      test('should remove image without cleanup for external URLs', () async {
        // Arrange
        const externalUrl = 'https://example.com/image.jpg';
        imageManager.addUploadedImageUrl(externalUrl);

        // Act
        await imageManager.removeImageAndCleanup(externalUrl);

        // Assert
        expect(imageManager.imageUrls, isNot(contains(externalUrl)));
        verifyNever(() => mockStorageService.deleteRecipeImage(externalUrl));
      });

      test('should cleanup google storage images', () async {
        // Arrange
        const storageUrl = 'https://storage.googleapis.com/image.jpg';
        imageManager.addUploadedImageUrl(storageUrl);

        // Act
        await imageManager.removeImageAndCleanup(storageUrl);

        // Assert
        expect(imageManager.imageUrls, isNot(contains(storageUrl)));
        verify(() => mockStorageService.deleteRecipeImage(storageUrl))
            .called(1);
      });

      test('should handle cleanup failure gracefully', () async {
        // Arrange
        const firebaseImageUrl = 'https://firebase.com/storage/image.jpg';
        imageManager.addUploadedImageUrl(firebaseImageUrl);
        when(() => mockStorageService.deleteRecipeImage(any()))
            .thenThrow(Exception('Delete error'));

        // Act
        await imageManager.removeImageAndCleanup(firebaseImageUrl);

        // Assert - image should still be removed from list even if cleanup fails
        expect(imageManager.imageUrls, isNot(contains(firebaseImageUrl)));
      });

      test('should clear all images and cleanup storage', () async {
        // Arrange
        final mixedUrls = [
          'https://firebase.com/storage/image1.jpg',
          'https://example.com/image2.jpg', // External - no cleanup
          'https://storage.googleapis.com/image3.jpg',
        ];
        imageManager.setImageUrls(mixedUrls);

        // Act
        await imageManager.clearAllImages();

        // Assert
        expect(imageManager.imageUrls, isEmpty);

        // Should only cleanup uploaded images (not external URLs)
        verify(() => mockStorageService.deleteRecipeImage(mixedUrls[0]))
            .called(1);
        verifyNever(() => mockStorageService.deleteRecipeImage(mixedUrls[1]));
        verify(() => mockStorageService.deleteRecipeImage(mixedUrls[2]))
            .called(1);
      });

      test('should handle cleanup failures during clear all', () async {
        // Arrange
        final uploadedUrls = [
          'https://firebase.com/storage/image1.jpg',
          'https://firebase.com/storage/image2.jpg',
        ];
        imageManager.setImageUrls(uploadedUrls);

        // First cleanup succeeds, second fails
        when(() => mockStorageService.deleteRecipeImage(uploadedUrls[0]))
            .thenAnswer((_) async {});
        when(() => mockStorageService.deleteRecipeImage(uploadedUrls[1]))
            .thenThrow(Exception('Delete error'));

        // Act - should not throw
        await imageManager.clearAllImages();

        // Assert
        expect(imageManager.imageUrls, isEmpty);
        verify(() => mockStorageService.deleteRecipeImage(uploadedUrls[0]))
            .called(1);
        verify(() => mockStorageService.deleteRecipeImage(uploadedUrls[1]))
            .called(1);
      });
    });

    group('Image Validation', () {
      test('should validate correct image formats', () {
        // Arrange & Act
        final validFormats = [
          'https://example.com/image.jpg',
          'https://example.com/image.jpeg',
          'https://example.com/image.png',
          'https://example.com/image.gif',
          'https://example.com/image.webp',
          'https://example.com/IMAGE.JPG', // Case insensitive
          'https://example.com/path/with/image.PNG',
        ];

        // Assert
        for (final url in validFormats) {
          expect(imageManager.isValidImageFormat(url), isTrue,
              reason: 'Should accept $url as valid image format');
        }
      });

      test('should reject invalid image formats', () {
        // Arrange & Act
        final invalidFormats = [
          'https://example.com/document.pdf',
          'https://example.com/video.mp4',
          'https://example.com/audio.mp3',
          'https://example.com/noextension',
          '',
          'not-a-url',
        ];

        // Assert
        for (final url in invalidFormats) {
          expect(imageManager.isValidImageFormat(url), isFalse,
              reason: 'Should reject $url as invalid image format');
        }
      });

      test('should validate image size correctly', () async {
        // Arrange
        final validSizeFile =
            MockFactory.createXFile('/test/small.jpg', length: 1024 * 1024); // 1MB
        final largeSizeFile =
            MockFactory.createXFile('/test/large.jpg', length: 10 * 1024 * 1024); // 10MB

        // Act & Assert
        expect(await imageManager.isValidImageSize(validSizeFile), isTrue);
        expect(await imageManager.isValidImageSize(largeSizeFile), isFalse);
      });

      test('should handle file size validation errors gracefully', () async {
        // Arrange - create a mock file that throws on length()
        final mockFile = MockXFile();
        when(() => mockFile.length()).thenThrow(Exception('File access error'));

        // Act & Assert - should return true when validation fails
        expect(await imageManager.isValidImageSize(mockFile), isTrue);
      });
    });

    group('Error State Management', () {
      test('should clear error when adding image URL successfully', () async {
        // Arrange - set an error first
        await imageManager.addImageFromUrl('invalid-url');
        expect(imageManager.hasImageUploadError, isTrue);

        // Act
        await imageManager.addImageFromUrl(testImageUrl1);

        // Assert
        expect(imageManager.imageUploadError, isNull);
        expect(imageManager.hasImageUploadError, isFalse);
      });

      test('should clear error when uploading file successfully', () async {
        // Arrange - set an error first by attempting to upload when at max capacity
        imageManager.setImageUrls([
          testImageUrl1,
          testImageUrl2,
          testImageUrl3,
          testImageUrl4,
          testImageUrl5
        ]);
        await imageManager.uploadImageFromFile(
            MockFactory.createXFile('/test/image.jpg'), testRecipeId);
        expect(imageManager.hasImageUploadError, isTrue);

        // Remove one image to make space
        imageManager.removeImageUrl(testImageUrl1);

        // Act
        await imageManager.uploadImageFromFile(
            MockFactory.createXFile('/test/image.jpg'), testRecipeId);

        // Assert
        expect(imageManager.imageUploadError, isNull);
        expect(imageManager.hasImageUploadError, isFalse);
      });

      test('should maintain error state through listener notifications',
          () async {
        // Arrange
        final errorStates = <String?>[];
        imageManager
            .addListener(() => errorStates.add(imageManager.imageUploadError));

        // Act - trigger error
        await imageManager.addImageFromUrl('invalid-url');

        // Act - clear error
        await imageManager.addImageFromUrl(testImageUrl1);

        // Assert
        expect(errorStates, contains('Ogiltig bildlänk'));
        expect(errorStates, contains(null));
      });
    });

    group('State Change Notifications', () {
      test('should notify listeners when image URLs change', () {
        // Arrange
        var notificationCount = 0;
        imageManager.addListener(() => notificationCount++);

        // Act - various operations that should trigger notifications
        imageManager.setImageUrls([testImageUrl1]);
        imageManager.addUploadedImageUrl(testImageUrl2);
        imageManager.removeImageUrl(testImageUrl1);
        imageManager.moveImageToFirst(testImageUrl2);
        imageManager.reorderImages(0, 0); // No change, but still notifies

        // Assert
        expect(notificationCount,
            equals(4)); // reorderImages doesn't change anything
      });

      test('should notify listeners when upload state changes', () async {
        // Arrange
        final uploadingStates = <bool>[];
        imageManager.addListener(
            () => uploadingStates.add(imageManager.isUploadingImage));

        final completer = Completer<String?>();
        when(() => mockStorageService.uploadRecipeImage(
              any(),
              any(),
              onProgress: any(named: 'onProgress'),
            )).thenAnswer((_) => completer.future);

        // Act
        final uploadFuture = imageManager.uploadImageFromFile(
            MockFactory.createXFile('/test/image.jpg'), testRecipeId);

        // Complete upload
        completer.complete('https://uploaded.jpg');
        await uploadFuture;

        // Assert
        expect(uploadingStates, contains(true));
        expect(uploadingStates, contains(false));
      });

      test('should notify listeners when error state changes', () async {
        // Arrange
        final hasErrorStates = <bool>[];
        imageManager.addListener(
            () => hasErrorStates.add(imageManager.hasImageUploadError));

        // Act
        await imageManager.addImageFromUrl('invalid-url'); // Set error
        await imageManager.addImageFromUrl(testImageUrl1); // Clear error

        // Assert
        expect(hasErrorStates, contains(true));
        expect(hasErrorStates, contains(false));
      });
    });

    group('Edge Cases and Error Handling', () {
      test('should handle extremely long image URLs', () async {
        // Arrange
        final longUrl = 'https://example.com/${'x' * 2000}.jpg';

        // Act & Assert - should not crash
        await imageManager.addImageFromUrl(longUrl);
        expect(
            imageManager.imageUrls.isNotEmpty ||
                imageManager.hasImageUploadError,
            isTrue);
      });

      test('should handle special characters in URLs', () async {
        // Arrange
        final specialUrls = [
          'https://example.com/image with spaces.jpg',
          'https://example.com/imáge_with_áccents.png',
          'https://example.com/image-with-dashes.gif',
          'https://example.com/image_with_underscores.webp',
        ];

        for (final url in specialUrls) {
          // Act & Assert - should handle gracefully
          await imageManager.addImageFromUrl(url);
          expect(
              imageManager.imageUrls.isNotEmpty ||
                  imageManager.hasImageUploadError,
              isTrue);

          // Reset for next test
          imageManager.setImageUrls([]);
        }
      });

      test('should handle unicode characters in URLs', () async {
        // Arrange
        final unicodeUrls = [
          'https://example.com/图片.jpg',
          'https://example.com/imagem_🖼️.png',
          'https://example.com/画像_テスト.gif',
        ];

        for (final url in unicodeUrls) {
          // Act & Assert - should handle gracefully
          await imageManager.addImageFromUrl(url);
          expect(
              imageManager.imageUrls.isNotEmpty ||
                  imageManager.hasImageUploadError,
              isTrue);

          // Reset for next test
          imageManager.setImageUrls([]);
        }
      });

      test('should handle concurrent upload operations', () async {
        // Arrange
        final testFiles = [
          MockFactory.createXFile('/test/image1.jpg'),
          MockFactory.createXFile('/test/image2.jpg'),
          MockFactory.createXFile('/test/image3.jpg'),
        ];

        // Configure mock to return different URLs for each call
        var callCount = 0;
        when(() => mockStorageService.uploadRecipeImage(
                  any(),
                  any(),
                  onProgress: any(named: 'onProgress'),
                ))
            .thenAnswer((_) async =>
                'https://storage.firebase.com/uploaded_image${++callCount}.jpg');

        // Act - start multiple uploads concurrently
        final futures = testFiles
            .map((file) => imageManager.uploadImageFromFile(file, testRecipeId))
            .toList();

        await Future.wait(futures);

        // Assert - all should complete without issues
        expect(imageManager.imageUrls.length, equals(3));
        expect(imageManager.isUploadingImage, isFalse);
      });

      test('should maintain state consistency across operations', () async {
        // Arrange & Act - perform various operations
        imageManager.setImageUrls([testImageUrl1, testImageUrl2]);
        final initialCount = imageManager.imageUrls.length;

        imageManager.addUploadedImageUrl(testImageUrl3);
        imageManager.removeImageUrl(testImageUrl1);
        imageManager.moveImageToFirst(testImageUrl3);

        // Assert - state should be consistent
        expect(imageManager.imageUrls.length,
            equals(initialCount)); // Added 1, removed 1
        expect(imageManager.imageUrls.first, equals(testImageUrl3));
        expect(imageManager.canAddMoreImages, isTrue);
        expect(imageManager.remainingImageSlots, equals(3));
      });

      test('should handle disposal correctly', () {
        // Arrange
        var notificationCount = 0;
        void listener() => notificationCount++;
        imageManager.addListener(listener);

        // Act
        imageManager.dispose();

        // Additional operations after disposal should throw FlutterError (correct Flutter behavior)
        expect(() => imageManager.setImageUrls([testImageUrl1]),
            throwsA(isA<FlutterError>()));
        expect(() => imageManager.addUploadedImageUrl(testImageUrl2),
            throwsA(isA<FlutterError>()));
      });

      test('should handle multiple dispose calls', () {
        // Act - first dispose should work normally
        imageManager.dispose();

        // Additional dispose calls should throw FlutterError (correct Flutter behavior)
        expect(() => imageManager.dispose(), throwsA(isA<FlutterError>()));
      });
    });

    group('Integration Scenarios', () {
      test('should handle complete image management workflow', () async {
        // Act & Assert - Complete workflow

        // 1. Start with empty state
        expect(imageManager.imageUrls, isEmpty);
        expect(imageManager.canAddMoreImages, isTrue);

        // 2. Add images from URLs
        await imageManager.addImageFromUrl(testImageUrl1);
        await imageManager.addImageFromUrl(testImageUrl2);
        expect(imageManager.imageUrls.length, equals(2));

        // 3. Upload file
        await imageManager.uploadImageFromFile(
            MockFactory.createXFile('/test/image.jpg'), testRecipeId);
        expect(imageManager.imageUrls.length, equals(3));

        // 4. Reorder images
        imageManager.moveImageToFirst(testImageUrl2);
        expect(imageManager.imageUrls.first, equals(testImageUrl2));

        // 5. Remove and cleanup
        await imageManager.removeImageAndCleanup(imageManager.imageUrls.first);
        expect(imageManager.imageUrls.length, equals(2));

        // 6. Clear all
        await imageManager.clearAllImages();
        expect(imageManager.imageUrls, isEmpty);
      });

      test('should handle error recovery workflow', () async {
        // 1. Trigger error
        await imageManager.addImageFromUrl('invalid-url');
        expect(imageManager.hasImageUploadError, isTrue);

        // 2. Recover from error
        await imageManager.addImageFromUrl(testImageUrl1);
        expect(imageManager.hasImageUploadError, isFalse);
        expect(imageManager.imageUrls.length, equals(1));

        // 3. Trigger upload error
        imageManager.setImageUrls([
          testImageUrl1,
          testImageUrl2,
          testImageUrl3,
          testImageUrl4,
          testImageUrl5
        ]);
        await imageManager.uploadImageFromFile(
            MockFactory.createXFile('/test/image.jpg'), testRecipeId);
        expect(imageManager.hasImageUploadError, isTrue);

        // 4. Make space and retry
        imageManager.removeImageUrl(testImageUrl1);
        await imageManager.uploadImageFromFile(
            MockFactory.createXFile('/test/image.jpg'), testRecipeId);
        expect(imageManager.hasImageUploadError, isFalse);
      });

      test('should handle maximum capacity scenarios', () async {
        // 1. Fill to capacity
        final maxUrls = [
          testImageUrl1,
          testImageUrl2,
          testImageUrl3,
          testImageUrl4,
          testImageUrl5
        ];
        imageManager.setImageUrls(maxUrls);

        expect(imageManager.canAddMoreImages, isFalse);
        expect(imageManager.remainingImageSlots, equals(0));

        // 2. Try to add more (should fail)
        await imageManager.addImageFromUrl('https://example.com/extra.jpg');
        expect(imageManager.imageUrls.length, equals(5));
        expect(imageManager.hasImageUploadError, isTrue);

        // 3. Remove some and add again
        imageManager.removeImageUrl(testImageUrl1);
        imageManager.removeImageUrl(testImageUrl2);

        expect(imageManager.canAddMoreImages, isTrue);
        expect(imageManager.remainingImageSlots, equals(2));

        // 4. Add multiple files (should limit to available slots)
        final multipleFiles = [
          MockFactory.createXFile('/test/image1.jpg'),
          MockFactory.createXFile('/test/image2.jpg'),
          MockFactory.createXFile('/test/image3.jpg'), // Should be excluded
        ];

        // Configure mock for multiple uploads with unique URLs
        var multipleCallCount = 0;
        when(() => mockStorageService.uploadRecipeImage(
                  any(),
                  any(),
                  onProgress: any(named: 'onProgress'),
                ))
            .thenAnswer((_) async =>
                'https://storage.firebase.com/multiple_${++multipleCallCount}.jpg');

        await imageManager.uploadMultipleImages(multipleFiles, testRecipeId);
        expect(imageManager.imageUrls.length, equals(5)); // Back to max
        expect(imageManager.imageUploadError, contains('Bara 2 av 3 bilder'));
      });
    });
  });
}

