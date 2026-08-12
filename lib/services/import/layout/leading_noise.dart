/// Cuts furniture off the FRONT of a photographed page, before its first
/// recipe starts.
///
/// [withoutOrphanTail] (same directory) cuts a heading the camera frame
/// separated from its own recipe off the END of the last page. This is its
/// mirror at the other edge: a running header, a folio/page number, or the
/// tail end of the PREVIOUS recipe can sit above the first page's own title,
/// and today it ships straight into the recipe [MultiRecipeSplitter] opens.
///
/// ## Why this is a weaker claim than the tail trim, not an equal one
///
/// [withoutOrphanTail]'s budget is safe because the tail it cuts is a suffix
/// of the very block [MultiRecipeSplitter] would have opened at that same
/// heading — its own doc proves the cut cannot destroy a block the layout
/// path would have kept. No such block exists here: in
/// `MultiRecipeSplitter._splitByLayout`, everything before the first
/// detected heading is discarded UNCONDITIONALLY, never evaluated as a
/// candidate block at all — so there is no sibling guarantee to lean on for
/// the content this rule removes.
///
/// The splitter's own safety net — `'a recipe BEFORE the first heading
/// cancels the split'`
/// (`test/unit/services/import/multi_recipe_splitter_layout_test.dart`) —
/// only fires once TWO headings have been found. On the single-heading page
/// (one recipe per photo, the common case, and exactly the page population
/// this rule targets) that net does not exist. A real recipe whose title
/// [HeadingDetector] refused (too long, lower-case first letter, a digit, a
/// trailing colon) sitting before the first DETECTED heading would today be
/// silently eaten with no other rule to catch it.
///
/// Two things hold the line instead: a smaller budget than the tail trim's
/// (`_leadingBudget`, half of `_tailBudget`, because there is no size-of-a-
/// kept-block proof to lean on here), and a hard refusal to cut anything
/// that reads like real recipe content — see [_looksLikeRecipeContent].
/// Furniture (a running header, a folio, a page number) essentially never
/// contains a measurement or a cooking verb; a missed recipe title almost
/// always has ingredients or instructions right behind it.
///
/// ## Unmeasured — the budget below is a starting point, not a result
///
/// [_tailBudget] was set by running `dart run tools/corpus_split_eval.dart
/// --trim` against 181 hand-graded corpus pages. This rule's `--leading-trim`
/// counterpart exists in the same tool, but nobody has run it — the corpus
/// lives outside every sandbox this rule has been developed in. Do not read
/// [_leadingBudget] as measured; it is the tail trim's OTHER real number (the
/// 60-budget row of its own measurement table, not an invented figure), used
/// here because leading noise is a different population and deserves a
/// smaller default until someone with corpus access runs `--leading-trim`
/// and reports a real number. **Run that before trusting this rule at scale
/// — i.e. before `enable_layout_recipe_split` is turned on for real users.**
///
/// ## Only page ZERO is ever eligible
///
/// Not because a heading could splice across pages (the tail trim's own
/// reason for restricting to the last page) — page zero's reason is
/// sharper: it is the only page in the document guaranteed to have nothing
/// legitimate before it. Any LATER page's leading content is, in practice,
/// the tail end of the PREVIOUS page's own recipe (its last ingredients or
/// instructions) — cutting that would be a plain content-loss bug, not a
/// corpus-tunable trade-off, so this rule never looks past page zero.
///
/// ## Composes with [withoutOrphanTail] on the same page
///
/// A single-photo import means page zero and the last page are the SAME
/// [PageLayout]. `ImportManager.autoParseMulti` runs the tail trim first,
/// so by the time this rule reads the page, [PageLayout.bodyTypeHeight] may
/// already be a different (smaller) median than before the tail was cut.
/// Both rules independently re-derive their own heading list from whatever
/// page they are handed, so this is safe by construction rather than by
/// coincidence — but it is why `leading_noise_test.dart` carries a
/// composition case exercising both rules on one page, not just each rule
/// alone.
library;

import 'package:butlery/services/import/layout/heading_detector.dart';
import 'package:butlery/services/import/parsers/recipe_section_detector.dart';
import 'package:butlery/services/ocr/text_layout.dart';

