// BUT-931: TextLineSelector marks lines Butlery's local heuristic detector
// suggested with a "Butlerys förslag" chip, so the
// user can tell suggested content apart from lines they typed/selected
// themselves. (Labelled "Butlery's suggestion", not "AI" — it's a rule-based
// heuristic, not an LLM.) These tests assert
// that user-visible behaviour (chip presence, theme-resolved colour, a11y
// label, tap-to-toggle), not layout/padding internals.

import 'dart:ui' show Tristate;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/import/text_line_selector.dart';

import '../../infrastructure/helpers/ink_fill.dart';
import '../../test_support/semantics_announcement.dart';
import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  const lines = ['200 g smör', 'Vispa ihop', '3 dl mjölk'];

  Widget buildSelector({
    Set<int> selected = const {},
    Set<int> aiSuggested = const {},
    ValueChanged<Set<int>>? onChanged,
  }) {
    return createLocalizedTestApp(
      child: TextLineSelector(
        lines: lines,
        selectedIndices: selected,
        aiSuggestedIndices: aiSuggested,
        onSelectionChanged: onChanged ?? (_) {},
      ),
    );
  }

  group('TextLineSelector AI-provenance chip (BUT-931)', () {
    testWidgets('shows the Butlerys förslag chip only on ai-suggested lines', (
      tester,
    ) async {
      await tester.pumpWidget(buildSelector(aiSuggested: {0}));

      // Swedish locale → "Butlerys förslag". One suggested line ⇒ exactly one chip.
      expect(find.text('Butlerys förslag'), findsOneWidget);
      // The auto_awesome glyph is the chip's icon.
      expect(find.byIcon(ButleryIcons.sparkles), findsOneWidget);
    });

    testWidgets('shows no chip when no lines are ai-suggested', (tester) async {
      await tester.pumpWidget(buildSelector());

      expect(find.text('Butlerys förslag'), findsNothing);
      expect(find.byIcon(ButleryIcons.sparkles), findsNothing);
    });

    testWidgets('renders one chip per ai-suggested line', (tester) async {
      await tester.pumpWidget(buildSelector(aiSuggested: {0, 2}));

      expect(find.text('Butlerys förslag'), findsNWidgets(2));
    });

    testWidgets('chip colour comes from the live theme, not a hardcoded value', (
      tester,
    ) async {
      late ColorScheme cs;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              cs = Theme.of(context).colorScheme;
              return TextLineSelector(
                lines: lines,
                selectedIndices: const {},
                aiSuggestedIndices: const {0},
                onSelectionChanged: (_) {},
              );
            },
          ),
        ),
      );

      // The chip's icon resolves to onSecondaryContainer — a theme tweak should
      // move this in lockstep, not break the test.
      final icon = tester.widget<Icon>(find.byIcon(ButleryIcons.sparkles));
      expect(icon.color, cs.onSecondaryContainer);
    });
  });

  group('TextLineSelector a11y provenance (BUT-931)', () {
    testWidgets(
      'ai-suggested line carries the provenance hint in its semantics',
      (tester) async {
        await tester.pumpWidget(buildSelector(aiSuggested: {0}));

        // The provenance comes from the visible chip, announced once.
        final ai = find.bySemanticsLabel(RegExp('200 g smör'));
        expect(
          announcedLines(tester, ai),
          contains('Butlerys förslag'),
        );
        expectNothingAnnouncedTwice(tester, ai);
        expectActivatable(tester, ai);
      },
    );

    testWidgets('a row announces whether it is selected', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(buildSelector(selected: {1}));

      Tristate selectedFlag(String line) => tester
          .getSemantics(find.bySemanticsLabel(RegExp(line)))
          .getSemanticsData()
          .flagsCollection
          .isSelected;

      expect(selectedFlag('Vispa ihop'), Tristate.isTrue);
      expect(selectedFlag('200 g smör'), Tristate.isFalse);
      handle.dispose();
    });
  });

  group('TextLineSelector selection behaviour', () {
    testWidgets('tapping an ai-suggested line still toggles its selection', (
      tester,
    ) async {
      Set<int>? lastSelection;
      await tester.pumpWidget(
        buildSelector(aiSuggested: {0}, onChanged: (s) => lastSelection = s),
      );

      await tester.tap(find.text('200 g smör'));
      await tester.pump();

      // The chip is decorative — provenance must not block selection, which is
      // the whole point of the assisted-import picker.
      expect(lastSelection, contains(0));
    });
  });

  // P7-B4: a chosen line is surface.selected with a real border, never a
  // tint (tokens.json:40-53, :116-119; Grafisk manual v6:209).
  for (final dark in [false, true]) {
    testWidgets('a chosen line is the solid surface.selected plate '
        '(${dark ? 'dark' : 'light'})', (tester) async {
      final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: TextLineSelector(
              lines: lines,
              selectedIndices: const {1},
              onSelectionChanged: (_) {},
            ),
          ),
        ),
      );
      await tester.pump();

      final plates = tester
          .widgetList<Material>(
            find.descendant(
              of: find.byType(TextLineSelector),
              matching: find.byType(Material),
            ),
          )
          .map((m) => m.color)
          .whereType<Color>()
          .toList();
      expect(
        plates.where((c) => c == theme.colorScheme.surfaceContainerHighest),
        hasLength(1),
      );
      expect(
        plates.where((c) => c.a > 0 && c.a < 1),
        isEmpty,
        reason: 'no plate is a translucent tint',
      );

      // The chosen line's edge is the drawn "Vald" border: 1.5 px
      // text.primary (Grafisk manual v6:207).
      final borders = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(TextLineSelector),
              matching: find.byType(Container),
            ),
          )
          .map((c) => c.decoration)
          .whereType<BoxDecoration>()
          .map((d) => d.border)
          .whereType<Border>()
          .where((b) => b.top.width == 1.5)
          .toList();
      expect(borders, hasLength(1));
      expect(borders.single.top.color, theme.colorScheme.onSurface);
    });
  }

  // BUT-2205: a chosen line rests on surface.raised, so its press takes the
  // step on raised; an unchosen line rests on the dialog and takes raised.
  for (final dark in [false, true]) {
    final theme = dark ? AppTheme.darkTheme : AppTheme.lightTheme;
    final mode = dark ? 'dark' : 'light';

    Widget selector() => createLocalizedTestApp(
      child: Theme(
        data: theme,
        child: TextLineSelector(
          lines: lines,
          selectedIndices: const {1},
          onSelectionChanged: (_) {},
        ),
      ),
    );

    testWidgets('a pressed chosen line takes the step on raised ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(selector());
      final target = find.text('Vispa ihop');
      final gesture = await holdPress(tester, target);
      expect(
        paintsInkFill(
          tester,
          target,
          ModeColors.of(theme.brightness).pressedOnRaised,
        ),
        isTrue,
      );
      await gesture.cancel();
    });

    testWidgets('a pressed unchosen line takes surface.raised ($mode)', (
      tester,
    ) async {
      await tester.pumpWidget(selector());
      final target = find.text('200 g smör');
      final gesture = await holdPress(tester, target);
      expect(
        paintsInkFill(
          tester,
          target,
          theme.colorScheme.surfaceContainerHighest,
        ),
        isTrue,
      );
      await gesture.cancel();
    });
  }
}
