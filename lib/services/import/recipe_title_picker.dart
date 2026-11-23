import 'package:butlery/services/import/parsers/recipe_section_detector.dart';
import 'package:butlery/services/import/prose_layout.dart';
import 'package:butlery/services/import/yield_layout.dart';

/// Finds a recipe's title on a page block by where headings sit, not by which
/// line comes first.
///
/// A photographed cookbook page opens with the foot of the previous recipe, a
/// page header ("Potatis på flera sätt") or a caption, so the first line is
/// often not the title. The title is the heading closest above the recipe's
/// first ingredient row, with the introduction in between.
///
/// Pure function, shared by `TextImportStrategy` so that file does not grow.
class RecipeTitlePicker {
  RecipeTitlePicker._();

  /// Import option set on blocks cut from a photographed page.
  static const String photoPageOption = 'photoPage';

  /// How many lines the introduction between a title and the first
  /// ingredient may take. A reflowed intro paragraph is one or two lines.
  static const int _maxLinesAboveAnchor = 8;

  static const int _maxTitleWords = 6;

  /// How far down a page the first method heading may sit when the page
  /// opens on ingredient rows.
  static const int _maxListLines = 45;

  static final _quantity = RegExp(
    r'\d+(?:[,.]\d+)?\s*(dl|cl|ml|l|kg|hg|g|msk|tsk|st|krm|burk|pkt|påse|klyfta)\b',
    caseSensitive: false,
  );

  /// A row that opens with an amount is an ingredient even without a unit
  /// ("3 ägg"); a lone number is a folio.
  static final _leadingAmount = RegExp(r'^\s*\d+(?:[,.]\d+)?\s+\S');

  /// Picture and page references that sit beside a title but are not part of
  /// it ("Bild sidan 78", "Ovan t v", "recept sidan 76").
  static final _pageReference = RegExp(
    r'\b(sidan|sid\.|bild|foto|ovan|nedan)\b',
    caseSensitive: false,
  );

  static final _terminalPunctuation = RegExp(r'[.,:;!?]$');

  /// The title, or null when the block shows no heading above its first
  /// ingredient and the caller should fall back to its own rule.
  ///
  /// [lines] are the block's non-empty lines, trimmed.
  static String? pick(List<String> lines, {required bool photoPage}) {
    final anchor = _firstIngredientRow(lines);
    if (anchor < 0) return null;
    if (anchor == 0) return photoPage ? _titleBelowList(lines) : null;
    // Pasted text opens on its own title, so a first-line heading stands. Only
    // a photographed page can open on the foot of the previous recipe, and
    // there a heading in line one may be the page header instead.
    if (!photoPage && _isHeading(lines.first)) return null;
    final lowest = anchor - _maxLinesAboveAnchor;
    var found = -1;
    for (var i = anchor - 1; i >= 0 && i >= lowest; i--) {
      if (!_isHeading(lines[i])) continue;
      found = i;
      break;
    }
    if (found < 0) return photoPage ? _titleBelowList(lines) : null;
    // A short heading right over the first row ("Smuldeg") names a part of the
    // recipe when the recipe's own title sits above an introduction.
    if (_endOfHeading(lines, found, anchor) == anchor) {
      final title = _titleAboveIntroduction(lines, found, lowest);
      if (title >= 0) found = title;
    }
    return _withContinuation(lines, found, anchor);
  }

  /// Some cookbooks print the ingredient lists at the top of the page and each
  /// recipe's title above its method further down. The title is then the first
  /// heading that is followed by running text.
  static String? _titleBelowList(List<String> lines) {
    final last = lines.length - 1;
    for (var i = 1; i < last && i <= _maxListLines; i++) {
      if (!_isHeading(lines[i])) continue;
      final next = _endOfHeading(lines, i, lines.length);
      if (next >= lines.length) return null;
      if (_isIntroduction(lines[next]) ||
          RecipeSectionDetector.instructionScore(lines[next]) >= 2) {
        return _withContinuation(lines, i, lines.length);
      }
    }
    return null;
  }

  static int _titleAboveIntroduction(
    List<String> lines,
    int group,
    int lowest,
  ) {
    var sawIntroduction = false;
    for (var i = group - 1; i >= 0 && i >= lowest; i--) {
      if (_isIntroduction(lines[i])) {
        sawIntroduction = true;
      } else if (sawIntroduction && _isHeading(lines[i])) {
        return i;
      }
    }
    return -1;
  }

  static bool _isIntroduction(String line) {
    final t = line.trim();
    return t.split(RegExp(r'\s+')).length >= 7 || t.endsWith('.');
  }

  static int _endOfHeading(List<String> lines, int at, int anchor) {
    var next = at + 1;
    while (next < anchor && _isContinuation(lines[next])) {
      next++;
    }
    return next;
  }

  /// A heading set on two lines ("Nordtysk" / "lapskojs") reads as one title.
  static String _withContinuation(List<String> lines, int at, int anchor) {
    final title = StringBuffer(lines[at].trim());
    var next = at + 1;
    while (next < anchor && _isContinuation(lines[next])) {
      title.write(' ${lines[next].trim()}');
      next++;
    }
    return title.toString();
  }

  static int _firstIngredientRow(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final t = lines[i].trim();
      if (_quantity.hasMatch(t) ||
          _leadingAmount.hasMatch(t) ||
          YieldLayout.isYieldLine(t) ||
          RecipeSectionDetector.isIngredientHeader(t.toLowerCase())) {
        return i;
      }
    }
    return -1;
  }

  static bool _isHeading(String line) {
    final t = line.trim();
    if (t.length < 3 || t.length > 60) return false;
    if (t.split(RegExp(r'\s+')).length > _maxTitleWords) return false;
    if (t.contains(RegExp(r'[\d:]'))) return false;
    if (!t.contains(RegExp(r'[A-Za-zÅÄÖåäöÉé]{4}'))) return false;
    if (ProseLayout.isTailLabel(t)) return false;
    if (_terminalPunctuation.hasMatch(t)) return false;
    if (_pageReference.hasMatch(t)) return false;
    final first = t[0];
    if (first != first.toUpperCase() || first == first.toLowerCase()) {
      return false;
    }
    final letters = t.replaceAll(RegExp(r'[^A-Za-zÅÄÖåäöÉé]'), '');
    if (letters.length >= 2 && t == t.toUpperCase()) return false;
    final lower = t.toLowerCase();
    return !RecipeSectionDetector.isSectionHeader(t) &&
        !RecipeSectionDetector.isIngredientHeader(lower) &&
        !RecipeSectionDetector.isInstructionHeader(lower) &&
        RecipeSectionDetector.instructionScore(t) < 2;
  }

  static bool _isContinuation(String line) {
    final t = line.trim();
    if (t.isEmpty || t.split(RegExp(r'\s+')).length > 4) return false;
    if (t.contains(RegExp(r'\d')) || _terminalPunctuation.hasMatch(t)) {
      return false;
    }
    final first = t[0];
    if (first != first.toLowerCase() || first == first.toUpperCase()) {
      return false;
    }
    return RecipeSectionDetector.instructionScore(t) < 2;
  }
}
