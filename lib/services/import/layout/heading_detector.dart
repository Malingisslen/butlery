/// Finds the lines on a photographed page that are RECIPE TITLES, by type size.
///
/// A heading is set larger than body text. That is how a reader tells three
/// dishes on one spread apart, and it is the one signal the text-only splitter
/// cannot see: measured over 181 hand-verified corpus pages it aligns on 12 of
/// the 48 multi-recipe spreads, and 46 recipes are never emitted at all.
///
/// Pure compute — no async, no Firebase, deliberately not a `BaseService`
/// (same category as `ingredient_categorizer.dart` and
/// `multi_recipe_splitter.dart`). It reads a [PageLayout] and returns line
/// INDICES; it never rebuilds the page's text, because the text is derived from
/// those same lines and an index only means something against it.
library;

import 'package:butlery/services/import/parsers/recipe_section_detector.dart';
import 'package:butlery/services/ocr/text_layout.dart';

class HeadingDetector {
  const HeadingDetector._();

  /// A line is a heading candidate at this multiple of the page's body type
  /// size.
  ///
  /// 1.50, not 1.35, and the difference is a measured product decision rather
  /// than taste. From a SIMULATION over the corpus (2026-08-06), block count
  /// against gold:
  ///
  /// | setting                    | single pages kept whole | spreads right |
  /// |----------------------------|-------------------------|---------------|
  /// | text rules (today)         | 91 %                    | 25 %          |
  /// | K 1.35, minChars 120, verb | 76 %                    | 58 %          |
  /// | K 1.50, minChars 120, verb | 87 %                    | 50 %          |
  /// | K 1.50, minChars 200, verb | **91 %**                | **40 %**      |
  ///
  /// **These are the simulation's own numbers, and its baseline row does not
  /// reproduce.** `dart run tools/corpus_split_eval.dart` — the shipped code —
  /// reports the text rules at 122/133, which rounds to 92 %, not 91 %; the
  /// spread column (12/48 = 25 %) does reproduce exactly. The difference is NOT
  /// the OCR engine, as an earlier version of this paragraph implied: both
  /// engines score the identical 122/133 on single pages, and they diverge only
  /// on spreads (25 % against 19 %) and recipes lost (46 against 47).
  ///
  /// So the rows above are comparable WITH EACH OTHER and with nothing else,
  /// and the conclusion below rests on that internal comparison rather than on
  /// the absolute figure. Whether the simulation truncated 122/133 or measured
  /// something slightly different is no longer recoverable — which is the
  /// argument for scoring a shipped implementation rather than a simulation of
  /// one, and is why `--layout` exists. [titleSizeSpread]'s table below is
  /// measured that way, and its shipping row reproduces on every run — the
  /// other rows need the constant edited and the sweep re-run.
  ///
  /// The rows differ in more than K, and the 91 % is contingent on ALL THREE:
  /// the minimum block size and the instruction-signal requirement live in the
  /// splitter, not here. Step 6 picking minChars 120 would quietly invalidate
  /// this file's headline number.
  ///
  /// 1.35 finds more spreads and cuts one single-recipe page in four. That
  /// trade looks even and is not: `batch_import_preview` pre-ticks every recipe
  /// it is handed and offers no way to merge two back together, so a page
  /// wrongly cut in half saves two half-recipes silently, while a page wrongly
  /// merged is at least visibly one blob. 1.50 is the only setting measured NOT
  /// to make today's working pages worse.
  static const double headingSizeRatio = 1.50;

