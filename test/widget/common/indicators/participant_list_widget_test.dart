/// Widget tests for ParticipantListWidget.
///
/// Verifies empty-state collapse, header with l10n count, online-count badge
/// l10n, current-user highlighting via "Du" label, online/offline status
/// labels per participant, and avatar initials rendering.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/viewmodels/realtime/participant_tracker.dart';
import 'package:butlery/widgets/common/indicators/participant_list_widget.dart';

Widget _wrap(Widget child) => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(
    body: MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: child,
    ),
  ),
);

ParticipantActivity _activity({
  required String userId,
  required String name,
  required bool isOnline,
}) {
  return ParticipantActivity(
    userId: userId,
    displayName: name,
    lastSeen: DateTime.now(),
    isOnline: isOnline,
  );
}

void main() {
  group('ParticipantListWidget — empty', () {
    testWidgets('collapses to SizedBox.shrink when activities is empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          const ParticipantListWidget(
            activities: [],
            currentUserId: 'me',
          ),
        ),
      );
      await tester.pump();

      // No header icon / chips / text rendered.
      expect(
        find.descendant(
          of: find.byType(ParticipantListWidget),
          matching: find.byIcon(Icons.people),
        ),
        findsNothing,
      );
      expect(
        find.descendant(
          of: find.byType(ParticipantListWidget),
          matching: find.byType(Text),
        ),
        findsNothing,
      );
    });
  });

  group('ParticipantListWidget — populated', () {
    testWidgets('renders header with people icon + Swedish participant count', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ParticipantListWidget(
            activities: [
              _activity(userId: 'me', name: 'Anna Andersson', isOnline: true),
              _activity(userId: 'u2', name: 'Bert Bertsson', isOnline: false),
            ],
            currentUserId: 'me',
          ),
        ),
      );
      await tester.pump();

      expect(
        find.descendant(
          of: find.byType(ParticipantListWidget),
          matching: find.byIcon(Icons.people),
        ),
        findsOneWidget,
      );
      // Swedish l10n: participantsCount = "Deltagare ({count})"
      expect(find.text('Deltagare (2)'), findsOneWidget);
    });

    testWidgets(
      'online-indicator pill shows count of online participants only',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            ParticipantListWidget(
              activities: [
                _activity(userId: 'me', name: 'Anna', isOnline: true),
                _activity(userId: 'u2', name: 'Bert', isOnline: true),
                _activity(userId: 'u3', name: 'Cecilia', isOnline: false),
              ],
              currentUserId: 'me',
            ),
          ),
        );
        await tester.pump();

        // Swedish l10n: participantsOnlineCount = "{count} online"
        expect(find.text('2 online'), findsOneWidget);
      },
    );

    testWidgets('current user chip shows "Du" label instead of display name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ParticipantListWidget(
            activities: [
              _activity(userId: 'me', name: 'Anna Andersson', isOnline: true),
              _activity(userId: 'u2', name: 'Bert Bertsson', isOnline: true),
            ],
            currentUserId: 'me',
          ),
        ),
      );
      await tester.pump();

      // commonYou = "Du" — current user's display name should be replaced.
      expect(find.text('Du'), findsOneWidget);
      expect(find.text('Anna Andersson'), findsNothing);
      // Other participant keeps their real name.
      expect(find.text('Bert Bertsson'), findsOneWidget);
    });

    testWidgets('per-participant online/offline status label is localized', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ParticipantListWidget(
            activities: [
              _activity(userId: 'me', name: 'Anna', isOnline: true),
              _activity(userId: 'u2', name: 'Bert', isOnline: false),
            ],
            currentUserId: 'me',
          ),
        ),
      );
      await tester.pump();

      // userStatusOnline = "Online", userStatusOffline = "Offline".
      // The header has "Deltagare (2)" — assert by scoping under the chips.
      // Anna is current user → chip subtitle = "Online".
      // Bert → chip subtitle = "Offline".
      expect(find.text('Online'), findsOneWidget);
      // "Offline" appears once: Bert's chip subtitle. The online-pill never
      // says "Offline" (it always shows "N online"), so a global find is safe.
      expect(find.text('Offline'), findsOneWidget);
    });

    testWidgets('renders one chip row per activity', (tester) async {
      await tester.pumpWidget(
        _wrap(
          ParticipantListWidget(
            activities: [
              _activity(userId: 'me', name: 'Anna', isOnline: true),
              _activity(userId: 'u2', name: 'Bert', isOnline: false),
              _activity(userId: 'u3', name: 'Cecilia', isOnline: true),
            ],
            currentUserId: 'me',
          ),
        ),
      );
      await tester.pump();

      // Wrap renders the chips; assert all non-current names appear.
      expect(find.text('Bert'), findsOneWidget);
      expect(find.text('Cecilia'), findsOneWidget);
      expect(find.text('Du'), findsOneWidget);
    });

    testWidgets('chip avatar shows initials derived from display name', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          ParticipantListWidget(
            activities: [
              _activity(userId: 'me', name: 'Anna Andersson', isOnline: true),
              _activity(userId: 'u2', name: 'Bert Bertsson', isOnline: false),
            ],
            currentUserId: 'me',
          ),
        ),
      );
      await tester.pump();

      // UserAvatarWidgets.getInitials('Anna Andersson') → "AA"
      // UserAvatarWidgets.getInitials('Bert Bertsson')  → "BB"
      expect(find.text('AA'), findsOneWidget);
      expect(find.text('BB'), findsOneWidget);
    });

    testWidgets('canManageParticipants prop is accepted (default false)', (
      tester,
    ) async {
      // Production-shape prop: stored on the widget; render path doesn't
      // currently branch on it, so we just verify it round-trips without
      // throwing and the widget still renders. If management UI is added
      // later, expand this test to assert visible affordances.
      await tester.pumpWidget(
        _wrap(
          ParticipantListWidget(
            activities: [
              _activity(userId: 'me', name: 'Anna', isOnline: true),
            ],
            currentUserId: 'me',
            canManageParticipants: true,
            onRemoveParticipant: (_) {},
            onChangePermission: (_) {},
          ),
        ),
      );
      await tester.pump();

      final w = tester.widget<ParticipantListWidget>(
        find.byType(ParticipantListWidget),
      );
      expect(w.canManageParticipants, isTrue);
      expect(w.onRemoveParticipant, isNotNull);
      expect(w.onChangePermission, isNotNull);
    });
  });
}
