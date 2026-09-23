/// P5-U26b: a version the user loses to another person's save is kept for 30
/// days and can be restored (produktregler.md:104, :109; PQ-01 = A).
///
/// Driven through the real RealtimeSyncService conflict path (updateResource →
/// shouldResolveConflict → resolveConflict), as the BUT-1265 stream test does,
/// with the real Firebase repository on fake_cloud_firestore. Covers:
/// - remoteWon on the user's own recipe keeps the losing version, under the
///   user's own path, before the winner is written;
/// - localWon keeps nothing (nothing of the user's was lost);
/// - a collaborator's lost edit on someone else's recipe (recipeShared) is not
///   kept here: that is PQ-02's suggestion, not this store;
/// - a store that fails does not stop the sync, and the conflict event (with
///   its 30 s rescue) still goes out;
/// - restore makes the kept version live again and outranks the winner, undo
///   puts the winner back, settle forgets the row;
/// - a version past its 30 days is never offered.
library;

// ignore_for_file: close_sinks

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/overwritten_version.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/repositories/firebase/firebase_overwritten_version_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/repositories/interfaces/overwritten_version_repository.dart';
import 'package:butlery/services/realtime/overwritten_version_service.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';

import 'package:butlery/models/realtime/realtime_menu.dart';

import '../../../infrastructure/builders/realtime_menu_builder.dart';
import '../../../infrastructure/factories/recipe_factory.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

class _MockAuthRepository extends Mock implements auth.AuthRepository {}

class _FailingStore extends Fake implements OverwrittenVersionRepository {
  int calls = 0;

  @override
  Future<OverwrittenVersion> keep(OverwrittenVersion version) async {
    calls++;
    throw StateError('permission-denied');
  }
}

const _owner = 'user_owner';
const _editor = 'editor_user';

RealtimeRecipe _recipe({
  required String id,
  String ownerId = _owner,
  int editCount = 1,
  required DateTime lastEditedAt,
  String lastEditedBy = _owner,
  String name = 'Jag',
  String title = 'Min',
}) => RealtimeRecipe(
  id: id,
  ownerId: ownerId,
  ownerDisplayName: 'Ägare',
  participants: const {
    _owner: ResourcePermission.owner,
    _editor: ResourcePermission.editor,
  },
  createdAt: DateTime(2026, 1, 1, 10),
  lastEditedAt: lastEditedAt,
  lastEditedBy: lastEditedBy,
  lastEditedByDisplayName: name,
  editCount: editCount,
  recipe: RecipeFactory.build(id: id, title: title),
);

