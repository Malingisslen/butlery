/// Drops the sliver of a NEIGHBOURING column that a phone photo catches at the
/// frame's edge.
///
/// Hold a cookbook flat and shoot one page, and the page beside it usually
/// creeps into the shot — three or four characters wide, sliced vertically by
/// the frame. The recognizer reads it faithfully and the import ends on `oc`
/// instead of on `lagad.` The fragments are unusable by construction: the frame
/// cut the words, so no downstream parsing recovers them.
///
/// This runs on every tier-0 recognition, but only REACHES an import on the
/// geometry arm: with `enable_layout_recipe_split` off — the code default —
/// `OCRExtractionService` ships `providerText`, which is uncropped and has no
/// geometry to crop against. So the symptom above persists in the default
/// configuration, by construction rather than by oversight.
///
/// ## The rule never looks at the image border
///
/// The obvious rule — "ink touching the edge of the picture" — cannot be written
/// here. [PageLayout.imageWidth] is 0 on a device (ML Kit reports no image size),
/// so any ratio against it degenerates silently rather than throwing, and an
/// absolute pixel tolerance means different things on a 4000px scan and the
/// 2048px production downscale. An earlier draft divided by the page's widest
/// ink extent instead, which is worse: the right-edge test is then true BY
/// CONSTRUCTION for whichever line owns that extent, leaving only a width test
/// between a short real word and deletion.
///
/// So the reference is the page's own body text. A bleed fragment is a NARROW
/// line lying entirely OUTSIDE the margins the body text keeps. Scale-free,
/// needs no image size, and no clause can satisfy itself.
///
/// Measured over the 181 hand-verified corpus pages — PROXY figures, Windows
/// offline OCR rather than ML Kit, re-derivable with
/// `dart run tools/corpus_split_eval.dart --edge-crop`:
/// gold-token recall 91.56 % -> 91.54 %, precision 66.26 % -> 66.64 %, pages
/// with the right recipe count 138 -> 139. On the 45 pages carrying a real
/// partial column, precision 66.65 % -> 67.70 %.
///
/// **Read that recall pair as an upper bound, not as proof nothing was lost.**
/// The token floor is three characters, so `dl`, `g`, `st`, `ml` and `cl` never
/// enter the gold set — and a right-hand quantity column is exactly the shape
/// this rule deletes. Of the 496 rows dropped corpus-wide, **62** consist only
/// of sub-3-character words that DO appear in that page's gold, and they are
/// invisible to 91.56 -> 91.54.
///
/// **37 of those 62 are bare numerals** (`1/2`, `2-3`, `50`) and 25 carry
/// letters. Read the whole 62 as an UPPER bound, both halves: small digits sit
/// in nearly every page's gold whether the deleted row was this page's quantity
/// column or the neighbour's, and 24 of the 25 letter rows are stopword
/// fragments — e.g. `i`, `en`, `de`, `är`, `på`, `då.` — which have the same
/// problem (measured 2026-08-08; only `ca 2` looked like a real quantity).
///
/// Two earlier drafts of this paragraph were wrong in the reassuring direction:
/// "mostly stray marginal words" (it is mostly numerals), then "letters are the
/// stronger signal of real loss" (they are stopwords). The honest statement is
/// that the recall pair cannot see this class at all, and 62 over-counts it.
///
/// The arm prints that 62 on its own line, so it is re-derivable like the rest.
/// It says 62 rather than the 41 an earlier draft of this paragraph claimed:
/// that figure came from a deleted probe, was never printed by anything, and
/// understated the blind spot by a third. A number in a doc that no shipped
/// command emits is the defect, not the number.
library;

import 'package:butlery/services/ocr/text_layout.dart';

/// A line joins the body-margin vote only if its ink spans at least this much of
/// the widest line. Narrow furniture must not get to define the margin it is
/// then measured against.
const _bodyWidthShare = 0.30;

/// A bleed fragment is no wider than this share of the body's own span.
///
/// Together with [_bodyWidthShare] this is what makes the rule non-circular: a
/// body line spans at least 0.30 x widest, and `bodySpan` is at most `widest`,
/// so a line that helped define the margins can never clear the 0.12 x bodySpan
/// bar. The line that owns the page's widest extent is never droppable.
const _bleedWidthShare = 0.12;

/// Below this many measurable lines the page gives no basis to judge.
const _minMeasurableLines = 6;

/// Below this many body lines the margins would be a guess, not a median.
const _minBodyLines = 4;

