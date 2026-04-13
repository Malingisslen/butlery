/// Unit tests for FirebaseStorageRepository
///
/// Tests the storage repository that provides file upload, download,
/// and management functionality for images in the application.
library;

// ignore_for_file: subtype_of_sealed_class

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:butlery/repositories/firebase/firebase_storage_repository.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// Custom FakeUploadTask that properly implements Future interface
class FakeUploadTask extends Fake implements UploadTask {
  final Future<TaskSnapshot> _future;
  final Stream<TaskSnapshot>? _snapshotEvents;

  FakeUploadTask({
    required Future<TaskSnapshot> future,
    Stream<TaskSnapshot>? snapshotEvents,
  })  : _future = future,
        _snapshotEvents = snapshotEvents;

  @override
  Stream<TaskSnapshot> get snapshotEvents =>
      _snapshotEvents ?? const Stream.empty();

  @override
  Future<R> then<R>(
    FutureOr<R> Function(TaskSnapshot value) onValue, {
    Function? onError,
  }) {
    return _future.then(onValue, onError: onError);
  }

  @override
  Future<TaskSnapshot> catchError(Function onError,
      {bool Function(Object error)? test}) {
    return _future.catchError(onError, test: test);
  }

  @override
  Future<TaskSnapshot> whenComplete(FutureOr<void> Function() action) {
    return _future.whenComplete(action);
  }

  @override
  Future<TaskSnapshot> timeout(Duration timeLimit,
      {FutureOr<TaskSnapshot> Function()? onTimeout}) {
    return _future.timeout(timeLimit, onTimeout: onTimeout);
  }

  @override
  Stream<TaskSnapshot> asStream() => _future.asStream();

  // Provide the future for proper await behavior
  Future<TaskSnapshot> get future => _future;
}

// Custom mock for SettableMetadata
class FakeSettableMetadata extends Fake implements SettableMetadata {
  @override
  final String? contentType;
  @override
  final Map<String, String>? customMetadata;

  FakeSettableMetadata({this.contentType, this.customMetadata});
}

