/// Steg 10E: a recipe is born private. A fork or a copy is built from a
/// recipe that may be on the profile, and must not carry that choice.
library;

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  late FirebaseRecipeRepository repository;
  late FakeFirebaseFirestore fakeFirestore;

  const uid = 'test-user-123';

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  setUp(() {
    fakeFirestore = FakeFirebaseFirestore();
    final auth = FakeAuthRepository()
      ..setAuthState(user: FakeUser(), userId: uid, isAuthenticated: true);
    repository = FirebaseRecipeRepository(
      firestore: fakeFirestore,
      authRepository: auth,
    );
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  Recipe shown(String id) =>
      RecipeFactory.build(id: id, createdBy: uid).copyWith(
        showOnProfile: true,
        showOnProfileChangedAt: DateTime.utc(2026, 10, 1),
      );

  Future<Map<String, dynamic>> storedCore(String id) async {
    final doc = await fakeFirestore
        .collection('users')
        .doc(uid)
        .collection('recipes')
        .doc(id)
        .get();
    return doc.data()!['core'] as Map<String, dynamic>;
  }

  test('create stores a copy of a shown recipe as private', () async {
    final created = await repository.create(shown('fork'));

    final core = await storedCore('fork');
    expect(core['showOnProfile'], isFalse);
    expect(core.containsKey('showOnProfileChangedAt'), isFalse);
    expect(created.showOnProfile, isFalse);
  });

  test('the offline create stores it as private too', () async {
    await repository.createOnce(shown('queued'));

    final core = await storedCore('queued');
    expect(core['showOnProfile'], isFalse);
    expect(core.containsKey('showOnProfileChangedAt'), isFalse);
  });

  test('a batch create stores every recipe as private', () async {
    await repository.addRecipes([shown('b1'), shown('b2')]);

    for (final id in ['b1', 'b2']) {
      final core = await storedCore(id);
      expect(core['showOnProfile'], isFalse, reason: id);
      expect(core.containsKey('showOnProfileChangedAt'), isFalse, reason: id);
    }
  });

  test('an update keeps the profile choice', () async {
    await repository.create(RecipeFactory.build(id: 'own', createdBy: uid));

    await repository.update(shown('own'));

    expect((await storedCore('own'))['showOnProfile'], isTrue);
  });
}
