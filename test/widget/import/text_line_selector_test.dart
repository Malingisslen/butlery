// BUT-931: TextLineSelector marks AI/heuristic-suggested lines with an
// "AI-förslag" chip + an a11y provenance hint, so the user can tell suggested
// content apart from lines they typed/selected themselves. These tests assert
// that user-visible behaviour (chip presence, theme-resolved colour, a11y
// label, tap-to-toggle), not layout/padding internals.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/import/text_line_selector.dart';

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
    testWidgets('shows the AI-förslag chip only on ai-suggested lines',
        (tester) async {
      await tester.pumpWidget(buildSelector(aiSuggested: {0}));

      // Swedish locale → "AI-förslag". One suggested line ⇒ exactly one chip.
      expect(find.text('AI-förslag'), findsOneWidget);
      // The auto_awesome glyph is the chip's icon.
      expect(find.byIcon(Icons.auto_awesome), findsOneWidget);
    });

    testWidgets('shows no chip when no lines are ai-suggested', (tester) async {
      await tester.pumpWidget(buildSelector());

      expect(find.text('AI-förslag'), findsNothing);
      expect(find.byIcon(Icons.auto_awesome), findsNothing);
    });

    testWidgets('renders one chip per ai-suggested line', (tester) async {
      await tester.pumpWidget(buildSelector(aiSuggested: {0, 2}));

      expect(find.text('AI-förslag'), findsNWidgets(2));
    });

    testWidgets('chip colour comes from the live theme, not a hardcoded value',
        (tester) async {
      late ColorScheme cs;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(builder: (context) {
            cs = Theme.of(context).colorScheme;
            return TextLineSelector(
              lines: lines,
              selectedIndices: const {},
              aiSuggestedIndices: const {0},
              onSelectionChanged: (_) {},
            );
          }),
        ),
      );

      // The chip's icon resolves to onSecondaryContainer — a theme tweak should
      // move this in lockstep, not break the test.
      final icon = tester.widget<Icon>(find.byIcon(Icons.auto_awesome));
      expect(icon.color, cs.onSecondaryContainer);
    });
  });

  group('TextLineSelector a11y provenance (BUT-931)', () {
    testWidgets(
        'ai-suggested line carries the provenance hint in its semantics',
        (tester) async {
      await tester.pumpWidget(buildSelector(aiSuggested: {0}));

      // The AI line's semantics label includes the provenance hint; a
      // non-AI line does not. Asserting on substrings keeps this robust to
      // copy tweaks to the surrounding selected/not-selected text.
      final aiSemantics = tester.getSemantics(
        find.bySemanticsLabel(RegExp('200 g smör.*AI-förslag')),
      );
      expect(aiSemantics, isNotNull);

      // The plain instruction line must NOT advertise AI provenance.
      expect(
        find.bySemanticsLabel(RegExp('Vispa ihop.*AI-förslag')),
        findsNothing,
      );
    });
  });

  group('TextLineSelector selection behaviour', () {
    testWidgets('tapping an ai-suggested line still toggles its selection',
        (tester) async {
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
}
