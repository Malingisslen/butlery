/// The sheet a not-yet-saved shared recipe opens (BUT-2156): who shared it,
/// what the receiver may do, and the two ways on.
library;

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/widgets/social/shared_receive_sheet.dart';

void main() {
  Future<void> open(
    WidgetTester tester, {
    required ResourcePermission permission,
    String? message,
    required ValueSetter<SharedReceiveChoice?> onResult,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('sv'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () async => onResult(
              await showSharedReceiveSheet(
                context,
                title: 'Köttbullar',
                fromLine: 'från Anna · igår',
                permission: permission,
                message: message,
              ),
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('names the sender, the title and a read-only permission', (
    tester,
  ) async {
    await open(
      tester,
      permission: ResourcePermission.viewer,
      message: 'Prova den här!',
      onResult: (_) {},
    );
    expect(find.text('Köttbullar'), findsOneWidget);
    expect(find.text('från Anna · igår'), findsOneWidget);
    expect(find.text('KAN LÄSA'), findsOneWidget);
    expect(find.text('”Prova den här!”'), findsOneWidget);
  });

  testWidgets('says when the receiver may edit', (tester) async {
    await open(
      tester,
      permission: ResourcePermission.editor,
      onResult: (_) {},
    );
    expect(find.text('KAN REDIGERA'), findsOneWidget);
    expect(find.text('KAN LÄSA'), findsNothing);
  });

  testWidgets('Acceptera and Visa receptet each return their choice', (
    tester,
  ) async {
    SharedReceiveChoice? result;
    await open(
      tester,
      permission: ResourcePermission.viewer,
      onResult: (r) => result = r,
    );
    await tester.tap(find.byKey(SharedReceiveSheet.acceptKey));
    await tester.pumpAndSettle();
    expect(result, SharedReceiveChoice.accept);

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(SharedReceiveSheet.viewKey));
    await tester.pumpAndSettle();
    expect(result, SharedReceiveChoice.view);
  });

  testWidgets('dismissing the sheet returns nothing', (tester) async {
    SharedReceiveChoice? result = SharedReceiveChoice.accept;
    await open(
      tester,
      permission: ResourcePermission.viewer,
      onResult: (r) => result = r,
    );
    await tester.tapAt(const Offset(10, 10));
    await tester.pumpAndSettle();
    expect(result, isNull);
  });
}
