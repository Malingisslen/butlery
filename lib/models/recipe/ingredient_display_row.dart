import 'package:butlery/models/recipe/recipe_ingredient.dart';

/// A row in a rendered ingredient list: either a component sub-heading
/// ("Deg", "Fyllning") or an ingredient line. Views (recipe detail, cooking
/// mode) build a flat `List<IngredientDisplayRow>` and render each case —
/// keeping the section-grouping logic in one tested place instead of in
/// every widget.
sealed class IngredientDisplayRow {
  const IngredientDisplayRow();

  /// Builds display rows by pairing structured entries (which carry the
  /// `section`) with their already-computed display [displayLines] (scaled +
  /// unit-converted text). The two lists MUST be index-aligned 1:1 — which
  /// they are because `PortionScalerLogic.scaleEntries` preserves order and
  /// length. On any length mismatch this FAILS OPEN: every line renders with
  /// no headings, exactly as before the feature — never drops or misplaces a
  /// line.
  ///
  /// Contiguous runs of the same `section` collapse to one heading. A null
  /// section emits no heading (ungrouped lines render flat). A section value
  /// that recurs after a different one emits a fresh heading (non-contiguous
  /// groups are distinct).
  static List<IngredientDisplayRow> build(
    List<RecipeIngredient> structured,
    List<String> displayLines,
  ) {
    if (structured.length != displayLines.length) {
      return [
        for (var i = 0; i < displayLines.length; i++)
          IngredientLineRow(text: displayLines[i], ingredientIndex: i),
      ];
    }

    final rows = <IngredientDisplayRow>[];
    // Sentinel distinct from every String? value (including null) so the first
    // line always evaluates its section against "nothing seen yet".
    Object? current = _noSection;
    for (var i = 0; i < displayLines.length; i++) {
      // Defensive re-normalization: production trims blank→null upstream, but
      // a directly-constructed entry could carry '' — never render a blank
      // heading regardless of who built the entry.
      final section = RecipeIngredient.normalizeSection(structured[i].section);
      if (section != current) {
        current = section;
        if (section != null) rows.add(IngredientHeadingRow(label: section));
      }
      rows.add(IngredientLineRow(text: displayLines[i], ingredientIndex: i));
    }
    return rows;
  }

  static const Object _noSection = Object();
}

/// A component sub-heading rendered above its group of ingredients.
class IngredientHeadingRow extends IngredientDisplayRow {
  final String label;
  const IngredientHeadingRow({required this.label});

  @override
  bool operator ==(Object other) =>
      other is IngredientHeadingRow && other.label == label;

  @override
  int get hashCode => label.hashCode;
}

/// A single ingredient line. [ingredientIndex] points back into the flat
/// ingredient list so interactions (cooking-mode substitution long-press)
/// resolve to the right ingredient — headings carry no such index and are
/// excluded from those interactions.
class IngredientLineRow extends IngredientDisplayRow {
  final String text;
  final int ingredientIndex;
  const IngredientLineRow({required this.text, required this.ingredientIndex});

  @override
  bool operator ==(Object other) =>
      other is IngredientLineRow &&
      other.text == text &&
      other.ingredientIndex == ingredientIndex;

  @override
  int get hashCode => Object.hash(text, ingredientIndex);
}
