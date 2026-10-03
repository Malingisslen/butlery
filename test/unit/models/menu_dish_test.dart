/// BUT-2214: a dish stored in a menu other people read keeps the recipe's
/// core and nothing that names a person or carries the owner's private tags.
library;

import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/realtime_menu_data.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/tagging/tag_result.dart';
import 'package:butlery/models/tagging/tri_state.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../infrastructure/factories/recipe_factory.dart';

final _at = DateTime.utc(2026, 10, 3, 9);

/// A recipe shared with others and edited live: every block that can carry a
/// person's name or the owner's tags is filled in.
Recipe _sharedRecipe(String id) =>
    RecipeFactory.build(
      id: id,
      title: 'Linsgryta $id',
      createdBy: 'owner-uid',
      createdAt: _at,
      updatedAt: _at,
      personalTagIds: const ['barnens-favoriter'],
      type: RecipeType.collaborative,
      socialData: RecipeSocialData(
        ownerId: 'owner-uid',
        ownerDisplayName: 'Olle',
        memberPermissions: const {'friend-uid': ResourcePermission.editor},
        allowGuestViewing: false,
        allowMemberInvites: false,
      ),
      realtimeData: RecipeRealtimeData(
        lastEditedByUserId: 'friend-uid',
        lastEditedByDisplayName: 'Frida',
        lastEditedAt: _at,
      ),
    ).copyWith(
      tagResult: TagResult(
        tags: {'vegetarisk'},
        allergenStatus: {'gluten': TriState.free},
        dietaryStatus: {'vegetarisk': TriState.free},
        coverage: 1.0,
        unknownIngredients: const [],
        generatedAt: _at,
        generatorVersion: '1.0.0',
      ),
    );

/// Every key path under [node] whose key ends in `DisplayName`.
Set<String> _names(Object? node, [String path = '']) {
  final found = <String>{};
  if (node is Map) {
    node.forEach((k, v) {
      final here = path.isEmpty ? '$k' : '$path.$k';
      if ('$k'.endsWith('DisplayName')) found.add(here);
      found.addAll(_names(v, here));
    });
  } else if (node is List) {
    for (final v in node) {
      found.addAll(_names(v, '$path[]'));
    }
  }
  return found;
}

void main() {
  test('a menu dish is the core, without names or personal tags', () {
    final recipe = _sharedRecipe('d1');
    // Premise: the whole recipe does carry what the dish must not.
    expect(_names(recipe.toFirestore()), isNotEmpty);
    expect(recipe.core.personalTagIds, isNotEmpty);

    final dish = recipe.toMenuDish();

    expect(_names(dish), isEmpty);
    for (final key in [
      'socialData',
      'realtimeData',
      'offlineData',
      'personalTagIds',
      'personalTags',
    ]) {
      expect(dish.containsKey(key), isFalse, reason: key);
    }
    final core = recipe.core.toFirestore()
      ..remove('personalTagIds')
      ..remove('personalTags');
    expect(dish, core);
    expect(dish['tagResult'], isNotNull);
    expect(dish['createdBy'], 'owner-uid');
  });

  test('a live menu stores menu dishes and reads them back', () {
    final recipe = _sharedRecipe('d1');
    final stored = RealtimeMenuData.fromMenuCategories(
      menuTitle: 'Veckans meny',
      createdForDate: _at,
      menuSnapshot: {
        'middag': [recipe],
      },
    ).serializeContent();

    final dishes = (stored['menuSnapshot'] as Map)['middag'] as List;
    expect(dishes.single, recipe.toMenuDish());

    final read = RealtimeMenuData.fromFirestore(
      stored,
    ).getRecipesForCategory('middag').single;
    expect(read.id, 'd1');
    expect(read.title, recipe.title);
    expect(read.core.createdBy, 'owner-uid');
    expect(read.core.tagResult?.tags, {'vegetarisk'});
    expect(read.core.personalTagIds, isNull);
    expect(read.socialData, isNull);
  });

  test('a live menu stored with whole recipes still loads', () {
    final recipe = _sharedRecipe('d1');
    final legacy = {
      ...RealtimeMenuData.fromMenuCategories(
        menuTitle: 'Veckans meny',
        createdForDate: _at,
        menuSnapshot: const {},
      ).serializeContent(),
      'menuSnapshot': {
        'middag': [recipe.toFirestore()],
      },
    };

    final read = RealtimeMenuData.fromFirestore(
      legacy,
    ).getRecipesForCategory('middag').single;
    expect(read.id, 'd1');
    expect(read.title, recipe.title);
  });

  test('a shared menu stores menu dishes', () {
    final recipe = _sharedRecipe('d1');
    final stored = SharedMenu.create(
      sharedByUserId: 'owner-uid',
      sharedByDisplayName: 'Olle',
      sharedToUserIds: const ['friend-uid'],
      menuTitle: 'Veckans meny',
      menuSnapshot: {
        'middag': [recipe],
      },
    ).toFirestore();

    final dish = ((stored['menuSnapshot'] as Map)['middag'] as List).single;
    expect(dish, recipe.toMenuDish());
  });
}
