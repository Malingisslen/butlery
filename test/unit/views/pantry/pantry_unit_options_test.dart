/// BUT-1858: unit tests for [AddPantryItemSheet.unitOptions].
///
/// The seam the pantry sheet's unit dropdown is built from — the same shape as
/// `RecipeFormState.mealTypeOptions` (BUT-1845) and tested the same way, rather
/// than reimplemented here.
///
/// The contract: for ANY stored string, `values` contains `selected` exactly
/// once, or `selected` is null. `DropdownButtonFormField` asserts that in its
/// constructor on every build, so a violation is a fallen screen in debug and a
/// blank control in release, not a wrong pixel.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';

void main() {
  group('unitOptions', () {
    test('an offered unit is selected and the list is unchanged', () {
      final options = AddPantryItemSheet.unitOptions('g');

      expect(options.selected, 'g');
      expect(
        options.values,
        AddPantryItemSheet.offeredUnits,
        reason: 'A unit already on offer must not widen the list.',
      );
      expect(options.values.where((v) => v == 'g').length, 1);
    });

    // The value that motivated the ticket: the shopping-checkoff flow stores a
    // free-text unit verbatim, and this is one the sheet never offered.
    test('an off-list unit is prepended, once, and selected', () {
      final options = AddPantryItemSheet.unitOptions('knippe');

      expect(options.selected, 'knippe');
      expect(options.values.first, 'knippe');
      expect(options.values.where((v) => v == 'knippe').length, 1);
      expect(
        options.values.sublist(1),
        AddPantryItemSheet.offeredUnits,
        reason: 'The offered vocabulary must follow, in order, unchanged.',
      );
    });

    // Empty is a REAL stored unit, not a missing one: an amount-less recipe
    // line yields it and the checkoff flow stores it verbatim. Selecting
    // nothing is what lets `copyWith(unit: null)` preserve it on save.
    test('an empty stored unit selects nothing and does not widen', () {
      final options = AddPantryItemSheet.unitOptions('');

      expect(options.selected, isNull);
      expect(options.values, AddPantryItemSheet.offeredUnits);
      expect(options.values, isNot(contains('')));
    });

    test('case and whitespace are not folded — the stored string wins', () {
      // Folding would show one word while a different one stays stored, which
      // is the silent divergence this seam exists to prevent.
      for (final stored in ['G', ' g', 'St']) {
        final options = AddPantryItemSheet.unitOptions(stored);
        expect(options.selected, stored);
        expect(options.values.first, stored);
      }
    });

    // The invariant as a test rather than only as prose. Empty is excluded on
    // purpose — it yields `selected: null`, pinned by its own case above.
    test(
      'for every plausible NON-EMPTY unit, selected occurs exactly once',
      () {
        const stored = [
          'st',
          'msk',
          'knippe',
          'förp',
          'påse',
          'krm',
          'kvist',
          'G',
          ' g',
          '42',
        ];

        for (final value in stored) {
          final options = AddPantryItemSheet.unitOptions(value);
          expect(
            options.values.where((v) => v == options.selected).length,
            1,
            reason: 'Exactly one item must match for stored unit "$value".',
          );
        }
      },
    );

    // Pins the vocabulary itself. BUT-1858 deliberately did NOT widen it to
    // `UnitDefinitions`' 88 entries — that decision is worth a red test if
    // someone half-applies it later. ORDER is pinned too, on purpose: it is
    // the display order of the dropdown, so a reorder is a UI change and
    // should have to be made deliberately rather than drift in.
    //
    // It is also the only case that pins the WHOLE list and its ORDER. The
    // siblings are not content-blind — the prepend branch keys on membership,
    // so dropping 'g' reddens the offered-unit case, adding '' reddens the
    // empty case, 'St' reddens the case-folding one and 'knippe' the off-list
    // one. What only this case catches is a REORDER, or an addition that
    // collides with no fixture. (Widget tests 1, 6, 8 and 10 tap
    // `find.text('dl')`, so they would redden too if 'dl' left the list.)
    test('the offered vocabulary is the eight the sheet has always shown', () {
      expect(AddPantryItemSheet.offeredUnits, const [
        'st',
        'g',
        'kg',
        'ml',
        'dl',
        'l',
        'tsk',
        'msk',
      ]);
    });
  });
}
