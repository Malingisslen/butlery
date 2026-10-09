// BUT-2145: deleting a shopping template is class 1 — it goes at once and
// "Ångra" brings it back for 7 s (produktregler.md § 2.4). The delete is
// written only once the snackbar closes without Ångra.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';
import 'package:butlery/widgets/shopping/shopping_template_browser.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../views/design_states/state_harness.dart';

final _sv = AppLocalizationsSv();

void main() {
  late StateEnvironment environment;
  late MockUnifiedShoppingService service;

  setUp(() async {
    environment = await StateEnvironment.setUp(online: true);
    service = MockUnifiedShoppingService();
    when(service.getUserTemplates).thenAnswer(
      (_) async => [
        {'id': 't1', 'name': 'Fredagsmys', 'itemCount': 4, 'useCount': 2},
        {'id': 't2', 'name': 'Veckohandling', 'itemCount': 12, 'useCount': 5},
      ],
    );
    when(() => service.deleteTemplate(any())).thenAnswer((_) async {});
    TestServiceLocator.registerMock<UnifiedShoppingService>(service);
  });

  tearDown(() async {
    await environment.tearDown();
  });

  Future<void> deleteFredagsmys(WidgetTester tester) async {
    setStateSurface(tester);
    await tester.pumpWidget(
      stateApp(
        mode: Brightness.light,
        home: Scaffold(
          body: ShoppingTemplateBrowser(onTemplateSelected: (_) {}),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Fredagsmys'), findsOneWidget);

    final row = find.ancestor(
      of: find.text('Fredagsmys'),
      matching: find.byType(ListTile),
    );
    await tester.tap(
      find.descendant(of: row, matching: find.byType(PopupMenuButton<String>)),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text(_sv.shoppingTemplateDelete).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
  }

  testWidgets('delete removes the row at once, with no confirmation, and '
      'writes nothing yet', (tester) async {
    await deleteFredagsmys(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Fredagsmys'), findsNothing);
    expect(find.text('Veckohandling'), findsOneWidget);
    expect(find.text(_sv.shoppingTemplateDeleted), findsOneWidget);
    verifyNever(() => service.deleteTemplate(any()));
  });

  testWidgets('Ångra brings the row back and the delete is never written', (
    tester,
  ) async {
    await deleteFredagsmys(tester);

    await tester.tap(find.text(_sv.commonUndo));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('Fredagsmys'), findsOneWidget);
    await tester.pump(const Duration(seconds: 10));
    verifyNever(() => service.deleteTemplate(any()));
  });

  testWidgets('without Ångra the delete is written once the window closes', (
    tester,
  ) async {
    await deleteFredagsmys(tester);

    await tester.pump(const Duration(seconds: 8));
    await tester.pump(const Duration(milliseconds: 500));

    verify(() => service.deleteTemplate('t1')).called(1);
    expect(find.text('Fredagsmys'), findsNothing);
  });

  testWidgets('a delete the server refuses brings the row back and says so', (
    tester,
  ) async {
    when(
      () => service.deleteTemplate(any()),
    ).thenThrow(Exception('permission-denied'));

    await deleteFredagsmys(tester);
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();

    verify(() => service.deleteTemplate('t1')).called(1);
    expect(find.text(_sv.commonUnknownError), findsOneWidget);
    expect(find.text('Fredagsmys'), findsOneWidget);
  });
}
