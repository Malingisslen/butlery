import 'package:butlery/models/tagging/ingredient_data.dart';
import 'package:butlery/models/tagging/ingredient_line.dart';

/// Which lines carry a recipe (Malin 2026-10-30, kärnflöde steg 5 beslut 7):
/// a weighed line is a main ingredient above 15 % of the weighed total; a line
/// with no weight is one when it is among the first three that are not
/// staples. Staples are never main ingredients.
abstract final class MainIngredients {
  static const weightShare = 0.15;
  static const firstLines = 3;

  static const _stapleEndings = ['salt', 'socker', 'peppar', 'olja'];

  static bool isStaple(IngredientLine line) {
    if (line.names.isEmpty) return false;
    if (line.known) return line.ingredients.every(_isStapleRow);
    return line.names.every(_isStapleName);
  }

  static bool _isStapleRow(IngredientData i) =>
      i.group == 'fat/oil' || _isStapleName(i.swedish);

  // Matched on the last word, so "flingsalt", "malen svartpeppar" and
  // "rapsolja" are staples; kolja is a fish.
  static bool _isStapleName(String name) {
    final word = name.toLowerCase().trim().split(' ').last;
    if (word == 'kolja') return false;
    return word == 'vatten' ||
        word == 'kranvatten' ||
        _stapleEndings.any(word.endsWith);
  }

  /// Lines that name an ingredient and are not staples, in recipe order.
  static List<IngredientLine> countable(List<IngredientLine> lines) =>
      lines.where((l) => l.names.isNotEmpty && !isStaple(l)).toList();

  static List<IngredientLine> of(List<IngredientLine> lines) {
    final candidates = countable(lines);
    final weighed = candidates.where((l) => (l.grams ?? 0) > 0);
    final total = weighed.fold<double>(0, (sum, l) => sum + l.grams!);
    return [
      for (var i = 0; i < candidates.length; i++)
        if ((candidates[i].grams ?? 0) > 0
            ? candidates[i].grams! / total > weightShare
            : i < firstLines)
          candidates[i],
    ];
  }

  /// Grams of the lines whose rows all satisfy [test]; a line with no weight
  /// adds nothing, so the sum is a floor.
  static double gramsWhere(
    List<IngredientLine> lines,
    bool Function(IngredientData) test,
  ) => lines
      .where((l) => l.ingredients.isNotEmpty && l.ingredients.every(test))
      .fold<double>(0, (sum, l) => sum + (l.grams ?? 0));
}
