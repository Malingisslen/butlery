/// BUT-2522: the "Spara som mall" dialog. A name is required, a failed save
/// keeps the dialog open with the reason, and a good save closes it with the
/// trimmed name and the receipt.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/week_template_entry.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/menu/week_template_viewmodel.dart';
import 'package:butlery/viewmodels/menu/weekly_menu_plan_viewmodel.dart';
import 'package:butlery/widgets/menu/templates/week_template_save_dialog.dart';

class _MockTemplates extends Mock implements WeekTemplateViewModel {}

class _MockCalendar extends Mock implements WeeklyMenuPlanViewModel {}

const _entries = [
  WeekTemplateEntry(
    day: DayOfWeek.mon,
    slot: MealSlot.middag,
    recipeId: 'r1',
    recipeTitle: 'Pasta',
  ),
  WeekTemplateEntry(
    day: DayOfWeek.tue,
    slot: MealSlot.middag,
    recipeId: 'r2',
    recipeTitle: 'Soppa',
  ),
];

void main() {
  late _MockTemplates vm;

  setUp(() {
    vm = _MockTemplates();
    when(() => vm.visibleWeekEntries).thenReturn(_entries);
    when(() => vm.visibleWeekDayCount).thenReturn(2);
  });

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => unawaited(
                showSaveWeekTemplateDialog(
                  context,
                  _MockCalendar(),
                  viewModel: vm,
                ),
              ),
              child: const Text('öppna'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('öppna'));
    await tester.pumpAndSettle();
  }

  Finder nameField() => find.byKey(const ValueKey('week-template-name'));

  testWidgets('shows what the template will hold', (tester) async {
    await open(tester);

    expect(find.text('Spara som mall'), findsOneWidget);
    expect(find.text('2 dagar, 2 rätter'), findsOneWidget);
  });

  testWidgets('an empty name is refused with a message and nothing is saved', (
    tester,
  ) async {
    await open(tester);

    await tester.enterText(nameField(), '   ');
    await tester.tap(find.text('Spara mall'));
    await tester.pumpAndSettle();

    expect(find.text('Ge mallen ett namn'), findsOneWidget);
    expect(find.text('Spara som mall'), findsOneWidget);
    verifyNever(() => vm.saveVisibleWeek(any()));
  });

  testWidgets('a failed save keeps the dialog open and says why', (
    tester,
  ) async {
    when(() => vm.saveVisibleWeek(any())).thenAnswer((_) async => false);
    await open(tester);

    await tester.enterText(nameField(), 'Vardag');
    await tester.tap(find.text('Spara mall'));
    await tester.pumpAndSettle();

    expect(find.text('Mallen kunde inte sparas'), findsOneWidget);
    expect(find.text('Spara som mall'), findsOneWidget);
    expect(find.text('Mallen Vardag är sparad'), findsNothing);
  });

  testWidgets('a good save closes the dialog with the trimmed name and the '
      'receipt', (tester) async {
    when(() => vm.saveVisibleWeek(any())).thenAnswer((_) async => true);
    await open(tester);

    await tester.enterText(nameField(), '  Vardag  ');
    await tester.tap(find.text('Spara mall'));
    await tester.pumpAndSettle();

    verify(() => vm.saveVisibleWeek('Vardag')).called(1);
    expect(find.text('Spara som mall'), findsNothing);
    expect(find.text('Mallen Vardag är sparad'), findsOneWidget);
  });

  testWidgets('a back press does not close the dialog while the save is '
      'running', (
    tester,
  ) async {
    final pending = Completer<bool>();
    when(() => vm.saveVisibleWeek(any())).thenAnswer((_) => pending.future);
    await open(tester);

    await tester.enterText(nameField(), 'Vardag');
    await tester.tap(find.text('Spara mall'));
    await tester.pump();
    unawaited(
      tester.state<NavigatorState>(find.byType(Navigator).first).maybePop(),
    );
    // Past the dialog's exit transition: a pop that went through would have
    // taken it off screen by now.
    for (var i = 0; i < 5; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Spara som mall'), findsOneWidget);

    pending.complete(true);
    await tester.pumpAndSettle();
    expect(find.text('Spara som mall'), findsNothing);
  });
}
