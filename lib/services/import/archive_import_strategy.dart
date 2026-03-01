/// 🔍 AI INFO BLOCK:
/// Component: Archive Import Strategy - Strategy for importing from Butlery archive
/// File: lib/services/import/archive_import_strategy.dart
/// Quick Guide: Handles recipe imports from the Butlery recipe archive collection
/// Dependencies IN: ImportStrategy interface, Recipe model, archived_recipes data
/// Dependencies OUT: Used by archive import ViewModels and import manager
/// Data flow: Archive recipe ID -> Recipe data lookup -> Recipe model
/// State management: Stateless lookup strategy
/// Purpose: Import pre-validated recipes from Butlery's curated collection
/// Common issues: Archive data consistency, recipe ID validation
/// Test coverage: Unit tests for archive lookup and validation
/// Performance: Fast lookup from pre-loaded archive data
/// Analytics: Archive import usage, popular recipe selections
/// Code smells: None - follows strategy pattern
/// Connected to: ArchiveImportViewModel, PersonalRecipeOperations
/// Used in phases: Phase 5 - Service Consolidation (import strategy pattern)

import 'package:uuid/uuid.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/data/archived_recipes.dart' as archive;
import 'package:butlery/services/import/import_strategy.dart';

/// Strategy for importing recipes from the Butlery archive
/// Handles:
/// - Single recipe import by ID
/// - Batch recipe import
/// - Archive validation
/// - Source URL attribution
class ArchiveImportStrategy extends ImportStrategy with ImportValidationMixin {
  static const _uuid = Uuid();

  @override
  String get strategyName => 'Archive Import';

  @override
  String get description =>
      'Import recipes from the Butlery curated recipe archive';

  @override
  String get inputExample => 'recipe_id_123 or archive:recipe_name';

  @override
  bool canHandle(String input) {
    final trimmed = input.trim();

    // Check for archive prefix
    if (trimmed.toLowerCase().startsWith('archive:')) return true;

    // Check if it's a valid recipe ID in archive
    return _findRecipeById(trimmed) != null;
  }

  @override
  bool validateInput(String input) {
    if (input.trim().isEmpty) return false;
    return canHandle(input);
  }

  @override
  Future<ImportResult> import(String input,
      {Map<String, dynamic>? options}) async {
    try {
      final trimmed = input.trim();
      Recipe? sourceRecipe;

      // Handle archive prefix
      if (trimmed.toLowerCase().startsWith('archive:')) {
        final recipeName = trimmed.substring(8); // Remove 'archive:' prefix
        sourceRecipe = _findRecipeByName(recipeName);
      } else {
        // Try to find by ID first, then by name
        sourceRecipe = _findRecipeById(trimmed) ?? _findRecipeByName(trimmed);
      }

      if (sourceRecipe == null) {
        return ImportResult.failure(
          'Recipe not found in archive: $trimmed',
          metadata: {'strategy': strategyName, 'searchTerm': trimmed},
        );
      }

      // Create new recipe with archive attribution
      // MED-14: Intentionally NOT copying tagResult from source recipe.
      // Tags will be regenerated when ImportManager saves the recipe,
      // ensuring fresh tags based on current tagging rules.
      final importedRecipe = Recipe(
        core: RecipeCore(
          id: _uuid.v4(), // Generate new ID for imported recipe
          title: sourceRecipe.title,
          description: sourceRecipe.description,
          ingredients: sourceRecipe.ingredients,
          instructions: sourceRecipe.instructions,
          mealType: sourceRecipe.mealType,
          portions: sourceRecipe.portions,
          timeMinutes: sourceRecipe.timeMinutes,
          rating: sourceRecipe.rating,
          personalTagIds: sourceRecipe.personalTagIds,
          sourceUrl: 'Från Butlerys arkiv',
          imageUrls: sourceRecipe.imageUrls,
          createdAt: DateTime.now(),
          updatedAt: DateTime.now(),
          createdBy: sourceRecipe.createdBy,
          isPublic: sourceRecipe.isPublic,
          lastCookedAt: sourceRecipe.lastCookedAt,
        ),
        type: sourceRecipe.type,
        socialData: sourceRecipe.socialData,
        realtimeData: sourceRecipe.realtimeData,
        offlineData: sourceRecipe.offlineData,
      );

      final warnings = <String>[];

      // Validate imported recipe
      if (!isValidRecipeName(importedRecipe.title)) {
        warnings.add('Recipe name validation failed');
      }

      if (!isValidIngredients(importedRecipe.ingredients)) {
        warnings.add('Ingredients validation failed');
      }

      return ImportResult.success(
        importedRecipe,
        warnings: warnings.isNotEmpty ? warnings : null,
        metadata: {
          'strategy': strategyName,
          'originalId': sourceRecipe.id,
          'archiveSize': archive.archivedRecipes.length,
        },
      );
    } catch (e) {
      return ImportResult.failure(
        'Error importing from archive: $e',
        metadata: {'strategy': strategyName},
      );
    }
  }

