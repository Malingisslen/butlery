// BUT-2183 5f, decision B101 (2026-10-01, option A throughout): the poll and
// share cards inside a chat bubble, pinned in both modes.
//
//  2. poll progress bars: raised on a surface row in an incoming bubble; the
//     ink border line on an inkRaised track in an outgoing one, with the
//     percentage in paper text
//  3. the recipe fallback thumbnail is an ink square on an outgoing row
//  5. the share card's icon box is raised in an incoming bubble and ink in an
//     outgoing one
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/messaging/message.dart';
import 'package:butlery/models/messaging/poll.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/messaging/builders/message_content_builder.dart';
import 'package:butlery/widgets/messaging/poll_message_widget.dart';

Widget _themedApp(Widget child, ThemeData theme) => MaterialApp(
  locale: const Locale('sv'),
  supportedLocales: AppLocalizations.supportedLocales,
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  theme: theme,
  home: Scaffold(body: child),
);

double _luminance(Color c) {
  double f(double v) =>
      v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4).toDouble();
  return 0.2126 * f(c.r) + 0.7152 * f(c.g) + 0.0722 * f(c.b);
}

double _contrast(Color fg, Color bg) {
  final a = _luminance(fg);
  final b = _luminance(bg);
  return (math.max(a, b) + 0.05) / (math.min(a, b) + 0.05);
}

Color? _textColor(WidgetTester tester, Finder of) =>
    tester.widget<Text>(of).style?.color;

Color? _barColor(WidgetTester tester, Finder fraction) {
  final bar = tester.widget<FractionallySizedBox>(fraction).child! as Container;
  return (bar.decoration! as BoxDecoration).color;
}

Color? _trackColor(WidgetTester tester, Finder fraction) {
  final stack = tester.widget<Stack>(
    find.ancestor(of: fraction, matching: find.byType(Stack)).first,
  );
  final track = (stack.children.first as Positioned).child as Container;
  return (track.decoration! as BoxDecoration).color;
}

Color? _rowColor(WidgetTester tester, Finder fraction) {
  final row = tester.widget<Container>(
    find
        .ancestor(
          of: fraction,
          matching: find.byWidgetPredicate(
            (w) =>
                w is Container &&
                w.decoration is BoxDecoration &&
                (w.decoration! as BoxDecoration).border is Border,
          ),
        )
        .first,
  );
  return (row.decoration! as BoxDecoration).color;
}

Poll _poll({required bool recipes}) => Poll(
  id: 'poll-b101',
  question: 'Vad ska vi äta?',
  creatorId: 'someone',
  createdAt: DateTime.utc(2026, 1, 1),
  options: [
    PollOption(
      id: 'a',
      text: 'Pizza',
      voterIds: const ['viewer'],
      recipeId: recipes ? 'r1' : null,
    ),
    PollOption(
      id: 'b',
      text: 'Sushi',
      voterIds: const ['other'],
      recipeId: recipes ? 'r2' : null,
    ),
  ],
);

