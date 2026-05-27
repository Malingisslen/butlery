// lib/services/import/import_manager_result.dart

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/import_strategy.dart';
import 'package:butlery/services/import/models/rate_limit_models.dart';

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

  /// Structured rate-limit denial — present when [strategy] is `rate_limited`.
  /// BUT-1144: lets callers preserve the rate limiter's real `retryAfter` /
  /// `limitType` / `suggestedAction` instead of synthesising defaults from
  /// the error string.
  final RateLimitDenied? rateLimitDenied;

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
        likelyIngredientLines = null,
        rateLimitDenied = null;

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
        likelyIngredientLines = null,
        rateLimitDenied = null;

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
        availableStrategies = null,
        rateLimitDenied = null;

  /// Rate-limit denial — surfaces the structured [RateLimitDenied] so the
  /// ViewModel can render the limiter's real `retryAfter` / `limitType` /
  /// `suggestedAction` instead of fabricating defaults from the message.
  /// (BUT-1144)
  ImportManagerResult.rateLimit(RateLimitDenied details)
      : isSuccess = false,
        recipe = null,
        errorMessage = details.message,
        strategy = 'rate_limited',
        warnings = null,
        metadata = null,
        availableStrategies = null,
        needsAssistance = false,
        extractedText = null,
        suggestedTitle = null,
        thumbnailUrl = null,
        sourceUrl = null,
        likelyIngredientLines = null,
        rateLimitDenied = details;

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
