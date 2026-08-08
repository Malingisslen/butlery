/// Where the words sat on the page — the half of OCR the app currently throws
/// away.
///
/// Every recognizer computes glyph geometry. Until 2026-08-05
/// `DeviceTextRecognizer` returned only the text and discarded it, so everything
/// downstream reconstructed page structure from a flat string; the seam now
/// carries the measurements, and this is the model it fills. Across 181
/// hand-verified cookbook pages the splitter aligns on only 12 of the 48
/// multi-recipe spreads, and 46 recipes are never emitted at all — figures from
/// the DEFAULT eval arm, which scores the paid tier's `ocr.txt`. The `--layout`
/// arm scores the capture's own text and reads 9 of 48 with 47 lost; both are
/// current, they differ by ENGINE, and `feature_flag_service.dart` quotes the
/// latter. Do not "fix" one into the other.
/// A heading is reliably LARGER than body text, and no text rule can see that.
///
/// Deliberately Flutter-free and JSON-serializable:
/// - no `dart:ui` `Rect`, so every consumer (heading detection, the splitter)
///   runs under plain `dart test` with no device and no engine. A column
///   orderer was a planned third consumer; it was measured and declined on
///   2026-08-07, see ACCEPTED_DEVIATIONS.md;
/// - the JSON shape is a DURABLE on-disk artifact. A capture is written once
///   and replayed for years by whatever reads it next — `tools/`, a Python
///   probe, a future rewrite — so it is flat, self-describing and outlives this
///   model. (An earlier draft justified that by claiming `tools/` must stay
///   free of `package:butlery` imports. That is not a rule —
///   `tools/corpus_split_eval.dart` imports it. The shape is right; the reason
///   was invented. No file count here on purpose: an earlier version named one
///   and it went stale.)
///
/// Its ONE import is `glyph_metrics.dart`, a sibling under the same discipline
/// — no Flutter, no `dart:ui`, nothing third-party. This file carried that
/// helper inline until it pushed the model past the 500-line limit; the
/// property that matters (a stored capture replays under plain `dart test`
/// years from now) is unchanged, and "zero imports" was only ever the
/// shorthand for it.
///
/// **The text is DERIVED from the lines, never the other way round.**
/// [PageLayout.text] and [DocumentLayout.text] are the only producers of the
/// string the parser sees, which is what makes a line index a line number by
/// definition rather than by hope. Anything that rebuilds the string
/// independently — a global `trim()`, a different join — breaks that silently,
/// so a consumer MUST check [DocumentLayout.text] against its own input and
/// fall back to the text-only path when they disagree.
///
/// That check must compare the LINE COUNT of both strings, NOT their bytes, and
/// must NOT trim either first.
///
/// `HtmlSanitizer.sanitizeText` normalises homoglyphs and strips control
/// characters but preserves `\n`, so it changes bytes only — which is why byte
/// equality would trip on healthy pages and disable the layout path
/// permanently, looking exactly like "geometry never helps".
///
/// NO trim is applied to the LAYOUT string. `device_text_recognizer_mlkit`
/// returns [PageLayout.text] verbatim — it trims only to TEST emptiness — and
/// `photo_import_viewmodel._recombineAndParse` joins the pages as they are, so
/// a page's leading and trailing blank rows survive and no index needs
/// adjusting.
///
/// The PROVIDER's own string is a different case and keeps the global trim it
/// has always had: it addresses no line index, its only job is to be the
/// rollback, and it is what ships while `enable_layout_recipe_split` is off —
/// which is today's default. The asymmetry is the design, not an oversight.
///
/// That is precisely why the count comparison must still not trim either side:
/// a caller that trims its OWN input reintroduces the drift, and would then
/// have to subtract the removed rows from every index it converts. An untrimmed
/// count sees the disagreement and falls back, which is the safe direction.
///
/// (Two earlier drafts of this paragraph were wrong in opposite directions —
/// one prescribed trimming both, one described a per-page trim the adapter no
/// longer does. Both are recorded rather than deleted because the rule survived
/// both wrong reasons, and the next reader deserves to know that.)
///
/// That check is [DocumentLayout.matchesLineCountOf] — named here because the
/// rule sat in this paragraph unimplemented from the model's first commit until
/// step 6a, which is exactly what happens when a MUST points at nothing.
///
/// **The chain is live as of 2026-08-07**, and this paragraph describes what
/// runs rather than what is planned — it said the opposite that same morning,
/// so check it against the code before trusting either version:
///
///     ML Kit adapter -> `OCRResult.layout` (typed field, cached with the
///     text under one image-hash key) -> `_PhotoPage.layout` ->
///     `DocumentLayout` built in `_recombineAndParse` ->
///     `ImportManager.autoParseMulti(layout:)` ->
///     `MultiRecipeSplitter.split(input, layout:)`
///
/// All of it behind `enable_layout_recipe_split`, default off. The LAST hop
/// declines unless [DocumentLayout.matchesLineCountOf] accepts the string it
/// is handed — the earlier ones decline for their own reasons (a null
/// `PageLayout`, [DocumentLayout.isComplete], a page the detector cannot
/// judge), so do not go looking for this check in `_recombineAndParse`.
///
/// Scoped to the ViewModel path. `PhotoImportStrategy` is the OTHER photo
/// route (`importSinglePhoto`, the handwriting loops) and calls the text
/// strategy directly without passing through `autoParseMulti`, so no geometry
/// travels there and type-size splitting does not apply to it. A page from a paid tier, from the handwriting path or
/// from a restored draft carries no geometry, which makes the whole document
/// incomplete and sends the import back to the text rules.
library;

