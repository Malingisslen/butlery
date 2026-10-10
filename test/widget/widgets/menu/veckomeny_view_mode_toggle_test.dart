/// The week menu's Lista/Kalender tabs under the root bar (P4-U09).
///
/// Skarmar v12 del 1 #veckomeny and #tomvecka draw two tabs, "Lista" and
/// "Kalender", with a 3 px saffron line under the chosen one: the plate
/// line's "vald flik" (Komponentark v1:844), token progressIndicator. Each
/// tab is at least 48 dp (tokens.json:485-492).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/semantics_announcement.dart';

void main() {
  group('VeckomenyViewModeToggle', () {
    testWidgets('tapping Kalender fires onSelect(kalender)', (tester) async {
      VeckomenyViewMode? selected;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: VeckomenyViewModeToggle(
            mode: VeckomenyViewMode.lista,
            onSelect: (m) => selected = m,
          ),
        ),
      );

      await tester.tap(find.text('Kalender'));
      await tester.pump();

      expect(selected, VeckomenyViewMode.kalender);
    });

    testWidgets('tapping Lista fires onSelect(lista)', (tester) async {
      VeckomenyViewMode? selected;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: VeckomenyViewModeToggle(
            mode: VeckomenyViewMode.kalender,
            onSelect: (m) => selected = m,
          ),
        ),
      );

      await tester.tap(find.text('Lista'));
      await tester.pump();

      expect(selected, VeckomenyViewMode.lista);
    });

    testWidgets('the chosen tab is announced selected, the other not', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: VeckomenyViewModeToggle(
            mode: VeckomenyViewMode.lista,
            onSelect: (_) {},
          ),
        ),
      );

      expect(
        tester.getSemantics(find.bySemanticsLabel('Lista')),
        containsSemantics(isSelected: true, isButton: true),
      );
      expect(
        tester.getSemantics(find.bySemanticsLabel('Kalender')),
        containsSemantics(isSelected: false, isButton: true),
      );
      handle.dispose();
    });

    testWidgets('each tab can be activated by a screen reader and is named '
        'once', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: VeckomenyViewModeToggle(
            mode: VeckomenyViewMode.lista,
            onSelect: (_) {},
          ),
        ),
      );

      for (final label in ['Lista', 'Kalender']) {
        final tab = find.bySemanticsLabel(label);
        expectActivatable(tester, tab);
        expectNothingAnnouncedTwice(tester, tab);
      }
      handle.dispose();
    });

    testWidgets('one saffron line, under the chosen tab only', (tester) async {
      late Color indicator;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) {
              indicator = context.modeColors.progressIndicator;
              return VeckomenyViewModeToggle(
                mode: VeckomenyViewMode.kalender,
                onSelect: (_) {},
              );
            },
          ),
        ),
      );

      final line = find.byKey(VeckomenyViewModeToggle.indicatorKey);
      expect(line, findsOneWidget);
      expect(
        find
            .ancestor(of: line, matching: find.byType(Stack))
            .evaluate()
            .any(
              (e) => find
                  .descendant(
                    of: find.byWidget(e.widget),
                    matching: find.text('Kalender'),
                  )
                  .evaluate()
                  .isNotEmpty,
            ),
        isTrue,
      );
      final box = tester.widget<ColoredBox>(
        find.descendant(of: line, matching: find.byType(ColoredBox)),
      );
      expect(box.color, indicator);
      expect(
        tester.getSize(line).height,
        VeckomenyViewModeToggle.indicatorHeight,
      );
    });

    testWidgets('each tab is at least 48 dp tall', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: VeckomenyViewModeToggle(
            mode: VeckomenyViewMode.lista,
            onSelect: (_) {},
          ),
        ),
      );
      for (final label in ['Lista', 'Kalender']) {
        final ink = find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(ink).height, greaterThanOrEqualTo(48));
      }
    });
  });

  group('VeckomenyViewModeToggle — 200 % text (BUT-2192)', () {
    testWidgets('the row fits inside the height it asks the bar for', (
      tester,
    ) async {
      final toggle = VeckomenyViewModeToggle(
        mode: VeckomenyViewMode.lista,
        onSelect: (_) {},
      );
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 2.0,
            maxScaleFactor: 2.0,
            child: Align(alignment: Alignment.topLeft, child: toggle),
          ),
        ),
      );

      expect(
        tester.getSize(find.byType(VeckomenyViewModeToggle)).height,
        lessThanOrEqualTo(toggle.preferredSize.height),
      );
    });

    // BUT-2341: at 320 dp the two tabs are wider than the screen.
    testWidgets('on a 320 dp phone the row scrolls to Kalender, which still '
        'selects', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      VeckomenyViewMode? selected;
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: MediaQuery.withClampedTextScaling(
            minScaleFactor: 2.0,
            maxScaleFactor: 2.0,
            child: Align(
              alignment: Alignment.topLeft,
              child: VeckomenyViewModeToggle(
                mode: VeckomenyViewMode.lista,
                onSelect: (m) => selected = m,
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      await tester.ensureVisible(find.text('Kalender'));
      await tester.pump();
      await tester.tap(find.text('Kalender'));
      expect(selected, VeckomenyViewMode.kalender);
    });
  });

  testWidgets('the bottom hairline spans the whole bar, not just the tabs', (
    tester,
  ) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Align(
          alignment: Alignment.topLeft,
          child: VeckomenyViewModeToggle(
            mode: VeckomenyViewMode.lista,
            onSelect: (_) {},
          ),
        ),
      ),
    );

    final toggle = tester.getRect(find.byType(VeckomenyViewModeToggle));
    final line = tester.getRect(
      find
          .descendant(
            of: find.byType(VeckomenyViewModeToggle),
            matching: find.byType(DecoratedBox),
          )
          .first,
    );
    final screen = tester.view.physicalSize / tester.view.devicePixelRatio;
    expect(toggle.width, screen.width);
    expect(line.width, toggle.width - 2 * (line.left - toggle.left));
  });
}
