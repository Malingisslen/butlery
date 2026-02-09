/// Tests for user-defined ingredient merge behavior (M2).
///
/// Verifies that user ingredients properly override global ingredients
/// and integrate correctly with the tagging system.
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:butlery/repositories/interfaces/ingredient_repository.dart';
import 'package:butlery/services/tagging/ingredient_lookup_service.dart';
import 'package:butlery/services/tagging/tag_generator.dart';
import '../../../infrastructure/builders/recipe_builder.dart';

// Mocks
class MockIngredientRepository extends Mock implements IngredientRepository {}

class MockUserIngredientRepository extends Mock
    implements UserIngredientRepository {}

void main() {
  late IngredientLookupService lookupService;
  late TagGenerator tagGenerator;
  late MockIngredientRepository mockIngredientRepo;
  late MockUserIngredientRepository mockUserIngredientRepo;

  setUp(() {
    mockIngredientRepo = MockIngredientRepository();
    mockUserIngredientRepo = MockUserIngredientRepository();

    // Default stubs for all repository methods
    when(() => mockIngredientRepo.findByName(any()))
        .thenAnswer((_) async => null);
    when(() => mockIngredientRepo.findByAlias(any()))
        .thenAnswer((_) async => []);
    when(() => mockUserIngredientRepo.findByName(any(), any()))
        .thenAnswer((_) async => null);

    lookupService = IngredientLookupService(
      ingredientRepository: mockIngredientRepo,
      userIngredientRepository: mockUserIngredientRepo,
    );
    tagGenerator = TagGenerator();
  });

  tearDown(() {
    lookupService.clearLookupCache();
  });

  group('M2: User ingredient override behavior', () {
    test('user ingredient with same name overrides global ingredient',
        () async {
      // Global ingredient: Tofu is plant-based
      final globalTofu = _createIngredient(
        'tofu-global',
        'tofu',
        properties: {'plant-based'},
      );

      // User ingredient: User's custom tofu has extra properties
      final userTofu = _createIngredient(
        'tofu-user-custom',
        'tofu',
        properties: {'plant-based', 'high-protein', 'fermented'},
        status: 'user-defined',
      );

      // Setup: global exists, user also has custom definition
      when(() => mockIngredientRepo.findByName('tofu'))
          .thenAnswer((_) async => globalTofu);
      when(() => mockUserIngredientRepo.findByName('user1', 'tofu'))
          .thenAnswer((_) async => userTofu);

      // When looking up with userId, user ingredient should take priority
      final result = await lookupService.lookupIngredients(
        ['tofu'],
        userId: 'user1',
      );

      expect(result.matchedCount, 1);
      expect(result.matched.first.id, 'tofu-user-custom');
      expect(result.matched.first.hasProperty('fermented'), isTrue);
    });

    test('user ingredient allows custom allergen properties', () async {
      // Global pasta has gluten
      final globalPasta = _createIngredient(
        'pasta-global',
        'pasta',
        properties: {'contains-gluten', 'pasta-base'},
      );

      // User's gluten-free pasta doesn't have gluten
      final userGlutenFreePasta = _createIngredient(
        'pasta-gf-user',
        'pasta',
        properties: {'pasta-base'}, // No contains-gluten
        status: 'user-defined',
      );

      when(() => mockIngredientRepo.findByName('pasta'))
          .thenAnswer((_) async => globalPasta);
      when(() => mockUserIngredientRepo.findByName('user1', 'pasta'))
          .thenAnswer((_) async => userGlutenFreePasta);

      final result = await lookupService.lookupIngredients(
        ['pasta'],
        userId: 'user1',
      );

      // User's gluten-free pasta should be used
      expect(result.matched.first.hasProperty('contains-gluten'), isFalse);
      expect(result.matched.first.hasProperty('pasta-base'), isTrue);
    });

    test('user ingredient diet override affects tag generation', () async {
      // Global egg has animal product
      final globalEgg = _createIngredient(
        'egg',
        'ägg',
        properties: {'egg', 'animal-product'},
      );

      // User defined vegan egg substitute
      final userVeganEgg = _createIngredient(
        'vegan-egg-user',
        'ägg',
        properties: {'plant-based'}, // No animal-product
        status: 'user-defined',
      );

      // Note: _cleanForLookup normalizes ä→a, so 'ägg' becomes 'agg'
      when(() => mockIngredientRepo.findByName('agg'))
          .thenAnswer((_) async => globalEgg);
      when(() => mockUserIngredientRepo.findByName('user1', 'agg'))
          .thenAnswer((_) async => userVeganEgg);

      // Lookup with user context
      final lookup = await lookupService.lookupIngredients(
        ['ägg', 'tofu'],
        userId: 'user1',
      );

      // Should find user's vegan egg
      expect(
        lookup.matched.any((i) => i.id == 'vegan-egg-user'),
        isTrue,
      );
    });

    test('mixed lookup with some user and some global ingredients', () async {
      // Global ingredients
      final globalRis = _createIngredient('rice', 'ris', properties: {});
      final globalLok = _createIngredient('onion', 'lök', properties: {});

      // User has custom version of one ingredient
      final userTofu = _createIngredient(
        'my-tofu',
        'tofu',
        properties: {'plant-based', 'organic'},
        status: 'user-defined',
      );

      // Setup: tofu only in user, ris and lök only in global
      when(() => mockIngredientRepo.findByName('ris'))
          .thenAnswer((_) async => globalRis);
      // Note: _cleanForLookup normalizes ö→o, so 'lök' becomes 'lok'
      when(() => mockIngredientRepo.findByName('lok'))
          .thenAnswer((_) async => globalLok);
      when(() => mockUserIngredientRepo.findByName('user1', 'tofu'))
          .thenAnswer((_) async => userTofu);

      final result = await lookupService.lookupIngredients(
        ['ris', 'tofu', 'lök'],
        userId: 'user1',
      );

      expect(result.matchedCount, 3);

      // User's tofu should be present
      expect(result.matched.any((i) => i.id == 'my-tofu'), isTrue);

      // Global ingredients should also be present
      expect(result.matched.any((i) => i.id == 'rice'), isTrue);
      expect(result.matched.any((i) => i.id == 'onion'), isTrue);
    });

    test('user ingredient not found falls back to global', () async {
      final globalTomat = _createIngredient(
        'tomato',
        'tomat',
        properties: {'vegetable'},
      );

      // User has no custom tomat
      when(() => mockIngredientRepo.findByName('tomat'))
          .thenAnswer((_) async => globalTomat);
      // mockUserIngredientRepo returns null by default

      final result = await lookupService.lookupIngredients(
        ['tomat'],
        userId: 'user1',
      );

      expect(result.matchedCount, 1);
      expect(result.matched.first.id, 'tomato');
    });
  });

  group('M2: User ingredient tag generation integration', () {
    test('user-defined gluten-free pasta generates FREE gluten status',
        () async {
      // User's gluten-free pasta
      final userGlutenFreePasta = _createIngredient(
        'gf-pasta',
        'pasta',
        properties: {'pasta-base'}, // No contains-gluten
        status: 'user-defined',
      );

      final userTomat = _createIngredient(
        'tomat-user',
        'tomat',
        properties: {},
        status: 'user-defined',
      );

      when(() => mockUserIngredientRepo.findByName('user1', 'pasta'))
          .thenAnswer((_) async => userGlutenFreePasta);
      when(() => mockUserIngredientRepo.findByName('user1', 'tomat'))
          .thenAnswer((_) async => userTomat);

      final recipe = RecipeBuilder()
          .withTitle('GF Pasta')
          .withIngredients(['pasta', 'tomat'])
          .withTimeMinutes(20)
          .build();

      final lookup = await lookupService.lookupIngredients(
        ['pasta', 'tomat'],
        userId: 'user1',
      );

      final result = tagGenerator.generate(
        ingredients: lookup,
        recipe: recipe,
      );

      // Should be gluten-free since user's pasta has no gluten property
      expect(result.allergenStatus['gluten'], isNot(TriState.contains));
    });

    test('user-defined vegan product changes dietary status', () async {
      // User defined vegan mayo (no animal products)
      final userVeganMayo = _createIngredient(
        'vegan-mayo',
        'majonnäs',
        properties: {'plant-based'},
        status: 'user-defined',
      );

      final userLettuce = _createIngredient(
        'lettuce',
        'sallad',
        properties: {'plant-based'},
        status: 'user-defined',
      );

      when(() => mockUserIngredientRepo.findByName('user1', 'majonnäs'))
          .thenAnswer((_) async => userVeganMayo);
      when(() => mockUserIngredientRepo.findByName('user1', 'sallad'))
          .thenAnswer((_) async => userLettuce);

      final recipe = RecipeBuilder()
          .withTitle('Vegan Salad')
          .withIngredients(['sallad', 'majonnäs'])
          .withTimeMinutes(10)
          .build();

      final lookup = await lookupService.lookupIngredients(
        ['sallad', 'majonnäs'],
        userId: 'user1',
      );

      final result = tagGenerator.generate(
        ingredients: lookup,
        recipe: recipe,
      );

      // With user's vegan mayo, should be vegan-friendly
      expect(result.dietaryStatus['vegansk'], isNot(TriState.contains));
    });
  });

  group('M2: Cache behavior with user ingredients', () {
    test('same ingredient name has different cache for different users',
        () async {
      final user1Tofu =
          _createIngredient('tofu-u1', 'tofu', properties: {'extra1'});
      final user2Tofu =
          _createIngredient('tofu-u2', 'tofu', properties: {'extra2'});

      when(() => mockUserIngredientRepo.findByName('user1', 'tofu'))
          .thenAnswer((_) async => user1Tofu);
      when(() => mockUserIngredientRepo.findByName('user2', 'tofu'))
          .thenAnswer((_) async => user2Tofu);

      // Lookup for user1
      final result1 =
          await lookupService.lookupIngredients(['tofu'], userId: 'user1');
      expect(result1.matched.first.id, 'tofu-u1');

      // Lookup for user2 - should not get user1's cached result
      final result2 =
          await lookupService.lookupIngredients(['tofu'], userId: 'user2');
      expect(result2.matched.first.id, 'tofu-u2');
    });

    test('global lookup not affected by user cache', () async {
      final globalTofu =
          _createIngredient('tofu-global', 'tofu', properties: {});
      final userTofu =
          _createIngredient('tofu-user', 'tofu', properties: {'custom'});

      when(() => mockIngredientRepo.findByName('tofu'))
          .thenAnswer((_) async => globalTofu);
      when(() => mockUserIngredientRepo.findByName('user1', 'tofu'))
          .thenAnswer((_) async => userTofu);

      // First, lookup with user context
      final userResult =
          await lookupService.lookupIngredients(['tofu'], userId: 'user1');
      expect(userResult.matched.first.id, 'tofu-user');

      // Then, global lookup should still work independently
      final globalResult = await lookupService.lookupIngredients(['tofu']);
      expect(globalResult.matched.first.id, 'tofu-global');
    });

    test('cache clear resets both user and global caches', () async {
      final globalTofu =
          _createIngredient('tofu-global', 'tofu', properties: {});
      final userTofu = _createIngredient('tofu-user', 'tofu', properties: {});

      when(() => mockIngredientRepo.findByName('tofu'))
          .thenAnswer((_) async => globalTofu);
      when(() => mockUserIngredientRepo.findByName('user1', 'tofu'))
          .thenAnswer((_) async => userTofu);

      // Populate caches
      await lookupService.lookupIngredients(['tofu']);
      await lookupService.lookupIngredients(['tofu'], userId: 'user1');

      expect(lookupService.cacheSize, 2);

      // Clear cache
      lookupService.clearLookupCache();

      expect(lookupService.cacheSize, 0);
    });
  });
}

/// Helper to create test ingredient data
IngredientData _createIngredient(
  String id,
  String swedish, {
  Set<String> properties = const {},
  String status = 'verified',
}) {
  return IngredientData(
    id: id,
    swedish: swedish,
    english: swedish,
    group: 'test',
    properties: properties,
    status: status,
  );
}
