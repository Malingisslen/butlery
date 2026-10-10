// Signing out deletes nothing (the dialog is reached with an empty offline
// queue), so its confirm button is the app's ordinary filled button rather
// than an error-red one.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/profile/dialogs/profile_dialogs.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets('$name: the logout confirm is not error red, and confirms', (
      tester,
    ) async {
      bool? answer;
      await tester.pumpWidget(
        MaterialApp(
          locale: const Locale('sv'),
          theme: theme,
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () async =>
                    answer = await ProfileDialogs.showLogoutDialog(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final confirm = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.widgetWithText(FilledButton, 'Logga ut'),
      );
      expect(confirm, findsOneWidget);
      final cs = Theme.of(tester.element(confirm)).colorScheme;
      final fill = tester
          .widget<Material>(
            find.descendant(of: confirm, matching: find.byType(Material)).first,
          )
          .color;
      expect(fill, isNotNull);
      expect(fill, isNot(cs.error));

      await tester.tap(confirm);
      await tester.pumpAndSettle();
      expect(answer, isTrue);
    });
  }
}
