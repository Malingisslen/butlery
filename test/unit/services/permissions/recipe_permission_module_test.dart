/// Direct unit tests for [RecipePermissionModule.isRecipeOwnerAsync] (BUT-1149
/// coverage burndown — previously zero direct coverage).
///
/// Security-critical ownership check. The valuable, cleanly-mockable surface is
/// isRecipeOwnerAsync, which reads the recipe from an injected repository and
/// compares the owner to the current user. The tests pin the fail-closed
/// behavior (no user / empty id / no repo / missing recipe / repo error → deny)
/// and the positive owner match. The other module methods route through the
/// service/helper collaborators and belong with permission_service tests.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/services/permissions/recipe_permission_module.dart';
import 'package:butlery/services/unified/operations/modules/recipe_permission_helper.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

class _Auth extends Mock implements AuthRepository {}

class _Svc extends Mock implements UnifiedRecipeService {}

class _Helper extends Mock implements RecipePermissionHelper {}

class _Repo extends Mock implements RecipeRepository {}

void main() {
  RecipePermissionModule build({
    String? uid = 'u1',
    RecipeRepository? repo,
  }) => RecipePermissionModule(
    authRepository: _Auth(),
    recipeRepository: repo,
    recipeService: _Svc(),
    permissionHelper: _Helper(),
    getCurrentUserId: () => uid,
  );

  group('isRecipeOwnerAsync fail-closed guards', () {
    test('denies when not authenticated', () async {
      expect(
        await build(uid: null, repo: _Repo()).isRecipeOwnerAsync('r1'),
        isFalse,
      );
    });

    test('denies on an empty recipe id', () async {
      expect(await build(repo: _Repo()).isRecipeOwnerAsync(''), isFalse);
    });

    test('denies when no repository is available', () async {
      expect(await build(repo: null).isRecipeOwnerAsync('r1'), isFalse);
    });
  });

  group('isRecipeOwnerAsync ownership', () {
    test('true when the recipe owner matches the current user', () async {
      final repo = _Repo();
      when(() => repo.read('r1')).thenAnswer(
        (_) async => RecipeFactory.build(createdBy: 'u1'),
      );
      expect(
        await build(uid: 'u1', repo: repo).isRecipeOwnerAsync('r1'),
        isTrue,
      );
    });

    test('false when the recipe is owned by someone else', () async {
      final repo = _Repo();
      when(() => repo.read('r1')).thenAnswer(
        (_) async => RecipeFactory.build(createdBy: 'someone-else'),
      );
      expect(
        await build(uid: 'u1', repo: repo).isRecipeOwnerAsync('r1'),
        isFalse,
      );
    });

    test('false when the recipe does not exist', () async {
      final repo = _Repo();
      when(() => repo.read('r1')).thenAnswer((_) async => null);
      expect(
        await build(uid: 'u1', repo: repo).isRecipeOwnerAsync('r1'),
        isFalse,
      );
    });

    test('false (fail-closed) when the repository throws', () async {
      final repo = _Repo();
      when(() => repo.read('r1')).thenThrow(Exception('db down'));
      expect(
        await build(uid: 'u1', repo: repo).isRecipeOwnerAsync('r1'),
        isFalse,
      );
    });
  });
}
