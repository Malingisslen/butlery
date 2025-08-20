import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

// Production imports
import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/image_picker_provider.dart';

// Test infrastructure
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Mocks
class MockImagePickerProvider extends Mock implements ImagePickerProvider {}
class MockPermissionProvider extends Mock implements PermissionProvider {}
class MockImageValidator extends Mock implements ImageValidator {}
class MockXFile extends Mock implements XFile {}
class MockFile extends Mock implements File {}

// Fake for Permission
class FakePermission extends Fake implements Permission {}

void main() {
  setUpAll(() {
    // Register fallback values for mocktail
    registerFallbackValue(ImageSource.camera);
    registerFallbackValue(FakePermission());
  });
  
  group('ImagePickerService Tests', () {
    late ImagePickerService service;
    late MockImagePickerProvider mockImagePickerProvider;
    late MockPermissionProvider mockPermissionProvider;
    late MockImageValidator mockImageValidator;
    
    setUp(() async {
      await BaseUnitTest.setupUnit();
      await TestServiceLocator.initialize();
      
      mockImagePickerProvider = MockImagePickerProvider();
      mockPermissionProvider = MockPermissionProvider();
      mockImageValidator = MockImageValidator();
      
      service = ImagePickerService(
        imagePickerProvider: mockImagePickerProvider,
        permissionProvider: mockPermissionProvider,
        imageValidator: mockImageValidator,
      );
    });
    
    tearDown(() async {
      await TestServiceLocator.reset();
      BaseUnitTest.resetMocks();
    });
    
    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });
    
    group('pickImage', () {
      test('should successfully pick image from camera with granted permission', () async {
        // Arrange
        final mockXFile = MockXFile();
        final mockFile = MockFile();
        
        when(() => mockPermissionProvider.checkPermission(Permission.camera))
            .thenAnswer((_) async => PermissionStatus.granted);
        
        when(() => mockImagePickerProvider.pickImage(
          source: ImageSource.camera,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 90,
        )).thenAnswer((_) async => mockXFile);
        
        when(() => mockXFile.path).thenReturn('/path/to/image.jpg');
        when(() => mockFile.path).thenReturn('/path/to/image.jpg');
        when(() => mockFile.exists()).thenAnswer((_) async => true);
        when(() => mockFile.length()).thenAnswer((_) async => 1024);
        when(() => mockImageValidator.isValidImageFile(any())).thenReturn(true);
        
        // Act
        final result = await service.pickImage(ImageSource.camera);
        
        // Assert
        expect(result, isNotNull);
        verify(() => mockPermissionProvider.checkPermission(Permission.camera)).called(1);
        verify(() => mockImagePickerProvider.pickImage(
          source: ImageSource.camera,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 90,
        )).called(1);
      });
      
      test('should request camera permission when denied', () async {
        // Arrange
        final mockXFile = MockXFile();
        
        when(() => mockPermissionProvider.checkPermission(Permission.camera))
            .thenAnswer((_) async => PermissionStatus.denied);
        
        when(() => mockPermissionProvider.requestPermission(Permission.camera))
            .thenAnswer((_) async => PermissionStatus.granted);
        
        when(() => mockImagePickerProvider.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => mockXFile);
        
        when(() => mockXFile.path).thenReturn('/path/to/image.jpg');
        when(() => mockImageValidator.isValidImageFile(any())).thenReturn(true);
        
        // Act
        await service.pickImage(ImageSource.camera);
        
        // Assert
        verify(() => mockPermissionProvider.checkPermission(Permission.camera)).called(1);
        verify(() => mockPermissionProvider.requestPermission(Permission.camera)).called(1);
      });
      
      test('should return null when camera permission is denied', () async {
        // Arrange
        when(() => mockPermissionProvider.checkPermission(Permission.camera))
            .thenAnswer((_) async => PermissionStatus.denied);
        
        when(() => mockPermissionProvider.requestPermission(Permission.camera))
            .thenAnswer((_) async => PermissionStatus.permanentlyDenied);
        
        // Act
        final result = await service.pickImage(ImageSource.camera);
        
        // Assert
        expect(result, isNull);
        verify(() => mockPermissionProvider.checkPermission(Permission.camera)).called(1);
        verify(() => mockPermissionProvider.requestPermission(Permission.camera)).called(1);
        verifyNever(() => mockImagePickerProvider.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        ));
      });
      
      test('should return null when user cancels image selection', () async {
        // Arrange
        when(() => mockPermissionProvider.checkPermission(Permission.camera))
            .thenAnswer((_) async => PermissionStatus.granted);
        
        when(() => mockImagePickerProvider.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => null);
        
        // Act
        final result = await service.pickImage(ImageSource.camera);
        
        // Assert
        expect(result, isNull);
      });
      
      test('should handle gallery permission with limited access', () async {
        // Arrange
        final mockXFile = MockXFile();
        
        when(() => mockPermissionProvider.checkPermission(Permission.photos))
            .thenAnswer((_) async => PermissionStatus.limited);
        
        when(() => mockImagePickerProvider.pickImage(
          source: ImageSource.gallery,
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 90,
        )).thenAnswer((_) async => mockXFile);
        
        when(() => mockXFile.path).thenReturn('/path/to/image.jpg');
        when(() => mockImageValidator.isValidImageFile(any())).thenReturn(true);
        
        // Act
        final result = await service.pickImage(ImageSource.gallery);
        
        // Assert
        expect(result, isNotNull);
        verify(() => mockPermissionProvider.checkPermission(Permission.photos)).called(1);
      });
      
      test('should fallback to storage permission when photos permission is permanently denied', () async {
        // Arrange
        final mockXFile = MockXFile();
        
        when(() => mockPermissionProvider.checkPermission(Permission.photos))
            .thenAnswer((_) async => PermissionStatus.permanentlyDenied);
        
        when(() => mockPermissionProvider.checkPermission(Permission.storage))
            .thenAnswer((_) async => PermissionStatus.granted);
        
        when(() => mockImagePickerProvider.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => mockXFile);
        
        when(() => mockXFile.path).thenReturn('/path/to/image.jpg');
        when(() => mockImageValidator.isValidImageFile(any())).thenReturn(true);
        
        // Act
        final result = await service.pickImage(ImageSource.gallery);
        
        // Assert
        expect(result, isNotNull);
        verify(() => mockPermissionProvider.checkPermission(Permission.photos)).called(1);
        verify(() => mockPermissionProvider.checkPermission(Permission.storage)).called(1);
      });
      
      test('should return null when image file validation fails', () async {
        // Arrange
        final mockXFile = MockXFile();
        
        when(() => mockPermissionProvider.checkPermission(any()))
            .thenAnswer((_) async => PermissionStatus.granted);
        
        when(() => mockImagePickerProvider.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => mockXFile);
        
        when(() => mockXFile.path).thenReturn('/path/to/image.jpg');
        when(() => mockImageValidator.isValidImageFile(any())).thenReturn(false);
        
        // Act
        final result = await service.pickImage(ImageSource.camera);
        
        // Assert
        expect(result, isNull);
        verify(() => mockImageValidator.isValidImageFile(any())).called(1);
      });
      
      test('should handle exceptions gracefully', () async {
        // Arrange
        when(() => mockPermissionProvider.checkPermission(any()))
            .thenThrow(Exception('Permission error'));
        
        // Act
        final result = await service.pickImage(ImageSource.camera);
        
        // Assert
        expect(result, isNull);
      });
    });
    
    group('pickMultipleImages', () {
      test('should successfully pick multiple images from gallery', () async {
        // Arrange
        final mockXFile1 = MockXFile();
        final mockXFile2 = MockXFile();
        final mockXFile3 = MockXFile();
        
        when(() => mockPermissionProvider.checkPermission(Permission.photos))
            .thenAnswer((_) async => PermissionStatus.granted);
        
        when(() => mockImagePickerProvider.pickMultiImage(
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 90,
        )).thenAnswer((_) async => [mockXFile1, mockXFile2, mockXFile3]);
        
        when(() => mockXFile1.path).thenReturn('/path/to/image1.jpg');
        when(() => mockXFile2.path).thenReturn('/path/to/image2.jpg');
        when(() => mockXFile3.path).thenReturn('/path/to/image3.jpg');
        
        when(() => mockImageValidator.isValidImageFile(any())).thenReturn(true);
        
        // Act
        final result = await service.pickMultipleImages(maxImages: 5);
        
        // Assert
        expect(result, hasLength(3));
        verify(() => mockImagePickerProvider.pickMultiImage(
          maxWidth: 2400,
          maxHeight: 2400,
          imageQuality: 90,
        )).called(1);
      });
      
      test('should limit number of selected images to maxImages', () async {
        // Arrange
        final images = List.generate(10, (i) {
          final mock = MockXFile();
          when(() => mock.path).thenReturn('/path/to/image$i.jpg');
          return mock;
        });
        
        when(() => mockPermissionProvider.checkPermission(Permission.photos))
            .thenAnswer((_) async => PermissionStatus.granted);
        
        when(() => mockImagePickerProvider.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => images);
        
        when(() => mockImageValidator.isValidImageFile(any())).thenReturn(true);
        
        // Act
        final result = await service.pickMultipleImages(maxImages: 5);
        
        // Assert
        expect(result, hasLength(5));
      });
      
      test('should filter out invalid images', () async {
        // Arrange
        final mockXFile1 = MockXFile();
        final mockXFile2 = MockXFile();
        final mockXFile3 = MockXFile();
        
        when(() => mockPermissionProvider.checkPermission(Permission.photos))
            .thenAnswer((_) async => PermissionStatus.granted);
        
        when(() => mockImagePickerProvider.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => [mockXFile1, mockXFile2, mockXFile3]);
        
        when(() => mockXFile1.path).thenReturn('/path/to/image1.jpg');
        when(() => mockXFile2.path).thenReturn('/path/to/image2.jpg');
        when(() => mockXFile3.path).thenReturn('/path/to/image3.jpg');
        
        // Only validate first and third images
        var callCount = 0;
        when(() => mockImageValidator.isValidImageFile(any())).thenAnswer((_) {
          callCount++;
          return callCount != 2; // Second image is invalid
        });
        
        // Act
        final result = await service.pickMultipleImages();
        
        // Assert
        expect(result, hasLength(2));
      });
      
      test('should return empty list when permission is denied', () async {
        // Arrange
        when(() => mockPermissionProvider.checkPermission(Permission.photos))
            .thenAnswer((_) async => PermissionStatus.denied);
        
        when(() => mockPermissionProvider.requestPermission(Permission.photos))
            .thenAnswer((_) async => PermissionStatus.permanentlyDenied);
        
        when(() => mockPermissionProvider.checkPermission(Permission.storage))
            .thenAnswer((_) async => PermissionStatus.permanentlyDenied);
        
        // Act
        final result = await service.pickMultipleImages();
        
        // Assert
        expect(result, isEmpty);
        verifyNever(() => mockImagePickerProvider.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        ));
      });
      
      test('should return empty list when user cancels selection', () async {
        // Arrange
        when(() => mockPermissionProvider.checkPermission(Permission.photos))
            .thenAnswer((_) async => PermissionStatus.granted);
        
        when(() => mockImagePickerProvider.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        )).thenAnswer((_) async => []);
        
        // Act
        final result = await service.pickMultipleImages();
        
        // Assert
        expect(result, isEmpty);
      });
      
      test('should handle exceptions gracefully', () async {
        // Arrange
        when(() => mockPermissionProvider.checkPermission(any()))
            .thenThrow(Exception('Permission error'));
        
        // Act
        final result = await service.pickMultipleImages();
        
        // Assert
        expect(result, isEmpty);
      });
    });
    
    group('debugPermissions', () {
      test('should check all permission statuses', () async {
        // Arrange
        when(() => mockPermissionProvider.checkPermission(Permission.camera))
            .thenAnswer((_) async => PermissionStatus.granted);
        when(() => mockPermissionProvider.checkPermission(Permission.photos))
            .thenAnswer((_) async => PermissionStatus.limited);
        when(() => mockPermissionProvider.checkPermission(Permission.storage))
            .thenAnswer((_) async => PermissionStatus.denied);
        when(() => mockPermissionProvider.checkPermission(Permission.mediaLibrary))
            .thenAnswer((_) async => PermissionStatus.permanentlyDenied);
        
        // Act
        await service.debugPermissions();
        
        // Assert
        verify(() => mockPermissionProvider.checkPermission(Permission.camera)).called(1);
        verify(() => mockPermissionProvider.checkPermission(Permission.photos)).called(1);
        verify(() => mockPermissionProvider.checkPermission(Permission.storage)).called(1);
        verify(() => mockPermissionProvider.checkPermission(Permission.mediaLibrary)).called(1);
      });
    });
  });
}