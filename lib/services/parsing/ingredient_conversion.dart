import 'package:butlery/models/parsing/field_result.dart';
import 'package:butlery/models/parsing/parsed_ingredient.dart';
import 'package:butlery/services/llm/llm_models.dart';

/// Converts an [ExtractedIngredient] (LLM DTO) to the canonical
/// [ParsedIngredient] model.
///
/// Lives in the service layer to avoid a model → service import.
ParsedIngredient parsedIngredientFromExtracted(
  ExtractedIngredient extracted, {
  String? originalLine,
  ParseConfidence confidence = ParseConfidence.medium,
}) {
  // Format amount consistently: 1.0 → "1", 1.5 → "1.5"
  final quantity = extracted.amount != null
      ? (extracted.amount! % 1 == 0
          ? extracted.amount!.toInt().toString()
          : extracted.amount.toString())
      : null;

  return ParsedIngredient(
    name: extracted.name,
    originalLine: originalLine ?? extracted.formatted,
    quantity: quantity,
    unit: extracted.unit,
    preparation: extracted.preparation,
    confidence: confidence,
  );
}
