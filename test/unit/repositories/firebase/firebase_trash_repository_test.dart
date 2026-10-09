/// BUT-907: the store behind the trash.
///
/// Proves what the repository promises on its own side of the rules: a
/// recipe moves to the signed-in owner's trash in ONE batch that also
/// deletes it, only the owner's recipe can move, a failed batch leaves both
/// documents as they were, a restore puts the recipe back one revision on
/// and refuses an expired or already-restored item, and emptying deletes in
/// batches of at most 500. Who may read or write a row on the server is
/// firestore.rules, pinned by functions/src/__tests__/trash-rules.test.ts,
/// because fake_cloud_firestore enforces no rules.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe/recipe_serialization.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/trash_item.dart';
import 'package:butlery/repositories/firebase/firebase_trash_repository.dart';
import 'package:butlery/repositories/interfaces/trash_repository.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

const _me = 'user-me';
const _other = 'user-other';

/// One batch as the repository built it: its operations in order.
class _RecordedBatch extends Fake implements WriteBatch {
  _RecordedBatch(this._inner, {required this.fail});

  final WriteBatch _inner;
  final bool fail;
  final List<String> ops = [];

  @override
  void set<T>(
    DocumentReference<T> document,
    T data, [
    SetOptions? options,
  ]) {
    ops.add('set ${document.path}');
    _inner.set(document, data, options);
  }

  @override
  void delete(DocumentReference document) {
    ops.add('delete ${document.path}');
    _inner.delete(document);
  }

  @override
  Future<void> commit() async {
    if (fail) {
      throw FirebaseException(plugin: 'cloud_firestore', code: 'unavailable');
    }
    await _inner.commit();
  }
}

/// The fake Firestore, with every batch recorded and, when [failCommits],
/// refused at commit as the server refuses an atomic write: nothing lands.
class _RecordingFirestore extends Fake implements FirebaseFirestore {
  _RecordingFirestore(this.inner);

  final FakeFirebaseFirestore inner;
  final List<_RecordedBatch> batches = [];
  bool failCommits = false;

  @override
  CollectionReference<Map<String, dynamic>> collection(String path) =>
      inner.collection(path);

  @override
  WriteBatch batch() {
    final b = _RecordedBatch(inner.batch(), fail: failCommits);
    batches.add(b);
    return b;
  }

  @override
  Future<T> runTransaction<T>(
    TransactionHandler<T> handler, {
    Duration timeout = const Duration(seconds: 30),
    int maxAttempts = 5,
  }) => inner.runTransaction(handler, timeout: timeout);
}

Recipe _ownRecipe(String id, {int? rev}) => Recipe(
  core: RecipeFactory.build(id: id, title: 'Gryta $id', createdBy: _me).core,
  type: RecipeType.personal,
  socialData: RecipeSocialData(
    ownerId: _me,
    ownerDisplayName: 'Jag',
    memberPermissions: const {_other: ResourcePermission.viewer},
    allowGuestViewing: false,
    allowMemberInvites: true,
  ),
  rev: rev,
);

