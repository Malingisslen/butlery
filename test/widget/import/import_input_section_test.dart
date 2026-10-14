// The import field's clear button: shown only while there is text, and one
// tap empties the field AND resets the view model's input, so a stale link
// cannot be imported after the user cleared it.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/viewmodels/smart_import_viewmodel.dart';
import 'package:butlery/views/smart_import/import_widgets.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

class _MockSmartImportViewModel extends Mock implements SmartImportViewModel {}

void main() {
  late _MockSmartImportViewModel vm;
  late TextEditingController controller;

  setUp(() {
    vm = _MockSmartImportViewModel();
    when(() => vm.isImporting).thenReturn(false);
    when(() => vm.clearInput()).thenReturn(null);
    controller = TextEditingController();
  });

  tearDown(() => controller.dispose());

  Future<void> pump(WidgetTester tester) => tester.pumpWidget(
    createLocalizedTestApp(
      // The view rebuilds the section as the text changes; the listenable
      // stands in for that.
      child: ListenableBuilder(
        listenable: controller,
        builder: (_, _) => ImportInputSection(
          controller: controller,
          focusNode: FocusNode(),
          viewModel: vm,
          onChanged: (_) {},
        ),
      ),
    ),
  );

  testWidgets('no clear button while the field is empty', (tester) async {
    await pump(tester);

    expect(find.byTooltip('Rensa'), findsNothing);
  });

  testWidgets('clear empties the field and resets the view model input', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField), 'https://ica.se/recept/1');
    await tester.pump();

    await tester.tap(find.byTooltip('Rensa'));
    await tester.pump();

    expect(controller.text, isEmpty);
    verify(() => vm.clearInput()).called(1);
    expect(find.byTooltip('Rensa'), findsNothing);
  });
}
