/// Q6-08 = A (produktbeslut 2026-09-27): who the signed-in user is to a
/// recipe, for the recipe detail menu ("Kebabmenyn
/// per behörighet").
///
/// - [RecipeMenuRole.owner] edits: "Redigera", and the owner-only rows.
/// - [RecipeMenuRole.other], anyone else, gets neither.
///
/// A pure predicate so the view and its test share one rule. Identity comes
/// from [Recipe.ownerUid] and the uid keys of
/// socialData.memberPermissions (the map firestore.rules grants shared
/// reads on), never from anything the screen shows.
library;

import 'package:butlery/models/recipe/recipe_ownership.dart';
import 'package:butlery/models/recipe_unified.dart';

enum RecipeMenuRole { owner, member, other }

RecipeMenuRole recipeMenuRole(Recipe recipe, String? currentUserId) {
  final ownerId = recipe.ownerUid;
  // A local recipe with no owner is the user's own (as showForkInOverflow).
  if (ownerId == null || ownerId.isEmpty || ownerId == currentUserId) {
    return RecipeMenuRole.owner;
  }
  if (currentUserId != null &&
      currentUserId.isNotEmpty &&
      (recipe.socialData?.memberPermissions?.containsKey(currentUserId) ??
          false)) {
    return RecipeMenuRole.member;
  }
  return RecipeMenuRole.other;
}
