import 'package:butlery/models/parsing/field_correction.dart';
import 'package:butlery/models/parsing/ingredient_correction.dart';
import 'package:butlery/models/parsing/instruction_correction.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart' as parsing;
import 'package:butlery/models/parsing/parsed_recipe.dart';
import 'package:butlery/models/parsing/parsing_correction.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/utils/text/ingredient_parser.dart' as util;

/// Calculates the diff between a parsed recipe and user's corrected version.
///
/// Used for training data collection - captures what the parser got wrong
/// so we can improve parsing heuristics and train ML models.
class RecipeDiffCalculator {
  /// Calculate diff between parsed and corrected recipe.
  ///
  /// Returns null if no meaningful corrections were made.
  ParsingCorrection? calculateDiff({
    required ParsedRecipe original,
    required Recipe corrected,
    required String userId,
  }) {
    // Calculate individual field diffs
    final titleDiff = FieldCorrection.create(
      original: original.title.value,
      corrected: corrected.title,
    );

    final portionsDiff = FieldCorrection.createFromInt(
      original: original.portions.value,
      corrected: corrected.portions,
    );

    final timeDiff = FieldCorrection.createFromDuration(
      original: original.totalTime.value,
      corrected: corrected.timeMinutes != null
          ? Duration(minutes: corrected.timeMinutes!)
          : null,
    );

    // Calculate ingredient diffs
    final ingredientDiffs = _diffIngredients(
      original.ingredients.value ?? [],
      corrected.ingredients,
    );

    // Calculate instruction diffs
    final instructionDiffs = _diffInstructions(
      original.instructions.value ?? [],
      corrected.instructions,
    );

    // Count total corrections
    final totalCorrections = (titleDiff != null ? 1 : 0) +
        (portionsDiff != null ? 1 : 0) +
        (timeDiff != null ? 1 : 0) +
        ingredientDiffs.length +
        instructionDiffs.length;

    // Return null if no corrections
    if (totalCorrections == 0) {
      return null;
    }

    // Build correction record
    return ParsingCorrection.create(
      recipeId: corrected.id,
      userId: userId,
      source: original.metadata.source,
      domain: original.metadata.domain,
      successfulTier: original.metadata.successfulTier,
      originalQuality: original.overallQuality,
      titleCorrection: titleDiff,
      portionsCorrection: portionsDiff,
      timeCorrection: timeDiff,
      ingredientCorrections: ingredientDiffs,
      instructionCorrections: instructionDiffs,
    );
  }

  /// Diff ingredient lists.
  ///
  /// Strategy:
  /// 1. Parse corrected strings to extract quantity/unit/name
  /// 2. Match by fuzzy name similarity
  /// 3. Detect added/removed/modified ingredients
  List<IngredientCorrection> _diffIngredients(
    List<parsing.ParsedIngredient> original,
    List<String> corrected,
  ) {
    final corrections = <IngredientCorrection>[];
    final matchedOriginal = <int>{};
    final matchedCorrected = <int>{};

    // Parse corrected strings
    final correctedParsed = corrected
        .map((line) => (
              line: line,
              parsed: util.IngredientParser.parseIngredient(line),
            ))
        .toList();

    // Step 1: Match by exact name
    for (var i = 0; i < original.length; i++) {
      for (var j = 0; j < correctedParsed.length; j++) {
        if (matchedCorrected.contains(j)) continue;

        if (_namesMatch(original[i].name, correctedParsed[j].parsed.name,
            threshold: 0.9)) {
          matchedOriginal.add(i);
          matchedCorrected.add(j);

          // Check if anything changed
          final diff = _compareIngredient(
            originalIndex: i,
            correctedIndex: j,
            original: original[i],
            correctedLine: correctedParsed[j].line,
            correctedParsed: correctedParsed[j].parsed,
          );
          if (diff != null) {
            corrections.add(diff);
          }
          break;
        }
      }
    }

    // Step 2: Match by fuzzy name (for renamed ingredients)
    for (var i = 0; i < original.length; i++) {
      if (matchedOriginal.contains(i)) continue;

      for (var j = 0; j < correctedParsed.length; j++) {
        if (matchedCorrected.contains(j)) continue;

        if (_namesMatch(original[i].name, correctedParsed[j].parsed.name,
            threshold: 0.5)) {
          matchedOriginal.add(i);
          matchedCorrected.add(j);

          // This is likely a name fix
          final diff = _compareIngredient(
            originalIndex: i,
            correctedIndex: j,
            original: original[i],
            correctedLine: correctedParsed[j].line,
            correctedParsed: correctedParsed[j].parsed,
          );
          if (diff != null) {
            corrections.add(diff);
          }
          break;
        }
      }
    }

    // Step 3: Unmatched original = removed
    for (var i = 0; i < original.length; i++) {
      if (!matchedOriginal.contains(i)) {
        corrections.add(IngredientCorrection.removed(
          originalIndex: i,
          originalLine: original[i].originalLine,
          originalQuantity: original[i].quantity,
          originalUnit: original[i].unit,
          originalName: original[i].name,
        ));
      }
    }

    // Step 4: Unmatched corrected = added
    for (var j = 0; j < correctedParsed.length; j++) {
      if (!matchedCorrected.contains(j)) {
        corrections.add(IngredientCorrection.added(
          correctedIndex: j,
          correctedLine: correctedParsed[j].line,
        ));
      }
    }

    return corrections;
  }

