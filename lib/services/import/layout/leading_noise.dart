/// Cuts furniture off the FRONT of a photographed page, before its first
/// recipe starts.
///
/// [withoutOrphanTail] (same directory) cuts a heading the camera frame
/// separated from its own recipe off the END of the last page. This is its
/// mirror at the other edge: a running header, a folio/page number, or the
/// tail end of the PREVIOUS recipe can sit above the first page's own title.
/// What happens to it today depends on whether the page splits: when
/// `MultiRecipeSplitter` opens two or more blocks it is discarded as
/// furniture, and when the splitter DECLINES — which is the single-recipe
/// page, the common case — it ships straight into the recipe. Those two
/// sentences have conditions and an earlier draft of this paragraph stated
/// neither.
///
/// ## Why this is a weaker claim than the tail trim, not an equal one
///
/// [withoutOrphanTail] cuts a suffix of the very block [MultiRecipeSplitter]
/// would have opened at that same heading, and its own doc argues the cut
/// therefore mostly cannot destroy a block the layout path would have kept.
/// **That argument is a MARGIN — `budget + 60 + tailRowCount <= 200`, and in
/// that file's own words "not a theorem".** Do not restate it as a proof:
/// the first draft of THIS file did exactly that, and the asymmetry it was
/// invoked to establish is the whole subject of this section.
///
/// At this end of the page the sibling guarantee is a different shape again.
/// `MultiRecipeSplitter._splitByLayout` never evaluates the pre-heading
/// region as a candidate block — it only COUNTS it, into `discarded`, and
/// cancels the entire layout split once that reaches `_minLayoutBlockChars`
/// (200), handing the untouched input to the text rules. So a guarantee does
/// exist here, at 200-character granularity. It just does not exist on the
/// path this rule is FOR.
///
/// The splitter's own safety net — `'a recipe BEFORE the first heading
/// cancels the split'`
/// (`test/unit/services/import/multi_recipe_splitter_layout_test.dart`) —
/// only fires once TWO headings have been found, and so does the discard
/// budget above: `_splitByLayout` returns at `flat.length < 2` before any
/// discard accounting runs. On the single-heading page (one recipe per
/// photo, the common case, and exactly the page population this rule
/// targets) NEITHER exists. A real recipe whose title [HeadingDetector]
/// refused (too long, lower-case first letter, a digit, a trailing colon)
/// sitting before the first DETECTED heading would today be silently eaten
/// with no other rule to catch it.
///
/// Two things hold the line instead: a smaller budget than the tail trim's
/// (`_leadingBudget`, half of `_tailBudget`, because the margin argument
/// above does not reach this end of the page at all), and a hard refusal to
/// cut anything that reads like real recipe content — see
/// [_looksLikeRecipeContent], and read its body rather than its name, since
/// what it actually tests is much broader than "a measurement or a cooking
/// verb" and errs heavily toward refusing the cut.
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
/// [PageLayout]. `ImportManager.autoParseMulti` runs the tail trim FIRST, so
/// by the time this rule reads the page, [PageLayout.bodyTypeHeight] — a
/// MEDIAN over the lines with four or more measured words — may already have
/// moved. Either direction: removing lines below the median raises it.
///
/// **This composition is NOT safe by construction, and an earlier version of
/// this paragraph said it was.** Re-deriving the heading list from the page
/// in hand buys index consistency — no rule ever addresses a row that moved —
/// and nothing more. It does not fix WHICH row comes back as
/// `headings.first`. When the tail trim's cut raises the median far enough,
/// the absolute bar `bodyTypeHeight * headingSizeRatio` rises with it, the
/// page's real title can drop OUT of the heading list, `headings.first` moves
/// to a later title, and the region this rule then measures against
/// [_leadingBudget] contains that real title and its opening lines.
/// Constructed and executed on 2026-08-12: with a folio, a real title, four
/// short content rows, a second title and an orphan tail, the shipped order
/// emits the second title alone and the real recipe is gone. Running THIS
/// rule first, on the untouched page, does not reproduce it.
///
/// What actually bounds the damage is [_leadingBudget] and
/// [_looksLikeRecipeContent] — two unmeasured heuristics — so the honest
/// statement is that the composition is safe by budget, not by construction.
/// The window is narrow (the eaten region must still come in under 60
/// characters, which needs unusually short body rows), it is dark while
/// `enable_layout_recipe_split` is off, and the fix — swapping the two rules,
/// since furniture rarely carries the four-word lines that move a median —
/// is deliberately NOT applied here: it would change the input
/// `withoutOrphanTail` is measured on and silently invalidate every figure in
/// that file's tables and in `ACCEPTED_DEVIATIONS.md` until the corpus is
/// re-run. That trade is Malin's to make, not this file's.
///
/// `import_manager_orphan_tail_test.dart` carries a composition case
/// exercising both rules on one page. It pins the ORDER, not this hazard —
/// its fixture's baseline does not cross the heading bar.
library;

import 'package:butlery/services/import/layout/heading_detector.dart';
import 'package:butlery/services/import/parsers/recipe_section_detector.dart';
import 'package:butlery/services/ocr/text_layout.dart';

/// Below this many characters before the first heading, the head is
/// furniture. See the library doc — this is a provisional default, not a
/// corpus-measured one.
const int _leadingBudget = 60;

/// True when [lines] reads like it belongs to a recipe rather than page
/// furniture. Checked in ADDITION to the character budget, never instead of
/// it: content worth protecting can be short-but-structured (a stray
/// ingredient line) or long (caught by the budget alone).
///
/// **Read the two predicates, not their names — they are much broader and
/// much narrower than "an ingredient line or a cooking verb", in different
/// directions, and the library doc above leans on this guard to justify a
/// second rule shipping without the tail trim's margin argument.**
///
/// Broader: `looksLikeIngredient` also returns true for ANY line holding a
/// comma at 4-79 characters, any `½¼¾`, a leading bullet, and ~25 bare food
/// words. Measured against real Swedish page furniture on 2026-08-12, that
/// blocks the trim on `FISK OCH SKALDJUR`, `KÖTT OCH FÅGEL`, `Potatis och
/// rotfrukter`, `Ris och pasta` and `Vardagsmat, snabbt` — i.e. on exactly
/// the chapter-name running headers a cookbook prints on every page. The
/// rule is not dead, but where it declines is correlated with the content of
/// the book rather than random.
///
/// Narrower: the same measurement found 15 of 17 realistic recipe rows read
/// as furniture. `looksLikeIngredient` misses the `numeral + plural noun`
/// shape whole (`3 potatisar`, `4 morötter`, `2 äpplen`), and
/// `hasInstructionKeywords` carries four bare verbs — `koka`, `stek`,
/// `blanda`, `rör` — so `Skala och tärna`, `Vispa`, `Grädda 12 minuter`,
/// `Sätt in i ugnen`, `Häll upp i skålar` all pass straight through. So the
/// library doc's "a missed recipe title almost always has ingredients or
/// instructions right behind it" is true of PAGES and false of this
/// predicate. Both facts are unmeasured against the corpus, like everything
/// else on this rule.
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