  /// Every line of [page] that reads as a recipe title, as indices into
  /// [PageLayout.lines].
  ///
  /// Deliberately NO upper size bound. Two ideas that sound right were measured
  /// and were worse. A ceiling ("drop anything over 2.5x", meant to reject
  /// chapter headings) lost recall at unchanged precision, because it punishes
  /// big titles instead of inconsistent ones. Grouping candidates into
  /// type-size classes and keeping one class was worse again.
  ///
  /// Both figures came from the TITLE-MATCH sweep at K = 1.35, not from the
  /// block-count table above, so they are not comparable to its rows and are
  /// deliberately not repeated here as numbers — the direction is what carries.
  /// Both are recorded so they are not re-derived; neither should return
  /// without a fresh measurement at the shipping threshold.
  ///
  /// Candidates that clear the size bar are then cut to [titleSizeSpread] of
  /// the page's TALLEST candidate — a page-relative floor, applied after this
  /// absolute one, and a different rule from the ceiling above. See its doc.
  ///
  /// Empty when the page has no measurable baseline — see
  /// [PageLayout.bodyTypeHeight]. That is the contract, not a failure: roughly
  /// a quarter of the corpus's multi-recipe CAPTURES decline — verified or not.
  /// On the 48 spreads with verified GOLD, the set every other number in this
  /// file is measured against, NONE decline. Do not apply the quarter to the
  /// 48. (No pinned count here: the corpus is live and outside the repo, so
  /// that fraction drifts by a page between runs — `corpus_paths.dart` says as
  /// much. The 0-of-48 is the load-bearing half and it is exact.) A caller must
  /// fall back to the text path rather than read an empty list as "no headings
  /// on this page".
  static List<int> headingLines(PageLayout page) {
    final body = page.bodyTypeHeight;
    if (body == null) return const [];

    final threshold = body * headingSizeRatio;
    final headings = <int>[];
    var tallest = 0.0;
    for (var i = 0; i < page.lines.length; i++) {
      final line = page.lines[i];
      // A line with no word boxes has no TYPE SIZE — its `typeHeight` is the
      // raw line box, on a different scale entirely. `glyphSpan`'s doc states
      // the inflation and which of it clears a size bar; the numbers are
      // deliberately NOT restated here, because restating them is exactly how
      // three copies of them went wrong inside one change.
      //
      // Two failure modes. Such a line can clear this bar on inflation alone
      // and open a false heading, and that does NOT require it to be larger
      // than body text.
      //
      // It can also set `tallest` and push a REAL title under the floor. The
      // window is exact: `floor = tallest / titleSizeSpread`, so the floor
      // stays under the size bar — and therefore harmless, since every
      // candidate already cleared that bar — only while the bogus height is
      // below `body * headingSizeRatio * titleSizeSpread`. Past that it can
      // take a genuine title.
      //
      // The fixture measures both sides and neither is the whole story on its
      // own. A bogus 85 implies a floor of 77.3, ALREADY above the 72.4 bar, so
      // a real title anywhere in 72.4-77.3 would be lost. This page's title
      // measures 89.7 — taller than the noise line itself, so the noise never
      // becomes `tallest` and the floor stays at 81.5; that, not luck, is why
      // the page survives. At 200 the noise IS the tallest, the floor is 181.8
      // and the title goes outright. Refusing early avoids both modes.
      //
      // Two things the refusal does NOT do, both worth knowing before anyone
      // relaxes it. It is not purely subtractive: dropping a bogus `tallest`
      // LOWERS the floor, so a page can go from one heading to two — whole to
      // split, the direction this project treats as expensive. And a REAL title
      // the recognizer failed to segment is now unfindable; mid-page that
      // silently merges two recipes into one block, which is the accepted
      // direction, and for a first title `MultiRecipeSplitter`'s discard budget
      // catches it. The corpus can show none of this — every stored capture has
      // word boxes.
      //
      // The mixed page is real because element absence is per LINE, not per
      // platform: `device_text_recognizer_mlkit.dart` models it defensively and
      // its test stages a page with one unsegmented line among segmented ones.
      // (Per-platform alone would imply uniform pages, which `bodyTypeHeight`
      // already declines — so it is not the argument for this guard.)
      if (!line.hasMeasuredWords) continue;
      if (line.typeHeight < threshold) continue;
      if (!_readsLikeTitle(line)) continue;
      headings.add(i);
      if (line.typeHeight > tallest) tallest = line.typeHeight;
    }

    // Keep only the candidates set in the page's LARGEST heading type.
    final floor = tallest / titleSizeSpread;
    return headings
        .where((i) => page.lines[i].typeHeight >= floor)
        .toList(growable: false);
  }

