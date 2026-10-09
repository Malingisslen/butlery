/// What a live menu's vote cards show and what the starter can do with them
/// (BUT-2118). The service is mocked at its edge; the derivation from ballot
/// documents is the real one.
library;

import 'dart:async';

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/services/menu_voting_service.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/viewmodels/menu_voting_viewmodel.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/mock_factory.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../test_support/base_unit_test.dart';

class MockMenuVotingService extends Mock implements MenuVotingService {}

class FakeMenuSlotVote extends Fake implements MenuSlotVote {}

final _now = DateTime.utc(2026, 10, 9, 12);
const _menuId = 'menu-1';
const _me = 'me';

VoteOption _opt(String id) =>
    VoteOption(id: id, dish: {'id': 'recipe-$id', 'title': 'Dish $id'});

StartedVote _started(
  String id, {
  Duration untilDeadline = const Duration(hours: 24),
  DateTime? createdAt,
}) => StartedVote(
  id: id,
  options: [_opt('a'), _opt('b')],
  deadline: _now.add(untilDeadline),
  createdAt: createdAt ?? _now,
);

MenuBallot _ballot(
  String userId, {
  Map<String, StartedVote> started = const {},
  Map<String, VoteOption> proposals = const {},
  Map<String, String> ballots = const {},
  Map<String, VoteResolution> resolved = const {},
}) => MenuBallot(
  userId: userId,
  started: started,
  proposals: proposals,
  ballots: ballots,
  resolved: resolved,
);

