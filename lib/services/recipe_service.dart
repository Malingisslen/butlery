// lib/services/recipe_service.dart

import 'package:flutter/foundation.dart';
import '../models/recipe.dart';

/// Resultat av en RecipeService operation
class RecipeOperationResult {
  final bool isSuccess;
  final String message;
  final List<String>? warnings;

  const RecipeOperationResult({
    required this.isSuccess,
    required this.message,
    this.warnings,
  });

  factory RecipeOperationResult.success(
    String message, {
    List<String>? warnings,
  }) {
    return RecipeOperationResult(
      isSuccess: true,
      message: message,
      warnings: warnings,
    );
  }

  factory RecipeOperationResult.error(String message) {
    return RecipeOperationResult(isSuccess: false, message: message);
  }
}

/// Singleton service för att hantera recept
/// Använder ChangeNotifier för reaktiv UI
class RecipeService extends ChangeNotifier {
  static RecipeService? _instance;

  // Private constructor för singleton
  RecipeService._internal();

  // Factory constructor som returnerar samma instans
  factory RecipeService() {
    _instance ??= RecipeService._internal();
    return _instance!;
  }

  // ===== STATE MANAGEMENT =====

  List<Recipe> _recipes = [];
  bool _isLoading = false;
  String? _lastError;
  bool _isInitialized = false;

  // ===== GETTERS =====

  /// Alla recept (read-only kopia)
  List<Recipe> get recipes => List.unmodifiable(_recipes);

  /// Om service laddar just nu
  bool get isLoading => _isLoading;

  /// Senaste fel (null om inget fel)
  String? get lastError => _lastError;

  /// Om service har ett aktivt fel
  bool get hasError => _lastError != null;

  /// Om service är initialiserad
  bool get isInitialized => _isInitialized;

  // ===== INITIALIZATION =====