  /// How far below the page's tallest heading a line may be set and still be a
  /// RECIPE TITLE rather than one of its parts.
  ///
  /// The measured failure this fixes: on the FIRST layout-arm run (2026-08-07,
  /// raw box heights, no glyph normalisation and no floor) 8 single-recipe pages
  /// were split in two because a COMPONENT heading — "Topping", "Vaniljglass",
  /// "Kardemummasmulor", "TUSENBLADSTÅRTA" — is set larger than body text and
  /// so cleared [headingSizeRatio]. Each sat at roughly two thirds of its
  /// page's real title, while two dish titles on a genuine spread are set in
  /// the same type by construction.
  ///
  /// This is NOT the size-CLASS idea recorded as measured-worse above: no
  /// clustering, no bucket to be poisoned by a heading the recognizer cut in
  /// two. One page-relative floor, applied after the absolute one.
  ///
  /// **Only meaningful because [OcrWord.typeHeight] normalises for glyphs.**
  /// On raw box heights the same page's two sibling titles measured 166.5 and
  /// 129.0 — a 1.29 spread from a descender and an umlaut, not from type size —
  /// so any floor tight enough to reject a component heading also rejected half
  /// the real spreads. Normalisation is what makes this rule possible at all;
  /// it is not an independent tweak.
  ///
  /// Swept with `dart run tools/corpus_split_eval.dart --layout`, which scores
  /// the SHIPPED code over real stored geometry, both arms on one input:
  ///
  /// | spread | single pages | spreads right | recipes lost | spurious blocks |
  /// |--------|--------------|---------------|--------------|-----------------|
  /// | text arm (no geometry) | 92 % | 19 % | 47      | 14              |
  /// | **1.10** | **92 %**   | **33 %**      | **39**   | **13**          |
  /// | 1.15   | 91 %         | 35 %          | 38           | 14              |
  /// | 1.20   | 91 %         | 33 %          | 39           | 15              |
  /// | none   | 88 %         | 31 %          | 34           | 22              |
  ///
  /// These rows are NOT comparable to [headingSizeRatio]'s table above. That
  /// one scores `ocr.txt`; this one scores the layout capture's own text, a
  /// different OCR engine — which is why the SPREAD baseline reads 19 % here
  /// and 25 % there. The single-page column does NOT differ by engine: both
  /// arms score the identical 122/133 (92 %). The 91 % in that table is the
  /// simulation's own unreproducible figure, as its own paragraph records. `tools/corpus_split_eval.dart` prints that warning on
  /// every run for the same reason. Only the rows below may be compared with
  /// each other.
  ///
  /// 1.10 breaks NOTHING: the single-page score is the text arm's own 92 %, and
  /// the spurious-block count comes in one BELOW importing with no geometry at
  /// all. It fixes 7 pages and breaks 0. Every other row buys spreads with
  /// working pages, which is the trade the whole plan is written to refuse.
  ///
  /// That clean result only appeared once [OcrWord.typeHeight] stopped
  /// measuring the alphabet. The same table against the earlier, buggy span
  /// arithmetic read 91 % / 29 % / 41 / 14 with one page broken, and against no
  /// normalisation at all, 86 % with EIGHT broken. The rule and the measurement
  /// underneath it are not separable.
  ///
  /// 1.15 is the measured bolder option: 2 points more spreads and one more
  /// recipe rescued, against one working page cut in half. A product call, not
  /// a better number, and one constant away.
  ///
  /// A tighter spread also fails in the SAFE direction under the engine
  /// uncertainty this whole path carries: too tight drops a real title and the
  /// page falls back to the text rules, while too loose admits a component
  /// heading and silently splits a working recipe in two.
  static const double titleSizeSpread = 1.10;

