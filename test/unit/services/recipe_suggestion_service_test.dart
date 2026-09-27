/// P5-U27b: a change to someone else's shared recipe becomes a suggestion,
/// kept 7 days, that the owner accepts or dismisses (produktregler.md:103,
/// :241; PQ-02 = A).
///
/// Driven through the real RealtimeSyncService conflict path (updateResource →
/// shouldResolveConflict → the recipeShared branch), with the real Firebase
/// repository on fake_cloud_firestore, as overwritten_version_service_test
/// does. Covers:
/// - the losing non-owner save is stored as a suggestion with a 7-day expiry,
///   the owner's version stays, nothing of the edit is written to the shared
///   recipe, and the conflict event carries the suggestion's id — even when
///   the edit's counter would have won under the old rule;
/// - without a store, or when storing fails, the package 5 choice applies
///   (no suggestion id on the event), so the edit is never dropped;
/// - the user's own save from another device makes no suggestion;
/// - the repository makes a suggestion only as oneself and never to one's own
///   recipe, lists only by one's own id, and lets only the owner decide;
/// - accept writes the suggested content as the owner, dismiss writes
///   nothing, and a suggestion past its 7 days is never offered.
/// Who may read or write a row on the server is firestore.rules, pinned by
/// functions/src/__tests__/recipe-suggestions-rules.test.ts, because
/// fake_cloud_firestore enforces no rules.
library;

// ignore_for_file: close_sinks

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_suggestion.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_recipe_suggestion_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/repositories/interfaces/recipe_suggestion_repository.dart';
import 'package:butlery/services/realtime/realtime_types.dart';
import 'package:butlery/services/realtime_sync_service.dart';
import 'package:butlery/services/recipe_suggestion_service.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';

class _MockAuthRepository extends Mock implements auth.AuthRepository {}

class _FailingStore extends Fake implements RecipeSuggestionRepository {
  int calls = 0;

  @override
  Stream<List<RecipeSuggestion>> watchMine(String recipeId) =>
      Stream.value(const []);

  @override
  Future<RecipeSuggestion> suggest(RecipeSuggestion suggestion) async {
    calls++;
    throw StateError('permission-denied');
  }
}

const _owner = 'user_owner';
const _member = 'member_user';