  /// Initialisera service - ladda data från storage
  Future<void> initialize() async {
    if (_isInitialized) return;

    _setLoading(true);
    clearError(); // ✅ FIXAT: Utan underscore

    try {
      // Simulera loading från database/storage
      await Future.delayed(const Duration(milliseconds: 300));

      // För nu använder vi mock data - senare ersätts med Firebase
      _recipes = _generateMockRecipes();

      _isInitialized = true;
      debugPrint(
        '✅ RecipeService: Initialiserad med ${_recipes.length} recept',
      );
    } catch (e) {
      _setError('Kunde inte initialisera RecipeService: $e');
      debugPrint('❌ RecipeService: Initialiseringsfel: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ===== CRUD OPERATIONS =====

  /// Lägg till ett nytt recept
  Future<RecipeOperationResult> addRecipe(Recipe recipe) async {
    _setLoading(true);
    clearError(); // ✅ FIXAT: Utan underscore

    try {
      // Kontrollera att receptet inte redan finns
      if (_recipes.any((r) => r.id == recipe.id)) {
        return RecipeOperationResult.error(
          'Recept med ID ${recipe.id} finns redan',
        );
      }

      // Simulera async operation (Firebase senare)
      await Future.delayed(const Duration(milliseconds: 200));

      _recipes.add(recipe);
      notifyListeners();

      debugPrint('✅ RecipeService: Lade till recept "${recipe.title}"');
      return RecipeOperationResult.success('Recept "${recipe.title}" sparat');
    } catch (e) {
      final error = 'Kunde inte spara recept: $e';
      _setError(error);
      return RecipeOperationResult.error(error);
    } finally {
      _setLoading(false);
    }
  }

  /// Lägg till flera recept samtidigt
  Future<RecipeOperationResult> addMultipleRecipes(List<Recipe> recipes) async {
    _setLoading(true);
    clearError(); // ✅ FIXAT: Utan underscore

    try {
      await Future.delayed(const Duration(milliseconds: 500));

      final warnings = <String>[];
      int addedCount = 0;

      for (final recipe in recipes) {
        if (_recipes.any((r) => r.id == recipe.id)) {
          warnings.add('Recept "${recipe.title}" finns redan');
          continue;
        }

        _recipes.add(recipe);
        addedCount++;
      }

      notifyListeners();

      final message =
          addedCount == recipes.length
              ? 'Alla $addedCount recept importerade'
              : '$addedCount av ${recipes.length} recept importerade';

      debugPrint('✅ RecipeService: $message');
      return RecipeOperationResult.success(
        message,
        warnings: warnings.isNotEmpty ? warnings : null,
      );
    } catch (e) {
      final error = 'Kunde inte importera recept: $e';
      _setError(error);
      return RecipeOperationResult.error(error);
    } finally {
      _setLoading(false);
    }
  }

  /// Uppdatera ett befintligt recept
  Future<RecipeOperationResult> updateRecipe(Recipe updatedRecipe) async {
    _setLoading(true);
    clearError(); // ✅ FIXAT: Utan underscore

    try {
      final index = _recipes.indexWhere((r) => r.id == updatedRecipe.id);
      if (index == -1) {
        return RecipeOperationResult.error(
          'Recept med ID ${updatedRecipe.id} hittades inte',
        );
      }

      await Future.delayed(const Duration(milliseconds: 200));

      _recipes[index] = updatedRecipe;
      notifyListeners();

      debugPrint(
        '✅ RecipeService: Uppdaterade recept "${updatedRecipe.title}"',
      );
      return RecipeOperationResult.success(
        'Recept "${updatedRecipe.title}" uppdaterat',
      );
    } catch (e) {
      final error = 'Kunde inte uppdatera recept: $e';
      _setError(error);
      return RecipeOperationResult.error(error);
    } finally {
      _setLoading(false);
    }
  }

  /// Ta bort ett recept
  Future<RecipeOperationResult> deleteRecipe(String recipeId) async {
    _setLoading(true);
    clearError(); // ✅ FIXAT: Utan underscore

    try {
      final recipe = _recipes.firstWhere(
        (r) => r.id == recipeId,
        orElse: () => throw Exception('Recept hittades inte'),
      );

      await Future.delayed(const Duration(milliseconds: 200));

      _recipes.removeWhere((r) => r.id == recipeId);
      notifyListeners();

      debugPrint('✅ RecipeService: Tog bort recept "${recipe.title}"');
      return RecipeOperationResult.success(
        'Recept "${recipe.title}" borttaget',
      );
    } catch (e) {
      final error = 'Kunde inte ta bort recept: $e';
      _setError(error);
      return RecipeOperationResult.error(error);
    } finally {
      _setLoading(false);
    }
  }

  /// Hämta recept by ID
  Recipe? getRecipeById(String id) {
    try {
      return _recipes.firstWhere((r) => r.id == id);
    } catch (e) {
      return null;
    }
  }

  /// Sök recept
  List<Recipe> searchRecipes(String query) {
    if (query.isEmpty) return recipes;

    final lowerQuery = query.toLowerCase();
    return _recipes.where((recipe) {
      return recipe.title.toLowerCase().contains(lowerQuery) ||
          recipe.description.toLowerCase().contains(lowerQuery) ||
          recipe.ingredients.any(
            (ing) => ing.toLowerCase().contains(lowerQuery),
          ) ||
          (recipe.tags?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ??
              false);
    }).toList();
  }

  // ===== ERROR HANDLING =====

  /// Rensa fel
  void clearError() {
    if (_lastError != null) {
      _lastError = null;
      notifyListeners();
    }
  }

  /// Sätt fel
  void _setError(String error) {
    _lastError = error;
    notifyListeners();
  }

  /// Sätt loading state
  void _setLoading(bool loading) {
    if (_isLoading != loading) {
      _isLoading = loading;
      notifyListeners();
    }
  }

  // ===== UTILITY METHODS =====

  /// Återställ service (för testing)
  void reset() {
    _recipes.clear();
    _isLoading = false;
    _lastError = null;
    _isInitialized = false;
    notifyListeners();
  }

  /// Refresh data (för pull-to-refresh)
  Future<void> refresh() async {
    _setLoading(true);
    clearError(); // ✅ FIXAT: Utan underscore

    try {
      // Simulera refresh från server
      await Future.delayed(const Duration(milliseconds: 500));
      // I framtiden: ladda om från Firebase
      notifyListeners();
    } catch (e) {
      _setError('Kunde inte uppdatera data: $e');
    } finally {
      _setLoading(false);
    }
  }

  // ===== MOCK DATA (TEMPORARY) =====

  /// Generera mock recept för development
  List<Recipe> _generateMockRecipes() {
    return [
      Recipe(
        id: 'mock-1',
        title: 'Krämig Kyckling Pasta',
        description: 'En läcker pasta med kycklingfilé i krämig sås',
        portions: 4,
        timeMinutes: 30,
        ingredients: [
          '400g pasta',
          '500g kycklingfilé',
          '2 dl vispgrädde',
          '1 gul lök',
          '2 vitlöksklyftor',
          'Salt och peppar',
        ],
        instructions: [
          'Koka pastan enligt förpackningen',
          'Stek kycklingen i bitar',
          'Fräs löken och vitlöken',
          'Tillsätt grädde och låt sjuda',
          'Blanda med pastan och servera',
        ],
        tags: ['pasta', 'kyckling', 'middag'],
        rating: 4.5,
        imageUrl: null,
        mealType: 'Middag',
      ),
      Recipe(
        id: 'mock-2',
        title: 'Klassisk Caesar Sallad',
        description: 'Crispy sallad med hemgjord dressing',
        portions: 2,
        timeMinutes: 15,
        ingredients: [
          '1 isbergssallad',
          '100g parmesan',
          '2 dl krutonger',
          '3 msk majonnäs',
          '1 msk dijonsenap',
          '1 vitlöksklyfta',
        ],
        instructions: [
          'Skölj och hacka salladen',
          'Gör dressing av majonnäs, senap och vitlök',
          'Blanda alla ingredienser',
          'Toppa med parmesan och krutonger',
        ],
        tags: ['sallad', 'lunch', 'vegetarisk'],
        rating: 4.0,
        imageUrl: null,
        mealType: 'Lunch',
      ),
      Recipe(
        id: 'mock-3',
        title: 'Chokladmuffins',
        description: 'Saftiga muffins med chokladbitar',
        portions: 12,
        timeMinutes: 25,
        ingredients: [
          '3 dl mjöl',
          '2 dl socker',
          '1 dl kakao',
          '2 ägg',
          '1 dl mjölk',
          '100g smör',
          '100g chokladbitar',
        ],
        instructions: [
          'Sätt ugnen på 200°C',
          'Blanda torra ingredienser',
          'Vispa ihop ägg, mjölk och smält smör',
          'Blanda allt och tillsätt chokladbitar',
          'Grädda i 15-20 minuter',
        ],
        tags: ['bakning', 'dessert', 'choklad'],
        rating: 4.8,
        imageUrl: null,
        mealType: 'Dessert',
      ),
    ];
  }

  @override
  void dispose() {
    // Cleanup om behövs
    super.dispose();
  }
}
