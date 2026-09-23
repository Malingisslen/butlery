/// Widget tests for [MenuPlacementChoiceFooter]'s in-flight state (BUT-1987).
///
/// What this has to get right: while a distribution is being placed, the
/// primary action must not accept a second tap. The viewmodel refuses one
/// silently — it cannot surface an error, because this surface ranks error
/// above data and a message would replace the calendar the first tap placed —
/// so the button is where the state has to be visible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/menu/menu_placement_footer.dart';

import '../../infrastructure/helpers/widget_test_app.dart';
import '../../infrastructure/helpers/base_widget_test.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';

void main() {
  setUp(() async {
    await BaseWidgetTest.setupWidget();
  });

  tearDown(() async {
    await BaseWidgetTest.teardownWidget();
  });

  Future<int> pumpFooter(WidgetTester tester, {required bool isPlacing}) async {
    var autoTaps = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: MenuPlacementChoiceFooter(
          isPlacing: isPlacing,
          onPlaceAuto: () => autoTaps++,
          onPlaceManual: () {},
        ),
      ),
    );
    await tester.tap(find.byType(ElevatedButton).first, warnIfMissed: false);
    await tester.pump();
    return autoTaps;
  }

  testWidgets('the auto-place action fires when idle', (tester) async {
    expect(await pumpFooter(tester, isPlacing: false), 1);
  });

  testWidgets('a tap while placing does not fire the action', (tester) async {
    expect(
      await pumpFooter(tester, isPlacing: true),
      0,
      reason: 'the second tap is what the viewmodel refuses silently',
    );
    // Stated as the contract rather than inferred from a tap that fired
    // nothing: a busy button is not activatable (P4-U01), although it keeps
    // its enabled look (Komponentark v1:365, busy is not disabled).
    expect(find.byType(BusyButtonSemantics), findsOneWidget);
    // The same flag draws the plate line along the button's bottom edge,
    // never a spinner (Komponentark v1:372, B-18).
    expect(find.byType(ButtonPlateLine), findsOneWidget);
  });
}
