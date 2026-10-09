/// What a person sees and can do on a live menu's vote card (BUT-2118), in
/// each state a vote can be in. Text is the app's Swedish copy, found as a
/// person reads it.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/realtime/menu_slot_vote.dart';
import 'package:butlery/widgets/menu/menu_vote_card.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

const _me = 'me';
const _starter = 'starter';

VoteOption _opt(String id, String name, {int votersBefore = 0}) => VoteOption(
  id: id,
  dish: {'id': 'recipe-$id', 'title': name},
  votersBefore: votersBefore,
);

MenuSlotVote _vote({
  String starterId = _starter,
  Map<String, String> votes = const {},
  Duration untilDeadline = const Duration(hours: 24),
  VoteResolution? resolution,
  List<VoteOption>? alternatives,
}) {
  final now = DateTime.now();
  return MenuSlotVote(
    id: 'v1',
    category: 'Middag',
    slotIndex: 0,
    starterId: starterId,
    alternatives: alternatives ?? [_opt('a', 'Pannkakor'), _opt('b', 'Pasta')],
    votes: votes,
    deadline: now.add(untilDeadline),
    createdAt: now.subtract(const Duration(hours: 1)),
    resolution: resolution,
  );
}

Future<void> _pump(
  WidgetTester tester,
  MenuSlotVote vote, {
  String me = _me,
  ValueChanged<String>? onVote,
  ValueChanged<String>? onDecide,
  VoidCallback? onReopen,
  VoidCallback? onRelease,
  VoidCallback? onPropose,
}) => tester.pumpWidget(
  createLocalizedTestApp(
    wrapInScrollView: true,
    child: MenuVoteCard(
      vote: vote,
      currentUserId: me,
      onVote: onVote,
      onDecide: onDecide,
      onReopen: onReopen,
      onRelease: onRelease,
      onPropose: onPropose,
    ),
  ),
);

final _lockedNotice = find.textContaining('Din röst går inte att ändra');
final _waiting = find.text('Väntar på den som startade rösten.');

