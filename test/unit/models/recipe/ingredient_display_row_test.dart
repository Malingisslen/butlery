/// Ingredient sections (PR #211) — display-row grouping.
///
/// [IngredientDisplayRow.build] turns (structured entries + scaled display
/// lines) into a flat list of heading/line rows. These pin the grouping
/// contract every ingredient view depends on: contiguous runs collapse to one
/// heading, ungrouped lines render flat, and a length mismatch fails open to
/// today's flat list without dropping a line.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe/ingredient_display_row.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';

RecipeIngredient ing(String raw, {String? section}) =>
    RecipeIngredient(name: raw, raw: raw, section: section);

void main() {
  group('IngredientDisplayRow.build', () {
    test(
      'emits one heading per contiguous section run, lines carry indices',
      () {
        final rows = IngredientDisplayRow.build(
          [
            ing('5 dl vetemjöl', section: 'Deg'),
            ing('25 g jäst', section: 'Deg'),
            ing('75 g smör', section: 'Fyllning'),
            ing('2 msk kanel', section: 'Fyllning'),
          ],
          ['5 dl vetemjöl', '25 g jäst', '75 g smör', '2 msk kanel'],
        );

        expect(rows, [
          const IngredientHeadingRow(label: 'Deg'),
          const IngredientLineRow(text: '5 dl vetemjöl', ingredientIndex: 0),
          const IngredientLineRow(text: '25 g jäst', ingredientIndex: 1),
          const IngredientHeadingRow(label: 'Fyllning'),
          const IngredientLineRow(text: '75 g smör', ingredientIndex: 2),
          const IngredientLineRow(text: '2 msk kanel', ingredientIndex: 3),
        ]);
      },
    );

    test('display text comes from the scaled lines, not the raw entries', () {
      // The scaler already produced "10 dl vetemjöl" (doubled). The row must
      // render THAT, while the section still comes from the structured entry.
      final rows = IngredientDisplayRow.build(
        [ing('5 dl vetemjöl', section: 'Deg')],
        ['10 dl vetemjöl'],
      );
      expect(rows, [
        const IngredientHeadingRow(label: 'Deg'),
        const IngredientLineRow(text: '10 dl vetemjöl', ingredientIndex: 0),
      ]);
    });

    test('a flat recipe (all null sections) yields only line rows', () {
      final rows = IngredientDisplayRow.build(
        [ing('salt'), ing('peppar')],
        ['salt', 'peppar'],
      );
      expect(rows.whereType<IngredientHeadingRow>(), isEmpty);
      expect(rows, hasLength(2));
    });

    test(
      'leading ungrouped lines then a group: no heading until the group',
      () {
        final rows = IngredientDisplayRow.build(
          [ing('salt'), ing('75 g smör', section: 'Fyllning')],
          ['salt', '75 g smör'],
        );
        expect(rows, [
          const IngredientLineRow(text: 'salt', ingredientIndex: 0),
          const IngredientHeadingRow(label: 'Fyllning'),
          const IngredientLineRow(text: '75 g smör', ingredientIndex: 1),
        ]);
      },
    );

    test(
      'the same section value recurring after another emits a fresh heading',
      () {
        final rows = IngredientDisplayRow.build(
          [
            ing('a', section: 'Deg'),
            ing('b', section: 'Fyllning'),
            ing('c', section: 'Deg'),
          ],
          ['a', 'b', 'c'],
        );
        expect(rows.whereType<IngredientHeadingRow>().map((r) => r.label), [
          'Deg',
          'Fyllning',
          'Deg',
        ]);
      },
    );

    test(
      'length mismatch fails open: all line rows, no headings, no drops',
      () {
        // Structured list longer than display lines (a scaler that collapsed a
        // line, say). Must not throw, must not drop a display line, must not
        // guess a heading.
        final rows = IngredientDisplayRow.build(
          [ing('a', section: 'Deg'), ing('b', section: 'Deg')],
          ['a'],
        );
        expect(rows, [const IngredientLineRow(text: 'a', ingredientIndex: 0)]);
      },
    );

    test('empty input yields no rows', () {
      expect(IngredientDisplayRow.build(const [], const []), isEmpty);
    });

    test('a blank/whitespace section never renders a heading (defensive) — '
        'the "no blank heading" guarantee holds even for a directly-'
        'constructed entry that skipped upstream normalization', () {
      final rows = IngredientDisplayRow.build(
        [ing('x', section: ''), ing('y', section: '   ')],
        ['x', 'y'],
      );
      expect(rows.whereType<IngredientHeadingRow>(), isEmpty);
      expect(rows, hasLength(2));
    });

    test('fails open when display lines OUTNUMBER structured entries too', () {
      // The opposite mismatch direction: no display line is dropped, no
      // heading guessed.
      final rows = IngredientDisplayRow.build(
        [ing('a', section: 'Deg')],
        ['a', 'b', 'c'],
      );
      expect(rows, [
        const IngredientLineRow(text: 'a', ingredientIndex: 0),
        const IngredientLineRow(text: 'b', ingredientIndex: 1),
        const IngredientLineRow(text: 'c', ingredientIndex: 2),
      ]);
    });

    test('line-row indices point into the FLAT list (for substitution)', () {
      final rows = IngredientDisplayRow.build(
        [
          ing('a', section: 'Deg'),
          ing('b', section: 'Fyllning'),
          ing('c', section: 'Fyllning'),
        ],
        ['a', 'b', 'c'],
      );
      final lineRows = rows.whereType<IngredientLineRow>().toList();
      // Indices stay 0,1,2 despite the two interleaved headings — so a
      // long-press resolves to the right ingredient in the flat list.
      expect(lineRows.map((r) => r.ingredientIndex), [0, 1, 2]);
    });
  });
}
