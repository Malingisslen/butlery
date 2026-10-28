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
          onToShopping: () {},
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
    // its enabled look (busy is not disabled).
    expect(find.byType(BusyButtonSemantics), findsOneWidget);
    // The same flag draws the plate line along the button's bottom edge,
    // never a spinner (B-18).
    expect(find.byType(ButtonPlateLine), findsOneWidget);
  });

  Future<void> pumpScaled(
    WidgetTester tester, {
    required double textScale,
    VoidCallback? onManual,
    VoidCallback? onShopping,
    bool isShoppingBusy = false,
  }) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(textScale)),
            child: Material(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: MenuPlacementChoiceFooter(
                  onPlaceAuto: () {},
                  onPlaceManual: onManual ?? () {},
                  onToShopping: onShopping ?? () {},
                  isShoppingBusy: isShoppingBusy,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Finder buttonWith(String label) => find.ancestor(
    of: find.text(label),
    matching: find.byType(OutlinedButton),
  );

  testWidgets('manual and shopping buttons each fire their own callback', (
    tester,
  ) async {
    var manual = 0;
    var shopping = 0;
    await pumpScaled(
      tester,
      textScale: 1.0,
      onManual: () => manual++,
      onShopping: () => shopping++,
    );

    await tester.tap(buttonWith('Jag placerar själv'));
    expect((manual, shopping), (1, 0));
    await tester.tap(buttonWith('Till inköpslista'));
    expect((manual, shopping), (1, 1));
  });

  testWidgets('at normal text size the two outlined buttons share a row', (
    tester,
  ) async {
    await pumpScaled(tester, textScale: 1.0);

    final manual = tester.getRect(buttonWith('Jag placerar själv'));
    final shopping = tester.getRect(buttonWith('Till inköpslista'));
    expect(manual.top, shopping.top);
    expect(manual.right, lessThanOrEqualTo(shopping.left));
  });

  testWidgets('at a large text size the two outlined buttons stack and do '
      'not overflow', (tester) async {
    await pumpScaled(tester, textScale: 2.0);

    final manual = tester.getRect(buttonWith('Jag placerar själv'));
    final shopping = tester.getRect(buttonWith('Till inköpslista'));
    expect(manual.bottom, lessThanOrEqualTo(shopping.top));
    expect(manual.left, shopping.left);
    expect(manual.width, shopping.width);
    expect(tester.takeException(), isNull);
  });

  testWidgets('a busy shopping flow marks only the shopping button busy', (
    tester,
  ) async {
    await pumpScaled(tester, textScale: 1.0, isShoppingBusy: true);

    Finder busyAround(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(BusyButtonSemantics),
    );
    expect(busyAround('Till inköpslista'), findsOneWidget);
    expect(busyAround('Jag placerar själv'), findsNothing);
    expect(find.byType(BusyButtonSemantics), findsOneWidget);
  });

  testWidgets('both buttons sit above the home-indicator inset', (
    tester,
  ) async {
    const inset = 34.0;
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(padding: const EdgeInsets.only(bottom: inset)),
            child: Material(
              child: Align(
                alignment: Alignment.bottomCenter,
                child: MenuPlacementChoiceFooter(
                  isPlacing: false,
                  onPlaceAuto: () {},
                  onPlaceManual: () {},
                  onToShopping: () {},
                ),
              ),
            ),
          ),
        ),
      ),
    );

    final screenHeight =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    final manual = find.ancestor(
      of: find.text('Jag placerar själv'),
      matching: find.byType(OutlinedButton),
    );
    expect(manual, findsOneWidget, reason: 'premise: the footer is shown');
    expect(
      tester.getRect(manual).bottom,
      lessThanOrEqualTo(screenHeight - inset),
    );
  });
}
