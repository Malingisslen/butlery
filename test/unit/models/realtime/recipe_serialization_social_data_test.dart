import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/realtime/recipe_serialization.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:flutter_test/flutter_test.dart';

Recipe _recipe(RecipeSocialData social) => Recipe(
  core: RecipeCore(
    id: 'r1',
    title: 'Köttbullar',
    description: 'Klassiska',
    ingredients: const ['köttfärs'],
    instructions: const ['Stek'],
    mealType: 'Middag',
    createdBy: 'owner',
  ),
  type: RecipeType.collaborative,
  socialData: social,
);

RecipeSocialData? _roundTrip(RecipeSocialData social) =>
    RecipeSerialization.deserializeRecipe(
      RecipeSerialization.serializeRecipe(_recipe(social)),
      'r1',
    ).socialData;

void main() {
  group('RecipeSerialization social data round trip', () {
    final social = RecipeSocialData(
      ownerId: 'owner',
      ownerDisplayName: 'Malin',
      memberPermissions: {
        'editor-uid': ResourcePermission.editor,
        'viewer-uid': ResourcePermission.viewer,
      },
      categoryIds: ['cat-1'],
      descriptionCollaborative: 'Tillsammans',
      grants: {
        'editor-uid': [RecipeSocialData.groupGrant('cat-1')],
        'viewer-uid': [RecipeSocialData.directGrant],
      },
    );

    test('an editor stays an editor', () {
      expect(
        _roundTrip(social)!.memberPermissions!['editor-uid'],
        ResourcePermission.editor,
      );
    });

    test('grants survive, so a group revoke still knows who to cut', () {
      expect(_roundTrip(social)!.grants, social.grants);
    });

    test('the collaborative description is read from its own key', () {
      expect(_roundTrip(social)!.descriptionCollaborative, 'Tillsammans');
    });
  });

  group('RecipeSocialData.fromJson against malformed payloads', () {
    test('wrong-typed collections read as absent instead of throwing', () {
      final parsed = RecipeSocialData.fromJson({
        'memberPermissions': 'oops',
        'categoryIds': 7,
        'grants': ['x'],
      });
      expect(parsed.memberPermissions, isNull);
      expect(parsed.categoryIds, isNull);
      expect(parsed.grants, isNull);
    });

    test('non-string entries are dropped, unknown permission is viewer', () {
      final parsed = RecipeSocialData.fromJson({
        'memberPermissions': {'u1': 99, 'u2': 'editor'},
        'categoryIds': ['a', 5, null],
        'grants': {
          'u1': ['direct', 3],
          'u2': 'bad',
        },
      });
      expect(parsed.memberPermissions, {
        'u1': ResourcePermission.viewer,
        'u2': ResourcePermission.viewer,
      });
      expect(parsed.categoryIds, ['a']);
      expect(parsed.grants, {
        'u1': ['direct'],
        'u2': <String>[],
      });
    });
  });
}
