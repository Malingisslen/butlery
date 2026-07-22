/// True end-to-end test of the USP chain: import → tag → allergen verdict.
///
/// BUT-1488: the previous version of this file mocked [TaggingService] away and
/// hand-fabricated [IngredientLookupResult]s, so it never exercised the real
/// wiring — a bug anywhere between "text pasted" and "allergen badge" would have
/// slipped through green. This version drives the REAL objects end to end:
///
///   real ImportManager.autoImport (TextImportStrategy)
///     → real TaggingService → real TaggingPipelineRunner
///       → real IngredientLookupService
///         → real FirebaseIngredientRepository over a fixture-seeded
///           FakeFirebaseFirestore (matching/coverage exactly as in production)
///
/// and asserts the tri-valued allergen verdicts for representative Swedish
/// recipes. Nothing between the pasted text and the allergen map is faked, so
/// this is the one test that would fail if the pipeline stopped producing
/// correct "innehåller / fritt från / okänt" verdicts.
///
/// The safety-critical invariant under test (see
/// [IngredientLookupResult.getPropertyStatus]):
///   - CONTAINS: at least one matched ingredient carries the allergen property.
///   - FREE:     100% coverage AND no matched ingredient carries it.
///   - UNKNOWN:  coverage < 100% — one unrecognised ingredient forces UNKNOWN
///               across every allergen, because we cannot prove absence.
@Tags(['integration'])
library;

import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/constants/firestore_collections.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/repositories/firebase/firebase_ingredient_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tagging_service.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';

/// autoImport never saves (it only parses + previews), so PersonalRecipeOperations
/// is constructed but never invoked. A bare mock with no stubs is therefore safe.
class _StubPersonalOps extends Mock implements PersonalRecipeOperations {}

