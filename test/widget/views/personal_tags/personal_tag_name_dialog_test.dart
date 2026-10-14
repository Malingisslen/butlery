import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/personal_tags/personal_tag_name_dialog.dart';

Widget _host(Future<String?> Function(String) submit) => MaterialApp(
  theme: AppTheme.lightTheme,
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  locale: const Locale('sv'),
  home: Scaffold(
    body: PersonalTagNameDialog(
      title: 'Skapa grupp',
      fieldLabel: 'Namn',
      confirmLabel: 'Skapa',
      emptyMessage: 'Gruppnamn krävs',
      submit: submit,
    ),
  ),
);

void main() {
  testWidgets('a failure stays in the dialog and keeps the typed name', (
    tester,
  ) async {
    await tester.pumpWidget(_host((_) async => 'Det gick inte'));
    await tester.enterText(find.byType(TextField), 'Frukost');
    await tester.tap(find.text('Skapa'));
    await tester.pumpAndSettle();

    expect(find.text('Det gick inte'), findsOneWidget);
    expect(find.text('Frukost'), findsOneWidget);
    expect(find.byType(PersonalTagNameDialog), findsOneWidget);
  });

  testWidgets('an empty name says so and does not submit', (tester) async {
    var calls = 0;
    await tester.pumpWidget(
      _host((_) async {
        calls++;
        return null;
      }),
    );
    await tester.tap(find.text('Skapa'));
    await tester.pumpAndSettle();

    expect(find.text('Gruppnamn krävs'), findsOneWidget);
    expect(calls, 0);
  });
}
