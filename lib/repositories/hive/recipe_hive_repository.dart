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

import 'package:hive_flutter/hive_flutter.dart';

import '../../models/recipe.dart';
import 'base_hive_repository.dart';

/// Repository för att lagra Recipe-objekt i Hive.
class RecipeHiveRepository extends BaseHiveRepository<Recipe> {
  RecipeHiveRepository() : super('recipes');

  @override
  Future<void> init() async {
    // Registrera adapter om nödvändigt
    if (!Hive.isAdapterRegistered(0)) {
      Hive.registerAdapter(RecipeAdapter());
    }
    await super.init();
  }

  // TODO: Använd user-specifika nycklar för komplett offline-stöd
}

