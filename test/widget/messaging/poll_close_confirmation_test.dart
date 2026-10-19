// BUT-1919: closing a poll asks first and names who wins right now.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/views/messaging/chat_view/poll_close_confirmation.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

Poll _poll(List<PollOption> options) => Poll(
  id: 'poll-1',
  question: 'Vad ska vi äta?',
  creatorId: 'creator',
  createdAt: DateTime.utc(2026, 1, 1),
  options: options,
);

void main() {
  group('Poll.leader', () {
    test('is the option with most votes', () {
      final poll = _poll(const [
        PollOption(id: 'a', text: 'Tacos', voterIds: ['u1']),
        PollOption(id: 'b', text: 'Pasta', voterIds: ['u2', 'u3']),
      ]);
      expect(poll.leader?.id, 'b');
      expect(poll.tiedLeaders.map((o) => o.id), ['b']);
    });

    test('goes to the earlier option on a tie', () {
      final poll = _poll(const [
        PollOption(id: 'a', text: 'Tacos', voterIds: ['u1']),
        PollOption(id: 'b', text: 'Pasta', voterIds: ['u2']),
      ]);
      expect(poll.leader?.id, 'a');
      expect(poll.tiedLeaders.map((o) => o.id), ['a', 'b']);
    });

    test('is null while nobody has voted', () {
      final poll = _poll(const [
        PollOption(id: 'a', text: 'Tacos'),
        PollOption(id: 'b', text: 'Pasta'),
      ]);
      expect(poll.leader, isNull);
      expect(poll.tiedLeaders, isEmpty);
    });
  });

  group('confirmPollClose', () {
    Future<void> open(WidgetTester tester, Poll poll) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => confirmPollClose(context, poll),
              child: const Text('öppna'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('öppna'));
      await tester.pumpAndSettle();
    }

    testWidgets('names the leader and closes on confirm', (tester) async {
      bool? result;
      final poll = _poll(const [
        PollOption(id: 'a', text: 'Tacos', voterIds: ['u1']),
        PollOption(id: 'b', text: 'Pasta', voterIds: ['u2', 'u3']),
      ]);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await confirmPollClose(context, poll),
              child: const Text('öppna'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('öppna'));
      await tester.pumpAndSettle();

      expect(
        find.textContaining('Just nu leder Pasta med 2 röster'),
        findsOneWidget,
      );

      await tester.tap(find.text('Avsluta'));
      await tester.pumpAndSettle();
      expect(result, isTrue);
    });

    testWidgets('keeping the poll open returns false', (tester) async {
      bool? result;
      final poll = _poll(const [
        PollOption(id: 'a', text: 'Tacos', voterIds: ['u1']),
      ]);
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () async =>
                  result = await confirmPollClose(context, poll),
              child: const Text('öppna'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('öppna'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Behåll öppen'));
      await tester.pumpAndSettle();
      expect(result, isFalse);
    });

    testWidgets('says so on a tie and with no votes', (tester) async {
      await open(
        tester,
        _poll(const [
          PollOption(id: 'a', text: 'Tacos', voterIds: ['u1']),
          PollOption(id: 'b', text: 'Pasta', voterIds: ['u2']),
        ]),
      );
      expect(find.textContaining('lika mellan Tacos, Pasta'), findsOneWidget);
      expect(find.textContaining('Tacos kom först'), findsOneWidget);

      await tester.tap(find.text('Behåll öppen'));
      await tester.pumpAndSettle();
      await open(
        tester,
        _poll(const [PollOption(id: 'a', text: 'Tacos')]),
      );
      expect(find.textContaining('Ingen har röstat än'), findsOneWidget);
    });
  });
}
