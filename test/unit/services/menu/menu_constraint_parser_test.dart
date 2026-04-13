import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/menu/parsed_menu_request.dart';
import 'package:butlery/services/menu/parser/code_lexicon_provider.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';
import 'package:butlery/services/menu/parser/menu_constraint_parser.dart';

late Lexicon _lex;

void main() {
  setUpAll(() async {
    _lex = await const CodeLexiconProvider().load();
  });

  // -------------------------------------------------------------------
  // Helper
  // -------------------------------------------------------------------

  ParsedMenuRequest p(String prompt) =>
      MenuConstraintParser.parse(prompt, _lex);

  void expectSlot(
    String prompt,
    String mealType, {
    required int count,
  }) {
    final result = p(prompt);
    expect(result.isEmpty, isFalse, reason: 'expected non-empty for "$prompt"');
    final slot = result.slotRequests.firstWhere(
      (s) => s.mealType == mealType,
      orElse: () => throw TestFailure('No slot for "$mealType" in "$prompt". '
          'Got: ${result.slotRequests.map((s) => s.mealType).toList()}'),
    );
    expect(slot.totalCount, count,
        reason: 'count mismatch for "$mealType" in "$prompt"');
  }

  // -------------------------------------------------------------------
  // COUNTS
  // -------------------------------------------------------------------

  group('counts', () {
    test('digit count', () => expectSlot('3 middagar', 'middag', count: 3));
    test('word count', () => expectSlot('tre middagar', 'middag', count: 3));

    test('high word: tolv',
        () => expectSlot('tolv luncher', 'lunch', count: 12));

    test('vague: ett par', () {
      expectSlot('ett par middagar', 'middag', count: 2);
    });

    test('vague: några', () {
      expectSlot('några luncher', 'lunch', count: 3);
    });

    test('range 2-3', () {
      expectSlot('2-3 middagar', 'middag', count: 3);
    });

    test('range with en-dash', () {
      expectSlot('2–3 middagar', 'middag', count: 3);
    });

    test('word range: två till tre', () {
      expectSlot('två till tre middagar', 'middag', count: 3);
    });

    test('every day', () {
      expectSlot('frukost varje dag', 'frukost', count: 7);
    });

    test('hela veckan', () {
      expectSlot('middag hela veckan', 'middag', count: 7);
    });

    test('varannan dag', () {
      expectSlot('lunch varannan dag', 'lunch', count: 4);
    });

    test('vardagar', () {
      expectSlot('middag vardagar', 'middag', count: 5);
    });
  });

  // -------------------------------------------------------------------
  // MEAL TYPES
  // -------------------------------------------------------------------

  group('meal types', () {
    test('standard: middag', () => expectSlot('3 middag', 'middag', count: 3));

    test('plural: middagar', () {
      expectSlot('3 middagar', 'middag', count: 3);
    });

    test('synonym: kvällsmat → middag', () {
      expectSlot('3 kvällsmat', 'middag', count: 3);
    });

    test('english: dinner → middag', () {
      expectSlot('3 dinners', 'middag', count: 3);
    });

    test('english: breakfast → frukost', () {
      expectSlot('2 breakfast', 'frukost', count: 2);
    });

    test('brunch → frukost', () {
      expectSlot('2 brunch', 'frukost', count: 2);
    });

    test('dessert', () => expectSlot('2 desserter', 'dessert', count: 2));

    test('fika', () => expectSlot('3 fika', 'fika', count: 3));

    test('mellanmål', () {
      expectSlot('2 mellanmål', 'mellanmål', count: 2);
    });

    test('generic "rätter" defaults to middag', () {
      expectSlot('5 rätter', 'middag', count: 5);
    });
  });

  // -------------------------------------------------------------------
  // DIETARY
  // -------------------------------------------------------------------

  group('dietary', () {
    test('vegansk subdivision', () {
      final result = p('3 middagar varav en vegansk');
      final slot = result.slotRequests.first;
      expect(slot.mealType, 'middag');
      expect(slot.totalCount, 3);
      final vegSub =
          slot.subRequests.where((s) => s.dietaryFree.contains('vegansk'));
      expect(vegSub, isNotEmpty);
      expect(vegSub.first.count, 1);
    });

    test('vego alias → vegetarisk', () {
      final result = p('2 middagar varav en vego');
      final sub = result.slotRequests.first.subRequests
          .firstWhere((s) => s.dietaryFree.isNotEmpty);
      expect(sub.dietaryFree, contains('vegetarisk'));
    });

    test('växtbaserat → vegansk', () {
      final result = p('3 luncher varav en växtbaserad');
      final sub = result.slotRequests.first.subRequests
          .firstWhere((s) => s.dietaryFree.isNotEmpty);
      expect(sub.dietaryFree, contains('vegansk'));
    });
  });

  // -------------------------------------------------------------------
  // ALLERGENS
  // -------------------------------------------------------------------

  group('allergens', () {
    test('glutenfri suffix', () {
      final result = p('3 middagar varav en glutenfri');
      final sub = result.slotRequests.first.subRequests
          .firstWhere((s) => s.allergenFree.isNotEmpty);
      expect(sub.allergenFree, contains('gluten'));
      expect(sub.count, 1);
    });

    test('inget jordnötter (global negation)', () {
      final result = p('inget jordnötter, 3 middagar');
      expect(result.globalAllergenAvoid, contains('jordnötter'));
      expect(result.slotRequests, isNotEmpty);
    });

    test('utan gluten (preposition negation)', () {
      final result = p('utan gluten, 3 middagar');
      expect(result.globalAllergenAvoid, contains('gluten'));
    });

    test('combined: gluten- och laktosfri', () {
      final result = p('3 middagar varav en glutenfri och laktosfri');
      final subs = result.slotRequests.first.subRequests;
      final allergSubs = subs.where((s) => s.allergenFree.isNotEmpty).toList();
      final allKeys = allergSubs.expand((s) => s.allergenFree).toSet();
      expect(allKeys, containsAll(['gluten', 'laktos']));
    });

    test('inga nötter eller fisk', () {
      final result = p('inga nötter eller fisk, 2 luncher');
      expect(result.globalAllergenAvoid, containsAll(['nötter', 'fisk']));
    });

    test('allergen-free suffixes: all 21 keys mapped', () {
      final stems = _lex.of(LexiconCategory.allergenFreeStems);
      final values = stems.values.toSet();
      expect(
        values,
        containsAll([
          'gluten',
          'mjölk',
          'laktos',
          'ägg',
          'fisk',
          'soja',
          'sesam',
          'kräftdjur',
          'blötdjur',
          'trädnötter',
          'jordnötter',
          'nötter',
          'selleri',
          'senap',
          'lupin',
          'sulfiter',
          'kött',
          'fläsk',
          'nötkött',
          'alkohol',
          'skaldjur',
        ]),
      );
    });
  });

  // -------------------------------------------------------------------
  // CUISINES
  // -------------------------------------------------------------------

  group('cuisines', () {
    for (final pair in [
      ('italiensk', 'italiensk'),
      ('mexikansk', 'mexikansk'),
      ('thai', 'thailandsk'),
      ('asiatisk', 'asiatisk'),
      ('indisk', 'indisk'),
      ('japansk', 'japansk'),
      ('svensk', 'svensk'),
      ('grekisk', 'grekisk'),
      ('spansk', 'spansk'),
      ('fransk', 'fransk'),
      ('marockansk', 'marockansk'),
    ]) {
      test('cuisine ${pair.$1}', () {
        final result = p('3 middagar varav en ${pair.$1}');
        final sub = result.slotRequests.first.subRequests
            .firstWhere((s) => s.requiredCuisines.isNotEmpty);
        expect(sub.requiredCuisines, contains(pair.$2));
      });
    }
  });

  // -------------------------------------------------------------------
  // FORMATS AND VERBS
  // -------------------------------------------------------------------

  group('formats and verbs', () {
    test('soppa', () {
      final result = p('3 middagar varav en soppa');
      final sub = result.slotRequests.first.subRequests
          .firstWhere((s) => s.requiredTags.isNotEmpty);
      expect(sub.requiredTags, contains('soppa'));
    });

    test('gryta', () {
      final result = p('2 middagar varav en gryta');
      final sub = result.slotRequests.first.subRequests
          .firstWhere((s) => s.requiredTags.isNotEmpty);
      expect(sub.requiredTags, contains('gryta'));
    });

    test('baka bröd → ovrigt with bröd tag', () {
      final result = p('baka bröd två dagar');
      final ovrigt =
          result.slotRequests.where((s) => s.mealType == 'ovrigt').toList();
      expect(ovrigt, isNotEmpty, reason: 'expected ovrigt slot');
      final tags =
          ovrigt.first.subRequests.expand((s) => s.requiredTags).toSet();
      expect(tags, contains('bröd'));
    });
  });

  // -------------------------------------------------------------------
  // TIME
  // -------------------------------------------------------------------

  group('time', () {
    test('max 30 minuter', () {
      final result = p('3 middagar max 30 minuter');
      final sub = result.slotRequests.first.subRequests.first;
      expect(sub.maxTimeMinutes, 30);
    });

    test('under 20 min', () {
      final result = p('3 middagar under 20 min');
      final sub = result.slotRequests.first.subRequests.first;
      expect(sub.maxTimeMinutes, 20);
    });

    test('snabba middagar → 30 min default', () {
      final result = p('3 snabba middagar');
      final sub = result.slotRequests.first.subRequests.first;
      expect(sub.maxTimeMinutes, 30);
    });
  });

  // -------------------------------------------------------------------
  // DAY PINS
  // -------------------------------------------------------------------

  group('day pins', () {
    test('tacofredag', () {
      final result = p('tacofredag');
      expect(result.dayPins, isNotEmpty);
      expect(result.dayPins.first.weekdayIndex, 5);
      expect(result.dayPins.first.constraint.requiredTags, contains('tacos'));
    });

    test('fredag tacos', () {
      final result = p('fredag tacos');
      expect(result.dayPins, isNotEmpty);
      expect(result.dayPins.first.weekdayIndex, 5);
    });

    test('fredagsmys', () {
      final result = p('fredagsmys, 3 middagar');
      expect(result.dayPins.any((p) => p.weekdayIndex == 5), isTrue);
    });
  });

  // -------------------------------------------------------------------
  // THEMES
  // -------------------------------------------------------------------

  group('themes', () {
    test('vardagsmat', () {
      final result = p('5 vardagsmat middagar');
      final tags = result.slotRequests.first.subRequests
          .expand((s) => s.requiredTags)
          .toSet();
      expect(tags, contains('vardagsmiddag'));
    });

    test('husmanskost', () {
      final result = p('3 husmanskost middagar');
      final tags = result.slotRequests.first.subRequests
          .expand((s) => s.requiredTags)
          .toSet();
      expect(tags, contains('husmanskost'));
    });

    test('billigt', () {
      final result = p('3 billigt middagar');
      final tags = result.slotRequests.first.subRequests
          .expand((s) => s.requiredTags)
          .toSet();
      expect(tags, contains('budget'));
    });

    test('matlåda', () {
      final result = p('2 middagar varav två matlådor');
      final sub = result.slotRequests.first.subRequests
          .firstWhere((s) => s.requiredTags.isNotEmpty);
      expect(sub.requiredTags, contains('meal-prep'));
    });
  });

  // -------------------------------------------------------------------
  // SUBDIVISIONS
  // -------------------------------------------------------------------

  group('subdivisions', () {
    test('varav en X', () {
      final result = p('3 middagar varav en vegansk');
      final slot = result.slotRequests.first;
      expect(slot.totalCount, 3);
      final vegSub =
          slot.subRequests.firstWhere((s) => s.dietaryFree.contains('vegansk'));
      expect(vegSub.count, 1);
    });

    test('där en ska vara', () {
      final result = p('4 luncher där en ska vara italiensk');
      final slot = result.slotRequests.first;
      expect(slot.totalCount, 4);
      final itSub = slot.subRequests
          .firstWhere((s) => s.requiredCuisines.contains('italiensk'));
      expect(itSub.count, 1);
    });

    test('remainder becomes unconstrained', () {
      final result = p('5 middagar varav 2 vegetariska');
      final slot = result.slotRequests.first;
      expect(slot.totalCount, 5);
      final unconstrained =
          slot.subRequests.where((s) => s.isUnconstrained).toList();
      expect(unconstrained, isNotEmpty);
      expect(unconstrained.first.count, 3);
    });

    test('soft constraint with gärna', () {
      final result = p('3 middagar varav gärna en italiensk');
      final slot = result.slotRequests.first;
      final soft = slot.subRequests.where((s) => s.isSoft).toList();
      expect(soft, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------
  // SKIP FRUKOST
  // -------------------------------------------------------------------

  group('skip frukost', () {
    test('ingen frukost', () {
      final result = p('ingen frukost, 3 middagar');
      final fruSlots =
          result.slotRequests.where((s) => s.mealType == 'frukost');
      expect(fruSlots, isEmpty);
      expect(result.slotRequests.first.mealType, 'middag');
    });

    test('16:8', () {
      final result = p('16:8, 3 middagar, 2 luncher');
      final fruSlots =
          result.slotRequests.where((s) => s.mealType == 'frukost');
      expect(fruSlots, isEmpty);
    });
  });

  // -------------------------------------------------------------------
  // ROBUSTNESS
  // -------------------------------------------------------------------

  group('robustness', () {
    test('polite preamble stripped', () {
      final result = p('hej, kan du planera 3 middagar');
      expect(result.isEmpty, isFalse);
      expectSlot('hej, kan du planera 3 middagar', 'middag', count: 3);
    });

    test('diacritic-stripped: vagansk → vegansk', () {
      final result = p('3 middagar varav en vagansk');
      // Levenshtein fallback — "vagansk" is distance 1 from "vegansk"
      final allDietary = result.slotRequests.first.subRequests
          .expand((s) => s.dietaryFree)
          .toSet();
      expect(allDietary, contains('vegansk'));
    });

    test('empty prompt → isEmpty', () {
      expect(p('').isEmpty, isTrue);
      expect(p('   ').isEmpty, isTrue);
    });

    test('just preamble → isEmpty', () {
      expect(p('hej kan du').isEmpty, isTrue);
    });

    test('multiple clauses: comma-separated', () {
      final result = p('3 middagar, 2 luncher');
      expect(result.slotRequests.length, 2);
      expectSlot('3 middagar, 2 luncher', 'middag', count: 3);
      expectSlot('3 middagar, 2 luncher', 'lunch', count: 2);
    });

    test('multiple clauses: och-separated', () {
      final result = p('3 middagar och 2 luncher');
      expect(result.slotRequests.length, 2);
    });
  });

  // -------------------------------------------------------------------
  // EXTRACTION TRACE
  // -------------------------------------------------------------------

  group('extraction trace', () {
    test('understood is populated for simple prompt', () {
      final result = p('3 middagar');
      expect(result.trace.understood, isNotEmpty);
    });

    test('notUnderstood captures unknown tokens', () {
      final result = p('3 middagar och något kul');
      expect(result.trace.notUnderstood, isNotEmpty);
    });
  });

  // -------------------------------------------------------------------
  // FULL MOTIVATING EXAMPLE
  // -------------------------------------------------------------------

  group('full motivating example', () {
    test('comprehensive prompt', () {
      final result = p(
        '3 middagar varav en glutenfri och två matlådor, '
        '4 luncher där en ska vara vegansk och en italiensk. '
        'Inget jordnötter denna vecka och baka bröd två dagar.',
      );

      expect(result.isEmpty, isFalse);

      // Global allergen
      expect(result.globalAllergenAvoid, contains('jordnötter'));

      // Middag slot
      final middag =
          result.slotRequests.firstWhere((s) => s.mealType == 'middag');
      expect(middag.totalCount, 3);

      // Lunch slot
      final lunch =
          result.slotRequests.firstWhere((s) => s.mealType == 'lunch');
      expect(lunch.totalCount, 4);

      // Bröd in ovrigt or as day-format
      final hasBrod = result.slotRequests
              .expand((s) => s.subRequests)
              .any((c) => c.requiredTags.contains('bröd')) ||
          result.slotRequests.any((s) =>
              s.mealType == 'ovrigt' &&
              s.subRequests.any((c) => c.requiredTags.contains('bröd')));
      expect(hasBrod, isTrue, reason: 'expected bröd tag somewhere');

      // Trace should have many understood entries and no (or few) not-understood
      expect(result.trace.understood.length, greaterThan(4));
    });
  });
}
