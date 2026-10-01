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
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/indicators/participant_list_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_colors_dark.dart';
import 'package:butlery/theme/app_theme.dart';

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

Widget _wrapThemed(Widget child, ThemeData theme) => MaterialApp(
  theme: theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: child),
);

BoxDecoration _boxAround(WidgetTester tester, Finder of) => tester
    .widgetList<Container>(
      find.ancestor(of: of, matching: find.byType(Container)),
    )
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .firstWhere((d) => d.color != null);

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
          matching: find.byIcon(ButleryIcons.users),
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
          matching: find.byIcon(ButleryIcons.users),
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

  // BUT-2183 5b: fills leave the old opacity steps. The online pill is a
  // success notice (tint fill, no border); the current user's chip is
  // surface.raised with the same border.subtle as the others; the avatar
  // circle is surface.raised.
  group('ParticipantListWidget tokens (BUT-2183)', () {
    for (final (name, theme, successTint, success) in [
      (
        'light',
        AppTheme.lightTheme,
        AppColors.surfaceTintSuccess,
        AppColors.success,
      ),
      (
        'dark',
        AppTheme.darkTheme,
        AppColorsDark.surfaceTintSuccess,
        AppColorsDark.success,
      ),
    ]) {
      testWidgets('$name: the online pill is tint.success, no border, with '
          'mode-aware success text', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(
            ParticipantListWidget(
              activities: [
                _activity(userId: 'me', name: 'Anna', isOnline: true),
              ],
              currentUserId: 'me',
            ),
            theme,
          ),
        );
        await tester.pump();

        final label = find.text('1 online');
        final box = _boxAround(tester, label);
        expect(box.color, successTint);
        expect(box.border, isNull);
        expect(tester.widget<Text>(label).style?.color, success);
      });

      testWidgets('$name: the current user chip is surface.raised, others '
          'surface, both with border.subtle', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(
            ParticipantListWidget(
              activities: [
                _activity(userId: 'me', name: 'Anna', isOnline: true),
                _activity(userId: 'u2', name: 'Bert', isOnline: true),
              ],
              currentUserId: 'me',
            ),
            theme,
          ),
        );
        await tester.pump();

        final cs = theme.colorScheme;
        final mine = _boxAround(tester, find.text('Du'));
        expect(mine.color, cs.surfaceContainerHighest);
        expect(mine.border, Border.all(color: cs.outlineVariant));
        final other = _boxAround(tester, find.text('Bert'));
        expect(other.color, cs.surface);
        expect(other.border, Border.all(color: cs.outlineVariant));
      });

      testWidgets('$name: the avatar circle is surface.raised', (tester) async {
        await tester.pumpWidget(
          _wrapThemed(
            ParticipantListWidget(
              activities: [
                _activity(userId: 'u2', name: 'Bert Bertsson', isOnline: true),
              ],
              currentUserId: 'me',
            ),
            theme,
          ),
        );
        await tester.pump();

        final circles = tester
            .widgetList<Container>(find.byType(Container))
            .map((c) => c.decoration)
            .whereType<BoxDecoration>()
            .where((d) => d.shape == BoxShape.circle)
            .toList();
        expect(circles, hasLength(1));
        expect(circles.single.color, theme.colorScheme.surfaceContainerHighest);
      });
    }
  });
}
