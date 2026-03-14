import 'package:flutter_test/flutter_test.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';

import 'package:butlery/repositories/firebase/firebase_social_sharing_repository.dart';
import 'package:butlery/models/shared_content.dart';

import '../../test_support/base_unit_test.dart';
import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  group('FirebaseSocialSharingRepository - Permission Validation', () {
    late FirebaseSocialSharingRepository repository;
    late FakeFirebaseFirestore fakeFirestore;
    late MockFirebaseAuthRepository mockAuthRepo;

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() async {
      await TestServiceLocator.initialize();

      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepo = MockFirebaseAuthRepository();
      mockAuthRepo.setAuthState(userId: 'current-user');

      repository = FirebaseSocialSharingRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepo,
      );
    });

    tearDown(() async {
      BaseUnitTest.resetMocks();
      await TestServiceLocator.reset();
    });

    tearDownAll(() async {
      await BaseUnitTest.teardownUnit();
    });

    SharedContent createSharedContent({
      String id = 'share-1',
      String ownerId = 'owner-user',
      List<String> sharedWithUserIds = const [],
      List<String> sharedWithGroupIds = const [],
    }) {
      return SharedContent(
        id: id,
        contentType: 'recipe',
        contentId: 'recipe-123',
        ownerId: ownerId,
        sharedWithUserIds: sharedWithUserIds,
        sharedWithGroupIds: sharedWithGroupIds,
        sharedAt: DateTime.now(),
        metadata: {},
        permissions: SharingPermissions.readOnly(),
      );
    }

    test('validateReadPermission grants access for group member (S6 fix)',
        () async {
      const ownerId = 'owner-user';
      const groupId = 'group-1';
      const memberUserId = 'group-member';

      // Set up group document under owner's friendCategories with member
      await fakeFirestore
          .collection('users')
          .doc(ownerId)
          .collection('friendCategories')
          .doc(groupId)
          .set({
        'name': 'Cooking Friends',
        'friendUserIds': [memberUserId, 'other-member'],
      });

      final content = createSharedContent(
        ownerId: ownerId,
        sharedWithGroupIds: [groupId],
      );

      // Validate that the group member has read access
      final hasAccess = await repository.validateReadPermission(
        memberUserId,
        content.id,
        content,
      );

      expect(hasAccess, isTrue);
    });

    test('validateReadPermission denies access for non-member', () async {
      const ownerId = 'owner-user';
      const groupId = 'group-1';
      const nonMemberUserId = 'outsider';

      // Set up group document with specific members (not including outsider)
      await fakeFirestore
          .collection('users')
          .doc(ownerId)
          .collection('friendCategories')
          .doc(groupId)
          .set({
        'name': 'Cooking Friends',
        'friendUserIds': ['member-1', 'member-2'],
      });

      final content = createSharedContent(
        ownerId: ownerId,
        sharedWithGroupIds: [groupId],
      );

      // Validate that a non-member is denied access
      final hasAccess = await repository.validateReadPermission(
        nonMemberUserId,
        content.id,
        content,
      );

      expect(hasAccess, isFalse);
    });

    test('owner always has access', () async {
      const ownerId = 'owner-user';

      final content = createSharedContent(
        ownerId: ownerId,
        // No explicit user or group sharing
      );

      // Owner should always have read access
      final hasAccess = await repository.validateReadPermission(
        ownerId,
        content.id,
        content,
      );

      expect(hasAccess, isTrue);
    });

    test('direct recipient has access', () async {
      const ownerId = 'owner-user';
      const recipientId = 'direct-recipient';

      final content = createSharedContent(
        ownerId: ownerId,
        sharedWithUserIds: [recipientId, 'another-recipient'],
      );

      // Direct recipient should have read access
      final hasAccess = await repository.validateReadPermission(
        recipientId,
        content.id,
        content,
      );

      expect(hasAccess, isTrue);

      // A user NOT in the recipient list should be denied
      final noAccess = await repository.validateReadPermission(
        'random-user',
        content.id,
        content,
      );

      expect(noAccess, isFalse);
    });
  });
}
