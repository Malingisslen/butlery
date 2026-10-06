import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/group_shared_content_service.dart';
import 'package:butlery/repositories/firebase/firebase_group_shared_content_repository.dart';
import 'package:butlery/core/constants/firestore_collections.dart';
import '../../infrastructure/factories/social_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

// BUT-2271: the group page shows what was shared WITH THIS GROUP and that the
// viewer can read. The query is on the viewer's own uid (the only shape the
// `shared_content` list rule can prove) and the group is matched on
// `groupIds`. fake_cloud_firestore does not enforce rules, so these tests pin
// the selection; the rules side is the existing list-rule suite.
void main() {
  late FakeFirebaseFirestore fakeFirestore;
  late FakePermissionService permissionService;
  late GroupSharedContentService service;

  const viewerId = 'viewer-1';
  const friendId = 'friend-1';
  const groupId = 'group-1';

  Future<void> addShare({
    required String id,
    String contentType = 'recipe',
    String sharedByUserId = friendId,
    List<String> sharedToUserIds = const [friendId, viewerId],
    List<String>? groupIds = const [groupId],
    DateTime? sharedAt,
  }) async {
    await fakeFirestore
        .collection(FirestoreCollections.sharedContent)
        .doc(id)
        .set({
          'contentType': contentType,
          'sharedByUserId': sharedByUserId,
          'sharedByDisplayName': 'Anna',
          'recipeTitle': 'Recept $id',
          'sharedToUserIds': sharedToUserIds,
          'groupIds': ?groupIds,
          'sharedAt': Timestamp.fromDate(sharedAt ?? DateTime(2026, 10, 1)),
        });
  }

  final group = SocialFactory.createFriendCategory(
    id: groupId,
    createdBy: friendId,
    memberIds: [viewerId],
  );

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    permissionService = FakePermissionService()
      ..setPermissionState(currentUserId: viewerId, isAuthenticated: true);
    service = GroupSharedContentService(
      repository: FirebaseGroupSharedContentRepository(
        firestore: fakeFirestore,
      ),
      permissionService: permissionService,
    );
  });

  test('shows a recipe shared with the group', () async {
    await addShare(id: 'r1');

    final result = await service.getSharedRecipes(group);

    expect(result.map((i) => i.id), ['r1']);
    expect(result.single.title, 'Recept r1');
    expect(result.single.sharedByDisplayName, 'Anna');
  });

  test(
    'a private share between two members is NOT shown on the group page',
    () async {
      await addShare(id: 'private', groupIds: null);
      await addShare(id: 'other-group', groupIds: const ['group-2']);

      expect(await service.getSharedRecipes(group), isEmpty);
    },
  );

  test('a group share the viewer is not a recipient of is not shown', () async {
    await addShare(id: 'not-mine', sharedToUserIds: const [friendId]);

    expect(await service.getSharedRecipes(group), isEmpty);
  });

  test('each tab gets only its own content type, newest first', () async {
    await addShare(id: 'old', sharedAt: DateTime(2026, 9, 1));
    await addShare(id: 'new', sharedAt: DateTime(2026, 10, 2));
    await addShare(id: 'menu', contentType: 'menu');
    await addShare(id: 'list', contentType: 'shopping_list');

    expect((await service.getSharedRecipes(group)).map((i) => i.id), [
      'new',
      'old',
    ]);
    expect((await service.getSharedMenus(group)).map((i) => i.id), ['menu']);
    expect((await service.getSharedShoppingLists(group)).map((i) => i.id), [
      'list',
    ]);
  });

  test(
    'a shared shopping list is titled by the listName it is written with',
    () async {
      await fakeFirestore
          .collection(FirestoreCollections.sharedContent)
          .doc('l1')
          .set({
            'contentType': 'shopping_list',
            'sharedByUserId': friendId,
            'listName': 'Inköpslista v.41',
            'sharedToUserIds': const [friendId, viewerId],
            'groupIds': const [groupId],
            'sharedAt': Timestamp.fromDate(DateTime(2026, 10, 1)),
          });

      final lists = await service.getSharedShoppingLists(group);

      expect(lists.single.title, 'Inköpslista v.41');
    },
  );

  test('signed out: nothing', () async {
    permissionService.setPermissionState(
      currentUserId: null,
      isAuthenticated: false,
    );
    await addShare(id: 'r1');

    expect(await service.getSharedRecipes(group), isEmpty);
    expect(await service.streamSharedRecipes(group).first, isEmpty);
  });

  test('the stream follows a new share to the group', () async {
    final stream = service.streamSharedRecipes(group);
    final seen = <List<String>>[];
    final sub = stream.listen(
      (items) => seen.add([for (final i in items) i.id]),
    );
    await pumpEventQueue();
    await addShare(id: 'r1');
    await pumpEventQueue();
    await sub.cancel();

    expect(seen.first, isEmpty);
    expect(seen.last, ['r1']);
  });
}
