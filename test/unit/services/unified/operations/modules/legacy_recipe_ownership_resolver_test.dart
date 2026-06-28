/// Direct unit tests for [LegacyRecipeOwnershipResolver] (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Decides who owns a recipe when ownership metadata is missing — the
/// fallback that gates whether a legacy recipe can be deleted/edited. Pure
/// logic over a Recipe; the tests build recipes via RecipeFactory with fixed
/// dates (no real clock) and assert each branch: standard ownership wins,
/// legacy detection, and the inference ladder (collection → admin-override →
/// orphan cleanup → give up).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/operations/modules/legacy_recipe_ownership_resolver.dart';

import '../../../../../infrastructure/factories/recipe_factory.dart';

// Fixed reference dates (no real-clock reads — keeps the flaky-time guard happy).
final _recent = DateTime(2023, 1, 1);
final _old = DateTime(2020, 1, 1); // before every legacy threshold

void main() {
  final resolver = LegacyRecipeOwnershipResolver();

  group('determineOwnership', () {
    test('returns the social-data owner when present', () {
      final recipe = RecipeFactory.build(
        socialData: const RecipeSocialData(ownerId: 'owner1'),
        createdAt: _recent,
      );
      expect(resolver.determineOwnership(recipe, 'me'), 'owner1');
    });

    test('falls back to createdBy when there is no social owner', () {
      final recipe = RecipeFactory.build(
        createdBy: 'creator1',
        createdAt: _recent,
      );
      expect(resolver.determineOwnership(recipe, 'me'), 'creator1');
    });

    test('infers the current user for a legacy personal recipe', () {
      final recipe = RecipeFactory.build(
        createdBy: '', // empty → legacy + no standard owner
        createdAt: _old,
      ); // defaults to RecipeType.personal
      expect(resolver.determineOwnership(recipe, 'me'), 'me');
    });
  });

  group('isLegacyRecipe', () {
    test('true when there is no social data', () {
      final recipe = RecipeFactory.build(createdBy: 'x', createdAt: _recent);
      expect(resolver.isLegacyRecipe(recipe), isTrue);
    });

    test('true when createdBy is empty', () {
      final recipe = RecipeFactory.build(
        createdBy: '',
        socialData: const RecipeSocialData(ownerId: 'o'),
        createdAt: _recent,
      );
      expect(resolver.isLegacyRecipe(recipe), isTrue);
    });

    test('true when the recipe predates the legacy cutoff', () {
      final recipe = RecipeFactory.build(
        createdBy: 'x',
        socialData: const RecipeSocialData(ownerId: 'o'),
        createdAt: DateTime(2022, 1, 1), // before 2022-06-01
      );
      expect(resolver.isLegacyRecipe(recipe), isTrue);
    });

    test('false for a recent recipe with full ownership data', () {
      final recipe = RecipeFactory.build(
        createdBy: 'x',
        socialData: const RecipeSocialData(ownerId: 'o'),
        createdAt: _recent,
      );
      expect(resolver.isLegacyRecipe(recipe), isFalse);
    });
  });

  group('isRecipeInUserCollection', () {
    test('personal recipes are assumed to be in the user collection', () {
      final recipe = RecipeFactory.build(createdAt: _recent); // personal
      expect(resolver.isRecipeInUserCollection(recipe, 'zzz'), isTrue);
    });

    test('non-personal recipe whose id contains the user id', () {
      final recipe = RecipeFactory.build(
        id: 'recipe_zzz_1',
        type: RecipeType.shared,
        createdAt: _recent,
      );
      expect(resolver.isRecipeInUserCollection(recipe, 'zzz'), isTrue);
    });

    test('non-personal recipe whose images live under the user path', () {
      final recipe = RecipeFactory.build(
        id: 'abcdef123456',
        type: RecipeType.shared,
        imageUrls: ['https://store/zzz/photo.jpg'],
        createdAt: _recent,
      );
      expect(resolver.isRecipeInUserCollection(recipe, 'zzz'), isTrue);
    });

    test(
      'non-personal recipe with no user signal is not in the collection',
      () {
        final recipe = RecipeFactory.build(
          id: 'abcdef123456',
          type: RecipeType.shared,
          imageUrls: const [],
          createdAt: _recent,
        );
        expect(resolver.isRecipeInUserCollection(recipe, 'zzz'), isFalse);
      },
    );
  });

  group('age + override predicates', () {
    test('isVeryOldRecipe is true only before the 2021-12-31 cutoff', () {
      expect(
        resolver.isVeryOldRecipe(RecipeFactory.build(createdAt: _old)),
        isTrue,
      );
      expect(
        resolver.isVeryOldRecipe(RecipeFactory.build(createdAt: _recent)),
        isFalse,
      );
    });

    test('hasAdminOverride is true for any non-empty user id', () {
      expect(resolver.hasAdminOverride('me'), isTrue);
      expect(resolver.hasAdminOverride(''), isFalse);
    });
  });

  group('isOrphanedLegacyRecipe', () {
    test('true: no owner, very old, and minimal/corrupt data', () {
      final recipe = RecipeFactory.build(
        id: 'short', // < 10 chars → corrupted id
        title: 'ab', // < 3 chars → minimal data
        createdBy: '',
        createdAt: _old,
      );
      expect(resolver.isOrphanedLegacyRecipe(recipe), isTrue);
    });

    test('false when the recipe still has ownership data', () {
      final recipe = RecipeFactory.build(
        id: 'short',
        title: 'ab',
        createdBy: 'someone',
        createdAt: _old,
      );
      expect(resolver.isOrphanedLegacyRecipe(recipe), isFalse);
    });

    test('false when the data is complete (normal title + id)', () {
      final recipe = RecipeFactory.build(
        id: 'recipe_1234567890',
        title: 'A Proper Title',
        createdBy: '',
        createdAt: _old,
      );
      expect(resolver.isOrphanedLegacyRecipe(recipe), isFalse);
    });
  });

  group('inferLegacyOwnership ladder', () {
    test('admin override grants ownership of a very old shared recipe', () {
      final recipe = RecipeFactory.build(
        id: 'recipe_no_match',
        title: 'Normal',
        type: RecipeType.shared,
        createdBy:
            'x', // non-empty → not orphaned, isolates the override branch
        createdAt: _old,
      );
      expect(resolver.inferLegacyOwnership(recipe, 'me'), 'me');
    });

    test('gives up (null) for a recent shared recipe with no signal', () {
      final recipe = RecipeFactory.build(
        id: 'recipe_xyz_long',
        title: 'Normal Title',
        type: RecipeType.shared,
        createdBy: 'x',
        createdAt: _recent,
      );
      expect(resolver.inferLegacyOwnership(recipe, 'me'), isNull);
    });
  });
}
