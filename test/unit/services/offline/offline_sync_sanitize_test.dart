/// BUT-1819: the offline sync path sanitizes before it writes.
///
/// This is the path the plan's fifth review round found, and it is the one that
/// matters most: it writes straight at `/users/{uid}/recipes` via
/// `FirestoreRepository.setDocument`, never touching `FirebaseRecipeRepository`,
/// so that class's `toFirestore` override — the sanitization chokepoint for the
/// collection — does not run. It is also the sync-a-recipe-created-offline path,
/// the one most likely to be carrying raw imported text.
///
/// A unit test of `sanitizeRecipeText` proves nothing about this call site,
/// which is exactly why this file exists: it asserts on the map handed to
/// Firestore, not on the function.
library;

import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/storage/drift/app_database.dart';
import 'package:butlery/core/storage/drift/daos/recipe_dao.dart';
import 'package:butlery/core/storage/drift/daos/sync_queue_dao.dart';
import 'package:butlery/core/storage/drift/tables/sync_queue.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/services/offline/offline_sync_manager.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../../../test_support/base_unit_test.dart';

class _MockAppDatabase extends Mock implements AppDatabase {}

class _MockRecipeDao extends Mock implements RecipeDao {}

class _MockSyncQueueDao extends Mock implements SyncQueueDao {}

class _MockFirestoreRepository extends Mock implements FirestoreRepository {}

// No hand-rolled `DocumentReference`/`CollectionReference` fakes here.
// `DocumentReference` is `@sealed` (package:meta, not the Dart keyword) and
// `CollectionReference` inherits that through `Query`, so implementing either
// trips `subtype_of_sealed_class`. Other test files silence it with an
// `ignore_for_file`; `FakeFirebaseFirestore` hands out the REAL types instead,
// which is better than silencing a warning about the thing being faked.

void main() {
  const uid = 'test-user-123';

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(SyncOperation.update);
    registerFallbackValue(
      FakeFirebaseFirestore().collection('recipes').doc('fallback'),
    );
    registerFallbackValue(<String, dynamic>{});
  });

  test(
    'a recipe synced from offline is sanitized before it is written',
    () async {
      final db = _MockAppDatabase();
      final recipeDao = _MockRecipeDao();
      final queueDao = _MockSyncQueueDao();
      final firestore = _MockFirestoreRepository();
      final auth = FakeAuthRepository();
      auth.setAuthState(user: FakeUser(), userId: uid, isAuthenticated: true);

      when(() => db.recipeDao).thenReturn(recipeDao);
      when(() => db.syncQueueDao).thenReturn(queueDao);

      // The recipe as it sits in local storage: a hostile source URL, exactly
      // what an import could have produced before the repository was fixed.
      final stored = RecipeFactory.build(
        id: 'r-offline',
        createdBy: uid,
        sourceUrl: 'javascript:alert(1)',
        // An EXPLICIT stamp, not the factory's wall-clock default. With that
        // default, the `updatedAt` assertion below discriminates two wall-clock
        // reads about a millisecond apart, so the mutation kill is luck rather
        // than structure — measured granularity on this machine is ~1 ms.
        // (The real-time guard matches the literal call even inside a comment,
        // which is why this paragraph names it in words.)
        updatedAt: DateTime.utc(2026, 1, 1),
      );

      when(() => queueDao.hasPending(any())).thenAnswer((_) async => true);
      when(() => queueDao.countPending(any())).thenAnswer((_) async => 1);
      when(() => queueDao.getPendingForUser(any())).thenAnswer(
        (_) async => [
          SyncQueueEntry(
            id: 1,
            userId: uid,
            recipeId: 'r-offline',
            operation: SyncOperation.update.name,
            queuedAt: DateTime.utc(2026, 1, 1),
            retryCount: 0,
            lastError: null,
          ),
        ],
      );
      when(() => queueDao.dequeue(any())).thenAnswer((_) async => 1);
      when(() => recipeDao.getRecipe(any(), any())).thenAnswer(
        (_) async => OfflineRecipe(
          id: 'r-offline',
          userId: uid,
          recipeJson: jsonEncode(stored.toJson()),
          updatedAt: DateTime.utc(2026, 1, 1),
          needsSync: true,
          lastSyncedAt: null,
        ),
      );
      when(() => recipeDao.markSynced(any(), any())).thenAnswer((_) async => 1);
      final fakeFirestore = FakeFirebaseFirestore();
      when(() => firestore.userRecipesCollection(any())).thenReturn(
        fakeFirestore.collection('users').doc(uid).collection('recipes'),
      );

      Map<String, dynamic>? written;
      when(() => firestore.setDocument(any(), any())).thenAnswer((inv) async {
        written = inv.positionalArguments[1] as Map<String, dynamic>;
      });

      final manager = OfflineSyncManager(
        database: db,
        firestoreRepository: firestore,
        authRepository: auth,
      );

      await manager.syncPendingChanges(isOnline: true);

      expect(written, isNotNull, reason: 'the sync must actually have written');
      final core = written!['core'] as Map<String, dynamic>;

      // The LIVE pin for the `updatedAt` pass-through. It was pinned only via
      // `addRecipes`, which this repo documents as having no production caller
      // — so the guard was fully tested on a dead path and one tidy-up away
      // from unpinned. Here `sanitizeRecipeText` is the only transform, so the
      // stamp survives or not entirely on that line. If it regresses, every
      // reconnect jumps the whole synced set to the top of "Mina recept",
      // because `watchRecipes` and `loadMoreRecipes` both order on this field.
      final storedStamp = core['updatedAt'];
      expect(
        storedStamp,
        isNotNull,
        reason: 'premise: the field is written at all',
      );
      final stampTime = storedStamp is Timestamp
          ? storedStamp.toDate().toUtc()
          : DateTime.parse(storedStamp as String).toUtc();
      expect(
        stampTime,
        equals(stored.updatedAt.toUtc()),
        reason:
            'a sanitize is not an edit — `Recipe.copyWith` would default this '
            'to `clock.now()`, so the offline copy would arrive claiming sync '
            'time instead of the time it was actually edited',
      );
      expect(
        core['sourceUrl'],
        isEmpty,
        reason:
            'drop `sanitizeRecipeText` here and the raw javascript: URL '
            'reaches Firestore — the repository chokepoint never sees this path',
      );
    },
  );
}
