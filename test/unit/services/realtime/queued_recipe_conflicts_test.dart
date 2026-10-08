// BUT-2213: a queued edit of the user's own recipe that met a newer server
// version becomes the conflict notice (origin queue), is kept 30 days behind
// Återställ (A1, Malin 2026-10-08), waits for a recipe screen opened later,
// and "Behåll min version" goes back through the recipe's own writer on the
// server's revision. Nothing is written to realtime_resources (BUT-2151).

// ignore_for_file: close_sinks

import 'dart:async';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_overwritten_version_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _MockAuthRepository extends Mock implements auth.AuthRepository {}

const _me = 'u1';
final _t0 = DateTime(2026, 10, 8, 12);

Recipe _recipe(String title, int rev) {
  final built = RecipeFactory.build(id: 'r1', title: title, createdBy: _me);
  return Recipe(
    core: built.core,
    type: built.type,
    realtimeData: RecipeRealtimeData(
      lastEditedByUserId: _me,
      lastEditedByDisplayName: 'Malin',
      lastEditedAt: _t0,
    ),
    rev: rev,
  );
}

void main() {
  late FakeFirebaseFirestore fake;
  late _MockAuthRepository syncAuth;
  late StreamController<User?> authStates;
  late List<Recipe> written;
  late RealtimeSyncService sync;

  RealtimeSyncService build({Stream<bool> Function()? queueSettled}) {
    final repoAuth = FakeAuthRepository()
      ..setAuthState(
        user: FakeUser(uid: _me),
        userId: _me,
        isAuthenticated: true,
      );
    return RealtimeSyncService(
      firestoreRepository: FirestoreRepository(firestore: fake),
      authRepository: syncAuth,
      overwrittenVersions: FirebaseOverwrittenVersionRepository(
        firestore: fake,
        authRepository: repoAuth,
      ),
      queueSettled: queueSettled,
      writeOwnRecipe: (recipe) async => written.add(recipe),
    );
  }

  Future<List<OverwrittenVersion>> kept() async {
    final snap = await fake
        .collection(FirestoreCollections.users)
        .doc(_me)
        .collection(FirestoreCollections.overwrittenVersions)
        .get();
    return [
      for (final d in snap.docs)
        OverwrittenVersion.fromFirestore(d.id, d.data())!,
    ];
  }

  setUp(() {
    fake = FakeFirebaseFirestore();
    syncAuth = _MockAuthRepository();
    authStates = StreamController<User?>.broadcast();
    when(() => syncAuth.currentUserId).thenReturn(_me);
    when(
      () => syncAuth.authStateChanges(),
    ).thenAnswer((_) => authStates.stream);
    written = [];
    sync = build();
  });

  tearDown(() async {
    await sync.dispose();
    await authStates.close();
  });

  test('the notice names the user\'s own recipe, the server\'s version as '
      'the one that stayed, and the queue as where it was found', () async {
    final events = <ConflictEvent>[];
    final sub = sync.conflictStream.listen(events.add);

    await withClock(
      Clock.fixed(_t0),
      () => sync.announceQueuedRecipeConflict(
        _recipe('Min ändring', 2),
        _recipe('Från min andra enhet', 3),
      ),
    );
    await pumpEventQueue();
    await sub.cancel();

    final event = events.single;
    expect(event.origin, ConflictOrigin.queue);
    expect(event.entity, ConflictEntity.recipeOwn);
    expect(event.chosenStrategy, ConflictResolutionStrategy.remoteWon);
    expect(event.docId, 'r1');
    expect((event.localValue as RealtimeRecipe).recipe.title, 'Min ändring');
    expect(
      (event.remoteValue as RealtimeRecipe).recipe.title,
      'Från min andra enhet',
    );
    expect(sync.pendingQueuedConflict('r1'), same(event));
    expect(
      (await fake.collection('realtime_resources').get()).docs,
      isEmpty,
      reason: 'BUT-2151: no recipe goes into realtime_resources',
    );
  });

  test('my version is kept 30 days behind Återställ even though the newer '
      'one is my own, from another device (A1)', () async {
    await withClock(
      Clock.fixed(_t0),
      () => sync.announceQueuedRecipeConflict(
        _recipe('Min ändring', 2),
        _recipe('Från min andra enhet', 3),
      ),
    );

    final rows = await kept();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.entity, ConflictEntity.recipeOwn);
    expect(row.resourceType, RealtimeResourceType.recipe);
    expect(row.resourceId, 'r1');
    expect(row.overwrittenBy, _me);
    expect(
      row.expiresAt.difference(row.overwrittenAt),
      OverwrittenVersion.keptFor,
    );
    expect((row.version['recipe'] as Map)['core']['title'], 'Min ändring');
  });

  test(
    'the kept version does not keep who the recipe is shared with',
    () async {
      final local = _recipe('Min ändring', 2);
      final shared = Recipe(
        core: local.core,
        type: local.type,
        realtimeData: local.realtimeData,
        socialData: const RecipeSocialData(
          ownerId: _me,
          memberPermissions: {
            _me: ResourcePermission.owner,
            'u2': ResourcePermission.viewer,
          },
        ),
        rev: 2,
      );

      await sync.announceQueuedRecipeConflict(
        shared,
        _recipe('Från min andra enhet', 3),
      );

      final row = (await kept()).single.version['recipe'] as Map;
      expect(row['socialData'], isNull);
      expect((row['core'] as Map)['title'], 'Min ändring');
    },
  );

  test('"Behåll min version" saves my version through the recipe writer on '
      'the server\'s revision, and the notice is no longer waiting', () async {
    await sync.announceQueuedRecipeConflict(
      _recipe('Min ändring', 2),
      _recipe('Från min andra enhet', 3),
    );
    await pumpEventQueue();
    final event = sync.pendingQueuedConflict('r1')!;

    await sync.keepQueuedRecipe(event);

    expect(written.single.title, 'Min ändring');
    expect(written.single.rev, 3);
    expect(sync.pendingQueuedConflict('r1'), isNull);
  });

  test('closing the banner forgets the waiting notice', () async {
    await sync.announceQueuedRecipeConflict(
      _recipe('Min ändring', 2),
      _recipe('Från min andra enhet', 3),
    );
    await pumpEventQueue();

    sync.clearQueuedConflict('r1');

    expect(sync.pendingQueuedConflict('r1'), isNull);
    expect(written, isEmpty);
  });

  test('while the queue still sends, the notice neither reaches the stream '
      'nor waits for a screen; when it empties it does both', () async {
    await sync.dispose();
    final queue = StreamController<bool>.broadcast();
    addTearDown(queue.close);
    sync = build(
      queueSettled: () async* {
        yield false;
        yield* queue.stream;
      },
    );
    final events = <ConflictEvent>[];
    final sub = sync.conflictStream.listen(events.add);
    addTearDown(sub.cancel);

    await sync.announceQueuedRecipeConflict(
      _recipe('Min ändring', 2),
      _recipe('Från min andra enhet', 3),
    );
    await pumpEventQueue();
    expect(events, isEmpty);
    expect(sync.pendingQueuedConflict('r1'), isNull);

    queue.add(true);
    await pumpEventQueue();
    expect(events, hasLength(1));
    expect(sync.pendingQueuedConflict('r1'), same(events.single));
  });
}
