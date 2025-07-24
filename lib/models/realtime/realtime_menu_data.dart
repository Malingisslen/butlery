// lib/models/realtime/realtime_menu_data.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../recipe_unified.dart';

/// Pure data representation for realtime menu content
/// 
/// This class contains ONLY:
/// - Menu data fields
/// - Serialization methods
/// - Basic data access
/// 
/// ❌ DOES NOT CONTAIN: Business logic, operations, analytics, UI concerns
class RealtimeMenuData {
  /// Title for the menu (e.g. "Family Andersson's weekly menu")
  final String menuTitle;

  /// When the menu was created/planned for
  final DateTime createdForDate;

  /// Category-based menu structure: Category -> List of recipes
  /// Key: 'Middag', 'Lunch', 'Frukost', etc. (same as existing menu structure)
  /// Value: List of Recipe objects for that category
  final Map<String, List<Recipe>> menuSnapshot;

  /// Extra notes for the entire menu
  final String? menuNotes;

  /// Favorite recipes often used (for quick-add)
  final List<String>? favoriteRecipeIds;

  /// Original prompt used to generate the menu (if applicable)
  final String? originalPrompt;

  const RealtimeMenuData({
    required this.menuTitle,
    required this.createdForDate,
    required this.menuSnapshot,
    this.menuNotes,
    this.favoriteRecipeIds,
    this.originalPrompt,
  });

  /// Create from menu categories format (compatible with MenuViewModel)
  factory RealtimeMenuData.fromMenuCategories({
    required String menuTitle,
    required Map<String, List<Recipe>> menuSnapshot,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
    DateTime? createdForDate,
  }) {
    return RealtimeMenuData(
      menuTitle: menuTitle,
      createdForDate: createdForDate ?? DateTime.now(),
      menuSnapshot: menuSnapshot,
      menuNotes: menuNotes,
      favoriteRecipeIds: favoriteRecipeIds,
      originalPrompt: originalPrompt,
    );
  }

  /// Create copy with updated data
  RealtimeMenuData copyWith({
    String? menuTitle,
    DateTime? createdForDate,
    Map<String, List<Recipe>>? menuSnapshot,
    String? menuNotes,
    List<String>? favoriteRecipeIds,
    String? originalPrompt,
  }) {
    return RealtimeMenuData(
      menuTitle: menuTitle ?? this.menuTitle,
      createdForDate: createdForDate ?? this.createdForDate,
      menuSnapshot: menuSnapshot ?? this.menuSnapshot,
      menuNotes: menuNotes ?? this.menuNotes,
      favoriteRecipeIds: favoriteRecipeIds ?? this.favoriteRecipeIds,
      originalPrompt: originalPrompt ?? this.originalPrompt,
    );
  }

  // ===== BASIC DATA ACCESS =====

  /// All categories in this menu
  List<String> get categories => menuSnapshot.keys.toList();

  /// Get recipes for specific category
  List<Recipe> getRecipesForCategory(String categoryName) {
    return menuSnapshot[categoryName] ?? [];
  }

  /// Check if category has recipes
  bool categoryHasRecipes(String categoryName) {
    return getRecipesForCategory(categoryName).isNotEmpty;
  }

  /// Get all unique recipes in the menu
  List<Recipe> get allUniqueRecipes {
    final allRecipes = <Recipe>[];
    final seenIds = <String>{};

    for (final categoryRecipes in menuSnapshot.values) {
      for (final recipe in categoryRecipes) {
        if (!seenIds.contains(recipe.id)) {
          allRecipes.add(recipe);
          seenIds.add(recipe.id);
        }
      }
    }

    return allRecipes;
  }

  /// Convert to MenuViewModel format
  Map<String, List<Recipe>> toMenuViewModelFormat() {
    return Map<String, List<Recipe>>.from(menuSnapshot);
  }

  /// Check if menu contains a specific recipe
  bool containsRecipe(String recipeId) {
    for (final recipes in menuSnapshot.values) {
      if (recipes.any((recipe) => recipe.id == recipeId)) {
        return true;
      }
    }
    return false;
  }

  /// Find which category a recipe belongs to
  String? findRecipeCategory(String recipeId) {
    for (final entry in menuSnapshot.entries) {
      if (entry.value.any((recipe) => recipe.id == recipeId)) {
        return entry.key;
      }
    }
    return null;
  }

  // ===== SERIALIZATION =====

  /// Serialize content for Firestore
  Map<String, dynamic> serializeContent() {
    // Serialize menuSnapshot to Firestore format (same as SharedMenu)
    final menuData = <String, List<Map<String, dynamic>>>{};
    for (final entry in menuSnapshot.entries) {
      final categoryName = entry.key;
      final recipes = entry.value;
      menuData[categoryName] =
          recipes.map((recipe) => recipe.toFirestore()).toList();
    }

    return {
      'menuTitle': menuTitle,
      'createdForDate': Timestamp.fromDate(createdForDate),
      'menuSnapshot': menuData,
      'menuNotes': menuNotes,
      'favoriteRecipeIds': favoriteRecipeIds,
      'originalPrompt': originalPrompt,
    };
  }

