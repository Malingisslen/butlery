/// BUT-2107: a collaborative recipe whose `socialData.ownerId` is '' and whose
/// `createdBy` is the signed-in user is that user's own recipe.
///
/// A plain `socialData?.ownerId ?? createdBy` stops at '', which then reads as
/// a real uid that matches nobody, so the creator was neither allowed to
/// comment nor treated as owner when moderating comments.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/operations/modules/comment_utilities.dart';

const _me = 'user_me';

Recipe _recipe({String? createdBy = _me, String ownerId = ''}) => Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Gryta',
    description: 'd',
    ingredients: const ['i'],
    instructions: const ['s'],
    mealType: 'Middag',
    createdBy: createdBy,
    createdAt: DateTime(2026, 10, 8),
    updatedAt: DateTime(2026, 10, 8),
  ),
  type: RecipeType.collaborative,
  socialData: RecipeSocialData(
    ownerId: ownerId,
    memberPermissions: {'user_viewer': ResourcePermission.viewer},
  ),
);

void main() {
  group('canCommentOnRecipe', () {
    test('the creator may comment when ownerId is empty', () {
      expect(
        CommentUtilities.canCommentOnRecipe(
          recipe: _recipe(),
          currentUserId: _me,
        ),
        isTrue,
      );
    });

    test('closing: someone else created it and I am not a member', () {
      expect(
        CommentUtilities.canCommentOnRecipe(
          recipe: _recipe(createdBy: 'stranger'),
          currentUserId: _me,
        ),
        isFalse,
      );
    });

    test('closing: both fields are empty', () {
      expect(
        CommentUtilities.canCommentOnRecipe(
          recipe: _recipe(createdBy: ''),
          currentUserId: _me,
        ),
        isFalse,
      );
    });
  });

  group('isRecipeOwnerOrAdmin', () {
    test('the creator counts as owner when ownerId is empty', () {
      expect(
        CommentUtilities.isRecipeOwnerOrAdmin(
          recipe: _recipe(),
          currentUserId: _me,
        ),
        isTrue,
      );
    });

    test('closing: someone else created it and I hold no admin right', () {
      expect(
        CommentUtilities.isRecipeOwnerOrAdmin(
          recipe: _recipe(createdBy: 'stranger'),
          currentUserId: _me,
        ),
        isFalse,
      );
    });

    test('closing: both fields are empty', () {
      expect(
        CommentUtilities.isRecipeOwnerOrAdmin(
          recipe: _recipe(createdBy: ''),
          currentUserId: _me,
        ),
        isFalse,
      );
    });
  });
}
