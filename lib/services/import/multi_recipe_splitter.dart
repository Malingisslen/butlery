import 'package:butlery/services/import/parsers/recipe_section_detector.dart';

/// Splits a single OCR/text blob that contains SEVERAL recipes (a cookbook
/// spread) into one text block per recipe.
///
/// Deterministic and rule-based — no LLM (cost principle). The signal is the
/// repeated *title → ingredients → instructions* structure: a new block only
/// opens when a title-like line is followed by an ingredient cluster AND the
/// current block is already complete (has both ingredients and an instruction
/// signal). That completeness gate is what stops a single recipe with a
/// sub-section header ("För såsen:", "Gräddsås:") from being split in two.
///
/// Pure-compute, no async, no Firebase — intentionally NOT a `BaseService`
/// (same rationale as `ingredient_categorizer.dart`). When it cannot find ≥2
/// confident blocks it returns `[input]` unchanged, so the single-recipe import
/// path is guaranteed untouched.
class MultiRecipeSplitter {
  /// How many following non-empty lines to scan for an ingredient cluster when
  /// deciding whether a title-like line really opens a recipe.
  static const int _lookahead = 8;

  /// A block must be at least this many chars to count — rejects OCR noise.
  static const int _minBlockChars = 40;

  /// Safety cap: a noisy page should fall back to single-recipe, not explode
  /// into dozens of fragments.
  static const int _maxBlocks = 12;

  /// A complete block needs at least this many ingredient-like lines.
  static const int _minIngredientLines = 2;

  static final _leadingDigit = RegExp(r'^\s*\d');

  /// A genuine ingredient line carries a quantity + unit. This is a STRICTER
  /// signal than `RecipeSectionDetector.looksLikeIngredient` (which also fires
  /// on any line merely mentioning an ingredient word) — instruction steps say
  /// "Smält smör", so the loose check would falsely see an ingredient cluster
  /// after a sub-header and split one recipe in two.
  static final _measurement = RegExp(
    r'\d+(?:[,.]\d+)?\s*(dl|cl|ml|l|kg|hg|g|msk|tsk|st|krm|burk|pkt|påse|klyfta)\b',
    caseSensitive: false,
  );

  /// Split [input] into N recipe blocks, or `[input]` when not confident.
  List<String> split(String input) {
    if (input.trim().isEmpty) return [input];

    final rawLines = input.split('\n');
    // Index map of non-empty lines → their position in rawLines, so blocks can
    // be reconstructed faithfully (preserving the original text between titles).
    final neLines = <_Line>[];
    for (var i = 0; i < rawLines.length; i++) {
      final t = rawLines[i].trim();
      if (t.isNotEmpty) neLines.add(_Line(i, t));
    }
    if (neLines.length < 4) return [input];

    final boundaries = <int>[]; // indices into rawLines where a block starts
    var hasIngredients = false;
    var hasInstructions = false;

    for (var p = 0; p < neLines.length; p++) {
      final line = neLines[p];

      if (_isTitleish(line.text) && _ingredientClusterAhead(neLines, p)) {
        if (boundaries.isEmpty) {
          boundaries.add(line.rawIndex);
        } else if (hasIngredients && hasInstructions) {
          // Current block is complete → this title opens a new recipe.
          boundaries.add(line.rawIndex);
          hasIngredients = false;
          hasInstructions = false;
        }
      }

      if (RecipeSectionDetector.looksLikeIngredient(line.text)) {
        hasIngredients = true;
      }
      if (_isInstructional(line.text)) {
        hasInstructions = true;
      }
    }

    if (boundaries.length < 2) return [input];

    // Slice rawLines into blocks at the boundary indices.
    final blocks = <String>[];
    for (var i = 0; i < boundaries.length; i++) {
      final start = boundaries[i];
      final end = i + 1 < boundaries.length
          ? boundaries[i + 1]
          : rawLines.length;
      final block = rawLines.sublist(start, end).join('\n').trim();
      if (block.isNotEmpty) blocks.add(block);
    }

    final valid = blocks.where(_isCompleteRecipeBlock).toList();
    if (valid.length < 2 || valid.length > _maxBlocks) return [input];
    return valid;
  }

