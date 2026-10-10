/// BUT-2157: "Avbryt planeringen" under the planning panel (Skarmar v12 del
/// 1 #veckogenererarpanel): an outlined 48 dp button with the note on what
/// cancelling keeps (Q1 = B).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/menu/veckomeny_planning_cancel_footer.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

void main() {
  testWidgets('says what cancelling keeps, and a tap cancels', (tester) async {
    var cancels = 0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: VeckomenyPlanningCancelFooter(onCancel: () => cancels++),
      ),
    );

    expect(find.text('Avbryt planeringen'), findsOneWidget);
    expect(
      find.text(
        'Avbryt behåller ditt senaste förslag. '
        'Inget skrivs över förrän du sparar.',
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.byType(OutlinedButton),
        matching: find.text('Avbryt planeringen'),
      ),
      findsOneWidget,
      reason: 'outlined: the saffron action is Generera',
    );

    await tester.tap(find.byKey(VeckomenyPlanningCancelFooter.buttonKey));
    expect(cancels, 1);
  });

  testWidgets('the button is at least 48 dp tall and reads as a button', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: VeckomenyPlanningCancelFooter(onCancel: () {}),
      ),
    );

    final size = tester.getSize(
      find.byKey(VeckomenyPlanningCancelFooter.buttonKey),
    );
    expect(size.height, greaterThanOrEqualTo(48));
    expect(
      tester.getSemantics(find.byKey(VeckomenyPlanningCancelFooter.buttonKey)),
      matchesSemantics(
        label: 'Avbryt planeringen',
        isButton: true,
        hasTapAction: true,
        isEnabled: true,
        hasEnabledState: true,
        isFocusable: true,
        hasFocusAction: true,
      ),
    );
    handle.dispose();
  });
}
