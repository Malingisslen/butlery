import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:butlery/services/menu_service.dart';
import 'package:butlery/models/recipe.dart';

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

    test('generates menu using recipes from repository', () {
      final recipes = [
        Recipe(
          title: 'Grönsallad',
          description: '',
          ingredients: const [],
          instructions: const [],
          mealType: 'Lunch',
        ),
        Recipe(
          title: 'Pasta',
          description: '',
          ingredients: const [],
          instructions: const [],
          mealType: 'Middag',
        ),
        Recipe(
          title: 'Soppa',
          description: '',
          ingredients: const [],
          instructions: const [],
          mealType: 'Lunch',
        ),
      ];

      when(repository.getAllRecipes()).thenReturn(recipes);

      final menu = service.generateMenuFromPrompt(
        '2 lunch och 1 middag',
        repository.getAllRecipes(),
      );

      expect(menu['Lunch']?.length, 2);
      expect(menu['Middag']?.length, 1);
    });
  });
}
