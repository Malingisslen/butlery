import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/menu/menu_pick_reasons.dart';
import 'package:butlery/widgets/menu/menu_why_section.dart';

Widget _wrap(Widget child) => MaterialApp(
  locale: const Locale('sv'),
  localizationsDelegates: const [
    AppLocalizations.delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  supportedLocales: AppLocalizations.supportedLocales,
  home: Scaffold(body: child),
);

void main() {
  testWidgets('Varför? opens and closes the reasons', (tester) async {
    await tester.pumpWidget(
      _wrap(const MenuWhyToggle(reasons: [MenuPickReason.pantry])),
    );
    expect(find.text('Använder ingredienser du har hemma'), findsNothing);
    await tester.tap(find.text('Varför?'));
    await tester.pump();
    expect(find.text('Använder ingredienser du har hemma'), findsOneWidget);
    await tester.tap(find.text('Varför?'));
    await tester.pump();
    expect(find.text('Använder ingredienser du har hemma'), findsNothing);
  });

  testWidgets('no reasons says it was chance, never invents one', (
    tester,
  ) async {
    await tester.pumpWidget(_wrap(const MenuWhyToggle(reasons: [])));
    await tester.tap(find.text('Varför?'));
    await tester.pump();
    expect(
      find.text('Inget särskilt skäl: den drogs bland dina recept.'),
      findsOneWidget,
    );
  });
}