import 'package:butlery/services/ocr/glyph_metrics.dart';

/// An axis-aligned box in the coordinate space of the image the recognizer
/// read. That image is the PREPROCESSED one (downscaled, greyscaled), so these
/// coordinates do not address the user's original photo — only relative
/// measurements (height ratios, x-clustering) are meaningful, and those are
/// scale-invariant.
class LayoutBox {
  final double left;
  final double top;
  final double width;
  final double height;

  const LayoutBox({
    required this.left,
    required this.top,
    required this.width,
    required this.height,
  });

  double get right => left + width;
  double get bottom => top + height;

  Map<String, dynamic> toJson() => {
    'x': left,
    'y': top,
    'w': width,
    'h': height,
  };

  factory LayoutBox.fromJson(Map<String, dynamic> json) => LayoutBox(
    left: _num(json['x']),
    top: _num(json['y']),
    width: _num(json['w']),
    height: _num(json['h']),
  );

  @override
  String toString() => 'LayoutBox($left, $top, $width x $height)';
}

/// A stored capture is data from disk, so every read is defensive: a field that
/// is not a list decodes to "no geometry" and the caller falls back to the
/// text-only path. Throwing here would turn a corrupt replay file into a failed
/// import.
List<Object?> _listOf(Object? v) => v is List ? v : const [];

/// Same defensive shape as [_num] and [_listOf]: a non-String decodes to an
/// EMPTY string, never to its `toString()`. `_str(['a'])` returning "[a]"
/// would put a JSON fragment into the page as a text line, which is worse
/// than losing it — the siblings neutralise wrong types and this must too.
///
/// Written as an explicit type test rather than reaching for `.orEmpty()`
/// because BUT-581's guard bans the raw null-coalesce-to-empty-string form
/// under `lib/`. Keeping this file free of THIRD-PARTY dependencies is the reason
/// to write the helper rather than import the extension — not, as an earlier
/// draft said, a Flutter dependency: `default_value_extensions.dart` imports
/// only `package:clock`. (An earlier version of this paragraph said "zero
/// imports"; the sibling `glyph_metrics.dart` is now imported, and it is under
/// the same discipline. The property is dependency-freedom, not the count.)
String _str(Object? v) => v is String ? v : '';

/// A number written as a string is the commonest JSON round-trip corruption,
/// and every box dimension goes through here.
double _num(Object? v) {
  if (v is num) return v.toDouble();
  if (v is String) return double.tryParse(v) ?? 0;
  return 0;
}

/// One recognized word. Words carry their own box because a LINE box is a poor
/// height signal on a skewed photo: an axis-aligned box around a tilted line
/// grows with the line's WIDTH, so a long body line can measure taller than a
/// short heading. The per-word median is what callers should use.
class OcrWord {
  final String text;
  final LayoutBox box;

