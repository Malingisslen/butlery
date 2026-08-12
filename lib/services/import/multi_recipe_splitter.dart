import 'package:butlery/services/import/layout/heading_detector.dart';
import 'package:butlery/services/import/parsers/recipe_section_detector.dart';
import 'package:butlery/services/ocr/text_layout.dart';

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
/// confident blocks it returns `[input]` unchanged — it never hands back a
/// single, SHORTENED block.
///
/// That is a narrow promise, and the narrowness matters. When it DOES split it
/// drops page furniture and blocks that fail their tests. On the LAYOUT path
/// that loss is bounded by the discard budget; on the TEXT path it is NOT
/// bounded at all — everything before the first boundary goes, and so does any
/// block failing `_isCompleteRecipeBlock`, at any size. A whole recipe whose
/// title the detector refused can vanish there. So "the splitter never deletes
/// text" is false; "the splitter never returns one shortened block" is what
/// holds.
///
/// And it is a promise about `split`, not about the import. Since 2026-08-08 the
/// caller may hand it less: `ImportManager.autoParseMulti` runs
/// `withoutFrameNoise` first (`withoutOrphanTail` alone until 2026-08-12),
/// which cuts a heading the camera frame separated from its own recipe off the
/// end of a page, and furniture off the front of the first page. Both cuts are
/// decided from the untouched page — see `frame_trim.dart`. The trims sit
/// there rather than here precisely so this contract survives — and so the
/// corpus arm can measure
/// the trim against an untrimmed column.
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

  /// A layout-derived block must be at least this many chars.
  ///
  /// 200, not the text path's 40, and the difference is measured rather than
  /// cautious: the simulation that produced "single-recipe pages stay at 91 %"
  /// used 200 plus an instruction signal. At 120 the same threshold scores
  /// 87 %/50 % instead of 91 %/40 %. The text path keeps 40 because its
  /// boundaries already had to clear an ingredient cluster; a size-derived
  /// boundary has no such evidence behind it, so the block itself must carry
  /// the weight.
  static const int _minLayoutBlockChars = 200;

  /// Fewer blocks than the text path allows. A layout that suggests nine
  /// recipes on ONE page is describing noise, not a cookbook.
  ///
  /// Counted per page, against the page each block actually opens on. The
  /// measured basis is per page, but `HeadingDetector.headingLinesForDocument`
  /// is document-scoped and a photo import may hold up to
  /// `PhotoImportViewModel.maxPages` pages. A flat document cap of 8 would
  /// therefore have switched the layout path off for five pages holding two
  /// recipes each, which is not noise — it is the case the feature was built
  /// for.
  static const int _maxLayoutBlocksPerPage = 8;

  /// Split [input] into N recipe blocks, or `[input]` when not confident.
  ///
  /// With a [layout], boundaries come from TYPE SIZE — a heading is set larger
  /// than body text, which is the signal the text rules cannot see. Everything
  /// about that path fails toward the text path, never toward a wrong split:
  ///
  /// - the layout is discarded unless [DocumentLayout.matchesLineCountOf]
  ///   accepts [input]. That compares ROW COUNTS, and passing it is NECESSARY,
  ///   NOT SUFFICIENT: two different strings of equal row count are
  ///   indistinguishable to it, and the provider's string and the layout's
  ///   OFTEN have equal row counts — less often since 2026-08-08, when
  ///   `edge_crop.dart` began removing rows from the layout string only, which
  ///   makes this gate stronger without making it sufficient. What closes it
  ///   is `OCRResult` holding text and geometry as ONE object, cached whole
  ///   under one image-hash key (2026-08-07) — see the contract at
  ///   [DocumentLayout.matchesLineCountOf], which forbids describing this gate
  ///   as covering it;
  /// - the layout path must produce at least two blocks and at most
  ///   [_maxLayoutBlocksPerPage] per page, each clearing
  ///   [_minLayoutBlockChars] and carrying an instruction signal;
  /// - a block failing either test is DROPPED, not merged and not returned —
  ///   so the path also carries a discard budget: once the text it is throwing
  ///   away reaches [_minLayoutBlockChars], a whole recipe could be inside it
  ///   and the path declines instead. Without that, one over-long title (the
  ///   detector's own limit is 60 chars, with one character of headroom over
  ///   the corpus) shipped two confident recipes and ate a third, while the
  ///   text path handed back the same page whole;
  /// - the budget closes the LOSS case, not every case. This path still runs
  ///   first and short-circuits the text rules, so a page whose third title the
  ///   detector refuses (too long, lowercase, carrying a quantity) comes back as
  ///   two blocks with nothing discarded — the third recipe merged into the
  ///   second — where the text rules might have found three. Under-splitting is
  ///   the residual; measured over the corpus it is a net win (47 recipes never
  ///   emitted becomes 39), which is not the same as saying it cannot happen;
  /// - anything else falls through to the text rules, which then get their
  ///   unchanged chance;
  /// - `_isCompleteRecipeBlock` is deliberately NOT applied to layout blocks. It
  ///   demands an ingredient signal AND an instruction signal, and a prose
  ///   cookbook has neither in list form — those pages are precisely why this
  ///   path exists, and every one of the corpus's prose spreads fails the text
  ///   rules today.
  List<String> split(String input, {DocumentLayout? layout}) {
    if (input.trim().isEmpty) return [input];

    final byLayout = _splitByLayout(input, layout);
    if (byLayout != null) return byLayout;

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

  /// The layout path, or null when it declines — and it declines often, on
  /// purpose. Null means "the text rules get their normal turn", never "this
  /// page has one recipe".
  List<String>? _splitByLayout(String input, DocumentLayout? layout) {
    if (layout == null) return null;
    // The precondition, and only half of one: it catches a ROW-COUNT mismatch.
    // A different string with the same row count still passes, still yields
    // confident line numbers, and still addresses the wrong rows. The other
    // half is that text and geometry are one object on `OCRResult`, cached
    // whole under one image-hash key — landed 2026-08-07, not owed.
    if (!layout.matchesLineCountOf(input)) return null;

    final flat = HeadingDetector.headingLinesForDocument(layout);
    // Null is "cannot judge" (a page with no measurable baseline); empty is
    // "judged, found none". Both go to the text rules, but only the first is
    // an absence of evidence.
    if (flat == null || flat.length < 2) return null;

    final starts = <int>[];
    for (final i in flat) {
      final row = layout.textLineIndex(i);
      if (row == null) return null;
      starts.add(row);
    }

    final rawLines = input.split('\n');
    final blocks = <String>[];
    // The text row each surviving block opens on, so the cap below can be
    // counted where it is justified — per page.
    final blockStarts = <int>[];
    // Everything before the first heading belongs to no block at all. Usually a
    // folio and a running header; occasionally a whole recipe whose title the
    // detector refused, which is why it is counted rather than assumed small.
    var discarded = rawLines.sublist(0, starts.first).join('\n').trim().length;

    for (var i = 0; i < starts.length; i++) {
      final end = i + 1 < starts.length ? starts[i + 1] : rawLines.length;
      // Belt and braces: `starts` is strictly increasing (the detector emits
      // ascending indices and `textLineIndex` is monotonic) and the row-count
      // gate bounds the last index, so neither half can fire today.
      if (starts[i] >= end || end > rawLines.length) return null;
      final block = rawLines.sublist(starts[i], end).join('\n').trim();
      // Trimmed per line, as every other caller of `_isInstructional` is:
      // `instructionScore` matches its verb with `startsWith`, so one leading
      // space costs the +3 the verb is worth and can drop the line below the
      // gate on its own.
      if (block.length < _minLayoutBlockChars ||
          !block.split('\n').any((l) => _isInstructional(l.trim()))) {
        discarded += block.length;
        continue;
      }
      blocks.add(block);
      blockStarts.add(starts[i]);
    }

    // The discard budget. A dropped block's text is gone from the import
    // entirely, and `batch_import_preview` pre-ticks what it is handed with no
    // way to notice the absence — so page furniture may vanish, but never a
    // recipe's worth of page.
    if (discarded >= _minLayoutBlockChars) return null;

    if (blocks.length < 2) return null;

    // Counted PER PAGE, not as a document total scaled by the page count. Those
    // are not the same rule: a total of 16 over two pages passes a scaled cap
    // even when all 16 sit on page one, which is exactly the "nine recipes on
    // one page is noise" case the cap exists to catch.
    final offsets = layout.lineOffsets;
    // Unreachable, like the bounds guard above: `matchesLineCountOf` already
    // refused an incomplete document, which is the only way this is null.
    if (offsets == null) return null;
    final perPage = List<int>.filled(offsets.length, 0);
    for (final row in blockStarts) {
      var page = 0;
      for (var p = 0; p < offsets.length; p++) {
        if (offsets[p] <= row) page = p;
      }
      perPage[page]++;
    }
    if (perPage.any((n) => n > _maxLayoutBlocksPerPage)) return null;

    return blocks;
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
