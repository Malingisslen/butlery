/// Unit tests for FirebaseStorageRepository concrete subclass.
///
/// Targets validate/delete/info methods that don't need image compression.
library;

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_storage_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

FirebaseStorageRepository _repo(
  MockFirebaseStorage storage, {
  String? authedUserId = 'alice',
}) {
  final mockAuth = MockAuthRepository();
  if (authedUserId != null) {
    mockAuth.setAuthState(
      user: FakeUser(uid: authedUserId),
      userId: authedUserId,
      isAuthenticated: true,
    );
  }
  return FirebaseStorageRepository(storage: storage, authRepository: mockAuth);
}

Future<void> _seedFile(
  MockFirebaseStorage storage,
  String path,
  List<int> bytes,
) async {
  await storage.ref(path).putData(Uint8List.fromList(bytes));
}

void main() {
  group('createReference', () {
    test('returns a Reference for given path', () {
      final repo = _repo(MockFirebaseStorage());
      final ref = repo.createReference('users/alice/img.jpg');
      expect(ref, isA<Reference>());
    });
  });

  group('getReferenceFromURL', () {
    test('returns null when URL is unparseable', () {
      final repo = _repo(MockFirebaseStorage());
      // MockFirebaseStorage throws on bogus URLs — wrapper returns null.
      expect(repo.getReferenceFromURL('not-a-url'), isNull);
    });
  });

  group('deleteImage', () {
    test('returns false when unauthenticated (validation fails)', () async {
      final repo = _repo(MockFirebaseStorage(), authedUserId: null);
      // _validateDeletePermission throws → caught → returns false.
      expect(await repo.deleteImage('users/alice/img.jpg'), isFalse);
    });

    test('returns false when URL extracts a different user id', () async {
      final repo = _repo(MockFirebaseStorage(), authedUserId: 'alice');
      // Path extracts 'bob' as user → mismatch → permission denied.
      expect(await repo.deleteImage('users/bob/img.jpg'), isFalse);
    });

    test('returns false when path has no users/ pattern', () async {
      final repo = _repo(MockFirebaseStorage(), authedUserId: 'alice');
      // _extractUserIdFromPath returns null → mismatch → permission denied.
      expect(await repo.deleteImage('public/img.jpg'), isFalse);
    });
  });

  group('deleteMultipleImages', () {
    test('iterates without throwing even when individual deletes fail',
        () async {
      final repo = _repo(MockFirebaseStorage(), authedUserId: 'alice');
      // All URLs are for other users → all fail → method swallows.
      await repo.deleteMultipleImages([
        'users/bob/a.jpg',
        'users/carol/b.jpg',
      ]);
    });
  });

  group('getUserStorageInfo', () {
    test('returns StorageInfo with file count and size', () async {
      final storage = MockFirebaseStorage();
      await _seedFile(
          storage, 'users/alice/recipes/a.jpg', List.filled(100, 0));
      await _seedFile(
          storage, 'users/alice/recipes/b.jpg', List.filled(200, 0));
      final repo = _repo(storage, authedUserId: 'alice');

      final info = await repo.getUserStorageInfo('alice');
      expect(info, isNotNull);
      expect(info!.fileCount, 2);
      expect(info.formattedSize, isNotEmpty);
    });

    test('returns StorageInfo with 0 files for empty directory', () async {
      final repo = _repo(MockFirebaseStorage(), authedUserId: 'alice');
      final info = await repo.getUserStorageInfo('alice');
      expect(info, isNotNull);
      expect(info!.fileCount, 0);
    });
  });

  group('compressImageBytes — small image short-circuits', () {
    test('returns bytes unchanged when below skipCompressionThreshold',
        () async {
      final repo = _repo(MockFirebaseStorage());
      // Use very small bytes — below threshold → returns unchanged without
      // touching FlutterImageCompress.
      final tiny = Uint8List.fromList(List.filled(100, 42));
      final result = await repo.compressImageBytes(tiny);
      expect(result.length, tiny.length);
      expect(result, tiny);
    });
  });
}
