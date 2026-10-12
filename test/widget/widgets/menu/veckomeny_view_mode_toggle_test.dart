/// The week menu's Lista/Kalender switch under the root bar: the component
/// sheet's segment with the chosen half filled (the approved week menu
/// picture). Each half is at least 48 dp.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/menu/veckomeny_selection_widgets.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';
import '../../../test_support/semantics_announcement.dart';

Widget _toggle(VeckomenyViewMode mode, ValueChanged<VeckomenyViewMode> on) =>
    createLocalizedTestApp(
      child: VeckomenyViewModeToggle(mode: mode, onSelect: on),
    );

void main() {
  group('VeckomenyViewModeToggle', () {
    testWidgets('tapping Kalender fires onSelect(kalender)', (tester) async {
      VeckomenyViewMode? selected;
      await tester.pumpWidget(
        _toggle(VeckomenyViewMode.lista, (m) => selected = m),
      );
      await tester.tap(find.text('Kalender'));
      await tester.pump();
      expect(selected, VeckomenyViewMode.kalender);
    });

    testWidgets('tapping Lista fires onSelect(lista)', (tester) async {
      VeckomenyViewMode? selected;
      await tester.pumpWidget(
        _toggle(VeckomenyViewMode.kalender, (m) => selected = m),
      );
      await tester.tap(find.text('Lista'));
      await tester.pump();
      expect(selected, VeckomenyViewMode.lista);
    });

    testWidgets('the chosen half is the segment that is selected', (
      tester,
    ) async {
      await tester.pumpWidget(_toggle(VeckomenyViewMode.kalender, (_) {}));
      final switchWidget = tester.widget<SegmentedButton<VeckomenyViewMode>>(
        find.byType(SegmentedButton<VeckomenyViewMode>),
      );
      expect(switchWidget.selected, {VeckomenyViewMode.kalender});
    });

    testWidgets('each half can be activated by a screen reader and is named '
        'once', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_toggle(VeckomenyViewMode.lista, (_) {}));
      for (final label in ['Lista', 'Kalender']) {
        final tab = find.bySemanticsLabel(label);
        expectActivatable(tester, tab);
        expectNothingAnnouncedTwice(tester, tab);
      }
      handle.dispose();
    });

    testWidgets('each half is at least 48 dp tall', (tester) async {
      await tester.pumpWidget(_toggle(VeckomenyViewMode.lista, (_) {}));
      for (final label in ['Lista', 'Kalender']) {
        final ink = find.ancestor(
          of: find.text(label),
          matching: find.byType(InkWell),
        );
        expect(tester.getSize(ink.first).height, greaterThanOrEqualTo(48));
      }
    });

    // BUT-2192, BUT-2341: 320 dp at 200 % text.
    testWidgets('at 320 dp and 200 % text it lays out and Kalender still '
        'selects', (tester) async {
      tester.view.physicalSize = const Size(320, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      VeckomenyViewMode? selected;
      await tester.pumpWidget(
        MediaQuery.withClampedTextScaling(
          minScaleFactor: 2.0,
          maxScaleFactor: 2.0,
          child: _toggle(VeckomenyViewMode.lista, (m) => selected = m),
        ),
      );
      expect(tester.takeException(), isNull);
      await tester.tap(find.text('Kalender'));
      await tester.pump();
      expect(selected, VeckomenyViewMode.kalender);
    });
  });
}
