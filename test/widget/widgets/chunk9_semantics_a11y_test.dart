// BUT-739 chunk-9: Semantics coverage for the residual-tap-target sweep
// surfaced by `tools/audit_unwrapped_tap_targets.dart`.
//
// Verifies that the InkWell / GestureDetector wraps applied in this sweep
// expose localized Semantics labels via `find.bySemanticsLabel`. Per the
// chunk-2..-8 convention we cover only the widgets that render without
// heavy ViewModel/Provider scaffolding here — the broader file set is
// guarded by the audit script.
//
// Covered:
// * PollMessageWidget — option vote tap + recipe-thumbnail tap (the two
//   wraps in lib/widgets/messaging/poll_message_widget.dart).
// * Veckomeny view-mode toggle (private `_toggleButton` reachable via the
//   public `VeckomenyView`, but cheaper to verify via the same Semantics
//   wrapper used in production — kept out here to avoid VM scaffolding).

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/widgets/messaging/poll_message_widget.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';

void main() {
  setUpAll(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  group('BUT-739 chunk-9 widget Semantics labels', () {
    testWidgets(
      'PollMessageWidget — text option exposes localized vote label',
      (tester) async {
        final handle = tester.ensureSemantics();

        final poll = Poll(
          id: 'poll_1',
          question: 'Vad ska vi äta?',
          options: const [
            PollOption(id: 'opt_1', text: 'Pasta'),
            PollOption(id: 'opt_2', text: 'Sallad'),
          ],
          creatorId: 'u_1',
          createdAt: DateTime(2026, 4, 29),
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: PollMessageWidget(
              voteHydration: PollVoteHydration.ok,
              poll: poll,
              currentUserId: 'u_1',
              isFromCurrentUser: true,
              onVote: (_) {},
            ),
          ),
        );

        // Swedish: "Rösta på Pasta"
        expect(
          find.bySemanticsLabel(RegExp(r'^Rösta på Pasta')),
          findsOneWidget,
        );
        expect(
          find.bySemanticsLabel(RegExp(r'^Rösta på Sallad')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );

    testWidgets(
      'PollMessageWidget — recipe option thumbnail exposes open-recipe label',
      (tester) async {
        final handle = tester.ensureSemantics();

        final poll = Poll(
          id: 'poll_2',
          question: 'Vad ska vi äta?',
          options: const [
            PollOption(
              id: 'opt_a',
              text: 'Köttbullar',
              recipeId: 'r_kb',
            ),
          ],
          creatorId: 'u_1',
          createdAt: DateTime(2026, 4, 29),
        );

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: PollMessageWidget(
              voteHydration: PollVoteHydration.ok,
              poll: poll,
              currentUserId: 'u_1',
              isFromCurrentUser: true,
              onVote: (_) {},
              onRecipeTap: (_) {},
            ),
          ),
        );

        // The recipe-thumbnail wrapper announces "Visa receptet Köttbullar".
        expect(
          find.bySemanticsLabel(RegExp(r'^Visa receptet Köttbullar')),
          findsOneWidget,
        );
        handle.dispose();
      },
    );
  });
}
