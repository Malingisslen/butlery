/// BUT-2107: `asResource` names the recipe's owner by `Recipe.ownerUid`, so an
/// EMPTY `socialData.ownerId` or `createdBy` counts as missing and the next
/// source takes over; the old `??` chain stopped at '' and the banner owner
/// became an empty uid.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/realtime/queued_recipe_conflicts.dart';

const _me = 'user_me';

Recipe _recipe({String? createdBy = _me, String? ownerId = ''}) => Recipe(
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
  type: RecipeType.personal,
  socialData: ownerId == null ? null : RecipeSocialData(ownerId: ownerId),
);

void main() {
  group('QueuedRecipeConflicts.asResource owner', () {
    test('an empty ownerId falls back to the creator', () {
      final resource = QueuedRecipeConflicts.asResource(_recipe(), 'fallback');
      expect(resource.ownerId, _me);
      expect(resource.participants, {_me: ResourcePermission.owner});
      expect(resource.lastEditedBy, _me);
    });

    test('the fallback owner is used when the recipe names none', () {
      final resource = QueuedRecipeConflicts.asResource(
        _recipe(createdBy: '', ownerId: null),
        'fallback',
      );
      expect(resource.ownerId, 'fallback');
      expect(resource.participants, {'fallback': ResourcePermission.owner});
    });

    test('the fallback owner is used when both fields are empty', () {
      final resource = QueuedRecipeConflicts.asResource(
        _recipe(createdBy: ''),
        'fallback',
      );
      expect(resource.ownerId, 'fallback');
    });

    test('closing: nothing names an owner, so the owner is empty', () {
      final resource = QueuedRecipeConflicts.asResource(
        _recipe(createdBy: '', ownerId: null),
        null,
      );
      expect(resource.ownerId, '');
    });

    test('closing: a real ownerId wins over creator and fallback', () {
      final resource = QueuedRecipeConflicts.asResource(
        _recipe(ownerId: 'owner_1'),
        'fallback',
      );
      expect(resource.ownerId, 'owner_1');
    });
  });
}