RealtimeRecipe _recipe({
  required String id,
  int editCount = 1,
  required DateTime lastEditedAt,
  required String lastEditedBy,
  required String name,
  required String title,
}) => RealtimeRecipe(
  id: id,
  ownerId: _owner,
  ownerDisplayName: 'Ägare',
  participants: const {
    _owner: ResourcePermission.owner,
    _member: ResourcePermission.editor,
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
  late FirebaseRecipeSuggestionRepository store;

  Future<void> seed(RealtimeRecipe r) =>
      fake.collection('realtime_resources').doc(r.id).set(r.toFirestore());

  Future<String?> liveTitle(String id) async {
    final snap = await fake.collection('realtime_resources').doc(id).get();
    return RealtimeRecipe.fromMap(id, snap.data()!).title;
  }

  Future<List<RecipeSuggestion>> rows() async {
    final snap = await fake
        .collection(FirestoreCollections.recipeSuggestions)
        .get();
    return [
      for (final d in snap.docs)
        RecipeSuggestion.fromFirestore(d.id, d.data())!,
    ];
  }

  void signIn(String uid) {
    when(() => syncAuth.currentUserId).thenReturn(uid);
    repoAuth.setAuthState(
      user: FakeUser(uid: uid),
      userId: uid,
      isAuthenticated: true,
    );
  }

  RealtimeSyncService buildSync(RecipeSuggestionRepository? repo) =>
      RealtimeSyncService(
        firestoreRepository: FirestoreRepository(firestore: fake),
        authRepository: syncAuth,
        suggestions: repo,
      );

  /// The member saves the owner's recipe, the owner saves over it, then the
  /// member saves again within the conflict window. The member's second save
  /// carries a HIGHER edit counter than the owner's, so under the resolver's
  /// counter rule it would win: the owner's version must win anyway.
  Future<void> conflict(
    RealtimeSyncService service,
    String id, {
    String remoteBy = _owner,
  }) async {
    final first = _recipe(
      id: id,
      lastEditedAt: DateTime(2026, 4, 1, 11, 59),
      lastEditedBy: _member,
      name: 'Mia',
      title: 'Mias första',
    );
    await seed(first);
    await service.updateResource(first);
    await seed(
      _recipe(
        id: id,
        editCount: 1,
        lastEditedAt: DateTime(2026, 4, 1, 12, 0, 1),
        lastEditedBy: remoteBy,
        name: remoteBy == _owner ? 'Olle' : 'Mia',
        title: 'Olles',
      ),
    );
    await service.updateResource(
      _recipe(
        id: id,
        editCount: 5,
        lastEditedAt: DateTime(2026, 4, 1, 11, 59, 30),
        lastEditedBy: _member,
        name: 'Mia',
        title: 'Mias förslag',
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
    store = FirebaseRecipeSuggestionRepository(
      firestore: fake,
      authRepository: repoAuth,
    );
    signIn(_member);
  });

  tearDown(() async {
    await authStates.close();
  });

  group('keeping a suggestion (RealtimeSyncService.updateResource)', () {
    test('the owner\'s version stays and the member\'s save becomes a '
        'suggestion kept 7 days', () async {
      final sync = buildSync(store);
      addTearDown(sync.dispose);
      final events = <ConflictEvent>[];
      final sub = sync.conflictStream.listen(events.add);
      addTearDown(sub.cancel);

      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'r1');
      });
      await pumpEventQueue();

      expect(
        await liveTitle('r1'),
        'Olles',
        reason: 'the owner\'s version wins; nothing of the edit is written',
      );
      final kept = await rows();
      expect(kept, hasLength(1));
      final s = kept.single;
      expect(s.recipeId, 'r1');
      expect(s.ownerId, _owner);
      expect(s.suggesterId, _member);
      expect(s.status, RecipeSuggestionStatus.pending);
      expect(s.expiresAt.difference(s.createdAt), const Duration(days: 7));
      expect(RealtimeRecipe.fromMap('r1', s.suggestion).title, 'Mias förslag');

      expect(events, hasLength(1));
      expect(events.single.entity, ConflictEntity.recipeShared);
      expect(
        events.single.chosenStrategy,
        ConflictResolutionStrategy.remoteWon,
      );
      expect(events.single.suggestionId, s.id);
      expect(events.single.docId, 'r1');
    });

    test('without a store the package 5 choice applies (PQ-02 = A)', () async {
      final sync = buildSync(null);
      addTearDown(sync.dispose);
      final events = <ConflictEvent>[];
      final sub = sync.conflictStream.listen(events.add);
      addTearDown(sub.cancel);

      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'r2');
      });
      await pumpEventQueue();

      expect(await rows(), isEmpty);
      expect(events, hasLength(1));
      expect(events.single.suggestionId, isNull);
    });

    test('a store that fails falls back to the package 5 choice', () async {
      final failing = _FailingStore();
      final sync = buildSync(failing);
      addTearDown(sync.dispose);
      final events = <ConflictEvent>[];
      final sub = sync.conflictStream.listen(events.add);
      addTearDown(sub.cancel);

      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'r3');
      });
      await pumpEventQueue();

      expect(failing.calls, 1);
      expect(events, hasLength(1));
      expect(events.single.suggestionId, isNull);
    });

    test('my own save from another device makes no suggestion', () async {
      final sync = buildSync(store);
      addTearDown(sync.dispose);
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'r4', remoteBy: _member);
      });
      expect(await rows(), isEmpty);
    });
  });

  group('the store (FirebaseRecipeSuggestionRepository)', () {
    RecipeSuggestion made({
      String recipeId = 'r1',
      String suggesterId = _member,
      String ownerId = _owner,
      DateTime? at,
    }) => RecipeSuggestion.create(
      recipeId: recipeId,
      ownerId: ownerId,
      suggesterId: suggesterId,
      suggestion: const {'title': 'x'},
      at: at ?? DateTime.utc(2026, 4, 1, 12),
    );

    test('a suggestion is made only as oneself', () async {
      await expectLater(
        store.suggest(made(suggesterId: 'someone_else')),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('an owner cannot suggest to their own recipe', () async {
      signIn(_owner);
      await expectLater(
        store.suggest(made(suggesterId: _owner)),
        throwsA(isA<PermissionDeniedException>()),
      );
    });

    test('each party lists by their own id, per recipe', () async {
      await store.suggest(made());
      await store.suggest(made(recipeId: 'r2'));
      expect(await store.watchMine('r1').first, hasLength(1));
      expect(await store.watchToMe('r1').first, isEmpty);
      signIn(_owner);
      expect(await store.watchToMe('r1').first, hasLength(1));
      expect(await store.watchMine('r1').first, isEmpty);
    });

    test('only the owner decides, and a decision is never pending', () async {
      final s = await store.suggest(made());
      await expectLater(
        store.decide(s.id, RecipeSuggestionStatus.accepted),
        throwsA(isA<PermissionDeniedException>()),
      );
      signIn(_owner);
      await expectLater(
        store.decide(s.id, RecipeSuggestionStatus.pending),
        throwsArgumentError,
      );
      await store.decide(s.id, RecipeSuggestionStatus.dismissed);
      expect((await rows()).single.status, RecipeSuggestionStatus.dismissed);
    });
  });

  group('deciding (RecipeSuggestionService)', () {
    late RealtimeSyncService sync;
    late RecipeSuggestionService service;

    Future<RecipeSuggestion> suggested(String id) async {
      await seed(
        _recipe(
          id: id,
          lastEditedAt: DateTime(2026, 4, 1, 12),
          lastEditedBy: _owner,
          name: 'Olle',
          title: 'Olles',
        ),
      );
      final edit = _recipe(
        id: id,
        editCount: 2,
        lastEditedAt: DateTime(2026, 4, 1, 12, 1),
        lastEditedBy: _member,
        name: 'Mia',
        title: 'Mias förslag',
      );
      signIn(_member);
      final s = await store.suggest(
        RecipeSuggestion.create(
          recipeId: id,
          ownerId: _owner,
          suggesterId: _member,
          suggestion: edit.toFirestore(),
          at: clock.now(),
        ),
      );
      signIn(_owner);
      return s;
    }

    setUp(() {
      sync = buildSync(store);
      service = RecipeSuggestionService(repository: store, syncService: sync);
    });

    tearDown(() => sync.dispose());

    test('accept makes the suggestion the recipe, as the owner', () async {
      final s = await suggested('a1');
      await service.accept(s);

      expect(await liveTitle('a1'), 'Mias förslag');
      final live = await fake.collection('realtime_resources').doc('a1').get();
      final parsed = RealtimeRecipe.fromMap('a1', live.data()!);
      expect(parsed.lastEditedBy, _owner);
      expect(parsed.participants[_member], ResourcePermission.editor);
      expect((await rows()).single.status, RecipeSuggestionStatus.accepted);
      expect(await service.watchPendingToMe('a1').first, isEmpty);
    });

    test('dismiss writes nothing to the recipe', () async {
      final s = await suggested('d1');
      await service.dismiss(s);

      expect(await liveTitle('d1'), 'Olles');
      expect((await rows()).single.status, RecipeSuggestionStatus.dismissed);
      signIn(_member);
      final mine = await service.watchMine('d1').first;
      expect(mine.single.status, RecipeSuggestionStatus.dismissed);
    });

    test('a suggestion to a recipe that is gone cannot be accepted', () async {
      final s = await suggested('g1');
      await fake.collection('realtime_resources').doc('g1').delete();
      await expectLater(
        service.accept(s),
        throwsA(isA<RecipeSuggestionTargetMissing>()),
      );
      expect((await rows()).single.status, RecipeSuggestionStatus.pending);
    });

    test('a suggestion past its 7 days is never offered', () async {
      await withClock(Clock.fixed(DateTime.utc(2026, 4, 1, 12)), () async {
        await suggested('e1');
      });
      await withClock(Clock.fixed(DateTime.utc(2026, 4, 8, 11)), () async {
        expect(await service.watchPendingToMe('e1').first, hasLength(1));
      });
      await withClock(Clock.fixed(DateTime.utc(2026, 4, 8, 12, 1)), () async {
        expect(await service.watchPendingToMe('e1').first, isEmpty);
      });
    });
  });

  group('one pending suggestion per member (Q6-07 = B)', () {
    test('a conflict while my suggestion waits gets the package 5 choice, '
        'not a second suggestion', () async {
      final waiting = await store.suggest(
        RecipeSuggestion.create(
          recipeId: 'q1',
          ownerId: _owner,
          suggesterId: _member,
          suggestion: const {'title': 'Mias första förslag'},
          at: DateTime(2026, 4, 1, 11),
        ),
      );
      final sync = buildSync(store);
      addTearDown(sync.dispose);
      final events = <ConflictEvent>[];
      final sub = sync.conflictStream.listen(events.add);
      addTearDown(sub.cancel);

      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'q1');
      });
      await pumpEventQueue();

      final kept = await rows();
      expect(kept.map((s) => s.id), [waiting.id]);
      expect(events, hasLength(1));
      expect(
        events.single.suggestionId,
        isNull,
        reason:
            'the choice (Behåll min version / Använd deras) applies, so '
            'the edit is not dropped silently',
      );
    });

    test('a decided suggestion no longer blocks a new one', () async {
      final first = await store.suggest(
        RecipeSuggestion.create(
          recipeId: 'q2',
          ownerId: _owner,
          suggesterId: _member,
          suggestion: const {'title': 'x'},
          at: DateTime(2026, 4, 1, 11),
        ),
      );
      signIn(_owner);
      await store.decide(first.id, RecipeSuggestionStatus.dismissed);
      signIn(_member);
      final sync = buildSync(store);
      addTearDown(sync.dispose);
      await withClock(Clock.fixed(DateTime(2026, 4, 1, 12)), () async {
        await conflict(sync, 'q2');
      });
      expect(await rows(), hasLength(2));
    });
  });

  group('a member\'s edit is a suggestion (Q6-08 = A)', () {
    late RealtimeSyncService sync;
    late RecipeSuggestionService service;
    late Map<String, Recipe> library;
    late List<Recipe> written;

    Recipe ownersRecipe(String id) => RecipeFactory.build(
      id: id,
      title: 'Olles pannkakor',
      ingredients: ['3 dl mjöl'],
      instructions: ['Vispa'],
      imageUrls: ['https://example.com/p.jpg'],
      createdBy: _owner,
      socialData: const RecipeSocialData(
        ownerId: _owner,
        memberPermissions: {_member: ResourcePermission.editor},
      ),
    );

    setUp(() {
      sync = buildSync(store);
      library = {};
      written = [];
      service = RecipeSuggestionService(
        repository: store,
        syncService: sync,
        readOwnRecipe: (id) async => library[id],
        writeOwnRecipe: (r) async {
          written.add(r);
          library[r.id] = r;
        },
      );
    });

    tearDown(() => sync.dispose());

    Recipe edited(String id) => ownersRecipe(
      id,
    ).copyWith(title: 'Mias pannkakor', instructions: ['Vispa', 'Stek i smör']);

    test('Spara keeps a pending suggestion and writes nothing', () async {
      final s = await withClock(
        Clock.fixed(DateTime.utc(2026, 4, 1, 12)),
        () => service.suggestEdit(
          edited: edited('m1'),
          ownerId: _owner,
          suggesterId: _member,
        ),
      );

      final kept = (await rows()).single;
      expect(kept.id, s.id);
      expect(kept.recipeId, 'm1');
      expect(kept.ownerId, _owner);
      expect(kept.suggesterId, _member);
      expect(kept.status, RecipeSuggestionStatus.pending);
      expect(
        kept.expiresAt.difference(kept.createdAt),
        RecipeSuggestion.keptFor,
      );
      expect(
        RealtimeRecipe.fromMap('m1', kept.suggestion).title,
        'Mias pannkakor',
      );
      expect(written, isEmpty, reason: 'a member never writes the recipe');
      expect(
        (await fake.collection('realtime_resources').get()).docs,
        isEmpty,
      );
    });

    test('a second edit while one waits is refused, and nothing is '
        'stored', () async {
      final first = await service.suggestEdit(
        edited: edited('m2'),
        ownerId: _owner,
        suggesterId: _member,
      );
      await expectLater(
        service.suggestEdit(
          edited: edited('m2').copyWith(title: 'Mias andra'),
          ownerId: _owner,
          suggesterId: _member,
        ),
        throwsA(
          isA<RecipeSuggestionAlreadyWaiting>().having(
            (e) => e.waiting.id,
            'waiting',
            first.id,
          ),
        ),
      );
      expect(await rows(), hasLength(1));

      // Another recipe is not blocked by it.
      await service.suggestEdit(
        edited: edited('m3'),
        ownerId: _owner,
        suggesterId: _member,
      );
      expect(await rows(), hasLength(2));
    });

    test('the owner sees the changed fields and accepts them into their own '
        'recipe, which keeps its sharing', () async {
      final s = await service.suggestEdit(
        edited: edited('m4'),
        ownerId: _owner,
        suggesterId: _member,
      );
      signIn(_owner);
      library['m4'] = ownersRecipe('m4');

      final diff = await service.diffAgainstLive(s);
      expect(diff.changedFields.map((f) => f.fieldKey), [
        'instructions',
        'title',
      ]);

      await service.accept(s);

      final after = written.single;
      expect(after.title, 'Mias pannkakor');
      expect(after.instructions, ['Vispa', 'Stek i smör']);
      expect(after.ingredients, ['3 dl mjöl']);
      expect(after.imageUrls, ['https://example.com/p.jpg']);
      expect(after.createdBy, _owner);
      expect(after.socialData?.ownerId, _owner);
      expect(
        after.socialData?.memberPermissions,
        {
          _member: ResourcePermission.editor,
        },
        reason: 'a suggestion never changes access',
      );
      expect((await rows()).single.status, RecipeSuggestionStatus.accepted);
    });

    test('dismissing writes nothing to the owner\'s recipe', () async {
      final s = await service.suggestEdit(
        edited: edited('m5'),
        ownerId: _owner,
        suggesterId: _member,
      );
      signIn(_owner);
      library['m5'] = ownersRecipe('m5');
      await service.dismiss(s);
      expect(written, isEmpty);
      expect((await rows()).single.status, RecipeSuggestionStatus.dismissed);
    });
  });
}
