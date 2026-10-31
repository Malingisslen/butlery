/// BUT-2107: a collaborative recipe whose `socialData.ownerId` is '' and whose
/// `createdBy` is the signed-in user is that user's own recipe.
///
/// A plain `socialData?.ownerId ?? createdBy` stops at '', which then reads as
/// a real uid that matches nobody, so discovery listed the creator's own
/// recipe as nobody's and, through `getRecipesByUser(userId: '')`, as the
/// property of the empty string.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/operations/modules/recipe_discovery_service.dart';

const _me = 'user_me';
final _created = DateTime(2026, 10, 8);

Recipe _recipe({
  String id = 'r1',
  String? createdBy = _me,
  String ownerId = '',
  RecipeType type = RecipeType.collaborative,
  Map<String, ResourcePermission> members = const {
    'user_viewer': ResourcePermission.viewer,
  },
}) => Recipe(
  core: RecipeCore(
    id: id,
    title: 'Gryta',
    description: 'd',
    ingredients: const ['i'],
    instructions: const ['s'],
    mealType: 'Middag',
    createdBy: createdBy,
    createdAt: _created,
    updatedAt: _created,
  ),
  type: type,
  socialData: RecipeSocialData(ownerId: ownerId, memberPermissions: members),
);

RecipeDiscoveryService _service(List<Recipe> recipes) => RecipeDiscoveryService(
  getCurrentUserId: () => _me,
  getRecipes: () => recipes,
);

List<String> _ids(List<Recipe> recipes) => recipes.map((r) => r.id).toList();

void main() {
  group('getCollaborativeRecipes', () {
    test('the creator finds their recipe when ownerId is empty', () async {
      final result = await _service([_recipe()]).getCollaborativeRecipes();
      expect(_ids(result), ['r1']);
    });

    test('closing: someone else created it and I am not a member', () async {
      final result = await _service([
        _recipe(createdBy: 'stranger'),
      ]).getCollaborativeRecipes();
      expect(result, isEmpty);
    });

    test('closing: both fields are empty', () async {
      final result = await _service([
        _recipe(createdBy: ''),
      ]).getCollaborativeRecipes();
      expect(result, isEmpty);
    });
  });

  group('getSharedWithMe', () {
    test(
      'a recipe I created is not shared with me, even as a member',
      () async {
        final result = await _service([
          _recipe(members: {_me: ResourcePermission.viewer}),
        ]).getSharedWithMe();
        expect(result, isEmpty);
      },
    );

    test(
      'closing: another creator with me as member is shared with me',
      () async {
        final result = await _service([
          _recipe(
            createdBy: 'stranger',
            members: {_me: ResourcePermission.viewer},
          ),
        ]).getSharedWithMe();
        expect(_ids(result), ['r1']);
      },
    );

    test(
      'closing: both fields empty with me as member is shared with me',
      () async {
        final result = await _service([
          _recipe(createdBy: '', members: {_me: ResourcePermission.viewer}),
        ]).getSharedWithMe();
        expect(_ids(result), ['r1']);
      },
    );
  });

  group('getSharedByMe', () {
    test(
      'the creator finds their shared recipe when ownerId is empty',
      () async {
        final result = await _service([_recipe()]).getSharedByMe();
        expect(_ids(result), ['r1']);
      },
    );

    test('closing: someone else created it', () async {
      final result = await _service([
        _recipe(createdBy: 'stranger'),
      ]).getSharedByMe();
      expect(result, isEmpty);
    });

    test('closing: both fields are empty', () async {
      final result = await _service([_recipe(createdBy: '')]).getSharedByMe();
      expect(result, isEmpty);
    });
  });

  group('getRecipesByUser', () {
    test(
      'the creator is found by their own uid when ownerId is empty',
      () async {
        final result = await _service([
          _recipe(),
        ]).getRecipesByUser(userId: _me);
        expect(_ids(result), ['r1']);
      },
    );

    test(
      'an empty userId owns nothing, even for a recipe with empty owners',
      () async {
        final result = await _service([
          _recipe(createdBy: '', members: {_me: ResourcePermission.viewer}),
        ]).getRecipesByUser(userId: '');
        expect(result, isEmpty);
      },
    );

    test('closing: another creator is not found by my uid', () async {
      final result = await _service([
        _recipe(createdBy: 'stranger'),
      ]).getRecipesByUser(userId: _me);
      expect(result, isEmpty);
    });
  });

  group('getRecentlySharedRecipes', () {
    Future<List<Recipe>> run(List<Recipe> recipes) => withClock(
      Clock.fixed(_created.add(const Duration(days: 1))),
      () => _service(recipes).getRecentlySharedRecipes(),
    );

    test('the creator sees their recipe when ownerId is empty', () async {
      expect(_ids(await run([_recipe()])), ['r1']);
    });

    test('closing: someone else created it and I am not a member', () async {
      expect(await run([_recipe(createdBy: 'stranger')]), isEmpty);
    });

    test('closing: both fields are empty', () async {
      expect(await run([_recipe(createdBy: '')]), isEmpty);
    });
  });

  group('getDiscoveryStatistics', () {
    test('the creator counts the recipe as owned when ownerId is empty', () {
      final stats = _service([_recipe()]).getDiscoveryStatistics();
      expect(stats['owned_collaborative'], 1);
      expect(stats['total_members_in_owned_recipes'], 1);
    });

    test('closing: someone else created it', () {
      final stats = _service([
        _recipe(createdBy: 'stranger'),
      ]).getDiscoveryStatistics();
      expect(stats['owned_collaborative'], 0);
    });

    test('closing: both fields are empty', () {
      final stats = _service([
        _recipe(createdBy: ''),
      ]).getDiscoveryStatistics();
      expect(stats['owned_collaborative'], 0);
    });
  });
}
