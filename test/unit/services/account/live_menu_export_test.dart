/// BUT-2151: the Art. 15 section for live menus (`realtime_resources`).
///
/// It must cover the menus the user owns and the ones they take part in, and,
/// per ADR-0023, strip other people's display names — on the menu and inside
/// each dish it stores — while keeping their uids.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_menu.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_data_export_repository.dart';
import 'package:butlery/services/account/export/live_menu_export.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

const _me = 'user-me';
const _owner = 'user-owner';
const _stranger = 'user-stranger';

/// Answers the two probes from fixed row lists, or throws.
class _StubExports extends FirebaseDataExportRepository {
  _StubExports({required super.authRepository, this.owned, this.joined})
    : super(firestore: FakeFirebaseFirestore());

  final int? owned;
  final int? joined;

  List<Map<String, dynamic>> _rows(String prefix, int n) => [
    for (var i = 0; i < n; i++)
      {
        'id': '${prefix}_$i',
        'data': <String, dynamic>{'ownerId': _owner},
      },
  ];

  @override
  Future<List<Map<String, dynamic>>> exportRealtimeResourcesOwned(
    String userId, {
    int maxDocuments = 500,
  }) async {
    if (owned == null) throw StateError('owned probe failed for $userId');
    return _rows('o', owned!.clamp(0, maxDocuments));
  }

