/// BUT-2529: the empty week's ready-made wishes fill the prompt field and
/// leave generating to the user; the pantry flag follows the fill into
/// Generera for as long as the field still holds exactly the wish.
library;

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/viewmodels/menu_viewmodel.dart';
import 'package:butlery/views/veckomeny_view/veckomeny_body.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/chips/butlery_filter_chip.dart';
import 'package:butlery/widgets/common/menu_persistence/menu_load_dialog.dart';
import 'package:butlery/widgets/menu/templates/week_template_save_dialog.dart';
import 'package:butlery/widgets/menu/veckomeny_quick_picks.dart';

import 'veckomeny_flow_harness.dart';

void main() {
  late VeckomenyFlowHarness h;

  setUp(() async {
    h = VeckomenyFlowHarness();
    await h.setUp();
  });

  tearDown(() => h.tearDown());

  Future<void> open(WidgetTester tester) =>
      withClock(Clock.fixed(flowMonday), () async {
        await h.pump(tester);
        await tester.pumpAndSettle();
      });

  MenuViewModel menuVm(WidgetTester tester) => Provider.of<MenuViewModel>(
    tester.element(find.byType(VeckomenyBody)),
    listen: false,
  );

  String fieldText(WidgetTester tester) =>
      tester.widget<TextField>(find.byType(TextField).first).controller!.text;

  Future<void> tapGenerate(WidgetTester tester) async {
    await tester.tap(
      find.descendant(
        of: find.byKey(const ValueKey('test-veckomeny-generate')),
        matching: find.byType(FormButton),
      ),
    );
    await tester.pumpAndSettle();
  }

  bool chipSelected(WidgetTester tester, String label) => tester
      .widget<ButleryFilterChip>(find.widgetWithText(ButleryFilterChip, label))
      .selected;

  testWidgets('an empty week shows the wish chips and the saved-weeks row', (
    tester,
  ) async {
    await open(tester);

    expect(find.text('FÄRDIGA ÖNSKEMÅL'), findsOneWidget);
    expect(find.text('Snabb vecka'), findsOneWidget);
    expect(find.text('Börja från en sparad vecka'), findsOneWidget);
    expect(find.text('Fasta dagar'), findsOneWidget);
  });

  testWidgets('the chips stay visible once the field has text', (tester) async {
    await open(tester);
    await tester.enterText(find.byType(TextField).first, '3 middagar');
    await tester.pump();

    expect(find.text('Snabb vecka'), findsOneWidget);
    expect(find.text('Börja från en sparad vecka'), findsOneWidget);
  });

  testWidgets('a week with dishes shows no chips, saved-weeks row or band', (
    tester,
  ) async {
    h.seedWeek(2);
    await open(tester);

    expect(find.text('FÄRDIGA ÖNSKEMÅL'), findsNothing);
    expect(find.text('Börja från en sparad vecka'), findsNothing);
    expect(find.text('Fasta dagar'), findsNothing);
  });

  testWidgets('a chip fills the field, shows selected and does not generate', (
    tester,
  ) async {
    await open(tester);
    await tester.tap(find.text('Snabb vecka'));
    await tester.pumpAndSettle();

    expect(fieldText(tester), '7 middagar snabba');
    expect(h.menu.generations, 0);
    expect(chipSelected(tester, 'Snabb vecka'), isTrue);
    expect(chipSelected(tester, 'Använd det jag har hemma'), isFalse);
  });

  testWidgets('a chip has a tap target of at least 48 dp', (tester) async {
    await open(tester);

    final box = tester.getSize(
      find.widgetWithText(ButleryFilterChip, 'Snabb vecka'),
    );
    expect(box.height, greaterThanOrEqualTo(48));
  });

  testWidgets('the pantry chip carries its flag into Generera', (tester) async {
    h.menu.next = {
      'Middag': [flowDinner(1)],
    };
    await open(tester);
    await tester.tap(find.text('Använd det jag har hemma'));
    await tester.pumpAndSettle();
    await tapGenerate(tester);

    expect(h.menu.generations, 1);
    expect(menuVm(tester).pantryFocusFor('7 middagar'), isTrue);
  });

  testWidgets('editing the text after the pantry chip drops the flag', (
    tester,
  ) async {
    h.menu.next = {
      'Middag': [flowDinner(1)],
    };
    await open(tester);
    await tester.tap(find.text('Använd det jag har hemma'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).first,
      '7 middagar vegetariskt',
    );
    await tester.pump();

    expect(chipSelected(tester, 'Använd det jag har hemma'), isFalse);
    await tapGenerate(tester);

    expect(h.menu.generations, 1);
    expect(menuVm(tester).pantryFocusFor('7 middagar vegetariskt'), isFalse);
  });

  testWidgets('the fast chip generates without pantry focus', (tester) async {
    h.menu.next = {
      'Middag': [flowDinner(1)],
    };
    await open(tester);
    await tester.tap(find.text('Snabb vecka'));
    await tester.pumpAndSettle();
    await tapGenerate(tester);

    expect(menuVm(tester).pantryFocusFor('7 middagar snabba'), isFalse);
  });

  testWidgets('the saved-weeks row opens the saved weeks sheet', (
    tester,
  ) async {
    await open(tester);
    expect(find.byType(LoadMenuBottomSheet), findsNothing);

    await tester.tap(find.text('Börja från en sparad vecka'));
    await tester.pumpAndSettle();

    expect(find.byType(LoadMenuBottomSheet), findsOneWidget);
  });

  testWidgets('"Spara veckan" opens the save-week dialog', (tester) async {
    h.seedWeek(2);
    await open(tester);
    expect(find.byType(WeekTemplateSaveDialog), findsNothing);

    await tester.tap(find.text('Spara veckan'));
    await tester.pumpAndSettle();

    expect(find.byType(WeekTemplateSaveDialog), findsOneWidget);
  });

  test('a wish fill is equal by value', () {
    const a = MenuWishFill(text: 't', pantryFocus: true, sourceId: 's');
    const b = MenuWishFill(text: 't', pantryFocus: true, sourceId: 's');
    expect(a, b);
  });
}
