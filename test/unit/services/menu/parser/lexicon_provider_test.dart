/// Direct unit tests for [Lexicon] (BUT-1149 coverage burndown — previously
/// zero direct coverage).
///
/// The immutable parser lexicon. Covers of() (present category vs empty-map
/// default), the empty constructor, and mergedWith (per-category shallow merge
/// where overlay keys win, base-only keys pass through, overlay-only categories
/// are added) — the Firestore-overlay-on-code-defaults path.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/menu/parser/lexicon_provider.dart';

void main() {
  group('of', () {
    test('returns the map for a present category', () {
      const lex = Lexicon({
        LexiconCategory.numbers: {'en': '1'},
      });
      expect(lex.of(LexiconCategory.numbers), {'en': '1'});
    });

    test('returns an empty map for an absent category', () {
      const lex = Lexicon({});
      expect(lex.of(LexiconCategory.numbers), isEmpty);
    });

    test('empty lexicon yields empty maps', () {
      expect(const Lexicon.empty().of(LexiconCategory.dayNames), isEmpty);
    });
  });

  group('mergedWith', () {
    const base = Lexicon({
      LexiconCategory.numbers: {'en': '1', 'två': '2'},
      LexiconCategory.dayNames: {'måndag': '1'},
    });
    const overlay = Lexicon({
      LexiconCategory.numbers: {'två': 'TWO', 'tre': '3'},
      LexiconCategory.dietaryStems: {'vegansk': 'vegan'},
    });

    test('overlay keys win and new keys are added within a category', () {
      final merged = base.mergedWith(overlay);
      expect(merged.of(LexiconCategory.numbers), {
        'en': '1', // base-only key preserved
        'två': 'TWO', // overlay overrides base
        'tre': '3', // overlay-only key added
      });
    });

    test('base-only categories pass through unchanged', () {
      final merged = base.mergedWith(overlay);
      expect(merged.of(LexiconCategory.dayNames), {'måndag': '1'});
    });

    test('overlay-only categories are added', () {
      final merged = base.mergedWith(overlay);
      expect(merged.of(LexiconCategory.dietaryStems), {'vegansk': 'vegan'});
    });
  });
}