  const OcrWord({required this.text, required this.box});

  /// The word's box height divided by the vertical zones its GLYPHS occupy —
  /// an estimate of type size that does not depend on which letters the word
  /// happens to contain. See [glyphSpan] for why that distinction is load
  /// bearing and what the constants are.
  double get typeHeight {
    final span = glyphSpan(text);
    return span <= 0 ? box.height : box.height / span;
  }

  Map<String, dynamic> toJson() => {'t': text, ...box.toJson()};

  factory OcrWord.fromJson(Map<String, dynamic> json) => OcrWord(
    text: _str(json['t']),
    box: LayoutBox.fromJson(json),
  );
}

/// One recognized line of text, with the words that make it up.
class OcrLine {
  final String text;
  final LayoutBox box;
  final List<OcrWord> words;

  /// Normalises the text at the ONE point both producers pass through — the
  /// replay decoder, and the recognizer adapter the seam is about to gain.
  ///
  /// A newline inside a line's text makes that line occupy two rows of the
  /// produced string, and then [DocumentLayout.lineOffsets] (which counts rows)
  /// and [DocumentLayout.textLineIndex] (which counts list entries) disagree
  /// and hand back a confident wrong line number. Guarding it in `fromJson`
  /// alone covered only the replay path. Teaching each reader to count rows
  /// instead would put the same assumption in two places again, which is the
  /// defect this replaces.
  ///
  /// Costs `const`; that is the price of the invariant holding structurally
  /// rather than by everyone remembering.
  OcrLine({required String text, required this.box, this.words = const []})
    : text = text.replaceAll(_newlines, ' ');

  /// The line's type size, as the MEDIAN of its words' GLYPH-NORMALISED
  /// heights — see [OcrWord.typeHeight] for why the raw box height is a poor
  /// measure of type size.
  ///
  /// Median, not mean: a single mis-segmented fragment (OCR merging a glyph
  /// with the line above) can double a mean and turn body text into a
  /// "heading".
  ///
  /// **The two branches are NOT on the same scale and must never be compared
  /// with each other.** With words this is in x-height units; without them it
  /// falls back to the raw line box, which spans whatever the line's tallest
  /// and lowest glyphs reach. The fallback is deliberately not normalised,
  /// because no single word's letters describe a whole line's ink.
  ///
  /// That makes an unmeasured line unusable as a heading signal rather than
  /// merely imprecise: `glyphSpan`'s doc lists the attainable inflations and
  /// which of them clear a size bar on their own. Use [hasMeasuredWords] to
  /// refuse the comparison — [PageLayout.bodyTypeHeight] and `HeadingDetector`
  /// both do.
  ///
  /// The two kinds can share ONE page because element absence is per LINE: the
  /// ML Kit adapter maps each line's elements independently, so a page with one
  /// unsegmented row among segmented ones is representable whatever ML Kit
  /// happens to do per platform. That is the claim this guard rests on, and it
  /// is about code we own.
  double get typeHeight {
    if (words.isEmpty) return box.height;
    final heights = words.map((w) => w.typeHeight).toList()..sort();
    final mid = heights.length ~/ 2;
    return heights.length.isOdd
        ? heights[mid]
        : (heights[mid - 1] + heights[mid]) / 2;
  }

  /// Whether the line has WORD BOXES at all, so that [typeHeight] is a median
  /// of per-word measurements rather than the raw line box.
  ///
  /// Any comparison of one line's height against another's — a size bar, a page
  /// baseline, a page-relative floor — has to refuse the lines this is false
  /// for, because their value is on a different scale entirely. Same rule
  /// [PageLayout.bodyTypeHeight] already states for a line with no measurement
  /// at all: an absence, not a number.
  ///
  /// Passing is NECESSARY, not sufficient. [OcrWord.typeHeight] itself falls
  /// back to a raw box for any word holding no letters, so a line of purely
  /// numeric tokens answers true here and still measures on the raw scale —
  /// the same two-scales problem one level down. `HeadingDetector` is covered
  /// by its own quantity and leading-digit guards; [PageLayout.bodyTypeHeight]
  /// has no text rules and is where such a row could still reach the baseline.
  bool get hasMeasuredWords => words.isNotEmpty;

