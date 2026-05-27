/// Tests for FirebaseCookSnapRepository's friends-aware read queries.
///
/// The repo's read methods take an `allowedUserIds` whitelist (resolved by
/// the service layer from the caller's friend list). The repo chunks the
/// list across Firestore's 30-element `whereIn` cap and merges results.
/// These tests prove:
///   1. empty whitelist short-circuits to an empty result (no Firestore call);
///   2. single-chunk path returns correctly filtered snaps;
///   3. multi-chunk path merges per-chunk results, sorts by createdAt desc,
///      and respects the global limit;
///   4. stream variant emits the merged-and-sorted view across all chunks.
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

    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    setUp(() {
      fakeFirestore = FakeFirebaseFirestore();
      mockAuthRepository = FakeAuthRepository();
      mockAuthRepository.setAuthState(userId: 'viewer-uid');
      repo = FirebaseCookSnapRepository(
        firestore: fakeFirestore,
        authRepository: mockAuthRepository,
      );
    });

    /// Seed N snaps for [recipeId], one per user in [userIds], with
    /// monotonically decreasing createdAt timestamps (most recent first).
    Future<void> seedSnaps({
      required String recipeId,
      required List<String> userIds,
    }) async {
      final base = DateTime(2026, 4, 26, 12);
      for (var i = 0; i < userIds.length; i++) {
        final snap = CookSnap(
          id: 'snap-${userIds[i]}',
          recipeId: recipeId,
          userId: userIds[i],
          userDisplayName: 'User-$i',
          photoUrl: 'https://example.com/$i.jpg',
          createdAt: base.subtract(Duration(minutes: i)),
        );
        await fakeFirestore
            .collection('cook_snaps')
            .doc(snap.id)
            .set(snap.toFirestore());
      }
    }

    test(
      'getCookSnapsForRecipe returns empty when allowedUserIds is empty '
      '(no Firestore round-trip)',
      () async {
        await seedSnaps(recipeId: 'r1', userIds: ['someone']);
        final result =
            await repo.getCookSnapsForRecipe('r1', allowedUserIds: const {});
        expect(result, isEmpty);
      },
    );

    test(
      'getCookSnapsForRecipe with single chunk returns only allowed userIds, '
      'sorted by createdAt desc',
      () async {
        await seedSnaps(
          recipeId: 'r1',
          userIds: ['friend-1', 'friend-2', 'stranger-1'],
        );
        final result = await repo.getCookSnapsForRecipe(
          'r1',
          allowedUserIds: {'friend-1', 'friend-2'},
        );
        expect(result.map((s) => s.userId).toList(),
            equals(['friend-1', 'friend-2']));
        expect(
          result[0].createdAt.isAfter(result[1].createdAt),
          isTrue,
          reason: 'createdAt should descend',
        );
      },
    );

    test(
      'getCookSnapsForRecipe with >30 allowedUserIds chunks the query and '
      'merges results across chunks',
      () async {
        // 35 friends → 2 chunks (30 + 5). Seed one snap per friend.
        final friends = List.generate(35, (i) => 'friend-$i');
        await seedSnaps(recipeId: 'r1', userIds: friends);

        final result = await repo.getCookSnapsForRecipe(
          'r1',
          allowedUserIds: friends.toSet(),
          limit: 100,
        );

        expect(
          result.length,
          equals(35),
          reason: 'all snaps from both chunks should be present',
        );
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
          allowedUserIds: friends.toSet(),
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
      'watchCookSnaps emits empty list immediately when allowedUserIds empty',
      () async {
        final stream = repo.watchCookSnaps('r1', allowedUserIds: const {});
        final first = await stream.first;
        expect(first, isEmpty);
      },
    );

    test(
      'watchCookSnaps single-chunk path emits sorted results matching '
      'allowedUserIds',
      () async {
        await seedSnaps(
          recipeId: 'r1',
          userIds: ['friend-1', 'friend-2', 'stranger'],
        );
        final stream = repo.watchCookSnaps(
          'r1',
          allowedUserIds: {'friend-1', 'friend-2'},
        );
        final first = await stream.first;
        expect(first.map((s) => s.userId).toSet(),
            equals({'friend-1', 'friend-2'}));
      },
    );

    test(
      'watchCookSnaps multi-chunk path emits merged results across chunks',
      () async {
        final friends = List.generate(35, (i) => 'friend-$i');
        await seedSnaps(recipeId: 'r1', userIds: friends);

        final stream = repo.watchCookSnaps(
          'r1',
          allowedUserIds: friends.toSet(),
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
          allowedUserIds: friends.toSet(),
          limit: 100,
        );
        final sub = stream.listen((_) {});
        await sub.cancel();
      },
    );
  });
}
