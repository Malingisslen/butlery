/// Cuts a heading that belongs to the NEXT recipe off the end of a photographed
/// page.
///
/// A photo is a window onto a continuous stream of recipes, and its bottom edge
/// lands wherever it lands. What sits there is often the next recipe's title
/// with nothing under it, and it ships inside the previous recipe. Malin
/// reported exactly this.
///
/// All 10 tails the shipped budget CUTS over the corpus, each read against its
/// PHOTOGRAPH on 2026-08-09 rather than as bare text — the whole set, so this
/// list stays checkable and no case can hide behind a flattering example.
/// **`dart run tools/corpus_split_eval.dart --trim` prints this same list**,
/// page id and all, so it is verifiable by command and not only by trust. Each
/// entry below is quoted AS THE RECOGNIZER READ IT, which is what the command
/// prints, with the word actually on the page after it. (The printed column
/// truncates a heading longer than 34 characters — none of these ten reach it,
/// and the run's JSON report carries the untruncated string in `trimmedDetail`.)
///
/// - `Mandelforell` (24 chars follow), `Vard{` (22, = Vardagssoppa), `Varm`
///   (98, = Varm bärsås), `Kraftf` (70, = Kraftfullt…), `Köttsa/l`
///   (8, = Köttsallad), `IAUS` (0, = a `Hus…` display heading on the facing
///   page's sliver) — the next recipe's title, its first lines sliced off by
///   the frame.
///
///   `IAUS` was listed separately as "four characters the recognizer invented"
///   until 2026-08-09. It is not invented: the capture's rows around it read
///   `L anilJso` / `rikt` / **`IAUS`** / `t.es.` / `gott j`, which map in order
///   onto the photo's `Lammso[ppa]` / `En rikti[g]` / `Hus…` / `t.ex.` /
///   `gott ju`. **The trap that produced the wrong reading:** on this page the
///   capture's y coordinates sit about one text line above the JPEG's text, so
///   cropping to a row's stored box shows blank paper and the row looks like
///   noise from nowhere. Match a capture row to the image by ORDERED CONTENT,
///   never by cropping to the stored box.
/// - `Olika fyllningar med vaniljkräm` (8) — a NEW SECTION's display heading at
///   the page foot with nothing readable under it; its content is on the next
///   page. The 8 characters are not even a separate row of content — they are
///   the heading's OWN second line, `om grund` (`som grund` on the page, the
///   `s` lost), which strengthens rather than qualifies "nothing under it".
/// - `Djupfrysning av tårtor` (98) — also a new section's display heading, but
///   NOT empty under it: the 98 characters are that section's own opening
///   sentence — complete — plus the start of its next one, interleaved with the
///   neighbouring column
///   (`De flesta tårtor kan djupfrysas Tårtbo / Fyllda / helt färdiga med gott
///   resultat. / År det dock bäst och ba`). Listed separately from the line
///   above on purpose — an earlier draft merged the two under "nothing readable
///   under it", which was false for this one and leaned in the feature's favour,
///   in the very list that exists so no case can hide behind a flattering
///   example. The cut is still right (Malin graded it from the photograph): the
///   section continues on the next page and none of it is part of the recipe
///   above.
/// - `Sina ingredienser` (0), `Sina ingr` (0) — not from the cookbook at all.
///   They are the blurb on the back of a DIFFERENT book lying on the table
///   behind the one being photographed.
///
/// Deliberately NOT cut: `Inlagd sill` (159 chars under it) and
/// `Annas hurtbullar` (143) sit in the band this rule leaves alone, so they
/// still ship. Naming a case the rule does not handle as its motivating example
/// is how a doc stops being checkable.
///
/// A first pass called two of the ten wrong, having read the text and not the
/// photographs. Both were right. If you are about to re-judge this list, open
/// the images.
///
/// ## Trimming is not splitting, and that is why this exists
///
/// `MultiRecipeSplitter` declines on these pages and the text rules put the
/// heading back. Measured over ALL 247 stored captures as of 2026-08-08 — not
/// the 181 with gold, which is the population the eval arms score — 19 pages end
/// their import on such a heading. **14 of the 19 never get as far as building a
/// block:** they exit at `flat.length < 2` — the probe found exactly one
/// heading on each of them — before any discard happens, and no change to the
/// splitting rules can reach them. Only the remaining minority reach the "finds
/// it, discards it, then notices it has fewer than two blocks" path — and even
/// there the label only fits 2 of them: 3 exit on the DISCARD BUDGET, which is
/// checked before the block count, and 2 on the single-block rule. Do not let the vivid mechanism stand for the common case;
/// an earlier draft of this paragraph led with it and buried the 14.
///
/// Cut the tail off the input instead and the MECHANISM reaches every such
/// page, splitting or not — the shipped 120-character budget then decides how
/// many are actually trimmed. Over the arm's 181 gold pages that is 10.
///
/// **Two populations, do not partition one into the other.** The 19 above is a
/// one-off probe over all 247 raw captures. The arm scores only the 181 with
/// gold — and at budget 200 it also counts 19, which is consistent with all 19
/// probe pages carrying gold but is not proof of it. Treat them as separate
/// measurements that happen to agree.
///
/// ## The 120-character ceiling is measured, not chosen
///
/// A tail is dropped when under [_tailBudget] characters follow the page's last
/// heading. Over the 181 gold pages, on top of the shipped edge crop
/// (`dart run tools/corpus_split_eval.dart --trim`):
///
/// | budget | pages | precision       | recall          | right block counts |
/// |--------|-------|-----------------|-----------------|--------------------|
/// | 60     | 7     | 66.64 -> 66.67 %| 91.54 -> 91.52 %| 139, unchanged     |
/// | **120**| **10**| 66.64 -> 66.77 %| 91.54 -> 91.52 %| 139, unchanged     |
/// | 200    | 19    | 66.64 -> 66.98 %| 91.54 -> **91.33 %** | **138 — a page lost** |
///
/// Only the 120 row runs from the shipped constant. The other two need
/// `_tailBudget` edited and `--trim` re-run — same caveat `heading_detector.dart`
/// carries on its own tables.
///
/// **The same sweep on gold that is not frame-cut debris — BUT-1847, and the
/// row that decides the ceiling is the 200 one, measured here for the first
/// time.** Same command plus `--no-frame-cut`, same 181 pages, same trimmed
/// pages; only the POPULATION of scored gold entries differs (see the next
/// section for what was dropped and why):
///
/// | budget | pages | precision       | recall          | right block counts | gold tokens lost |
/// |--------|-------|-----------------|-----------------|--------------------|------------------|
/// | 60     | 7     | 65.83 -> 65.87 %| 91.64 -> 91.64 %| 145, unchanged     | **0** (15925 -> 15925) |
/// | **120**| **10**| 65.83 -> 65.97 %| 91.64 -> 91.64 %| 145, unchanged     | **0** (15925 -> 15925) |
/// | 200    | 19    | 65.83 -> 66.27 %| 91.64 -> **91.59 %** | **144 — a page lost** | **9** (15925 -> 15916) |
///
/// So the shipped budget's content cost is zero under BOTH golds, and the 200
/// budget's is NOT (this 9 is gold TOKENS — not to be read against the 9 band
/// tails counted further down, which are pages; the two are unrelated):
/// of the 36 gold tokens it costs on biased gold
/// (`16121 -> 16085 of 17611`), 27 were frame-cut debris and **9 are real recipe
/// text**. The band's refusal was argued from the photographs (below) before it
/// could be priced; it is now priced, and the two agree.
/// Read the biased table as an upper bound and this one as the cost.
///
/// **That 9 is sensitive to ONE borderline label, which is why the label is
/// written down rather than assumed.** `Inlagd sill` and `Mixade vitaminer` are
/// the same case at 159 and 166 characters, and both are `fragment`. The label
/// that moves the row is `Inlagd sill`, which is the one BUT-1847 decided:
/// with it a `tail` the row reads 23 tokens instead of 9, and that state WAS
/// measured. `Mixade vitaminer` has been a `fragment` since BUT-1818 and flipping
/// BOTH was never measured — it would cost more than 23, since a `tail` there
/// re-enters the denominator on a page the 200 budget also cuts. Non-zero and a
/// lost block count in every state measured, so the verdict does not turn on the
/// call — the number does. The criterion that decides the pair is in
/// `docs/testing/cookbook-corpus-gold-grading.md`; do not re-decide it from how
/// the transcription happens to read.
///
/// **The RECALL column is biased AGAINST this rule, by 13 known cases
/// corpus-wide — BUT-1818, re-graded BUT-1847.** The gold records frame-cut half
/// recipes as complete ones. 23 of the 242 verified entries are graded that way
/// against their photographs, of which **13 bias recall** (`frameCut: fragment`,
/// debris of the KIND this trim removes — though only ONE of the 13 sits on a
/// page the trim actually cuts; the other twelve bias the recall LEVEL and the
/// block counts, not the trim's before/after delta); the other 10 are `tail` and
/// bias nothing.
/// The BUT-1818 figures were 11 and 3, from a hand grading of what a TEXT screen
/// surfaced; BUT-1847 opened all 181 pages as images, confirmed all 14 unchanged
/// and added nine — two `fragment` and seven `tail`. A DIFFERENT instrument — a
/// terminal-punctuation screen, not the word-shape one that surfaced BUT-1818's
/// candidates — recovers 9 of the 23 over the finished set (13 if it also looks
/// for an explicit `...`, because four more carry that marker; the remaining ten
/// are invisible to either, being clean prose that simply stops). Do NOT read
/// that as the word-shape screen's own score: it carries 89 false positives and
/// its own finds are all inside the 23, so re-running IT would recover far more
/// than 9 and prove nothing. Treat any count taken from text as a floor, and
/// grade from the photographs.
/// **The procedure, the fragment-vs-tail rubric and the traps are in
/// `docs/testing/cookbook-corpus-gold-grading.md`; read it before re-grading.**
/// An unfound fragment only makes the trim look worse.
/// Recall therefore scores retained debris as a hit, and the trim is penalised
/// for removing precisely what it exists to remove.
///
/// That general figure reaches THIS delta directly, which is why the caveat is
/// not hand-waving: `PXL_20260803_204356897_MACRO_FOCUS` is one of the ten pages
/// trimmed here, and the same page carries a verified gold entry titled
/// `Mandelforell` with zero ingredients and one truncated instruction — the very
/// debris this rule removes, scored as gold. And the whole delta is THREE gold
/// tokens corpus-wide (16121 -> 16118 of 17611) — `mandelforell`, `räkna`,
/// `rensad` — every one of them carried by that same tail.
///
/// **BUT-1818 MEASURED it and the cost is zero; BUT-1847's re-grade moved the
/// figures and left that verdict standing.** 23 gold entries are graded against
/// their photographs and marked `frameCut`: 13 `fragment` (the whole entry is a
/// sliver of the next recipe) and 10 `tail` (a real recipe whose ending the
/// capture took). `--no-frame-cut` drops the 13 — and ONLY the 13, because a
/// `tail` gold is SHORT of tokens rather than long, so dropping it would remove
/// no bias and would remove a whole page. Same 181 pages, same 10 trimmed pages,
/// so the two columns are one population:
///
/// |            | biased gold | `--no-frame-cut` |
/// |------------|-------------|------------------|
/// | recall     | 91.54 -> 91.52 % | **91.64 -> 91.64 %** |
/// | precision  | 66.64 -> 66.77 % | 65.83 -> 65.97 % |
/// | right block counts | 139 of 181 | **145 of 181** |
///
/// And it is exactly zero, not a rounded 0.00: the report carries the raw
/// integers, **15925 -> 15925 of 17378** gold tokens, against the biased run's
/// 16121 -> 16118 of 17611. A percentage pair reading `X -> X` never proves
/// zero on its own; read the numerator. (BUT-1818's own column read
/// 15974 -> 15974 of 17441 with 144 of 181 blocks — two fragments fewer in the
/// dropped set. The de-biased column moves whenever the grading does, which is
/// why the run that produced it has to be named.) (A draft added "and per page, zero pages lose
/// a gold token and zero gain one" — true when measured, but NO shipped command
/// emits it, and this file's own rule is that a figure must stay re-derivable.
/// The integers above are emitted; that sentence was not, so it is gone.)
///
/// So the 0.02 points were the biased gold, in full. The block counts move
/// 139 -> 145 as **SEVEN pages gained and ONE lost**, not six clean gains — the
/// aggregate is a masked swap, and `--trim --no-frame-cut` now prints the
/// per-page movement so it stays re-derivable (the table lives in the trim
/// arm, so the flag alone does not emit it). The seven are pages where the splitter
/// emitted one block fewer than the biased gold demanded: it correctly declined
/// to make a recipe out of a sliver. The one lost,
/// `PXL_20260803_204205028`, is the opposite and the more useful case — the
/// splitter emitted 3 blocks on a page holding 1 real recipe — and NOT one per
/// sliver, which is what a block COUNT tempts you to assume. Read out of the
/// real splitter: block 1 is the recipe itself with the `Dillstuvad potatis`
/// sliver swallowed INSIDE it, block 2 is that recipe's own variant subsection
/// `Med mangold eller nässlor` opened as a second recipe, block 3 is the
/// `Hasselbackspotatis` sliver. So one sliver opens nothing and the false split
/// is INSIDE a real recipe — and the biased gold had been scoring all of it as
/// RIGHT. Removing the bias does not only stop punishing correct declines; it
/// stops rewarding a real false split.
///
/// A first draft of this sentence said "one block per sliver", inferred from
/// the count. **A count that matches gold never tells you WHICH blocks came
/// out** — print them, or run the splitter.
/// (TEN pages carry a dropped fragment, and only eight of them move: seven gained
/// plus the one lost. The other two are wrong under BOTH golds and move nothing —
/// `PXL_20260803_204143402`, the most-biased page in the corpus at gold 5 -> 2, and
/// `PXL_20260803_204345256` at gold 3 -> 2. Named because seven plus one leaves two
/// cases unaccounted for, and this file's whole discipline is that an aggregate
/// must not hide one. No page is ALL fragment, so none leaves the population —
/// check that invariant after any re-grade.)
/// The FIRST budget table at the top of this section (not the comparison just
/// above) keeps the biased figures because
/// they are what every other document quotes and they still reproduce with the
/// flag off; read them as the UPPER BOUND they are. The 200 row was the figure
/// most exposed and is no longer unre-measured — the de-biased table beside it
/// prices it at 9 real gold tokens. **An earlier draft of this
/// paragraph compared 181 pages against 178** — it dropped the `tail` entries
/// too, which took three whole pages out, one of them a trimmed one. Same
/// conclusion, but across two different populations, which is not a
/// measurement. The verdicts here rest on the PHOTOGRAPHS either way.
///
/// At 200 the rule starts eating READABLE CONTENT. That is not a guess: all 9
/// tails in the 120-200 band were re-read AGAINST THE PHOTOGRAPHS on 2026-08-09,
/// and every one carries coherent text under the heading — a whole small recipe
/// (`Chokladkräm`: title, two ingredients, a note, all of it on the page), an
/// intro paragraph (`Annas hurtbullar`), the start of the next recipe (`Inlagd
/// sill`, `Mixade vitaminer`), or a tip section with its own list (`I stället
/// för sås`). So the band above 120 is deliberately left alone, and this file
/// has two outcomes rather than the three an earlier draft designed.
///
/// **TWO of those nine are debris by the corpus's own grading, and the verdict
/// survives them (BUT-1847).** `Mixade vitaminer` (166 chars) and `Inlagd sill`
/// (159) both carry `frameCut: fragment`, so cutting either costs nothing. The
/// claim above that every tail in the band carries coherent text under the
/// heading is right about the ink on the page and wrong about what the GOLD is
/// worth, for those two — they are the same case at seven characters' distance,
/// and the label is argued in `docs/testing/cookbook-corpus-gold-grading.md`
/// rather than from how their transcriptions happen to read. The band was argued
/// on nine readings before any of it was priced; the de-biased 200 row now prices
/// it at 9 real gold tokens and one lost block count, the same answer reached by
/// measurement rather than by reading. Do not use the two debris cases to reopen
/// the band without re-running that row.
///
/// The budget is a PROXY, and the property it proxies is the one a future reader
/// needs: below 120 the corpus holds only frame-cut debris; above it, content.
/// An earlier version of this paragraph called the band "subheadings inside a
/// recipe" — read off the bare text, and wrong on both examples it named. The
/// verdict survived that correction; the reason did not, so do not re-derive the
/// budget from the old wording. See `docs/architecture/ACCEPTED_DEVIATIONS.md`.
///
/// PROXY figures throughout — the geometry is Windows' offline recognizer, not
/// ML Kit, as everywhere else on this path.
library;

