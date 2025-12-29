import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_lookup_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';

void main() {
  group('IngredientLookupResult', () {
    group('construction', () {
      test('creates with required parameters', () {
        final matched = [
          _ingredient('chicken', 'protein/meat/poultry', {'meat'}),
        ];
        final result = IngredientLookupResult(
          matched: matched,
          unmatched: ['unknown'],
          coverage: 0.5,
        );

        expect(result.matched, matched);
        expect(result.unmatched, ['unknown']);
        expect(result.coverage, 0.5);
      });

      test('empty() creates result with 0% coverage (no data)', () {
        // HIGH-1: Empty recipes have 0.0 coverage because there's
        // no ingredient data to analyze (consistent with TagResult.empty())
        final result = IngredientLookupResult.empty();

        expect(result.matched, isEmpty);
        expect(result.unmatched, isEmpty);
        expect(result.coverage, 0.0);
      });

      test('fromLists calculates coverage correctly', () {
        final result = IngredientLookupResult.fromLists(
          matched: [
            _ingredient('a', 'group', {}),
            _ingredient('b', 'group', {}),
            _ingredient('c', 'group', {}),
          ],
          unmatched: ['unknown'],
        );

        expect(result.coverage, 0.75);
        expect(result.matchedCount, 3);
        expect(result.unmatchedCount, 1);
        expect(result.totalCount, 4);
      });

      test('fromLists returns 100% coverage when all matched', () {
        final result = IngredientLookupResult.fromLists(
          matched: [_ingredient('a', 'group', {})],
          unmatched: [],
        );

        expect(result.coverage, 1.0);
        expect(result.hasFullCoverage, isTrue);
      });

      test('fromLists returns 0% coverage when empty (no data)', () {
        // HIGH-1: Empty lists = no data to analyze = 0.0 coverage
        final result = IngredientLookupResult.fromLists(
          matched: [],
          unmatched: [],
        );

        expect(result.coverage, 0.0);
      });
    });

    group('convenience getters', () {
      test('hasUnknowns returns true when unmatched is not empty', () {
        final withUnknowns = IngredientLookupResult.fromLists(
          matched: [_ingredient('a', 'group', {})],
          unmatched: ['unknown'],
        );
        final withoutUnknowns = IngredientLookupResult.fromLists(
          matched: [_ingredient('a', 'group', {})],
          unmatched: [],
        );

        expect(withUnknowns.hasUnknowns, isTrue);
        expect(withoutUnknowns.hasUnknowns, isFalse);
      });

      test('hasFullCoverage returns true when coverage >= 1.0', () {
        final full = IngredientLookupResult(
          matched: [],
          unmatched: [],
          coverage: 1.0,
        );
        final partial = IngredientLookupResult(
          matched: [],
          unmatched: ['x'],
          coverage: 0.9,
        );

        expect(full.hasFullCoverage, isTrue);
        expect(partial.hasFullCoverage, isFalse);
      });

      test('count getters return correct values', () {
        final result = IngredientLookupResult.fromLists(
          matched: [
            _ingredient('a', 'group', {}),
            _ingredient('b', 'group', {}),
          ],
          unmatched: ['x', 'y', 'z'],
        );

        expect(result.matchedCount, 2);
        expect(result.unmatchedCount, 3);
        expect(result.totalCount, 5);
      });
    });

    group('property aggregation', () {
      test('allProperties returns unique properties from all ingredients', () {
        final result = IngredientLookupResult.fromLists(
          matched: [
            _ingredient('chicken', 'protein/meat', {'meat', 'poultry'}),
            _ingredient('beef', 'protein/meat', {'meat', 'beef'}),
          ],
          unmatched: [],
        );

        expect(result.allProperties, {'meat', 'poultry', 'beef'});
      });

      test('allGroups returns unique groups', () {
        final result = IngredientLookupResult.fromLists(
          matched: [
            _ingredient('chicken', 'protein/meat/poultry', {}),
            _ingredient('beef', 'protein/meat/beef', {}),
            _ingredient('rice', 'grain', {}),
          ],
          unmatched: [],
        );

        expect(result.allGroups, {
          'protein/meat/poultry',
          'protein/meat/beef',
          'grain',
        });
      });

      test('allTopLevelGroups returns unique top-level groups', () {
        final result = IngredientLookupResult.fromLists(
          matched: [
            _ingredient('chicken', 'protein/meat/poultry', {}),
            _ingredient('beef', 'protein/meat/beef', {}),
            _ingredient('rice', 'grain', {}),
            _ingredient('carrot', 'vegetable/root', {}),
          ],
          unmatched: [],
        );

        expect(result.allTopLevelGroups, {'protein', 'grain', 'vegetable'});
      });
    });

    group('property queries', () {
      late IngredientLookupResult result;

      setUp(() {
        result = IngredientLookupResult.fromLists(
          matched: [
            _ingredient('chicken', 'protein/meat/poultry', {'meat', 'poultry'}),
            _ingredient('egg', 'protein/egg', {'egg', 'animal-product'}),
            _ingredient('pasta', 'grain/pasta', {'contains-gluten'}),
          ],
          unmatched: [],
        );
      });

      test('hasProperty returns true when any ingredient has property', () {
        expect(result.hasProperty('meat'), isTrue);
        expect(result.hasProperty('egg'), isTrue);
        expect(result.hasProperty('contains-gluten'), isTrue);
        expect(result.hasProperty('dairy'), isFalse);
      });

      test('hasAnyProperty returns true when any property exists', () {
        expect(result.hasAnyProperty(['meat', 'dairy']), isTrue);
        expect(result.hasAnyProperty(['fish', 'dairy']), isFalse);
      });

      test('getIngredientsWithProperty returns matching ingredients', () {
        final meats = result.getIngredientsWithProperty('meat');

        expect(meats.length, 1);
        expect(meats.first.swedish, 'chicken');
      });
    });

    group('group queries', () {
      late IngredientLookupResult result;

      setUp(() {
        result = IngredientLookupResult.fromLists(
          matched: [
            _ingredient('chicken', 'protein/meat/poultry', {}),
            _ingredient('salmon', 'protein/seafood/fish', {}),
            _ingredient('shrimp', 'protein/seafood/shellfish', {}),
            _ingredient('carrot', 'vegetable/root', {}),
          ],
          unmatched: [],
        );
      });

      test('hasGroup matches exact and child groups', () {
        expect(result.hasGroup('protein'), isTrue);
        expect(result.hasGroup('protein/meat'), isTrue);
        expect(result.hasGroup('protein/meat/poultry'), isTrue);
        expect(result.hasGroup('protein/seafood'), isTrue);
        expect(result.hasGroup('protein/dairy'), isFalse);
      });

      test('getIngredientsInGroup returns matching ingredients', () {
        final seafood = result.getIngredientsInGroup('protein/seafood');

        expect(seafood.length, 2);
        expect(
            seafood.map((i) => i.swedish), containsAll(['salmon', 'shrimp']));
      });

      test('convenience group getters work correctly', () {
        expect(result.hasMeat, isTrue);
        expect(result.hasSeafood, isTrue);
        expect(result.hasFish, isTrue);
        expect(result.hasShellfish, isTrue);
        expect(result.hasVegetables, isTrue);
        expect(result.hasDairy, isFalse);
        expect(result.hasEggs, isFalse);
      });
    });

    group('TriState calculations', () {
      test('getPropertyStatus returns CONTAINS when property exists', () {
        final result = IngredientLookupResult.fromLists(
          matched: [
            _ingredient('pasta', 'grain', {'contains-gluten'})
          ],
          unmatched: [],
        );

        expect(result.getPropertyStatus('contains-gluten'), TriState.contains);
      });

      test('getPropertyStatus returns FREE when 100% coverage and no property',
          () {
        final result = IngredientLookupResult.fromLists(
          matched: [_ingredient('rice', 'grain', {})],
          unmatched: [],
        );

        expect(result.getPropertyStatus('contains-gluten'), TriState.free);
      });

      test('getPropertyStatus returns UNKNOWN when coverage < 100%', () {
        final result = IngredientLookupResult.fromLists(
          matched: [_ingredient('rice', 'grain', {})],
          unmatched: ['unknown'],
        );

        expect(result.getPropertyStatus('contains-gluten'), TriState.unknown);
      });

      test('getCombinedPropertyStatus uses OR logic', () {
        final result = IngredientLookupResult.fromLists(
          matched: [
            _ingredient('almond', 'nut', {'tree-nut'})
          ],
          unmatched: [],
        );

        // tree-nut OR peanut = CONTAINS (because tree-nut is present)
        expect(
          result.getCombinedPropertyStatus(['tree-nut', 'peanut']),
          TriState.contains,
        );
      });

      test('getCombinedPropertyStatus returns FREE when none present', () {
        final result = IngredientLookupResult.fromLists(
          matched: [_ingredient('rice', 'grain', {})],
          unmatched: [],
        );

        expect(
          result.getCombinedPropertyStatus(['tree-nut', 'peanut']),
          TriState.free,
        );
      });

      test('getDietaryStatus checks excluded properties', () {
        final meatResult = IngredientLookupResult.fromLists(
          matched: [
            _ingredient('chicken', 'meat', {'meat'})
          ],
          unmatched: [],
        );

        final veggieResult = IngredientLookupResult.fromLists(
          matched: [_ingredient('tofu', 'plant', {})],
          unmatched: [],
        );

        // Vegetarian excludes meat and seafood
        expect(
          meatResult.getDietaryStatus(['meat', 'seafood']),
          TriState.contains,
        );
        expect(
          veggieResult.getDietaryStatus(['meat', 'seafood']),
          TriState.free,
        );
      });
    });

    group('copyWith', () {
      test('creates copy with new matched ingredients', () {
        final original = IngredientLookupResult.fromLists(
          matched: [_ingredient('a', 'group', {})],
          unmatched: ['x'],
        );

        final copy = original.copyWith(
          matched: [
            _ingredient('a', 'group', {}),
            _ingredient('b', 'group', {}),
          ],
        );

        expect(copy.matchedCount, 2);
        expect(copy.unmatchedCount, 1);
        // Coverage recalculated
        expect(copy.coverage, closeTo(0.667, 0.01));
      });

      test('creates copy with new unmatched ingredients', () {
        final original = IngredientLookupResult.fromLists(
          matched: [_ingredient('a', 'group', {})],
          unmatched: ['x'],
        );

        final copy = original.copyWith(unmatched: []);

        expect(copy.matchedCount, 1);
        expect(copy.unmatchedCount, 0);
        expect(copy.coverage, 1.0);
      });
    });

    group('merge', () {
      test('combines matched and unmatched from both results', () {
        final result1 = IngredientLookupResult.fromLists(
          matched: [_ingredient('a', 'group', {})],
          unmatched: ['x'],
        );
        final result2 = IngredientLookupResult.fromLists(
          matched: [_ingredient('b', 'group', {})],
          unmatched: ['y'],
        );

        final merged = result1.merge(result2);

        expect(merged.matchedCount, 2);
        expect(merged.unmatchedCount, 2);
        expect(merged.coverage, 0.5);
      });
    });

    group('toString', () {
      test('includes match counts and coverage', () {
        final result = IngredientLookupResult.fromLists(
          matched: [_ingredient('a', 'group', {})],
          unmatched: ['x', 'y'],
        );

        final str = result.toString();

        expect(str, contains('1 matched'));
        expect(str, contains('2 unmatched'));
        expect(str, contains('33%'));
      });
    });
  });
}

IngredientData _ingredient(String name, String group, Set<String> properties) {
  return IngredientData(
    id: name.toLowerCase().replaceAll(' ', '-'),
    swedish: name,
    english: name,
    group: group,
    properties: properties,
  );
}
