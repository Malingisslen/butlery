/// BUT-2213: the recipe's revision (`rev`) on the repository.
///
/// fake_cloud_firestore runs a transaction's body straight through, so these
/// tests check what is compared and what is written, not how concurrent
/// transactions interleave.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

const _uid = 'test-user-123';
final _t0 = DateTime(2026, 10, 8, 12);

void main() {
  late FakeFirebaseFirestore fake;
  late FirebaseRecipeRepository repository;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    fake = FakeFirebaseFirestore();
    final auth = FakeAuthRepository()
      ..setAuthState(user: FakeUser(), userId: _uid, isAuthenticated: true);
    repository = FirebaseRecipeRepository(
      firestore: fake,
      authRepository: auth,
    );
  });

  DocumentReference<Map<String, dynamic>> doc() =>
      fake.collection('users').doc(_uid).collection('recipes').doc('r1');

  Recipe recipe(String title, {int? rev, String createdBy = _uid}) {
    final built = RecipeFactory.build(
      id: 'r1',
      title: title,
      createdBy: createdBy,
      createdAt: _t0,
      updatedAt: _t0,
    );
    return Recipe(core: built.core, type: built.type, rev: rev);
  }

  /// The server's recipe, saved with [rev] (or no `rev` field at all).
  Future<void> seed(String title, {int? rev, String createdBy = _uid}) =>
      doc().set({
        ...recipe(title, createdBy: createdBy).toFirestore(),
        'rev': ?rev,
      });

  Future<Map<String, dynamic>> server() async => (await doc().get()).data()!;

  Future<T> at<T>(Future<T> Function() body) =>
      withClock(Clock.fixed(_t0), body);

  test('a save on the server\'s revision is written and raises it by '
      'one', () async {
    await seed('Linsgryta', rev: 3);

    final rev = await at(
      () => repository.updateAtRevision(
        recipe('Linsgryta med spenat'),
        expectedRev: 3,
      ),
    );

    expect(rev, 4);
    final data = await server();
    expect(data['rev'], 4);
    expect(data['core']['title'], 'Linsgryta med spenat');
  });

  test('a save on an older revision is not written, and the conflict '
      'carries the server\'s recipe', () async {
    await seed('Från min andra enhet', rev: 4);

    await expectLater(
      at(
        () => repository.updateAtRevision(
          recipe('Linsgryta med spenat'),
          expectedRev: 3,
        ),
      ),
      throwsA(
        isA<RecipeRevisionConflictException>()
            .having(
              (e) => e.remote.title,
              'remote title',
              'Från min andra enhet',
            )
            .having((e) => e.remote.rev, 'remote rev', 4),
      ),
    );
    final data = await server();
    expect(data['rev'], 4);
    expect(data['core']['title'], 'Från min andra enhet');
  });

  test('a repeated send of what the server already holds counts as done '
      'and writes nothing', () async {
    await seed('Linsgryta', rev: 0);
    final edit = recipe('Linsgryta med spenat');
    await at(() => repository.updateAtRevision(edit, expectedRev: 0));

    // The answer was lost, so the queue sends the same edit on the same base.
    final rev = await at(
      () => repository.updateAtRevision(edit, expectedRev: 0),
    );

    expect(rev, 1);
    expect((await server())['rev'], 1, reason: 'a second write would make 2');
  });

  test('a save whose base is not known is written without comparing', () async {
    await seed('Linsgryta', rev: 5);

    final rev = await at(
      () => repository.updateAtRevision(recipe('Ny titel')),
    );

    expect(rev, 6);
    expect((await server())['core']['title'], 'Ny titel');
  });

  test('a recipe saved before revisions existed is revision 0', () async {
    await seed('Linsgryta');

    expect(
      await at(
        () => repository.updateAtRevision(recipe('Ny titel'), expectedRev: 0),
      ),
      1,
    );
    expect((await server())['rev'], 1);
    expect(Recipe.fromMap('r1', {'core': <String, dynamic>{}}).rev, 0);
  });

  test('another whole save raises the revision without reading it', () async {
    await seed('Linsgryta');

    await at(() => repository.update(recipe('Första')));
    expect((await server())['rev'], 1);
    await at(() => repository.update(recipe('Andra')));
    expect((await server())['rev'], 2);
  });

  test(
    'a recipe that is gone is "not found", and nothing is created',
    () async {
      await expectLater(
        at(() => repository.updateAtRevision(recipe('X'), expectedRev: 0)),
        throwsA(isA<ResourceNotFoundException>()),
      );
      expect((await doc().get()).exists, isFalse);
    },
  );

  test('the server\'s owner is checked, not the one the save claims', () async {
    await seed('Någon annans', rev: 1, createdBy: 'someone-else');

    await expectLater(
      at(() => repository.updateAtRevision(recipe('Min'), expectedRev: 1)),
      throwsA(isA<PermissionDeniedException>()),
    );
    expect((await server())['core']['title'], 'Någon annans');
  });

  test('the revision is the repository\'s: a device copy keeps it, the '
      'recipe\'s own serializer never writes it', () {
    final withRev = recipe('Linsgryta', rev: 7);
    expect(withRev.toFirestore().containsKey('rev'), isFalse);
    expect(Recipe.fromJson(withRev.toJson()).rev, 7);
    expect(Recipe.fromJson(recipe('Linsgryta').toJson()).rev, isNull);
    expect(withRev.copyWith(title: 'X').rev, 7);
  });
}
