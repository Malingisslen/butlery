/// BUT-2107: a modern recipe whose `socialData.ownerId` is '' and whose
/// `createdBy` is the signed-in user is the user's own recipe.
///
/// A plain `socialData?.ownerId ?? createdBy` stops at '', which then reads as
/// a real uid that matches nobody, so the owner was refused.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_repository.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

const _me = 'test-user-123';
const _other = 'someone-else';
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
      ..setAuthState(user: FakeUser(), userId: _me, isAuthenticated: true);
    repository = FirebaseRecipeRepository(
      firestore: fake,
      authRepository: auth,
    );
  });

  DocumentReference<Map<String, dynamic>> doc() =>
      fake.collection('users').doc(_me).collection('recipes').doc('r1');

  Recipe recipe({
    String createdBy = _me,
    String? ownerId = '',
    String title = 'Gryta',
  }) => Recipe(
    core: RecipeFactory.build(
      id: 'r1',
      title: title,
      createdBy: createdBy,
      createdAt: _t0,
      updatedAt: _t0,
    ).core,
    type: RecipeType.personal,
    socialData: RecipeSocialData(ownerId: ownerId),
  );

  Recipe plainMine() => Recipe(
    core: RecipeFactory.build(
      id: 'r1',
      createdBy: _me,
      createdAt: _t0,
      updatedAt: _t0,
    ).core,
    type: RecipeType.personal,
  );

  Future<void> seed(Recipe r) => doc().set(r.toFirestore());

  group('permission questions', () {
    test('create: an empty ownerId with me as creator is allowed', () async {
      expect(await repository.validateCreatePermission(_me, recipe()), isTrue);
    });

    test('create: a recipe someone else created is refused', () async {
      expect(
        await repository.validateCreatePermission(
          _me,
          recipe(createdBy: _other),
        ),
        isFalse,
      );
    });

    test('read: the creator reads it, a stranger and a no-owner recipe '
        'do not', () async {
      expect(
        await repository.validateReadPermission(_me, 'r1', recipe()),
        isTrue,
      );
      expect(
        await repository.validateReadPermission(
          _me,
          'r1',
          recipe(createdBy: _other),
        ),
        isFalse,
      );
      expect(
        await repository.validateReadPermission(
          _me,
          'r1',
          recipe(createdBy: ''),
        ),
        isFalse,
      );
    });

    test('update: the creator updates it, a stranger and a no-owner recipe '
        'do not', () async {
      expect(
        await repository.validateUpdatePermission(_me, 'r1', recipe()),
        isTrue,
      );
      expect(
        await repository.validateUpdatePermission(
          _me,
          'r1',
          recipe(createdBy: _other),
        ),
        isFalse,
      );
      expect(
        await repository.validateUpdatePermission(
          _me,
          'r1',
          recipe(createdBy: ''),
        ),
        isFalse,
      );
    });

    test(
      'delete: the creator deletes it, the other cases are refused',
      () async {
        await seed(recipe());
        expect(await repository.validateDeletePermission(_me, 'r1'), isTrue);

        await seed(recipe(createdBy: _other));
        expect(await repository.validateDeletePermission(_me, 'r1'), isFalse);

        await seed(recipe(createdBy: ''));
        expect(await repository.validateDeletePermission(_me, 'r1'), isFalse);
      },
    );

    test('canRead, canWrite and canDelete follow the creator', () async {
      await seed(recipe());
      expect(await repository.canRead('r1', _me), isTrue);
      expect(await repository.canWrite('r1', _me), isTrue);
      expect(await repository.canDelete('r1', _me), isTrue);

      await seed(recipe(createdBy: _other));
      expect(await repository.canRead('r1', _me), isFalse);
      expect(await repository.canWrite('r1', _me), isFalse);
      expect(await repository.canDelete('r1', _me), isFalse);

      await seed(recipe(createdBy: ''));
      expect(await repository.canRead('r1', _me), isFalse);
      expect(await repository.canWrite('r1', _me), isFalse);
      expect(await repository.canDelete('r1', _me), isFalse);
    });
  });

  group('writes', () {
    test('create stores a recipe whose ownerId is empty', () async {
      await repository.create(recipe());

      expect((await doc().get()).exists, isTrue);
    });

    test('create refuses a recipe someone else created', () async {
      await expectLater(
        repository.create(recipe(createdBy: _other)),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect((await doc().get()).exists, isFalse);
    });

    test('createOnce stores a recipe whose ownerId is empty', () async {
      expect(await repository.createOnce(recipe()), 0);

      expect((await doc().get()).exists, isTrue);
    });

    test('createOnce refuses a recipe someone else created', () async {
      await expectLater(
        repository.createOnce(recipe(createdBy: _other)),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect((await doc().get()).exists, isFalse);
    });

    test('update writes over a stored recipe whose ownerId is empty', () async {
      await seed(recipe());

      await repository.update(plainMine().copyWith(title: 'Ny titel'));

      expect((await doc().get()).data()!['core']['title'], 'Ny titel');
    });

    test('update refuses a stored recipe someone else created', () async {
      await seed(recipe(createdBy: _other));

      await expectLater(
        repository.update(plainMine().copyWith(title: 'Ny titel')),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect((await doc().get()).data()!['core']['title'], 'Gryta');
    });

    test('updateAtRevision writes over a stored recipe whose ownerId is '
        'empty', () async {
      await seed(recipe());

      final rev = await repository.updateAtRevision(
        plainMine().copyWith(title: 'Ny titel'),
        expectedRev: 0,
      );

      expect(rev, 1);
      expect((await doc().get()).data()!['core']['title'], 'Ny titel');
    });

    test('updateAtRevision refuses a stored recipe someone else '
        'created', () async {
      await seed(recipe(createdBy: _other));

      await expectLater(
        repository.updateAtRevision(
          plainMine().copyWith(title: 'Ny titel'),
          expectedRev: 0,
        ),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect((await doc().get()).data()!['core']['title'], 'Gryta');
    });

    test('delete removes a stored recipe whose ownerId is empty', () async {
      await seed(recipe());

      await repository.delete('r1');

      expect((await doc().get()).exists, isFalse);
    });

    test('delete refuses a stored recipe someone else created', () async {
      await seed(recipe(createdBy: _other));

      await expectLater(
        repository.delete('r1'),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect((await doc().get()).exists, isTrue);
    });
  });

  group('sharing', () {
    test('addCollaborator lets the creator share a recipe whose ownerId is '
        'empty', () async {
      await seed(recipe());

      await repository.addCollaborator('r1', _other);

      final stored = Recipe.fromMap('r1', (await doc().get()).data()!);
      expect(stored.socialData?.memberPermissions?.keys, contains(_other));
    });

    test('addCollaborator refuses a recipe someone else created', () async {
      await seed(recipe(createdBy: _other));

      await expectLater(
        repository.addCollaborator('r1', 'third-user'),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    // fake_cloud_firestore deep-merges a map on update, so the removed key
    // cannot be observed in the store; the revision bump proves the removal
    // got past the owner check and was written.
    test('removeCollaborator lets the creator unshare a recipe whose ownerId '
        'is empty', () async {
      await seed(recipe());
      await repository.addCollaborator('r1', _other);
      final before = (await doc().get()).data()!['rev'];

      await repository.removeCollaborator('r1', _other);

      expect((await doc().get()).data()!['rev'], before + 1);
    });

    test('removeCollaborator refuses a recipe someone else created', () async {
      await seed(recipe(createdBy: _other));

      await expectLater(
        repository.removeCollaborator('r1', _other),
        throwsA(isA<PermissionDeniedException>()),
      );
    });
  });
}
