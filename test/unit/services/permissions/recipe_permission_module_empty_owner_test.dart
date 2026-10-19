/// BUT-2107: a recipe whose `socialData.ownerId` is '' and whose `createdBy`
/// is the signed-in user is that user's own recipe.
///
/// A plain `socialData?.ownerId ?? createdBy` stops at '', which then reads as
/// a real uid that matches nobody, so the creator was refused as owner.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/permissions/recipe_permission_module.dart';
import 'package:butlery/services/unified/operations/modules/recipe_permission_helper.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

class _Auth extends Mock implements AuthRepository {}

class _Svc extends Mock implements UnifiedRecipeService {}

class _Helper extends Mock implements RecipePermissionHelper {}

class _Repo extends Mock implements RecipeRepository {}

const _me = 'u1';

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
  type: RecipeType.personal,
  socialData: RecipeSocialData(ownerId: ownerId),
);

void main() {
  late _Repo repo;
  late _Svc svc;
  late RecipePermissionModule module;

  setUp(() {
    repo = _Repo();
    svc = _Svc();
    module = RecipePermissionModule(
      authRepository: _Auth(),
      recipeRepository: repo,
      recipeService: svc,
      permissionHelper: _Helper(),
      getCurrentUserId: () => _me,
    );
  });

  Future<bool> asyncOwner(Recipe r) {
    when(() => repo.read('r1')).thenAnswer((_) async => r);
    return module.isRecipeOwnerAsync('r1');
  }

  bool syncOwner(Recipe r) {
    when(() => svc.getRecipeById('r1')).thenReturn(r);
    return module.isRecipeOwner('r1');
  }

  group('isRecipeOwnerAsync', () {
    test('the creator owns a recipe whose ownerId is empty', () async {
      expect(await asyncOwner(_recipe()), isTrue);
    });

    test('closing: someone else created it', () async {
      expect(await asyncOwner(_recipe(createdBy: 'other')), isFalse);
    });

    test('closing: both fields are empty', () async {
      expect(await asyncOwner(_recipe(createdBy: '')), isFalse);
    });
  });

  group('isRecipeOwner', () {
    test('the creator owns a recipe whose ownerId is empty', () {
      expect(syncOwner(_recipe()), isTrue);
    });

    test('closing: someone else created it', () {
      expect(syncOwner(_recipe(createdBy: 'other')), isFalse);
    });

    test('closing: both fields are empty', () {
      expect(syncOwner(_recipe(createdBy: '')), isFalse);
    });
  });
}
