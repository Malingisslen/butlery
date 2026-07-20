/// Unit tests for FirebaseStorageRepository.
///
/// Exercises upload, delete and name-generation against the
/// official `firebase_storage_mocks` in-memory fake — we assert user-visible
/// behaviour (bytes stored, URL returned, file removed) rather than internal
/// call sequencing.
library;

import 'dart:async';
import 'dart:typed_data';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/repositories/firebase/firebase_storage_repository.dart';
import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
// production_mocks supplies FakeAuthRepository / MockFile / MockUuid / FakeUser.
// The Firebase Storage SDK mocks now come from firebase_storage_mocks (above).
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseStorageRepository', () {
    late FirebaseStorageRepository repository;
    late MockFirebaseStorage mockStorage;
    late MockUuid mockUuid;
    late FakeAuthRepository mockAuthRepository;

    const testUserId = 'test-user-123';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      mockStorage = MockFirebaseStorage();
      mockUuid = MockUuid();
      mockAuthRepository = FakeAuthRepository();

      mockAuthRepository.setAuthState(
        user: FakeUser(uid: testUserId),
        userId: testUserId,
        isAuthenticated: true,
      );

      _stubUuid(mockUuid, 'test-uuid-123');

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
      test('stores uploaded bytes and returns a download URL', () async {
        final imageData = Uint8List.fromList([1, 2, 3, 4, 5]);
        const path = 'users/$testUserId/recipes/images/test-image.jpg';

        final result = await repository.uploadImageData(
          imageData: imageData,
          userId: testUserId,
          path: path,
        );

        // Data landed in the fake storage (keys are normalised without
        // the leading slash — see firebase_storage_mocks).
        expect(mockStorage.storedDataMap.get(path), imageData);
        expect(result, isNotNull);
        expect(result, contains(path));
      });

      test('records custom metadata and required uploadedBy stamp', () async {
        final imageData = Uint8List.fromList([1, 2, 3]);
        const path = 'users/$testUserId/recipes/path.jpg';

        await repository.uploadImageData(
          imageData: imageData,
          userId: testUserId,
          path: path,
          metadata: {
            'originalName': 'photo.jpg',
            'recipeId': 'recipe_123',
          },
        );

        // firebase_storage_mocks keys this map by the raw `_path` which has
        // a leading slash; read by the key `storedSettableMetadataMap` uses.
        final storedKey = mockStorage.storedSettableMetadataMap.keys.firstWhere(
          (k) => k.endsWith(path),
        );
        final stored = mockStorage.storedSettableMetadataMap[storedKey];
        expect(stored, isNotNull);

        final custom = stored!['customMetadata'] as Map<String, dynamic>;
        expect(custom['originalName'], 'photo.jpg');
        expect(custom['recipeId'], 'recipe_123');
        // Repository always stamps `uploadedBy` for the storage.rules check.
        expect(custom['uploadedBy'], testUserId);
      });

      test(
        'returns null when the upload path is outside the user directory',
        () async {
          final imageData = Uint8List.fromList([1, 2, 3]);
          // Path does not belong to the current user — permission check fails,
          // the repository swallows the exception and returns null.
          const path = 'users/someone-else/recipes/path.jpg';

          final result = await repository.uploadImageData(
            imageData: imageData,
            userId: 'someone-else',
            path: path,
          );

          expect(result, isNull);
          expect(mockStorage.storedDataMap.get(path), isNull);
        },
      );

      test(
        'uploadImage still rejects a foreign path after the duplicate '
        'permission check was removed (BUT-1558)',
        () async {
          // BUT-1558 deleted uploadImage's own _validateUploadPermission call
          // because uploadImageData re-runs the identical (audit-logged) check.
          // That is only safe while the inner check actually still gates the
          // write — this pins it. If someone later bypasses uploadImageData or
          // moves the validation, this test fails instead of silently opening
          // writes into another user's directory.
          final file = MockFile();
          when(() => file.path).thenReturn('/tmp/photo.jpg');
          when(
            () => file.readAsBytes(),
          ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
          when(() => file.lengthSync()).thenReturn(3);

          const foreignPath = 'users/someone-else/recipes/intruder.jpg';

          final result = await repository.uploadImage(
            imageFile: file,
            userId: 'someone-else',
            path: foreignPath,
          );

          expect(
            mockStorage.storedDataMap.get(foreignPath),
            isNull,
            reason: 'no bytes may reach another user directory',
          );
          expect(
            result,
            isNull,
            reason: 'foreign-path upload must not succeed',
          );

          // POSITIVE CONTROL: the same fixture DOES upload to the user's own
          // path. Without this, a future change that makes compression bail on
          // this payload would short-circuit uploadImage before it ever reaches
          // the permission check — and the assertions above would still pass,
          // proving nothing. This makes such a regression fail loudly here.
          const ownPath = 'users/$testUserId/recipes/own.jpg';
          final ownResult = await repository.uploadImage(
            imageFile: file,
            userId: testUserId,
            path: ownPath,
          );
          expect(
            ownResult,
            isNotNull,
            reason:
                'control upload must succeed, else the denial above is '
                'not evidence the permission check ran',
          );
        },
      );
    });

    // BUT-1635: backfills the progress-subscription-cancel coverage BUT-1558
    // shipped without. firebase_storage_mocks' MockTaskSnapshot has no
    // `bytesTransferred`/`totalBytes` (noSuchMethod), so attaching onProgress
    // to the stock fake makes the listener throw — which is why the original
    // attempt was abandoned. The fix is a purpose-built UploadTask fake whose
    // snapshot stream we own: `hasListener` on that controller is then a direct,
    // non-vacuous read of whether the repository's subscription outlived the
    // upload.
    group('Upload progress subscription lifecycle (BUT-1558)', () {
      late _ProgressStorage progressStorage;
      late FirebaseStorageRepository progressRepository;

      setUp(() {
        progressStorage = _ProgressStorage();
        progressRepository = FirebaseStorageRepository(
          storage: progressStorage,
          uuid: mockUuid,
          authRepository: mockAuthRepository,
        );
      });

      test('cancels the snapshot subscription after a successful upload', () async {
        final progressValues = <double>[];

        final result = await progressRepository.uploadImageData(
          imageData: Uint8List.fromList([1, 2, 3, 4]),
          userId: testUserId,
          path: 'users/$testUserId/recipes/progress.jpg',
          onProgress: progressValues.add,
        );

        expect(result, isNotNull, reason: 'upload itself must still succeed');

        // POSITIVE CONTROL: without this, `hasListener == false` below would
        // also pass if no listener was ever attached — proving nothing about
        // the cancel.
        expect(
          progressValues,
          isNotEmpty,
          reason: 'a listener must actually have been attached and fired',
        );

        // The controller is deliberately left OPEN, so an uncancelled
        // subscription would still be registered here.
        expect(
          progressStorage.task.controller.hasListener,
          isFalse,
          reason:
              'the progress subscription must not outlive the upload — a leaked '
              'listener keeps the TaskSnapshot stream and the uploaded bytes alive',
        );
      });

      test(
        'cancels the snapshot subscription even when the upload fails',
        () async {
          // The `finally` block is what makes this true: on the throwing path
          // the cancel must still run, otherwise every failed upload leaks.
          progressStorage.failUpload = true;
          final progressValues = <double>[];

          final result = await progressRepository.uploadImageData(
            imageData: Uint8List.fromList([1, 2, 3, 4]),
            userId: testUserId,
            path: 'users/$testUserId/recipes/progress-fail.jpg',
            onProgress: progressValues.add,
          );

          expect(result, isNull, reason: 'a failed upload returns null');
          expect(
            progressValues,
            isNotEmpty,
            reason: 'a listener must actually have been attached and fired',
          );
          expect(
            progressStorage.task.controller.hasListener,
            isFalse,
            reason: 'a failed upload must not leak its progress subscription',
          );
        },
      );

      test(
        'attaches no subscription at all when no onProgress is given',
        () async {
          final result = await progressRepository.uploadImageData(
            imageData: Uint8List.fromList([1, 2, 3, 4]),
            userId: testUserId,
            path: 'users/$testUserId/recipes/no-progress.jpg',
          );

          expect(result, isNotNull);
          expect(progressStorage.task.controller.hasListener, isFalse);
        },
      );
    });

    group('Multiple Image Upload', () {
      test('uploads each image in parallel and reports progress', () async {
        // Bytes are small enough to skip compression
        // (see UploadConstants.skipCompressionThreshold), so each file goes
        // straight to the fake storage and succeeds.
        final file1 = MockFile();
        final file2 = MockFile();
        for (final (f, p) in [
          (file1, '/path/img1.jpg'),
          (file2, '/path/img2.jpg'),
        ]) {
          when(() => f.path).thenReturn(p);
          when(
            () => f.readAsBytes(),
          ).thenAnswer((_) async => Uint8List.fromList([1, 2, 3]));
          when(() => f.lengthSync()).thenReturn(3);
        }

        final progressUpdates = <(int, int)>[];

        final results = await repository.uploadMultipleImages(
          imageFiles: [file1, file2],
          userId: testUserId,
          basePath: 'users/$testUserId/recipes/batch',
          onProgress: (completed, total) =>
              progressUpdates.add((completed, total)),
        );

        expect(results.length, 2);
        expect(progressUpdates, isNotEmpty);
        expect(progressUpdates.last, (2, 2));
      });
    });

    group('Image Deletion', () {
      test('deletes a stored object addressed by its download URL', () async {
        // Seed via the public repository interface so the mock normalisation
        // matches what deleteImage will see.
        await repository.uploadImageData(
          imageData: Uint8List.fromList([1, 2, 3]),
          userId: testUserId,
          path: 'users/$testUserId/recipes/image.jpg',
        );
        // Grab the download URL the same way production would.
        final url = await mockStorage
            .ref()
            .child('users/$testUserId/recipes/image.jpg')
            .getDownloadURL();

        final result = await repository.deleteImage(url);

        expect(result, isTrue);
        expect(mockStorage.storedDataMap.keys, isEmpty);
      });

      test('returns false when the current user does not own the file', () async {
        // Someone else's file — deleteImage rejects on permission check.
        const url =
            'https://firebasestorage.googleapis.com/v0/b/some-bucket/o/users/another-user/recipes/image.jpg';

        final result = await repository.deleteImage(url);

        expect(result, isFalse);
      });

      test('deletes multiple images addressed by their URLs', () async {
        final paths = [
          'users/$testUserId/recipes/image1.jpg',
          'users/$testUserId/recipes/image2.jpg',
          'users/$testUserId/recipes/image3.jpg',
        ];
        final urls = <String>[];
        for (final p in paths) {
          await repository.uploadImageData(
            imageData: Uint8List.fromList([1]),
            userId: testUserId,
            path: p,
          );
          urls.add(await mockStorage.ref().child(p).getDownloadURL());
        }

        await repository.deleteMultipleImages(urls);

        expect(mockStorage.storedDataMap.keys, isEmpty);
      });
    });

    group('File Name Generation', () {
      test('preserves the extension and embeds the UUID prefix', () {
        _stubUuid(mockUuid, 'unique-id-123');

        final fileName = repository.generateFileName(
          originalPath: '/path/to/original.jpg',
        );

        expect(fileName, contains('unique-i'));
        expect(fileName, endsWith('.jpg'));
      });

      test('uses a custom prefix when provided', () {
        _stubUuid(mockUuid, 'abc-123-456-789');

        final fileName = repository.generateFileName(
          originalPath: '/path/to/original.png',
          prefix: 'recipe',
        );

        expect(fileName, startsWith('recipe_'));
        expect(fileName, contains('abc-123-'));
        expect(fileName, endsWith('.png'));
      });
    });
  });
}

