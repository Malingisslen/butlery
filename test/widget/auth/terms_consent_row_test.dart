// Taps on the terms box and on its words each toggle once.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/auth/terms_consent_row.dart';

Future<List<bool>> _pump(
  WidgetTester tester, {
  bool accepted = false,
}) async {
  final seen = <bool>[];
  final row = Padding(
    padding: const EdgeInsets.all(16),
    child: TermsConsentRow(accepted: accepted, onChanged: seen.add),
  );
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('sv'),
      theme: AppTheme.lightTheme,
      home: Scaffold(body: row),
    ),
  );
  return seen;
}

void main() {
  testWidgets('a tap on the drawn box toggles once', (tester) async {
    final seen = await _pump(tester);

    await tester.tap(find.byType(Checkbox));

    expect(seen, [true]);
  });

  testWidgets('a tap on the opening words toggles once', (tester) async {
    final seen = await _pump(tester, accepted: true);

    final row = tester.getRect(find.byType(TermsConsentRow));
    await tester.tapAt(row.topLeft + const Offset(40, 24));

    expect(seen, [false]);
  });
}
