// lib/services/import/import_manager_result.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_strategy.dart';

/// Result of import manager operation
class ImportManagerResult {
  final bool isSuccess;
  final Recipe? recipe;
  final String? errorMessage;
  final String? strategy;
  final List<String>? warnings;
  final Map<String, dynamic>? metadata;
  final List<String>? availableStrategies;

  /// Whether this result requires user assistance to complete.
  final bool needsAssistance;

  /// Extracted text for user-assisted import (only set when needsAssistance=true).
  final String? extractedText;

  /// Suggested title for user-assisted import.
  final String? suggestedTitle;

  /// Thumbnail URL for visual reference.
  final String? thumbnailUrl;

  /// Source URL for the import.
  final String? sourceUrl;

  /// Pre-detected ingredient line indices.
  final List<int>? likelyIngredientLines;

  ImportManagerResult.success(
    this.recipe, {
    this.strategy,
    this.warnings,
    this.metadata,
  })  : isSuccess = true,
        errorMessage = null,
        availableStrategies = null,
        needsAssistance = false,
        extractedText = null,
        suggestedTitle = null,
        thumbnailUrl = null,
        sourceUrl = null,
        likelyIngredientLines = null;

  ImportManagerResult.failure(
    this.errorMessage, {
    this.strategy,
    this.warnings,
    this.recipe,
    this.availableStrategies,
  })  : isSuccess = false,
        metadata = null,
        needsAssistance = false,
        extractedText = null,
        suggestedTitle = null,
        thumbnailUrl = null,
        sourceUrl = null,
        likelyIngredientLines = null;

  /// Result indicating user assistance is needed.
  ImportManagerResult.assistance({
    required this.extractedText,
    this.suggestedTitle,
    this.thumbnailUrl,
    this.sourceUrl,
    this.likelyIngredientLines,
    this.strategy,
    this.metadata,
  })  : isSuccess = false,
        needsAssistance = true,
        recipe = null,
        errorMessage = null,
        warnings = null,
        availableStrategies = null;

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