void main() {
  late FakeFirebaseFirestore fake;
  late _MockAuthRepository syncAuth;
  late FakeAuthRepository repoAuth;
  late StreamController<User?> authStates;
  late FirebaseOverwrittenVersionRepository store;
  late RealtimeSyncService sync;

  Future<void> seed(RealtimeRecipe r) =>
      fake.collection('realtime_resources').doc(r.id).set(r.toFirestore());

  Future<List<Map<String, dynamic>>> keptRows(String uid) async {
    final snap = await fake
        .collection(FirestoreCollections.users)
        .doc(uid)
        .collection(FirestoreCollections.overwrittenVersions)
        .get();
    return [for (final d in snap.docs) d.data()];
  }

  void signIn(String uid) {
    when(() => syncAuth.currentUserId).thenReturn(uid);
    repoAuth.setAuthState(
      user: FakeUser(uid: uid),
      userId: uid,
      isAuthenticated: true,
    );
  }

  RealtimeSyncService buildSync(OverwrittenVersionRepository? repo) =>
      RealtimeSyncService(
        firestoreRepository: FirestoreRepository(firestore: fake),
        authRepository: syncAuth,
        overwrittenVersions: repo,
      );

  /// Drives one conflict on [id]: a first save by the signed-in user, then a
  /// remote with [remoteEditCount], then the user's second save with
  /// editCount 2. Remote wins when [remoteEditCount] > 2.
  Future<void> conflict(
    RealtimeSyncService service,
    String id, {
    required int remoteEditCount,
    String ownerId = _owner,
  }) async {
    final first = _recipe(
      id: id,
      ownerId: ownerId,
      lastEditedAt: DateTime(2026, 4, 1, 11, 59),
    );
    await seed(first);
    await service.updateResource(first);
    await seed(
      _recipe(
        id: id,
        ownerId: ownerId,
        editCount: remoteEditCount,
        lastEditedAt: DateTime(2026, 4, 1, 12, 0, 1),
        lastEditedBy: ownerId == _owner ? _editor : _owner,
        name: 'Per',
        title: 'Pers',
      ),
    );
    await service.updateResource(
      _recipe(
        id: id,
        ownerId: ownerId,
        editCount: 2,
        lastEditedAt: DateTime(2026, 4, 1, 11, 59, 30),
        lastEditedBy: ownerId == _owner ? _owner : _editor,
      ),
    );
  }

  setUp(() {
    fake = FakeFirebaseFirestore();
    syncAuth = _MockAuthRepository();
    authStates = StreamController<User?>.broadcast();
    when(
      () => syncAuth.authStateChanges(),
    ).thenAnswer((_) => authStates.stream);
    repoAuth = FakeAuthRepository();
    store = FirebaseOverwrittenVersionRepository(
      firestore: fake,
      authRepository: repoAuth,
    );
    signIn(_owner);
    sync = buildSync(store);
  });

  tearDown(() async {
    await sync.dispose();
    await authStates.close();
  });

  group('keeping (RealtimeSyncService.updateResource)', () {
    test('a lost save on my own recipe is kept for me, 30 days', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'r1', remoteEditCount: 9);

        final rows = await keptRows(_owner);
        expect(rows, hasLength(1));
        final kept = OverwrittenVersion.fromFirestore('k', rows.single)!;
        expect(kept.entity, ConflictEntity.recipeOwn);
        expect(kept.resourceId, 'r1');
        expect(kept.overwrittenBy, _editor);
        expect(kept.overwrittenByName, 'Per');
        expect(
          (OverwrittenVersionService.parse(kept) as RealtimeRecipe).title,
          'Min',
          reason: 'the kept version is mine, the one that lost',
        );
        expect(
          kept.expiresAt.difference(kept.overwrittenAt),
          OverwrittenVersion.keptFor,
        );
        expect(await keptRows(_editor), isEmpty);
      });
    });

    test('a lost save on the week menu is kept for me', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        RealtimeMenu week(int editCount, DateTime at, String by, String title) {
          final b = RealtimeMenuBuilder()
              .withId('w1')
              .withOwner(_owner, 'Jag')
              .withParticipant(_editor, ResourcePermission.editor)
              .withTitle(title)
              .withEditCount(editCount)
              .withLastEditedBy(by, by == _owner ? 'Jag' : 'Per');
          b.createdAt = DateTime(2026, 3, 30);
          b.lastEditedAt = at;
          return b.build();
        }

        Future<void> seedMenu(RealtimeMenu m) => fake
            .collection('realtime_resources')
            .doc(m.id)
            .set(m.toFirestore());

        final first = week(1, DateTime(2026, 4, 1, 11, 59), _owner, 'Min');
        await seedMenu(first);
        await sync.updateResource(first);
        await seedMenu(
          week(9, DateTime(2026, 4, 1, 12, 0, 1), _editor, 'Pers'),
        );
        await sync.updateResource(
          week(2, DateTime(2026, 4, 1, 11, 59, 30), _owner, 'Min'),
        );

        final rows = await keptRows(_owner);
        expect(rows, hasLength(1));
        final kept = OverwrittenVersion.fromFirestore('k', rows.single)!;
        expect(kept.entity, ConflictEntity.weekMenu);
        expect(kept.resourceType, RealtimeResourceType.menu);
        expect(
          (OverwrittenVersionService.parse(kept) as RealtimeMenu).menuTitle,
          'Min',
        );
      });
    });

    test(
      'my own save from another device overwriting mine keeps nothing',
      () async {
        await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
          final first = _recipe(
            id: 'r4',
            lastEditedAt: DateTime(2026, 4, 1, 11, 59),
          );
          await seed(first);
          await sync.updateResource(first);
          await seed(
            _recipe(
              id: 'r4',
              editCount: 9,
              lastEditedAt: DateTime(2026, 4, 1, 12, 0, 1),
              title: 'Från min andra enhet',
            ),
          );
          await sync.updateResource(
            _recipe(
              id: 'r4',
              editCount: 2,
              lastEditedAt: DateTime(2026, 4, 1, 11, 59, 30),
            ),
          );

          expect(await keptRows(_owner), isEmpty);
        });
      },
    );

    test('a save that wins keeps nothing', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'r1', remoteEditCount: 1);

        expect(await keptRows(_owner), isEmpty);
      });
    });

    test("a collaborator's lost edit on someone else's recipe is not kept "
        'here (recipeShared, PQ-02)', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        signIn(_editor);
        await conflict(sync, 'r2', remoteEditCount: 9);

        expect(await keptRows(_editor), isEmpty);
        expect(await keptRows(_owner), isEmpty);
      });
    });

    test('a store that fails does not stop the sync, and the 30 s notice '
        'still carries the version', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        final failing = _FailingStore();
        final service = buildSync(failing);
        addTearDown(service.dispose);
        final events = <ConflictEvent>[];
        final sub = service.conflictStream.listen(events.add);

        await conflict(service, 'r3', remoteEditCount: 9);
        await Future<void>.delayed(Duration.zero);
        await sub.cancel();

        expect(failing.calls, 1);
        expect(
          events.single.chosenStrategy,
          ConflictResolutionStrategy.remoteWon,
        );
        expect(
          (events.single.localValue as RealtimeRecipe).title,
          'Min',
          reason: 'the snackbar\'s rescue still has the lost version',
        );
      });
    });
  });

  group('restoring (OverwrittenVersionService)', () {
    test('restore makes my version live, undo puts theirs back, settle '
        'forgets the row', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'r1', remoteEditCount: 9);
        final service = OverwrittenVersionService(
          repository: store,
          syncService: sync,
        );
        final versions = await service
            .watch(entity: ConflictEntity.recipeOwn, resourceId: 'r1')
            .first;
        expect(versions, hasLength(1));

        final receipt = await service.restore(versions.single);
        var live = (await sync.fetchLatestResource<RealtimeRecipe>('r1'))!;
        expect(live.title, 'Min');
        expect(
          live.editCount,
          greaterThan(9),
          reason: 'the restored version outranks the save that overwrote it',
        );
        expect((receipt.replaced as RealtimeRecipe).title, 'Pers');

        await service.undo(receipt);
        live = (await sync.fetchLatestResource<RealtimeRecipe>('r1'))!;
        expect(live.title, 'Pers');
        expect(
          await keptRows(_owner),
          hasLength(1),
          reason: 'after Ångra my version is still kept',
        );

        await service.settle(receipt);
        expect(await keptRows(_owner), isEmpty);
      });
    });

    test('a resource that is gone is not recreated, and the version stays '
        'kept', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'r1', remoteEditCount: 9);
        await fake.collection('realtime_resources').doc('r1').delete();
        final service = OverwrittenVersionService(
          repository: store,
          syncService: sync,
        );
        final version =
            (await service
                    .watch(entity: ConflictEntity.recipeOwn, resourceId: 'r1')
                    .first)
                .single;

        await expectLater(
          () => service.restore(version),
          throwsA(isA<OverwrittenVersionTargetMissing>()),
        );
        expect(
          (await fake.collection('realtime_resources').doc('r1').get()).exists,
          isFalse,
        );
        expect(await keptRows(_owner), hasLength(1));
      });
    });

    test('restore and undo bring back the content only, never who the '
        'recipe is shared with', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'r1', remoteEditCount: 9);
        // After the conflict the owner removes the editor and adds someone.
        // (A whole-document set: an update would merge the participants map.)
        final ref = fake.collection('realtime_resources').doc('r1');
        await ref.set({
          ...(await ref.get()).data()!,
          'participants': {_owner: 'owner', 'new_user': 'editor'},
          'participantIds': [_owner, 'new_user'],
        });
        final service = OverwrittenVersionService(
          repository: store,
          syncService: sync,
        );
        final version =
            (await service
                    .watch(entity: ConflictEntity.recipeOwn, resourceId: 'r1')
                    .first)
                .single;
        expect(
          version.version['participantIds'],
          contains(_editor),
          reason: 'the kept snapshot still lists the removed editor',
        );

        Future<void> expectSharingKept() async {
          final doc =
              (await fake.collection('realtime_resources').doc('r1').get())
                  .data()!;
          expect(doc['participantIds'], [_owner, 'new_user']);
          expect(
            (doc['participants'] as Map).keys,
            unorderedEquals([_owner, 'new_user']),
          );
        }

        final receipt = await service.restore(version);
        final live = (await sync.fetchLatestResource<RealtimeRecipe>('r1'))!;
        expect(live.title, 'Min');
        await expectSharingKept();

        await service.undo(receipt);
        expect(
          (await sync.fetchLatestResource<RealtimeRecipe>('r1'))!.title,
          'Pers',
        );
        await expectSharingKept();
      });
    });

    test('a resource that is no longer active is not brought back', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'r1', remoteEditCount: 9);
        await fake.collection('realtime_resources').doc('r1').update({
          'isActive': false,
        });
        final service = OverwrittenVersionService(
          repository: store,
          syncService: sync,
        );
        final version =
            (await service
                    .watch(entity: ConflictEntity.recipeOwn, resourceId: 'r1')
                    .first)
                .single;

        await expectLater(
          () => service.restore(version),
          throwsA(isA<OverwrittenVersionTargetMissing>()),
        );
        final doc =
            (await fake.collection('realtime_resources').doc('r1').get())
                .data()!;
        expect(doc['isActive'], isFalse);
        expect(doc['title'] ?? doc['name'], isNot('Min'));
        expect(await keptRows(_owner), hasLength(1));
      });
    });

    test('a version past its 30 days is never offered', () async {
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'r1', remoteEditCount: 9);
      });
      final service = OverwrittenVersionService(
        repository: store,
        syncService: sync,
      );
      final kept = OverwrittenVersion.fromFirestore(
        'k',
        (await keptRows(_owner)).single,
      )!;

      final justBefore = kept.expiresAt.subtract(const Duration(minutes: 1));
      await withClock(Clock.fixed(justBefore), () async {
        expect(
          await service.watch(entity: ConflictEntity.recipeOwn).first,
          hasLength(1),
        );
      });
      await withClock(Clock.fixed(kept.expiresAt), () async {
        expect(
          await service.watch(entity: ConflictEntity.recipeOwn).first,
          isEmpty,
        );
      });
    });
  });
}
