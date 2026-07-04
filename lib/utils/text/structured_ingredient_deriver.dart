import 'dart:collection';

import 'package:butlery/models/recipe/recipe_ingredient.dart';
import 'package:butlery/utils/text/ingredient_parser.dart';

/// BUT-1232: derives persisted [RecipeIngredient] entries from free-text
/// ingredient lines where no structured data exists (text import, manual
/// form entry, model-level edits).
///
/// Uses the pure regex [IngredientParser] — deliberately NOT the CRF/NER
/// services or `RecipeParserService.parseFromText` (full tier cascade with
/// an LLM tier, zero callers): derivation must be deterministic, synchronous
/// and free, and richer parser output already lands via the import
/// pipelines (BUT-1216). Pure compute, no DI/IO — safe to call from the
/// model layer.
class StructuredIngredientDeriver {
  StructuredIngredientDeriver._();

  /// Derives one entry from [line]. `raw` is always the line VERBATIM so the
  /// `Recipe.structuredIngredients` alignment invariant
  /// (`entry.raw == ingredients[i]`) holds against untrimmed form strings.
  /// Lines the parser can't extract structure from degrade to
  /// [RecipeIngredient.rawOnly] (amount/unit null).
  static RecipeIngredient derive(String line) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) return RecipeIngredient.rawOnly(line);

    final parsed = IngredientParser.parseIngredient(trimmed);

    // IngredientParser has no failure mode: an unparseable line comes back
    // as quantity 1.0 + empty unit + the whole (normalized, lowercased)
    // line as name. Same guard as IngredientParser.scaleAndFormatIngredient.
    final normalizedLower = trimmed
        .replaceAll(RegExp(r'\s+'), ' ')
        .toLowerCase();
    final isFallback =
        parsed.quantity == 1.0 &&
        parsed.unit.isEmpty &&
        parsed.name == normalizedLower;
    if (isFallback || parsed.name.isEmpty) {
      return RecipeIngredient.rawOnly(line);
    }

    // Store whole quantities as int so Firestore doesn't carry "3.0".
    final num amount = parsed.quantity == parsed.quantity.roundToDouble()
        ? parsed.quantity.toInt()
        : parsed.quantity;

    return RecipeIngredient(
      amount: amount,
      unit: parsed.unit.isEmpty ? null : parsed.unit,
      name: parsed.name,
      raw: line,
    );
  }

  /// Derives entries for all [lines], index-aligned with the input.
  ///
  /// When [reuse] is given (e.g. a recipe's previously persisted structured
  /// list), entries whose `raw` exactly matches a line are kept instead of
  /// re-derived — preserves richer import-time data (CRF/LLM-parsed notes)
  /// for unchanged lines and survives reordering. Duplicate raw lines are
  /// consumed FIFO so two identical lines under different headings each keep
  /// their own entry.
  ///
  /// When [sections] is given (index-aligned with [lines]) it is
  /// AUTHORITATIVE: it overwrites any section carried by a reused entry,
  /// including clearing it — the caller (the form) knows where each line
  /// sits now, the stale persisted entry doesn't. A length mismatch means
  /// the caller's bookkeeping broke; sections are ignored entirely (fail
  /// open to today's behavior) rather than misassigned.
  static List<RecipeIngredient> deriveAll(
    List<String> lines, {
    List<RecipeIngredient>? reuse,
    List<String?>? sections,
  }) {
    final byRaw = <String, Queue<RecipeIngredient>>{};
    for (final entry in reuse ?? const <RecipeIngredient>[]) {
      byRaw.putIfAbsent(entry.raw, () => Queue()).add(entry);
    }
    final applySections = sections != null && sections.length == lines.length;
    return [
      for (final (i, line) in lines.indexed)
        _withSection(
          _takeReused(byRaw, line) ?? derive(line),
          applySections ? sections[i] : null,
          applySections,
        ),
    ];
  }

  static RecipeIngredient? _takeReused(
    Map<String, Queue<RecipeIngredient>> byRaw,
    String line,
  ) {
    final queue = byRaw[line];
    if (queue == null || queue.isEmpty) return null;
    return queue.removeFirst();
  }

  static RecipeIngredient _withSection(
    RecipeIngredient entry,
    String? section,
    bool authoritative,
  ) {
    if (!authoritative) return entry;
    final normalized = RecipeIngredient.normalizeSection(section);
    return normalized == entry.section ? entry : entry.copyWithSection(section);
  }
}