import 'package:butlery/services/import/layout/heading_detector.dart';
import 'package:butlery/services/ocr/text_layout.dart';

/// Below this many characters after the last heading, the tail is furniture.
///
/// The ceiling is where the rule starts cutting real content — see the table in
/// the library doc. Do not raise it without re-reading the 120-200 tails AGAINST
/// THE PHOTOGRAPHS; the last person to read them as text got both examples
/// wrong. What is actually there is readable content, in one case a whole small
/// recipe.
///
/// 200 is also where a second property gives out — a MARGIN, not a proof, and
/// the difference is the point. `MultiRecipeSplitter._minLayoutBlockChars` is
/// 200, and the slice removed here is the same block that path would have opened
/// at the same heading, so a trimmed tail mostly could not have cleared its
/// floor. But the two are counted DIFFERENTLY: the splitter measures
/// `sublist(...).join('\n').trim()`, which includes the HEADING ROW (up to 60
/// characters, `HeadingDetector._maxTitleChars`) and one `'\n'` per row; this
/// budget counts neither, only `text.trim().length` of the rows AFTER the
/// heading. So "the trim cannot destroy a block the layout path would have kept"
/// holds only while `budget + 60 + tailRowCount <= 200` — at 120 that is up to
/// 20 tail rows, which covers every shape in the corpus but is not a theorem.
/// Raising the budget spends that margin silently, on top of the content cost
/// the table shows.
const int _tailBudget = 120;

