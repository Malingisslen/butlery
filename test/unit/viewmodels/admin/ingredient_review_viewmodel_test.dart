/// The ingredient review tab's ViewModel: an empty or failed load is an error
/// (never "0 ingredienser"), counters keep deleted/unknown statuses in an
/// "övrigt" bucket, and filters combine.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/viewmodels/admin/ingredient_review_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../test_support/ingredient_review_fixtures.dart';

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  IngredientReviewViewModel build({
    List<IngredientData>? items,
    Object? error,
    bool withConfig = true,
  }) => IngredientReviewViewModel(
    repository: FakeIngredientRepository(
      items ?? ingredientReviewSample(),
      error: error,
    ),
    tagConfigService: FakeTagConfigService(
      withConfig ? ingredientReviewConfig() : null,
    ),
  );

  test('counts per status with deleted in the övrigt bucket', () async {
    final vm = build();
    await vm.load();
    expect(vm.statusCounts, {
      'draft': 1,
      'validated': 1,
      'verified': 1,
      'needs-review': 1,
      'other': 1,
    });
    expect(vm.totalCount, 5);
    expect(vm.error, isNull);
  });

  test('unknown status also counts as övrigt', () async {
    final vm = build(
      items: [
        IngredientData(
          id: 'x',
          swedish: 'x',
          english: 'x',
          group: 'g',
          properties: const {},
          status: 'user-defined',
        ),
      ],
    );
    await vm.load();
    expect(vm.statusCounts['other'], 1);
  });

  test('empty load is an error, never zero ingredients', () async {
    final vm = build(items: const []);
    await vm.load();
    expect(vm.error, isNotNull);
    expect(vm.totalCount, 0);
  });

  test('throwing repository is an error state', () async {
    final vm = build(error: StateError('offline'));
    await vm.load();
    expect(vm.error, isNotNull);
    expect(vm.ingredients, isEmpty);
  });

  test('last synced is the newest updatedAt', () async {
    final vm = build();
    await vm.load();
    expect(vm.lastSynced, DateTime.utc(2026, 10, 20));
  });

  test('search matches Swedish, English, aliases and id', () async {
    final vm = build();
    await vm.load();
    vm.setQuery('vetemjöl');
    expect(vm.ingredients.map((i) => i.id), ['wheat-flour']);
    vm.setQuery('chicken');
    expect(vm.ingredients.map((i) => i.id), ['chicken-breast']);
    vm.setQuery('mjöl');
    expect(vm.ingredients.map((i) => i.id), ['wheat-flour']);
    vm.setQuery('tap water');
    expect(vm.ingredients.map((i) => i.id), ['water']);
    vm.setQuery('almond');
    expect(vm.ingredients.map((i) => i.id), ['almond']);
  });

  test('status and top-level group filters combine', () async {
    final vm = build();
    await vm.load();
    vm.setGroupFilter('pantry');
    expect(vm.ingredients.length, 3);
    vm.setStatusFilter('verified');
    expect(vm.ingredients.map((i) => i.id), ['wheat-flour']);
    vm.setStatusFilter('other');
    expect(vm.ingredients, isEmpty);
  });

  test(
    'allergen filter uses the tagger result, with a no-allergen option',
    () async {
      final vm = build();
      await vm.load();
      vm.setAllergenFilter('gluten');
      expect(vm.ingredients.map((i) => i.id), ['wheat-flour']);
      vm.setAllergenFilter('nötter');
      expect(vm.ingredients.map((i) => i.id), ['almond']);
      vm.setAllergenFilter(IngredientReviewViewModel.noAllergenFilter);
      expect(vm.ingredients.map((i) => i.id).toSet(), {
        'chicken-breast',
        'water',
        'salt',
      });
      vm.setStatusFilter('draft');
      expect(vm.ingredients.map((i) => i.id), ['chicken-breast']);
    },
  );

  test('missing price needs both price fields empty', () async {
    final vm = build();
    await vm.load();
    vm.setMissingPriceOnly(true);
    expect(vm.ingredients.map((i) => i.id).toSet(), {
      'chicken-breast',
      'water',
    });
  });

  test('missing tag config keeps the list but flags allergen data', () async {
    final vm = build(withConfig: false);
    await vm.load();
    expect(vm.hasTagConfig, isFalse);
    expect(vm.totalCount, 5);
    expect(vm.previewOf(vm.ingredients.first), isNull);
  });

  test(
    'clipboard text carries id, name, group, status, allergens, diets',
    () async {
      final vm = build();
      await vm.load();
      final text = vm.claudeTextFor(
        vm.ingredients.firstWhere((i) => i.id == 'chicken-breast'),
      );
      expect(text, contains('Id: chicken-breast'));
      expect(text, contains('Svenskt namn: kycklingbröst'));
      expect(text, contains('Grupp: protein/meat'));
      expect(text, contains('Status: draft'));
      expect(text, contains('Egenskaper: meat'));
      expect(text, contains('Ger allergener: inga'));
      expect(text, contains('Bryter koster: vegetarisk'));
    },
  );
}
