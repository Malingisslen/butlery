/// Integration-style test for FirebaseStorageRepository's Cache-Control
/// pass-through (BUT-410 heirloom scans).
///
/// Uses the in-memory `firebase_storage_mocks` fake so we can inspect the
/// SettableMetadata that was written without hitting a real bucket.
@Tags(['integration'])
library;

import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:firebase_storage_mocks/firebase_storage_mocks.dart';
import 'package:butlery/repositories/firebase/firebase_storage_repository.dart';
import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseStorageRepository cache-control', () {
    late FirebaseStorageRepository repository;
    late MockFirebaseStorage mockStorage;
    late MockUuid mockUuid;
    late MockAuthRepository mockAuthRepository;

    const testUserId = 'test-user-heir';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      mockStorage = MockFirebaseStorage();
      mockUuid = MockUuid();
      mockAuthRepository = MockAuthRepository();

      mockAuthRepository.setAuthState(
        user: FakeUser(uid: testUserId),
        userId: testUserId,
        isAuthenticated: true,
      );

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

    test('uploadImageData forwards cacheControl into SettableMetadata',
        () async {
      final bytes = Uint8List.fromList(List.filled(16, 1));
      const path = 'users/$testUserId/recipes/r1/heirloom/deadbeefcafef00d.jpg';
      const cacheControl = 'public, max-age=31536000, immutable';

      final url = await repository.uploadImageData(
        imageData: bytes,
        userId: testUserId,
        path: path,
        cacheControl: cacheControl,
      );

      expect(url, isNotNull, reason: 'Upload should succeed');

      final storedKey = mockStorage.storedSettableMetadataMap.keys
          .firstWhere((k) => k.endsWith(path));
      final stored = mockStorage.storedSettableMetadataMap[storedKey];
      expect(stored, isNotNull);
      expect(stored!['cacheControl'], cacheControl);
    });

    test('uploadImageData without cacheControl stores null (legacy behavior)',
        () async {
      final bytes = Uint8List.fromList(List.filled(16, 2));
      const path = 'users/$testUserId/recipes/r2/images/normal.jpg';

      await repository.uploadImageData(
        imageData: bytes,
        userId: testUserId,
        path: path,
      );

      final storedKey = mockStorage.storedSettableMetadataMap.keys
          .firstWhere((k) => k.endsWith(path));
      final stored = mockStorage.storedSettableMetadataMap[storedKey];
      expect(stored, isNotNull);
      // When the caller doesn't opt in, the header is absent (null) — ordinary
      // recipe images keep their current CDN defaults.
      expect(stored!['cacheControl'], isNull);
    });
  });
}