  /// Compare a matched ingredient pair.
  IngredientCorrection? _compareIngredient({
    required int originalIndex,
    required int correctedIndex,
    required parsing.ParsedIngredient original,
    required String correctedLine,
    required util.ParsedIngredient correctedParsed,
  }) {
    // Compare fields
    final quantityChanged = !_quantitiesEqual(
      original.quantity,
      correctedParsed.quantity.toString(),
    );
    final unitChanged = !_unitsEqual(
      original.unit,
      correctedParsed.unit,
    );
    final nameChanged = !_namesMatch(
      original.name,
      correctedParsed.name,
      threshold: 0.9,
    );

    // Check if only position changed
    final positionChanged = originalIndex != correctedIndex;
    final contentChanged = quantityChanged || unitChanged || nameChanged;

    if (!contentChanged && !positionChanged) {
      return null; // No change at all
    }

    if (!contentChanged && positionChanged) {
      // Only reordering - low priority
      return IngredientCorrection(
        type: IngredientCorrectionType.reordered,
        originalIndex: originalIndex,
        correctedIndex: correctedIndex,
        originalLine: original.originalLine,
        correctedLine: correctedLine,
      );
    }

    // Content changed
    return IngredientCorrection.modified(
      originalIndex: originalIndex,
      correctedIndex: correctedIndex,
      originalLine: original.originalLine,
      correctedLine: correctedLine,
      originalQuantity: original.quantity,
      originalUnit: original.unit,
      originalName: original.name,
      quantityChanged: quantityChanged,
      unitChanged: unitChanged,
      nameChanged: nameChanged,
    );
  }

  /// Diff instruction lists.
  List<InstructionCorrection> _diffInstructions(
    List<String> original,
    List<String> corrected,
  ) {
    final corrections = <InstructionCorrection>[];
    final matchedOriginal = <int>{};
    final matchedCorrected = <int>{};

    // Step 1: Exact matches
    for (var i = 0; i < original.length; i++) {
      for (var j = 0; j < corrected.length; j++) {
        if (matchedCorrected.contains(j)) continue;

        if (_textsMatch(original[i], corrected[j], threshold: 0.95)) {
          matchedOriginal.add(i);
          matchedCorrected.add(j);

          // Check for reordering
          if (i != j) {
            corrections.add(InstructionCorrection.reordered(
              originalIndex: i,
              correctedIndex: j,
              text: original[i],
            ));
          }
          break;
        }
      }
    }

    // Step 2: Fuzzy matches (modified text)
    for (var i = 0; i < original.length; i++) {
      if (matchedOriginal.contains(i)) continue;

      for (var j = 0; j < corrected.length; j++) {
        if (matchedCorrected.contains(j)) continue;

        if (_textsMatch(original[i], corrected[j], threshold: 0.5)) {
          matchedOriginal.add(i);
          matchedCorrected.add(j);

          corrections.add(InstructionCorrection.modified(
            originalIndex: i,
            correctedIndex: j,
            originalText: original[i],
            correctedText: corrected[j],
          ));
          break;
        }
      }
    }

    // Step 3: Unmatched original = removed
    for (var i = 0; i < original.length; i++) {
      if (!matchedOriginal.contains(i)) {
        corrections.add(InstructionCorrection.removed(
          originalIndex: i,
          originalText: original[i],
        ));
      }
    }

    // Step 4: Unmatched corrected = added
    for (var j = 0; j < corrected.length; j++) {
      if (!matchedCorrected.contains(j)) {
        corrections.add(InstructionCorrection.added(
          correctedIndex: j,
          correctedText: corrected[j],
        ));
      }
    }

    return corrections;
  }