/// Below this many characters before the first heading, the head is
/// furniture. See the library doc — this is a provisional default, not a
/// corpus-measured one.
const int _leadingBudget = 60;

/// True when [lines] reads like it belongs to a recipe rather than page
/// furniture — a measurement/ingredient line, or a cooking-instruction
/// keyword anywhere in the block. Checked in ADDITION to the character
/// budget, never instead of it: furniture is short AND unstructured: content
/// worth protecting can be either short-but-structured (a stray ingredient
/// line) or long (caught by the budget alone).
bool _looksLikeRecipeContent(List<String> lines) {
  if (lines.any(RecipeSectionDetector.looksLikeIngredient)) return true;
  return RecipeSectionDetector.hasInstructionKeywords(lines.join('\n'));
}

/// [input] and [layout] with leading furniture removed from the front of the
/// FIRST page, or both unchanged.
///
/// Returns the ORIGINAL objects when there is nothing to do, so a caller can
/// test `identical(result.text, input)` to tell whether anything happened —
/// same contract as [withoutOrphanTail].
({String text, DocumentLayout? layout}) withoutLeadingNoise(
  String input,
  DocumentLayout? layout,
) {
  final unchanged = (text: input, layout: layout);
  if (layout == null || !layout.matchesLineCountOf(input)) return unchanged;

  // Only page ZERO may be trimmed — see the library doc for why that is a
  // sharper claim than "the first page", not just the mirror of "the last
  // page" the tail trim restricts itself to.
  //
  // Belt and braces, same convention as `withoutOrphanTail`: `pages.isEmpty`
  // and `first == null` cannot fire once `matchesLineCountOf` passed
  // (it implies `isComplete`); `lines.isEmpty` CAN fire, and just falls
  // through to the next guard returning the same `unchanged` one line later.
  final pages = layout.pages;
  if (pages.isEmpty) return unchanged;
  final first = pages.first;
  if (first == null || first.lines.isEmpty) return unchanged;

  final headings = HeadingDetector.headingLines(first);
  if (headings.isEmpty) return unchanged;
  final pageRow = headings.first;
  // A heading already on the page's first row leaves nothing before it to
  // cut.
  if (pageRow == 0) return unchanged;

  final leadingLines = [
    for (var i = 0; i < pageRow; i++) first.lines[i].text,
  ];
  final headChars = leadingLines.fold<int>(
    0,
    (sum, text) => sum + text.trim().length,
  );
  if (headChars >= _leadingBudget) return unchanged;

  // Refuse even an under-budget cut if what precedes the heading reads like
  // real recipe content rather than furniture — see the library doc and
  // [_looksLikeRecipeContent].
  if (_looksLikeRecipeContent(leadingLines)) return unchanged;

  // `headingLines` indexes into the PAGE; `textLineIndex` wants an index
  // into the FLATTENED document. Page zero's own lines start the flattened
  // list, so no offset is needed here — the tail trim's fold over preceding
  // pages has no equivalent on this end of the document.
  final textRow = layout.textLineIndex(pageRow);
  // Unreachable once the gates above passed — belt and braces, same
  // convention as `withoutOrphanTail`.
  if (textRow == null) return unchanged;

  final rows = input.split('\n');
  // Unreachable once the gates above passed: `pageRow >= 1` puts the cut at
  // least one row into page zero, and the row-count gate already made
  // `rows.length` equal to the geometry's own total.
  if (textRow <= 0 || textRow > rows.length) return unchanged;

  // Both sides lose the same count — the page drops `pageRow` rows from its
  // front and the text drops `textRow` rows from its front, which are equal
  // because page zero's slice starts at the start of both. So
  // `matchesLineCountOf` still passes for the pair returned here.
  final trimmedPage = PageLayout(
    lines: first.lines.sublist(pageRow),
    imageWidth: first.imageWidth,
    imageHeight: first.imageHeight,
  );
  final trimmedPages = [trimmedPage, ...pages.sublist(1)];

  return (
    text: rows.sublist(textRow).join('\n'),
    layout: DocumentLayout(trimmedPages),
  );
}
