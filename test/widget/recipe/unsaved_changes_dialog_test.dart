import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/widgets/recipe/unsaved_changes_dialog.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  late AppLocalizations l10n;
  bool? result;

  Future<void> open(WidgetTester tester) async {
    result = null;
    await tester.pumpWidget(
      createLocalizedTestApp(
        child: Builder(
          builder: (context) {
            l10n = AppLocalizations.of(context);
            return Center(
              child: ElevatedButton(
                onPressed: () async =>
                    result = await showUnsavedChangesDialog(context),
                child: const Text('open'),
              ),
            );
          },
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('names the problem and offers both ways out', (tester) async {
    await open(tester);

    expect(find.text(l10n.recipeUnsavedChangesTitle), findsOneWidget);
    expect(find.text(l10n.confirmUnsavedChanges), findsOneWidget);
    expect(find.text(l10n.recipeContinueEditing), findsOneWidget);
    expect(find.text(l10n.recipeLeaveWithoutSaving), findsOneWidget);
  });

  testWidgets('"continue editing" answers false', (tester) async {
    await open(tester);
    await tester.tap(find.text(l10n.recipeContinueEditing));
    await tester.pumpAndSettle();

    expect(result, isFalse);
    expect(find.text(l10n.recipeUnsavedChangesTitle), findsNothing);
  });

  testWidgets('"leave without saving" answers true', (tester) async {
    await open(tester);
    await tester.tap(find.text(l10n.recipeLeaveWithoutSaving));
    await tester.pumpAndSettle();

    expect(result, isTrue);
  });
}