  /// Import multiple recipes by their IDs
  Future<List<ImportResult>> importMultiple(List<String> recipeIds) async {
    final results = <ImportResult>[];

    for (final recipeId in recipeIds) {
      final result = await import(recipeId);
      results.add(result);
    }

    return results;
  }

  /// Import recipes by search criteria
  Future<List<ImportResult>> importBySearch({
    String? query,
    List<String>? tags,
    String? mealType,
    int? maxTimeMinutes,
  }) async {
    final matchingRecipes = _searchArchive(
      query: query,
      tags: tags,
      mealType: mealType,
      maxTimeMinutes: maxTimeMinutes,
    );

    final results = <ImportResult>[];

    for (final recipe in matchingRecipes) {
      final result = await import(recipe.id);
      results.add(result);
    }

    return results;
  }

  /// Get all available recipes in archive
  List<Recipe> getAvailableRecipes() {
    return List.from(archive.archivedRecipes);
  }

  /// Get recipe count in archive
  int getRecipeCount() {
    return archive.archivedRecipes.length;
  }

  /// Get available tags in archive
  Set<String> getAvailableTags() {
    final tags = <String>{};
    for (final recipe in archive.archivedRecipes) {
      if (recipe.personalTagIds != null) {
        tags.addAll(recipe.personalTagIds!);
      }
    }
    return tags;
  }

  /// Get available meal types in archive
  Set<String> getAvailableMealTypes() {
    final mealTypes = <String>{};
    for (final recipe in archive.archivedRecipes) {
      mealTypes.add(recipe.mealType);
    }
    return mealTypes;
  }

  Recipe? _findRecipeById(String id) {
    try {
      return archive.archivedRecipes
          .where((recipe) => recipe.id == id)
          .firstOrNull;
    } catch (e) {
      AppLogger.warning(
          'ArchiveImportStrategy: Failed to find recipe by ID "$id": $e');
      return null;
    }
  }

  Recipe? _findRecipeByName(String name) {
    try {
      final lowerName = name.toLowerCase().trim();
      return archive.archivedRecipes
          .where((recipe) => recipe.title.toLowerCase().contains(lowerName))
          .firstOrNull;
    } catch (e) {
      AppLogger.warning(
          'ArchiveImportStrategy: Failed to find recipe by name "$name": $e');
      return null;
    }
  }

  List<Recipe> _searchArchive({
    String? query,
    List<String>? tags,
    String? mealType,
    int? maxTimeMinutes,
  }) {
    var results = List<Recipe>.from(archive.archivedRecipes);

    // Filter by search query
    if (query != null && query.trim().isNotEmpty) {
      final lowerQuery = query.toLowerCase();
      results = results.where((recipe) {
        return recipe.title.toLowerCase().contains(lowerQuery) ||
            recipe.description.toLowerCase().contains(lowerQuery) ||
            recipe.ingredients.any((ingredient) =>
                ingredient.toLowerCase().contains(lowerQuery)) ||
            (recipe.personalTagIds
                    ?.any((tag) => tag.toLowerCase().contains(lowerQuery)) ??
                false);
      }).toList();
    }

    // Filter by tags
    if (tags != null && tags.isNotEmpty) {
      results = results.where((recipe) {
        return recipe.personalTagIds != null &&
            tags.every((tag) => recipe.personalTagIds!.contains(tag));
      }).toList();
    }

    // Filter by meal type
    if (mealType != null && mealType.trim().isNotEmpty) {
      results = results
          .where((recipe) =>
              recipe.mealType.toLowerCase() == mealType.toLowerCase())
          .toList();
    }

    // Filter by max time
    if (maxTimeMinutes != null) {
      results = results
          .where((recipe) =>
              recipe.timeMinutes != null &&
              recipe.timeMinutes! <= maxTimeMinutes)
          .toList();
    }

    return results;
  }
}
