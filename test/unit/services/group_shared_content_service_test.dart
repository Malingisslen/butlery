import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import '../../infrastructure/factories/social_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late MockPermissionService mockPermissionService;
  late GroupSharedContentService service;

  const ownerId = 'owner-123';
  const friend1Id = 'friend-1';
  const friend2Id = 'friend-2';

  Future<void> addSharedRecipe({
    required String id,
    required String sharedByUserId,
    required String recipeTitle,
    required List<String> sharedToUserIds,
    DateTime? sharedAt,
  }) async {
    await fakeFirestore
        .collection(FirestoreCollections.sharedContent)
        .doc(id)
        .set({
      'sharedByUserId': sharedByUserId,
      'sharedByDisplayName': 'Test User',
      'recipeTitle': recipeTitle,
      'originalRecipeId': 'original-$id',
      'sharedToUserIds': sharedToUserIds,
      'sharedAt': Timestamp.fromDate(sharedAt ?? DateTime(2026, 3, 1)),
    });
  }

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    mockPermissionService = MockPermissionService();
    mockPermissionService.setPermissionState(
      currentUserId: ownerId,
      isAuthenticated: true,
    );
    service = GroupSharedContentService(
      firestore: fakeFirestore,
      permissionService: mockPermissionService,
    );
  });

  group('getSharedRecipes', () {
    test('queries sharedToUserIds with owner and all member IDs', () async {
      final group = SocialFactory.createFriendCategory(
        createdBy: ownerId,
        memberIds: [friend1Id, friend2Id],
      );

      await addSharedRecipe(
        id: 'recipe-1',
        sharedByUserId: friend1Id,
        recipeTitle: 'Köttbullar',
        sharedToUserIds: [friend1Id, ownerId],
      );

      final result = await service.getSharedRecipes(group);

      expect(result, hasLength(1));
      expect(result[0].type, equals('recipe'));
      expect(result[0].title, equals('Köttbullar'));
      expect(result[0].sharedByUserId, equals(friend1Id));
    });

    test('returns SharedContentItem with correct display fields', () async {
      final group = SocialFactory.createFriendCategory(
        createdBy: ownerId,
        memberIds: [friend1Id],
      );

      await addSharedRecipe(
        id: 'recipe-2',
        sharedByUserId: ownerId,
        recipeTitle: 'Pannkakor',
        sharedToUserIds: [ownerId, friend1Id],
        sharedAt: DateTime(2026, 2, 15),
      );

      final result = await service.getSharedRecipes(group);

      expect(result, hasLength(1));
      expect(result[0].id, equals('recipe-2'));
      expect(result[0].sharedByDisplayName, equals('Test User'));
    });

    test('returns empty list when currentUserId is null', () async {
      mockPermissionService.setPermissionState(
        currentUserId: null,
        isAuthenticated: false,
      );
      final group = SocialFactory.createFriendCategory(
        createdBy: ownerId,
        memberIds: [friend1Id],
      );

      await addSharedRecipe(
        id: 'recipe-3',
        sharedByUserId: ownerId,
        recipeTitle: 'Pasta',
        sharedToUserIds: [ownerId, friend1Id],
      );

      final result = await service.getSharedRecipes(group);

      expect(result, isEmpty);
    });

    test('handles empty group with only owner', () async {
      final group = SocialFactory.createFriendCategory(
        createdBy: ownerId,
      );

      await addSharedRecipe(
        id: 'recipe-4',
        sharedByUserId: ownerId,
        recipeTitle: 'Soppa',
        sharedToUserIds: [ownerId],
      );

      final result = await service.getSharedRecipes(group);

      expect(result, hasLength(1));
      expect(result[0].title, equals('Soppa'));
    });

    test('does not return recipes shared with non-group members', () async {
      final group = SocialFactory.createFriendCategory(
        createdBy: ownerId,
        memberIds: [friend1Id],
      );

      await addSharedRecipe(
        id: 'recipe-5',
        sharedByUserId: 'stranger',
        recipeTitle: 'Secret Recipe',
        sharedToUserIds: ['stranger', 'other-user'],
      );

      final result = await service.getSharedRecipes(group);

      expect(result, isEmpty);
    });

    test('returns multiple recipes sorted by sharedAt descending', () async {
      final group = SocialFactory.createFriendCategory(
        createdBy: ownerId,
        memberIds: [friend1Id],
      );

      await addSharedRecipe(
        id: 'older',
        sharedByUserId: ownerId,
        recipeTitle: 'Older Recipe',
        sharedToUserIds: [ownerId, friend1Id],
        sharedAt: DateTime(2026, 1, 1),
      );

      await addSharedRecipe(
        id: 'newer',
        sharedByUserId: friend1Id,
        recipeTitle: 'Newer Recipe',
        sharedToUserIds: [friend1Id, ownerId],
        sharedAt: DateTime(2026, 3, 1),
      );

      final result = await service.getSharedRecipes(group);

      expect(result, hasLength(2));
      expect(result[0].title, equals('Newer Recipe'));
      expect(result[1].title, equals('Older Recipe'));
    });
  });

  group('streamSharedRecipes', () {
    test('includes group owner in allMemberIds', () async {
      final group = SocialFactory.createFriendCategory(
        createdBy: ownerId,
        memberIds: [friend1Id],
      );

      await addSharedRecipe(
        id: 'recipe-stream-1',
        sharedByUserId: friend1Id,
        recipeTitle: 'Streamed Recipe',
        sharedToUserIds: [ownerId],
      );

      final stream = service.streamSharedRecipes(group);
      final result = await stream.first;

      expect(result, hasLength(1));
      expect(result[0].title, equals('Streamed Recipe'));
    });

    test('returns empty stream when userId is null', () async {
      mockPermissionService.setPermissionState(
        currentUserId: null,
        isAuthenticated: false,
      );
      final group = SocialFactory.createFriendCategory(
        createdBy: ownerId,
        memberIds: [friend1Id],
      );

      final stream = service.streamSharedRecipes(group);
      final result = await stream.first;

      expect(result, isEmpty);
    });

    test('initially emits empty list when no recipes exist', () async {
      final group = SocialFactory.createFriendCategory(
        createdBy: ownerId,
        memberIds: [friend1Id],
      );

      final stream = service.streamSharedRecipes(group);

      await expectLater(
        stream,
        emitsInOrder([isEmpty]),
      );
    });
  });
}
