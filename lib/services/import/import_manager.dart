/// 🔍 AI INFO BLOCK:
/// Component: Import Manager - Coordinates different import strategies
/// File: lib/services/import/import_manager.dart
/// Quick Guide: Strategy pattern coordinator for recipe imports with auto-detection
/// Dependencies IN: Import strategies, PersonalRecipeOperations
/// Dependencies OUT: Used by import ViewModels and UI components
/// Data flow: Input -> Strategy selection -> Strategy execution -> Recipe creation
/// State management: Stateless coordination with strategy delegation
/// Purpose: Unified import interface with automatic strategy selection
/// Common issues: Strategy selection logic, error handling across strategies
/// Test coverage: Unit tests for strategy selection and coordination
/// Performance: Fast strategy selection with efficient delegation
/// Analytics: Import strategy usage, success rates by strategy
/// Code smells: None - follows strategy pattern with good separation
/// Connected to: Import ViewModels, PersonalRecipeOperations, Import strategies
/// Used in phases: Phase 5 - Service Consolidation (import strategy pattern)

import '../../models/recipe.dart';
import '../unified/operations/personal_recipe_operations.dart';
import 'import_strategy.dart';
import 'text_import_strategy.dart';
import 'archive_import_strategy.dart';

/// Import manager that coordinates different import strategies
/// 
/// Features:
/// - Automatic strategy selection based on input
/// - Fallback strategy chain
/// - Batch import support
/// - Import validation and error handling
/// - Integration with PersonalRecipeOperations
class ImportManager {
  final PersonalRecipeOperations _personalOperations;
  final List<ImportStrategy> _strategies = [];

  ImportManager(this._personalOperations) {
    _initializeStrategies();
  }

  void _initializeStrategies() {
    // Register available import strategies
    _strategies.addAll([
      ArchiveImportStrategy(),
      TextImportStrategy(),
      // Add more strategies here as they are implemented:
      // UrlImportStrategy(),
      // PhotoImportStrategy(),
      // FileImportStrategy(),
    ]);
  }

  /// Get all available import strategies
  List<ImportStrategy> get availableStrategies => List.unmodifiable(_strategies);