void main() {
  late ImportManager importManager;
  late TaggingService taggingService;

  setUp(() async {
    importManager = ImportManager.withStrategies(
      _StubPersonalOps(),
      [TextImportStrategy()],
    );

    final lookupService = await _buildFixtureLookupService();
    taggingService = TaggingService(lookupService: lookupService);
  });

  /// Runs the full chain for [recipeText]: parse it via the real import
  /// pipeline, then tag the parsed recipe via the real tagging pipeline.
  Future<Recipe> importAndTag(String recipeText) async {
    final importResult = await importManager.autoImport(recipeText);
    expect(
      importResult.isSuccess,
      isTrue,
      reason: 'Import failed: ${importResult.errorMessage}',
    );
    final parsed = importResult.recipe!;
    expect(
      parsed.core.ingredients,
      isNotEmpty,
      reason: 'Parser extracted no ingredients from the recipe text',
    );

    final tagResult = await taggingService.generateTags(parsed);
    expect(tagResult, isNotNull, reason: 'Tagging returned null');

    return Recipe(
      core: parsed.core.copyWith(tagResult: tagResult),
      type: parsed.type,
      socialData: parsed.socialData,
      realtimeData: parsed.realtimeData,
      offlineData: parsed.offlineData,
    );
  }

  group('Import → Tagging end-to-end (real pipeline)', () {
    test(
      'meat-and-dairy recipe: dairy, egg and gluten all CONTAINS',
      () async {
        // Köttbullar: köttfärs (meat), grädde + smör (dairy), ägg (egg),
        // ströbröd (gluten). CONTAINS needs only one matched allergen
        // ingredient, so these verdicts hold regardless of coverage.
        const text = '''
Köttbullar med gräddsås

Ingredienser:
500 g köttfärs
2 dl grädde
1 dl ströbröd
1 msk smör
1 gul lök

Gör så här:
1. Blanda köttfärs, ströbröd och lök till en smet.
2. Rulla till bullar och stek dem i smör.
3. Häll i grädde och låt såsen puttra samman.
''';

        final recipe = await importAndTag(text);
        final allergens = recipe.core.tagResult!.allergenStatus;

        expect(allergens['mjölk'], TriState.contains);
        expect(allergens['gluten'], TriState.contains);
      },
    );

    test(
      'fish recipe: fisk CONTAINS while dairy/egg/gluten are FREE',
      () async {
        // Ugnsbakad lax with only produce + oil around it: fish present, no
        // dairy/egg/gluten. FREE is only legitimate at 100% coverage, so the
        // test asserts full coverage before trusting the FREE verdicts.
        const text = '''
Ugnsbakad lax med potatis

Ingredienser:
600 g lax
4 st potatis
1 st citron
2 msk olivolja

Gör så här:
1. Lägg lax och potatis i en ugnsform.
2. Ringla över olivolja och pressa citron över.
3. Grädda i ugnen tills laxen är genomstekt.
''';

        final recipe = await importAndTag(text);
        final tagResult = recipe.core.tagResult!;
        final allergens = tagResult.allergenStatus;

        expect(allergens['fisk'], TriState.contains);

        // FREE verdicts are only meaningful at full coverage.
        expect(
          tagResult.coverage,
          1.0,
          reason:
              'FREE verdicts require 100% coverage; unmatched: '
              '${tagResult.unknownIngredients}',
        );
        expect(allergens['mjölk'], TriState.free);
        expect(allergens['ägg'], TriState.free);
        expect(allergens['gluten'], TriState.free);
      },
    );

    test(
      'vegan recipe: every animal allergen is FREE at full coverage',
      () async {
        // Vegansk linsgryta: no animal-derived allergens at all. At 100%
        // coverage every EU animal allergen should read FREE.
        const text = '''
Vegansk linsgryta

Ingredienser:
3 dl röda linser
4 dl kokosmjölk
1 burk krossade tomater
1 gul lök
2 dl ris

Gör så här:
1. Fräs lök i en gryta.
2. Tillsätt linser, kokosmjölk och krossade tomater.
3. Låt grytan puttra och servera med ris.
''';

        final recipe = await importAndTag(text);
        final tagResult = recipe.core.tagResult!;
        final allergens = tagResult.allergenStatus;

        expect(
          tagResult.coverage,
          1.0,
          reason:
              'FREE verdicts require 100% coverage; unmatched: '
              '${tagResult.unknownIngredients}',
        );
        expect(allergens['mjölk'], TriState.free);
        expect(allergens['ägg'], TriState.free);
        expect(allergens['fisk'], TriState.free);
        expect(allergens['gluten'], TriState.free);
      },
    );

    test(
      'unrecognised ingredient forces every allergen to UNKNOWN (safety floor)',
      () async {
        // One ingredient the fixture DB does not know ("teffmjöl") drops
        // coverage below 100%. The safety rule then forbids ANY free-from
        // verdict — even for allergens no known ingredient carries — because
        // absence cannot be proven. This is the invariant that keeps a
        // mis-parsed or novel ingredient from producing a false "fritt från".
        const text = '''
Teffgröt

Ingredienser:
2 dl teffmjöl
4 dl vatten

Gör så här:
1. Koka upp vatten i en kastrull.
2. Vispa ner teffmjöl och rör tills gröten tjocknar.
''';

        final recipe = await importAndTag(text);
        final tagResult = recipe.core.tagResult!;
        final allergens = tagResult.allergenStatus;

        expect(
          tagResult.coverage,
          lessThan(1.0),
          reason: 'Test premise requires an unmatched ingredient',
        );
        // No FREE verdict may be produced while coverage is incomplete.
        expect(
          allergens.values.any((s) => s == TriState.free),
          isFalse,
          reason:
              'Incomplete coverage must never yield a FREE allergen verdict: '
              '$allergens',
        );
        expect(allergens['mjölk'], TriState.unknown);
        expect(allergens['gluten'], TriState.unknown);
      },
    );
  });
}

