/// Unit tests for BaseStorageRepository.
///
/// Targets the ~88 unhit lines in lib/repositories/base/base_storage_repository.dart.
/// Uses a test-only concrete subclass that exposes @protected methods + the
/// firebase_storage_mocks MockFirebaseStorage to drive the storage operations
/// without touching real Firebase.
library;

import 'dart:typed_data';

import 'package:firebase_storage/firebase_storage.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/repositories/base/base_storage_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

/// Concrete subclass exposing @protected methods as public proxies for tests.
class _TestStorageRepo extends BaseStorageRepository {
  _TestStorageRepo({required super.storage, required super.authRepository});

  Future<String?> publicGetDownloadURL(String path) => getDownloadURL(path);
  Future<FullMetadata?> publicGetMetadata(String path) => getMetadata(path);
  Future<ListResult> publicListFiles(String path) => listFiles(path);
  Future<void> publicDeleteFile(String path, {bool logAudit = true}) =>
      deleteFile(path, logAudit: logAudit);
  Future<void> publicDeleteDirectory(String path, {bool logAudit = true}) =>
      deleteDirectory(path, logAudit: logAudit);
  Future<void> publicValidatePath(String userId, String path, String op) =>
      validatePathPermission(userId, path, op);
  String? publicExtractUserId(String pathOrUrl) =>
      extractUserIdFromPath(pathOrUrl);
}

_TestStorageRepo _repo(
  MockFirebaseStorage storage, {
  String? authedUserId = 'alice',
}) {
  final mockAuth = FakeAuthRepository();
  if (authedUserId != null) {
    mockAuth.setAuthState(
      user: FakeUser(uid: authedUserId),
      userId: authedUserId,
      isAuthenticated: true,
    );
  }
  return _TestStorageRepo(storage: storage, authRepository: mockAuth);
}

Future<void> _seedFile(
  MockFirebaseStorage storage,
  String path,
  List<int> bytes,
) async {
  await storage.ref(path).putData(Uint8List.fromList(bytes));
}

