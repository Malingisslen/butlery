import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/views/unified_shopping/widgets/category_order_sheet.dart';

void main() {
  late int resets;
  late int saves;

  Future<void> openSheet(WidgetTester tester) async {
    resets = 0;
    saves = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('sv'),
        home: Scaffold(
          body: Builder(
            builder: (context) => TextButton(
              onPressed: () => CategoryOrderSheet.show(
                context,
                currentOrder: const [],
                onSave: (_) async => saves++,
                onReset: () async => resets++,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('Återställ calls the reset and closes the sheet', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Återställ'));
    await tester.pumpAndSettle();

    expect(resets, 1);
    expect(saves, 0);
    expect(find.text('Återställ'), findsNothing);
  });

  testWidgets('Spara saves the order and closes the sheet', (tester) async {
    await openSheet(tester);

    await tester.tap(find.text('Spara ordning'));
    await tester.pumpAndSettle();

    expect(saves, 1);
    expect(resets, 0);
    expect(find.text('Spara ordning'), findsNothing);
  });
}