void main() {
  group('an open vote', () {
    testWidgets('warns that a ballot cannot be changed until you have voted', (
      tester,
    ) async {
      await _pump(tester, _vote(), onVote: (_) {});
      expect(find.text('Pannkakor'), findsOneWidget);
      expect(_lockedNotice, findsOneWidget);

      await _pump(
        tester,
        _vote(votes: const {_me: 'a'}),
        onVote: (_) {},
      );

      expect(find.text('Pannkakor'), findsOneWidget);
      expect(_lockedNotice, findsNothing);
    });

    testWidgets('tapping an option casts that option', (tester) async {
      final cast = <String>[];
      await _pump(tester, _vote(), onVote: cast.add);

      await tester.tap(find.text('Pasta'));

      expect(cast, ['b']);
    });

    testWidgets('after voting no option can be tapped again', (tester) async {
      final cast = <String>[];
      await _pump(tester, _vote(), onVote: cast.add);
      await tester.tap(find.text('Pannkakor'));
      expect(cast, ['a'], reason: 'the tap works before voting');

      await _pump(
        tester,
        _vote(votes: const {_me: 'a'}),
        onVote: cast.add,
      );
      await tester.tap(find.text('Pannkakor'));
      await tester.tap(find.text('Pasta'));

      expect(cast, ['a']);
    });

    testWidgets('a screen reader hears a locked option as disabled', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      bool enabled(String label) => tester
          .getSemantics(find.bySemanticsLabel(RegExp(label)))
          .flagsCollection
          .isEnabled
          .toBoolOrNull()!;

      await _pump(tester, _vote(), onVote: (_) {});
      expect(enabled('Pasta'), isTrue);

      await _pump(
        tester,
        _vote(votes: const {_me: 'a'}),
        onVote: (_) {},
      );
      expect(enabled('Pasta'), isFalse);
      handle.dispose();
    });

    testWidgets('someone else\'s ballot does not lock mine', (tester) async {
      final cast = <String>[];
      await _pump(
        tester,
        _vote(votes: const {'anna': 'a'}),
        onVote: cast.add,
      );

      await tester.tap(find.text('Pasta'));

      expect(cast, ['b']);
      expect(find.text('Inga röster'), findsOneWidget);
    });

    testWidgets('an option added after people had voted says how many had', (
      tester,
    ) async {
      await _pump(
        tester,
        _vote(
          alternatives: [
            _opt('a', 'Pannkakor'),
            _opt('b', 'Pasta'),
            _opt('c', 'Gryta', votersBefore: 2),
          ],
        ),
        onVote: (_) {},
      );

      expect(find.text('Tillagd sent: 2 hade redan röstat'), findsOneWidget);
      expect(find.textContaining('Tillagd sent'), findsOneWidget);
    });

    testWidgets('offers to add a dish, and tapping it asks to', (tester) async {
      var proposed = 0;
      await _pump(tester, _vote(), onVote: (_) {}, onPropose: () => proposed++);

      await tester.tap(find.text('Föreslå något annat'));

      expect(proposed, 1);
    });

    testWidgets('offers no way to add a dish unless it is allowed', (
      tester,
    ) async {
      await _pump(tester, _vote(), onVote: (_) {});

      expect(find.text('Pannkakor'), findsOneWidget);
      expect(find.text('Föreslå något annat'), findsNothing);
    });

    testWidgets('the starter settles a clear leader, nobody else can', (
      tester,
    ) async {
      final decided = <String>[];
      final lead = _vote(votes: const {'anna': 'b', 'bo': 'b', 'cy': 'a'});

      await _pump(
        tester,
        lead,
        me: _starter,
        onVote: (_) {},
        onDecide: decided.add,
      );
      await tester.tap(find.text('Avgör'));

      expect(decided, ['b']);

      await _pump(tester, lead, onVote: (_) {}, onDecide: decided.add);

      expect(find.text('Pannkakor'), findsOneWidget);
      expect(find.text('Avgör'), findsNothing);
    });

    testWidgets('does not offer to settle before anyone has voted', (
      tester,
    ) async {
      await _pump(tester, _vote(), me: _starter, onDecide: (_) {});

      expect(find.text('Pannkakor'), findsOneWidget);
      expect(find.text('Avgör'), findsNothing);
    });

    group('tied', () {
      final tied = _vote(votes: const {'anna': 'a', 'bo': 'b'});

      testWidgets('the starter gets a button per leader and picks one', (
        tester,
      ) async {
        final decided = <String>[];
        await _pump(
          tester,
          tied,
          me: _starter,
          onVote: (_) {},
          onDecide: decided.add,
          onReopen: () {},
          onRelease: () {},
        );

        expect(find.text('Oavgjort, kräver ett beslut'), findsOneWidget);
        expect(find.text('Välj Pannkakor'), findsOneWidget);
        expect(find.text('Välj Pasta'), findsOneWidget);
        expect(find.text('Avgör'), findsNothing);
        expect(_waiting, findsNothing);
        expect(
          find.text('Ge det ett dygn'),
          findsNothing,
          reason: 'a vote still running has no deadline to extend',
        );
        expect(find.text('Släpp platsen'), findsNothing);

        await tester.tap(find.text('Välj Pasta'));

        expect(decided, ['b']);
      });

      testWidgets('only the leaders can be picked', (tester) async {
        await _pump(
          tester,
          _vote(
            votes: const {'anna': 'a', 'bo': 'b'},
            alternatives: [
              _opt('a', 'Pannkakor'),
              _opt('b', 'Pasta'),
              _opt('c', 'Gryta'),
            ],
          ),
          me: _starter,
          onDecide: (_) {},
        );

        expect(find.text('Välj Pannkakor'), findsOneWidget);
        expect(find.text('Välj Gryta'), findsNothing);
      });

      testWidgets('everyone else is told it waits on the starter', (
        tester,
      ) async {
        await _pump(tester, tied, onVote: (_) {}, onDecide: (_) {});

        expect(find.text('Oavgjort, kräver ett beslut'), findsOneWidget);
        expect(_waiting, findsOneWidget);
        expect(find.textContaining('Välj '), findsNothing);
      });
    });
  });

  group('a vote that ran out with ballots', () {
    const ranOut = Duration(hours: -1);

    testWidgets('a clear leader waits for the starter, who can decide anyway, '
        'reopen or release', (tester) async {
      final calls = <String>[];
      final vote = _vote(untilDeadline: ranOut, votes: const {'anna': 'a'});

      await _pump(
        tester,
        vote,
        me: _starter,
        onDecide: (id) => calls.add('decide:$id'),
        onReopen: () => calls.add('reopen'),
        onRelease: () => calls.add('release'),
      );
      await tester.tap(find.text('Avgör ändå'));
      await tester.tap(find.text('Öppna igen'));
      await tester.tap(find.text('Släpp platsen'));

      expect(calls, ['decide:a', 'reopen', 'release']);
    });

    testWidgets('someone who did not start it only sees that it waits', (
      tester,
    ) async {
      await _pump(
        tester,
        _vote(untilDeadline: ranOut, votes: const {'anna': 'a'}),
        onDecide: (_) {},
        onReopen: () {},
        onRelease: () {},
      );

      expect(_waiting, findsOneWidget);
      expect(find.text('Avgör ändå'), findsNothing);
      expect(find.text('Släpp platsen'), findsNothing);
    });

    testWidgets(
      'a tie is never broken for the starter, who may give it a day or '
      'let the slot go',
      (tester) async {
        final calls = <String>[];
        await _pump(
          tester,
          _vote(untilDeadline: ranOut, votes: const {'anna': 'a', 'bo': 'b'}),
          me: _starter,
          onDecide: calls.add,
          onReopen: () => calls.add('reopen'),
          onRelease: () => calls.add('release'),
        );

        expect(find.text('Oavgjort, kräver ett beslut'), findsOneWidget);
        expect(find.text('Avgör ändå'), findsNothing);
        await tester.tap(find.text('Välj Pasta'));
        await tester.tap(find.text('Ge det ett dygn'));
        await tester.tap(find.text('Släpp platsen'));

        expect(calls, ['b', 'reopen', 'release']);
      },
    );
  });

  group('a vote that ran out with no ballots', () {
    final vote = _vote(untilDeadline: const Duration(hours: -1));

    testWidgets(
      'says nobody voted and offers the starter to release the slot',
      (tester) async {
        final released = <String>[];
        await _pump(
          tester,
          vote,
          me: _starter,
          onRelease: () => released.add('release'),
        );

        expect(find.text('Ingen röstade'), findsOneWidget);
        await tester.tap(find.text('Släpp platsen'));
        expect(released, ['release']);
      },
    );

    testWidgets('does not offer anyone else a release', (tester) async {
      await _pump(tester, vote, onRelease: () {});

      expect(find.text('Ingen röstade'), findsOneWidget);
      expect(find.text('Släpp platsen'), findsNothing);
    });
  });

  group('a settled vote', () {
    testWidgets('a decided vote shows the winner and the votes it got', (
      tester,
    ) async {
      await _pump(
        tester,
        _vote(
          votes: const {'anna': 'b', 'bo': 'b'},
          resolution: VoteResolution(
            outcome: VoteOutcome.winner,
            optionId: 'b',
            at: DateTime.now(),
          ),
        ),
        onVote: (_) {},
      );

      expect(find.text('Omröstning avgjord'), findsOneWidget);
      expect(find.text('Vinnare: Pasta'), findsOneWidget);
      expect(find.text('2 röster'), findsOneWidget);
      expect(
        find.text('Pannkakor'),
        findsNothing,
        reason: 'the options are no longer up for a vote',
      );
    });

    testWidgets('a released vote draws nothing', (tester) async {
      await _pump(
        tester,
        _vote(
          resolution: VoteResolution(
            outcome: VoteOutcome.released,
            at: DateTime.now(),
          ),
        ),
        onVote: (_) {},
      );

      expect(find.byType(MenuVoteCard), findsOneWidget);
      expect(find.byType(Card), findsNothing);
      expect(find.text('Pannkakor'), findsNothing);
      expect(tester.getSize(find.byType(MenuVoteCard)), Size.zero);
    });
  });
}