  /// Words on the line — the cheapest "is this a heading-shaped line" signal
  /// that does not depend on the text itself.
  int get wordCount {
    if (words.isNotEmpty) return words.length;
    final trimmed = text.trim();
    // `''.split(...)` yields `['']`, so an empty line would answer 1.
    return trimmed.isEmpty ? 0 : trimmed.split(RegExp(r'\s+')).length;
  }

  /// The box is splatted flat, the same spelling a word uses. This JSON is
  /// the contract with `tools/`, and one type deserves one wire shape there —
  /// otherwise a reader that isn't Dart writes two decoders for [LayoutBox].
  Map<String, dynamic> toJson() => {
    'text': text,
    ...box.toJson(),
    if (words.isNotEmpty) 'words': words.map((w) => w.toJson()).toList(),
  };

  factory OcrLine.fromJson(Map<String, dynamic> json) {
    final words = _listOf(json['words'])
        .whereType<Map>()
        .map((w) => OcrWord.fromJson(w.cast<String, dynamic>()))
        .toList();
    // A stored line may carry no box of its own — no capture records one — so
    // derive it from the words rather than decoding a zero, keeping a replayed
    // capture geometrically identical to a live one.
    //
    // NOTHING under `lib/` reads a line box today (2026-08-07): the detector
    // measures type size from WORD boxes, and [typeHeight] falls back to the
    // line box only for a line with NO words — where this rescue cannot change
    // that height, since `_union(const [])` is zero-HEIGHT too. (It is not the
    // same box in general: a line storing `x`/`y` but no `w`/`h` decodes at ITS
    // OWN stored origin, while the union returns the WORDS' origin — two
    // different points. Only the height is read, so only the height matters
    // here.) So the rescue is wire fidelity, not a live dependency;
    // `text_layout_test.dart` is what pins it.
    // Two earlier versions of this comment each named a beneficiary — first the
    // column orderer (measured and declined, ACCEPTED_DEVIATIONS.md), then the
    // heading detector (measured: identical output either way). Do not name a
    // third without measuring it.
    //
    // ONE spelling, matching [toJson] and a word's. A nested `box` key was
    // decoded here too until 2026-08-05; nothing has ever written one (0 in
    // 10,986 stored capture lines), and it quietly skipped the zero-rescue
    // below — the same content decoded to a zero-size box nested and a real
    // one flat.
    final flat = LayoutBox.fromJson(json);
    final box = (flat.width > 0 || flat.height > 0) ? flat : _union(words);
    return OcrLine(
      text: _str(json['text']),
      box: box,
      words: words,
    );
  }

  /// CR, LF or a run of either. A newline inside one line's text would make it
  /// occupy two rows of the produced string and shift every index after it.
  static final RegExp _newlines = RegExp('[\\r\\n]+');

  static LayoutBox _union(List<OcrWord> words) {
    if (words.isEmpty) {
      return const LayoutBox(left: 0, top: 0, width: 0, height: 0);
    }
    var l = words.first.box.left, t = words.first.box.top;
    var r = words.first.box.right, b = words.first.box.bottom;
    for (final w in words.skip(1)) {
      if (w.box.left < l) l = w.box.left;
      if (w.box.top < t) t = w.box.top;
      if (w.box.right > r) r = w.box.right;
      if (w.box.bottom > b) b = w.box.bottom;
    }
    return LayoutBox(left: l, top: t, width: r - l, height: b - t);
  }
}

/// One photographed page.
class PageLayout {
  final List<OcrLine> lines;

  /// Pixel size of the image these coordinates address (the preprocessed one).
  final double imageWidth;
  final double imageHeight;

  const PageLayout({
    required this.lines,
    this.imageWidth = 0,
    this.imageHeight = 0,
  });

  /// The page's own text. The single producer — see the library doc.
  String get text => lines.map((l) => l.text).join('\n');

