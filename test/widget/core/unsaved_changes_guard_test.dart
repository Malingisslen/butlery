import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/unsaved_changes_guard.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  Widget app({required bool hasUnsaved}) => createLocalizedTestApp(
    child: Builder(
      builder: (context) => Scaffold(
        body: TextButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute<void>(
              builder: (_) => UnsavedChangesGuard(
                isDirty: hasUnsaved,
                child: const Scaffold(body: Text('inne')),
              ),
            ),
          ),
          child: const Text('öppna'),
        ),
      ),
    ),
  );

  testWidgets('asks before leaving with unsaved work', (tester) async {
    await tester.pumpWidget(app(hasUnsaved: true));
    await tester.tap(find.text('öppna'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('Osparade ändringar'), findsOneWidget);
    expect(find.text('inne'), findsOneWidget);
  });

  testWidgets('leaves without asking when nothing is unsaved', (tester) async {
    await tester.pumpWidget(app(hasUnsaved: false));
    await tester.tap(find.text('öppna'));
    await tester.pumpAndSettle();

    await tester.binding.handlePopRoute();
    await tester.pumpAndSettle();

    expect(find.text('inne'), findsNothing);
  });
}
