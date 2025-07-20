/// 🔍 AI INFO BLOCK:
/// Component: Recipe Hive repository
/// File: repositories/hive/recipe_hive_repository.dart
/// Quick Guide: Persists Recipe objects using Hive
/// Dependencies IN: hive_flutter, models/recipe.dart
/// Dependencies OUT: services needing offline recipes
/// Data flow: init -> CRUD via BaseHiveRepository
/// State management: relies on Hive for persistence
/// Purpose: Separate data layer for recipes
/// Common issues: adapter registration must match typeId
/// Test coverage: none yet
/// Performance: limited by Hive I/O
/// Analytics: none
/// Code smells: incomplete offline features
/// Connected to: base_hive_repository.dart
/// Used in phases: offline storage prototype

import '../../models/recipe_unified.dart';
import 'base_hive_repository.dart';

/// Repository för att lagra Recipe-objekt i Hive.
class RecipeHiveRepository extends BaseHiveRepository<Recipe> {
  RecipeHiveRepository() : super('recipes');

  @override
  Future<void> init({String? userId}) async {
    // TODO: Register unified Recipe adapter when available
    // For now, using JSON serialization instead
    await super.init(userId: userId);
  }

  /// Initialiserar med aktuell användares ID för säker user-specifik cache
  Future<void> initWithUser(String userId) async {
    await init(userId: userId);
  }
}

