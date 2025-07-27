import 'package:butlery/models/recipe_unified.dart';

enum RecipeChangeType { added, modified, removed }

class RecipeChange {
  final RecipeChangeType type;
  final Recipe recipe;

  RecipeChange({required this.type, required this.recipe});
}
