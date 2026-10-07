/// BUT-2224 = A: the editor's draft state shows a warning triangle instead
/// of the cloud when the draft could not be written, and the failure
/// snackbar once per failure period.
library;

import 'package:butlery/widgets/recipe/recipe_form/draft_save_indicator.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

const _snackbarText =
    'Utkastet kunde inte sparas. Det du skrivit finns kvar här. '
    'Tryck Spara för att spara receptet.';

Widget _indicator({
  bool isSaving = false,
  bool hasRecentSave = false,
  bool hasFailed = false,
  int failurePeriod = 0,
}) {
  return createLocalizedTestApp(
    child: DraftSaveIndicator(
      isSaving: isSaving,
      hasRecentSave: hasRecentSave,
      hasFailed: hasFailed,
      failurePeriod: failurePeriod,
    ),
  );
}

Future<void> _dismissSnackbars(WidgetTester tester) async {
  ScaffoldMessenger.of(
    tester.element(find.byType(DraftSaveIndicator)),
  ).clearSnackBars();
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('a recent save shows the cloud', (tester) async {
    await tester.pumpWidget(_indicator(hasRecentSave: true));

    expect(find.byIcon(Icons.cloud_done_outlined), findsOneWidget);
    expect(find.byKey(const ValueKey('draft-save-failed')), findsNothing);
  });

  testWidgets('a failure shows the triangle instead of the cloud, and the '
      'decided snackbar text', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _indicator(hasRecentSave: true, hasFailed: true, failurePeriod: 1),
    );
    await tester.pump();

    expect(find.byKey(const ValueKey('draft-save-failed')), findsOneWidget);
    expect(find.byIcon(Icons.cloud_done_outlined), findsNothing);
    expect(
      find.bySemanticsLabel('Utkastet kunde inte sparas.'),
      findsOneWidget,
    );
    expect(find.text(_snackbarText), findsOneWidget);
    semantics.dispose();
  });

  testWidgets('an editor opened after the failure has recovered stays quiet', (
    tester,
  ) async {
    await tester.pumpWidget(_indicator(hasRecentSave: true, failurePeriod: 1));
    await tester.pump();

    expect(find.text(_snackbarText), findsNothing);
  });

  testWidgets('the snackbar shows once per failure period', (tester) async {
    await tester.pumpWidget(_indicator(hasFailed: true, failurePeriod: 1));
    await tester.pump();
    expect(find.text(_snackbarText), findsOneWidget);
    await _dismissSnackbars(tester);

    // Further failed writes in the same period redraw, but stay quiet.
    await tester.pumpWidget(_indicator(isSaving: true, failurePeriod: 1));
    await tester.pumpWidget(_indicator(hasFailed: true, failurePeriod: 1));
    await tester.pump();
    expect(find.text(_snackbarText), findsNothing);
    expect(find.byKey(const ValueKey('draft-save-failed')), findsOneWidget);

    // A success ends the period; the next failure is announced again.
    await tester.pumpWidget(_indicator(hasRecentSave: true, failurePeriod: 1));
    await tester.pumpWidget(_indicator(hasFailed: true, failurePeriod: 2));
    await tester.pump();
    expect(find.text(_snackbarText), findsOneWidget);
    await _dismissSnackbars(tester);
  });
}
