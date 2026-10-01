/// Widget tests for PollMessageWidget — recipe-aware rendering (BUT-340).
///
/// Verifies:
/// - Recipe options render a thumbnail + title + portions metadata
/// - Plain-text polls render unchanged (no thumbnails, no portions row)
/// - Tapping a recipe option's thumbnail calls [onRecipeTap]
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/messaging/poll_message_widget.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_mode_colors.dart';

Widget _themedApp(Widget child, Brightness brightness) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: brightness == Brightness.dark ? ThemeMode.dark : ThemeMode.light,
  home: Scaffold(body: child),
);

/// The option rows.
Iterable<BoxDecoration> _optionDecorations(WidgetTester tester) => tester
    .widgetList<Container>(find.byType(Container))
    .map((c) => c.decoration)
    .whereType<BoxDecoration>()
    .where((d) => d.border is Border && (d.border! as Border).top.width == 1.5);

Poll _recipePoll() {
  return Poll(
    id: 'poll-1',
    question: 'Vad ska vi äta?',
    creatorId: 'user-creator',
    createdAt: DateTime.now(),
    options: [
      PollOption(
        id: 'opt-1',
        text: 'Kycklinggryta med ris',
        recipeId: 'recipe-1',
        recipePortions: 4,
      ),
      PollOption(
        id: 'opt-2',
        text: 'Pasta bolognese',
        recipeId: 'recipe-2',
        recipePortions: 2,
      ),
    ],
  );
}

Poll _textPoll() {
  return Poll.create(
    question: 'Pizza or Sushi?',
    optionTexts: const ['Pizza', 'Sushi'],
    creatorId: 'user-creator',
  );
}

