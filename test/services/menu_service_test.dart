import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/models/recipe_unified.dart';

abstract class RecipeRepository {
  List<Recipe> getAllRecipes();
}

class MockRecipeRepository extends Mock implements RecipeRepository {}

void main() {
  group('MenuService.generateMenuFromPrompt', () {
    late MenuService service;
    late MockRecipeRepository repository;

    setUp(() {
      service = MenuService();
      repository = MockRecipeRepository();
    });

    test('generates menu using recipes from repository', () async {
      final recipes = [
        Recipe(
          core: RecipeCore(
            id: '1',
            title: 'Grönsallad',
            description: '',
            ingredients: const [],
            instructions: const [],
            mealType: 'Lunch',
          ),
          type: RecipeType.personal,
        ),
        Recipe(
          core: RecipeCore(
            id: '2',
            title: 'Pasta',
            description: '',
            ingredients: const [],
            instructions: const [],
            mealType: 'Middag',
          ),
          type: RecipeType.personal,
        ),
        Recipe(
          core: RecipeCore(
            id: '3',
            title: 'Soppa',
            description: '',
            ingredients: const [],
            instructions: const [],
            mealType: 'Lunch',
          ),
          type: RecipeType.personal,
        ),
      ];

      when(repository.getAllRecipes()).thenReturn(recipes);

      final menu = await service.generateMenuFromPrompt(
        '2 lunch och 1 middag',
        repository.getAllRecipes(),
      );

      expect(menu['Lunch']?.length, 2);
      expect(menu['Middag']?.length, 1);
    });
  });
}
