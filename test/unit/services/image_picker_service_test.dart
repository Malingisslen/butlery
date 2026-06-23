import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';

import 'package:butlery/services/image_picker_service.dart';
import 'package:butlery/services/image_picker_provider.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';

// Pure mocks — the centralised versions have concrete @override
// implementations that block mocktail stubs.
class _MockImagePickerProvider extends Mock implements ImagePickerProvider {}

class _MockPermissionProvider extends Mock implements PermissionProvider {}

class _MockImageValidator extends Mock implements ImageValidator {}

void main() {
  late ImagePickerService service;
  late _MockImagePickerProvider mockPicker;
  late _MockPermissionProvider mockPermission;
  late _MockImageValidator mockValidator;
  late Directory tmpDir;

  /// Create a real file on disk so File.exists() returns true.
  Future<String> createTempImage(String name) async {
    final path = '${tmpDir.path}/$name';
    final file = File(path);
    await file.writeAsBytes([0xFF, 0xD8, 0xFF]); // JPEG magic bytes
    return path;
  }

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(Permission.camera);
    registerFallbackValue(ImageSource.camera);
    registerFallbackValue(File(''));
  });

  setUp(() async {
    mockPicker = _MockImagePickerProvider();
    mockPermission = _MockPermissionProvider();
    mockValidator = _MockImageValidator();

    service = ImagePickerService(
      imagePickerProvider: mockPicker,
      permissionProvider: mockPermission,
      imageValidator: mockValidator,
    );

    tmpDir = await Directory.systemTemp.createTemp('image_picker_test_');
  });

  tearDown(() async {
    // Clean up temp files
    if (await tmpDir.exists()) {
      await tmpDir.delete(recursive: true);
    }
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  group('pickImage', () {
    test('should pick image from camera with granted permission', () async {
      final path = await createTempImage('image.jpg');

      when(
        () => mockPermission.checkPermission(Permission.camera),
      ).thenAnswer((_) async => PermissionStatus.granted);

      // BUT-992: defaults are 1600 / 80 since wave-16.
      when(
        () => mockPicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        ),
      ).thenAnswer((_) async => XFile(path));

      when(() => mockValidator.isValidImageFile(any())).thenReturn(true);

      final result = await service.pickImage(ImageSource.camera);

      expect(result, isNotNull);
      expect(result!.path, equals(path));
      verify(() => mockPermission.checkPermission(Permission.camera)).called(1);
      // BUT-992: confirm the picker was actually called with the new
      // bandwidth-friendly defaults (regression guard).
      verify(
        () => mockPicker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        ),
      ).called(1);
    });

    test('should request camera permission when denied then granted', () async {
      final path = await createTempImage('image.jpg');

      when(
        () => mockPermission.checkPermission(Permission.camera),
      ).thenAnswer((_) async => PermissionStatus.denied);
      when(
        () => mockPermission.requestPermission(Permission.camera),
      ).thenAnswer((_) async => PermissionStatus.granted);

      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => XFile(path));

      when(() => mockValidator.isValidImageFile(any())).thenReturn(true);

      final result = await service.pickImage(ImageSource.camera);

      expect(result, isNotNull);
      verify(
        () => mockPermission.requestPermission(Permission.camera),
      ).called(1);
    });

    test(
      'should return null when camera permission permanently denied',
      () async {
        when(
          () => mockPermission.checkPermission(Permission.camera),
        ).thenAnswer((_) async => PermissionStatus.denied);
        when(
          () => mockPermission.requestPermission(Permission.camera),
        ).thenAnswer((_) async => PermissionStatus.permanentlyDenied);

        final result = await service.pickImage(ImageSource.camera);

        expect(result, isNull);
        verifyNever(
          () => mockPicker.pickImage(
            source: any(named: 'source'),
            maxWidth: any(named: 'maxWidth'),
            maxHeight: any(named: 'maxHeight'),
            imageQuality: any(named: 'imageQuality'),
          ),
        );
      },
    );

    test('should return null when user cancels selection', () async {
      when(
        () => mockPermission.checkPermission(Permission.camera),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => null);

      final result = await service.pickImage(ImageSource.camera);
      expect(result, isNull);
    });

    test('should handle gallery with limited permission', () async {
      final path = await createTempImage('gallery.jpg');

      when(
        () => mockPermission.checkPermission(Permission.photos),
      ).thenAnswer((_) async => PermissionStatus.limited);

      // BUT-992: defaults are 1600 / 80 since wave-16.
      when(
        () => mockPicker.pickImage(
          source: ImageSource.gallery,
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        ),
      ).thenAnswer((_) async => XFile(path));

      when(() => mockValidator.isValidImageFile(any())).thenReturn(true);

      final result = await service.pickImage(ImageSource.gallery);

      expect(result, isNotNull);
      verify(() => mockPermission.checkPermission(Permission.photos)).called(1);
    });

    test('should fallback to storage when photos permanently denied', () async {
      final path = await createTempImage('fallback.jpg');

      when(
        () => mockPermission.checkPermission(Permission.photos),
      ).thenAnswer((_) async => PermissionStatus.permanentlyDenied);
      when(
        () => mockPermission.checkPermission(Permission.storage),
      ).thenAnswer((_) async => PermissionStatus.granted);

      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => XFile(path));

      when(() => mockValidator.isValidImageFile(any())).thenReturn(true);

      final result = await service.pickImage(ImageSource.gallery);

      expect(result, isNotNull);
      verify(() => mockPermission.checkPermission(Permission.photos)).called(1);
      verify(
        () => mockPermission.checkPermission(Permission.storage),
      ).called(1);
    });

    test('should return null when image validation fails', () async {
      final path = await createTempImage('invalid.jpg');

      when(
        () => mockPermission.checkPermission(any()),
      ).thenAnswer((_) async => PermissionStatus.granted);

      when(
        () => mockPicker.pickImage(
          source: any(named: 'source'),
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => XFile(path));

      when(() => mockValidator.isValidImageFile(any())).thenReturn(false);

      final result = await service.pickImage(ImageSource.camera);

      expect(result, isNull);
      verify(() => mockValidator.isValidImageFile(any())).called(1);
    });

    test('should handle exceptions gracefully', () async {
      when(
        () => mockPermission.checkPermission(any()),
      ).thenThrow(Exception('Permission error'));

      final result = await service.pickImage(ImageSource.camera);
      expect(result, isNull);
    });
  });

  group('pickMultipleImages', () {
    test('should pick multiple images from gallery', () async {
      final paths = await Future.wait(
        List.generate(3, (i) => createTempImage('multi_$i.jpg')),
      );

      when(
        () => mockPermission.checkPermission(Permission.photos),
      ).thenAnswer((_) async => PermissionStatus.granted);

      // BUT-992: defaults are 1600 / 80 since wave-16.
      when(
        () => mockPicker.pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        ),
      ).thenAnswer((_) async => paths.map((p) => XFile(p)).toList());

      when(() => mockValidator.isValidImageFile(any())).thenReturn(true);

      final result = await service.pickMultipleImages(maxImages: 5);

      expect(result, hasLength(3));
      // BUT-992: regression guard — pickMultiImage must use the new defaults.
      verify(
        () => mockPicker.pickMultiImage(
          maxWidth: 1600,
          maxHeight: 1600,
          imageQuality: 80,
        ),
      ).called(1);
    });

    test('should limit to maxImages', () async {
      final paths = await Future.wait(
        List.generate(10, (i) => createTempImage('limit_$i.jpg')),
      );

      when(
        () => mockPermission.checkPermission(Permission.photos),
      ).thenAnswer((_) async => PermissionStatus.granted);

      when(
        () => mockPicker.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => paths.map((p) => XFile(p)).toList());

      when(() => mockValidator.isValidImageFile(any())).thenReturn(true);

      final result = await service.pickMultipleImages(maxImages: 5);
      expect(result, hasLength(5));
    });

    test('should filter out invalid images', () async {
      final paths = await Future.wait(
        List.generate(3, (i) => createTempImage('filter_$i.jpg')),
      );

      when(
        () => mockPermission.checkPermission(Permission.photos),
      ).thenAnswer((_) async => PermissionStatus.granted);

      when(
        () => mockPicker.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => paths.map((p) => XFile(p)).toList());

      var callCount = 0;
      when(() => mockValidator.isValidImageFile(any())).thenAnswer((_) {
        callCount++;
        return callCount != 2; // Second image invalid
      });

      final result = await service.pickMultipleImages();
      expect(result, hasLength(2));
    });

    test('should return empty list when permission denied', () async {
      when(
        () => mockPermission.checkPermission(Permission.photos),
      ).thenAnswer((_) async => PermissionStatus.denied);
      when(
        () => mockPermission.requestPermission(Permission.photos),
      ).thenAnswer((_) async => PermissionStatus.permanentlyDenied);
      when(
        () => mockPermission.checkPermission(Permission.storage),
      ).thenAnswer((_) async => PermissionStatus.permanentlyDenied);

      final result = await service.pickMultipleImages();

      expect(result, isEmpty);
    });

    test('should return empty list when user cancels', () async {
      when(
        () => mockPermission.checkPermission(Permission.photos),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(
        () => mockPicker.pickMultiImage(
          maxWidth: any(named: 'maxWidth'),
          maxHeight: any(named: 'maxHeight'),
          imageQuality: any(named: 'imageQuality'),
        ),
      ).thenAnswer((_) async => []);

      final result = await service.pickMultipleImages();
      expect(result, isEmpty);
    });

    test('should handle exceptions gracefully', () async {
      when(
        () => mockPermission.checkPermission(any()),
      ).thenThrow(Exception('Permission error'));

      final result = await service.pickMultipleImages();
      expect(result, isEmpty);
    });
  });

  group('debugPermissions', () {
    test('should check all permission statuses', () async {
      when(
        () => mockPermission.checkPermission(Permission.camera),
      ).thenAnswer((_) async => PermissionStatus.granted);
      when(
        () => mockPermission.checkPermission(Permission.photos),
      ).thenAnswer((_) async => PermissionStatus.limited);
      when(
        () => mockPermission.checkPermission(Permission.storage),
      ).thenAnswer((_) async => PermissionStatus.denied);
      when(
        () => mockPermission.checkPermission(Permission.mediaLibrary),
      ).thenAnswer((_) async => PermissionStatus.permanentlyDenied);

      await service.debugPermissions();

      verify(() => mockPermission.checkPermission(Permission.camera)).called(1);
      verify(() => mockPermission.checkPermission(Permission.photos)).called(1);
      verify(
        () => mockPermission.checkPermission(Permission.storage),
      ).called(1);
      verify(
        () => mockPermission.checkPermission(Permission.mediaLibrary),
      ).called(1);
    });
  });
}
