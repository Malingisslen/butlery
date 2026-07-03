/// BUT-1232: proves the deterministic derivation contract — parseable lines
/// yield amount/unit/name, unparseable lines degrade to raw-only, and `raw`
/// always carries the input verbatim (the `Recipe.structuredIngredients`
/// alignment invariant depends on it).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/utils/text/structured_ingredient_deriver.dart';

void main() {
  group('StructuredIngredientDeriver.derive', () {
    test('parses quantity + unit + name from a standard Swedish line', () {
      final entry = StructuredIngredientDeriver.derive('3 dl vetemjöl');

      expect(entry.amount, 3);
      expect(
        entry.amount,
        isA<int>(),
        reason: 'whole quantities persist as int, not 3.0',
      );
      expect(entry.unit, 'dl');
      expect(entry.name, 'vetemjöl');
      expect(entry.raw, '3 dl vetemjöl');
      expect(entry.isStructured, isTrue);
    });

    test('parses Swedish comma decimals', () {
      final entry = StructuredIngredientDeriver.derive('1,5 dl grädde');

      expect(entry.amount, 1.5);
      expect(entry.unit, 'dl');
      expect(entry.name, 'grädde');
    });

    test('quantity without unit yields amount and null unit', () {
      final entry = StructuredIngredientDeriver.derive('2 ägg');

      expect(entry.amount, 2);
      expect(entry.unit, isNull);
      expect(entry.name, 'ägg');
      expect(entry.isStructured, isTrue);
    });

    test('unparseable line degrades to raw-only (amount/unit null)', () {
      final entry = StructuredIngredientDeriver.derive('färsk basilika');

      expect(entry.amount, isNull);
      expect(entry.unit, isNull);
      expect(entry.raw, 'färsk basilika');
      expect(entry.isStructured, isFalse);
    });

    test(
      'raw preserves the line verbatim including surrounding whitespace',
      () {
        final entry = StructuredIngredientDeriver.derive('  3 dl mjölk ');

        // Alignment invariant: form strings are persisted untrimmed, so raw
        // must match exactly or the facade getter discards the entry.
        expect(entry.raw, '  3 dl mjölk ');
        expect(entry.amount, 3);
        expect(entry.unit, 'dl');
      },
    );

    test('empty/whitespace line degrades to raw-only', () {
      final entry = StructuredIngredientDeriver.derive('   ');

      expect(entry.amount, isNull);
      expect(entry.unit, isNull);
      expect(entry.raw, '   ');
    });
  });

  group('StructuredIngredientDeriver.deriveAll', () {
    test('produces one entry per line, index-aligned via raw', () {
      final lines = ['3 dl vetemjöl', 'färsk basilika', '2 ägg'];

      final entries = StructuredIngredientDeriver.deriveAll(lines);

      expect(entries.length, lines.length);
      for (var i = 0; i < lines.length; i++) {
        expect(entries[i].raw, lines[i]);
      }
    });

    test('reuse keeps existing entries on exact raw match instead of '
        're-deriving (preserves richer import-time data)', () {
      const richEntry = RecipeIngredient(
        amount: 3,
        unit: 'dl',
        name: 'vetemjöl',
        note: 'siktat', // regex derivation can never produce a note
        raw: '3 dl vetemjöl',
      );

      final entries = StructuredIngredientDeriver.deriveAll(
        ['2 ägg', '3 dl vetemjöl'], // reordered + one new line
        reuse: const [richEntry],
      );

      expect(
        entries[1],
        same(richEntry),
        reason: 'unchanged line keeps its original entry across reorder',
      );
      expect(entries[0].amount, 2, reason: 'new line is derived');
    });

    test('duplicate raw lines consume reuse entries FIFO — identical lines '
        'under different headings keep their own entries', () {
      const inDeg = RecipeIngredient(
        amount: 1,
        unit: 'dl',
        name: 'socker',
        note: 'strösocker', // distinguishes the entries beyond section
        raw: '1 dl socker',
        section: 'Deg',
      );
      const inFyllning = RecipeIngredient(
        amount: 1,
        unit: 'dl',
        name: 'socker',
        raw: '1 dl socker',
        section: 'Fyllning',
      );

      final entries = StructuredIngredientDeriver.deriveAll(
        ['1 dl socker', '1 dl socker'],
        reuse: const [inDeg, inFyllning],
      );

      expect(entries[0], same(inDeg));
      expect(
        entries[1],
        same(inFyllning),
        reason:
            'second duplicate must get the SECOND reuse entry, not a '
            'copy of the first (the old byRaw map collapsed these)',
      );
    });

    test('more duplicate lines than reuse entries derives the overflow', () {
      const only = RecipeIngredient(
        amount: 2,
        name: 'ägg',
        note: 'rumsvarma',
        raw: '2 ägg',
      );
      final entries = StructuredIngredientDeriver.deriveAll(
        ['2 ägg', '2 ägg'],
        reuse: const [only],
      );
      expect(entries[0], same(only));
      expect(entries[1].note, isNull, reason: 'overflow line is re-derived');
      expect(entries[1].raw, '2 ägg');
    });
  });

  group('StructuredIngredientDeriver.deriveAll sections', () {
    test('sections apply index-aligned to derived entries', () {
      final entries = StructuredIngredientDeriver.deriveAll(
        ['5 dl vetemjöl', '25 g jäst', '75 g smör'],
        sections: ['Deg', 'Deg', 'Fyllning'],
      );
      expect(entries.map((e) => e.section), ['Deg', 'Deg', 'Fyllning']);
    });

    test('sections are AUTHORITATIVE over a reused entry — moving a line to '
        'another heading wins over stale persisted data', () {
      const persisted = RecipeIngredient(
        amount: 1,
        unit: 'dl',
        name: 'socker',
        raw: '1 dl socker',
        section: 'Deg',
      );
      final entries = StructuredIngredientDeriver.deriveAll(
        ['1 dl socker'],
        reuse: const [persisted],
        sections: ['Fyllning'],
      );
      expect(entries.single.section, 'Fyllning');
      expect(entries.single.amount, 1, reason: 'rich data still reused');
    });

    test(
      'a null section in an authoritative list CLEARS the reused section',
      () {
        const persisted = RecipeIngredient(
          name: 'socker',
          raw: 'socker',
          section: 'Deg',
        );
        final entries = StructuredIngredientDeriver.deriveAll(
          ['socker'],
          reuse: const [persisted],
          sections: [null],
        );
        expect(entries.single.section, isNull);
      },
    );

    test('blank section labels normalize to null', () {
      final entries = StructuredIngredientDeriver.deriveAll(
        ['socker'],
        sections: ['   '],
      );
      expect(entries.single.section, isNull);
    });

    test('length mismatch ignores sections entirely (fail open) — reused '
        'sections survive, nothing is misassigned', () {
      const persisted = RecipeIngredient(
        name: 'socker',
        raw: 'socker',
        section: 'Deg',
      );
      final entries = StructuredIngredientDeriver.deriveAll(
        ['socker', '2 ägg'],
        reuse: const [persisted],
        sections: ['Fyllning'], // 1 section for 2 lines — broken bookkeeping
      );
      expect(entries[0].section, 'Deg', reason: 'reuse kept untouched');
      expect(entries[1].section, isNull);
    });

    test(
      'omitting sections keeps reused sections (non-authoritative path)',
      () {
        const persisted = RecipeIngredient(
          name: 'socker',
          raw: 'socker',
          section: 'Deg',
        );
        final entries = StructuredIngredientDeriver.deriveAll(
          ['socker'],
          reuse: const [persisted],
        );
        expect(entries.single, same(persisted));
      },
    );
  });
}