/// The row on the LAST page from which an orphan trailing heading should be
/// cut, or null when there is nothing to cut.
///
/// **This is [withoutOrphanTail]'s decision, and nothing else.** It was split
/// out so `frame_trim.dart` can take BOTH page trims' decisions from the
/// UNTOUCHED document and only then cut. Chaining the two appliers instead
/// let this rule's cut move `PageLayout.bodyTypeHeight` — a median — under
/// the leading trim, evicting a real title from its heading list; that was
/// constructed and executed on 2026-08-12, and `leading_noise.dart`'s library
/// doc carries the case.
///
/// **The split is deliberately behaviour-preserving for THIS rule.** Every
/// gate below, and their order, is what the applier ran before; the applier
/// now calls this and does only the cutting. That is what lets the corpus
/// figures in the library doc above and in `ACCEPTED_DEVIATIONS.md` stand
/// without a re-run — this rule already decided on the untouched document,
/// because it ran first. Only the leading trim's input changed.
int? orphanTailCutRow(String input, DocumentLayout? layout) {
  if (layout == null || !layout.matchesLineCountOf(input)) return null;

  // Only the LAST page may be trimmed. Photograph three pages in a row and page
  // one's trailing heading is continued on page two — it is spliced, not
  // orphaned. Only the end of the document is a real end-of-window.
  //
  // Belt and braces: `pages.isEmpty` and `last == null` cannot fire once the
  // gate above passed — `matchesLineCountOf` implies `isComplete`, which is
  // false for an empty page list and for any null page. `lines.isEmpty` CAN
  // fire, but removing it changes nothing either: an empty page has no
  // `bodyTypeHeight`, so `headingLines` returns empty and the next guard
  // returns the same null one line later. So all three are REMOVABLE
  // WITHOUT EFFECT, though for two different reasons — the first two cannot
  // fire, the third fires and changes nothing. Same convention as
  // `MultiRecipeSplitter`, which labels its own guards rather than letting them
  // read as live states.
  final pages = layout.pages;
  if (pages.isEmpty) return null;
  final last = pages.last;
  if (last == null || last.lines.isEmpty) return null;

  final headings = HeadingDetector.headingLines(last);
  if (headings.isEmpty) return null;
  final pageRow = headings.last;
  // A heading on the page's first row would leave nothing behind, and would
  // also make the trimmed page contribute zero lines while still occupying one
  // text row — the one case that breaks the applier's row-count invariant.
  //
  // NOT redundant with the applier's own bound, and the two part company on
  // ANY multi-page document — an earlier version of this comment called the
  // line redundant on the strength of single-page fixtures alone, which was
  // false. With two pages the heading sits at the last page's row 0,
  // `textRow` resolves to `lineOffsets.last` (positive), that bound never
  // fires, and without this line the last page is emptied while the text
  // keeps its rows. The counts then disagree and the splitter declines
  // geometry for the whole import, silently. `orphan_tail_test.dart`'s
  // two-page fixture pins THIS one.
  if (pageRow == 0) return null;

  var tailChars = 0;
  for (var i = pageRow + 1; i < last.lines.length; i++) {
    tailChars += last.lines[i].text.trim().length;
  }
  if (tailChars >= _tailBudget) return null;

  return pageRow;
}