  /// Auto-detect and import recipe from input
  Future<ImportManagerResult> autoImport(String input, {
    ImportStrategy? preferredStrategy,
    Map<String, dynamic>? options,
  }) async {
    try {
      // Try preferred strategy first if provided
      if (preferredStrategy != null && preferredStrategy.canHandle(input)) {
        final result = await _importWithStrategy(preferredStrategy, input, options);
        if (result.isSuccess) {
          return result;
        }
      }

      // Try all compatible strategies
      for (final strategy in _strategies) {
        if (strategy.canHandle(input)) {
          final result = await _importWithStrategy(strategy, input, options);
          if (result.isSuccess) {
            return result;
          }
        }
      }

      // No strategy could handle the input
      return ImportManagerResult.failure(
        'No import strategy could handle the provided input',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    } catch (e) {
      return ImportManagerResult.failure(
        'Import manager error: $e',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    }
  }

  /// Import using a specific strategy
  Future<ImportManagerResult> importWithStrategy(
    String strategyName,
    String input, {
    Map<String, dynamic>? options,
  }) async {
    final strategy = _strategies
        .where((s) => s.strategyName == strategyName)
        .firstOrNull;

    if (strategy == null) {
      return ImportManagerResult.failure(
        'Strategy not found: $strategyName',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    }

    return await _importWithStrategy(strategy, input, options);
  }

  /// Batch import multiple inputs
  Future<BatchImportResult> batchImport(
    List<String> inputs, {
    ImportStrategy? preferredStrategy,
    Map<String, dynamic>? options,
  }) async {
    final results = <ImportManagerResult>[];
    final recipes = <Recipe>[];
    final errors = <String>[];

    for (final input in inputs) {
      final result = await autoImport(
        input,
        preferredStrategy: preferredStrategy,
        options: options,
      );

      results.add(result);

      if (result.isSuccess && result.recipe != null) {
        recipes.add(result.recipe!);
      } else {
        errors.add(result.errorMessage ?? 'Unknown error');
      }
    }

    return BatchImportResult(
      results: results,
      successfulRecipes: recipes,
      errors: errors,
      totalProcessed: inputs.length,
      successCount: recipes.length,
      failureCount: errors.length,
    );
  }

  /// Get strategies that can handle the given input
  List<ImportStrategy> getCompatibleStrategies(String input) {
    return _strategies.where((strategy) => strategy.canHandle(input)).toList();
  }

  /// Validate input for import
  bool validateInput(String input, {ImportStrategy? strategy}) {
    if (strategy != null) {
      return strategy.validateInput(input);
    }

    // Check if any strategy can validate the input
    return _strategies.any((s) => s.validateInput(input));
  }

  /// Get import suggestions for input
  List<ImportSuggestion> getImportSuggestions(String input) {
    final suggestions = <ImportSuggestion>[];

    for (final strategy in _strategies) {
      if (strategy.canHandle(input)) {
        suggestions.add(ImportSuggestion(
          strategy: strategy,
          confidence: _calculateConfidence(strategy, input),
          description: strategy.description,
        ));
      }
    }

    // Sort by confidence (highest first)
    suggestions.sort((a, b) => b.confidence.compareTo(a.confidence));

    return suggestions;
  }

  // ===== PRIVATE METHODS =====

  Future<ImportManagerResult> _importWithStrategy(
    ImportStrategy strategy,
    String input,
    Map<String, dynamic>? options,
  ) async {
    try {
      // Execute import strategy
      final importResult = await strategy.import(input, options: options);

      if (!importResult.isSuccess) {
        return ImportManagerResult.failure(
          importResult.errorMessage ?? 'Import failed',
          strategy: strategy.strategyName,
          warnings: importResult.warnings,
        );
      }

      if (importResult.recipe == null) {
        return ImportManagerResult.failure(
          'Import successful but no recipe returned',
          strategy: strategy.strategyName,
        );
      }

      // Save recipe using PersonalRecipeOperations
      final saveResult = await _personalOperations.addLegacyRecipe(importResult.recipe!);

      if (!saveResult.isSuccess) {
        return ImportManagerResult.failure(
          'Failed to save imported recipe: ${saveResult.message}',
          strategy: strategy.strategyName,
          recipe: importResult.recipe,
        );
      }

      return ImportManagerResult.success(
        importResult.recipe!,
        strategy: strategy.strategyName,
        warnings: importResult.warnings,
        metadata: importResult.metadata,
      );
    } catch (e) {
      return ImportManagerResult.failure(
        'Strategy execution error: $e',
        strategy: strategy.strategyName,
      );
    }
  }

  double _calculateConfidence(ImportStrategy strategy, String input) {
    // Basic confidence calculation - can be enhanced
    if (!strategy.canHandle(input)) return 0.0;
    
    // Archive import has highest confidence for known IDs
    if (strategy is ArchiveImportStrategy) {
      return 0.9;
    }
    
    // Text import is flexible but lower confidence
    if (strategy is TextImportStrategy) {
      return 0.6;
    }
    
    return 0.5; // Default confidence
  }
}

/// Result of import manager operation
class ImportManagerResult {
  final bool isSuccess;
  final Recipe? recipe;
  final String? errorMessage;
  final String? strategy;
  final List<String>? warnings;
  final Map<String, dynamic>? metadata;
  final List<String>? availableStrategies;

  ImportManagerResult.success(
    this.recipe, {
    this.strategy,
    this.warnings,
    this.metadata,
  })  : isSuccess = true,
        errorMessage = null,
        availableStrategies = null;

  ImportManagerResult.failure(
    this.errorMessage, {
    this.strategy,
    this.warnings,
    this.recipe,
    this.availableStrategies,
  })  : isSuccess = false,
        metadata = null;

  bool get hasWarnings => warnings != null && warnings!.isNotEmpty;
  bool get hasMetadata => metadata != null && metadata!.isNotEmpty;
  
  // Compatibility getters for ViewModels
  List<Recipe> get importedRecipes => recipe != null ? [recipe!] : [];
  String? get error => errorMessage;
}

/// Result of batch import operation
class BatchImportResult {
  final List<ImportManagerResult> results;
  final List<Recipe> successfulRecipes;
  final List<String> errors;
  final int totalProcessed;
  final int successCount;
  final int failureCount;

  BatchImportResult({
    required this.results,
    required this.successfulRecipes,
    required this.errors,
    required this.totalProcessed,
    required this.successCount,
    required this.failureCount,
  });

  double get successRate => totalProcessed > 0 ? successCount / totalProcessed : 0.0;
  bool get hasErrors => errors.isNotEmpty;
  bool get allSuccessful => successCount == totalProcessed;
}

/// Import suggestion with confidence rating
class ImportSuggestion {
  final ImportStrategy strategy;
  final double confidence;
  final String description;

  ImportSuggestion({
    required this.strategy,
    required this.confidence,
    required this.description,
  });
}