  /// Create from Firestore document data
  factory RealtimeMenuData.fromFirestore(Map<String, dynamic> data) {
    // Parse menu-specific data (same structure as SharedMenu)
    final menuData = data['menuSnapshot'] as Map<String, dynamic>? ?? {};
    final menuSnapshot = <String, List<Recipe>>{};

    // Convert menu data back to Recipe objects
    for (final entry in menuData.entries) {
      final categoryName = entry.key;
      final recipesData = entry.value as List<dynamic>? ?? [];

      final recipes = recipesData
          .map((recipeData) => Recipe(
                core: RecipeCore(
                  id: recipeData['id'] as String? ?? '',
                  title: recipeData['title'] as String? ?? '',
                  description: recipeData['description'] as String? ?? '',
                  ingredients: List<String>.from(recipeData['ingredients'] ?? []),
                  instructions: List<String>.from(recipeData['instructions'] ?? []),
                  imageUrls: List<String>.from(recipeData['imageUrls'] ?? []),
                  mealType: recipeData['mealType'] as String? ?? 'Middag',
                  portions: recipeData['portions'] as int?,
                  timeMinutes: recipeData['timeMinutes'] as int?,
                  rating: (recipeData['rating'] as num?)?.toDouble(),
                  tags: recipeData['tags'] != null
                      ? List<String>.from(recipeData['tags'])
                      : null,
                  sourceUrl: recipeData['sourceUrl'] as String?,
                  createdAt: DateTime.now(),
                  updatedAt: DateTime.now(),
                  createdBy: '',
                ),
                type: RecipeType.personal,
              ))
          .toList();

      menuSnapshot[categoryName] = recipes;
    }

    return RealtimeMenuData(
      menuTitle: data['menuTitle'] as String? ?? '',
      createdForDate:
          (data['createdForDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      menuSnapshot: menuSnapshot,
      menuNotes: data['menuNotes'] as String?,
      favoriteRecipeIds: data['favoriteRecipeIds'] != null
          ? List<String>.from(data['favoriteRecipeIds'])
          : null,
      originalPrompt: data['originalPrompt'] as String?,
    );
  }

  /// JSON serialization for caching
  Map<String, dynamic> toJson() {
    // Serialize menuSnapshot for JSON
    final menuData = <String, List<Map<String, dynamic>>>{};
    for (final entry in menuSnapshot.entries) {
      menuData[entry.key] =
          entry.value.map((recipe) => recipe.toJson()).toList();
    }

    return {
      'menuTitle': menuTitle,
      'createdForDate': createdForDate.toIso8601String(),
      'menuSnapshot': menuData,
      'menuNotes': menuNotes,
      'favoriteRecipeIds': favoriteRecipeIds,
      'originalPrompt': originalPrompt,
    };
  }

  /// Create from JSON data
  factory RealtimeMenuData.fromJson(Map<String, dynamic> json) {
    // Parse menuSnapshot from JSON
    final menuData = json['menuSnapshot'] as Map<String, dynamic>? ?? {};
    final menuSnapshot = <String, List<Recipe>>{};

    for (final entry in menuData.entries) {
      final recipesData = entry.value as List<dynamic>? ?? [];
      final recipes = recipesData
          .map((recipeData) =>
              Recipe.fromJson(recipeData as Map<String, dynamic>))
          .toList();
      menuSnapshot[entry.key] = recipes;
    }

    return RealtimeMenuData(
      menuTitle: json['menuTitle'] as String? ?? '',
      createdForDate: DateTime.parse(json['createdForDate'] as String),
      menuSnapshot: menuSnapshot,
      menuNotes: json['menuNotes'] as String?,
      favoriteRecipeIds: json['favoriteRecipeIds'] != null
          ? List<String>.from(json['favoriteRecipeIds'])
          : null,
      originalPrompt: json['originalPrompt'] as String?,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RealtimeMenuData &&
          runtimeType == other.runtimeType &&
          menuTitle == other.menuTitle &&
          createdForDate == other.createdForDate &&
          _mapEquals(menuSnapshot, other.menuSnapshot) &&
          menuNotes == other.menuNotes &&
          _listEquals(favoriteRecipeIds, other.favoriteRecipeIds) &&
          originalPrompt == other.originalPrompt;

  @override
  int get hashCode =>
      menuTitle.hashCode ^
      createdForDate.hashCode ^
      menuSnapshot.hashCode ^
      menuNotes.hashCode ^
      favoriteRecipeIds.hashCode ^
      originalPrompt.hashCode;

  @override
  String toString() {
    return 'RealtimeMenuData('
        'title: $menuTitle, '
        'categories: ${categories.length}, '
        'createdFor: ${createdForDate.toIso8601String().substring(0, 10)}'
        ')';
  }

  // Helper methods for equality comparison
  bool _mapEquals<K, V>(Map<K, List<V>>? a, Map<K, List<V>>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    
    for (final key in a.keys) {
      if (!b.containsKey(key)) return false;
      if (!_listEquals(a[key], b[key])) return false;
    }
    return true;  
  }

  bool _listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null && b == null) return true;
    if (a == null || b == null) return false;
    if (a.length != b.length) return false;
    
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}