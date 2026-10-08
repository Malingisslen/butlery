/// The assisted import's review step stores what its meal-type dropdown
/// offers, and the viewmodel's default has to be one of those items or the
/// control asserts on build. Both halves are the app's Swedish vocabulary so
/// the menu generator's slot match reaches a recipe imported this way.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:butlery/viewmodels/assisted_import_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';
import 'package:butlery/widgets/import/assisted_import_dialog.dart';
import 'package:butlery/widgets/import/text_line_selector.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

// Indices after trim+split: 0-1 ingredients, 2 blank, 3-4 instructions.
const _extractedText = '''200 g kycklingfilé
2 msk olivolja

Steg 1. Stekpanna het
Steg 2. Tillsätt kyckling och stek''';

void main() {
  testWidgets(
    'the review step offers the app\'s meal types and its default is one of them',
    (tester) async {
      // Shown through showDialog as in production: the dialog's footer lays
      // out against the route's bounded constraints.
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Builder(
            builder: (context) => TextButton(
              onPressed: () => showDialog<void>(
                context: context,
                builder: (_) => const AssistedImportDialog(
                  extractedText: _extractedText,
                  suggestedTitle: 'Kycklingrätt',
                ),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();

      final viewModel = tester
          .element(find.byType(TextLineSelector))
          .read<AssistedImportViewModel>();
      viewModel.setIngredientSelection({0, 1});
      viewModel.nextStep();
      await tester.pumpAndSettle();
      viewModel.setInstructionSelection({3, 4});
      viewModel.nextStep();
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      final offered = tester
          .widget<DropdownButton<String>>(find.byType(DropdownButton<String>))
          .items!
          .map((item) => item.value)
          .toList();
      expect(offered, contains(viewModel.mealType));
      expect(RecipeFormState.mealTypes, containsAll(offered));
    },
  );
}
