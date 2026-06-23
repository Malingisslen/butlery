// test/widget/cooking/cooking_session_card_test.dart
//
// BUT-408: widget pumps for the live "Erik lagar just nu" card.
// Covers: idle (hidden), single, merge (2 cooks on same recipe),
// and reduce-motion (no pulse animation).

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/cooking/cooking_session.dart';
import 'package:butlery/widgets/cooking/cooking_session_card.dart';
import 'package:butlery/widgets/common/indicators/pulse_dot.dart';

void main() {
  CookingSession session({
    String id = 'r1',
    String title = 'Kycklinggryta',
    String userId = 'u1',
    String userName = 'Erik',
    DateTime? at,
    int? currentStep,
    int? totalSteps,
  }) => CookingSession(
    recipeId: id,
    recipeTitle: title,
    startedAt: at ?? DateTime(2026, 4, 20, 18),
    userId: userId,
    userName: userName,
    currentStep: currentStep,
    totalSteps: totalSteps,
  );

  Widget wrap(Widget child, {bool disableAnimations = false}) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(disableAnimations: disableAnimations),
          child: child,
        ),
      ),
    );
  }

  group('CookingSessionCard', () {
    testWidgets('renders SizedBox.shrink when no sessions', (tester) async {
      await tester.pumpWidget(
        wrap(const CookingSessionCard(sessions: [])),
      );

      // The primary label must NOT appear anywhere.
      expect(find.textContaining('lagar'), findsNothing);
      // And the pulse dot must be absent.
      expect(find.byType(PulseDot), findsNothing);
    });

    testWidgets('single session renders "Erik lagar kycklinggryta"', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          CookingSessionCard(sessions: [session()]),
          // Reduce-motion avoids an infinite repeating animation that
          // would otherwise make pumpAndSettle hang.
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(find.text('Erik lagar Kycklinggryta'), findsOneWidget);
      expect(find.text('lagar just nu'), findsOneWidget);
      expect(find.byType(PulseDot), findsOneWidget);
      expect(find.byIcon(Icons.chevron_right), findsOneWidget);
    });

    testWidgets('two sessions on the same recipe merge with ampersand', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          CookingSessionCard(
            sessions: [
              session(userId: 'u1', userName: 'Erik'),
              session(userId: 'u2', userName: 'Sara'),
            ],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(find.text('Erik & Sara lagar Kycklinggryta'), findsOneWidget);
      expect(find.byType(PulseDot), findsOneWidget);
    });

    // -------------------------------------------------------------------
    // BUT-408 follow-up: step suffix rendering.
    // -------------------------------------------------------------------

    testWidgets('single session WITHOUT step fields renders no suffix', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          CookingSessionCard(sessions: [session()]),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      // Base line present, no " · steg" appended.
      expect(find.text('Erik lagar Kycklinggryta'), findsOneWidget);
      expect(find.textContaining('steg'), findsNothing);
    });

    testWidgets('single session WITH step fields renders "· steg 3 av 7"', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          CookingSessionCard(
            sessions: [
              session(currentStep: 3, totalSteps: 7),
            ],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      // Whole line is one Text widget — assert the full string so we know the
      // separator, order, and Swedish copy are all intact.
      expect(
        find.text('Erik lagar Kycklinggryta · steg 3 av 7'),
        findsOneWidget,
      );
    });

    testWidgets('merge case hides the step suffix even when set per-session', (
      tester,
    ) async {
      // Two cooks on the same recipe; the primary has step tracking but the
      // merged line must NOT carry the step — different cooks are on
      // different steps.
      await tester.pumpWidget(
        wrap(
          CookingSessionCard(
            sessions: [
              session(
                userId: 'u1',
                userName: 'Erik',
                currentStep: 3,
                totalSteps: 7,
              ),
              session(
                userId: 'u2',
                userName: 'Sara',
                currentStep: 5,
                totalSteps: 7,
              ),
            ],
          ),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      expect(find.text('Erik & Sara lagar Kycklinggryta'), findsOneWidget);
      expect(find.textContaining('steg'), findsNothing);
    });

    testWidgets('reduce-motion: pulse dot is rendered but not animated', (
      tester,
    ) async {
      await tester.pumpWidget(
        wrap(
          CookingSessionCard(sessions: [session()]),
          disableAnimations: true,
        ),
      );
      await tester.pump();

      // The dot is still on screen — reduce-motion only stops the scale
      // pulse, it doesn't hide the presence indicator.
      expect(find.byType(PulseDot), findsOneWidget);
      expect(find.text('Erik lagar Kycklinggryta'), findsOneWidget);

      // With reduce-motion active, pumping for a frame must be safe — no
      // running AnimationController timers means pump completes cleanly.
      await tester.pump(const Duration(seconds: 2));
      // Still visible after a long gap.
      expect(find.byType(PulseDot), findsOneWidget);
    });
  });
}
