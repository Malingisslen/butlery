/// BUT-2107: a recipe whose `socialData.ownerId` is '' is owned by its
/// creator, so the form asks "whose recipe is this" of `createdBy`.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/repositories/interfaces/recipe_repository.dart';
import 'package:butlery/viewmodels/recipe_form/recipe_permission_manager.dart';

import '../../infrastructure/di/test_service_locator.dart';
import '../../infrastructure/factories/recipe_factory.dart';
import '../../infrastructure/mocks/production_mocks.dart';
import '../../test_support/base_unit_test.dart';

const _me = 'me';
const _olle = 'olle';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late RecipePermissionManager manager;
  late MockRecipeRepository repository;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    production.ServiceLocator.initialize(DIContainer());
  });

  setUp(() async {
    await TestServiceLocator.initialize();
    final permissions = FakePermissionService()
      ..setPermissionState(currentUserId: _me, isAuthenticated: true);
    manager = RecipePermissionManager(permissionService: permissions);
    repository = MockRecipeRepository();
    TestServiceLocator.registerMock<RecipeRepository>(repository);
  });

  tearDown(() async {
    manager.dispose();
    await TestServiceLocator.reset();
  });

  Recipe recipe({required String createdBy, String ownerId = ''}) =>
      RecipeFactory.build(
        id: 'r1',
        createdBy: createdBy,
        socialData: RecipeSocialData(ownerId: ownerId),
      );

  group('someoneElsesOwner', () {
    test('an empty owner id names the creator when it is somebody else', () {
      expect(manager.someoneElsesOwner(recipe(createdBy: _olle)), _olle);
    });

    test('an empty owner id with me as creator is my own recipe', () {
      expect(manager.someoneElsesOwner(recipe(createdBy: _me)), isNull);
    });

    test('both fields empty is nobody\'s, so not someone else\'s', () {
      expect(manager.someoneElsesOwner(recipe(createdBy: '')), isNull);
    });
  });

  group('watchCanEdit', () {
    test('watches the creator\'s copy when the owner id is empty', () async {
      when(
        () => repository.watchSharedRecipe(ownerId: _olle, recipeId: 'r1'),
      ).thenAnswer(
        (_) => Stream.value(
          RecipeFactory.build(
            id: 'r1',
            createdBy: _olle,
            socialData: const RecipeSocialData(
              ownerId: _olle,
              memberPermissions: {_me: ResourcePermission.editor},
            ),
          ),
        ),
      );

      expect(await manager.watchCanEdit(recipe(createdBy: _olle)).first, true);
    });

    test('has nothing to watch on my own recipe', () async {
      expect(await manager.watchCanEdit(recipe(createdBy: _me)).isEmpty, true);
      verifyNever(
        () => repository.watchSharedRecipe(
          ownerId: any(named: 'ownerId'),
          recipeId: any(named: 'recipeId'),
        ),
      );
    });

    test('has nothing to watch when no owner resolves', () async {
      expect(await manager.watchCanEdit(recipe(createdBy: '')).isEmpty, true);
    });
  });
}
