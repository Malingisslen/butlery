/// BUT-544: predicate / filter tests for `BlockedUserFilter`.
///
/// The filter is the seam where comment + chat read paths drop content from
/// users the viewer has blocked.
///
/// BUT-1909 added the lookup group below, which covers the cache and the two
/// error contracts directly. The header used to point at
/// `comment_crud_operations_test.dart` for that; it never covered it — a false
/// coverage pointer is worse than a false count, because it is the sentence a
/// later run cites to skip writing the test.
library;

import 'dart:async';

import 'package:butlery/repositories/firebase/firebase_block_repository.dart';
import 'package:butlery/services/social/blocking/blocked_user_filter.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _MockBlockRepo extends Mock implements FirebaseBlockRepository {}

void main() {
  group('BlockedUserFilter.shouldHide', () {
    test('returns true when authorId is in the blocked set', () {
      expect(
        BlockedUserFilter.shouldHide('alice', {'alice', 'bob'}),
        isTrue,
      );
    });

    test('returns false when authorId is not in the blocked set', () {
      expect(
        BlockedUserFilter.shouldHide('charlie', {'alice', 'bob'}),
        isFalse,
      );
    });

    test('empty blocked set never hides', () {
      expect(
        BlockedUserFilter.shouldHide('alice', const <String>{}),
        isFalse,
      );
    });
  });

  group('BlockedUserFilter.filter', () {
    test('empty blocked set is a no-op (returns all items)', () {
      final input = ['alice:1', 'bob:2', 'charlie:3'];
      final result = BlockedUserFilter.filter<String>(
        input,
        authorOf: (s) => s.split(':').first,
        blockedIds: const <String>{},
      );
      expect(result, equals(input));
    });

    test('drops items whose author is blocked, preserves order', () {
      final input = ['alice:1', 'bob:2', 'charlie:3', 'alice:4'];
      final result = BlockedUserFilter.filter<String>(
        input,
        authorOf: (s) => s.split(':').first,
        blockedIds: const {'alice'},
      );
      expect(result, equals(['bob:2', 'charlie:3']));
    });

    test('returns a fresh list — does not mutate input', () {
      final input = ['alice:1', 'bob:2'];
      final result = BlockedUserFilter.filter<String>(
        input,
        authorOf: (s) => s.split(':').first,
        blockedIds: const {'alice'},
      );
      expect(
        result,
        isNot(same(input)),
        reason:
            'Filter must not return the same instance — callers may '
            'rely on input being untouched (streams, shared caches).',
      );
    });

    test('blocking every author yields an empty list', () {
      final input = ['alice:1', 'bob:2'];
      final result = BlockedUserFilter.filter<String>(
        input,
        authorOf: (s) => s.split(':').first,
        blockedIds: const {'alice', 'bob'},
      );
      expect(result, isEmpty);
    });

    test('handles arbitrary item types via authorOf', () {
      final items = [
        _Item('alice', 1),
        _Item('bob', 2),
      ];
      final result = BlockedUserFilter.filter<_Item>(
        items,
        authorOf: (i) => i.author,
        blockedIds: const {'alice'},
      );
      expect(result.map((i) => i.id), equals([2]));
    });
  });
  // ── BUT-1909: the two lookups differ, and the difference is the point ────
  //
  // `currentBlockedIds` degrades an unreadable list to an EMPTY set, which is
  // right for display — a blank conversation is worse than a briefly unfiltered
  // one. It is wrong for any decision that cannot be taken back, because an
  // empty set is indistinguishable from "nobody is blocked": a refusal branch
  // written against it is DEAD CODE, and that is exactly what shipped in the
  // first draft of `MessagingService.closePoll`.
  group('currentBlockedIds vs requireBlockedIds', () {
    late _MockBlockRepo repo;

    setUp(() {
      repo = _MockBlockRepo();
    });

    test('the CONTROL: currentBlockedIds returns the list when the repository '
        'answers', () {
      // The happy path, so the cases below are read against a filter that does
      // reach the repository at all.
      when(() => repo.getBlockedUserIds()).thenAnswer((_) async => {'alice'});
      when(
        () => repo.watchBlockedUserIds(),
      ).thenAnswer((_) => const Stream.empty());

      final filter = BlockedUserFilter(blockRepository: repo);
      expect(filter.currentBlockedIds(), completion({'alice'}));
    });

    // ── BUT-1917: the INCOMING direction is wired to the incoming reads ──
    //
    // These exist because the extraction that added the second direction is a
    // copy-paste seam: `_incomingCache` is built from `_repo.getBlockedByUserIds`
    // and `_repo.watchBlockedByUserIds`, and pointing either at the OUTGOING
    // method compiles, runs, and silently makes the display tally filter by the
    // wrong direction, and the consumer suites cannot tell: the one case there
    // that builds a REAL filter gives it a repository that throws in both
    // directions.
    //
    // The two directions therefore return DIFFERENT sets in every case below.
    // With one shared fixture a mis-wire is green.

    test(
      'currentBlockedByIds reads the INCOMING list, not the outgoing one',
      () {
        when(() => repo.getBlockedUserIds()).thenAnswer((_) async => {'alice'});
        when(
          () => repo.watchBlockedUserIds(),
        ).thenAnswer((_) => const Stream.empty());
        when(() => repo.getBlockedByUserIds()).thenAnswer((_) async => {'bob'});
        when(
          () => repo.watchBlockedByUserIds(),
        ).thenAnswer((_) => const Stream.empty());

        final filter = BlockedUserFilter(blockRepository: repo);
        expect(filter.currentBlockedByIds(), completion({'bob'}));
      },
    );

    test('the two directions are separate caches, not one', () async {
      when(() => repo.getBlockedUserIds()).thenAnswer((_) async => {'alice'});
      when(
        () => repo.watchBlockedUserIds(),
      ).thenAnswer((_) => const Stream.empty());
      when(() => repo.getBlockedByUserIds()).thenAnswer((_) async => {'bob'});
      when(
        () => repo.watchBlockedByUserIds(),
      ).thenAnswer((_) => const Stream.empty());

      final filter = BlockedUserFilter(blockRepository: repo);

      // Outgoing FIRST, so a single shared cache would latch {'alice'} and hand
      // it back for the incoming call too.
      expect(await filter.currentBlockedIds(), {'alice'});
      expect(await filter.currentBlockedByIds(), {'bob'});
      verify(() => repo.getBlockedByUserIds()).called(1);
    });

    test(
      'requireBlockedByIds reads the INCOMING list from the SERVER',
      () async {
        when(
          () => repo.getBlockedUserIdsFromServer(),
        ).thenAnswer((_) async => {'alice'});
        when(
          () => repo.getBlockedByUserIdsFromServer(),
        ).thenAnswer((_) async => {'bob'});

        final filter = BlockedUserFilter(blockRepository: repo);

        expect(await filter.requireBlockedByIds(), {'bob'});
        // Never the cache-friendly read: offline that answers from the local
        // cache without an error, which is the whole reason this method exists.
        verifyNever(() => repo.getBlockedByUserIds());
      },
    );

    test('requireBlockedByIds THROWS rather than degrading', () async {
      when(
        () => repo.getBlockedByUserIdsFromServer(),
      ).thenThrow(Exception('offline'));

      final filter = BlockedUserFilter(blockRepository: repo);
      await expectLater(filter.requireBlockedByIds(), throwsException);
    });

    test('currentBlockedIds degrades to an empty set', () async {
      when(() => repo.getBlockedUserIds()).thenThrow(Exception('offline'));

      final filter = BlockedUserFilter(blockRepository: repo);
      expect(await filter.currentBlockedIds(), isEmpty);
    });

    test('requireBlockedIds THROWS instead', () async {
      when(
        () => repo.getBlockedUserIdsFromServer(),
      ).thenThrow(Exception('offline'));

      final filter = BlockedUserFilter(blockRepository: repo);
      await expectLater(filter.requireBlockedIds(), throwsException);
    });

    // BUT-1922. The two paths no longer share a read, and this group is what
    // says so. A plain `get()` is answered from the local cache WITHOUT an
    // error while the device is offline, so the display path can latch a set
    // that was never confirmed against the server — and the decision path used
    // to return exactly that set, with no I/O of its own.
    group('the decision path reads from the SERVER', () {
      test('requireBlockedIds never uses the cache-friendly read', () async {
        when(
          () => repo.getBlockedUserIdsFromServer(),
        ).thenAnswer((_) async => {'alice'});

        final filter = BlockedUserFilter(blockRepository: repo);
        expect(await filter.requireBlockedIds(), {'alice'});

        verifyNever(() => repo.getBlockedUserIds());
      });

      test(
        'a cache-latched DISPLAY read does not satisfy the decision path',
        () async {
          // The hole itself. Open a chat offline: the display path answers from
          // the local cache and latches. Before this change `requireBlockedIds`
          // returned that latched set without reading anything, so a block made
          // on the user's OTHER device was invisible to `closePoll` and the
          // ballot it should have removed decided the household's week.
          when(
            () => repo.getBlockedUserIds(),
          ).thenAnswer((_) async => const <String>{});
          final watch = StreamController<Set<String>>.broadcast();
          addTearDown(watch.close);
          when(
            () => repo.watchBlockedUserIds(),
          ).thenAnswer((_) => watch.stream);
          when(
            () => repo.getBlockedUserIdsFromServer(),
          ).thenAnswer((_) async => {'alice'});

          final filter = BlockedUserFilter(blockRepository: repo);
          expect(await filter.currentBlockedIds(), isEmpty);

          expect(
            await filter.requireBlockedIds(),
            {'alice'},
            reason: 'the latched display set is not a claim about the server',
          );
          verify(() => repo.getBlockedUserIdsFromServer()).called(1);
        },
      );

      test('the decision read does NOT seed the display cache', () async {
        // `requireBlockedIds` opens no watch, so anything it wrote into
        // `_cached` would sit there with nothing able to refresh or invalidate
        // it — the display path would then serve a set that can only go stale.
        // Adding `_initialized = true; _cached = ids;` before its return is
        // green across every other case in this file, which is why this one
        // exists.
        when(
          () => repo.getBlockedUserIdsFromServer(),
        ).thenAnswer((_) async => {'alice'});
        when(
          () => repo.getBlockedUserIds(),
        ).thenAnswer((_) async => {'bob'});
        final watch = StreamController<Set<String>>.broadcast();
        addTearDown(watch.close);
        when(() => repo.watchBlockedUserIds()).thenAnswer((_) => watch.stream);

        final filter = BlockedUserFilter(blockRepository: repo);
        expect(await filter.requireBlockedIds(), {'alice'});

        expect(
          await filter.currentBlockedIds(),
          {'bob'},
          reason:
              'the display path must still do its own seeding read and open '
              'its own watch, not inherit the decision path answer',
        );
        verify(() => repo.watchBlockedUserIds()).called(1);
      });

      test('a dispose MID-READ refuses instead of answering', () async {
        // The generation guard, carried onto the new path. Without it a
        // `dispose()` landing on the server read lets an answer this filter no
        // longer speaks for decide a poll.
        final gate = Completer<Set<String>>();
        when(
          () => repo.getBlockedUserIdsFromServer(),
        ).thenAnswer((_) => gate.future);

        final filter = BlockedUserFilter(blockRepository: repo);
        final pending = filter.requireBlockedIds();
        await filter.dispose();
        gate.complete({'alice'});

        await expectLater(pending, throwsStateError);
      });
    });

    test(
      'a failed lookup does not latch an empty list for the session',
      () async {
        // The bug behind the bug. `_initialized` used to be set BEFORE the fetch,
        // so one blip froze an empty block list for the whole app session and
        // every later read served unfiltered content — while `_filterBlocked`'s
        // own comment promised "the next snapshot will retry the lookup". The
        // latch now happens only after success.
        var attempt = 0;
        when(() => repo.getBlockedUserIds()).thenAnswer((_) async {
          attempt++;
          if (attempt == 1) throw Exception('offline');
          return {'alice'};
        });
        when(
          () => repo.watchBlockedUserIds(),
        ).thenAnswer((_) => const Stream.empty());

        final filter = BlockedUserFilter(blockRepository: repo);
        expect(await filter.currentBlockedIds(), isEmpty);
        expect(
          await filter.currentBlockedIds(),
          {'alice'},
          reason: 'the second read must retry, not serve the cached failure',
        );
      },
    );

    test('a watch error invalidates instead of freezing the cache', () async {
      // The second layer of the same fail-open, on the DISPLAY path — since
      // BUT-1922 the decision path never reads this cache at all.
      // `unavailable` on a long-lived listener is routine.
      final errors = StreamController<Set<String>>.broadcast();
      addTearDown(errors.close);
      var fetches = 0;
      when(() => repo.getBlockedUserIds()).thenAnswer((_) async {
        fetches++;
        return {'alice'};
      });
      when(() => repo.watchBlockedUserIds()).thenAnswer((_) => errors.stream);

      final filter = BlockedUserFilter(blockRepository: repo);
      expect(await filter.currentBlockedIds(), {'alice'});
      expect(fetches, 1);

      errors.addError(Exception('unavailable'));
      await Future<void>.delayed(Duration.zero);

      await filter.currentBlockedIds();
      expect(
        fetches,
        2,
        reason:
            'the watch died, so the cached set is no longer a claim about now '
            '— the next read must go back to the repository',
      );
    });

    /// A watch that stays OPEN, as a real Firestore snapshot stream does.
    /// `const Stream.empty()` completes immediately, which fires `onDone` and
    /// invalidates the cache — correct behaviour on a stream that really ended,
    /// but not the state a caching test means to describe.
    StreamController<Set<String>> openWatch() {
      final c = StreamController<Set<String>>.broadcast();
      addTearDown(c.close);
      return c;
    }

    test('concurrent first callers open exactly one watch', () async {
      // The leak the in-flight guard closes. Without it each concurrent caller
      // subscribes, `_subscription` keeps only the last, and the rest are never
      // cancelled — they outlive `dispose()` and keep listening on the
      // disposed filter's query. One cold chat open reaches this from three
      // places at once.
      when(() => repo.getBlockedUserIds()).thenAnswer((_) async {
        await Future<void>.delayed(const Duration(milliseconds: 5));
        return {'alice'};
      });
      final watch = openWatch();
      when(() => repo.watchBlockedUserIds()).thenAnswer((_) => watch.stream);

      final filter = BlockedUserFilter(blockRepository: repo);
      await Future.wait([
        filter.currentBlockedIds(),
        filter.currentBlockedIds(),
        filter.currentBlockedIds(),
      ]);

      verify(() => repo.getBlockedUserIds()).called(1);
      verify(() => repo.watchBlockedUserIds()).called(1);
    });

    test(
      'dispose cancels an in-flight fetch instead of letting it re-latch',
      () async {
        // `social_module.dart` registers this with `dispose: (f) => f.dispose()`.
        // A dispose mid-fetch used to leave the completed fetch re-latching and
        // repopulating the cache with the PREVIOUS user's block list, plus a
        // subscription nobody cancels.
        final gate = Completer<Set<String>>();
        when(() => repo.getBlockedUserIds()).thenAnswer((_) => gate.future);
        // BUT-1922: the decision path has its own server read now, so it needs
        // its own stub — the point of the test is still that the two variants
        // part company on the SAME dispose, so both stubs share one completer.
        when(
          () => repo.getBlockedUserIdsFromServer(),
        ).thenAnswer((_) => gate.future);
        final watch = openWatch();
        when(() => repo.watchBlockedUserIds()).thenAnswer((_) => watch.stream);

        final filter = BlockedUserFilter(blockRepository: repo);
        final pending = filter.currentBlockedIds();
        final pendingRequire = filter.requireBlockedIds();
        await filter.dispose();
        gate.complete({'alice'});

        // The two variants must part company HERE, and this is the assertion
        // that says so. The display one degrades to empty; the refusing one
        // must THROW, because an empty set is indistinguishable from "nobody is
        // blocked" — the neutral-value fail-open this file keeps being caught
        // by, most recently in this very guard.
        expect(await pending, isEmpty);
        await expectLater(pendingRequire, throwsStateError);

        // And the next read must go back to the repository rather than serve
        // the disposed filter's list.
        when(() => repo.getBlockedUserIds()).thenAnswer((_) async => {'bob'});
        expect(await filter.currentBlockedIds(), {'bob'});
      },
    );

    test('a watch that ENDS invalidates too', () async {
      // Not hypothetical: `FirebaseBlockRepository.watchBlockedUserIds` returns
      // `Stream.value({})` when there is no signed-in user, which emits an
      // empty set over the real one and then COMPLETES. Without the `onDone`
      // limb that empty set is latched for the session — the frozen-empty-list
      // fail-open the other two layers just closed, arriving through the door
      // nobody was watching.
      final watch = StreamController<Set<String>>.broadcast();
      var fetches = 0;
      when(() => repo.getBlockedUserIds()).thenAnswer((_) async {
        fetches++;
        return {'alice'};
      });
      when(() => repo.watchBlockedUserIds()).thenAnswer((_) => watch.stream);

      final filter = BlockedUserFilter(blockRepository: repo);
      expect(await filter.currentBlockedIds(), {'alice'});
      expect(fetches, 1);

      await watch.close();
      await Future<void>.delayed(Duration.zero);

      await filter.currentBlockedIds();
      expect(
        fetches,
        2,
        reason: 'a watch that ended is no longer keeping the cache current',
      );
    });

    test('a successful lookup IS cached', () async {
      // The other direction: retrying forever would put a Firestore read on
      // every message emission.
      when(() => repo.getBlockedUserIds()).thenAnswer((_) async => {'alice'});
      final watch = openWatch();
      when(() => repo.watchBlockedUserIds()).thenAnswer((_) => watch.stream);

      final filter = BlockedUserFilter(blockRepository: repo);
      await filter.currentBlockedIds();
      await filter.currentBlockedIds();

      verify(() => repo.getBlockedUserIds()).called(1);
      // The watch too: a mutant that caches the fetch but re-subscribes on
      // every read stays green without this, and leaks a subscription per read.
      verify(() => repo.watchBlockedUserIds()).called(1);
    });
  });
}

class _Item {
  _Item(this.author, this.id);
  final String author;
  final int id;
}
