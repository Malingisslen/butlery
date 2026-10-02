// BUT-2151: "Återställ" writes an older version back. A merge would keep a
// nested key only the newer version had, so the restored document would not
// be the version the user chose. performUpdate replaces the whole document;
// every other setDocument caller keeps merging.

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/realtime/conflict_resolution_module.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

void main() {
  late FakeFirebaseFirestore fake;
  late FirestoreRepository repo;

  setUp(() {
    fake = FakeFirebaseFirestore();
    repo = FirestoreRepository(firestore: fake);
  });

  RealtimeRecipe olderVersion() => RealtimeRecipe(
    id: 'rt-1',
    recipe: RecipeFactory.build(id: 'r-1', title: 'Linsgryta'),
    ownerId: 'owner',
    ownerDisplayName: 'owner',
    participants: const {'owner': ResourcePermission.owner},
    lastEditedAt: DateTime(2026, 1, 1),
    lastEditedBy: 'owner',
    lastEditedByDisplayName: 'owner',
    editCount: 1,
  );

  test(
    'a restore drops a nested key that only the newer version had',
    () async {
      final ref = fake.collection('realtime_resources').doc('rt-1');
      final newer = olderVersion().toFirestore();
      (newer['metadata'] as Map<String, dynamic>)['addedLater'] = 'ny';
      await ref.set(newer);

      final module = ConflictResolutionModule(
        firestoreRepository: repo,
        getLatestResource: <T extends RealtimeResource>(_) async =>
            throw UnimplementedError(),
        onConflict: (_) {},
        collectionPath: 'realtime_resources',
      );
      await module.performUpdate(ref, olderVersion());

      final stored = (await ref.get()).data()!;
      expect(
        (stored['metadata'] as Map<String, dynamic>).containsKey('addedLater'),
        isFalse,
      );
      expect(stored.keys.toSet(), olderVersion().toFirestore().keys.toSet());
    },
  );

  test('setDocument still merges by default', () async {
    final ref = fake.collection('any').doc('d');
    await ref.set({
      'kept': 1,
      'nested': {'a': 1},
    });

    await repo.setDocument(ref, {
      'added': 2,
      'nested': {'b': 2},
    });

    expect((await ref.get()).data(), {
      'kept': 1,
      'added': 2,
      'nested': {'a': 1, 'b': 2},
    });
  });
}