  /// Heading positions for a WHOLE import, as indices into
  /// [DocumentLayout.lines] — or null when the document cannot be judged.
  ///
  /// This exists because the page-scoped [headingLines] is the wrong unit for
  /// the splitter, in a way that fails silently. Two traps, both invisible on a
  /// one-page import:
  ///
  /// 1. A caller converting a PAGE index with [DocumentLayout.textLineIndex]
  ///    must first add every preceding page's line count. Forget it and every
  ///    boundary from page two onward lands early.
  /// 2. [DocumentLayout.isComplete] is fail-closed for a page with NO geometry,
  ///    but a page that HAS geometry and DECLINES (too few measured body lines)
  ///    still counts as complete. Measured on the corpus, roughly a quarter of
  ///    multi-recipe captures decline. So a two-page import whose first page declines and
  ///    whose second yields two headings would open its first block at page
  ///    two — and the splitter slices from the first boundary onward, so page
  ///    one's entire content would vanish from every block. Silent whole-page
  ///    loss.
  ///
  /// Null therefore means "send the whole document down the text path", never
  /// "this document has no headings". Both are the caller's cue to fall back;
  /// only null distinguishes "cannot judge" from "judged, found none".
  static List<int>? headingLinesForDocument(DocumentLayout doc) {
    if (!doc.isComplete) return null;
    final flat = <int>[];
    var offset = 0;
    for (final page in doc.pages) {
      // A single declining page condemns the whole document, by design. Mixing
      // judged and unjudged pages is exactly trap 2.
      if (page!.bodyTypeHeight == null) return null;
      for (final i in headingLines(page)) {
        flat.add(offset + i);
      }
      offset += page.lines.length;
    }
    return flat;
  }

  /// The plain-text half of the test. A big line is not always a title — OCR
  /// fragments, page furniture and mis-segmented rows are big too.
  ///
  /// The often-quoted "81 % recall at 32 % precision, 71 %/62 % with the
  /// guards" was measured at K = 1.35, NOT at the 1.50 this ships. Quoting it
  /// as a property of this detector would be wrong; the guards' direction
  /// (precision up, recall down) is what carries over, not the figures. Re-run
  /// the measurement at 1.50 before citing a number here.
  static bool _readsLikeTitle(OcrLine line) {
    final t = line.text.trim();
    if (t.length < _minTitleChars || t.length > _maxTitleChars) return false;
    if (line.wordCount < 1 || line.wordCount > _maxTitleWords) return false;
    // A quantity means an ingredient row, however large it was set.
    if (_measurement.hasMatch(t)) return false;
    if (_leadingDigit.hasMatch(t)) return false;
    // Sentence punctuation means running text; a title carries none. A trailing
    // hyphen means the line continues into the next one.
    final last = t[t.length - 1];
    if (last == ':' || last == ',' || last == '.' || last == '-') return false;
    // A fragment OCR cut out of a paragraph.
    if (t.startsWith('(')) return false;
    final first = t[0];
    if (first != first.toUpperCase() || first == first.toLowerCase()) {
      return false;
    }
    // A section header set at heading size is still not a dish.
    if (RecipeSectionDetector.isInstructionHeader(t.toLowerCase())) {
      return false;
    }
    if (RecipeSectionDetector.isIngredientHeader(t)) return false;
    return true;
  }

  static const int _minTitleChars = 3;

  /// Measured over the 242 verified corpus titles: the longest is 59 characters
  /// ("Smörstekta äppelringar med kardemummasmulor och vaniljglass") and NONE
  /// exceeds 60. So this bound has ONE character of headroom, not the
  /// comfortable margin an earlier version of this comment claimed.
  ///
  /// Deliberate — 60 is the value the corpus measurement was taken at, and
  /// moving it un-measures the result — but it means a longer title in a
  /// cookbook the corpus does not contain is refused. If titles start going
  /// missing, check this first, and raise it by re-running
  /// `tools/corpus_split_eval.dart`, never by editing the number.
  static const int _maxTitleChars = 60;

  /// A dish name is a handful of words. The corpus maximum is 7, so 8 leaves
  /// exactly one word of headroom — the same tightness as the character bound
  /// above, and it moves under the same rule.
  static const int _maxTitleWords = 8;

  static final RegExp _leadingDigit = RegExp(r'^\s*\d');

  /// The STRICT quantity test, matching `MultiRecipeSplitter._measurement`
  /// rather than `RecipeSectionDetector.looksLikeIngredient` — the loose one
  /// fires on any line containing a bare ingredient WORD, and a dish is usually
  /// named after its main ingredient ("Dillstuvad potatis", "Förlorade ägg").
  /// Measured: that single guard was rejecting 15 of the 16 real titles it
  /// threw away.
  static final RegExp _measurement = RegExp(
    r'\d+(?:[,.]\d+)?\s*(dl|cl|ml|l|kg|hg|g|msk|tsk|st|krm|burk|pkt|påse|klyfta)\b',
    caseSensitive: false,
  );
}
