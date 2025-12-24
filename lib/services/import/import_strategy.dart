import 'package:butlery/models/recipe_unified.dart';

/// Strategy pattern interface for recipe import (text, URL, photo, archive).
abstract class ImportStrategy {
  String get strategyName;
  bool canHandle(String input);
  Future<ImportResult> import(String input, {Map<String, dynamic>? options});
  bool validateInput(String input);
  String get inputExample;
  String get description;
}

/// Result of an import operation
class ImportResult {
  final bool isSuccess;
  final Recipe? recipe;
  final String? errorMessage;
  final List<String>? warnings;
  final Map<String, dynamic>? metadata;
  final bool needsAssistance;
  final String? extractedText;
  final String? suggestedTitle;
  final List<int>? likelyIngredientLines;

  ImportResult.success(this.recipe, {this.warnings, this.metadata})
      : isSuccess = true,
        errorMessage = null,
        needsAssistance = false,
        extractedText = null,
        suggestedTitle = null,
        likelyIngredientLines = null;

  ImportResult.failure(this.errorMessage, {this.warnings, this.metadata})
      : isSuccess = false,
        recipe = null,
        needsAssistance = false,
        extractedText = null,
        suggestedTitle = null,
        likelyIngredientLines = null;

  ImportResult.assistance({
    required this.extractedText,
    this.suggestedTitle,
    this.likelyIngredientLines,
    this.metadata,
  })  : isSuccess = false,
        needsAssistance = true,
        recipe = null,
        errorMessage = null,
        warnings = null;

  bool get hasWarnings => warnings != null && warnings!.isNotEmpty;
  bool get hasMetadata => metadata != null && metadata!.isNotEmpty;
}

mixin ImportValidationMixin {
  bool isValidRecipeName(String name) {
    return name.trim().isNotEmpty && name.trim().length >= 2;
  }

  bool isValidIngredients(List<String> ingredients) {
    return ingredients.isNotEmpty &&
        ingredients.any((ingredient) => ingredient.trim().isNotEmpty);
  }

  bool isValidInstructions(List<String> instructions) {
    return instructions.isNotEmpty &&
        instructions.any((instruction) => instruction.trim().isNotEmpty);
  }

  String normalizeText(String input) {
    return input
        .replaceAll(
            RegExp(
              r'[\u{1F300}-\u{1F9FF}]|' // Misc Symbols, Emoticons, Dingbats
              r'[\u{1FA00}-\u{1FAFF}]|' // Symbols Extended-A (includes 🫑)
              r'[\u{2600}-\u{26FF}]|' // Misc Symbols (☀️, ⚡, etc.)
              r'[\u{2700}-\u{27BF}]|' // Dingbats
              r'[\u{FE00}-\u{FE0F}]|' // Variation Selectors
              r'\u{200D}', // Zero Width Joiner
              unicode: true,
            ),
            '') // Remove emojis first
        .split('\n') // Process line by line to preserve newlines
        .map((line) => line
            .replaceAll(RegExp(r'[ \t]+'), ' ')
            .trim()) // Normalize spaces/tabs per line
        .join('\n') // Rejoin with newlines
        .trim();
  }

  int? extractNumber(String text) {
    final match = RegExp(r'\d+').firstMatch(text);
    return match != null ? int.tryParse(match.group(0)!) : null;
  }

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
