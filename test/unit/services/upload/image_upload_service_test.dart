import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/services/upload/image_upload_service.dart';
import 'package:butlery/services/storage_service.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';

class MockStorageService extends Mock implements StorageService {}

void main() {
  group('ImageUploadService - uploadImageFromBytes', () {
    late ImageUploadService uploadService;
    late MockStorageService mockStorageService;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();
      mockStorageService = MockStorageService();
      uploadService = ImageUploadService(
        storageService: mockStorageService,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    test('routes with avatar prefix', () async {
      const expectedUrl = 'https://storage.example.com/avatar.jpg';

      when(() => mockStorageService.uploadImageBytes(
            any(),
            any(),
            any(),
            prefix: 'avatar',
          )).thenAnswer((_) async => expectedUrl);

      final result = await uploadService.uploadImageFromBytes(
        bytes: Uint8List.fromList([1, 2, 3, 4, 5]),
        userId: 'test-user',
        fileName: 'avatar.jpg',
        prefix: 'avatar',
      );

      expect(result.success, isTrue);
      expect(result.url, equals(expectedUrl));
      verify(() => mockStorageService.uploadImageBytes(
            any(),
            'test-user',
            'avatar.jpg',
            prefix: 'avatar',
          )).called(1);
    });

    test('defaults to recipe prefix', () async {
      const expectedUrl = 'https://storage.example.com/recipe.jpg';

      when(() => mockStorageService.uploadImageBytes(
            any(),
            any(),
            any(),
            prefix: 'recipe',
          )).thenAnswer((_) async => expectedUrl);

      final result = await uploadService.uploadImageFromBytes(
        bytes: Uint8List.fromList([10, 20, 30]),
        userId: 'test-user',
        fileName: 'recipe_photo.jpg',
      );

      expect(result.success, isTrue);
      expect(result.url, equals(expectedUrl));
      verify(() => mockStorageService.uploadImageBytes(
            any(),
            'test-user',
            'recipe_photo.jpg',
            prefix: 'recipe',
          )).called(1);
    });

    test('returns failure for empty bytes', () async {
      final result = await uploadService.uploadImageFromBytes(
        bytes: Uint8List(0),
        userId: 'test-user',
        fileName: 'photo.jpg',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('empty'));
      verifyNever(() => mockStorageService.uploadImageBytes(
            any(),
            any(),
            any(),
            prefix: any(named: 'prefix'),
          ));
    });

    test('returns failure when StorageService returns null', () async {
      when(() => mockStorageService.uploadImageBytes(
            any(),
            any(),
            any(),
            prefix: 'avatar',
          )).thenAnswer((_) async => null);

      final result = await uploadService.uploadImageFromBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        userId: 'test-user',
        fileName: 'avatar.jpg',
        prefix: 'avatar',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('null URL'));
    });

    test('handles StorageService exception gracefully', () async {
      when(() => mockStorageService.uploadImageBytes(
            any(),
            any(),
            any(),
            prefix: 'recipe',
          )).thenThrow(Exception('Network error'));

      final result = await uploadService.uploadImageFromBytes(
        bytes: Uint8List.fromList([1, 2, 3]),
        userId: 'test-user',
        fileName: 'photo.jpg',
      );

      expect(result.success, isFalse);
      expect(result.error, contains('Network error'));
    });
  });
}