Widget _pollWidget(Poll poll, {required bool outgoing}) => PollMessageWidget(
  voteHydration: PollVoteHydration.ok,
  poll: poll,
  currentUserId: 'viewer',
  isFromCurrentUser: outgoing,
);

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;

    group('B101 poll bars ($name)', () {
      testWidgets('2: incoming text option draws the voted bar raised on a '
          'surface row, percentage in onSurfaceVariant', (tester) async {
        await tester.pumpWidget(
          _themedApp(
            _pollWidget(_poll(recipes: false), outgoing: false),
            theme,
          ),
        );

        final voted = find.byType(FractionallySizedBox).first;
        expect(_barColor(tester, voted), cs.surfaceContainerHighest);
        expect(_rowColor(tester, voted), cs.surface);
        final percent = find.text('50%').first;
        expect(_textColor(tester, percent), cs.onSurfaceVariant);
        expect(
          _contrast(cs.onSurfaceVariant, cs.surfaceContainerHighest),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(cs.onSurface, cs.surfaceContainerHighest),
          greaterThanOrEqualTo(4.5),
        );
      });

      testWidgets('2: outgoing text option draws the voted bar in the ink '
          'border line on inkRaised, percentage and label in paper', (
        tester,
      ) async {
        await tester.pumpWidget(
          _themedApp(_pollWidget(_poll(recipes: false), outgoing: true), theme),
        );

        final voted = find.byType(FractionallySizedBox).first;
        expect(_barColor(tester, voted), AppModeColors.borderOnInk());
        expect(_barColor(tester, voted), const Color(0xFF3F5145));
        expect(_rowColor(tester, voted), AppModeColors.surfaceRaisedOnInk());
        expect(_textColor(tester, find.text('50%').first), cs.onPrimary);
        expect(_textColor(tester, find.text('Pizza')), cs.onPrimary);
        expect(
          _contrast(cs.onPrimary, AppModeColors.borderOnInk()),
          greaterThanOrEqualTo(4.5),
        );
      });

      for (final outgoing in [false, true]) {
        final side = outgoing ? 'outgoing' : 'incoming';
        testWidgets('2: $side recipe option bar and track are solid, the '
            'same for a voted and an unvoted option', (tester) async {
          await tester.pumpWidget(
            _themedApp(
              _pollWidget(_poll(recipes: true), outgoing: outgoing),
              theme,
            ),
          );

          final bars = find.byType(FractionallySizedBox);
          expect(bars, findsNWidgets(2));
          final barToken = outgoing
              ? AppModeColors.borderOnInk()
              : cs.surfaceContainerHighest;
          final trackToken = outgoing
              ? AppModeColors.surfaceRaisedOnInk()
              : cs.surface;
          for (final bar in [bars.at(0), bars.at(1)]) {
            expect(_barColor(tester, bar), barToken);
            expect(_barColor(tester, bar)!.a, 1.0);
            expect(_trackColor(tester, bar), trackToken);
            expect(_trackColor(tester, bar)!.a, 1.0);
          }
          final percentToken = outgoing ? cs.onPrimary : cs.onSurfaceVariant;
          expect(find.text('50%'), findsNWidgets(2));
          for (final percent in find.text('50%').evaluate()) {
            expect(
              (percent.widget as Text).style?.color,
              percentToken,
            );
          }
        });
      }

      testWidgets('3: the fallback thumbnail is an ink square with a paper '
          'icon when outgoing, raised with a secondary icon when incoming', (
        tester,
      ) async {
        for (final outgoing in [true, false]) {
          await tester.pumpWidget(
            _themedApp(
              _pollWidget(_poll(recipes: true), outgoing: outgoing),
              theme,
            ),
          );

          final glyph = find.byWidgetPredicate(
            (w) => w is ButleryIcon && w.icon == ButleryIcons.utensils,
          );
          final square = tester
              .widgetList<DecoratedBox>(
                find.ancestor(
                  of: glyph.first,
                  matching: find.byType(DecoratedBox),
                ),
              )
              .map((d) => d.decoration)
              .whereType<BoxDecoration>()
              .firstWhere((d) => d.color != null);
          final fill = outgoing ? cs.primary : cs.surfaceContainerHighest;
          final iconColor = outgoing ? cs.onPrimary : cs.onSurfaceVariant;
          expect(square.color, fill);
          expect(square.color!.a, 1.0);
          expect(tester.widget<ButleryIcon>(glyph.first).color, iconColor);
          expect(_contrast(iconColor, fill), greaterThanOrEqualTo(4.5));
          if (outgoing) {
            // It must stand out from the row it sits on.
            expect(fill, isNot(AppModeColors.surfaceRaisedOnInk()));
          }
        }
      });
    });

    group('B101 share card ($name)', () {
      for (final outgoing in [false, true]) {
        testWidgets(
          '5: the icon box is ${outgoing ? 'ink with a paper icon' : 'raised with an onSurface icon'} '
          'in an ${outgoing ? 'outgoing' : 'incoming'} bubble',
          (
            tester,
          ) async {
            final message = Message.recipeShare(
              conversationId: 'c1',
              senderId: 'u1',
              senderDisplayName: 'Anna',
              recipeId: 'r1',
              recipeTitle: 'Pannkakor',
            );
            await tester.pumpWidget(
              _themedApp(
                Builder(
                  builder: (context) => MessageContentBuilder.build(
                    context: context,
                    message: message,
                    isFromCurrentUser: outgoing,
                  ),
                ),
                theme,
              ),
            );

            final glyph = find.byWidgetPredicate(
              (w) => w is ButleryIcon && w.icon == ButleryIcons.utensils,
            );
            final box = tester
                .widgetList<Container>(
                  find.ancestor(of: glyph, matching: find.byType(Container)),
                )
                .map((c) => c.decoration)
                .whereType<BoxDecoration>()
                .firstWhere((d) => d.color != null);
            final fill = outgoing ? cs.primary : cs.surfaceContainerHighest;
            final iconColor = outgoing ? cs.onPrimary : cs.onSurface;
            expect(box.color, fill);
            expect(box.color!.a, 1.0);
            expect(tester.widget<ButleryIcon>(glyph).color, iconColor);
            expect(_contrast(iconColor, fill), greaterThanOrEqualTo(4.5));
          },
        );
      }
    });
  }
}
