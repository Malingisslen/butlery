/// Unit tests for FirebaseBlockRepository.
///
/// Tests permission validation, block CRUD operations, and edge cases
/// for the user blocking system using composite-key documents.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/models/block_record.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseBlockRepository', () {
    late FirebaseBlockRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = FakeAuthRepository();
      mockAuthRepo.setAuthState(
        user: FakeUser(uid: 'user-123'),
        userId: 'user-123',
        isAuthenticated: true,
      );
      repository = FirebaseBlockRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Permission Validation', () {
      test('should grant create permission when blockerId matches userId',
          () async {
        // Arrange
        final record = BlockRecord.create(
          blockerId: 'user-123',
          blockedId: 'target-456',
        );

        // Act
        final result =
            await repository.validateCreatePermission('user-123', record);

        // Assert
        expect(result, isTrue);
      });

      test(
          'should reject create permission when blockerId does not match userId',
          () async {
        // Arrange
        final record = BlockRecord.create(
          blockerId: 'other-user',
          blockedId: 'target-456',
        );

        // Act
        final result =
            await repository.validateCreatePermission('user-123', record);

        // Assert
        expect(result, isFalse);
      });

      test('should always return false for update permission', () async {
        // Arrange
        final record = BlockRecord.create(
          blockerId: 'user-123',
          blockedId: 'target-456',
        );

        // Act
        final result = await repository.validateUpdatePermission(
          'user-123',
          record.id,
          record,
        );

        // Assert
        expect(result, isFalse);
      });

      test(
          'should grant delete permission when blockerId matches in composite ID',
          () async {
        // Arrange
        final compositeId = BlockRecord.compositeId('user-123', 'target-456');

        // Act
        final result =
            await repository.validateDeletePermission('user-123', compositeId);

        // Assert
        expect(result, isTrue);
      });

      test(
          'should reject delete permission when blockerId does not match in composite ID',
          () async {
        // Arrange
        final compositeId = BlockRecord.compositeId('other-user', 'target-456');

        // Act
        final result =
            await repository.validateDeletePermission('user-123', compositeId);

        // Assert
        expect(result, isFalse);
      });
    });

    group('Block CRUD Operations', () {
      test('should create doc with composite ID when blocking a user',
          () async {
        // Act
        await repository.blockUser('target-456');

        // Assert
        final expectedId = BlockRecord.compositeId('user-123', 'target-456');
        final doc =
            await fakeFirestore.collection('blocks').doc(expectedId).get();
        expect(doc.exists, isTrue);
      });

      test('should store correct fields when blocking a user', () async {
        // Act
        await repository.blockUser('target-456');

        // Assert
        final expectedId = BlockRecord.compositeId('user-123', 'target-456');
        final doc =
            await fakeFirestore.collection('blocks').doc(expectedId).get();
        final data = doc.data()!;

        expect(data['blockerId'], equals('user-123'));
        expect(data['blockedId'], equals('target-456'));
        expect(data['blockedAt'], isNotNull);
      });

      test('should delete the block doc when unblocking a user', () async {
        // Arrange
        await repository.blockUser('target-456');
        final expectedId = BlockRecord.compositeId('user-123', 'target-456');

        // Verify block exists
        var doc =
            await fakeFirestore.collection('blocks').doc(expectedId).get();
        expect(doc.exists, isTrue);

        // Act
        await repository.unblockUser('target-456');

        // Assert
        doc = await fakeFirestore.collection('blocks').doc(expectedId).get();
        expect(doc.exists, isFalse);
      });

      test('should return true for blocked user and false for unblocked',
          () async {
        // Arrange
        await repository.blockUser('target-456');

        // Act & Assert
        expect(await repository.isBlocked('target-456'), isTrue);
        expect(await repository.isBlocked('other-user'), isFalse);
      });

      test('should return true for isBlockedBy when reverse block exists',
          () async {
        // Arrange - create a block record where target blocks current user
        final reverseId = BlockRecord.compositeId('target-456', 'user-123');
        await fakeFirestore.collection('blocks').doc(reverseId).set({
          'blockerId': 'target-456',
          'blockedId': 'user-123',
          'blockedAt': DateTime.now().toIso8601String(),
        });

        // Act & Assert
        expect(await repository.isBlockedBy('target-456'), isTrue);
        expect(await repository.isBlockedBy('other-user'), isFalse);
      });

      test('should return correct set of blocked user IDs', () async {
        // Arrange
        await repository.blockUser('target-1');
        await repository.blockUser('target-2');
        await repository.blockUser('target-3');

        // Act
        final blockedIds = await repository.getBlockedUserIds();

        // Assert
        expect(blockedIds, equals({'target-1', 'target-2', 'target-3'}));
      });
    });

    group('Edge Cases', () {
      test(
          'should throw AuthenticationException when blocking while unauthenticated',
          () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );

        // Act & Assert
        expect(
          () => repository.blockUser('target-456'),
          throwsA(isA<AuthenticationException>()),
        );
      });

      test(
          'should delete all blocks in both directions for deleteAllBlocksForUser',
          () async {
        // Arrange - create blocks where user-123 is the blocker
        await repository.blockUser('target-1');
        await repository.blockUser('target-2');

        // Create blocks where user-123 is the blocked user
        final reverseId1 = BlockRecord.compositeId('other-1', 'user-123');
        final reverseId2 = BlockRecord.compositeId('other-2', 'user-123');
        await fakeFirestore.collection('blocks').doc(reverseId1).set({
          'blockerId': 'other-1',
          'blockedId': 'user-123',
          'blockedAt': DateTime.now().toIso8601String(),
        });
        await fakeFirestore.collection('blocks').doc(reverseId2).set({
          'blockerId': 'other-2',
          'blockedId': 'user-123',
          'blockedAt': DateTime.now().toIso8601String(),
        });

        // Act
        await repository.deleteAllBlocksForUser('user-123');

        // Assert - all blocks involving user-123 should be gone
        final snapshot = await fakeFirestore.collection('blocks').get();
        expect(snapshot.docs, isEmpty);
      });

      test(
          'should throw PermissionDeniedException when deleting blocks for another user',
          () async {
        // Act & Assert
        expect(
          () => repository.deleteAllBlocksForUser('other-user'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test(
          'should return empty set stream when unauthenticated for watchBlockedUserIds',
          () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: null,
          userId: null,
          isAuthenticated: false,
        );

        // Act
        final stream = repository.watchBlockedUserIds();

        // Assert
        expect(stream, emits(isEmpty));
      });
    });
  });
}