void main() {
  late MockMenuVotingService service;
  late StreamController<List<MenuBallot>> ballots;
  late List<String> applied;
  late Object? applyError;
  late List<String> order;
  late MenuVotingViewModel vm;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(FakeMenuSlotVote());
    registerFallbackValue(RecipeFactory.build(id: 'fallback'));
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    production.ServiceLocator.initialize(DIContainer());
    TestServiceLocator.registerMock<PermissionService>(
      MockFactory.createPermissionService(currentUserId: _me),
    );

    service = MockMenuVotingService();
    ballots = StreamController<List<MenuBallot>>.broadcast();
    when(() => service.watchBallots(_menuId)).thenAnswer((_) => ballots.stream);
    applied = [];
    order = [];
    applyError = null;
    when(() => service.recordWinner(any(), any(), any())).thenAnswer((_) async {
      order.add('recordWinner');
      return true;
    });

    vm = MenuVotingViewModel(
      menuId: _menuId,
      votingService: service,
      applyDish: (category, slot, dish) async {
        order.add('applyDish');
        if (applyError != null) throw applyError!;
        applied.add('$category#$slot:${dish.id}');
      },
    );
  });

  tearDown(() async {
    if (!vm.isDisposed) vm.dispose();
    await ballots.close();
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  Future<void> deliver(
    List<MenuBallot> docs, {
    Set<String> people = const {_me, 'anna', 'bo'},
  }) async {
    vm.subscribe();
    vm.setParticipants(people);
    ballots.add(docs);
    await pumpEventQueue();
  }

  MenuSlotVote only() => vm.allVotes.single;

  group('what the menu shows', () {
    test('derives votes from the ballots and the roster, and tells its '
        'listeners', () async {
      var notified = 0;
      vm.addListener(() => notified++);

      await deliver([
        _ballot(_me, started: {'Middag#0': _started('v1')}),
        _ballot('anna', ballots: {'v1': 'a'}),
        _ballot('stranger', ballots: {'v1': 'b'}),
      ]);

      expect(only().id, 'v1');
      expect(only().votes, {'anna': 'a'});
      expect(notified, greaterThanOrEqualTo(2));
    });

    test('a failing ballot stream leaves the votes as they were and keeps '
        'listening', () async {
      await deliver([
        _ballot(_me, started: {'Middag#0': _started('v1')}),
      ]);
      expect(only().id, 'v1');

      ballots.addError(StateError('stream failed'));
      await pumpEventQueue();

      expect(only().id, 'v1');

      ballots.add([
        _ballot(_me, started: {'Middag#1': _started('v2')}),
      ]);
      await pumpEventQueue();

      expect(only().id, 'v2');
    });

    test(
      'a change to the roster re-counts the votes already received',
      () async {
        await deliver([
          _ballot(_me, started: {'Middag#0': _started('v1')}),
          _ballot('anna', ballots: {'v1': 'a'}),
        ]);
        expect(only().votes, {'anna': 'a'});

        vm.setParticipants({_me});

        expect(only().votes, isEmpty);
      },
    );

    test('an unchanged roster does not notify again', () async {
      await deliver([]);
      var notified = 0;
      vm.addListener(() => notified++);

      vm.setParticipants({'bo', 'anna', _me});

      expect(notified, 0);
    });

    test('nothing is counted before the roster is known', () async {
      vm.subscribe();
      ballots.add([
        _ballot(_me, started: {'Middag#0': _started('v1')}),
      ]);
      await pumpEventQueue();

      expect(vm.allVotes, isEmpty);
    });

    test('a slot shows its newest vote, and not another slot\'s', () async {
      await deliver([
        _ballot(
          _me,
          started: {
            'Middag#0': _started(
              'old',
              createdAt: _now.subtract(const Duration(hours: 5)),
            ),
            'Middag#1': _started('other-slot'),
          },
        ),
        _ballot(
          'anna',
          started: {
            'Middag#0': _started(
              'new',
              createdAt: _now.subtract(const Duration(hours: 1)),
            ),
          },
        ),
      ]);

      withClock(Clock.fixed(_now), () {
        expect(vm.voteForSlot('Middag', 0)!.id, 'new');
        expect(vm.voteForSlot('Middag', 1)!.id, 'other-slot');
        expect(vm.voteForSlot('Middag', 2), isNull);
        expect(vm.voteForSlot('Lunch', 0), isNull);
      });
    });

    test('a released vote leaves the slot', () async {
      await deliver([
        _ballot(
          _me,
          started: {'Middag#0': _started('v1')},
          resolved: {
            'v1': VoteResolution(outcome: VoteOutcome.released, at: _now),
          },
        ),
      ]);

      withClock(Clock.fixed(_now), () {
        expect(vm.voteForSlot('Middag', 0), isNull);
      });
    });

    test(
      'a decided vote stays for a day after it was settled, then goes',
      () async {
        await deliver([
          _ballot(
            _me,
            started: {'Middag#0': _started('v1')},
            resolved: {
              'v1': VoteResolution(
                outcome: VoteOutcome.winner,
                optionId: 'a',
                at: _now,
              ),
            },
          ),
        ]);

        final goesAt = _now.add(MenuVotingViewModel.showDecidedFor);
        withClock(
          Clock.fixed(goesAt.subtract(const Duration(seconds: 1))),
          () => expect(vm.voteForSlot('Middag', 0), isNotNull),
        );
        withClock(
          Clock.fixed(goesAt),
          () => expect(vm.voteForSlot('Middag', 0), isNull),
        );
      },
    );

    test(
      'an expired vote nobody settled waits for a week, then is hidden',
      () async {
        await deliver([
          _ballot(
            _me,
            started: {'Middag#0': _started('v1', untilDeadline: Duration.zero)},
          ),
          _ballot('anna', ballots: {'v1': 'a'}),
        ]);

        withClock(Clock.fixed(_now.add(const Duration(days: 6))), () {
          expect(
            vm.voteForSlot('Middag', 0)!.state,
            SlotVoteState.expiredWithVotes,
          );
        });
        withClock(Clock.fixed(_now.add(const Duration(days: 8))), () {
          expect(vm.voteForSlot('Middag', 0), isNull);
        });
      },
    );

    test('only running votes are active', () async {
      await deliver([
        _ballot(
          _me,
          started: {
            'Middag#0': _started('open'),
            'Middag#1': _started('ran-out', untilDeadline: Duration.zero),
          },
        ),
      ]);

      withClock(Clock.fixed(_now.add(const Duration(hours: 1))), () {
        expect(vm.activeVotes.map((v) => v.id), ['open']);
      });
    });

    test('knows whether I have already added a dish to a vote', () async {
      await deliver([
        _ballot('anna', started: {'Middag#0': _started('v1')}),
      ]);
      expect(vm.hasProposed(only()), isFalse);

      ballots.add([
        _ballot('anna', started: {'Middag#0': _started('v1')}),
        _ballot(_me, proposals: {'v1': _opt('d')}),
        _ballot('bo', proposals: {'v2': _opt('e')}),
      ]);
      await pumpEventQueue();

      expect(vm.hasProposed(only()), isTrue);
    });

    test('a dish someone else added is not mine', () async {
      await deliver([
        _ballot('anna', started: {'Middag#0': _started('v1')}),
        _ballot('bo', proposals: {'v1': _opt('d')}),
      ]);

      expect(vm.hasProposed(only()), isFalse);
    });
  });

  group('canStartVote', () {
    Future<void> slotWith(
      StartedVote started, {
      VoteResolution? resolution,
      Map<String, String> votes = const {},
    }) => deliver([
      _ballot(
        _me,
        started: {'Middag#0': started},
        resolved: {started.id: ?resolution},
      ),
      _ballot('anna', ballots: votes),
    ]);

    test('is open on a slot with no vote', () async {
      await deliver([]);

      withClock(Clock.fixed(_now), () {
        expect(vm.canStartVote('Middag', 0), isTrue);
      });
    });

    test(
      'is closed while a vote runs and while one waits on its starter',
      () async {
        await slotWith(_started('v1'));
        withClock(Clock.fixed(_now), () {
          expect(vm.canStartVote('Middag', 0), isFalse);
        });

        await slotWith(_started('v1', untilDeadline: Duration.zero));
        withClock(Clock.fixed(_now.add(const Duration(hours: 1))), () {
          expect(
            vm.canStartVote('Middag', 0),
            isFalse,
            reason: 'expired with nobody voting still waits to be released',
          );
        });
      },
    );

    test('is open again once the vote is decided or released', () async {
      await slotWith(
        _started('v1'),
        resolution: VoteResolution(
          outcome: VoteOutcome.winner,
          optionId: 'a',
          at: _now,
        ),
      );
      withClock(Clock.fixed(_now), () {
        expect(vm.canStartVote('Middag', 0), isTrue);
      });

      await slotWith(
        _started('v1'),
        resolution: VoteResolution(outcome: VoteOutcome.released, at: _now),
      );
      withClock(Clock.fixed(_now), () {
        expect(vm.canStartVote('Middag', 0), isTrue);
      });
    });
  });

  group('startVote', () {
    final current = RecipeFactory.build(id: 'now', title: 'Nu');
    final proposal = RecipeFactory.build(id: 'next', title: 'Nästa');

    void stubStart() => when(
      () => service.startVote(
        menuId: any(named: 'menuId'),
        category: any(named: 'category'),
        slotIndex: any(named: 'slotIndex'),
        current: any(named: 'current'),
        proposal: any(named: 'proposal'),
      ),
    ).thenAnswer((_) async => true);

    test('is passed on to the service when the slot is free', () async {
      stubStart();
      await deliver([]);

      final ok = await withClock(
        Clock.fixed(_now),
        () => vm.startVote(
          category: 'Middag',
          slotIndex: 1,
          current: current,
          proposal: proposal,
        ),
      );

      expect(ok, isTrue);
      verify(
        () => service.startVote(
          menuId: _menuId,
          category: 'Middag',
          slotIndex: 1,
          current: current,
          proposal: proposal,
        ),
      ).called(1);
    });

    test('is refused, without a write, while a vote is running', () async {
      stubStart();
      await deliver([
        _ballot(_me, started: {'Middag#1': _started('v1')}),
      ]);

      final ok = await withClock(
        Clock.fixed(_now),
        () => vm.startVote(
          category: 'Middag',
          slotIndex: 1,
          current: current,
          proposal: proposal,
        ),
      );

      expect(ok, isFalse);
      verifyNever(
        () => service.startVote(
          menuId: any(named: 'menuId'),
          category: any(named: 'category'),
          slotIndex: any(named: 'slotIndex'),
          current: any(named: 'current'),
          proposal: any(named: 'proposal'),
        ),
      );
    });
  });

  group('voting, proposing, reopening and releasing', () {
    test('each goes to the service for this menu', () async {
      when(
        () => service.castVote(any(), any(), any()),
      ).thenAnswer((_) async => true);
      when(
        () => service.propose(any(), any(), any()),
      ).thenAnswer((_) async => true);
      when(() => service.reopen(any(), any())).thenAnswer((_) async => true);
      when(() => service.release(any(), any())).thenAnswer((_) async => true);
      await deliver([
        _ballot(_me, started: {'Middag#0': _started('v1')}),
      ]);
      final vote = only();
      final dish = RecipeFactory.build(id: 'x');

      expect(await vm.castVote(vote, 'a'), isTrue);
      expect(await vm.propose(vote, dish), isTrue);
      expect(await vm.reopen(vote), isTrue);
      expect(await vm.release(vote), isTrue);

      verify(() => service.castVote(_menuId, vote, 'a')).called(1);
      verify(() => service.propose(_menuId, vote, dish)).called(1);
      verify(() => service.reopen(_menuId, vote)).called(1);
      verify(() => service.release(_menuId, vote)).called(1);
    });
  });

  group('settle', () {
    Future<MenuSlotVote> myVote({String starter = _me}) async {
      await deliver(
        [
          _ballot(starter, started: {'Middag#2': _started('v1')}),
        ],
        people: {_me, 'anna', 'bo', 'other'},
      );
      return only();
    }

    test(
      'puts the dish on the slot first and records the winner after',
      () async {
        final vote = await myVote();

        final ok = await vm.settle(vote, 'b');

        expect(ok, isTrue);
        expect(applied, ['Middag#2:recipe-b']);
        expect(order, ['applyDish', 'recordWinner']);
        verify(() => service.recordWinner(_menuId, vote, 'b')).called(1);
      },
    );

    test(
      'a failed menu write records nothing and reports the failure',
      () async {
        applyError = StateError('menu write refused');
        final vote = await myVote();

        final ok = await vm.settle(vote, 'a');

        expect(ok, isFalse);
        expect(order, ['applyDish']);
        verifyNever(() => service.recordWinner(any(), any(), any()));
        expect(vm.error, AppLocale.current.menuVoteApplyFailed);
        expect(vm.hasError, isTrue);
      },
    );

    test('a winner the service will not record is not reported as settled, '
        'though the dish is already on the slot', () async {
      when(() => service.recordWinner(any(), any(), any())).thenAnswer((
        _,
      ) async {
        order.add('recordWinner');
        return false;
      });
      final vote = await myVote();

      final ok = await vm.settle(vote, 'b');

      expect(ok, isFalse);
      expect(
        order,
        ['applyDish', 'recordWinner'],
        reason: 'the refusal came from recording, not from an earlier guard',
      );
      expect(applied, ['Middag#2:recipe-b']);
    });

    test('someone who did not start the vote cannot settle it', () async {
      final vote = await myVote(starter: 'other');

      final ok = await vm.settle(vote, 'a');

      expect(ok, isFalse);
      expect(order, isEmpty);
      verifyNever(() => service.recordWinner(any(), any(), any()));
    });

    test('an option that is not on the vote cannot be settled on', () async {
      final vote = await myVote();

      final ok = await vm.settle(vote, 'not-an-option');

      expect(ok, isFalse);
      expect(order, isEmpty);
    });

    test('without a way to write to the menu nothing is recorded', () async {
      final bare = MenuVotingViewModel(
        menuId: _menuId,
        votingService: service,
      );
      addTearDown(bare.dispose);
      final vote = await myVote();

      final ok = await bare.settle(vote, 'a');

      expect(ok, isFalse);
      verifyNever(() => service.recordWinner(any(), any(), any()));
    });
  });

  group('dispose', () {
    test('stops listening to the ballots', () async {
      await deliver([]);
      expect(ballots.hasListener, isTrue);

      vm.dispose();
      await pumpEventQueue();

      expect(ballots.hasListener, isFalse);
    });

    test('subscribing again replaces the earlier subscription', () async {
      final second = StreamController<List<MenuBallot>>.broadcast();
      addTearDown(second.close);
      vm.subscribe();
      when(
        () => service.watchBallots(_menuId),
      ).thenAnswer((_) => second.stream);

      vm.subscribe();

      expect(ballots.hasListener, isFalse);
      expect(second.hasListener, isTrue);
    });
  });
}
