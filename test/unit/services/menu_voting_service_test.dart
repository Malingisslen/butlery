/// Live-menu voting end to end below the view model: the real service over the
/// real ballot repository on a fake Firestore (BUT-2118). Every assertion reads
/// what actually landed in the stored documents.
///
/// `FakeFirebaseFirestore.runTransaction` is a passthrough, so nothing here
/// speaks for atomicity; it speaks for what is written and what is refused.
library;

import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/firebase/firebase_menu_voting_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/menu_voting_repository.dart';
import 'package:butlery/services/menu_voting_service.dart';
import 'package:butlery/services/permission_service.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

const _menu = 'menu-1';
const _starter = 'starter';
const _anna = 'anna';
const _bo = 'bo';
const _everyone = {_starter, _anna, _bo};

final _t0 = DateTime.utc(2026, 10, 9, 12);

void main() {
  late FakeFirebaseFirestore firestore;
  late FakeAuthRepository auth;
  late FakePermissionService permissions;
  late FirebaseMenuVotingRepository repository;
  late MenuVotingService service;

  final soup = RecipeFactory.build(id: 'soup', title: 'Soppa');
  final stew = RecipeFactory.build(id: 'stew', title: 'Gryta');
  final pie = RecipeFactory.build(id: 'pie', title: 'Paj');

  // The service reads the permission service and the repository the auth
  // repository, so a person has to be signed in on both.
  void signInAs(String uid) {
    auth.setAuthState(userId: uid);
    permissions.setPermissionState(currentUserId: uid);
  }

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    firestore = FakeFirebaseFirestore();
    auth = FakeAuthRepository();
    permissions = MockFactory.createPermissionService();
    repository = FirebaseMenuVotingRepository(
      authRepository: auth,
      firestore: firestore,
    );
    TestServiceLocator.registerMock<AuthRepository>(auth);
    TestServiceLocator.registerMock<PermissionService>(permissions);
    TestServiceLocator.registerMock<MenuVotingRepository>(repository);
    service = MenuVotingService();
    signInAs(_starter);
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  Future<T> at<T>(DateTime moment, Future<T> Function() action) =>
      withClock(Clock.fixed(moment), action);

  Future<MenuBallot?> ballotOf(String uid) async {
    final snap = await firestore
        .collection(FirestoreCollections.realtimeResources)
        .doc(_menu)
        .collection(FirestoreCollections.liveMenuVotes)
        .doc(uid)
        .get();
    return snap.exists ? MenuBallot.fromMap(uid, snap.data()!) : null;
  }

  Future<MenuSlotVote> theVote({String slot = 'Middag#0'}) async {
    final documents = await repository.watchBallots(_menu).first;
    return MenuSlotVote.deriveAll(
      documents,
      _everyone,
    ).firstWhere((v) => v.slotKey == slot);
  }

  Future<bool> start({DateTime? when, Recipe? against}) => at(
    when ?? _t0,
    () => service.startVote(
      menuId: _menu,
      category: 'Middag',
      slotIndex: 0,
      current: soup,
      proposal: against ?? stew,
    ),
  );

  group('startVote', () {
    test('writes the starter\'s own vote on the slot: the dish now and the '
        'proposal, open for a day', () async {
      expect(await start(), isTrue);

      final vote = (await ballotOf(_starter))!.started['Middag#0']!;
      expect(vote.options.map((o) => o.recipeId), ['soup', 'stew']);
      expect(vote.options.map((o) => o.recipeName), ['Soppa', 'Gryta']);
      expect(vote.options.every((o) => o.votersBefore == 0), isTrue);
      expect(
        vote.deadline.isAtSameMomentAs(_t0.add(MenuVotingService.votingWindow)),
        isTrue,
      );
      expect(vote.createdAt.isAtSameMomentAs(_t0), isTrue);
    });

    test(
      'stores the retention stamp the rules ask for on the document',
      () async {
        await start();

        final raw = await firestore
            .collection(FirestoreCollections.realtimeResources)
            .doc(_menu)
            .collection(FirestoreCollections.liveMenuVotes)
            .doc(_starter)
            .get();
        expect(raw.data()!['userId'], _starter);
        expect(raw.data()!.containsKey('updatedAt'), isTrue);
        expect(
          (raw.data()!['expireAt'] as Timestamp).toDate().isAtSameMomentAs(
            _t0.add(FirebaseMenuVotingRepository.retention),
          ),
          isTrue,
        );
      },
    );

    test('is refused while the slot\'s vote is still running, and the '
        'running vote is left as it was', () async {
      await start();
      final first = (await ballotOf(_starter))!.started['Middag#0']!.id;

      final again = await start(
        when: _t0.add(const Duration(hours: 1)),
        against: pie,
      );

      expect(again, isFalse);
      final stored = (await ballotOf(_starter))!.started['Middag#0']!;
      expect(stored.id, first);
      expect(stored.options.map((o) => o.recipeId), ['soup', 'stew']);
    });

    test('may start over once the vote ran out', () async {
      await start();
      final first = (await ballotOf(_starter))!.started['Middag#0']!.id;

      final again = await start(
        when: _t0.add(const Duration(hours: 25)),
        against: pie,
      );

      expect(again, isTrue);
      final stored = (await ballotOf(_starter))!.started['Middag#0']!;
      expect(stored.id, isNot(first));
      expect(stored.options.map((o) => o.recipeId), ['soup', 'pie']);
    });

    test('may start over after settling, and the old settlement goes with the '
        'old vote', () async {
      await start();
      final first = await at(_t0, () async => (await theVote()));
      await at(_t0, () => service.release(_menu, first));
      expect((await ballotOf(_starter))!.resolved, isNotEmpty);

      final again = await start(when: _t0.add(const Duration(hours: 1)));

      expect(again, isTrue);
      final ballot = (await ballotOf(_starter))!;
      expect(ballot.started['Middag#0']!.id, isNot(first.id));
      expect(ballot.resolved, isEmpty);
    });

    test('another slot gets its own vote beside it', () async {
      await start();

      final other = await at(
        _t0,
        () => service.startVote(
          menuId: _menu,
          category: 'Lunch',
          slotIndex: 2,
          current: soup,
          proposal: pie,
        ),
      );

      expect(other, isTrue);
      expect(
        (await ballotOf(_starter))!.started.keys,
        unorderedEquals(['Middag#0', 'Lunch#2']),
      );
    });

    test('nobody signed in: nothing is written', () async {
      auth.setAuthState();
      permissions.setPermissionState(currentUserId: null);

      expect(await start(), isFalse);

      expect(await ballotOf(_starter), isNull);
    });
  });

  group('castVote', () {
    late MenuSlotVote vote;

    setUp(() async {
      await start();
      vote = await at(_t0, theVote);
    });

    test(
      'puts the choice on the voter\'s own document, not the starter\'s',
      () async {
        signInAs(_anna);

        final ok = await at(
          _t0,
          () => service.castVote(_menu, vote, vote.alternatives.last.id),
        );

        expect(ok, isTrue);
        expect((await ballotOf(_anna))!.ballots, {
          vote.id: vote.alternatives.last.id,
        });
        expect((await ballotOf(_starter))!.ballots, isEmpty);
      },
    );

    test(
      'is locked: a second cast is refused and the first choice stands',
      () async {
        signInAs(_anna);
        final first = vote.alternatives.first.id;
        final second = vote.alternatives.last.id;
        await at(_t0, () => service.castVote(_menu, vote, first));

        final changed = await at(
          _t0,
          () => service.castVote(_menu, vote, second),
        );

        expect(changed, isFalse);
        expect((await ballotOf(_anna))!.ballots, {vote.id: first});
      },
    );

    test('an option that is not on the vote is refused', () async {
      signInAs(_anna);

      final ok = await at(_t0, () => service.castVote(_menu, vote, 'smuggled'));

      expect(ok, isFalse);
      expect(await ballotOf(_anna), isNull);
    });

    test('a vote that ran out takes no more ballots', () async {
      signInAs(_anna);

      final ok = await at(
        _t0.add(const Duration(hours: 25)),
        () => service.castVote(_menu, vote, vote.alternatives.first.id),
      );

      expect(ok, isFalse);
      expect(await ballotOf(_anna), isNull);
    });
  });

  group('propose', () {
    late MenuSlotVote vote;

    setUp(() async {
      await start();
      vote = await at(_t0, theVote);
    });

    test('adds the dish to the proposer\'s document, remembering how many had '
        'already voted', () async {
      signInAs(_anna);
      await at(
        _t0,
        () => service.castVote(_menu, vote, vote.alternatives.first.id),
      );
      signInAs(_bo);
      final seen = await at(_t0, theVote);

      final ok = await at(_t0, () => service.propose(_menu, seen, pie));

      expect(ok, isTrue);
      final proposal = (await ballotOf(_bo))!.proposals[vote.id]!;
      expect(proposal.recipeId, 'pie');
      expect(proposal.votersBefore, 1);
      final derived = await at(_t0, theVote);
      expect(derived.alternatives.map((o) => o.recipeId), [
        'soup',
        'stew',
        'pie',
      ]);
    });

    test('is once per person and vote', () async {
      signInAs(_bo);
      await at(_t0, () => service.propose(_menu, vote, pie));

      final again = await at(_t0, () => service.propose(_menu, vote, stew));

      expect(again, isFalse);
      expect(
        (await ballotOf(_bo))!.proposals[vote.id]!.recipeId,
        'pie',
      );
    });

    test('is refused once the vote ran out', () async {
      signInAs(_bo);

      final ok = await at(
        _t0.add(const Duration(hours: 25)),
        () => service.propose(_menu, vote, pie),
      );

      expect(ok, isFalse);
      expect(await ballotOf(_bo), isNull);
    });
  });

  group('settling', () {
    late MenuSlotVote vote;

    setUp(() async {
      await start();
      vote = await at(_t0, theVote);
    });

    test('recording a winner writes the starter\'s resolution', () async {
      final ok = await at(
        _t0,
        () => service.recordWinner(_menu, vote, vote.alternatives.last.id),
      );

      expect(ok, isTrue);
      final resolution = (await ballotOf(_starter))!.resolved[vote.id]!;
      expect(resolution.outcome, VoteOutcome.winner);
      expect(resolution.optionId, vote.alternatives.last.id);
      expect(resolution.at.isAtSameMomentAs(_t0), isTrue);
    });

    test('releasing writes a resolution with no option', () async {
      final ok = await at(_t0, () => service.release(_menu, vote));

      expect(ok, isTrue);
      final resolution = (await ballotOf(_starter))!.resolved[vote.id]!;
      expect(resolution.outcome, VoteOutcome.released);
      expect(resolution.optionId, isNull);
    });

    test('only the person who started the vote can settle it', () async {
      signInAs(_anna);

      final won = await at(
        _t0,
        () => service.recordWinner(_menu, vote, vote.alternatives.first.id),
      );
      final released = await at(_t0, () => service.release(_menu, vote));

      expect(won, isFalse);
      expect(released, isFalse);
      expect(await ballotOf(_anna), isNull);
      expect((await ballotOf(_starter))!.resolved, isEmpty);
    });

    test('a settled vote cannot be settled again', () async {
      await at(
        _t0,
        () => service.recordWinner(_menu, vote, vote.alternatives.first.id),
      );

      final changed = await at(_t0, () => service.release(_menu, vote));

      expect(changed, isFalse);
      expect(
        (await ballotOf(_starter))!.resolved[vote.id]!.outcome,
        VoteOutcome.winner,
      );
    });
  });

  group('reopen', () {
    late MenuSlotVote vote;

    setUp(() async {
      await start();
      vote = await at(_t0, theVote);
    });

    test('gives a vote that ran out another day from now', () async {
      final later = _t0.add(const Duration(hours: 30));

      final ok = await at(later, () => service.reopen(_menu, vote));

      expect(ok, isTrue);
      final stored = (await ballotOf(_starter))!.started['Middag#0']!;
      expect(
        stored.deadline.isAtSameMomentAs(
          later.add(MenuVotingService.votingWindow),
        ),
        isTrue,
      );
      expect(stored.id, vote.id, reason: 'the same vote, not a new one');
      expect(
        stored.options.map((o) => o.id),
        vote.alternatives.map((o) => o.id),
      );
    });

    test('only the starter can reopen it', () async {
      signInAs(_anna);

      final ok = await at(
        _t0.add(const Duration(hours: 30)),
        () => service.reopen(_menu, vote),
      );

      expect(ok, isFalse);
      expect(await ballotOf(_anna), isNull);
      expect(
        (await ballotOf(
          _starter,
        ))!.started['Middag#0']!.deadline.isAtSameMomentAs(vote.deadline),
        isTrue,
      );
    });

    test('a settled vote stays closed', () async {
      await at(_t0, () => service.release(_menu, vote));

      final ok = await at(
        _t0.add(const Duration(hours: 30)),
        () => service.reopen(_menu, vote),
      );

      expect(ok, isFalse);
      expect(
        (await ballotOf(
          _starter,
        ))!.started['Middag#0']!.deadline.isAtSameMomentAs(vote.deadline),
        isTrue,
      );
    });
  });

  group('a vote that was replaced while someone still held the old one', () {
    late MenuSlotVote old;
    late MenuSlotVote current;

    setUp(() async {
      await start();
      old = await at(_t0, theVote);
      await start(when: _t0.add(const Duration(hours: 25)), against: pie);
      current = await at(_t0.add(const Duration(hours: 25)), theVote);
    });

    Future<void> expectCurrentUntouched() async {
      final stored = (await ballotOf(_starter))!;
      expect(stored.started['Middag#0']!.id, current.id);
      expect(
        stored.started['Middag#0']!.deadline.isAtSameMomentAs(current.deadline),
        isTrue,
      );
      expect(stored.resolved, isEmpty);
    }

    test('premise: the slot now holds a different vote', () {
      expect(current.id, isNot(old.id));
    });

    test('reopening the old one is refused and does not extend the new '
        'one', () async {
      final ok = await at(
        _t0.add(const Duration(hours: 26)),
        () => service.reopen(_menu, old),
      );

      expect(ok, isFalse);
      await expectCurrentUntouched();
    });

    test('releasing the old one is refused and does not settle the new '
        'one', () async {
      final ok = await at(
        _t0.add(const Duration(hours: 26)),
        () => service.release(_menu, old),
      );

      expect(ok, isFalse);
      await expectCurrentUntouched();
    });

    test('recording a winner on the old one is refused too', () async {
      final ok = await at(
        _t0.add(const Duration(hours: 26)),
        () => service.recordWinner(_menu, old, old.alternatives.first.id),
      );

      expect(ok, isFalse);
      await expectCurrentUntouched();
    });
  });

  group('a vote that is already settled', () {
    late MenuSlotVote settled;

    setUp(() async {
      await start();
      final open = await at(_t0, theVote);
      await at(
        _t0,
        () => service.recordWinner(_menu, open, open.alternatives.first.id),
      );
      settled = await at(_t0, theVote);
    });

    test('premise: the vote is settled while its deadline is still ahead', () {
      expect(settled.state, SlotVoteState.decided);
      expect(settled.deadline.isAfter(_t0), isTrue);
    });

    test('takes no more ballots', () async {
      signInAs(_anna);

      final ok = await at(
        _t0,
        () => service.castVote(_menu, settled, settled.alternatives.last.id),
      );

      expect(ok, isFalse);
      expect(await ballotOf(_anna), isNull);
    });

    test('takes no more dishes', () async {
      signInAs(_bo);

      final ok = await at(_t0, () => service.propose(_menu, settled, pie));

      expect(ok, isFalse);
      expect(await ballotOf(_bo), isNull);
    });
  });

  group('the ballot repository', () {
    test('refuses to write a document that is not the signed-in user\'s and '
        'writes nothing', () async {
      signInAs(_anna);

      await expectLater(
        repository.updateOwnBallot(
          _menu,
          (current) => MenuBallot(userId: _starter, ballots: const {'v': 'a'}),
        ),
        throwsA(isA<PermissionDeniedException>()),
      );

      expect(await ballotOf(_starter), isNull);
      expect(await ballotOf(_anna), isNull);
    });

    test('hands the change the stored document, or an empty one, and writes '
        'nothing when the same instance comes back', () async {
      MenuBallot? seen;

      await repository.updateOwnBallot(_menu, (current) {
        seen = current;
        return current;
      });

      expect(seen!.userId, _starter);
      expect(seen!.isEmpty, isTrue);
      expect(await ballotOf(_starter), isNull);
    });

    test('lists every person\'s document on the menu and none from another '
        'menu', () async {
      await start();
      final vote = await at(_t0, theVote);
      signInAs(_anna);
      await at(
        _t0,
        () => service.castVote(_menu, vote, vote.alternatives.first.id),
      );
      await firestore
          .collection(FirestoreCollections.realtimeResources)
          .doc('other-menu')
          .collection(FirestoreCollections.liveMenuVotes)
          .doc(_bo)
          .set(
            MenuBallot(userId: _bo, ballots: const {'v': 'a'}).toFirestore(),
          );

      final documents = await repository.watchBallots(_menu).first;

      expect(
        documents.map((d) => d.userId),
        unorderedEquals([_starter, _anna]),
      );
    });
  });
}
