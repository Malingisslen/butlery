// Q6-08 = A: who the signed-in user is to a recipe, for the recipe detail
// menu (produktregler.md:243-251). The role comes from the recipe's owner id
// and member map only.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/views/recipe_detail/recipe_menu_role.dart';

import '../../infrastructure/factories/recipe_factory.dart';

void main() {
  const me = 'me';
  const olle = 'olle';

  Recipe recipe({
    String? createdBy,
    String? ownerId,
    Map<String, ResourcePermission>? members,
  }) => RecipeFactory.build(
    id: 'r1',
    createdBy: createdBy,
    socialData: ownerId == null && members == null
        ? null
        : RecipeSocialData(ownerId: ownerId, memberPermissions: members),
  );

  test('my own recipe', () {
    expect(recipeMenuRole(recipe(createdBy: me), me), RecipeMenuRole.owner);
  });

  test('a local recipe with no owner is mine', () {
    expect(recipeMenuRole(recipe(createdBy: ''), me), RecipeMenuRole.owner);
  });

  test('the owner id wins over createdBy', () {
    expect(
      recipeMenuRole(recipe(createdBy: olle, ownerId: me), me),
      RecipeMenuRole.owner,
    );
  });

  test('a member of someone else\'s shared recipe, whatever the role', () {
    for (final role in [ResourcePermission.editor, ResourcePermission.viewer]) {
      expect(
        recipeMenuRole(
          recipe(createdBy: olle, ownerId: olle, members: {me: role}),
          me,
        ),
        RecipeMenuRole.member,
      );
    }
  });

  test('someone else\'s recipe not shared with me', () {
    expect(
      recipeMenuRole(
        recipe(
          createdBy: olle,
          ownerId: olle,
          members: {'mia': ResourcePermission.editor},
        ),
        me,
      ),
      RecipeMenuRole.other,
    );
    expect(recipeMenuRole(recipe(createdBy: olle), me), RecipeMenuRole.other);
  });

  test('signed out, someone else\'s recipe is never mine to edit', () {
    expect(
      recipeMenuRole(
        recipe(
          createdBy: olle,
          ownerId: olle,
          members: {me: ResourcePermission.editor},
        ),
        null,
      ),
      RecipeMenuRole.other,
    );
  });
}
