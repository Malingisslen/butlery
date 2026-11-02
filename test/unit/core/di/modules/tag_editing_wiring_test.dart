/// BUT-1508: `TaggingModule` hands the tag editor its allergen-correction log.
/// The log is fire-and-forget and a missing one is silent by design, so a
/// dropped hand-off would end the tagging feedback loop with nothing failing.
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';

import 'package:butlery/core/di/modules/tagging_module.dart';
import 'package:butlery/models/tagging/tag_decision.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/repositories/tag_overrides_log_repository.dart';
import 'package:butlery/services/tagging/tag_editing_service.dart';

import '../../../../infrastructure/builders/recipe_builder.dart';
import '../../../../infrastructure/di/test_service_locator.dart';
import '../../../../test_support/base_unit_test.dart';

void main() {
  late GetIt module;
  late FakeFirebaseFirestore logStore;

  setUp(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
    logStore = FakeFirebaseFirestore();
    final app = GetIt.instance;
    if (app.isRegistered<TagOverridesLogRepository>()) {
      await app.unregister<TagOverridesLogRepository>();
    }
    app.registerSingleton<TagOverridesLogRepository>(
      TagOverridesLogRepository(firestore: logStore),
    );
    module = GetIt.asNewInstance();
    await TaggingModule().configure(module);
  });

  tearDown(() async {
    await module.reset();
    await TestServiceLocator.reset();
    await BaseUnitTest.teardownUnit();
  });

  test('an allergen correction is written to the registered log', () async {
    final recipe = RecipeBuilder()
        .withId('recipe-7')
        .withTagResult(
          TagResult(
            tags: const {},
            allergenStatus: const {'gluten': TriState.contains},
            dietaryStatus: const {},
            coverage: 1.0,
            unknownIngredients: const [],
            generatorVersion: '3.0.0',
            generatedAt: DateTime.utc(2026, 11, 2),
            decisions: const [
              TagDecision(
                type: 'allergen',
                key: 'gluten',
                result: TriState.contains,
                reason: "Ingredient 'vetemjöl' has property 'gluten'",
                triggeringIngredients: ['vetemjöl'],
              ),
            ],
          ),
        )
        .build();

    final result = module<TagEditingService>().applyAllergenOverride(
      recipe: recipe,
      allergenKey: 'gluten',
      newStatus: TriState.free,
      editedBy: 'chef_anna',
      userConfirmed: true,
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(result.success, isTrue);
    final logged = await logStore
        .collection(TagOverridesLogRepository.collectionName)
        .get();
    expect(logged.docs, hasLength(1));
    final entry = logged.docs.single.data();
    expect(entry['userId'], 'chef_anna');
    expect(entry['recipeId'], 'recipe-7');
    expect(entry['tag'], 'gluten');
    expect(entry['direction'], 'contains->free');
    expect(entry['triggeringIngredients'], ['vetemjöl']);
  });
}
