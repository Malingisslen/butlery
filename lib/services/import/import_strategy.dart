/// 🔍 AI INFO BLOCK:
/// Component: Import Strategy Interface - Strategy pattern for recipe import
/// File: lib/services/import/import_strategy.dart
/// Quick Guide: Base interface for different import strategies (text, URL, photo, archive)
/// Dependencies IN: Recipe model, RecipeOperationResult
/// Dependencies OUT: Used by import strategies and import ViewModels
/// Data flow: Import ViewModels -> Import Strategies -> Import Methods
/// State management: Stateless strategy pattern
/// Purpose: Unified interface for all import methods with clean separation
/// Common issues: Different data formats, validation requirements
/// Test coverage: Unit tests for each strategy implementation
/// Performance: Efficient parsing and validation per strategy type
/// Analytics: Import success/failure rates, import source tracking
/// Code smells: None - follows strategy pattern
/// Connected to: Import ViewModels, PersonalRecipeOperations
/// Used in phases: Phase 5 - Service Consolidation (import strategy pattern)

import 'package:butlery/models/recipe_unified.dart';

/// Base interface for recipe import strategies
/// Implements the Strategy pattern for different import methods:
/// - Text import (social media, manual text)
/// - URL import (web scraping)
/// - Photo import (OCR processing)
/// - Archive import (Butlery recipe collection)
/// - File import (JSON, other formats)
abstract class ImportStrategy {
  /// The name of this import strategy
  String get strategyName;

  /// Whether this strategy can handle the given input
  bool canHandle(String input);

  /// Import recipe from the given input
  Future<ImportResult> import(String input, {Map<String, dynamic>? options});

  /// Validate input format before attempting import
  bool validateInput(String input);

  /// Get example input format for this strategy
  String get inputExample;

  /// Get description of what this strategy handles
  String get description;
}

/// Result of an import operation
class ImportResult {
  final bool isSuccess;
  final Recipe? recipe;
  final String? errorMessage;
  final List<String>? warnings;
  final Map<String, dynamic>? metadata;

  ImportResult.success(this.recipe, {this.warnings, this.metadata})
      : isSuccess = true,
        errorMessage = null;

  ImportResult.failure(this.errorMessage, {this.warnings, this.metadata})
      : isSuccess = false,
        recipe = null;

  bool get hasWarnings => warnings != null && warnings!.isNotEmpty;
  bool get hasMetadata => metadata != null && metadata!.isNotEmpty;
}

/// Mixin for common import functionality
mixin ImportValidationMixin {
  /// Validate recipe name
  bool isValidRecipeName(String name) {
    return name.trim().isNotEmpty && name.trim().length >= 2;
  }

  /// Validate ingredients list
  bool isValidIngredients(List<String> ingredients) {
    return ingredients.isNotEmpty &&
        ingredients.any((ingredient) => ingredient.trim().isNotEmpty);
  }

  /// Validate instructions list
  bool isValidInstructions(List<String> instructions) {
    return instructions.isNotEmpty &&
        instructions.any((instruction) => instruction.trim().isNotEmpty);
  }

  /// Clean and normalize text input (preserves newlines for line-by-line parsing)
  String normalizeText(String input) {
    // Remove emojis and normalize whitespace WHILE PRESERVING NEWLINES
    return input
        .replaceAll(RegExp(r'[\u{1F300}-\u{1F9FF}]', unicode: true),
            '') // Remove emojis first
        .split('\n') // Process line by line to preserve newlines
        .map((line) => line
            .replaceAll(RegExp(r'[ \t]+'), ' ')
            .trim()) // Normalize spaces/tabs per line
        .join('\n') // Rejoin with newlines
        .trim();
  }

  /// Extract numeric value from text (for portions, time, etc.)
  int? extractNumber(String text) {
    final match = RegExp(r'\d+').firstMatch(text);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

  /// Extract rating from text (1.0-5.0)
  double? extractRating(String text) {
    final match =
        RegExp(r'(\d+(?:\.\d+)?)\s*(?:av\s*5|/5|\*|⭐)').firstMatch(text);
    if (match != null) {
      final rating = double.tryParse(match.group(1)!);
      return rating != null && rating >= 1.0 && rating <= 5.0 ? rating : null;
    }
    return null;
  }
}
