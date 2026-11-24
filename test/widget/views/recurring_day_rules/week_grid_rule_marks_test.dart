// Intention: a day a saved rule governs carries a repeat mark, and a tap on a
// day's name hands the day on; both are drawn from the rules at render time.
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/menu/weekly_menu_plan.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/menu/calendar/calendar_week_grid.dart';

void main() {
  Future<void> pump(WidgetTester tester, {void Function(DayOfWeek)? onTap}) {
    tester.view.physicalSize = const Size(700, 1800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    return tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        locale: const Locale('sv', 'SE'),
        supportedLocales: AppLocalizations.supportedLocales,
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            child: CalendarWeekGrid(
              weekStart: DateTime(2026, 11, 23),
              todayIndex: -1,
              cellBuilder: (_, _, _) => const SizedBox(height: 40),
              onTapDay: onTap,
              markedDays: const {DayOfWeek.mon, DayOfWeek.fri},
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('only the governed days carry the mark', (tester) async {
    await pump(tester);
    expect(find.byIcon(ButleryIcons.refreshCw), findsNWidgets(2));
  });

  testWidgets('a tap on a day name reports that day', (tester) async {
    DayOfWeek? tapped;
    await pump(tester, onTap: (d) => tapped = d);
    await tester.tap(find.text('ONS'));
    expect(tapped, DayOfWeek.wed);
  });

  testWidgets('without a handler the day name is not a button', (tester) async {
    await pump(tester);
    expect(find.widgetWithText(InkWell, 'ONS'), findsNothing);
  });
}
