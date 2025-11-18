/// Import manager with strategy pattern for multi-format imports (text, archive, URL, file) and batch processing.
/// ```dart
/// final im = ImportManager(ops); await im.autoImport(text);

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/unified/operations/personal_recipe_operations.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:butlery/services/import/archive_import_strategy.dart';
import 'package:butlery/services/import/file_import_strategy.dart';
import 'package:butlery/services/import/url_import_strategy.dart';
import 'package:butlery/services/import/photo_import_strategy.dart';

/// Import manager coordinating multiple import strategies with auto-selection, fallback, and batch processing.
class ImportManager {
  final PersonalRecipeOperations _personalOperations;
  final List<ImportStrategy> _strategies = [];

  ImportManager(this._personalOperations) {
    _initializeStrategies();
  }

  void _initializeStrategies() {
    // Register available import strategies in priority order
    _strategies.addAll([
      ArchiveImportStrategy(), // 1. Try archive first (fast, pre-validated)
      UrlImportStrategy(), // 2. Try URL import (web scraping)
      TextImportStrategy(), // 3. Try text parsing (fallback for plain text)
      FileImportStrategy(), // 4. File import (explicit file selection)
      PhotoImportStrategy(), // 5. Photo import (OCR extraction)
    ]);
  }

  /// Get all available import strategies
  List<ImportStrategy> get availableStrategies =>
      List.unmodifiable(_strategies);

  /// Auto-detects strategy and parses recipe WITHOUT saving (for preview/validation).
  /// ```dart
  /// final r = await im.autoParseOnly(text); if (r.isSuccess) showPreview(r.recipe!);
  Future<ImportManagerResult> autoParseOnly(
    String input, {
    ImportStrategy? preferredStrategy,
    Map<String, dynamic>? options,
  }) async {
    try {
      // Try preferred strategy first if provided
      if (preferredStrategy != null && preferredStrategy.canHandle(input)) {
        final result =
            await _parseWithStrategy(preferredStrategy, input, options);
        if (result.isSuccess) {
          return result;
        }
      }

      // Try all compatible strategies
      for (final strategy in _strategies) {
        if (strategy.canHandle(input)) {
          final result = await _parseWithStrategy(strategy, input, options);
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

  /// Auto-detects strategy and imports recipe with fallback (tries all compatible strategies).
  /// ```dart
  /// final r = await im.autoImport(content, preferredStrategy: textStrategy);
  Future<ImportManagerResult> autoImport(
    String input, {
    ImportStrategy? preferredStrategy,
    Map<String, dynamic>? options,
  }) async {
    try {
      // Try preferred strategy first if provided
      if (preferredStrategy != null && preferredStrategy.canHandle(input)) {
        final result =
            await _importWithStrategy(preferredStrategy, input, options);
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
    final strategy =
        _strategies.where((s) => s.strategyName == strategyName).firstOrNull;

    if (strategy == null) {
      return ImportManagerResult.failure(
        'Strategy not found: $strategyName',
        availableStrategies: _strategies.map((s) => s.strategyName).toList(),
      );
    }

    return await _importWithStrategy(strategy, input, options);
  }

  /// Processes multiple recipe imports in batch with comprehensive progress tracking and error aggregation.
  /// This method provides efficient batch processing for multiple recipe imports with individual strategy
  /// selection, comprehensive error collection, and detailed result reporting. It processes each input
  /// independently while aggregating results for comprehensive batch operation feedback and analytics.
  /// [inputs] List of recipe content in various supported formats for batch processing
  /// [preferredStrategy] Optional strategy to prefer for all imports in the batch
  /// [options] Optional configuration parameters applied to all import operations
  /// Returns [BatchImportResult] with individual results, success statistics, and error aggregation
  /// **Batch Processing Features:**
  /// - **Individual Processing**: Each input processed independently with optimal strategy selection
  /// - **Error Isolation**: Failed imports don't affect successful imports in the same batch
  /// - **Progress Tracking**: Detailed statistics on success/failure rates and processing progress
  /// - **Result Aggregation**: Comprehensive collection of successful recipes and error information
  /// - **Strategy Analytics**: Tracking of strategy usage and success rates across batch operations
  /// **Performance Optimization:**
  /// - Sequential processing prevents resource contention and ensures stability
  /// - Memory-efficient processing with immediate result collection and cleanup
  /// - Strategy reuse across batch items for optimal performance
  /// - Comprehensive error handling prevents batch failure from individual errors
  /// **Result Management:**
  /// - Separate collections for successful recipes and error messages
  /// - Detailed statistics including success rate and processing counts
  /// - Individual result preservation for detailed analysis and debugging
  /// - Strategy tracking for batch operation analytics and optimization
  /// **Usage Examples:**
  /// ```dart
  /// // Batch import with progress tracking
  /// final batchResult = await importManager.batchImport(recipeTexts);
  /// // Display batch results
  /// print('Imported ${batchResult.successCount}/${batchResult.totalProcessed} recipes');
  /// print('Success rate: ${(batchResult.successRate * 100).toInt()}%');
  /// // Handle successful imports
  /// for (final recipe in batchResult.successfulRecipes) {
  ///   addToRecipeCollection(recipe);
  /// }
  /// // Handle errors with detailed feedback
  /// if (batchResult.hasErrors) {
  ///   showBatchErrors(batchResult.errors);
  /// }
  /// ```
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

  /// Get text import strategy for direct usage
  TextImportStrategy getTextImportStrategy() {
    final textStrategy =
        _strategies.whereType<TextImportStrategy>().firstOrNull;

    if (textStrategy == null) {
      throw StateError('TextImportStrategy not found in available strategies');
    }

    return textStrategy;
  }

  /// Save imported recipe using PersonalRecipeOperations
  Future<ImportManagerResult> saveImportedRecipe(Recipe recipe) async {
    try {
      final saveResult = await _personalOperations.addUnifiedRecipe(recipe);

      if (saveResult.isSuccess) {
        return ImportManagerResult.success(
          recipe,
          strategy: 'direct_save',
        );
      } else {
        return ImportManagerResult.failure(
          'Failed to save recipe: ${saveResult.message}',
          strategy: 'direct_save',
        );
      }
    } catch (e) {
      return ImportManagerResult.failure(
        'Error saving recipe: $e',
        strategy: 'direct_save',
      );
    }
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
      final saveResult =
          await _personalOperations.addUnifiedRecipe(importResult.recipe!);

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

  /// Parse with strategy without saving - returns recipe in memory only
  Future<ImportManagerResult> _parseWithStrategy(
    ImportStrategy strategy,
    String input,
    Map<String, dynamic>? options,
  ) async {
    try {
      // Execute import strategy to parse recipe
      final importResult = await strategy.import(input, options: options);

      if (!importResult.isSuccess) {
        return ImportManagerResult.failure(
          importResult.errorMessage ?? 'Parse failed',
          strategy: strategy.strategyName,
          warnings: importResult.warnings,
        );
      }

      if (importResult.recipe == null) {
        return ImportManagerResult.failure(
          'Parse successful but no recipe returned',
          strategy: strategy.strategyName,
        );
      }

      // Return parsed recipe WITHOUT saving to storage
      return ImportManagerResult.success(
        importResult.recipe!,
        strategy: strategy.strategyName,
        warnings: importResult.warnings,
        metadata: importResult.metadata,
      );
    } catch (e) {
      return ImportManagerResult.failure(
        'Parse execution error: $e',
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

  double get successRate =>
      totalProcessed > 0 ? successCount / totalProcessed : 0.0;
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