  /// Body-text type size for THIS page, as the median over lines long enough
  /// to be running text. Per page, never across a document: two photos of the
  /// same book differ in distance, zoom and crop, so a shared baseline would
  /// call one page's body text the other page's headings.
  ///
  /// Returns null when the page has too few body-like lines to establish a
  /// baseline — a caller must then decline to judge rather than guess.
  double? get bodyTypeHeight {
    final heights =
        lines
            // Word boxes first: without them `typeHeight` is a raw line box on
            // a different scale from every normalised sibling, and averaging
            // the two produces a baseline that belongs to neither. One page can
            // carry both kinds because element absence is per LINE — see
            // [OcrLine.typeHeight].
            .where((l) => l.hasMeasuredWords && l.wordCount >= _minBodyWords)
            .map((l) => l.typeHeight)
            // A line with NO measurement is not a body line, it is an absence.
            // Keeping its 0 was the worst possible failure: a fully degraded
            // page answered a baseline of 0.0, and every `typeHeight >= body *
            // k` test then said TRUE for every line on it. On a MIXED page it
            // was quieter and just as wrong — two measured lines at 70 plus
            // two unmeasured gave 35, promoting both real body lines to
            // headings. Dropping them makes a fully degraded page decline, as
            // the contract below promises, and a partly degraded one measure
            // only what it actually measured.
            .where((h) => h > 0)
            .toList()
          ..sort();
    if (heights.length < _minBodyLines) return null;
    final mid = heights.length ~/ 2;
    return heights.length.isOdd
        ? heights[mid]
        : (heights[mid - 1] + heights[mid]) / 2;
  }

  /// A line needs this many words before it counts as running text rather than
  /// a heading, a label or OCR noise.
  static const int _minBodyWords = 4;

  /// Fewer body-like lines than this and the median is not a baseline, it is
  /// an accident.
  static const int _minBodyLines = 4;

  Map<String, dynamic> toJson() => {
    'width': imageWidth,
    'height': imageHeight,
    'lines': lines.map((l) => l.toJson()).toList(),
  };

  factory PageLayout.fromJson(Map<String, dynamic> json) => PageLayout(
    imageWidth: _num(json['width']),
    imageHeight: _num(json['height']),
    lines: _listOf(json['lines'])
        .whereType<Map>()
        .map((l) => OcrLine.fromJson(l.cast<String, dynamic>()))
        .toList(),
  );
}

/// Every page of one import, in capture order.
///
/// A photo import can hold several pages, and the parser sees them joined into
/// one string. Both the string and the line-index mapping are produced HERE, in
/// one place, so the offsets can never drift from the text they describe.
class DocumentLayout {
  /// One entry per page, in order. A null entry means "this page has no
  /// geometry" — a page that fell through to a provider that returns none.
  final List<PageLayout?> pages;

  const DocumentLayout(this.pages);

  /// True only when EVERY page carries geometry.
  ///
  /// Fail-closed on purpose. A document of mixed provenance would need line
  /// indices that are trustworthy on some pages and meaningless on others, and
  /// the failure is silent — the split lands in the wrong place and nothing
  /// reports it. Mixed tiers also mean mixed engines, so their type sizes are
  /// not comparable in the first place.
  bool get isComplete => pages.isNotEmpty && pages.every((p) => p != null);

  /// The combined text — the string the parser will see — or null when any
  /// page lacks geometry.
  ///
  /// Null, not a best effort. A geometry-less page is one a paid tier read: it
  /// contributes its OWN lines to the real combined string, and this object has
  /// no idea how many. Producing a plausible-looking string there would be
  /// wrong by an unbounded amount and would look exactly like a correct one.
  String? get text =>
      isComplete ? pages.map((p) => p!.text).join(_pageSeparator) : null;

  /// Every line of every page, flattened in capture order.
  ///
  /// An index here is the line number WITHIN ITS PAGE's slice, NOT a line
  /// number in [text] — past page one they differ by the blank separator. Use
  /// [textLineIndex] to convert; that is the whole reason it exists. "Capture
  /// order" is the recognizer's order, which need not be reading order on a
  /// two-column spread — no re-orderer exists, and building one was measured
  /// and declined on 2026-08-07 (see ACCEPTED_DEVIATIONS.md).
  List<OcrLine> get lines => [for (final page in pages) ...?page?.lines];

