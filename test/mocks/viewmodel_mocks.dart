import 'package:flutter/foundation.dart';
import 'package:mocktail/mocktail.dart';
import 'package:butlery/viewmodels/unified_recipe_viewmodel.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/viewmodels/recipe_detail_viewmodel.dart';

/// Mock for UnifiedRecipeViewModel
class MockUnifiedRecipeViewModel extends Mock
    with ChangeNotifier
    implements UnifiedRecipeViewModel {}

/// Mock for AuthViewModel
class MockAuthViewModel extends Mock
    with ChangeNotifier
    implements AuthViewModel {}

/// Mock for RecipeDetailViewModel
class MockRecipeDetailViewModel extends Mock
    with ChangeNotifier
    implements RecipeDetailViewModel {}

// Additional ViewModels for other screens can be added as needed

// Register fallback values for custom types
void registerFallbackValues() {
  // Register any custom types that are used as parameters in mocked methods
  // Example:
  // registerFallbackValue(RecipeFactory.empty());
}