void main() {
  group('FirebaseStorageRepository', () {
    late FirebaseStorageRepository repository;
    late MockFirebaseStorage mockStorage;
    late MockUuid mockUuid;
    late MockReference mockRef;
    late MockReference mockChildRef;
    late MockTaskSnapshot mockTaskSnapshot;
    late MockAuthRepository mockAuthRepository;

    const testUserId = 'test-user-123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
      registerFallbackValue(Uint8List(0));
      registerFallbackValue(FakeSettableMetadata());
      registerFallbackValue(File(''));
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      // Create mocks
      mockStorage = MockFirebaseStorage();
      mockUuid = MockUuid();
      mockRef = MockReference();
      mockChildRef = MockReference();
      mockTaskSnapshot = MockTaskSnapshot();
      mockAuthRepository = MockAuthRepository();

      // Setup mock auth using setAuthState (not when()) since MockAuthRepository
      // has real getter overrides. BaseStorageRepository.currentUserId accesses
      // _authRepository.currentUser?.uid, so we must provide a FakeUser.
      mockAuthRepository.setAuthState(
        user: FakeUser(uid: testUserId),
        userId: testUserId,
        isAuthenticated: true,
      );

      // Setup mock behaviors
      when(() => mockUuid.v4()).thenReturn('test-uuid-123');
      when(() => mockStorage.ref()).thenReturn(mockRef);
      when(() => mockRef.child(any())).thenReturn(mockChildRef);

      // Create repository with mocked dependencies
      repository = FirebaseStorageRepository(
        storage: mockStorage,
        uuid: mockUuid,
        authRepository: mockAuthRepository,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Image Upload', () {
      test('should upload image data successfully', () async {
        // Arrange
        final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);
        // Path must start with users/{userId}/ for permission validation
        const path = 'users/$testUserId/recipes/images/test-image.jpg';
        const expectedUrl = 'https://storage.example.com/test-image.jpg';

        // Setup mock task snapshot
        when(() => mockTaskSnapshot.ref).thenReturn(mockChildRef);
        when(() => mockTaskSnapshot.bytesTransferred).thenReturn(100);
        when(() => mockTaskSnapshot.totalBytes).thenReturn(100);
        when(() => mockChildRef.getDownloadURL()).thenAnswer(
          (_) async => expectedUrl,
        );

        // Create FakeUploadTask with proper Future behavior
        final uploadTask = FakeUploadTask(
          future: Future.value(mockTaskSnapshot),
          snapshotEvents: Stream.value(mockTaskSnapshot),
        );

        when(() => mockChildRef.putData(
              any(),
              any(),
            )).thenAnswer((_) => uploadTask);

        // Act
        final result = await repository.uploadImageData(
          imageData: imageData,
          userId: testUserId,
          path: path,
        );

        // Assert
        expect(result, equals(expectedUrl));
        verify(() => mockStorage.ref()).called(1);
        verify(() => mockRef.child(path)).called(1);
        verify(() => mockChildRef.putData(
              imageData,
              any(that: isA<SettableMetadata>()),
            )).called(1);
      });

      test('should handle upload progress callback', () async {
        // Arrange
        final imageData = Uint8List.fromList([1, 2, 3]);
        const path = 'users/$testUserId/recipes/path.jpg';
        const expectedUrl = 'https://example.com/image.jpg';

        final progressValues = <double>[];

        // Create multiple task snapshots for progress
        final snapshot1 = MockTaskSnapshot();
        final snapshot2 = MockTaskSnapshot();
        final snapshot3 = MockTaskSnapshot();

        when(() => snapshot1.bytesTransferred).thenReturn(33);
        when(() => snapshot1.totalBytes).thenReturn(100);
        when(() => snapshot2.bytesTransferred).thenReturn(66);
        when(() => snapshot2.totalBytes).thenReturn(100);
        when(() => snapshot3.bytesTransferred).thenReturn(100);
        when(() => snapshot3.totalBytes).thenReturn(100);

        // Setup final snapshot
        when(() => mockTaskSnapshot.ref).thenReturn(mockChildRef);
        when(() => mockChildRef.getDownloadURL()).thenAnswer(
          (_) async => expectedUrl,
        );

        // Create FakeUploadTask with progress stream
        final uploadTask = FakeUploadTask(
          future: Future.value(mockTaskSnapshot),
          snapshotEvents:
              Stream.fromIterable([snapshot1, snapshot2, snapshot3]),
        );

        when(() => mockChildRef.putData(
              any(),
              any(),
            )).thenAnswer((_) => uploadTask);

        // Act
        final result = await repository.uploadImageData(
          imageData: imageData,
          userId: testUserId,
          path: path,
          onProgress: (progress) => progressValues.add(progress),
        );

        // Assert
        expect(result, equals(expectedUrl));
        expect(progressValues, isNotEmpty);
      });

      test('should include metadata in upload', () async {
        // Arrange
        final imageData = Uint8List.fromList([1, 2, 3]);
        const path = 'users/$testUserId/recipes/path.jpg';
        final metadata = {
          'originalName': 'photo.jpg',
          'recipeId': 'recipe_123',
        };

        // Setup mock task snapshot
        when(() => mockTaskSnapshot.ref).thenReturn(mockChildRef);
        when(() => mockTaskSnapshot.bytesTransferred).thenReturn(100);
        when(() => mockTaskSnapshot.totalBytes).thenReturn(100);
        when(() => mockChildRef.getDownloadURL()).thenAnswer(
          (_) async => 'https://example.com/image.jpg',
        );

        // Create FakeUploadTask
        final uploadTask = FakeUploadTask(
          future: Future.value(mockTaskSnapshot),
          snapshotEvents: Stream.value(mockTaskSnapshot),
        );

        when(() => mockChildRef.putData(
              any(),
              any(),
            )).thenAnswer((_) => uploadTask);

        // Act
        await repository.uploadImageData(
          imageData: imageData,
          userId: testUserId,
          path: path,
          metadata: metadata,
        );

        // Assert
        verify(() => mockChildRef.putData(
              imageData,
              any(
                  that: isA<SettableMetadata>()
                      .having(
                        (m) => m.customMetadata?.containsKey('originalName'),
                        'has originalName',
                        isTrue,
                      )
                      .having(
                        (m) => m.customMetadata?.containsKey('recipeId'),
                        'has recipeId',
                        isTrue,
                      )),
            )).called(1);
      });

      test('should return null on upload failure', () async {
        // Arrange
        final imageData = Uint8List.fromList([1, 2, 3]);
        const path = 'users/$testUserId/recipes/path.jpg';

        when(() => mockChildRef.putData(
              any(),
              any(),
            )).thenThrow(Exception('Upload failed'));

        // Act
        final result = await repository.uploadImageData(
          imageData: imageData,
          userId: testUserId,
          path: path,
        );

        // Assert
        expect(result, isNull);
      });
    });

    group('Multiple Image Upload', () {
      test('should handle multiple image upload with compression failures',
          () async {
        // Arrange
        final file1 = MockFile();
        final file2 = MockFile();
        final file3 = MockFile();

        when(() => file1.path).thenReturn('/path/to/image1.jpg');
        when(() => file2.path).thenReturn('/path/to/image2.jpg');
        when(() => file3.path).thenReturn('/path/to/image3.jpg');

        when(() => file1.readAsBytes()).thenAnswer(
          (_) async => Uint8List.fromList([1, 2, 3]),
        );
        when(() => file2.readAsBytes()).thenAnswer(
          (_) async => Uint8List.fromList([4, 5, 6]),
        );
        when(() => file3.readAsBytes()).thenAnswer(
          (_) async => Uint8List.fromList([7, 8, 9]),
        );

        when(() => file1.lengthSync()).thenReturn(3);
        when(() => file2.lengthSync()).thenReturn(3);
        when(() => file3.lengthSync()).thenReturn(3);

        final imageFiles = [file1, file2, file3];
        const basePath = 'users/$testUserId/recipes/batch';

        // Act
        // uploadMultipleImages calls uploadImage which uses FlutterImageCompress.
        // Since FlutterImageCompress isn't available in tests, compression fails
        // and uploadImage returns null, so we expect empty results.
        final results = await repository.uploadMultipleImages(
          imageFiles: imageFiles,
          userId: testUserId,
          basePath: basePath,
        );

        // Assert - compression fails so no uploads succeed
        expect(results.length, equals(0));
      });

      test('should track progress for multiple uploads', () async {
        // Arrange
        final file1 = MockFile();
        final file2 = MockFile();

        when(() => file1.path).thenReturn('/path/to/image1.jpg');
        when(() => file2.path).thenReturn('/path/to/image2.jpg');

        when(() => file1.readAsBytes()).thenAnswer(
          (_) async => Uint8List.fromList([1, 2, 3]),
        );
        when(() => file2.readAsBytes()).thenAnswer(
          (_) async => Uint8List.fromList([4, 5, 6]),
        );

        when(() => file1.lengthSync()).thenReturn(3);
        when(() => file2.lengthSync()).thenReturn(3);

        final imageFiles = [file1, file2];
        const basePath = 'users/$testUserId/recipes/batch';

        final progressUpdates = <(int, int)>[];

        // Act
        // Progress is still tracked even if uploads fail
        await repository.uploadMultipleImages(
          imageFiles: imageFiles,
          userId: testUserId,
          basePath: basePath,
          onProgress: (completed, total) {
            progressUpdates.add((completed, total));
          },
        );

        // Assert - progress is still reported even if uploads fail
        expect(progressUpdates, isNotEmpty);
        expect(progressUpdates.last, equals((2, 2)));
      });
    });

    group('Image Deletion', () {
      test('should delete image successfully', () async {
        // Arrange — URL must contain users/{userId} for permission validation
        const imageUrl =
            'https://storage.example.com/users%2F$testUserId%2Frecipes%2Fimage.jpg';
        final mockDeleteRef = MockReference();

        when(() => mockStorage.refFromURL(imageUrl)).thenReturn(mockDeleteRef);
        when(() => mockDeleteRef.delete()).thenAnswer((_) async {});

        // Act
        final result = await repository.deleteImage(imageUrl);

        // Assert
        expect(result, isTrue);
        verify(() => mockStorage.refFromURL(imageUrl)).called(1);
        verify(() => mockDeleteRef.delete()).called(1);
      });

      test('should return false on deletion failure', () async {
        // Arrange
        const imageUrl =
            'https://storage.example.com/users%2F$testUserId%2Frecipes%2Fimage.jpg';
        final mockDeleteRef = MockReference();

        when(() => mockStorage.refFromURL(imageUrl)).thenReturn(mockDeleteRef);
        when(() => mockDeleteRef.delete()).thenAnswer(
          (_) async => throw Exception('Delete failed'),
        );

        // Act
        final result = await repository.deleteImage(imageUrl);

        // Assert
        expect(result, isFalse);
      });

      test('should delete multiple images', () async {
        // Arrange — all URLs must contain users/{userId}
        final imageUrls = [
          'https://storage.example.com/users%2F$testUserId%2Frecipes%2Fimage1.jpg',
          'https://storage.example.com/users%2F$testUserId%2Frecipes%2Fimage2.jpg',
          'https://storage.example.com/users%2F$testUserId%2Frecipes%2Fimage3.jpg',
        ];

        final mockDeleteRef = MockReference();

        when(() => mockStorage.refFromURL(any())).thenReturn(mockDeleteRef);
        when(() => mockDeleteRef.delete()).thenAnswer((_) async {});

        // Act
        await repository.deleteMultipleImages(imageUrls);

        // Assert
        verify(() => mockStorage.refFromURL(any())).called(3);
        verify(() => mockDeleteRef.delete()).called(3);
      });
    });

    group('File Name Generation', () {
      test('should generate unique file name', () {
        // Arrange
        const originalPath = '/path/to/original.jpg';
        when(() => mockUuid.v4()).thenReturn('unique-id-123');

        // Act
        final fileName = repository.generateFileName(
          originalPath: originalPath,
        );

        // Assert
        expect(fileName, contains('unique-i'));
        expect(fileName, endsWith('.jpg'));
      });

      test('should use custom prefix in file name', () {
        // Arrange
        const originalPath = '/path/to/original.png';
        const prefix = 'recipe';
        when(() => mockUuid.v4()).thenReturn('abc-123-456-789');

        // Act
        final fileName = repository.generateFileName(
          originalPath: originalPath,
          prefix: prefix,
        );

        // Assert
        expect(fileName, startsWith('recipe_'));
        expect(fileName, contains('abc-123-'));
        expect(fileName, endsWith('.png'));
      });
    });
  });
}