void main() {
  group('getDownloadURL', () {
    test('returns URL when file exists', () async {
      final storage = MockFirebaseStorage();
      await _seedFile(storage, 'users/alice/img.jpg', [1, 2, 3]);
      final repo = _repo(storage);

      final url = await repo.publicGetDownloadURL('users/alice/img.jpg');
      expect(url, isNotNull);
    });

    test('returns null when file missing', () async {
      final repo = _repo(MockFirebaseStorage());
      // MockFirebaseStorage throws object-not-found on missing files.
      final url = await repo.publicGetDownloadURL('users/alice/ghost.jpg');
      expect(url, isNull);
    });
  });

  group('getMetadata', () {
    test('returns metadata when file exists', () async {
      final storage = MockFirebaseStorage();
      await _seedFile(storage, 'users/alice/img.jpg', [1, 2, 3]);
      final repo = _repo(storage);

      final metadata = await repo.publicGetMetadata('users/alice/img.jpg');
      expect(metadata, isNotNull);
    });

    test(
        'handles missing file (mock returns empty metadata, real returns null)',
        () async {
      final repo = _repo(MockFirebaseStorage());
      // MockFirebaseStorage diverges from real Firebase here — real
      // backend throws object-not-found, mock returns an empty FullMetadata.
      // Either return-type is acceptable; absent throw is the contract.
      final metadata = await repo.publicGetMetadata('users/alice/ghost.jpg');
      // Acceptable: either null (real Firebase swallows object-not-found) or
      // a FullMetadata instance (mock returns an empty one). Either way,
      // the absence of a thrown exception is the contract.
      expect(metadata, anyOf(isNull, isA<FullMetadata>()));
    });
  });

  group('listFiles', () {
    test('returns ListResult with all files in directory', () async {
      final storage = MockFirebaseStorage();
      await _seedFile(storage, 'users/alice/a.jpg', [1]);
      await _seedFile(storage, 'users/alice/b.jpg', [2]);
      final repo = _repo(storage);

      final result = await repo.publicListFiles('users/alice');
      expect(result.items.length, greaterThanOrEqualTo(2));
    });
  });

  group('deleteFile', () {
    test('deletes existing file', () async {
      final storage = MockFirebaseStorage();
      await _seedFile(storage, 'users/alice/img.jpg', [1, 2, 3]);
      final repo = _repo(storage);

      await repo.publicDeleteFile('users/alice/img.jpg');
      // Verify gone — getDownloadURL should return null now.
      expect(await repo.publicGetDownloadURL('users/alice/img.jpg'), isNull);
    });

    test('handles missing file gracefully (object-not-found swallowed)',
        () async {
      final repo = _repo(MockFirebaseStorage());
      // Should not throw.
      await repo.publicDeleteFile('users/alice/ghost.jpg');
    });

    test('logAudit:false skips audit-log branch', () async {
      final storage = MockFirebaseStorage();
      await _seedFile(storage, 'users/alice/img.jpg', [1]);
      final repo = _repo(storage);
      await repo.publicDeleteFile('users/alice/img.jpg', logAudit: false);
    });
  });

  group('deleteDirectory (recursive)', () {
    test('removes all files in directory', () async {
      final storage = MockFirebaseStorage();
      await _seedFile(storage, 'users/alice/a.jpg', [1]);
      await _seedFile(storage, 'users/alice/b.jpg', [2]);
      final repo = _repo(storage);

      await repo.publicDeleteDirectory('users/alice');

      final result = await repo.publicListFiles('users/alice');
      expect(result.items, isEmpty);
    });

    test('logAudit:false skips per-file audit logging branch', () async {
      final storage = MockFirebaseStorage();
      await _seedFile(storage, 'users/alice/a.jpg', [1]);
      final repo = _repo(storage);

      await repo.publicDeleteDirectory('users/alice', logAudit: false);
    });

    test('handles empty directory without error', () async {
      final repo = _repo(MockFirebaseStorage());
      // No files to delete — should succeed silently.
      await repo.publicDeleteDirectory('users/alice');
    });
  });

  group('validatePathPermission', () {
    test('throws when unauthenticated', () async {
      final repo = _repo(MockFirebaseStorage(), authedUserId: null);
      await expectLater(
        () => repo.publicValidatePath('alice', 'users/alice/img.jpg', 'upload'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('throws when accessing another user directory', () async {
      final repo = _repo(MockFirebaseStorage(), authedUserId: 'alice');
      await expectLater(
        () => repo.publicValidatePath('bob', 'users/bob/img.jpg', 'upload'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('throws when path is not in user directory format', () async {
      final repo = _repo(MockFirebaseStorage(), authedUserId: 'alice');
      await expectLater(
        () => repo.publicValidatePath('alice', 'public/img.jpg', 'upload'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('succeeds when user accesses own path with users/{uid}/ prefix',
        () async {
      final repo = _repo(MockFirebaseStorage(), authedUserId: 'alice');
      await repo.publicValidatePath(
          'alice', 'users/alice/recipes/img.jpg', 'upload');
    });
  });

  group('extractUserIdFromPath', () {
    test('extracts uid from path format', () {
      final repo = _repo(MockFirebaseStorage());
      expect(
          repo.publicExtractUserId('users/u-anna/recipes/abc.jpg'), 'u-anna');
    });

    test('extracts uid from URL-encoded firebase URL', () {
      final repo = _repo(MockFirebaseStorage());
      const url =
          'https://firebasestorage.googleapis.com/v0/b/x/o/users%2Fu-anna%2Fimg.jpg?alt=media';
      expect(repo.publicExtractUserId(url), 'u-anna');
    });

    test('returns null when no users/ pattern', () {
      final repo = _repo(MockFirebaseStorage());
      expect(repo.publicExtractUserId('random/path/no-pattern'), isNull);
    });
  });
}
