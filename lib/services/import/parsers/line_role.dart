/// The one context-free answer to "is this recipe line an ingredient, a
/// heading or a block marker?" that both the text import path and the
/// rule-based URL classifier ask (BUT-2242). Each path still applies its own
/// context rules (quantity rows, paragraph shape, Viterbi) to lines this
/// returns [LineRoleKind.undecided] for.
library;

import 'package:butlery/services/import/parsers/recipe_section_detector.dart';

enum LineRoleKind { blockMarker, heading, ingredient, undecided }

final class LineRole {
  const LineRole(this.kind, [this.label]);

  final LineRoleKind kind;

  /// The group label for a heading; the text to keep in the flat ingredient
  /// list for an ingredient, colon stripped.
  final String? label;

  @override
  String toString() => '${kind.name}${label == null ? '' : '($label)'}';
}

abstract final class LineRoles {
  static const _undecided = LineRole(LineRoleKind.undecided);

  static LineRole of(String line) {
    final text = line.trim();
    if (text.isEmpty) return _undecided;
    if (RecipeSectionDetector.isGenericBlockMarker(text)) {
      return const LineRole(LineRoleKind.blockMarker);
    }
    final gluten = RecipeSectionDetector.bareGlutenIngredientLabel(text);
    if (gluten != null) return LineRole(LineRoleKind.ingredient, gluten);
    final colonIngredient = _loneIngredientWord(text);
    if (colonIngredient != null) {
      return LineRole(LineRoleKind.ingredient, colonIngredient);
    }
    final heading = RecipeSectionDetector.componentSubHeadingLabel(text);
    if (heading != null) return LineRole(LineRoleKind.heading, heading);
    return _undecided;
  }

  // Malin, 2026-10-06: "Mjölk:" or "Ägg:" alone on a line is an ingredient
  // row that lost its amount, not a group heading. One word only, so a
  // heading such as "Till potatisen:" is not read as an ingredient.
  static String? _loneIngredientWord(String text) {
    if (!text.endsWith(':')) return null;
    final label = text.substring(0, text.length - 1).trim();
    if (label.isEmpty || label.contains(RegExp(r'\s'))) return null;
    return RecipeSectionDetector.looksLikeIngredient(label) ? label : null;
  }
}
