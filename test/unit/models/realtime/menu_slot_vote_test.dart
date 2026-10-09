/// Ballot documents and the votes derived from them (BUT-2118).
///
/// Pure Dart: the interesting behaviour is who counts, which options a vote
/// has, and what state it is in at a given moment.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/realtime/menu_slot_vote.dart';

final _now = DateTime.utc(2026, 10, 9, 12);

VoteOption _opt(String id, {String? name, int votersBefore = 0}) => VoteOption(
  id: id,
  dish: {'id': 'recipe-$id', 'title': name ?? 'Dish $id'},
  votersBefore: votersBefore,
);

StartedVote _started(
  String id, {
  List<VoteOption>? options,
  DateTime? deadline,
}) => StartedVote(
  id: id,
  options: options ?? [_opt('a'), _opt('b')],
  deadline: deadline ?? _now.add(const Duration(hours: 24)),
  createdAt: _now,
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

MenuSlotVote _vote({
  Map<String, String> votes = const {},
  DateTime? deadline,
  VoteResolution? resolution,
  List<VoteOption>? alternatives,
}) => MenuSlotVote(
  id: 'v1',
  category: 'Middag',
  slotIndex: 0,
  starterId: 'starter',
  alternatives: alternatives ?? [_opt('a'), _opt('b'), _opt('c')],
  votes: votes,
  deadline: deadline ?? _now.add(const Duration(hours: 24)),
  createdAt: _now,
  resolution: resolution,
);

void main() {
  group('MenuBallot', () {
    test('survives the trip through its stored shape', () {
      final deadline = DateTime.utc(2026, 10, 10, 8);
      final ballot = _ballot(
        'u1',
        started: {
          'Middag#1': _started(
            'v1',
            options: [
              _opt('a', name: 'Pasta'),
              _opt('b', votersBefore: 3),
            ],
            deadline: deadline,
          ),
        },
        proposals: {'v9': _opt('p', votersBefore: 2)},
        ballots: {'v9': 'p'},
        resolved: {
          'v1': VoteResolution(
            outcome: VoteOutcome.winner,
            optionId: 'a',
            at: _now,
          ),
        },
      );

      final back = MenuBallot.fromMap('u1', ballot.toFirestore());

      final vote = back.started['Middag#1']!;
      expect(vote.id, 'v1');
      expect(vote.deadline.isAtSameMomentAs(deadline), isTrue);
      expect(vote.options.map((o) => o.id), ['a', 'b']);
      expect(vote.options.first.recipeName, 'Pasta');
      expect(vote.options.last.votersBefore, 3);
      expect(back.proposals['v9']!.votersBefore, 2);
      expect(back.ballots, {'v9': 'p'});
      expect(back.resolved['v1']!.outcome, VoteOutcome.winner);
      expect(back.resolved['v1']!.optionId, 'a');
    });

    test('an entry of the wrong shape is dropped, the rest is kept', () {
      final stored = _ballot(
        'u1',
        started: {'Middag#0': _started('v1')},
        proposals: {'ok': _opt('p')},
        ballots: {'ok': 'p'},
      ).toFirestore();
      // toFirestore hands back narrowly typed maps; widen them to plant junk.
      for (final key in ['started', 'proposals', 'ballots', 'resolved']) {
        stored[key] = Map<String, dynamic>.from(stored[key] as Map);
      }
      (stored['started'] as Map)['bad'] = 'not a map';
      (stored['proposals'] as Map)['bad'] = 42;
      (stored['ballots'] as Map)['bad'] = 7;
      (stored['resolved'] as Map)['bad'] = ['x'];

      final back = MenuBallot.fromMap('u1', stored);

      expect(back.started.keys, ['Middag#0']);
      expect(back.proposals.keys, ['ok']);
      expect(back.ballots, {'ok': 'p'});
      expect(back.resolved, isEmpty);
    });

    test('a started vote whose options are not a list reads with none', () {
      final stored = _ballot(
        'u1',
        started: {'Middag#0': _started('v1')},
      ).toFirestore();
      final started = Map<String, dynamic>.from(stored['started'] as Map);
      started['Middag#0'] = {
        ...(started['Middag#0'] as Map).cast<String, dynamic>(),
        'options': {'not': 'a list'},
      };
      stored['started'] = started;

      final back = MenuBallot.fromMap('u1', stored);

      expect(back.started['Middag#0']!.options, isEmpty);
    });

    test('an option of the wrong shape is dropped, the valid one is kept', () {
      final stored = _ballot(
        'u1',
        started: {
          'Middag#0': _started('v1', options: [_opt('a', name: 'Pasta')]),
        },
      ).toFirestore();
      final started = Map<String, dynamic>.from(stored['started'] as Map);
      final vote = Map<String, dynamic>.from(started['Middag#0'] as Map);
      vote['options'] = [...(vote['options'] as List), 'junk'];
      started['Middag#0'] = vote;
      stored['started'] = started;

      final back = MenuBallot.fromMap('u1', stored);

      expect(back.started['Middag#0']!.options.map((o) => o.recipeName), [
        'Pasta',
      ]);
    });

    test('a document with nothing in it reads as empty', () {
      final back = MenuBallot.fromMap('u1', const {});

      expect(back.userId, 'u1');
      expect(back.isEmpty, isTrue);
    });

    test('an unknown outcome reads as released '
        'and a release stores no option', () {
      final released = VoteResolution(outcome: VoteOutcome.released, at: _now);

      expect(released.toFirestore().containsKey('optionId'), isFalse);
      final back = VoteResolution.fromMap({
        'outcome': 'something-new',
        'at': released.toFirestore()['at'],
      });
      expect(back.outcome, VoteOutcome.released);
      expect(back.optionId, isNull);
    });

    test('slotKey is category#index, and the vote reports the same key', () {
      expect(MenuBallot.slotKey('Middag', 2), 'Middag#2');
      expect(_vote().slotKey, 'Middag#0');
    });
  });

  group('MenuSlotVote.deriveAll', () {
    const people = {'starter', 'anna', 'bo'};

    List<MenuSlotVote> derive(List<MenuBallot> docs, [Set<String>? ids]) =>
        MenuSlotVote.deriveAll(docs, ids ?? people);

    test('options are the starter\'s two plus each person\'s own proposal', () {
      final docs = [
        _ballot('starter', started: {'Middag#0': _started('v1')}),
        _ballot('anna', proposals: {'v1': _opt('c')}),
        _ballot('bo', proposals: {'v1': _opt('d')}),
      ];

      final vote = derive(docs).single;

      expect(
        vote.alternatives.map((o) => o.id),
        unorderedEquals(['a', 'b', 'c', 'd']),
      );
      expect(vote.alternatives.take(2).map((o) => o.id), ['a', 'b']);
      expect(vote.starterId, 'starter');
      expect(vote.category, 'Middag');
      expect(vote.slotIndex, 0);
    });

    test('a proposal on another vote is not an option here', () {
      final docs = [
        _ballot('starter', started: {'Middag#0': _started('v1')}),
        _ballot('anna', proposals: {'other-vote': _opt('c')}),
      ];

      expect(derive(docs).single.alternatives.map((o) => o.id), ['a', 'b']);
    });

    test('an option id that two proposals share is listed once', () {
      final docs = [
        _ballot('starter', started: {'Middag#0': _started('v1')}),
        _ballot('anna', proposals: {'v1': _opt('c', name: 'First')}),
        _ballot('bo', proposals: {'v1': _opt('c', name: 'Second')}),
      ];

      final options = derive(docs).single.alternatives;

      expect(options.where((o) => o.id == 'c'), hasLength(1));
    });

    test('only people on the menu now are counted, and a ballot is theirs by '
        'document, not by what it says', () {
      final docs = [
        _ballot('starter', started: {'Middag#0': _started('v1')}),
        _ballot('anna', ballots: {'v1': 'a'}),
        _ballot('bo', ballots: {'v1': 'b'}),
        _ballot('gone', ballots: {'v1': 'a'}),
      ];

      final vote = derive(docs).single;

      expect(vote.votes, {'anna': 'a', 'bo': 'b'});
      expect(vote.totalVotes, 2);
    });

    test('a person who left takes their proposal with them', () {
      final docs = [
        _ballot('starter', started: {'Middag#0': _started('v1')}),
        _ballot('gone', proposals: {'v1': _opt('c')}, ballots: {'v1': 'c'}),
      ];

      final vote = derive(docs);

      expect(vote.single.alternatives.map((o) => o.id), ['a', 'b']);
      expect(vote.single.votes, isEmpty);
    });

    test('a ballot naming an option that is not on the vote is ignored', () {
      final docs = [
        _ballot('starter', started: {'Middag#0': _started('v1')}),
        _ballot('anna', ballots: {'v1': 'a'}),
        _ballot('bo', ballots: {'v1': 'smuggled'}),
      ];

      final vote = derive(docs).single;

      expect(vote.votes, {'anna': 'a'});
      expect(vote.alternatives.map((o) => o.id), ['a', 'b']);
    });

    test('a ballot for a proposed option counts once that proposer is on the '
        'menu, and stops counting when they leave', () {
      final docs = [
        _ballot('starter', started: {'Middag#0': _started('v1')}),
        _ballot('anna', proposals: {'v1': _opt('c')}),
        _ballot('bo', ballots: {'v1': 'c'}),
      ];

      expect(derive(docs).single.votes, {'bo': 'c'});
      expect(derive(docs, {'starter', 'bo'}).single.votes, isEmpty);
    });

    test('a starter who left drops the vote, even with people voting', () {
      final docs = [
        _ballot('gone', started: {'Middag#0': _started('v1')}),
        _ballot('anna', ballots: {'v1': 'a'}),
      ];

      expect(derive(docs), isEmpty);
    });

    test('a slot key that is not category#index is skipped, a good one beside '
        'it is not', () {
      final docs = [
        _ballot(
          'starter',
          started: {
            'Middag': _started('v1'),
            '#3': _started('v2'),
            'Middag#x': _started('v3'),
            'Middag#-1': _started('v4'),
            'Förrätt#2': _started('v5'),
          },
        ),
      ];

      final votes = derive(docs);

      expect(votes.map((v) => v.id), ['v5']);
      expect(votes.single.category, 'Förrätt');
      expect(votes.single.slotIndex, 2);
    });

    test('a category that itself contains # is split at the last one', () {
      final docs = [
        _ballot('starter', started: {'Tillbehör #2#1': _started('v1')}),
      ];

      final vote = derive(docs).single;

      expect(vote.category, 'Tillbehör #2');
      expect(vote.slotIndex, 1);
    });

    test(
      'the starter\'s settlement of this vote, and only this vote, applies',
      () {
        final docs = [
          _ballot(
            'starter',
            started: {'Middag#0': _started('v1')},
            resolved: {
              'v1': VoteResolution(
                outcome: VoteOutcome.winner,
                optionId: 'a',
                at: _now,
              ),
              'unrelated': VoteResolution(
                outcome: VoteOutcome.released,
                at: _now,
              ),
            },
          ),
          // Someone else claiming the vote is settled does nothing.
          _ballot(
            'anna',
            resolved: {
              'v1': VoteResolution(outcome: VoteOutcome.released, at: _now),
            },
          ),
        ];

        final vote = derive(docs).single;

        expect(vote.resolution!.outcome, VoteOutcome.winner);
        expect(vote.winningOption!.id, 'a');
      },
    );

    test('two starters on different slots give two votes', () {
      final docs = [
        _ballot('starter', started: {'Middag#0': _started('v1')}),
        _ballot('anna', started: {'Lunch#1': _started('v2')}),
      ];

      expect(derive(docs).map((v) => (v.id, v.starterId)), [
        ('v1', 'starter'),
        ('v2', 'anna'),
      ]);
    });
  });

  group('MenuSlotVote state', () {
    final resolvedWinner = VoteResolution(
      outcome: VoteOutcome.winner,
      optionId: 'a',
      at: _now,
    );

    SlotVoteState stateAt(DateTime at, MenuSlotVote vote) =>
        withClock(Clock.fixed(at), () => vote.state);

    test('is open until the deadline, with or without votes', () {
      expect(stateAt(_now, _vote()), SlotVoteState.open);
      expect(stateAt(_now, _vote(votes: {'anna': 'a'})), SlotVoteState.open);
    });

    test(
      'the deadline instant itself is still open, one tick later is not',
      () {
        final vote = _vote(deadline: _now);

        expect(stateAt(_now, vote), SlotVoteState.open);
        expect(
          stateAt(_now.add(const Duration(milliseconds: 1)), vote),
          SlotVoteState.expiredEmpty,
        );
      },
    );

    test('an expired vote with ballots waits on the starter, it is not '
        'settled', () {
      final vote = _vote(votes: {'anna': 'a'}, deadline: _now);
      final later = _now.add(const Duration(hours: 1));

      expect(stateAt(later, vote), SlotVoteState.expiredWithVotes);
      withClock(Clock.fixed(later), () {
        expect(vote.isResolved, isFalse);
        expect(vote.isActive, isFalse);
      });
    });

    test('a settled vote is decided or released whatever the clock says', () {
      final far = _now.add(const Duration(days: 30));

      expect(
        stateAt(far, _vote(resolution: resolvedWinner)),
        SlotVoteState.decided,
      );
      expect(
        stateAt(
          far,
          _vote(
            resolution: VoteResolution(outcome: VoteOutcome.released, at: _now),
          ),
        ),
        SlotVoteState.released,
      );
    });

    test('is stale a week after the deadline, not before, and never once '
        'settled', () {
      final vote = _vote(deadline: _now);
      final edge = _now.add(MenuSlotVote.hideAfterExpiry);

      withClock(Clock.fixed(edge), () => expect(vote.isStale, isFalse));
      withClock(
        Clock.fixed(edge.add(const Duration(seconds: 1))),
        () => expect(vote.isStale, isTrue),
      );
      withClock(
        Clock.fixed(edge.add(const Duration(days: 30))),
        () => expect(
          _vote(deadline: _now, resolution: resolvedWinner).isStale,
          isFalse,
        ),
      );
    });
  });

  group('MenuSlotVote tally', () {
    test('counts per option and names the single leader as the clear '
        'winner', () {
      final vote = _vote(votes: {'u1': 'a', 'u2': 'a', 'u3': 'b'});

      expect(vote.tallies, {'a': 2, 'b': 1});
      expect(vote.leaders.map((o) => o.id), ['a']);
      expect(vote.isTie, isFalse);
      expect(vote.clearWinner!.id, 'a');
    });

    test('equal top counts are a tie with no winner, and an option nobody '
        'chose is not among the leaders', () {
      final vote = _vote(votes: {'u1': 'a', 'u2': 'b'});

      expect(vote.isTie, isTrue);
      expect(vote.leaders.map((o) => o.id), ['a', 'b']);
      expect(vote.clearWinner, isNull);
    });

    test('with no ballots there are no leaders, no tie and no winner', () {
      final vote = _vote();

      expect(vote.leaders, isEmpty);
      expect(vote.isTie, isFalse);
      expect(vote.clearWinner, isNull);
    });

    test('knows its starter and who has voted', () {
      final vote = _vote(votes: {'anna': 'a'});

      expect(vote.isStarter('starter'), isTrue);
      expect(vote.isStarter('anna'), isFalse);
      expect(vote.hasVoted('anna'), isTrue);
      expect(vote.hasVoted('starter'), isFalse);
    });

    test('the winning option is the one the resolution names, if it is on '
        'the vote', () {
      final named = _vote(
        resolution: VoteResolution(
          outcome: VoteOutcome.winner,
          optionId: 'b',
          at: _now,
        ),
      );
      final unknown = _vote(
        resolution: VoteResolution(
          outcome: VoteOutcome.winner,
          optionId: 'zzz',
          at: _now,
        ),
      );

      expect(named.winningOption!.id, 'b');
      expect(unknown.winningOption, isNull);
    });
  });
}