  /// Check if two ingredient names match with fuzzy threshold.
  bool _namesMatch(String? a, String? b, {required double threshold}) {
    if (a == null || b == null) return false;
    if (a.isEmpty || b.isEmpty) return false;

    final normalizedA = _normalizeName(a);
    final normalizedB = _normalizeName(b);

    if (normalizedA == normalizedB) return true;

    // Simple containment check
    if (normalizedA.contains(normalizedB) ||
        normalizedB.contains(normalizedA)) {
      return true;
    }

    // Levenshtein-based similarity
    final similarity = _calculateSimilarity(normalizedA, normalizedB);
    return similarity >= threshold;
  }

  /// Check if two instruction texts match.
  bool _textsMatch(String a, String b, {required double threshold}) {
    final normalizedA = a.trim().toLowerCase();
    final normalizedB = b.trim().toLowerCase();

    if (normalizedA == normalizedB) return true;

    final similarity = _calculateSimilarity(normalizedA, normalizedB);
    return similarity >= threshold;
  }

  /// Check if two quantities are equal (handles string/number comparison).
  bool _quantitiesEqual(String? a, String? b) {
    if (a == b) return true;
    if (a == null || b == null) return false;

    // Normalize and compare as numbers
    final numA = double.tryParse(a.replaceAll(',', '.'));
    final numB = double.tryParse(b.replaceAll(',', '.'));

    if (numA != null && numB != null) {
      return (numA - numB).abs() < 0.01;
    }

    return a.trim().toLowerCase() == b.trim().toLowerCase();
  }

  /// Check if two units are equal.
  bool _unitsEqual(String? a, String? b) {
    if (a == b) return true;
    if ((a == null || a.isEmpty) && (b == null || b.isEmpty)) return true;

    final normalizedA = (a ?? '').trim().toLowerCase();
    final normalizedB = (b ?? '').trim().toLowerCase();

    return normalizedA == normalizedB;
  }

  /// Normalize ingredient name for comparison.
  String _normalizeName(String name) {
    return name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  /// Calculate similarity between two strings (0.0 to 1.0).
  double _calculateSimilarity(String a, String b) {
    if (a.isEmpty && b.isEmpty) return 1.0;
    if (a.isEmpty || b.isEmpty) return 0.0;

    final distance = _levenshteinDistance(a, b);
    final maxLength = a.length > b.length ? a.length : b.length;
    return 1.0 - (distance / maxLength);
  }

  /// Calculate Levenshtein distance between two strings.
  int _levenshteinDistance(String a, String b) {
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;

    List<int> previousRow = List.generate(b.length + 1, (i) => i);
    List<int> currentRow = List.filled(b.length + 1, 0);

    for (var i = 0; i < a.length; i++) {
      currentRow[0] = i + 1;

      for (var j = 0; j < b.length; j++) {
        final cost = a[i] == b[j] ? 0 : 1;
        currentRow[j + 1] = [
          currentRow[j] + 1,
          previousRow[j + 1] + 1,
          previousRow[j] + cost,
        ].reduce((a, b) => a < b ? a : b);
      }

      final temp = previousRow;
      previousRow = currentRow;
      currentRow = temp;
    }

    return previousRow[b.length];
  }
}
