/// BUT-2401: two browser windows saving one recipe.
///
/// Each window has its own adapter over one server. fake_cloud_firestore runs
/// a transaction's body straight through, so this proves what is compared for
/// a stale base (one save after the other), not two transactions interleaving.
library;

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/exceptions/repository_exception.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';
import 'package:butlery/services/unified/modules/service_adapters/recipe_service_adapter.dart';

import '../../../../../infrastructure/factories/recipe_factory.dart';
import '../../../../../infrastructure/mocks/production_mocks.dart';
import '../../../../../test_support/base_unit_test.dart';

class _MockTrashRepository extends Mock implements TrashRepository {}

const _uid = 'test-user-123';
final _t0 = DateTime(2026, 10, 19, 12);

void main() {
  late FakeFirebaseFirestore fake;
  late RecipeServiceAdapter windowA;
  late RecipeServiceAdapter windowB;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() async {
    fake = FakeFirebaseFirestore();
    final auth = FakeAuthRepository()
      ..setAuthState(user: FakeUser(), userId: _uid, isAuthenticated: true);
    RecipeServiceAdapter window() => RecipeServiceAdapter(
      recipeRepository: FirebaseRecipeRepository(
        firestore: fake,
        authRepository: auth,
      ),
      trashRepository: _MockTrashRepository(),
    );
    windowA = window();
    windowB = window();
    await fake
        .collection('users')
        .doc(_uid)
        .collection('recipes')
        .doc('r1')
        .set({..._recipe('Linsgryta').toFirestore(), 'rev': 3});
  });

  Future<Map<String, dynamic>> server() async =>
      (await fake
              .collection('users')
              .doc(_uid)
              .collection('recipes')
              .doc('r1')
              .get())
          .data()!;

  Future<T> at<T>(Future<T> Function() body) =>
      withClock(Clock.fixed(_t0), body);

  test('the window that saves second on the same base gets a conflict '
      'carrying the first window\'s version, and writes nothing', () async {
    await at(
      () => windowA.updateRecipeOnRevision(_recipe('Från fönster A', rev: 3)),
    );

    await expectLater(
      at(
        () => windowB.updateRecipeOnRevision(_recipe('Från fönster B', rev: 3)),
      ),
      throwsA(
        isA<RecipeRevisionConflictException>().having(
          (e) => e.remote.title,
          'remote title',
          'Från fönster A',
        ),
      ),
    );
    final data = await server();
    expect(data['rev'], 4);
    expect(data['core']['title'], 'Från fönster A');
  });

  test('a window saving again from its stale copy is not in conflict with '
      'its own earlier save', () async {
    final stale = _recipe('Första', rev: 3);
    await at(() => windowA.updateRecipeOnRevision(stale));

    final ok = await at(
      () => windowA.updateRecipeOnRevision(_recipe('Andra', rev: 3)),
    );

    expect(ok, isTrue);
    final data = await server();
    expect(data['rev'], 5);
    expect(data['core']['title'], 'Andra');
  });
}

Recipe _recipe(String title, {int? rev}) {
  final built = RecipeFactory.build(
    id: 'r1',
    title: title,
    createdBy: _uid,
    createdAt: _t0,
    updatedAt: _t0,
  );
  return Recipe(core: built.core, type: built.type, rev: rev);
}
