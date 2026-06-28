/// Direct unit tests for [ParsedMenuRequest] and its companions (BUT-1149
/// coverage burndown — previously zero direct coverage).
///
/// Pure data model carrying parsed menu intent. The computed getters are what
/// matter: the empty factory + isEmpty, SlotRequest.totalCount, the
/// RecipeConstraint.isUnconstrained predicate (how legacy "3 middagar" flows
/// through unchanged), and ExtractionTrace.hasGaps.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/parsed_menu_request.dart';

void main() {
  group('ParsedMenuRequest.empty / isEmpty', () {
    test('empty factory carries the prompt and is empty', () {
      final r = ParsedMenuRequest.empty('en veckomeny');
      expect(r.rawPrompt, 'en veckomeny');
      expect(r.slotRequests, isEmpty);
      expect(r.isEmpty, isTrue);
    });

    test('isEmpty is false once a slot request exists', () {
      final r = ParsedMenuRequest(
        slotRequests: const [
          SlotRequest(mealType: 'middag', subRequests: []),
        ],
        globalAllergenAvoid: const {},
        globalDietaryRequire: const {},
        dayPins: const [],
        trace: const ExtractionTrace(),
        rawPrompt: 'x',
      );
      expect(r.isEmpty, isFalse);
    });

    test('isEmpty stays true when only global filters are set', () {
      final r = ParsedMenuRequest(
        slotRequests: const [],
        globalAllergenAvoid: const {'mjölk'},
        globalDietaryRequire: const {'vegansk'},
        dayPins: const [],
        trace: const ExtractionTrace(),
        rawPrompt: 'x',
      );
      expect(r.isEmpty, isTrue);
    });
  });

  group('SlotRequest.totalCount', () {
    test('sums the counts of all sub-requests', () {
      const slot = SlotRequest(
        mealType: 'middag',
        subRequests: [
          RecipeConstraint(count: 2),
          RecipeConstraint(count: 1, dietaryFree: {'vegansk'}),
        ],
      );
      expect(slot.totalCount, 3);
    });

    test('is zero for an empty slot', () {
      const slot = SlotRequest(mealType: 'lunch', subRequests: []);
      expect(slot.totalCount, 0);
    });
  });

  group('RecipeConstraint.isUnconstrained', () {
    test('true when no filters and no time bound are set', () {
      expect(const RecipeConstraint(count: 3).isUnconstrained, isTrue);
    });

    test('false when any filter or the time bound is present', () {
      expect(
        const RecipeConstraint(count: 1, maxTimeMinutes: 30).isUnconstrained,
        isFalse,
      );
      expect(
        const RecipeConstraint(
          count: 1,
          allergenFree: {'mjölk'},
        ).isUnconstrained,
        isFalse,
      );
      expect(
        const RecipeConstraint(
          count: 1,
          requiredCuisines: {'italiensk'},
        ).isUnconstrained,
        isFalse,
      );
    });
  });

  group('ExtractionTrace.hasGaps', () {
    test('false for a clean trace', () {
      expect(const ExtractionTrace().hasGaps, isFalse);
    });

    test('true when there is anything not understood or any warning', () {
      expect(
        const ExtractionTrace(notUnderstood: ['blah']).hasGaps,
        isTrue,
      );
      expect(
        const ExtractionTrace(warnings: ['heads up']).hasGaps,
        isTrue,
      );
    });
  });
}