  @override
  Future<List<Map<String, dynamic>>> exportRealtimeResourcesAsParticipant(
    String userId, {
    int maxDocuments = 500,
  }) async => _rows('j', (joined ?? 0).clamp(0, maxDocuments));
}

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeAuthRepository auth;
  late LiveMenuExport export;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = FakeAuthRepository();
    auth.setAuthState(
      user: FakeUser(uid: _me),
      userId: _me,
      isAuthenticated: true,
    );
    export = LiveMenuExport(
      FirebaseDataExportRepository(firestore: firestore, authRepository: auth),
    );
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  Future<void> seed(String id, Map<String, dynamic> data) => firestore
      .collection(FirestoreCollections.realtimeResources)
      .doc(id)
      .set(data);

  Map<String, dynamic> menuOf(Map<String, dynamic> section, String id) =>
      ((section['live_menus'] as List).cast<Map<String, dynamic>>().firstWhere(
                (m) => m['menu_id'] == id,
              )['data']
              as Map)
          .cast<String, dynamic>();

  test('owned and joined menus are both exported, nobody else\'s', () async {
    // Owned but no longer on the roster: only the owner probe can find it.
    await seed('${_me}_m1', {
      'ownerId': _me,
      'ownerDisplayName': 'Jag',
      'participantIds': [_stranger],
    });
    await seed('${_owner}_m2', {
      'ownerId': _owner,
      'ownerDisplayName': 'Olle',
      'participantIds': [_owner, _me],
    });
    await seed('${_stranger}_m3', {
      'ownerId': _stranger,
      'participantIds': [_stranger],
    });

    final section = await export.export(_me);

    expect(section['total_count'], 2);
    expect(
      (section['live_menus'] as List).map((m) => (m as Map)['menu_id']),
      unorderedEquals(['${_me}_m1', '${_owner}_m2']),
    );
    expect(menuOf(section, '${_me}_m1')['ownerDisplayName'], 'Jag');
    expect(section.containsKey('truncated'), isFalse);
  });

  test('other people\'s names go, their uids and my own name stay', () async {
    await seed('${_owner}_m2', {
      'ownerId': _owner,
      'ownerDisplayName': 'Olle',
      'lastEditedBy': _me,
      'lastEditedByDisplayName': 'Jag',
      'participants': {_owner: 'owner', _me: 'editor'},
      'participantIds': [_owner, _me],
    });

    final section = await export.export(_me);
    final menu = menuOf(section, '${_owner}_m2');

    expect(menu.containsKey('ownerDisplayName'), isFalse);
    expect(menu['ownerId'], _owner);
    expect(menu['lastEditedByDisplayName'], 'Jag');
    expect(menu['participants'], {_owner: 'owner', _me: 'editor'});
    expect(section.containsKey('data_minimisation'), isTrue);
  });

  test(
    'names inside each dish follow the same rule, and its stamps are UTC',
    () async {
      final local = DateTime(2026, 3, 1, 18, 30);
      Recipe dish(String id, String ownerId, String name) =>
          RecipeFactory.build(
            id: id,
            title: 'Rätt $id',
            createdBy: ownerId,
            socialData: RecipeSocialData(
              ownerId: ownerId,
              ownerDisplayName: name,
              memberPermissions: const {},
              allowGuestViewing: false,
              allowMemberInvites: false,
            ),
            realtimeData: RecipeRealtimeData(
              lastEditedByUserId: ownerId,
              lastEditedByDisplayName: name,
              lastEditedAt: local,
            ),
          );
      final menu = RealtimeMenu.fromMenuCategories(
        menuTitle: 'Veckans meny',
        menuSnapshot: {
          'middag': [dish('d1', _owner, 'Olle'), dish('d2', _me, 'Jag')],
        },
        ownerId: _owner,
        ownerDisplayName: 'Olle',
        editorUserIds: const [_me],
      );
      // Whole recipes, as a client before BUT-2214 or a hand-rolled one
      // stores them: the app's own save path keeps no names in a dish.
      await seed(menu.id, {
        ...menu.toFirestore(),
        'menuSnapshot': {
          'middag': [
            dish('d1', _owner, 'Olle').toFirestore(),
            dish('d2', _me, 'Jag').toFirestore(),
          ],
        },
      });

      final exported = menuOf(await export.export(_me), menu.id);
      final dishes = ((exported['menuSnapshot'] as Map)['middag'] as List)
          .cast<Map<String, dynamic>>();
      final theirs = dishes.firstWhere(
        (d) => (d['socialData'] as Map)['ownerId'] == _owner,
      );
      final mine = dishes.firstWhere(
        (d) => (d['socialData'] as Map)['ownerId'] == _me,
      );

      expect(
        (theirs['socialData'] as Map).containsKey('ownerDisplayName'),
        isFalse,
      );
      expect(
        (theirs['realtimeData'] as Map).containsKey('lastEditedByDisplayName'),
        isFalse,
      );
      expect((mine['socialData'] as Map)['ownerDisplayName'], 'Jag');
      expect((mine['realtimeData'] as Map)['lastEditedByDisplayName'], 'Jag');
      expect(
        (theirs['realtimeData'] as Map)['lastEditedAt'],
        local.toUtc().toIso8601String(),
      );
    },
  );

  test(
    'the name rules cover every display name a menu and a whole-recipe dish '
    'persist',
    () {
      final recipe = RecipeFactory.build(
        id: 'd',
        socialData: RecipeSocialData(
          ownerId: 'o',
          ownerDisplayName: 'O',
          memberPermissions: const {'x': ResourcePermission.editor},
          allowGuestViewing: false,
          allowMemberInvites: false,
        ),
        realtimeData: const RecipeRealtimeData(
          lastEditedByUserId: 'o',
          lastEditedByDisplayName: 'O',
        ),
      );
      final menu = RealtimeMenu.fromMenuCategories(
        menuTitle: 'm',
        menuSnapshot: {
          'middag': [recipe],
        },
        ownerId: 'o',
        ownerDisplayName: 'O',
      ).toFirestore();

      Set<String> namesIn(Object? node, String path) {
        final found = <String>{};
        if (node is Map) {
          node.forEach((k, v) {
            final here = path.isEmpty ? '$k' : '$path.$k';
            if ('$k'.endsWith('DisplayName')) found.add(here);
            found.addAll(namesIn(v, here));
          });
        } else if (node is List) {
          for (final v in node) {
            found.addAll(namesIn(v, '$path[]'));
          }
        }
        return found;
      }

      // BUT-2214: the app stores a dish without names, so a saved menu
      // carries them only on the menu itself.
      expect(namesIn(menu, ''), {...LiveMenuExport.nameKeysByOwnerIdKey.keys});
      // A whole recipe, the shape an older or hand-rolled client stores.
      expect(namesIn(recipe.toFirestore(), ''), {
        for (final (mapKey, nameKey, _) in LiveMenuExport.dishNameKeys)
          '$mapKey.$nameKey',
      });
    },
  );

  test(
    'an over-cap probe marks the section truncated, each on its own',
    () async {
      final ownedOver = await LiveMenuExport(
        _StubExports(authRepository: auth, owned: 501, joined: 0),
      ).export(_me);
      final joinedOver = await LiveMenuExport(
        _StubExports(authRepository: auth, owned: 0, joined: 501),
      ).export(_me);

      expect(ownedOver['truncated'], isTrue);
      expect(joinedOver['truncated'], isTrue);
    },
  );

  test(
    'a failed probe yields the stable error, never the raw exception',
    () async {
      final section = await LiveMenuExport(
        _StubExports(authRepository: auth),
      ).export(_me);

      expect(section['error_code'], 'live-menus-export-failed');
      expect(section['error'], 'Live menus could not be exported.');
    },
  );
}