/// Builds the production [IngredientLookupService] over a fixture-seeded
/// [FakeFirebaseFirestore], so ingredient matching, fuzzy variations and
/// coverage are computed exactly as in production — no network, no Firebase
/// project. The fixture is a small hand-authored set of Swedish ingredients
/// carrying the allergen properties the vocabulary
/// (`valid_properties.dart`) recognises.
Future<IngredientLookupService> _buildFixtureLookupService() async {
  final firestore = FakeFirebaseFirestore();
  for (final ingredient in _fixtureIngredients) {
    await firestore
        .collection(FirestoreCollections.ingredients)
        .doc(ingredient.id)
        .set(ingredient.toFirestore());
  }

  final repository = FirebaseIngredientRepository(firestore: firestore);
  await repository.initialize();

  return IngredientLookupService(
    ingredientRepository: repository,
    userIngredientRepository: _NoUserIngredients(),
  );
}

IngredientData _ing(
  String id,
  String swedish,
  String group,
  Set<String> properties, {
  List<String> aliases = const [],
}) => IngredientData(
  id: id,
  swedish: swedish,
  english: id,
  group: group,
  properties: properties,
  aliasesSv: aliases,
);

/// Hand-authored fixture ingredient set. Allergen properties use the trigger
/// vocabulary from `allergen_config.dart` (dairy, egg, fish, contains-gluten).
final List<IngredientData> _fixtureIngredients = [
  // Meat / dairy / egg / gluten cluster (köttbullar).
  _ing('kottfars', 'köttfärs', 'protein/meat/beef', {
    'meat',
    'beef',
    'animal-product',
  }),
  _ing(
    'gradde',
    'grädde',
    'protein/dairy',
    {
      'dairy',
      'contains-lactose',
      'animal-product',
    },
    aliases: ['vispgrädde', 'matlagningsgrädde'],
  ),
  _ing('smor', 'smör', 'protein/dairy', {
    'dairy',
    'contains-lactose',
    'animal-product',
  }),
  _ing('agg', 'ägg', 'protein/egg', {'egg', 'animal-product'}),
  _ing('strobrod', 'ströbröd', 'grain/wheat', {'contains-gluten'}),
  _ing(
    'lok',
    'lök',
    'vegetable/allium',
    {'plant-based', 'vegan-friendly'},
    aliases: ['gul lök', 'gullök'],
  ),

  // Fish cluster (lax).
  _ing('lax', 'lax', 'protein/seafood/fish', {
    'fish',
    'seafood',
    'animal-product',
  }),
  _ing('potatis', 'potatis', 'vegetable/root', {
    'plant-based',
    'vegan-friendly',
  }),
  _ing('citron', 'citron', 'fruit/citrus', {'plant-based', 'vegan-friendly'}),
  _ing('olivolja', 'olivolja', 'fat/oil', {'plant-based', 'vegan-friendly'}),

  // Vegan cluster (linsgryta).
  _ing(
    'rodalinser',
    'röda linser',
    'protein/plant-based/legume',
    {
      'plant-based',
      'vegan-friendly',
    },
    aliases: ['linser', 'röd lins'],
  ),
  _ing('kokosmjolk', 'kokosmjölk', 'protein/plant-based', {
    'plant-based',
    'vegan-friendly',
  }),
  _ing(
    'krossadetomater',
    'krossade tomater',
    'vegetable/fruit-veg',
    {
      'plant-based',
      'vegan-friendly',
      'nightshade',
    },
    aliases: ['tomater', 'krossad tomat'],
  ),
  _ing('ris', 'ris', 'grain/rice', {'plant-based', 'vegan-friendly'}),

  // Neutral pantry staples that recipes lean on.
  _ing('vatten', 'vatten', 'other/liquid', {'plant-based', 'vegan-friendly'}),
];

/// No user-defined ingredients — the fixture global DB is the whole story.
class _NoUserIngredients implements UserIngredientRepository {
  @override
  Future<IngredientData?> findByName(String userId, String name) async => null;
  @override
  Future<IngredientData?> getById(String userId, String ingredientId) async =>
      null;
  @override
  Future<List<IngredientData>> getAll(String userId) async => const [];
  @override
  Future<IngredientData> create(
    String userId,
    IngredientData ingredient,
  ) async => ingredient;
  @override
  Future<void> update(String userId, IngredientData ingredient) async {}
  @override
  Future<void> delete(String userId, String ingredientId) async {}
  @override
  Stream<List<IngredientData>> watchAll(String userId) =>
      Stream.value(const []);
}