  /// Where each page's first line starts, counted in lines of [text], or null
  /// when [text] is null.
  ///
  /// Counted from the string each page actually produces, never from
  /// `lines.length`: a page with zero lines still occupies one (empty) row of
  /// [text], and counting the list instead put every later page one line early
  /// while [isComplete] still reported true.
  List<int>? get lineOffsets {
    if (!isComplete) return null;
    final offsets = <int>[];
    var cursor = 0;
    for (var i = 0; i < pages.length; i++) {
      offsets.add(cursor);
      cursor += _newlineCount(pages[i]!.text) + 1;
      if (i + 1 < pages.length) cursor += _separatorLines;
    }
    return offsets;
  }

  /// True when [input] has the same number of ROWS as [text] — the check the
  /// library doc above mandates before any line index may be trusted.
  ///
  /// It lives here so no caller invents its own version. The step-5 review
  /// (d8d565981) found the rule written down and implemented nowhere, which
  /// left a heading index addressing a string nobody had shown matched the
  /// parser's input. (An earlier draft credited the seam commit's review
  /// instead; that one caught the trimming paragraph, not this gap. Recorded
  /// rather than replaced, because the same mistake was then reported as fixed
  /// when the edit had silently failed to apply.)
  ///
  /// ROWS, not bytes: `HtmlSanitizer.sanitizeText` runs between here and the
  /// parser, rewriting homoglyphs and stripping control characters while
  /// preserving newlines, so byte equality fails on healthy pages and would
  /// disable the layout path permanently.
  ///
  /// UNTRIMMED on both sides: the provider's own string is trimmed on the
  /// tier-0 path, and trimming here too would hide exactly the row shift that
  /// makes an index wrong. A caller that trimmed its own input must subtract
  /// the removed rows itself, not ask this to forgive them.
  ///
  /// Passing is NECESSARY, not sufficient. Two strings of equal row count are
  /// indistinguishable to this check, and the tier-0 provider string and the
  /// layout string OFTEN have equal row counts. (Until 2026-08-08 that read
  /// "usually … they differ only in separators and a global trim". Since
  /// `edge_crop.dart` the layout string also has rows REMOVED — 132 of 181
  /// corpus pages — so on a cropped page the counts differ and this check does
  /// catch the mix-up. On an uncropped page they still match, so the reasoning
  /// below is unchanged: the crop makes this gate stronger, never sufficient.)
  /// So a cached `OCRResult` holding one while
  /// the layout beside it was built from the other would pass here and still
  /// be addressed by the wrong indices. That is closed elsewhere and NOT here:
  /// `OCRResult` carries text and geometry as one object and the cache stores
  /// that object whole under one image-hash key (2026-08-07), so the pair can
  /// never be re-combined. This method still cannot cover it and must never be
  /// described as covering it.
  ///
  /// False whenever [text] is null — an incomplete document can never pass.
  bool matchesLineCountOf(String input) {
    final own = text;
    if (own == null) return false;
    return _newlineCount(own) == _newlineCount(input);
  }

  /// Converts an index into [lines] to a line number in [text].
  ///
  /// Exists so no caller ever hand-rolls the page arithmetic.
  /// `MultiRecipeSplitter` works in indices of the newline-split input, so a
  /// heading found at `lines[i]` has to arrive as a TEXT line number or it
  /// opens a recipe block in the wrong place.
  int? textLineIndex(int flatIndex) {
    final offsets = lineOffsets;
    if (offsets == null || flatIndex < 0) return null;
    var seen = 0;
    for (var p = 0; p < pages.length; p++) {
      final n = pages[p]!.lines.length;
      if (flatIndex < seen + n) return offsets[p] + (flatIndex - seen);
      seen += n;
    }
    return null;
  }

  /// The blank line between pages — the same separator
  /// `photo_import_viewmodel._recombineAndParse` already uses, so page
  /// boundaries read like the blank lines that separate sections within a page.
  static const String _pageSeparator = '\n\n';

  /// Derived, not restated: how many empty rows [_pageSeparator] inserts.
  static final int _separatorLines = _newlineCount(_pageSeparator) - 1;

  static int _newlineCount(String s) => '\n'.allMatches(s).length;
}
