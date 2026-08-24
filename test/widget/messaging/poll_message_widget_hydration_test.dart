/// BUT-1908: the poll widget must not claim a vote count it never received,
/// and must not offer the close action on one.
///
/// The harm this pins is not a rendering nit. A chat page hydrates at most
/// `MessageQueryModule.maxHydratedPolls` polls, so from the 21st down the votes
/// are not fetched and the poll drew "0 röster" over real ones. The close button
/// was drawn anyway; the close path then re-read the message on its own uncapped
/// route, resolved the REAL winner, and wrote that recipe into the household's
/// week. The screen said nothing was there and the app acted on votes the
/// creator was never shown.
///
/// Two states, deliberately not one boolean. `capped` is a client decision a
/// re-read repairs; `failed` may be permanent. They need different Swedish text.
/// As a SAFETY control they are identical — both must disable the button — which
/// is why the gate below is asserted for each of them separately rather than
/// once against "not ok".
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/widgets/messaging/poll_message_widget.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  const creator = 'user-creator';

  /// A poll with two real votes on one option, so a widget that renders the
  /// stored numbers shows "2 röster" — the exact wrong claim, if the tally was
  /// never confirmed.
  Poll votedPoll() => Poll(
    id: 'poll-1',
    question: 'Vad ska vi äta?',
    creatorId: creator,
    createdAt: DateTime.utc(2026, 1, 1),
    options: const [
      PollOption(id: 'opt-a', text: 'Tacos', voterIds: ['user-b', 'user-c']),
      PollOption(id: 'opt-b', text: 'Pasta'),
    ],
  );

  Future<void> pumpPoll(
    WidgetTester tester, {
    required PollVoteHydration hydration,
    String viewer = creator,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: PollMessageWidget(
          poll: votedPoll(),
          currentUserId: viewer,
          isFromCurrentUser: false,
          voteHydration: hydration,
          onClose: () {},
        ),
      ),
    );
  }

  group('a poll whose votes were read behaves as before', () {
    testWidgets('shows the count and offers the close action to its creator', (
      tester,
    ) async {
      // The control. Without it every assertion below is satisfied by a widget
      // that renders nothing at all, and the gate could be a constant `false`.
      await pumpPoll(tester, hydration: PollVoteHydration.ok);

      expect(find.text('2 röster'), findsOneWidget);
      expect(find.text('Stäng omröstning'), findsOneWidget);
      expect(find.text('Rösterna har inte hämtats'), findsNothing);
      expect(find.text('Rösterna kunde inte läsas'), findsNothing);
    });
  });

  group('a poll past the hydration cap', () {
    testWidgets('says the votes were not fetched instead of counting them', (
      tester,
    ) async {
      await pumpPoll(tester, hydration: PollVoteHydration.capped);

      expect(find.text('Rösterna har inte hämtats'), findsOneWidget);
      expect(
        find.text('Öppna chatten igen för att hämta dem.'),
        findsOneWidget,
        reason: 'capped is repairable, and the text must say how',
      );
      expect(
        find.text('2 röster'),
        findsNothing,
        reason:
            'the stored numbers are still in the poll — the widget must not '
            'present them as a count it confirmed',
      );
    });

    testWidgets('does not offer the close action', (tester) async {
      await pumpPoll(tester, hydration: PollVoteHydration.capped);

      expect(find.text('Stäng omröstning'), findsNothing);
    });
  });

  group('a poll whose vote read failed', () {
    testWidgets('says so in different words from the capped case', (
      tester,
    ) async {
      // The two states must not collapse into one string. A user who can fix it
      // by reopening the chat and one who cannot are being told different
      // things, and a single message would be wrong for one of them.
      await pumpPoll(tester, hydration: PollVoteHydration.failed);

      expect(find.text('Rösterna kunde inte läsas'), findsOneWidget);
      expect(find.text('Försök igen om en stund.'), findsOneWidget);
      expect(find.text('Rösterna har inte hämtats'), findsNothing);
      expect(find.text('2 röster'), findsNothing);
    });

    testWidgets('does not offer the close action either', (tester) async {
      await pumpPoll(tester, hydration: PollVoteHydration.failed);

      expect(find.text('Stäng omröstning'), findsNothing);
    });
  });

  group('the gate is about the votes, not about who is looking', () {
    testWidgets('a non-creator never saw the close action anyway', (
      tester,
    ) async {
      // Guards the direction the fix could overshoot in: the new condition sits
      // beside the creator check, and a rewrite that replaced it rather than
      // joining it would pass every case above while handing the button to
      // everyone on a well-hydrated poll.
      await pumpPoll(
        tester,
        hydration: PollVoteHydration.ok,
        viewer: 'someone-else',
      );

      expect(find.text('Stäng omröstning'), findsNothing);
      expect(
        find.text('2 röster'),
        findsOneWidget,
        reason: 'a non-creator still sees the tally',
      );
    });
  });
}
