/// BUT-1845: unit tests for [RecipeFormState.mealTypeOptions].
///
/// Tests the REAL seam behind both recipe-form dropdowns — they reach it
/// through the one-line `RecipeFormViewModel.mealTypeOptions` facade — in
/// the style of `test/unit/widgets/tagging/personal_tag_rule_dropdown_test.dart`
/// — not a parallel reimplementation of the rule.
///
/// The contract it has to keep: for ANY stored string, `values` contains
/// `selected` exactly once, or `selected` is null. `DropdownButtonFormField`
/// asserts that in its constructor on every build, so a violation is a crash on
/// screen, not a wrong pixel.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/viewmodels/recipe_form/recipe_form_state.dart';

void main() {
  group('mealTypeOptions', () {
    test('an offered value is selected and appears exactly once', () {
      final options = RecipeFormState.mealTypeOptions('Lunch');

      expect(options.selected, 'Lunch');
      expect(options.values.where((v) => v == 'Lunch').length, 1);
      expect(
        options.values,
        RecipeFormState.mealTypes,
        reason: 'A value already on offer must not widen the list.',
      );
    });

    // The value that motivated the ticket: text import writes it
    // (`text_import_strategy.dart:990`) and no list in the app contains it.
    test('a value the app does not offer is prepended, once, and selected', () {
      final options = RecipeFormState.mealTypeOptions('Huvudrätt');

      expect(options.selected, 'Huvudrätt');
      expect(options.values.first, 'Huvudrätt');
      expect(options.values.where((v) => v == 'Huvudrätt').length, 1);
      expect(
        options.values.sublist(1),
        RecipeFormState.mealTypes,
        reason: 'The offered vocabulary must follow, in order, unchanged.',
      );
    });

    test('the assisted import default is carried the same way', () {
      // `assisted_import_viewmodel.dart:77` defaults to this and writes it into
      // the recipe, which is then handed straight to the form.
      final options = RecipeFormState.mealTypeOptions('dinner');

      expect(options.selected, 'dinner');
      expect(options.values.first, 'dinner');
    });

    test('an empty stored value selects nothing and does not widen', () {
      final options = RecipeFormState.mealTypeOptions('');

      expect(
        options.selected,
        isNull,
        reason:
            'An empty value matches no item; null leaves the control '
            'unselected instead of asserting.',
      );
      expect(options.values, RecipeFormState.mealTypes);
      expect(options.values, isNot(contains('')));
    });

    // Deliberate, not an oversight. Folding would make the row shown ('Lunch')
    // stop matching the string stored and saved ('lunch') — a silent
    // divergence — and folding `values` without `selected` would re-trip the
    // dropdown's assert outright. Unifying the vocabulary is BUT-1845's
    // follow-up; until then the two rows sit side by side.
    test('case differences are NOT folded — lunch and Lunch coexist', () {
      final options = RecipeFormState.mealTypeOptions('lunch');

      expect(options.selected, 'lunch');
      expect(options.values.first, 'lunch');
      expect(
        options.values.where((v) => v.toLowerCase() == 'lunch').length,
        2,
        reason:
            'Both spellings must be present: folding them would show one word '
            'while a different one stays stored and saved.',
      );
    });

    test('whitespace is not trimmed either', () {
      final options = RecipeFormState.mealTypeOptions(' Lunch');

      expect(options.selected, ' Lunch');
      expect(options.values.first, ' Lunch');
    });

    // The invariant, stated as a test rather than only as prose: whatever the
    // stored value, the dropdown can render it. Empty is excluded on purpose —
    // it yields `selected: null`, which matches no item by design and is
    // pinned by its own case above.
    test(
      'for every plausible NON-EMPTY value, selected occurs exactly once',
      () {
        const stored = [
          'Lunch',
          'Huvudrätt',
          'dinner',
          'lunch',
          'monthly',
          '42',
          ' Lunch',
          'Fika',
        ];

        for (final value in stored) {
          final options = RecipeFormState.mealTypeOptions(value);
          expect(
            options.values.where((v) => v == options.selected).length,
            1,
            reason: 'Exactly one item must match for stored value "$value".',
          );
        }
      },
    );
  });
}
