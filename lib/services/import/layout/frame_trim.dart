/// Cuts the camera frame's debris off BOTH ends of a photographed import, with
/// both decisions taken from the UNTOUCHED document.
///
/// The two rules are unchanged; what changes is WHEN each looks at the page.
/// This calls their DECISIONS — `orphanTailCutRow` and `leadingNoiseCutRow` —
/// not the appliers `withoutOrphanTail`/`withoutLeadingNoise`, which it
/// replaces rather than delegates to. It exists because chaining those two
/// appliers was measurably wrong, and the wrongness was invisible.
///
/// ## The defect this replaces
///
/// A single-photo import makes page zero and the last page the SAME
/// [PageLayout], so the first applier's cut was an input to the second one.
/// `PageLayout.bodyTypeHeight` is a MEDIAN over the lines carrying four or
/// more measured words, and `HeadingDetector` scales its absolute bar from it,
/// so removing lines can move the bar. Constructed and executed 2026-08-12
/// (`frame_trim_test.dart`): a folio, a real title, four TALL content rows,
/// two further titles, and four SHORT rows below the last of them. The tail
/// cut removed those short rows — the ones dragging the median down — so the
/// median rose, the bar rose past the REAL title, that title dropped out of
/// the heading list, `headings.first` moved to a later title, and the leading
/// trim then measured the real recipe as furniture and ate it. The row-count
/// invariant still passed, so nothing reported it.
///
/// Taking both decisions here, before either cut, removes that coupling — not
/// by making it less likely, which is what swapping the order would have done.
///
/// ## Why this costs no corpus re-measurement
///
/// [orphanTailCutRow] sees exactly what `withoutOrphanTail` saw before: the
/// untouched document, because it ran first. Its decision is therefore
/// unchanged, and the figures in `orphan_tail.dart`'s tables and in
/// `ACCEPTED_DEVIATIONS.md` still describe production. Only the leading trim's
/// input moved, which was the bug. That asymmetry is the whole reason this
/// shape was chosen over swapping the two calls, which WOULD have changed the
/// tail trim's input and silently un-measured it (Malin's call, 2026-08-12).
///
/// The leading trim's own budget remains unmeasured — see `leading_noise.dart`
/// — and `dart run tools/corpus_split_eval.dart --leading-trim` is still owed
/// before `enable_layout_recipe_split` is turned on.
library;

import 'package:butlery/services/import/layout/leading_noise.dart';
import 'package:butlery/services/import/layout/orphan_tail.dart';
import 'package:butlery/services/ocr/text_layout.dart';

/// [input] and [layout] with both frame trims applied, or both unchanged.
///
/// Returns the ORIGINAL objects when neither rule fires, so a caller can test
/// `identical(result.text, input)` — the same contract both siblings keep.
({String text, DocumentLayout? layout}) withoutFrameNoise(
  String input,
  DocumentLayout? layout,
) {
  final unchanged = (text: input, layout: layout);
  if (layout == null || !layout.matchesLineCountOf(input)) return unchanged;

  // The fix, in two lines: both decisions read the SAME untouched document.
  // Neither can observe the other's cut, because neither cut has happened.
  final tailPageRow = orphanTailCutRow(input, layout);
  var headPageRow = leadingNoiseCutRow(input, layout);
  if (tailPageRow == null && headPageRow == null) return unchanged;

  final pages = layout.pages;
  final rows = input.split('\n');

  int? textTail;
  if (tailPageRow != null) {
    textTail = orphanTailTextRow(layout, tailPageRow);
    // Belt and braces, and deliberately the SAME bounds `withoutOrphanTail`
    // keeps: refusing everything here rather than just the tail keeps this
    // function's tail behaviour identical to that one's in every branch,
    // which is what the "no re-measurement" claim above rests on.
    if (textTail == null || textTail <= 0 || textTail > rows.length) {
      return unchanged;
    }
  }

  int? textHead;
  if (headPageRow != null) {
    // Page zero's lines start the flattened list, so no page offset applies —
    // the mirror of `orphanTailTextRow`'s fold, which has no equivalent at
    // this end of the document.
    final row = layout.textLineIndex(headPageRow);
    if (row == null || row <= 0 || row > rows.length) {
      headPageRow = null;
    } else {
      textHead = row;
    }
  }

  // Where the two cuts would cross — reachable only on a ONE-page import,
  // where the same page carries both — the LEADING cut is the one dropped.
  // Dropping the tail cut instead would change what `withoutOrphanTail`
  // does on that page and re-open the measurement question for the sake of
  // the newer, unmeasured rule. An ENGINEERING call, stated as judgment call
  // (2) of the plan Malin approved on 2026-08-12 — not a founder decision on
  // this line itself, which is the distinction the entry above draws.
  if (headPageRow != null && textTail != null && textHead! >= textTail) {
    headPageRow = null;
    textHead = null;
  }
  if (tailPageRow == null && headPageRow == null) return unchanged;

  // The LAST page is rebuilt first so that on a one-page document the leading
  // splice below reads the already-tail-trimmed lines rather than the
  // original ones — `head < tail` is guaranteed by the crossing guard above,
  // so the two slices compose into `lines[head..tail)`.
  final cutPages = <PageLayout?>[...pages];
  if (tailPageRow != null) {
    final last = pages.last!;
    cutPages[pages.length - 1] = PageLayout(
      lines: last.lines.sublist(0, tailPageRow),
      imageWidth: last.imageWidth,
      imageHeight: last.imageHeight,
    );
  }
  if (headPageRow != null) {
    final first = cutPages.first!;
    cutPages[0] = PageLayout(
      lines: first.lines.sublist(headPageRow),
      imageWidth: first.imageWidth,
      imageHeight: first.imageHeight,
    );
  }

  // Both sides lose the same count at each end, for the reasons each sibling
  // states for its own end: page zero drops `headPageRow` rows and the text
  // drops `textHead`, which are equal because page zero starts both; the last
  // page drops `lines.length - tailPageRow` and the text drops
  // `rows.length - textTail`, which are equal because the last page ends both.
  // So `matchesLineCountOf` still passes for the pair returned here — on one
  // page and on a spread, with either cut alone or both.
  return (
    text: rows.sublist(textHead ?? 0, textTail ?? rows.length).join('\n'),
    layout: DocumentLayout(cutPages),
  );
}
