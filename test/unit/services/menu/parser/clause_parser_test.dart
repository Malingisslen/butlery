/// Direct unit tests for clause_parser's pure helpers (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Covers the cleanly-isolated, Lexicon-driven extraction helpers:
/// detectCount (digit / digit-range / "X till Y" / word-range / vague / word
/// number / nutritional-number guard / default-1), detectMealType (first-word
/// and later-token stem match, empty + no-match), and hasAnyModifier. The full
/// parseClause/_buildSlot orchestration is left to higher-level parser tests.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/menu/parser/clause_parser.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';

void main() {
  group('detectCount', () {
    const lex = Lexicon({
      LexiconCategory.numbers: {'en': '1', 'tre': '3'},
      LexiconCategory.vagueQuantity: {'några': '3'},
    });

    test('digit range takes the upper bound', () {
      final r = detectCount('3-5 middagar', lex);
      expect(r.count, 5);
      expect(r.remaining.trim(), 'middagar');
      expect(r.label, '3–5');
    });

    test('"X till Y" digit range takes the upper bound', () {
      expect(detectCount('2 till 4 rätter', lex).count, 4);
    });

    test('word range resolves the upper word via the numbers lexicon', () {
      final r = detectCount('en till tre middagar', lex);
      expect(r.count, 3);
    });

    test('a plain leading digit is the count', () {
      final r = detectCount('3 middagar', lex);
      expect(r.count, 3);
      expect(r.remaining.trim(), 'middagar');
    });

    test('a nutritional number (kcal) is NOT consumed as a count', () {
      final r = detectCount('500 kcal lunch', lex);
      expect(r.count, 1); // left at default
      expect(r.remaining, '500 kcal lunch');
    });

    test('a vague quantity word maps to its count', () {
      final r = detectCount('några rätter', lex);
      expect(r.count, 3);
      expect(r.label, 'några');
    });

    test('a spelled-out number maps via the numbers lexicon', () {
      expect(detectCount('tre middagar', lex).count, 3);
    });

    test('no count → default 1 with the input untouched', () {
      final r = detectCount('middagar', lex);
      expect(r.count, 1);
      expect(r.remaining, 'middagar');
      expect(r.label, isNull);
    });
  });

  group('detectMealType', () {
    const lex = Lexicon({
      LexiconCategory.mealStems: {'middag': 'middag', 'lunch': 'lunch'},
    });

    test('matches a stem at the first word', () {
      final r = detectMealType('middag pasta', lex);
      expect(r.mealType, 'middag');
      expect(r.remaining, 'pasta');
      expect(r.matchedStem, 'middag');
    });

    test('matches a stem in a later token', () {
      final r = detectMealType('pasta lunch', lex);
      expect(r.mealType, 'lunch');
      expect(r.remaining, 'pasta');
    });

    test('empty input yields no meal type', () {
      final r = detectMealType('', lex);
      expect(r.mealType, isNull);
    });

    test('no stem present yields no meal type, input unchanged', () {
      final r = detectMealType('bara pasta', lex);
      expect(r.mealType, isNull);
      expect(r.remaining, 'bara pasta');
    });
  });

  group('hasAnyModifier', () {
    const lex = Lexicon({
      LexiconCategory.dietaryStems: {'vegansk': 'vegan'},
      LexiconCategory.formatStems: {'pasta': 'pasta'},
    });

    test('true when a token matches a modifier category', () {
      expect(hasAnyModifier('vegansk rätt', lex), isTrue);
      expect(hasAnyModifier('en pasta', lex), isTrue);
    });

    test('false when no token matches', () {
      expect(hasAnyModifier('helt vanlig mat', lex), isFalse);
    });
  });
}
