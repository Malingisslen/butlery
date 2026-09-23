/// Dark-mode sweep of lib/widgets (package 4, P4-T7).
///
/// colorScheme.primary is surface.ink #24382C in BOTH schemes
/// (tools/app-theme-map.json scheme.slots.primary; tokens.json
/// semantic["surface.ink"]), so ink used as a foreground vanished on the dark
/// base #17251D (1.27:1). These tests pin a representative set of shared
/// widgets to the mode-aware roles in both modes:
/// - text and glyphs on the page are text.primary (onSurface): ink on light,
///   paper on dark (tokens.json semantic["text.primary"]);
/// - a chosen chip is an ink fill with paper text, edged in text.primary
///   (Komponentark v1:142, dark matrix v1:523);
/// - a chosen reaction is surface.selected with a real border, never an ink
///   tint (tokens.json:40-53 opacityLadder, semantic["surface.selected"]);
/// - status snackbars are the ink snackbar, never a status fill
///   (Komponentark v1:300, :745-750; PQ-09 = A).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/cards/selection_card.dart';
import 'package:butlery/widgets/common/emoji_reaction_display.dart';
import 'package:butlery/widgets/common/filter_status_chip.dart';
import 'package:butlery/widgets/common/profile/utils/result_displayer.dart';
import 'package:butlery/widgets/common/search_filter/quick_filter_chips.dart';
import 'package:butlery/widgets/import/components/step_progress_indicator.dart';

const _paper = Color(0xFFF5F4ED);
const _ink = Color(0xFF24382C);
const _inkDeep = Color(0xFF17251D);
const _raisedDark = Color(0xFF2F4437);

double _luminance(Color c) => c.computeLuminance();

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a), lb = _luminance(b);
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

Widget _app(ThemeData theme, Widget child) => MaterialApp(
  theme: theme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(body: Center(child: child)),
);

Color? _textColor(WidgetTester tester, String text) {
  final widget = tester.widget<Text>(find.text(text));
  return widget.style?.color;
}

void main() {
  for (final (mode, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    final cs = theme.colorScheme;
    final isDark = mode == 'dark';

    group('lib/widgets dark-mode sweep ($mode)', () {
      test('premise: primary is ink in both schemes', () {
        expect(cs.primary, _ink);
        expect(cs.surface, isDark ? _inkDeep : _paper);
        expect(cs.onSurface, isDark ? _paper : _ink);
      });

      testWidgets('a tag badge reads text.primary on the page', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            theme,
            const UnifiedBadge(label: 'Vego', variant: BadgeVariant.outlined),
          ),
        );
        final color = _textColor(tester, 'Vego')!;
        expect(color, cs.onSurface);
        expect(_contrast(color, cs.surface), greaterThanOrEqualTo(4.5));
      });

      testWidgets('the filter count reads text.primary on the page', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            theme,
            const FilterStatusChip(filterParts: ['Vego'], selectedCount: 2),
          ),
        );
        final color = _textColor(tester, '2 valda')!;
        expect(color, cs.onSurface);
        expect(_contrast(color, cs.surface), greaterThanOrEqualTo(4.5));
      });

      testWidgets(
        'a chosen quick filter is an ink chip with paper text and a '
        'text.primary edge',
        (tester) async {
          await tester.pumpWidget(
            _app(
              theme,
              QuickFilterChips(
                options: const [
                  QuickFilterOption(id: 'veg', label: 'Vegetariskt'),
                  QuickFilterOption(id: 'fast', label: 'Snabbt'),
                ],
                selectedIds: const {'veg'},
                onFilterToggle: (_) {},
                showAllOption: false,
              ),
            ),
          );
          await tester.pumpAndSettle();

          final chosenText = _textColor(tester, 'Vegetariskt')!;
          expect(chosenText, cs.onPrimary);
          expect(_contrast(chosenText, cs.primary), greaterThanOrEqualTo(4.5));

          final chosenBox = tester.widget<AnimatedContainer>(
            find.ancestor(
              of: find.text('Vegetariskt'),
              matching: find.byType(AnimatedContainer),
            ),
          );
          final deco = chosenBox.decoration! as BoxDecoration;
          expect(deco.color, cs.primary);
          expect((deco.border! as Border).top.color, cs.onSurface);
          if (isDark) {
            // The paper edge of the dark drawing (Komponentark v1:523).
            expect((deco.border! as Border).top.color, _paper);
          }

          final restText = _textColor(tester, 'Snabbt')!;
          expect(restText, cs.onSurface);
        },
      );

      testWidgets(
        'your reaction is surface.selected with a text.primary border, '
        'never an ink tint',
        (tester) async {
          await tester.pumpWidget(
            _app(
              theme,
              EmojiReactionDisplay(
                reactions: const {
                  'heart': ['me', 'you'],
                },
                currentUserId: 'me',
                onReactionTap: (_) {},
              ),
            ),
          );
          final box = tester.widget<Container>(
            find
                .ancestor(of: find.text('2'), matching: find.byType(Container))
                .first,
          );
          final deco = box.decoration! as BoxDecoration;
          expect(deco.color, cs.surfaceContainerHighest);
          expect(deco.color!.a, 1.0, reason: 'opacity is never a state');
          if (isDark) expect(deco.color, _raisedDark);
          final border = (deco.border! as Border).top.color;
          expect(border, cs.onSurface);
          expect(border.a, 1.0);

          final count = _textColor(tester, '2')!;
          expect(count, cs.onSurface);
          expect(_contrast(count, deco.color!), greaterThanOrEqualTo(4.5));
        },
      );

      testWidgets('a chosen card has a text.primary border', (tester) async {
        await tester.pumpWidget(
          _app(
            theme,
            const SelectionCard(isSelected: true, child: Text('Kort')),
          ),
        );
        final card = tester.widget<Card>(find.byType(Card));
        final side = (card.shape! as RoundedRectangleBorder).side;
        expect(side.color, cs.onSurface);
        expect(_contrast(side.color, cs.surface), greaterThanOrEqualTo(3.0));
      });

      testWidgets('a done step connector is text.primary', (tester) async {
        await tester.pumpWidget(
          _app(
            theme,
            const StepProgressIndicator(currentStep: 2, totalSteps: 3),
          ),
        );
        final lines = tester
            .widgetList<Container>(find.byType(Container))
            .where((c) => c.constraints?.maxHeight == 2 && c.color != null)
            .map((c) => c.color)
            .toList();
        expect(lines, contains(cs.onSurface));
        // In light text.primary and ink share #24382C; in dark the line is
        // paper, never the ink that vanished on #17251D.
        if (isDark) expect(lines, isNot(contains(cs.primary)));
      });

      testWidgets('a failed result is the ink snackbar, not a red fill', (
        tester,
      ) async {
        await tester.pumpWidget(
          _app(
            theme,
            Builder(
              builder: (context) => TextButton(
                onPressed: () => ResultDisplayer.showResult(
                  context,
                  success: false,
                  message: 'Kunde inte spara profilen',
                ),
                child: const Text('Visa'),
              ),
            ),
          ),
        );
        await tester.tap(find.text('Visa'));
        await tester.pump();
        final bar = tester.widget<SnackBar>(find.byType(SnackBar));
        expect(bar.backgroundColor, isNull, reason: 'the theme gives ink');
        expect(bar.content, isA<InkSnackBar>());
        expect(theme.snackBarTheme.backgroundColor, _ink);
      });
    });
  }
}
