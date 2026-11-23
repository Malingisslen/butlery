import 'package:butlery/services/import/parsers/recipe_section_detector.dart';

/// The cookbook layout where a recipe is a short heading followed by running
/// text that carries its quantities ("Koka 750 g potatis med skal …"), with no
/// ingredient list in between.
///
/// Pure functions, shared by `MultiRecipeSplitter` so that file stays under
/// the size limit.
class ProseLayout {
  ProseLayout._();

  /// How many non-empty lines below the heading may hold the first method
  /// sentence. A one-line intro ("Pumpapurén blir härligt sötsyrlig.") may
  /// sit between.
  static const int _firstSentenceWithin = 2;

  /// How far below the heading the quantities are counted.
  static const int _quantityLookahead = 6;

  static const int _minQuantities = 2;

  /// A title is a name, not the opening of a sentence.
  static const int _maxTitleWords = 6;

  static final _quantity = RegExp(
    r'\d+(?:[,.]\d+)?\s*(dl|cl|ml|l|kg|hg|g|msk|tsk|st|krm|burk|pkt|påse|klyfta)\b',
    caseSensitive: false,
  );

  /// A label the book prints at the foot of a recipe ("Passar bra till: …"):
  /// the recipe ends there, so it never opens the next one.
  static final _tailLabel = RegExp(
    r'^(lämpliga tillbehör|passar bra till|mitt tips)\b',
    caseSensitive: false,
  );

  static bool isTailLabel(String line) => _tailLabel.hasMatch(line.trim());

  /// True when [lines] holds, at [from], a heading whose method follows
  /// immediately as running text with at least two quantities in it.
  ///
  /// The heading may contain an ingredient word ("Rissolée-potatis"): what
  /// makes it a title is the sentence under it, not its own words. A bare
  /// ingredient line ("Potatis") is followed by more ingredients, never by a
  /// sentence that starts with a cooking verb.
  static bool opensRecipe(List<String> lines, int from) {
    if (!_isHeadlineShaped(lines[from])) return false;
    var sentenceAt = -1;
    final firstEnd = (from + 1 + _firstSentenceWithin).clamp(0, lines.length);
    for (var p = from + 1; p < firstEnd; p++) {
      if (RecipeSectionDetector.instructionScore(lines[p]) >= 1) {
        sentenceAt = p;
        break;
      }
    }
    if (sentenceAt < 0) return false;
    var quantities = 0;
    final end = (sentenceAt + _quantityLookahead).clamp(0, lines.length);
    for (var p = sentenceAt; p < end; p++) {
      quantities += _quantity.allMatches(lines[p]).length;
    }
    return quantities >= _minQuantities;
  }

  static bool _isHeadlineShaped(String line) {
    final t = line.trim();
    if (t.length < 3 || t.length > 60) return false;
    if (t.split(RegExp(r'\s+')).length > _maxTitleWords) return false;
    if (t.contains(RegExp(r'[\d,•:.]'))) return false;
    if (isTailLabel(t)) return false;
    if (RecipeSectionDetector.instructionScore(t) >= 2) return false;
    final first = t[0];
    return first == first.toUpperCase() && first != first.toLowerCase();
  }
}