/// A rule that wants a third of the page is not seeing a bleed column — it is
/// seeing a badly framed shot, or a genuinely narrow single-column page.
const _maxCropShare = 1 / 3;

/// Horizontal ink extent of one line.
class _Span {
  const _Span(this.left, this.right);

  final double left;
  final double right;

  double get width => right - left;
}

/// Ink extent from the WORD boxes, never from [OcrLine.box].
///
/// The two disagree by origin: on a device `box` is ML Kit's own line rect,
/// while a replayed capture derives it from this same word union
/// (`docs/architecture/ACCEPTED_DEVIATIONS.md`). Walking words is the only path
/// that answers identically in both, which is what lets a corpus measurement
/// mean anything about the phone.
_Span? _inkSpan(OcrLine line) {
  if (line.words.isEmpty) return null;
  var left = double.infinity;
  var right = double.negativeInfinity;
  for (final word in line.words) {
    final l = word.box.left;
    final r = word.box.left + word.box.width;
    if (l < left) left = l;
    if (r > right) right = r;
  }
  return right <= left ? null : _Span(left, right);
}

double _median(List<double> values) {
  final sorted = [...values]..sort();
  return sorted[sorted.length ~/ 2];
}

/// Row indices in [page] that are edge bleed.
///
/// Empty means "keep everything" for BOTH reasons a caller might care about —
/// nothing qualified, and the page gave no basis to judge. That collapse is
/// deliberate: every outcome here is "crop or don't", and a caller that cannot
/// act differently on the two should not be handed the distinction.
///
/// A line with no word boxes is never dropped: it carries no geometry, so there
/// is nothing to judge it on, and refusing to judge is the safe direction.
Set<int> _edgeBleedRows(PageLayout page) {
  final spans = <int, _Span>{};
  for (var i = 0; i < page.lines.length; i++) {
    final span = _inkSpan(page.lines[i]);
    if (span != null) spans[i] = span;
  }
  if (spans.length < _minMeasurableLines) return const {};

  final widest = spans.values
      .map((s) => s.width)
      .reduce((a, b) => a > b ? a : b);
  if (widest <= 0) return const {};

  final body = spans.values
      .where((s) => s.width >= _bodyWidthShare * widest)
      .toList();
  if (body.length < _minBodyLines) return const {};

  final bodyLeft = _median(body.map((s) => s.left).toList());
  final bodyRight = _median(body.map((s) => s.right).toList());
  final bodySpan = bodyRight - bodyLeft;
  if (bodySpan <= 0) return const {};

  final bleed = <int>{};
  spans.forEach((row, span) {
    if (span.width > _bleedWidthShare * bodySpan) return;
    // Outside the body's margins, not merely short. A narrow line INSIDE them is
    // an ingredient amount or a one-word instruction, and dropping those is the
    // failure mode this clause exists to prevent.
    if (span.left >= bodyRight || span.right <= bodyLeft) bleed.add(row);
  });

  if (bleed.length > page.lines.length * _maxCropShare) return const {};
  return bleed;
}

/// [page] without its edge bleed, or [page] unchanged when there is none.
///
/// Must run BEFORE anything derives [PageLayout.text] from the page.
/// `MultiRecipeSplitter._splitByLayout` discards the geometry unless
/// [DocumentLayout.matchesLineCountOf] accepts the string it was handed — a ROW
/// COUNT comparison, deliberately NOT a byte one, because `HtmlSanitizer`
/// rewrites bytes between the two and byte equality would disable the layout
/// path permanently.
///
/// So the consequence of cropping too late is worse than a no-op: the string
/// would still carry rows the page no longer has, the counts would disagree, and
/// the whole layout path would decline for that page — losing the type-size
/// splitting as well as the crop.
PageLayout cropEdgeBleed(PageLayout page) {
  final bleed = _edgeBleedRows(page);
  if (bleed.isEmpty) return page;

  final kept = <OcrLine>[];
  for (var i = 0; i < page.lines.length; i++) {
    if (!bleed.contains(i)) kept.add(page.lines[i]);
  }
  if (kept.isEmpty) return page;

  // Carry the image size across. It is 0 from ML Kit today, so this changes
  // nothing in production — but a cropped page that silently zeroed a field the
  // original had set is the wrong-value-not-crash class, and it would only ever
  // bite on the pages this function touched.
  return PageLayout(
    lines: kept,
    imageWidth: page.imageWidth,
    imageHeight: page.imageHeight,
  );
}