/// Where [orphanTailCutRow]'s cut lands in the FLATTENED text, or null.
///
/// `headingLines` indexes into the PAGE; [DocumentLayout.textLineIndex] wants
/// an index into the flattened document. Passing one as the other would, on a
/// two-page import, resolve to a row on page ONE — cutting the input
/// mid-page-one and taking all of page two with it. Silently, and invisibly to
/// a corpus of single-page captures. `heading_detector.dart` names this trap by
/// hand. Shared with `frame_trim.dart` so the conversion exists once.
int? orphanTailTextRow(DocumentLayout layout, int pageRow) {
  final pages = layout.pages;
  final offset = pages
      .take(pages.length - 1)
      .fold<int>(0, (sum, p) => sum + (p?.lines.length ?? 0));
  return layout.textLineIndex(offset + pageRow);
}

/// [input] and [layout] with an orphan trailing heading removed, or both
/// unchanged.
///
/// Returns the ORIGINAL objects when there is nothing to do, so a caller can
/// test `identical(result.text, input)` to tell whether anything happened.
/// Per FIELD — Dart guarantees nothing about `identical` on two records, so
/// comparing the records themselves may be false after a no-op.
///
/// Reads `HeadingDetector.headingLines` on the LAST PAGE only, while the
/// splitter one hop later reads `headingLinesForDocument`, which returns null if
/// ANY page lacks a measurable baseline. So on a multi-page import whose FIRST
/// page is unjudgeable this still trims and the splitter still declines — safe
/// (the row-count invariant holds and the text rules get the trimmed string),
/// but the two hops do not share a verdict, only the gate below.
///
/// The sharpest form of that: THIS RULE CAN UN-JUDGE THE PAGE IT JUST TRIMMED.
/// Cut enough measurable rows off the last page and it drops below
/// `PageLayout._minBodyLines`, `bodyTypeHeight` goes null,
/// `headingLinesForDocument` returns null for the whole document, and the
/// splitter falls back to the text rules. Safe — that is today's shipped
/// behaviour, and the pair still passes the row-count gate — but it is the one
/// interaction the paragraph above does not name, and a reader chasing "why did
/// geometry go dark on exactly the pages we trimmed" needs it stated.
///
/// ## Cuts rows off the text — never re-derives it from the geometry
///
/// The returned text is [input] with rows removed, not `layout.text`. Those two
/// differ in production: `OCRExtractionService` runs `HtmlSanitizer` over the
/// text and not over the page, so re-deriving would swap the sanitized parser
/// input for the unsanitized one across the WHOLE document — and of the body
/// text this rule touches, nothing is re-sanitized when the recipe is saved.
/// `sanitizeRecipeText (services/parsing/sanitizers/recipe_sanitizer.dart)` rewrites the title, the
/// description and `sourceUrl`, and no ingredient or instruction row.
///
/// For the same reason the gate — applied by [orphanTailCutRow], above — is
/// [DocumentLayout.matchesLineCountOf], a ROW COUNT, and never a byte
/// comparison: bytes differ on every page the
/// sanitizer touched, so a byte gate would disable this silently — and the
/// corpus could never show it, because the eval harness derives its input FROM
/// `DocumentLayout.text` and is therefore always byte-identical.
({String text, DocumentLayout? layout}) withoutOrphanTail(
  String input,
  DocumentLayout? layout,
) {
  final unchanged = (text: input, layout: layout);
  final pageRow = orphanTailCutRow(input, layout);
  if (pageRow == null) return unchanged;
  // Non-null once the decision returned a row — it is the decision's own first
  // gate. Read back rather than re-derived so the two cannot drift.
  final pages = layout!.pages;
  final last = pages.last!;

  final textRow = orphanTailTextRow(layout, pageRow);
  // Also unreachable — the index is in range once the gate above passed; the
  // null is the return type's, not a state. Same belt-and-braces as the bound.
  if (textRow == null) return unchanged;

  final rows = input.split('\n');
  // Belt and braces, both halves, like the page guards above. `textRow <= 0`
  // cannot fire because `pageRow >= 1` puts the cut at least one row into the
  // last page; `textRow > rows.length` cannot fire because the row-count gate
  // already made `rows.length` equal to the geometry's own total, so the index
  // is bounded by `totalRows - 1`. Measured 2026-08-09 over 252 generated
  // shapes (1-3 pages, 4-7 body lines, heading at every position, 0-2 tail
  // rows, empty middle page): no null, no out-of-bounds, no non-positive.
  //
  // Removing this line alone reddens NOTHING, and that is correct rather than a
  // coverage gap — the mutant is equivalent. A draft of this comment claimed
  // the second half was live and pinned by a test; both halves of that were
  // false, and it was written from another reviewer's assertion instead of a
  // measurement. Do not restore it.
  if (textRow <= 0 || textRow > rows.length) return unchanged;

  // Both sides lose the same count — the page drops `lines.length - pageRow`
  // rows and the text drops `rows.length - textRow`, which are equal because
  // the last page's slice ends at the end of both. So `matchesLineCountOf`
  // still passes for the pair returned here, and the splitter still accepts it.
  final trimmedPage = PageLayout(
    lines: last.lines.sublist(0, pageRow),
    imageWidth: last.imageWidth,
    imageHeight: last.imageHeight,
  );
  final trimmedPages = [...pages.sublist(0, pages.length - 1), trimmedPage];

  return (
    text: rows.sublist(0, textRow).join('\n'),
    layout: DocumentLayout(trimmedPages),
  );
}