  /// A heading-like line: short, capitalised, and NOT a header/ingredient/
  /// measurement/yield label.
  bool _isTitleish(String line) {
    final t = line.trim();
    if (t.length < 3 || t.length > 60) return false;
    if (_leadingDigit.hasMatch(t)) return false;
    // Colon-terminated lines are sub-section headers ("För såsen:", "Gräddsås:",
    // "Ingredienser:"), never recipe titles. (We deliberately do NOT use
    // `isSectionHeader` — its single-word heuristic rejects real one-word titles
    // like "Pannkakor".)
    if (t.endsWith(':')) return false;
    // NB: deliberately not using `isGarbage` — it delegates to the single-word
    // `isSectionHeader` heuristic and so flags real one-word titles ("Pannkakor")
    // as garbage. The digit/length/header guards here cover the noise cases.
    if (RecipeSectionDetector.isIngredientHeader(t)) return false;
    if (RecipeSectionDetector.isInstructionHeader(t.toLowerCase())) {
      return false;
    }
    if (RecipeSectionDetector.looksLikeIngredient(t)) return false;
    // An instruction step can be short + capitalised and happen to sit just
    // before the next recipe's ingredients — exclude it so it can't open a
    // spurious block.
    if (_isInstructional(t)) return false;
    // Must start with a capital letter (recipe headings do; prose mid-sentence
    // fragments from column bleed usually don't).
    final first = t[0];
    return first == first.toUpperCase() && first != first.toLowerCase();
  }

  /// An instruction signal — a "Gör så här" style header or a line that scores
  /// as a cooking step.
  bool _isInstructional(String line) =>
      RecipeSectionDetector.isInstructionHeader(line.toLowerCase()) ||
      RecipeSectionDetector.instructionScore(line) >= 2;

  /// True when the next [_lookahead] non-empty lines after [from] contain an
  /// ingredient header or at least two ingredient-like lines — i.e. this title
  /// is actually introducing a recipe, not a stray capitalised line.
  bool _ingredientClusterAhead(List<_Line> neLines, int from) {
    var count = 0;
    final end = (from + 1 + _lookahead).clamp(0, neLines.length);
    for (var p = from + 1; p < end; p++) {
      final t = neLines[p].text;
      if (RecipeSectionDetector.isIngredientHeader(t)) return true;
      if (_measurement.hasMatch(t)) {
        count++;
        if (count >= _minIngredientLines) return true;
      }
    }
    return false;
  }

  /// A block only survives if it independently looks like a real recipe:
  /// enough length, an ingredient cluster, and an instruction signal.
  bool _isCompleteRecipeBlock(String block) {
    if (block.length < _minBlockChars) return false;
    final lines = block
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty);
    // Validation is intentionally LOOSER than boundary detection: here we just
    // confirm a sliced block is recipe-shaped, so countable ingredients without
    // a unit ("2 ägg") still count. Strict measurement matching is only needed
    // upstream, to avoid OPENING a spurious block.
    var ingredientLines = 0;
    var hasIngredientHeader = false;
    var instructional = false;
    for (final l in lines) {
      if (RecipeSectionDetector.isIngredientHeader(l)) {
        hasIngredientHeader = true;
      }
      if (RecipeSectionDetector.looksLikeIngredient(l)) ingredientLines++;
      if (_isInstructional(l)) instructional = true;
    }
    // An explicit "Ingredienser:" header is a strong ingredient signal on its
    // own, so a block carrying one survives even when its lines are too few to
    // reach _minIngredientLines. (This used to compensate for
    // looksLikeIngredient missing unit-less, åäö-leading lines like "2 ägg";
    // BUT-1661 replaced Dart's ASCII \b with a Unicode-safe boundary, so those
    // lines now count on their own and this is a genuine OR, not a workaround.)
    final hasIngredients =
        hasIngredientHeader || ingredientLines >= _minIngredientLines;
    return hasIngredients && instructional;
  }
}

class _Line {
  final int rawIndex;
  final String text;
  const _Line(this.rawIndex, this.text);
}