void _stubUuid(MockUuid mock, String value) {
  when(() => mock.v4()).thenReturn(value);
}

/// Minimal FirebaseStorage fake whose UploadTask emits a real TaskSnapshot.
///
/// firebase_storage_mocks cannot do this (its MockTaskSnapshot resolves
/// `bytesTransferred` through noSuchMethod), and the progress-cancel behaviour
/// is invisible without a snapshot stream we control.
class _ProgressStorage implements FirebaseStorage {
  final _ProgressReference _root = _ProgressReference();

  /// When true the upload future completes with an error, exercising the
  /// `finally`-cancel path rather than the happy path.
  bool get failUpload => _root.failUpload;
  set failUpload(bool value) => _root.failUpload = value;

  _ProgressUploadTask get task => _root.lastTask!;

  @override
  Reference ref([String? path]) => _root;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProgressReference implements Reference {
  bool failUpload = false;
  _ProgressUploadTask? lastTask;

  @override
  Reference child(String path) => this;

  @override
  Future<String> getDownloadURL() async => 'https://example.test/download';

  @override
  UploadTask putData(Uint8List data, [SettableMetadata? metadata]) {
    final task = _ProgressUploadTask(this, failUpload: failUpload);
    lastTask = task;
    // Runs after the repository has synchronously attached its listener
    // (nothing awaits between `putData` and `.listen`).
    scheduleMicrotask(() async {
      task.controller.add(task.snapshot);
      // Let the stream event reach the listener before the task resolves,
      // so onProgress is genuinely invoked.
      await Future<void>.delayed(Duration.zero);
      if (failUpload) {
        task.completer.completeError(Exception('upload failed'));
      } else {
        task.completer.complete(task.snapshot);
      }
    });
    return task;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProgressUploadTask implements UploadTask {
  final controller = StreamController<TaskSnapshot>();
  final completer = Completer<TaskSnapshot>();

  @override
  final _ProgressSnapshot snapshot;

  _ProgressUploadTask(Reference ref, {required bool failUpload})
    : snapshot = _ProgressSnapshot(ref) {
    // An error delivered through `then` must not also surface as an unhandled
    // async error from the raw future.
    if (failUpload) completer.future.catchError((Object _) => snapshot);
  }

  @override
  Stream<TaskSnapshot> get snapshotEvents => controller.stream;

  @override
  Future<S> then<S>(
    FutureOr<S> Function(TaskSnapshot) onValue, {
    Function? onError,
  }) => completer.future.then(onValue, onError: onError);

  @override
  Stream<TaskSnapshot> asStream() => completer.future.asStream();

  @override
  Future<TaskSnapshot> catchError(
    Function onError, {
    bool Function(Object error)? test,
  }) => completer.future.catchError(onError, test: test);

  @override
  Future<TaskSnapshot> whenComplete(FutureOr<void> Function() action) =>
      completer.future.whenComplete(action);

  @override
  Future<TaskSnapshot> timeout(
    Duration timeLimit, {
    FutureOr<TaskSnapshot> Function()? onTimeout,
  }) => completer.future.timeout(timeLimit, onTimeout: onTimeout);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _ProgressSnapshot implements TaskSnapshot {
  @override
  final Reference ref;

  _ProgressSnapshot(this.ref);

  @override
  int get bytesTransferred => 2;

  @override
  int get totalBytes => 4;

  @override
  TaskState get state => TaskState.running;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
