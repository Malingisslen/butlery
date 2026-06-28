/// Direct unit tests for the menu-prompt global_extractor functions (BUT-1149
/// coverage burndown — previously zero direct coverage).
///
/// Pure extraction passes that pull global constraints out of a Swedish menu
/// prompt before clause splitting: day→format pins, global dietary requirements,
/// allergen/ingredient negations, and verb-object sweeps. Each takes a Lexicon
/// (built here from minimal fixtures) plus output collections, mutates them, and
/// returns the prompt with the consumed spans masked.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/services/menu/parser/global_extractor.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';

void main() {
  group('extractDayFormatPins', () {
    final lex = const Lexicon({
      LexiconCategory.dayNames: {'måndag': '1'},
      LexiconCategory.formatStems: {'pasta': 'pasta'},
    });

    test('pins a recognised format to the named day and masks the span', () {
      final pins = <DayPin>[];
      final understood = <TraceEntry>[];
      final out = extractDayFormatPins('måndag pasta', lex, pins, understood);

      expect(pins, hasLength(1));
      expect(pins.first.weekdayIndex, 1);
      expect(pins.first.mealType, 'middag');
      expect(pins.first.constraint.requiredTags, contains('pasta'));
      expect(understood.any((e) => e.category == TraceCategory.day), isTrue);
      expect(out.contains('pasta'), isFalse); // consumed
    });

    test('supports the "day: format" colon form', () {
      final pins = <DayPin>[];
      extractDayFormatPins('måndag: pasta', lex, pins, <TraceEntry>[]);
      expect(pins, hasLength(1));
    });

    test('does not pin when the following word is not a known tag', () {
      final pins = <DayPin>[];
      extractDayFormatPins('måndag bordet', lex, pins, <TraceEntry>[]);
      expect(pins, isEmpty);
    });
  });

  group('extractGlobalDietary', () {
    final lex = const Lexicon({
      LexiconCategory.dietaryStems: {'vegetariskt': 'vegetarian'},
    });

    test('captures "bara <diet>" into the require set', () {
      final require = <String>{};
      final out = extractGlobalDietary(
        'bara vegetariskt',
        lex,
        require,
        <TraceEntry>[],
      );
      expect(require, contains('vegetarian'));
      expect(out.contains('vegetariskt'), isFalse);
    });

    test('ignores a prefix followed by an unknown word', () {
      final require = <String>{};
      extractGlobalDietary('bara bordet', lex, require, <TraceEntry>[]);
      expect(require, isEmpty);
    });

    test('returns working unchanged when the dietary lexicon is empty', () {
      final require = <String>{};
      final out = extractGlobalDietary(
        'bara vegetariskt',
        const Lexicon.empty(),
        require,
        <TraceEntry>[],
      );
      expect(out, 'bara vegetariskt');
      expect(require, isEmpty);
    });
  });

  group('extractAllergenNegations', () {
    final lex = const Lexicon({
      LexiconCategory.negationWords: {'inget': 'x'},
      LexiconCategory.allergenNounStems: {'mjölk': 'dairy', 'ägg': 'egg'},
    });

    test('maps a negated allergen noun into the avoid set', () {
      final avoid = <String>{};
      extractAllergenNegations(
        'inget mjölk',
        lex,
        avoid,
        <String>{},
        <TraceEntry>[],
      );
      expect(avoid, contains('dairy'));
    });

    test('chains negated nouns across "och"', () {
      final avoid = <String>{};
      extractAllergenNegations(
        'inget mjölk och ägg',
        lex,
        avoid,
        <String>{},
        <TraceEntry>[],
      );
      expect(avoid, containsAll(<String>['dairy', 'egg']));
    });

    test('captures an unknown word (≥3 chars) as a raw exclude tag', () {
      final excl = <String>{};
      extractAllergenNegations(
        'inget broccoli',
        lex,
        <String>{},
        excl,
        <TraceEntry>[],
      );
      expect(excl, contains('broccoli'));
    });
  });

  group('sweepVerbObjects', () {
    final lex = const Lexicon({
      LexiconCategory.verbObjectMap: {'baka': 'baking'},
      LexiconCategory.numbers: {'tre': '3'},
    });

    test('adds an övrigt slot for a verb-object match (count 1)', () {
      final slots = <SlotRequest>[];
      sweepVerbObjects('baka bröd', lex, slots, <TraceEntry>[]);
      expect(slots, hasLength(1));
      expect(slots.first.mealType, 'ovrigt');
      expect(slots.first.subRequests.first.requiredTags, contains('baking'));
      expect(slots.first.subRequests.first.count, 1);
    });

    test('reads a numeric quantity', () {
      final slots = <SlotRequest>[];
      sweepVerbObjects('baka bröd 3 dagar', lex, slots, <TraceEntry>[]);
      expect(slots.first.subRequests.first.count, 3);
    });

    test('reads a spelled-out quantity via the numbers lexicon', () {
      final slots = <SlotRequest>[];
      sweepVerbObjects('baka bröd tre gånger', lex, slots, <TraceEntry>[]);
      expect(slots.first.subRequests.first.count, 3);
    });

    test('does not duplicate a tag already present in a slot', () {
      final slots = <SlotRequest>[
        const SlotRequest(
          mealType: 'ovrigt',
          subRequests: [
            RecipeConstraint(count: 1, requiredTags: {'baking'}),
          ],
        ),
      ];
      sweepVerbObjects('baka bröd', lex, slots, <TraceEntry>[]);
      expect(slots, hasLength(1)); // no new slot added
    });

    test('is a no-op when the verb lexicon is empty', () {
      final slots = <SlotRequest>[];
      sweepVerbObjects(
        'baka bröd',
        const Lexicon.empty(),
        slots,
        <TraceEntry>[],
      );
      expect(slots, isEmpty);
    });
  });
}