void main() {
  group('PollMessageWidget — recipe options', () {
    testWidgets('renders recipe titles + portions row for recipe options', (
      tester,
    ) async {
      final poll = _recipePoll();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: PollMessageWidget(
            voteHydration: PollVoteHydration.ok,
            poll: poll,
            currentUserId: 'viewer',
            isFromCurrentUser: false,
          ),
        ),
      );
      await tester.pump();

      // Recipe titles
      expect(find.text('Kycklinggryta med ris'), findsOneWidget);
      expect(find.text('Pasta bolognese'), findsOneWidget);

      // Portions metadata — "4 portioner" / "2 portioner" (Swedish label).
      expect(find.textContaining('4'), findsWidgets);
      expect(find.textContaining('2'), findsWidgets);

      // Question is rendered.
      expect(find.text('Vad ska vi äta?'), findsOneWidget);
    });

    testWidgets(
      'tapping a recipe option calls onRecipeTap when widget provides it',
      (tester) async {
        final poll = _recipePoll();
        String? tappedRecipeId;

        await tester.pumpWidget(
          createLocalizedTestApp(
            child: PollMessageWidget(
              voteHydration: PollVoteHydration.ok,
              poll: poll,
              currentUserId: 'viewer',
              isFromCurrentUser: false,
              onRecipeTap: (id) => tappedRecipeId = id,
            ),
          ),
        );
        await tester.pump();

        // Tap the fallback thumbnail of the first option (Icon restaurant_menu).
        final thumbnailIcons = find.byIcon(ButleryIcons.utensils);
        expect(thumbnailIcons, findsWidgets);
        await tester.tap(thumbnailIcons.first);
        await tester.pump();

        expect(tappedRecipeId, equals('recipe-1'));
      },
    );
  });

  group('PollMessageWidget — plain-text options (backward compat)', () {
    testWidgets('renders plain-text options without recipe chrome', (
      tester,
    ) async {
      final poll = _textPoll();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: PollMessageWidget(
            voteHydration: PollVoteHydration.ok,
            poll: poll,
            currentUserId: 'viewer',
            isFromCurrentUser: false,
          ),
        ),
      );
      await tester.pump();

      expect(find.text('Pizza'), findsOneWidget);
      expect(find.text('Sushi'), findsOneWidget);

      // Plain-text mode must not render the recipe fallback thumbnail icon.
      expect(find.byIcon(ButleryIcons.utensils), findsNothing);
    });
  });

  group(
    'PollMessageWidget — the voted option is a 1.5 px line, not a fill',
    () {
      final poll = Poll(
        id: 'poll-1',
        question: 'Pizza eller sushi?',
        creatorId: 'someone',
        createdAt: DateTime.utc(2026, 1, 1),
        options: const [
          PollOption(id: 'a', text: 'Pizza', voterIds: ['viewer']),
          PollOption(id: 'b', text: 'Sushi'),
        ],
      );

      for (final brightness in Brightness.values) {
        testWidgets(
          '${brightness.name}: incoming bubble draws the voted row in '
          'onSurface, the other row in no line, both on surface.base',
          (
            tester,
          ) async {
            await tester.pumpWidget(
              _themedApp(
                PollMessageWidget(
                  voteHydration: PollVoteHydration.ok,
                  poll: poll,
                  currentUserId: 'viewer',
                  isFromCurrentUser: false,
                ),
                brightness,
              ),
            );
            final cs = Theme.of(
              tester.element(find.byType(PollMessageWidget)),
            ).colorScheme;

            final rows = _optionDecorations(tester).toList();
            expect(rows, hasLength(2));
            expect(rows[0].border!.top.color, cs.onSurface);
            expect(rows[1].border!.top.color, Colors.transparent);
            expect(rows[0].color, cs.surface);
            expect(rows[1].color, cs.surface);
          },
        );

        testWidgets(
          '${brightness.name}: outgoing bubble draws the voted row in '
          'paper (onPrimary), because the bubble is ink in both modes',
          (
            tester,
          ) async {
            await tester.pumpWidget(
              _themedApp(
                PollMessageWidget(
                  voteHydration: PollVoteHydration.ok,
                  poll: poll,
                  currentUserId: 'viewer',
                  isFromCurrentUser: true,
                ),
                brightness,
              ),
            );
            final cs = Theme.of(
              tester.element(find.byType(PollMessageWidget)),
            ).colorScheme;

            final rows = _optionDecorations(tester).toList();
            expect(rows, hasLength(2));
            expect(rows[0].border!.top.color, cs.onPrimary);
            expect(rows[1].border!.top.color, Colors.transparent);
          },
        );
      }
    },
  );

  group('PollMessageWidget — secondary text on ink (BUT-2183)', () {
    final poll = Poll(
      id: 'poll-2',
      question: 'Pizza eller sushi?',
      creatorId: 'someone',
      createdAt: DateTime.utc(2026, 1, 1),
      options: const [
        PollOption(id: 'a', text: 'Pizza', voterIds: ['viewer']),
        PollOption(id: 'b', text: 'Sushi'),
      ],
    );

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: the vote count is text.secondary on '
          'ink when outgoing and onSurfaceVariant when incoming', (
        tester,
      ) async {
        Future<Color?> countColour(bool outgoing) async {
          await tester.pumpWidget(
            _themedApp(
              PollMessageWidget(
                voteHydration: PollVoteHydration.ok,
                poll: poll,
                currentUserId: 'viewer',
                isFromCurrentUser: outgoing,
              ),
              brightness,
            ),
          );
          return tester.widget<Text>(find.text('1 röst')).style!.color;
        }

        expect(await countColour(true), AppModeColors.textSecondaryOnInk());
        final incoming = await countColour(false);
        expect(
          incoming,
          Theme.of(
            tester.element(find.byType(PollMessageWidget)),
          ).colorScheme.onSurfaceVariant,
        );
      });
    }
  });

  group('PollMessageWidget — outgoing rows sit on inkRaised (BUT-2183)', () {
    final poll = Poll(
      id: 'poll-3',
      question: 'Pizza eller sushi?',
      creatorId: 'someone',
      createdAt: DateTime.utc(2026, 1, 1),
      options: const [
        PollOption(id: 'a', text: 'Pizza', voterIds: ['viewer']),
        PollOption(id: 'b', text: 'Sushi'),
      ],
    );

    for (final brightness in Brightness.values) {
      testWidgets('${brightness.name}: voted and unvoted rows are opaque '
          'palette.inkRaised, the same in both modes', (tester) async {
        await tester.pumpWidget(
          _themedApp(
            PollMessageWidget(
              voteHydration: PollVoteHydration.ok,
              poll: poll,
              currentUserId: 'viewer',
              isFromCurrentUser: true,
            ),
            brightness,
          ),
        );

        final rows = _optionDecorations(tester).toList();
        expect(rows, hasLength(2));
        for (final row in rows) {
          expect(row.color, AppColors.surfaceDark);
          expect(row.color!.a, 1.0);
        }
        expect(AppColors.surfaceDark, const Color(0xFF2F4437));
      });
    }
  });
}
