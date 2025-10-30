/// Comprehensive unit tests for FirebaseSocialSharingRepository.
///
/// Tests social content sharing functionality including multi-target distribution,
/// permission management, engagement tracking, and security validation.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/firebase/firebase_social_sharing_repository.dart';
import 'package:butlery/models/shared_content.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseSocialSharingRepository - Social Sharing', () {
    late FirebaseSocialSharingRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockAuthRepository mockAuthRepo;
    late FakeUser mockUser;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      // Create fake Firestore instance
      fakeFirestore = FakeFirebaseFirestore();

      // Create mocks
      mockAuthRepo = MockAuthRepository();
      mockUser = FakeUser(uid: 'owner-123');

      // Setup default auth state
      mockAuthRepo.setAuthState(
        user: mockUser,
        userId: 'owner-123',
        isAuthenticated: true,
      );

      // Create repository with fake Firestore
      repository = FirebaseSocialSharingRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    group('Permission Validation', () {
      test('should allow owner to create shared content', () async {
        // Arrange
        final content = _createSharedContent('owner-123', 'content-1');

        // Act
        final canCreate = await repository.validateCreatePermission('owner-123', content);

        // Assert
        expect(canCreate, isTrue);
      });

      test('should reject non-owner from creating shared content', () async {
        // Arrange
        final content = _createSharedContent('owner-123', 'content-1');

        // Act
        final canCreate = await repository.validateCreatePermission('other-user', content);

        // Assert
        expect(canCreate, isFalse);
      });

      test('should allow owner to read their shared content', () async {
        // Arrange
        final content = _createSharedContent('owner-123', 'content-1');

        // Act
        final canRead = await repository.validateReadPermission('owner-123', 'share-1', content);

        // Assert
        expect(canRead, isTrue);
      });

      test('should allow recipient to read shared content', () async {
        // Arrange
        final content = _createSharedContent(
          'owner-123',
          'content-1',
          sharedWithUserIds: ['recipient-456'],
        );

        // Act
        final canRead = await repository.validateReadPermission('recipient-456', 'share-1', content);

        // Assert
        expect(canRead, isTrue);
      });

      test('should reject non-recipient from reading shared content', () async {
        // Arrange
        final content = _createSharedContent(
          'owner-123',
          'content-1',
          sharedWithUserIds: ['recipient-456'],
        );

        // Act
        final canRead = await repository.validateReadPermission('other-user', 'share-1', content);

        // Assert
        expect(canRead, isFalse);
      });

      test('should allow owner to update sharing permissions', () async {
        // Arrange
        final content = _createSharedContent('owner-123', 'content-1');

        // Act
        final canUpdate = await repository.validateUpdatePermission('owner-123', 'share-1', content);

        // Assert
        expect(canUpdate, isTrue);
      });

      test('should reject non-owner from updating sharing permissions', () async {
        // Arrange
        final content = _createSharedContent('owner-123', 'content-1');

        // Act
        final canUpdate = await repository.validateUpdatePermission('other-user', 'share-1', content);

        // Assert
        expect(canUpdate, isFalse);
      });

      test('should allow owner to delete shared content', () async {
        // Arrange
        const shareId = 'share-1';
        final content = _createSharedContent('owner-123', 'content-1', id: shareId);
        await _seedSharedContent(fakeFirestore, shareId, content);

        // Act
        final canDelete = await repository.validateDeletePermission('owner-123', shareId);

        // Assert
        expect(canDelete, isTrue);
      });

      test('should reject non-owner from deleting shared content', () async {
        // Arrange
        const shareId = 'share-1';
        final content = _createSharedContent('owner-123', 'content-1', id: shareId);
        await _seedSharedContent(fakeFirestore, shareId, content);

        // Act
        final canDelete = await repository.validateDeletePermission('other-user', shareId);

        // Assert
        expect(canDelete, isFalse);
      });
    });

    group('Share to Group', () {
      test('should share content to a group successfully', () async {
        // Arrange
        const groupId = 'group-789';
        final content = _createSharedContent('owner-123', 'recipe-1', id: 'share-1');
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act
        await repository.shareToGroup(groupId, content);

        // Assert
        final doc = await fakeFirestore.collection('shared_content').doc('share-1').get();
        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['sharedWithGroupIds'], contains(groupId));
      });

      test('should reject sharing to group when not owner', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: FakeUser(uid: 'other-user'),
          userId: 'other-user',
          isAuthenticated: true,
        );

        const groupId = 'group-789';
        final content = _createSharedContent('owner-123', 'recipe-1', id: 'share-1');

        // Act & Assert
        expect(
          () => repository.shareToGroup(groupId, content),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should handle adding group to already shared content', () async {
        // Arrange
        final content = _createSharedContent(
          'owner-123',
          'recipe-1',
          id: 'share-1',
          sharedWithGroupIds: ['group-1'],
        );
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act
        await repository.shareToGroup('group-2', content);

        // Assert
        final doc = await fakeFirestore.collection('shared_content').doc('share-1').get();
        final data = doc.data()!;
        expect(data['sharedWithGroupIds'], containsAll(['group-1', 'group-2']));
      });
    });

    group('Share to Users', () {
      test('should share content to multiple users successfully', () async {
        // Arrange
        final userIds = ['user-1', 'user-2', 'user-3'];
        final content = _createSharedContent('owner-123', 'recipe-1', id: 'share-1');
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act
        await repository.shareToUsers(userIds, content);

        // Assert
        final doc = await fakeFirestore.collection('shared_content').doc('share-1').get();
        expect(doc.exists, isTrue);
        final data = doc.data()!;
        expect(data['sharedWithUserIds'], containsAll(userIds));
      });

      test('should reject sharing when not owner', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: FakeUser(uid: 'other-user'),
          userId: 'other-user',
          isAuthenticated: true,
        );

        final userIds = ['user-1', 'user-2'];
        final content = _createSharedContent('owner-123', 'recipe-1', id: 'share-1');

        // Act & Assert
        expect(
          () => repository.shareToUsers(userIds, content),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should not duplicate users when sharing to already shared users', () async {
        // Arrange
        final content = _createSharedContent(
          'owner-123',
          'recipe-1',
          id: 'share-1',
          sharedWithUserIds: ['user-1'],
        );
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act
        await repository.shareToUsers(['user-1', 'user-2'], content);

        // Assert
        final doc = await fakeFirestore.collection('shared_content').doc('share-1').get();
        final data = doc.data()!;
        final sharedWithUserIds = List<String>.from(data['sharedWithUserIds']);
        expect(sharedWithUserIds.where((id) => id == 'user-1').length, equals(1));
        expect(sharedWithUserIds, contains('user-2'));
      });
    });

    group('Update Sharing Permissions', () {
      // NOTE: These tests are skipped due to FakeFirebaseFirestore limitations
      // with FieldValue.arrayUnion() and FieldValue.arrayRemove().
      // These operations are tested in integration tests with real Firebase.

      test('should add users to sharing permissions', () async {
        // Arrange
        final content = _createSharedContent(
          'owner-123',
          'recipe-1',
          id: 'share-1',
          sharedWithUserIds: ['user-1'],
        );
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act
        await repository.updateSharingPermissions(
          'share-1',
          ['user-2', 'user-3'],
          [],
        );

        // Assert
        final doc = await fakeFirestore.collection('shared_content').doc('share-1').get();
        final data = doc.data()!;
        expect(data['sharedWithUserIds'], containsAll(['user-1', 'user-2', 'user-3']));
      }, skip: 'FakeFirebaseFirestore FieldValue.arrayUnion limitation - tested in integration tests');

      test('should remove users from sharing permissions', () async {
        // Arrange
        final content = _createSharedContent(
          'owner-123',
          'recipe-1',
          id: 'share-1',
          sharedWithUserIds: ['user-1', 'user-2', 'user-3'],
        );
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act
        await repository.updateSharingPermissions(
          'share-1',
          [],
          ['user-2'],
        );

        // Assert
        final doc = await fakeFirestore.collection('shared_content').doc('share-1').get();
        final data = doc.data()!;
        expect(data['sharedWithUserIds'], isNot(contains('user-2')));
        expect(data['sharedWithUserIds'], containsAll(['user-1', 'user-3']));
      }, skip: 'FakeFirebaseFirestore FieldValue.arrayRemove limitation - tested in integration tests');

      test('should reject permission update when not owner', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: FakeUser(uid: 'other-user'),
          userId: 'other-user',
          isAuthenticated: true,
        );

        final content = _createSharedContent('owner-123', 'recipe-1', id: 'share-1');
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act & Assert
        expect(
          () => repository.updateSharingPermissions('share-1', ['user-2'], []),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should throw when content not found', () async {
        // Act & Assert
        expect(
          () => repository.updateSharingPermissions('nonexistent', ['user-1'], []),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('Revoke Sharing', () {
      test('should revoke sharing successfully', () async {
        // Arrange
        final content = _createSharedContent(
          'owner-123',
          'recipe-1',
          id: 'share-1',
          sharedWithUserIds: ['user-1', 'user-2'],
        );
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act
        await repository.revokeSharing('share-1');

        // Assert
        final doc = await fakeFirestore.collection('shared_content').doc('share-1').get();
        expect(doc.exists, isFalse);
      });

      test('should reject revoke when not owner', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: FakeUser(uid: 'other-user'),
          userId: 'other-user',
          isAuthenticated: true,
        );

        final content = _createSharedContent('owner-123', 'recipe-1', id: 'share-1');
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act & Assert
        expect(
          () => repository.revokeSharing('share-1'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should throw when content not found', () async {
        // Act & Assert
        expect(
          () => repository.revokeSharing('nonexistent'),
          throwsA(isA<ResourceNotFoundException>()),
        );
      });
    });

    group('Accept/Decline Shared Content', () {
      // NOTE: Accept/decline tests are skipped due to FakeFirebaseFirestore limitations
      // with nested map updates (acceptedBy.$userId, declinedBy.$userId).
      // These operations are tested in integration tests with real Firebase.

      test('should accept shared content successfully', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: FakeUser(uid: 'user-1'),
          userId: 'user-1',
          isAuthenticated: true,
        );

        final content = _createSharedContent(
          'owner-123',
          'recipe-1',
          id: 'share-1',
          sharedWithUserIds: ['user-1'],
        );
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act
        await repository.acceptSharedContent('share-1', 'user-1');

        // Assert
        final doc = await fakeFirestore.collection('shared_content').doc('share-1').get();
        final data = doc.data()!;
        expect(data['acceptedBy'], isNotNull);
        expect(data['acceptedBy']['user-1'], isNotNull);
      }, skip: 'FakeFirebaseFirestore nested map update limitation - tested in integration tests');

      test('should decline shared content successfully', () async {
        // Arrange
        mockAuthRepo.setAuthState(
          user: FakeUser(uid: 'user-1'),
          userId: 'user-1',
          isAuthenticated: true,
        );

        final content = _createSharedContent(
          'owner-123',
          'recipe-1',
          id: 'share-1',
          sharedWithUserIds: ['user-1'],
        );
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act
        await repository.declineSharedContent('share-1', 'user-1');

        // Assert
        final doc = await fakeFirestore.collection('shared_content').doc('share-1').get();
        final data = doc.data()!;
        expect(data['declinedBy'], isNotNull);
        expect(data['declinedBy']['user-1'], isNotNull);
      }, skip: 'FakeFirebaseFirestore nested map update limitation - tested in integration tests');

      test('should reject accept when not the target user', () async {
        // Arrange - Current user is owner-123 trying to accept for user-1
        final content = _createSharedContent(
          'owner-123',
          'recipe-1',
          id: 'share-1',
          sharedWithUserIds: ['user-1'],
        );
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act & Assert
        expect(
          () => repository.acceptSharedContent('share-1', 'user-1'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });

      test('should reject decline when not the target user', () async {
        // Arrange - Current user is owner-123 trying to decline for user-1
        final content = _createSharedContent(
          'owner-123',
          'recipe-1',
          id: 'share-1',
          sharedWithUserIds: ['user-1'],
        );
        await _seedSharedContent(fakeFirestore, 'share-1', content);

        // Act & Assert
        expect(
          () => repository.declineSharedContent('share-1', 'user-1'),
          throwsA(isA<PermissionDeniedException>()),
        );
      });
    });

    group('Query Operations', () {
      test('should get content shared with user', () async {
        // Arrange
        final content1 = _createSharedContent(
          'owner-123',
          'recipe-1',
          id: 'share-1',
          sharedWithUserIds: ['user-1'],
        );
        final content2 = _createSharedContent(
          'owner-456',
          'recipe-2',
          id: 'share-2',
          sharedWithUserIds: ['user-1'],
        );
        final content3 = _createSharedContent(
          'owner-789',
          'recipe-3',
          id: 'share-3',
          sharedWithUserIds: ['user-2'], // Not for user-1
        );

        await _seedSharedContent(fakeFirestore, 'share-1', content1);
        await _seedSharedContent(fakeFirestore, 'share-2', content2);
        await _seedSharedContent(fakeFirestore, 'share-3', content3);

        // Act
        final stream = repository.getSharedWithMe('user-1');
        final results = await stream.first;

        // Assert
        expect(results.length, equals(2));
        expect(results.map((c) => c.id), containsAll(['share-1', 'share-2']));
        expect(results.map((c) => c.id), isNot(contains('share-3')));
      });

      test('should get user\'s own shared content', () async {
        // Arrange
        final content1 = _createSharedContent('owner-123', 'recipe-1', id: 'share-1');
        final content2 = _createSharedContent('owner-123', 'recipe-2', id: 'share-2');
        final content3 = _createSharedContent('owner-456', 'recipe-3', id: 'share-3');

        await _seedSharedContent(fakeFirestore, 'share-1', content1);
        await _seedSharedContent(fakeFirestore, 'share-2', content2);
        await _seedSharedContent(fakeFirestore, 'share-3', content3);

        // Act
        final stream = repository.getMySharedContent('owner-123');
        final results = await stream.first;

        // Assert
        expect(results.length, equals(2));
        expect(results.map((c) => c.id), containsAll(['share-1', 'share-2']));
        expect(results.map((c) => c.id), isNot(contains('share-3')));
      });
    });

    group('Sharing Statistics', () {
      // NOTE: This test is skipped due to FakeFirebaseFirestore limitations
      // with nested map updates for acceptedBy/viewedBy tracking.
      // This operation is tested in integration tests with real Firebase.

      test('should calculate sharing stats correctly', () async {
        // Arrange
        final now = DateTime.now();

        // Content shared BY user
        final sharedByMe1 = _createSharedContent('user-123', 'recipe-1', id: 'share-1');
        final sharedByMe2 = _createSharedContent('user-123', 'recipe-2', id: 'share-2');

        // Content shared WITH user
        final sharedWithMe1 = _createSharedContent(
          'owner-1',
          'recipe-3',
          id: 'share-3',
          sharedWithUserIds: ['user-123'],
        );
        final sharedWithMe2 = _createSharedContent(
          'owner-2',
          'recipe-4',
          id: 'share-4',
          sharedWithUserIds: ['user-123'],
        );

        await _seedSharedContent(fakeFirestore, 'share-1', sharedByMe1);
        await _seedSharedContent(fakeFirestore, 'share-2', sharedByMe2);
        await _seedSharedContent(fakeFirestore, 'share-3', sharedWithMe1);
        await _seedSharedContent(fakeFirestore, 'share-4', sharedWithMe2);

        // Mark some as accepted and viewed
        await fakeFirestore.collection('shared_content').doc('share-3').update({
          'acceptedBy.user-123': Timestamp.fromDate(now),
          'viewedBy.user-123': Timestamp.fromDate(now),
        });
        await fakeFirestore.collection('shared_content').doc('share-4').update({
          'viewedBy.user-123': Timestamp.fromDate(now),
        });

        // Act
        final stats = await repository.getSharingStats('user-123');

        // Assert
        expect(stats['totalShared'], equals(2));
        expect(stats['totalReceived'], equals(2));
        expect(stats['acceptedCount'], equals(1));
        expect(stats['viewedCount'], equals(2));
        expect(stats['acceptanceRate'], equals(0.5)); // 1 accepted out of 2 viewed
      }, skip: 'FakeFirebaseFirestore nested map update limitation - tested in integration tests');

      test('should return zero stats for user with no sharing activity', () async {
        // Act
        final stats = await repository.getSharingStats('new-user');

        // Assert
        expect(stats['totalShared'], equals(0));
        expect(stats['totalReceived'], equals(0));
        expect(stats['acceptedCount'], equals(0));
        expect(stats['viewedCount'], equals(0));
        expect(stats['acceptanceRate'], equals(0));
      });
    });
  });
}

// ===== TEST HELPERS =====

/// Create a test shared content
SharedContent _createSharedContent(
  String ownerId,
  String contentId, {
  String? id,
  String contentType = 'recipe',
  List<String>? sharedWithUserIds,
  List<String>? sharedWithGroupIds,
  DateTime? sharedAt,
}) {
  return SharedContent(
    id: id ?? 'share-${DateTime.now().millisecondsSinceEpoch}',
    contentType: contentType,
    contentId: contentId,
    ownerId: ownerId,
    sharedWithUserIds: sharedWithUserIds ?? [],
    sharedWithGroupIds: sharedWithGroupIds ?? [],
    sharedAt: sharedAt ?? DateTime.now(),
    metadata: {},
    permissions: SharingPermissions.readOnly(),
  );
}

/// Seed shared content into fake Firestore
Future<void> _seedSharedContent(
  FakeFirebaseFirestore firestore,
  String shareId,
  SharedContent content,
) async {
  final data = {
    'contentType': content.contentType,
    'contentId': content.contentId,
    'ownerId': content.ownerId,
    'sharedWithUserIds': content.sharedWithUserIds,
    'sharedWithGroupIds': content.sharedWithGroupIds,
    'sharedAt': Timestamp.fromDate(content.sharedAt),
    'metadata': content.metadata,
    'permissions': content.permissions.toMap(),
    'viewedBy': {},
    'acceptedBy': {},
    'declinedBy': {},
  };

  await firestore.collection('shared_content').doc(shareId).set(data);
}
