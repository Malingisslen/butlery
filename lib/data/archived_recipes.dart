// lib/data/archived_recipes.dart

import 'recipes/recipe_seeds.dart';

// Export for external usage
export 'recipes/recipe_seeds.dart';

// Facade for backward compatibility
final archivedRecipes = RecipeSeeds.allRecipes;