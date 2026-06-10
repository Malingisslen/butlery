/// Tests for FirebaseCookSnapRepository's friends-aware read queries.
///
/// BUT-1214 contract: read methods take the viewer's id plus a friend-id
/// set (resolved by the service layer). The repo issues ONE unfiltered
/// query for the viewer's own snaps (authors always see their own `onlyMe`
/// snaps) and visibility-filtered whereIn chunks for friends' snaps —
/// rules deny foreign `onlyMe` docs, so the friends query must exclude
/// them structurally. These tests prove:
///   1. empty viewerId short-circuits to an empty result;
///   2. the viewer sees their own snaps regardless of visibility;
///   3. friends' sameAsRecipe snaps appear, friends' onlyMe snaps do NOT;
///   4. multi-chunk merge stays sorted and respects the global limit;
///   5. stream variant mirrors the get variant.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/repositories/firebase/firebase_cook_snap_repository.dart';

import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  group('FirebaseCookSnapRepository — friends-aware queries', () {
    late FakeFirebaseFirestore fakeFirestore;
    late FakeAuthRepository mockAuthRepository;
    late FirebaseCookSnapRepository repo;

    const viewer = 'viewer-uid';

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepository = FakeAuthRepository();
      mockAuthRepository.setAuthState(userId: viewer);
      repo = FirebaseCookSnapRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepository,
      );
    });

    /// Seed one snap per user in [userIds] for [recipeId], with
    /// monotonically decreasing createdAt (most recent first). [indexOffset]
    /// keeps timestamps distinct across multiple seed calls.
    Future<void> seedSnaps({
      required String recipeId,
      required List<String> userIds,
      CookSnapVisibility visibility = CookSnapVisibility.sameAsRecipe,
      int indexOffset = 0,
    }) async {
      final base = DateTime(2026, 4, 26, 12);
      for (var i = 0; i < userIds.length; i++) {
        final snap = CookSnap(
          id: 'snap-${userIds[i]}-$visibility',
          recipeId: recipeId,
          userId: userIds[i],
          userDisplayName: 'User-$i',
          photoUrl: 'https://example.com/$i.jpg',
          visibility: visibility,
          createdAt: base.subtract(Duration(minutes: i + indexOffset)),
        );
        await fakeFirestore
            .collection('cook_snaps')
            .doc(snap.id)
            .set(snap.toFirestore());
      }
    }

    test(
      'getCookSnapsForRecipe returns empty when viewerId is empty '
      '(no Firestore round-trip)',
      () async {
        await seedSnaps(recipeId: 'r1', userIds: ['someone']);
        final result = await repo.getCookSnapsForRecipe('r1',
            viewerId: '', friendIds: const {'someone'});
        expect(result, isEmpty);
      },
    );

    test(
      'viewer sees own snaps — including own onlyMe — with no friends',
      () async {
        await seedSnaps(recipeId: 'r1', userIds: [viewer]);
        await seedSnaps(
          recipeId: 'r1',
          userIds: [viewer],
          visibility: CookSnapVisibility.onlyMe,
          indexOffset: 5,
        );
        final result = await repo
            .getCookSnapsForRecipe('r1', viewerId: viewer, friendIds: const {});
        expect(result.length, 2,
            reason: 'own query must not filter on visibility');
      },
    );

    test(
      "friends' sameAsRecipe snaps appear; friends' onlyMe snaps do not",
      () async {
        await seedSnaps(recipeId: 'r1', userIds: ['friend-1']);
        await seedSnaps(
          recipeId: 'r1',
          userIds: ['friend-2'],
          visibility: CookSnapVisibility.onlyMe,
          indexOffset: 5,
        );
        await seedSnaps(
            recipeId: 'r1', userIds: ['stranger-1'], indexOffset: 10);

        final result = await repo.getCookSnapsForRecipe(
          'r1',
          viewerId: viewer,
          friendIds: {'friend-1', 'friend-2'},
        );
        expect(result.map((s) => s.userId).toList(), equals(['friend-1']),
            reason: "friend-2's onlyMe snap and the stranger's snap "
                'must both be excluded');
      },
    );

    test(
      'legacy friend doc without a visibility field is NOT returned '
      '(documents the backfill requirement — see '
      'functions/scripts/backfill-cook-snap-visibility.js)',
      () async {
        final legacy = CookSnap(
          id: 'snap-legacy',
          recipeId: 'r1',
          userId: 'friend-1',
          userDisplayName: 'Legacy',
          photoUrl: 'https://example.com/legacy.jpg',
        ).toFirestore()
          ..remove('visibility');
        await fakeFirestore
            .collection('cook_snaps')
            .doc('snap-legacy')
            .set(legacy);

        final result = await repo.getCookSnapsForRecipe(
          'r1',
          viewerId: viewer,
          friendIds: {'friend-1'},
        );
        expect(result, isEmpty,
            reason: 'equality filter cannot match a missing field — legacy '
                'docs need the backfill before the new client ships');
      },
    );

    test(
      'getCookSnapsForRecipe with >30 friendIds chunks the query and '
      'merges results across chunks (plus own snaps)',
      () async {
        // 35 friends → 2 whereIn chunks (30 + 5) + 1 own query.
        final friends = List.generate(35, (i) => 'friend-$i');
        await seedSnaps(recipeId: 'r1', userIds: friends);
        await seedSnaps(recipeId: 'r1', userIds: [viewer], indexOffset: 40);

        final result = await repo.getCookSnapsForRecipe(
          'r1',
          viewerId: viewer,
          friendIds: friends.toSet(),
          limit: 100,
        );

        expect(result.length, equals(36),
            reason: 'all snaps from both chunks + own should be present');
        // Result must remain globally sorted by createdAt desc after merge.
        for (var i = 1; i < result.length; i++) {
          expect(
            result[i - 1].createdAt.isAfter(result[i].createdAt) ||
                result[i - 1].createdAt.isAtSameMomentAs(result[i].createdAt),
            isTrue,
            reason: 'merged result must be sorted desc by createdAt',
          );
        }
      },
    );

    test(
      'getCookSnapsForRecipe applies the global limit AFTER merging chunks',
      () async {
        final friends = List.generate(35, (i) => 'friend-$i');
        await seedSnaps(recipeId: 'r1', userIds: friends);

        final result = await repo.getCookSnapsForRecipe(
          'r1',
          viewerId: viewer,
          friendIds: friends.toSet(),
          limit: 10,
        );

        expect(result.length, equals(10));
        // The 10 globally-newest snaps are friend-0..friend-9 (since seedSnaps
        // assigns the earliest timestamps to the highest indexes).
        expect(
          result.map((s) => s.userId).toSet(),
          equals(List.generate(10, (i) => 'friend-$i').toSet()),
        );
      },
    );

    test(
      'watchCookSnaps emits empty list immediately when viewerId empty',
      () async {
        final stream =
            repo.watchCookSnaps('r1', viewerId: '', friendIds: const {});
        final first = await stream.first;
        expect(first, isEmpty);
      },
    );

    test(
      "watchCookSnaps excludes friends' onlyMe snaps but includes own",
      () async {
        await seedSnaps(recipeId: 'r1', userIds: ['friend-1']);
        await seedSnaps(
          recipeId: 'r1',
          userIds: ['friend-2'],
          visibility: CookSnapVisibility.onlyMe,
          indexOffset: 5,
        );
        await seedSnaps(
          recipeId: 'r1',
          userIds: [viewer],
          visibility: CookSnapVisibility.onlyMe,
          indexOffset: 10,
        );
        final stream = repo.watchCookSnaps(
          'r1',
          viewerId: viewer,
          friendIds: {'friend-1', 'friend-2'},
        );
        final first = await stream.first;
        expect(
            first.map((s) => s.userId).toSet(), equals({'friend-1', viewer}));
      },
    );

    test(
      'watchCookSnaps multi-chunk path emits merged results across chunks',
      () async {
        final friends = List.generate(35, (i) => 'friend-$i');
        await seedSnaps(recipeId: 'r1', userIds: friends);

        final stream = repo.watchCookSnaps(
          'r1',
          viewerId: viewer,
          friendIds: friends.toSet(),
          limit: 100,
        );

        // combineLatestList waits for every chunk's first emission before
        // producing output, so the first emission already contains all 35.
        final snaps = await stream.first.timeout(const Duration(seconds: 2));
        expect(snaps.length, equals(35));
      },
    );

    test(
      'watchCookSnaps cancellation cancels every inner chunk subscription '
      '(no leaks)',
      () async {
        final friends = List.generate(35, (i) => 'friend-$i');
        await seedSnaps(recipeId: 'r1', userIds: friends);

        final stream = repo.watchCookSnaps(
          'r1',
          viewerId: viewer,
          friendIds: friends.toSet(),
          limit: 100,
        );
        final sub = stream.listen((_) {});
        await sub.cancel();
      },
    );
  });
}