void main() {
  late _RecordingFirestore firestore;
  late FakeAuthRepository auth;
  late FirebaseTrashRepository repository;

  CollectionReference<Map<String, dynamic>> col(String uid, String name) =>
      firestore.inner
          .collection(FirestoreCollections.users)
          .doc(uid)
          .collection(name);
  CollectionReference<Map<String, dynamic>> trashOf(String uid) =>
      col(uid, FirestoreCollections.userTrash);
  CollectionReference<Map<String, dynamic>> recipesOf(String uid) =>
      col(uid, FirestoreCollections.recipes);

  Future<void> storeRecipe(String uid, Recipe recipe) => recipesOf(
    uid,
  ).doc(recipe.id).set(RecipeSerialization.toFirestore(recipe));

  void signIn(String? uid) => auth.setAuthState(
    user: uid == null ? null : FakeUser(uid: uid),
    userId: uid,
    isAuthenticated: uid != null,
  );

  setUp(() {
    firestore = _RecordingFirestore(FakeFirebaseFirestore());
    auth = FakeAuthRepository();
    signIn(_me);
    repository = FirebaseTrashRepository(
      firestore: firestore,
      authRepository: auth,
    );
  });

  group('moveRecipeToTrash', () {
    test('writes the copy and deletes the recipe in one batch', () async {
      final recipe = _ownRecipe('r1', rev: 3);
      await storeRecipe(_me, recipe);

      await repository.moveRecipeToTrash(recipe);

      expect(firestore.batches, hasLength(1));
      expect(firestore.batches.single.ops, [
        'set users/$_me/trash/r1',
        'delete users/$_me/recipes/r1',
      ]);
      expect((await recipesOf(_me).doc('r1').get()).exists, isFalse);
      final row = (await trashOf(_me).doc('r1').get()).data()!;
      expect(row['ownerId'], _me);
      expect(row['sourceId'], 'r1');
      expect((row['payload'] as Map).containsKey('socialData'), isFalse);
    });

    test('a refused batch leaves both documents as they were', () async {
      final recipe = _ownRecipe('r1');
      await storeRecipe(_me, recipe);
      firestore.failCommits = true;

      await expectLater(
        repository.moveRecipeToTrash(recipe),
        throwsA(isA<FirebaseException>()),
      );

      expect(firestore.batches.single.ops, hasLength(2));
      expect((await recipesOf(_me).doc('r1').get()).exists, isTrue);
      expect((await trashOf(_me).doc('r1').get()).exists, isFalse);
    });

    test("another owner's recipe is refused and nothing is written", () async {
      final theirs = Recipe(
        core: RecipeFactory.build(id: 'r9', createdBy: _other).core,
        type: RecipeType.personal,
        socialData: RecipeSocialData(
          ownerId: _other,
          ownerDisplayName: 'Någon',
          memberPermissions: const {_me: ResourcePermission.viewer},
          allowGuestViewing: false,
          allowMemberInvites: true,
        ),
      );

      await expectLater(
        repository.moveRecipeToTrash(theirs),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(firestore.batches, isEmpty);
    });

    // createdBy is the caller, so only the delete check can refuse it.
    test(
      'a recipe someone else owns is refused even when createdBy is mine',
      () async {
        final theirs = Recipe(
          core: RecipeFactory.build(id: 'r7', createdBy: _me).core,
          type: RecipeType.personal,
          socialData: RecipeSocialData(
            ownerId: _other,
            ownerDisplayName: 'Någon',
            memberPermissions: const {_me: ResourcePermission.viewer},
            allowGuestViewing: false,
            allowMemberInvites: true,
          ),
        );

        await expectLater(
          repository.moveRecipeToTrash(theirs),
          throwsA(isA<PermissionDeniedException>()),
        );
        expect(firestore.batches, isEmpty);
      },
    );

    // The legacy check infers ownership of any PERSONAL recipe without
    // socialData, so the trash's own create check is what stops this one.
    test('a legacy-shaped recipe created by someone else is refused', () async {
      final theirs = RecipeFactory.buildPersonal(id: 'r8', createdBy: _other);

      await expectLater(
        repository.moveRecipeToTrash(theirs),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect(firestore.batches, isEmpty);
    });

    test('signed out, nothing is attempted', () async {
      signIn(null);
      await expectLater(
        repository.moveRecipeToTrash(_ownRecipe('r1')),
        throwsA(isA<AuthenticationException>()),
      );
      expect(firestore.batches, isEmpty);
    });
  });

  group('restoreRecipe', () {
    Future<TrashItem> trashed(String id, {int? rev}) async {
      final recipe = _ownRecipe(id, rev: rev);
      await storeRecipe(_me, recipe);
      await repository.moveRecipeToTrash(recipe);
      return (await repository.listTrash()).singleWhere((i) => i.id == id);
    }

    test('puts the recipe back one revision on and empties the row', () async {
      final item = await trashed('r1', rev: 3);

      final restored = await repository.restoreRecipe(item);

      expect(restored.rev, 4);
      expect(restored.type, RecipeType.personal);
      final doc = (await recipesOf(_me).doc('r1').get()).data()!;
      expect(doc['rev'], 4);
      expect((doc['core'] as Map)['title'], 'Gryta r1');
      expect(doc['socialData'], isNull);
      expect((await trashOf(_me).doc('r1').get()).exists, isFalse);
    });

    test('given tags replace the stored ones', () async {
      final item = await trashed('r1');
      final tags = TagResult.failed(reason: 'probe');

      final restored = await repository.restoreRecipe(item, tagResult: tags);

      expect(restored.tagResult?.generatorVersion, 'failed');
      final doc = (await recipesOf(_me).doc('r1').get()).data()!;
      expect(
        ((doc['core'] as Map)['tagResult'] as Map)['generatorVersion'],
        'failed',
      );
    });

    test('an expired item is refused and nothing changes', () async {
      final item = await trashed('r1');

      await expectLater(
        withClock(
          Clock.fixed(item.expireAt),
          () => repository.restoreRecipe(item),
        ),
        throwsA(isA<TrashItemExpiredException>()),
      );
      expect((await trashOf(_me).doc('r1').get()).exists, isTrue);
      expect((await recipesOf(_me).doc('r1').get()).exists, isFalse);
    });

    test('a recipe already back is not written over', () async {
      final item = await trashed('r1');
      await storeRecipe(_me, _ownRecipe('r1', rev: 9));

      await expectLater(
        repository.restoreRecipe(item),
        throwsA(isA<TrashItemGoneException>()),
      );
      final doc = (await recipesOf(_me).doc('r1').get()).data()!;
      expect(doc['rev'], isNull, reason: 'the stored recipe is untouched');
      expect((await trashOf(_me).doc('r1').get()).exists, isTrue);
    });

    test('an item no longer in the trash is refused', () async {
      final item = await trashed('r1');
      await trashOf(_me).doc('r1').delete();

      await expectLater(
        repository.restoreRecipe(item),
        throwsA(isA<TrashItemGoneException>()),
      );
      expect((await recipesOf(_me).doc('r1').get()).exists, isFalse);
    });

    test("another user's item is refused", () async {
      final item = await trashed('r1');
      signIn(_other);

      await expectLater(
        repository.restoreRecipe(item),
        throwsA(isA<PermissionDeniedException>()),
      );
      expect((await trashOf(_me).doc('r1').get()).exists, isTrue);
    });
  });

  group('listing', () {
    test("newest first, and only the signed-in user's", () async {
      final now = clock.now();
      for (final (id, ago) in [('old', 3), ('new', 1), ('mid', 2)]) {
        final item = withClock(
          Clock.fixed(now.subtract(Duration(days: ago))),
          () => TrashItem.fromRecipe(_ownRecipe(id), ownerId: _me),
        );
        await trashOf(_me).doc(id).set(item.toFirestore());
      }
      await trashOf(_other)
          .doc('theirs')
          .set(
            TrashItem.fromRecipe(
              _ownRecipe('theirs'),
              ownerId: _other,
            ).toFirestore(),
          );

      final items = await repository.listTrash();

      expect(items.map((i) => i.id), ['new', 'mid', 'old']);
    });
  });

  group('deleteForever and emptyTrash', () {
    Future<void> seed(String uid, int count) async {
      for (var i = 0; i < count; i++) {
        await trashOf(uid)
            .doc('r$i')
            .set(
              TrashItem.fromRecipe(
                _ownRecipe('r$i'),
                ownerId: uid,
              ).toFirestore(),
            );
      }
    }

    test('deleteForever removes only the named rows', () async {
      await seed(_me, 3);

      await repository.deleteForever(['r0', 'r2']);

      final left = await trashOf(_me).get();
      expect(left.docs.map((d) => d.id), ['r1']);
    });

    for (final count in [500, 501]) {
      test('emptyTrash clears $count rows in batches of at most 500', () async {
        await seed(_me, count);
        await seed(_other, 1);

        final deleted = await repository.emptyTrash();

        expect(deleted, count);
        expect((await trashOf(_me).get()).docs, isEmpty);
        expect((await trashOf(_other).get()).docs, hasLength(1));
        expect(
          firestore.batches.map((b) => b.ops.length),
          everyElement(lessThanOrEqualTo(FirebaseTrashRepository.batchLimit)),
        );
        expect(
          firestore.batches.fold<int>(0, (n, b) => n + b.ops.length),
          count,
        );
      });
    }

    test('signed out, emptyTrash deletes nothing', () async {
      await seed(_me, 2);
      signIn(null);

      await expectLater(
        repository.emptyTrash(),
        throwsA(isA<AuthenticationException>()),
      );
      expect((await trashOf(_me).get()).docs, hasLength(2));
    });
  });
}
