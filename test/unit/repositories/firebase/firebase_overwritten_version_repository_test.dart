/// P5-U26b: the store behind "Återställ i 30 dagar" (produktregler.md:104,
/// :109).
///
/// Proves what the repository promises on its own side of the rules: a kept
/// version lands under the signed-in user's own path and nowhere else, it is
/// exactly 30 days long, the listing is scoped by entity and resource and
/// ordered by when the version was overwritten, a row the app cannot restore
/// is never offered, and forgetting removes the row. Who may read or write it
/// on the server is firestore.rules, pinned by
/// functions/src/__tests__/overwritten-versions-rules.test.ts, because
/// fake_cloud_firestore enforces no rules.
library;

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/repositories/firebase/firebase_overwritten_version_repository.dart';
import 'package:butlery/services/realtime/overwritten_version_service.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

const _me = 'user-me';
const _other = 'user-other';

RealtimeRecipe _recipe(String id, {String editor = _me, String name = 'Jag'}) =>
    RealtimeRecipe(
      id: id,
      ownerId: _me,
      ownerDisplayName: 'Jag',
      participants: const {
        _me: ResourcePermission.owner,
        _other: ResourcePermission.editor,
      },
      createdAt: DateTime.utc(2026, 9, 1),
      lastEditedAt: DateTime.utc(2026, 9, 20, 12),
      lastEditedBy: editor,
      lastEditedByDisplayName: name,
      editCount: 3,
      recipe: RecipeFactory.build(id: id, title: 'Min version av $id'),
    );

OverwrittenVersion _kept(String resourceId, DateTime at, {ConflictEntity? e}) =>
    OverwrittenVersion.capture(
      ownerId: _me,
      entity: e ?? ConflictEntity.recipeOwn,
      lost: _recipe(resourceId),
      winner: _recipe(resourceId, editor: _other, name: 'Per'),
      at: at,
    );

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeAuthRepository auth;
  late FirebaseOverwrittenVersionRepository repository;

  CollectionReference<Map<String, dynamic>> keptOf(String uid) => firestore
      .collection(FirestoreCollections.users)
      .doc(uid)
      .collection(FirestoreCollections.overwrittenVersions);

  setUp(() {
    firestore = FakeFirebaseFirestore();
    auth = FakeAuthRepository();
    auth.setAuthState(
      user: FakeUser(uid: _me),
      userId: _me,
      isAuthenticated: true,
    );
    repository = FirebaseOverwrittenVersionRepository(
      firestore: firestore,
      authRepository: auth,
    );
  });

  group('capture', () {
    test('keeps the lost version for exactly 30 days, named by the winner', () {
      final at = DateTime.utc(2026, 9, 23, 14, 2);
      final v = _kept('r1', at);

      expect(v.expiresAt.difference(v.overwrittenAt), const Duration(days: 30));
      expect(v.overwrittenAt, at);
      expect(v.overwrittenBy, _other);
      expect(v.overwrittenByName, 'Per');
      expect(v.resourceType, RealtimeResourceType.recipe);
      expect(
        (OverwrittenVersionService.parse(v) as RealtimeRecipe).title,
        'Min version av r1',
        reason: 'the stored version is the one that lost, and it parses back',
      );
      expect(v.isKeptAt(at.add(const Duration(days: 29, hours: 23))), isTrue);
      expect(v.isKeptAt(at.add(const Duration(days: 30))), isFalse);
    });
  });

  group('keep', () {
    test('writes under the signed-in user and nowhere else', () async {
      final stored = await repository.keep(
        _kept('r1', DateTime.utc(2026, 9, 23)),
      );

      expect(stored.id, isNotEmpty);
      final mine = await keptOf(_me).get();
      expect(mine.docs.map((d) => d.id), [stored.id]);
      expect((await keptOf(_other).get()).docs, isEmpty);
      final data = mine.docs.single.data();
      expect(data['ownerId'], _me);
      expect(data['entity'], 'recipeOwn');
      expect(data['resourceId'], 'r1');
      expect(
        (data['expiresAt'] as Timestamp).toDate().difference(
          (data['overwrittenAt'] as Timestamp).toDate(),
        ),
        const Duration(days: 30),
      );
    });

    test('refuses a version that belongs to someone else', () async {
      final foreign = OverwrittenVersion.capture(
        ownerId: _other,
        entity: ConflictEntity.recipeOwn,
        lost: _recipe('r1'),
        winner: _recipe('r1', editor: _me),
        at: DateTime.utc(2026, 9, 23),
      );

      await expectLater(() => repository.keep(foreign), throwsA(anything));
      expect((await keptOf(_other).get()).docs, isEmpty);
      expect((await keptOf(_me).get()).docs, isEmpty);
    });
  });

  group('watch', () {
    test('scopes by entity and resource, newest first', () async {
      final older = await repository.keep(
        _kept('r1', DateTime.utc(2026, 9, 20)),
      );
      final newer = await repository.keep(
        _kept('r1', DateTime.utc(2026, 9, 22)),
      );
      await repository.keep(_kept('r2', DateTime.utc(2026, 9, 21)));
      await repository.keep(
        _kept('w1', DateTime.utc(2026, 9, 21), e: ConflictEntity.weekMenu),
      );

      final forR1 = await repository
          .watch(entity: ConflictEntity.recipeOwn, resourceId: 'r1')
          .first;
      expect(forR1.map((v) => v.id), [newer.id, older.id]);

      final weeks = await repository
          .watch(entity: ConflictEntity.weekMenu)
          .first;
      expect(weeks.map((v) => v.resourceId), ['w1']);
    });

    test('never offers a row it cannot restore', () async {
      await keptOf(_me).doc('broken').set({
        'ownerId': _me,
        'entity': 'recipeOwn',
        'resourceType': 'recipe',
        // no resourceId, no version
        'overwrittenAt': Timestamp.fromDate(DateTime.utc(2026, 9, 20)),
        'expiresAt': Timestamp.fromDate(DateTime.utc(2026, 10, 20)),
      });
      await keptOf(_me).doc('shared').set({
        ..._kept('r1', DateTime.utc(2026, 9, 20)).toFirestore(),
        'entity': 'recipeShared',
      });

      final rows = await repository
          .watch(entity: ConflictEntity.recipeOwn)
          .first;
      expect(rows, isEmpty);
    });

    test("never reads another user's rows", () async {
      await keptOf(
        _other,
      ).doc('theirs').set(_kept('r1', DateTime.utc(2026, 9, 20)).toFirestore());

      final rows = await repository
          .watch(entity: ConflictEntity.recipeOwn)
          .first;
      expect(rows, isEmpty);
    });
  });

  test('forget removes the row', () async {
    final stored = await repository.keep(
      _kept('r1', DateTime.utc(2026, 9, 23)),
    );

    await repository.forget(stored.id);

    expect((await keptOf(_me).get()).docs, isEmpty);
  });
}
