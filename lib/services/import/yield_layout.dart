import 'package:butlery/services/import/parsers/recipe_section_detector.dart';

/// The cookbook layout where each recipe carries a yield line ("Till 4
/// portioner behövs:") and where a two-recipe page may print both ingredient
/// lists first and both methods after them.
///
/// Pure functions, shared by `MultiRecipeSplitter` so that file stays under
/// the size limit.
class YieldLayout {
  YieldLayout._();

  static final _yieldLine = RegExp(
    r'^(?:till\s+|för\s+)?\d+(?:\s*[-–]\s*\d+)?\s*(?:portioner|portion|personer|port)\b',
    caseSensitive: false,
  );

  // A bare piece count ("4 stycken") is how a book of small items prints its
  // yield. Anchored to the whole line so an ingredient row ("4 st ägg") is
  // never read as one.
  static final _pieceYieldLine = RegExp(
    r'^(?:till\s+|för\s+)?\d+(?:\s*[-–]\s*\d+)?\s*(?:stycken|st)\.?$',
    caseSensitive: false,
  );

  // The two middle characters tolerate OCR noise ("Gốr sd här").
  static final _methodHeader = RegExp(
    r'^g.{1,2}r\s+s.{1,2}\s+h.{1,2}r\b',
    caseSensitive: false,
  );

  static bool isYieldLine(String line) =>
      _yieldLine.hasMatch(line.trim()) || _pieceYieldLine.hasMatch(line.trim());

  static bool isMethodHeader(String line) =>
      _methodHeader.hasMatch(line.trim());

  /// Hands each ingredient-only block the method that belongs to it.
  ///
  /// A run of blocks without a method, followed by one block carrying
  /// several, means the page printed the ingredient lists first and the
  /// methods after them. The k-th method goes to the k-th block, in reading
  /// order. A run whose last block holds fewer methods than the run needs is
  /// returned untouched: guessing which method is whose would hand a recipe
  /// the wrong instructions.
  static List<String> distributeMethods(List<String> blocks) {
    final result = <String>[];
    var i = 0;
    while (i < blocks.length) {
      var j = i;
      while (j < blocks.length - 1 && _methodStarts(blocks[j]).isEmpty) {
        j++;
      }
      final pending = j - i;
      final starts = _methodStarts(blocks[j]);
      if (pending == 0 || starts.length < pending + 1) {
        result.addAll(blocks.sublist(i, j + 1));
        i = j + 1;
        continue;
      }
      final lines = blocks[j].split('\n');
      final front = lines.sublist(0, starts.first).join('\n');
      final methods = <String>[
        for (var k = 0; k < starts.length; k++)
          lines
              .sublist(
                starts[k],
                k + 1 < starts.length ? starts[k + 1] : lines.length,
              )
              .join('\n'),
      ];
      for (var k = 0; k < pending; k++) {
        result.add('${blocks[i + k]}\n${methods[k]}'.trim());
      }
      result.add('$front\n${methods.sublist(pending).join('\n')}'.trim());
      i = j + 1;
    }
    return result;
  }

  static List<int> _methodStarts(String block) {
    final lines = block.split('\n');
    return [
      for (var i = 0; i < lines.length; i++)
        if (isMethodHeader(lines[i])) i,
    ];
  }

  /// True when [line] is short, quantity-free and capitalised, and a yield
  /// line followed by ingredients sits within [lookahead] lines below it
  /// (`hasIngredientsAfter` decides the second half).
  static bool isHeadlineAbove(
    List<String> lines,
    int from,
    int lookahead,
    bool Function(int yieldIndex) hasIngredientsAfter,
  ) {
    final t = lines[from];
    if (t.length < 3 || t.length > 60) return false;
    if (t.contains(RegExp(r'[\d,•:.]'))) return false;
    if (RecipeSectionDetector.instructionScore(t) >= 2) return false;
    final first = t[0];
    if (first != first.toUpperCase() || first == first.toLowerCase()) {
      return false;
    }
    final end = (from + 1 + lookahead).clamp(0, lines.length);
    for (var p = from + 1; p < end; p++) {
      if (isYieldLine(lines[p])) return hasIngredientsAfter(p);
    }
    return false;
  }
}
