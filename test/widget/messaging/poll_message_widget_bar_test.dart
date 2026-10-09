// BUT-2261 finding 14: an option at 100% showed an empty result bar when the
// viewer had not voted for it.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/widgets/messaging/poll_message_widget.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('fills the bar of an option the viewer did not vote for', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: PollMessageWidget(
          poll: Poll(
            id: 'poll-1',
            question: 'Vad ska vi äta?',
            creatorId: 'user-creator',
            createdAt: DateTime.utc(2026, 1, 1),
            options: const [
              PollOption(id: 'opt-a', text: 'Tacos', voterIds: ['user-b']),
              PollOption(id: 'opt-b', text: 'Pasta'),
            ],
          ),
          currentUserId: 'user-viewer',
          isFromCurrentUser: false,
          voteHydration: PollVoteHydration.ok,
        ),
      ),
    );

    expect(find.text('100%'), findsOneWidget);
    final fullBar = find.byWidgetPredicate(
      (w) => w is FractionallySizedBox && w.widthFactor == 1.0,
    );
    expect(fullBar, findsOneWidget);
    final fill = tester.widget<Container>(
      find.descendant(of: fullBar, matching: find.byType(Container)).first,
    );
    final color = (fill.decoration! as BoxDecoration).color!;
    expect(color.a, greaterThan(0));
  });
}
