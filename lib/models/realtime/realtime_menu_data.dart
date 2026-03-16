/// Comprehensive realtime menu data providing pure data representation for collaborative meal planning infrastructure.
/// This class implements sophisticated menu data management following Single Responsibility Principle,
/// handling all aspects of menu data representation including category-based recipe organization, temporal management,
/// comprehensive serialization, and basic data access operations. It provides complete data infrastructure while
/// maintaining clean separation from business logic, analytics, and UI presentation concerns.

// lib/models/realtime/realtime_menu_data.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/core/types/app_timestamp.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Comprehensive realtime menu data with pure data representation and robust serialization for collaborative meal planning.
/// Represents complete menu data structure with category-based recipe organization, temporal management,
/// and comprehensive metadata support through focused data responsibility and clean serialization patterns.
/// This class serves as the foundation for all menu data operations and persistence functionality.
class RealtimeMenuData {
  /// Menu title for identification and display purposes in collaborative meal planning.
  final String menuTitle;

  /// Target date for meal planning timeline organization and scheduling coordination.
  final DateTime createdForDate;

  /// Category-based recipe organization providing structured meal planning with Swedish meal categories.
  final Map<String, List<Recipe>> menuSnapshot;

  /// Optional menu notes providing additional context and collaborative planning information.
  final String? menuNotes;

  /// Optional favorite recipe IDs for personalized quick-access and preference tracking.
  final List<String>? favoriteRecipeIds;

  /// Optional original AI generation prompt preserving menu creation context and regeneration capability.
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

  /// Get all categories
  List<String> get categories => menuSnapshot.keys.toList();

  /// Get all unique recipes (deduplicated across categories)
  List<Recipe> get allUniqueRecipes {
    final seen = <String>{};
    final unique = <Recipe>[];

    for (final recipes in menuSnapshot.values) {
      for (final recipe in recipes) {
        if (!seen.contains(recipe.id)) {
          seen.add(recipe.id);
          unique.add(recipe);
        }
      }
    }

    return unique;
  }

  /// Get recipes for specific category
  List<Recipe> getRecipesForCategory(String categoryName) {
    return menuSnapshot[categoryName] ?? [];
  }

  /// Check if category has recipes
  bool categoryHasRecipes(String categoryName) {
    return menuSnapshot[categoryName]?.isNotEmpty ?? false;
  }

  /// Convert to MenuViewModel format
  Map<String, List<Recipe>> toMenuViewModelFormat() => Map.from(menuSnapshot);

  /// Check if menu contains a specific recipe
  bool containsRecipe(String recipeId) {
    return allUniqueRecipes.any((recipe) => recipe.id == recipeId);
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

  /// Serialize for Firestore
  Map<String, dynamic> serializeContent() {
    // Serialize menuSnapshot for Firestore
    final menuData = <String, List<Map<String, dynamic>>>{};
    for (final entry in menuSnapshot.entries) {
      menuData[entry.key] =
          entry.value.map((recipe) => recipe.toFirestore()).toList();
    }

    return {
      'menuTitle': menuTitle,
      'createdForDate': AppTimestamp.fromDateTime(createdForDate).toFirestore(),
      'menuSnapshot': menuData,
      'menuNotes': menuNotes,
      'favoriteRecipeIds': favoriteRecipeIds,
      'originalPrompt': originalPrompt,
    };
  }

  /// Create from Firestore data
  factory RealtimeMenuData.fromFirestore(Map<String, dynamic> data) {
    // Parse menuSnapshot from Firestore
    final menuData = SerializationUtils.safeMap(data, 'menuSnapshot');
    final menuSnapshot = <String, List<Recipe>>{};

    for (final entry in menuData.entries) {
      final recipesData = entry.value as List<dynamic>? ?? [];
      final recipes = recipesData
          .map((recipeData) =>
              Recipe.fromMap('', recipeData as Map<String, dynamic>))
          .toList();

      menuSnapshot[entry.key] = recipes;
    }

    final favoriteIds = data['favoriteRecipeIds'] != null
        ? SerializationUtils.safeStringList(data, 'favoriteRecipeIds')
        : null;

    return RealtimeMenuData(
      menuTitle: SerializationUtils.safeString(data, 'menuTitle'),
      createdForDate:
          AppTimestamp.fromFirestore(data['createdForDate']).dateTime,
      menuSnapshot: menuSnapshot,
      menuNotes: SerializationUtils.safeNullableString(data, 'menuNotes'),
      favoriteRecipeIds: favoriteIds?.isEmpty == true ? null : favoriteIds,
      originalPrompt:
          SerializationUtils.safeNullableString(data, 'originalPrompt'),
    );
  }

  /// JSON serialization for caching
  Map<String, dynamic> toJson() {
    // Serialize menuSnapshot for JSON
    final menuData = <String, List<Map<String, dynamic>>>{};
    for (final entry in menuSnapshot.entries) {
      menuData[entry.key] =
          entry.value.map((recipe) => recipe.toFirestore()).toList();
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
    final menuData = SerializationUtils.safeMap(json, 'menuSnapshot');
    final menuSnapshot = <String, List<Recipe>>{};

    for (final entry in menuData.entries) {
      final recipesData = entry.value as List<dynamic>? ?? [];
      final recipes = recipesData
          .map((recipeData) =>
              Recipe.fromMap('', recipeData as Map<String, dynamic>))
          .toList();

      menuSnapshot[entry.key] = recipes;
    }

    final favoriteIds = json['favoriteRecipeIds'] != null
        ? SerializationUtils.safeStringList(json, 'favoriteRecipeIds')
        : null;

    return RealtimeMenuData(
      menuTitle: SerializationUtils.safeString(json, 'menuTitle'),
      createdForDate:
          SerializationUtils.safeRequiredDateTime(json, 'createdForDate'),
      menuSnapshot: menuSnapshot,
      menuNotes: SerializationUtils.safeNullableString(json, 'menuNotes'),
      favoriteRecipeIds: favoriteIds?.isEmpty == true ? null : favoriteIds,
      originalPrompt:
          SerializationUtils.safeNullableString(json, 'originalPrompt'),
    );
  }

  /// Create copy with updated values
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RealtimeMenuData &&
        other.menuTitle == menuTitle &&
        other.createdForDate == createdForDate &&
        _mapEquals(other.menuSnapshot, menuSnapshot) &&
        other.menuNotes == menuNotes &&
        _listEquals(other.favoriteRecipeIds, favoriteRecipeIds) &&
        other.originalPrompt == originalPrompt;
  }

  @override
  int get hashCode => Object.hash(
        menuTitle,
        createdForDate,
        menuSnapshot,
        menuNotes,
        favoriteRecipeIds,
        originalPrompt,
      );

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
