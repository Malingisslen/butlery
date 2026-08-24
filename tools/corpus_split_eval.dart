// claude:large-file-ok — waiver + rationale in the "Size" section below
/// CLI: does a photographed page yield as many recipes as it actually holds?
///
///   dart run tools/corpus_split_eval.dart
///   BUTLERY_CORPUS_DIR=/path/to/corpus dart run tools/corpus_split_eval.dart
///
/// `tools/corpus_eval.dart` scores how well each recipe was PARSED. This scores
/// the step before it: how many recipes the splitter found on the page at all.
/// A page holding five recipes that comes back as one blob scores fine on
/// nothing — the four missing recipes are simply absent from the parse eval,
/// which only ever sees what was emitted.
///
/// Reports the two populations separately and on purpose. A single-recipe page
/// wrongly cut in two is not the mirror image of a spread wrongly merged into
/// one: `batch_import_preview.dart` pre-ticks every recipe it is handed and
/// offers no way to rejoin them, so a false split saves two half-recipes
/// silently. Any change that raises the multi-recipe number by lowering the
/// single-recipe one is a regression, however good the average looks.
///
/// Runs the SAME `MultiRecipeSplitter` production uses, over the stored
/// `ocr.txt` — no OCR call, no network, free to run as often as you like.
///
/// ## `--layout`: scoring the geometry path
///
/// The default run scores the TEXT rules over `ocr.txt`. `--layout` scores the
/// geometry path, and it must use a different input string to do so honestly.
///
/// `ocr.txt` and `layout-winocr.json` come from DIFFERENT engines (the paid
/// tier's text, Windows' offline geometry — see `CorpusPaths.ocrLayout`), so a
/// heading index from the capture does not address the stored text: as of
/// 2026-08-08, 0 of 247 pages are byte-identical and only 34 share a row count
/// (the corpus is live, so date any count taken from it). Feeding the two
/// together would measure `matchesLineCountOf` refusing them, not the splitter.
///
/// So `--layout` derives the input from the capture itself — `DocumentLayout
/// .text`, the one producer — and scores BOTH arms over that same string:
///
///   text arm   : `split(input)`                 — today's rules, no geometry
///   layout arm : `split(input, layout: doc)`     — the shipped layout path
///
/// Paired on one input, so the difference between the arms is the geometry and
/// nothing else. The absolute numbers are NOT comparable to the default run's
/// (different OCR engine, worse Swedish); only the two arms are comparable to
/// each other. Both facts are printed with the result so a number cannot be
/// quoted out of its arm.
///
/// ## `--edge-crop`: scoring what the crop does to the TEXT
///
///   dart run tools/corpus_split_eval.dart --edge-crop
///
/// Block counts are nearly blind to `cropEdgeBleed` — dropping a four-character
/// sliver rarely changes how many blocks come out, it changes what is IN them —
/// so this arm scores gold-token recall and precision as well as the block
/// count, before and after cropping the same capture. It is where every figure
/// in `edge_crop.dart`'s doc comes from, so those stay re-derivable after the
/// throwaway probes are gone. (The BUT-1816 deviation entry draws on THREE arms,
/// not this one alone: its block counts come from `--layout`, its crop figures
/// from here, its trim figures from `--trim`.)
///
/// ## `--trim`: scoring the orphan-tail cut
///
///   dart run tools/corpus_split_eval.dart --trim
///
/// Implies `--edge-crop`, because the BEFORE column has to be what production
/// stores WHEN GEOMETRY IS ATTACHED, i.e. with `enable_layout_recipe_split`
/// on. With the flag off — the code default — production ships uncropped
/// `providerText` and NEITHER column describes that run. Scores
/// `withoutOrphanTail` — dropping a heading the frame cut off from its own
/// recipe — before and after, over the same capture.
///
/// It can only compare two columns because that function lives OUTSIDE
/// `MultiRecipeSplitter.split`, in `ImportManager`. Move it inside and both
/// columns trim, the difference vanishes, and the gate passes while measuring
/// nothing. Two drafts had that shape.
///
/// ## `--leading-trim`: scoring the leading-noise cut
///
///   dart run tools/corpus_split_eval.dart --leading-trim
///
/// The mirror of `--trim` at the OTHER edge of the page: what dropping
/// furniture (a running header, a folio, the previous recipe's tail) off the
/// FRONT of the first page costs or buys.
///
/// **AFTER is `withoutFrameNoise`, not `withoutLeadingNoise`.** Since
/// `frame_trim.dart` the two page trims no longer run in sequence — both
/// decisions are taken from the untouched page and applied together — so
/// scoring the leading rule on the tail rule's OUTPUT would measure a
/// pipeline nobody runs. BEFORE stays `withoutOrphanTail` alone: that is
/// production minus this rule, so the delta is this rule and nothing else.
/// Both columns sit on top of the shipped edge crop, which the arm applies
/// itself.
///
/// Its columns are therefore hard-coded and no flag can change them. What
/// implying `--trim` actually buys is LOADING: the chain `--leading-trim` ->
/// `--trim` -> `--edge-crop` -> `--layout` is what makes `_loadPages` attach
/// geometry, and without it every page hits `if (doc == null) continue` and
/// the arm scores zero pages. (An earlier draft borrowed `--trim`'s own
/// justification — "the BEFORE column has to be what the previous stage hands
/// this one" — which is true of `--trim` and not of this arm.)
///
/// **`leading_noise.dart`'s own budget is unmeasured — this arm exists so it
/// stops being unmeasured.** It was written without corpus access, using the
/// tail trim's OTHER measured row (60, not the shipped 120) as a
/// deliberately conservative placeholder. Run this arm, read the printed
/// per-page list of what was cut, sweep `_leadingBudget`, and update that
/// constant's doc — not this comment — with the result. Nothing here should
/// be trusted as a finding until that run has happened at least once.
///
/// ## `--no-frame-cut`: scoring against gold that is not frame-cut debris
///
///   dart run tools/corpus_split_eval.dart --trim --no-frame-cut
///
/// The only flag that changes the POPULATION rather than the algorithm, which
/// is why it is documented here and not just where it is parsed. BUT-1818
/// graded 14 verified gold entries against their PHOTOGRAPHS and marked them
/// `frameCut`; BUT-1847 re-graded every verified entry the same way and the set
/// grew. **No count of the CURRENT set is written here on purpose** (BUT-1818's
/// own 14 above stays: it is attributed to that ticket and superseded in the
/// same breath, so no re-grade can falsify it) — the run tallies the markings
/// as it loads the gold and prints what it found, so this file cannot go stale
/// against a corpus it does not contain. (Both counts that used to sit here had
/// already gone stale once.) This drops the `fragment` ones — an entry that is
/// not a recipe the page holds at all, just the sliver of the next one — and
/// keeps the `tail` ones, which are real recipes whose ending the capture took.
/// Off by default, so every figure quoted elsewhere keeps reproducing.
/// The rubric that decides which of the two an entry is, and the traps that make
/// a text-only grading undercount, are in
/// `docs/testing/cookbook-corpus-gold-grading.md`.
///
/// Prints how many entries it dropped and how many pages remain; add `--trim`
/// and that arm also prints the per-page gold-vs-gold movement for every page
/// that lost a fragment, and carries it in the report. That last table
/// exists because the aggregate lies: a net block-count gain is pages gained
/// MINUS pages lost, and the lost ones are the cases worth reading.
///
/// ## Size
///
/// This file is past the repo's 500-line guideline, and stays that way
/// deliberately. `ACCEPTED_LARGE_FILES.md` is scoped to `lib/`, so there is no
/// row to add — the waiver is recorded here instead.
///
/// **Revisited: a fourth arm landed (`_formatLeadingTrim`, BUT-1828) and this
/// paragraph is the promised revisit, not a rewrite that pretends it never
/// said "three".** The reasoning holds anyway: all four share the corpus
/// loader, the `_Page` model and the same `MultiRecipeSplitter` instance, and
/// the three token-scoring arms share the gold tokeniser too (the `--layout`
/// arm does not use it — it compares block COUNTS through `_score`, which is
/// why the inherited "three arms" wording could say "the gold tokeniser"
/// without qualification and this one cannot). `_formatLeadingTrim` in
/// particular
/// reads `_formatTrim`'s own AFTER column as ITS before column — splitting it
/// into a separate file would sever that dependency from the code that makes
/// it true, not just from the doc that states it. A reader would still need
/// every arm to know which population a number describes, which is the one
/// mistake this tool exists to prevent. Revisit again if a FIFTH arm lands.
///
/// No line count is quoted here on purpose, and the two that were are named so
/// the retraction is itself checkable. `~150` shipped in `d034c5ece`, when the
/// newest arm was `_formatEdgeCrop` at 177 doc-inclusive lines — wrong when
/// written, though it became accidentally right once `_formatTrim` landed at
/// 151. Its replacement, `237`, was a BOUNDARY MISCOUNT: it measured to the next
/// declaration instead of the closing brace and swept in `_goldTextOf`'s doc;
/// the honest span was 233 at that moment. (That one is a live measurement of a
/// function this same paragraph calls still growing, so treat it as the size of
/// the miscount, not as the current span.)
///
/// Note what those two failures were NOT: neither was decay. A per-function span
/// does not move when an unrelated part of this file changes. One was wrong on
/// arrival and one was measured against the wrong boundary — which is the better
/// argument for leaving the number out, in the file whose whole thesis is that a
/// figure must stay re-derivable. Measure it when you need it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:butlery/services/import/layout/frame_trim.dart';
import 'package:butlery/services/import/layout/orphan_tail.dart';
import 'package:butlery/services/import/multi_recipe_splitter.dart';
import 'package:butlery/services/ocr/edge_crop.dart';
import 'package:butlery/services/ocr/text_layout.dart';

import 'corpus/corpus_paths.dart';

void main(List<String> args) {
  // BUT-1818/BUT-1847: the gold records frame-cut SLIVERS as complete recipes
  // (`frameCut: fragment`, graded against the photographs 2026-08-09, re-graded
  // over every verified entry 2026-08-19). Scoring
  // them rewards KEEPING debris, which is the opposite of what the splitter and
  // the orphan-tail trim are for. Off by default so every figure already quoted
  // in the docs keeps reproducing; pass the flag to see the run without that
  // bias.
  //
  // **`frameCut: tail` is NOT dropped, and that is the whole design.** A `tail`
  // entry is a real recipe the page holds whose LAST LINE the frame took, so its
  // gold is SHORT of tokens, not long — dropping it removes no bias. It would
  // only remove a page: BUT-1818's three `tail` entries were all flat
  // single-recipe pages,
  // so an earlier draft that dropped them took the population 181 -> 178 and
  // took one TRIMMED page (`Köttsa/l`) with it, which made the two columns of
  // the comparison different populations. Worse on a multi-recipe page: a
  // dropped `tail` lowers the expected count while the recipe is still there,
  // marking a CORRECT split as spurious — the opposite bias, introduced by the
  // fix.
  final dropFrameCut = args.contains('--no-frame-cut');
  final leadingTrimMode = args.contains('--leading-trim');
  // Implies `--trim`'s LOADING — geometry has to be attached or the arm
  // scores nothing. NOT its BEFORE column: since `frame_trim.dart` this arm
  // compares `withoutOrphanTail` alone against `withoutFrameNoise`, and it
  // applies both itself. See the flag's section in the file header.
  final trimMode = args.contains('--trim') || leadingTrimMode;
  final edgeCropMode = args.contains('--edge-crop') || trimMode;
  // The crop only exists on the geometry path, so its arm implies `--layout`'s
  // loading. Block counts alone cannot see it — it changes block CONTENT — which
  // is why this arm scores tokens instead.
  final layoutMode = args.contains('--layout') || edgeCropMode;
  final paths = CorpusPaths.resolve();
  stdout.writeln('Corpus root: ${paths.root}');
  if (!paths.exists) {
    stderr.writeln('Corpus directory not found.');
    exit(1);
  }

  final pages = _loadPages(
    paths,
    layoutMode: layoutMode,
    dropFrameCut: dropFrameCut,
  );
  if (pages.isEmpty) {
    stderr.writeln(
      layoutMode
          ? 'No pages with verified gold AND a stored layout capture found.'
          : 'No pages with verified gold found.',
    );
    exit(1);
  }

  final splitter = MultiRecipeSplitter();
  final scored = pages
      .map((p) => _score(p, splitter.split(p.ocrText).length))
      .toList();

  final report = <String, dynamic>{
    'pages': scored.map((s) => s.toJson()).toList(),
    'summary': _summary(scored),
  };

  if (!layoutMode) {
    stdout.writeln(_format(scored));
  } else {
    final withLayout = pages
        .map(
          (p) => _score(p, splitter.split(p.ocrText, layout: p.layout).length),
        )
        .toList();
    report['layoutArm'] = {
      'pages': withLayout.map((s) => s.toJson()).toList(),
      'summary': _summary(withLayout),
    };
    stdout.writeln(_formatPaired(scored, withLayout));
  }

  if (edgeCropMode) {
    final crop = _formatEdgeCrop(pages, splitter, dropFrameCut: dropFrameCut);
    report['edgeCropArm'] = crop.summary;
    stdout.writeln(crop.text);
  }

  if (trimMode) {
    final trim = _formatTrim(pages, splitter, dropFrameCut: dropFrameCut);
    report['trimArm'] = trim.summary;
    stdout.writeln(trim.text);
  }

  if (leadingTrimMode) {
    final leadingTrim = _formatLeadingTrim(
      pages,
      splitter,
      dropFrameCut: dropFrameCut,
    );
    report['leadingTrimArm'] = leadingTrim.summary;
    stdout.writeln(leadingTrim.text);
  }

  final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
  final fc = dropFrameCut ? '-nofc' : '';
  final suffix = leadingTrimMode
      ? 'leading-trim'
      : (trimMode
            ? 'trim'
            : (edgeCropMode ? 'edge-crop' : (layoutMode ? 'layout' : 'text')));
  final file = File('${paths.reportsDir()}/split-eval-$suffix$fc-$ts.json');
  file.parent.createSync(recursive: true);
  report['generatedAt'] = ts;
  report['arm'] = leadingTrimMode
      ? 'winocr-text, paired + edge-crop + orphan-tail trim + leading-noise trim'
      : (trimMode
            ? 'winocr-text, paired + edge-crop + orphan-tail trim'
            : (edgeCropMode
                  ? 'winocr-text, paired + edge-crop'
                  : (layoutMode
                        ? 'winocr-text, paired'
                        : 'ocr.txt, text rules')));
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln('Report written: ${file.path}');
}

/// The `--edge-crop` arm: what dropping edge bleed does to the TEXT.
///
/// Block counts are blind to this change — cropping a four-character sliver off
/// a page rarely moves how many blocks come out, it moves what is IN them. So
/// this arm scores gold-token recall and precision instead, and reports two
/// populations for the same reason the block report does: a page whose only
/// bleed row is a folio is not the case the feature is for, and averaging it
/// with the pages carrying a real partial column hides the one that matters.
///
/// This lives in the shipped tool rather than a scratch probe on purpose. The
/// numbers in `edge_crop.dart`'s doc and in the deviation log have to stay
/// re-derivable; a measurement deleted with the commit that motivated it is the
/// hole `ACCEPTED_DEVIATIONS.md` had to patch after the fact once already.
({String text, Map<String, dynamic> summary}) _formatEdgeCrop(
  List<_Page> pages,
  MultiRecipeSplitter splitter, {
  bool dropFrameCut = false,
}) {
  var scoredPages = 0, croppedPages = 0, droppedLines = 0;
  var goldTot = 0, hitBefore = 0, hitAfter = 0, emitBefore = 0, emitAfter = 0;
  var bandPages = 0, bandGold = 0, bandBefore = 0, bandAfter = 0;
  var bandEmitBefore = 0, bandEmitAfter = 0;
  var alignedBefore = 0, alignedAfter = 0;
  var shortOnlyInGold = 0, shortNumeralsOnly = 0;

  for (final page in pages) {
    final doc = page.layout;
    final gold = page.goldTokens;
    if (doc == null || gold.isEmpty) continue;
    final single = doc.pages.first;
    if (single == null) continue;

    final cropped = cropEdgeBleed(single);
    final dropped = single.lines.length - cropped.lines.length;
    final croppedDoc = DocumentLayout([cropped]);

    final beforeText = doc.text, afterText = croppedDoc.text;
    if (beforeText == null || afterText == null) continue;
    scoredPages++;

    // Everything below counts over the SAME population the printed recall and
    // precision do — hence after the `continue` above, not before it. The two
    // cannot diverge on today's corpus (every stored capture is one non-null
    // page), but a line reading "of the 496 rows on these 181 pages" should be
    // true by construction rather than by loop order.
    if (dropped > 0) {
      croppedPages++;
      droppedLines += dropped;

      // Size the blind spot the 3-character token floor creates, on the rows
      // this rule actually deleted. A dropped row counts when it carries NO
      // scored token at all and every short word it does carry appears in this
      // page's gold — plausible real content that `recall` is structurally
      // unable to miss. Printed rather than asserted: the first version of this
      // caveat quoted a figure from a deleted probe and understated it by a
      // third.
      final removed = <String>[...single.lines.map((l) => l.text)];
      for (final kept in cropped.lines) {
        removed.remove(kept.text);
      }
      for (final row in removed) {
        if (_tokens(row).isNotEmpty) continue;
        final shorts = _shortTokens(row);
        if (shorts.isEmpty) continue;
        if (!shorts.every(page.goldShortTokens.contains)) continue;
        shortOnlyInGold++;
        // Split by shape. A row of bare numerals is the quantity-column shape
        // this rule is most likely to delete wrongly — and also the shape most
        // likely counted by coincidence, since small digits sit in nearly every
        // page's gold.
        //
        // The letters half is NOT the clean counterpart, measured 2026-08-08:
        // 24 of its 25 rows are Swedish stopword fragments — e.g. `i`, `en`,
        // `de`, `är`, `på`, `då.` — in essentially every page's gold, i.e. the
        // same coincidence mechanism. Only one (`ca 2`) looked like a quantity
        // fragment. So the
        // split separates two coincidence-prone shapes rather than signal from
        // noise, and 62 is an upper bound on BOTH halves. Stated because the
        // sentence this replaced claimed the letters were the stronger signal.
        if (!row.toLowerCase().contains(_anyLetter)) shortNumeralsOnly++;
      }
    }

    final blocksBefore = splitter.split(beforeText, layout: doc);
    final blocksAfter = splitter.split(afterText, layout: croppedDoc);
    // The block-count pair the deviation entry and `edge_crop.dart` quote. It
    // has to come out of THIS arm: `--layout` replays an uncropped pipeline, so
    // it cannot see the crop at all, and a figure attributed to a command that
    // does not print it is how a record stops being re-derivable.
    if (blocksBefore.length == page.goldRecipes) alignedBefore++;
    if (blocksAfter.length == page.goldRecipes) alignedAfter++;
    final before = _tokens(blocksBefore.join('\n'));
    final after = _tokens(blocksAfter.join('\n'));

    goldTot += gold.length;
    hitBefore += before.intersection(gold).length;
    hitAfter += after.intersection(gold).length;
    emitBefore += before.length;
    emitAfter += after.length;

    // Four rows is a column, not a page number.
    if (dropped >= 4) {
      bandPages++;
      bandGold += gold.length;
      bandBefore += before.intersection(gold).length;
      bandAfter += after.intersection(gold).length;
      bandEmitBefore += before.length;
      bandEmitAfter += after.length;
    }
  }

  String pct(int a, int b) =>
      b == 0 ? '   -  ' : '${(100 * a / b).toStringAsFixed(2)} %';

  final b = StringBuffer()
    ..writeln('\nEdge crop vs gold tokens — $scoredPages pages')
    ..writeln()
    ..writeln('  Same PROXY caveat as --layout: the geometry is the stored')
    ..writeln('  winocr capture, not ML Kit. Both arms share one input, so the')
    ..writeln('  difference between them is the crop and nothing else.')
    ..write(
      dropFrameCut
          ? '  --no-frame-cut is ON: this arm is scored against the'
                ' corrected gold too, so these figures are NOT the ones'
                ' quoted elsewhere.\n'
          : '',
    )
    ..writeln()
    ..writeln('  cropped pages        : $croppedPages   ($droppedLines rows)')
    ..writeln(
      '  right block count    : $alignedBefore -> $alignedAfter '
      'of $scoredPages',
    )
    ..writeln()
    ..writeln('  ALL PAGES            before     after')
    ..writeln(
      '    recall             : ${pct(hitBefore, goldTot)}    '
      '${pct(hitAfter, goldTot)}',
    )
    ..writeln(
      '    precision          : ${pct(hitBefore, emitBefore)}    '
      '${pct(hitAfter, emitAfter)}',
    )
    ..writeln('    tokens emitted     : $emitBefore -> $emitAfter')
    ..writeln(
      '    BLIND SPOT: dropped rows made only of sub-3-char words that are '
      'in gold: $shortOnlyInGold',
    )
    ..writeln(
      '                of which bare numerals: $shortNumeralsOnly   '
      'carrying letters: ${shortOnlyInGold - shortNumeralsOnly}',
    )
    ..writeln()
    ..writeln('  REAL EDGE COLUMN (>=4 rows dropped): $bandPages pages')
    ..writeln(
      '    recall             : ${pct(bandBefore, bandGold)}    '
      '${pct(bandAfter, bandGold)}',
    )
    ..writeln(
      '    precision          : ${pct(bandBefore, bandEmitBefore)}    '
      '${pct(bandAfter, bandEmitAfter)}',
    );
  return (
    text: b.toString(),
    summary: {
      'scoredPages': scoredPages,
      'frameCutFragmentsDropped': dropFrameCut,
      'croppedPages': croppedPages,
      'droppedRows': droppedLines,
      'droppedRowsShortOnlyInGold': shortOnlyInGold,
      'alignedBefore': alignedBefore,
      'alignedAfter': alignedAfter,
      'goldTokens': goldTot,
      'recallBefore': hitBefore,
      'recallAfter': hitAfter,
      'emittedBefore': emitBefore,
      'emittedAfter': emitAfter,
      'bandPages': bandPages,
      'bandGoldTokens': bandGold,
      'bandRecallBefore': bandBefore,
      'bandRecallAfter': bandAfter,
      'bandEmittedBefore': bandEmitBefore,
      'bandEmittedAfter': bandEmitAfter,
    },
  );
}

/// The `--trim` arm: what dropping an orphan trailing heading does to the TEXT.
///
/// Measures on top of the shipped edge crop, because that is what production
/// stores whenever geometry is attached (flag on; see the file header for the
/// flag-off caveat) — so this arm implies `--edge-crop`, which implies
/// `--layout`.
///
/// It can only compare two columns because the tail rule lives OUTSIDE
/// `MultiRecipeSplitter.split` — in `ImportManager`, through
/// `withoutFrameNoise` since 2026-08-12; this arm still calls
/// `withoutOrphanTail` because that applier is the rule ALONE, which is what
/// a before/after pair needs. Move the rule inside `split` and
/// both columns trim, the difference vanishes, and the gate below would pass by
/// construction while measuring nothing. That is not hypothetical — it was the
/// shape of two drafts.
({String text, Map<String, dynamic> summary}) _formatTrim(
  List<_Page> pages,
  MultiRecipeSplitter splitter, {
  bool dropFrameCut = false,
}) {
  var scored = 0, trimmed = 0;
  var goldTot = 0, hitBefore = 0, hitAfter = 0, emitBefore = 0, emitAfter = 0;
  var alignedBefore = 0, alignedAfter = 0;
  // An aggregate "139 -> 139" cannot tell "nothing moved" from "one page fixed,
  // one broken" — and this file's own header says that average is exactly what
  // must never hide the trade. `_formatPaired` already prints fixed/broke; so
  // does this arm now.
  var fixed = 0, broke = 0;
  // WHICH pages, not just how many. `orphan_tail.dart` documents all ten tails
  // by name and character count, and until this list existed those names came
  // from a throwaway probe that was then deleted — the exact defect the header
  // of this file and `edge_crop.dart` both name in their own words ("a number
  // in a doc that no shipped command emits"). Now `--trim` emits them.
  final trimmedPages = <({String id, String head, int chars})>[];
  // Captured, never recomputed. The gold-vs-gold table below needs each page's
  // AFTER block count, and reconstructing the crop -> trim -> split chain a
  // second time is only correct while the two copies stay identical — a step
  // added here and not there would print a table describing a DIFFERENT
  // pipeline than the aggregate came from, silently.
  final blocksAfterByPage = <String, int>{};
  final movement = <Map<String, dynamic>>[];
  var movementGained = 0, movementLost = 0;

  for (final page in pages) {
    final doc = page.layout;
    final gold = page.goldTokens;
    if (doc == null || gold.isEmpty) continue;
    final single = doc.pages.first;
    if (single == null) continue;

    // Both columns start from what tier 0 actually stores: edge-cropped.
    final croppedDoc = DocumentLayout([cropEdgeBleed(single)]);
    final baseText = croppedDoc.text;
    if (baseText == null) continue;

    final cut = withoutOrphanTail(baseText, croppedDoc);
    if (!identical(cut.text, baseText)) {
      trimmed++;
      // The tail is a strict suffix, so its first non-blank row is the heading
      // that was cut and the rest is what the budget counted.
      final tailRows = baseText
          .substring(cut.text.length)
          .split('\n')
          .map((r) => r.trim())
          .where((r) => r.isNotEmpty)
          .toList();
      trimmedPages.add((
        id: '${page.bookSlug}/${page.imageId}',
        head: tailRows.isEmpty ? '(blank)' : tailRows.first,
        chars: tailRows.skip(1).fold<int>(0, (a, r) => a + r.length),
      ));
    }
    scored++;

    final before = splitter.split(baseText, layout: croppedDoc);
    final after = splitter.split(cut.text, layout: cut.layout);
    blocksAfterByPage['${page.bookSlug}/${page.imageId}'] = after.length;
    final rightBefore = before.length == page.goldRecipes;
    final rightAfter = after.length == page.goldRecipes;
    if (rightBefore) alignedBefore++;
    if (rightAfter) alignedAfter++;
    if (!rightBefore && rightAfter) fixed++;
    if (rightBefore && !rightAfter) broke++;

    final tB = _tokens(before.join('\n')), tA = _tokens(after.join('\n'));
    goldTot += gold.length;
    hitBefore += tB.intersection(gold).length;
    hitAfter += tA.intersection(gold).length;
    emitBefore += tB.length;
    emitAfter += tA.length;
  }

  String pct(int a, int b) =>
      b == 0 ? '   -  ' : '${(100 * a / b).toStringAsFixed(2)} %';

  final b = StringBuffer()
    ..writeln('\nOrphan-tail trim vs gold tokens — $scored pages')
    ..writeln()
    ..writeln(
      '  Measured ON TOP of the shipped edge crop, so the BEFORE column',
    )
    ..writeln('  is what tier 0 stores WHENEVER GEOMETRY IS ATTACHED, i.e.')
    ..writeln('  with enable_layout_recipe_split ON. With the flag off — the')
    ..writeln('  code default — production ships uncropped providerText with')
    ..writeln('  no geometry, and NEITHER column describes that run. Same')
    ..writeln('  PROXY caveat: the geometry is the winocr capture, not ML Kit.')
    ..writeln()
    ..writeln(
      dropFrameCut
          ? '  --no-frame-cut is ON: the `frameCut: fragment` gold entries'
                ' are excluded — ${_frameCutCensus.fragment} of the'
                ' ${_frameCutCensus.marked} entries graded frameCut by hand —'
                ' so the figures below carry no KNOWN frame-cut bias, and'
                ' ${_frameCutCensus.marked} is'
                ' a floor, not a count. Residual bias only makes the trim look WORSE.'
                ' `frameCut: tail` entries are still scored, on purpose.'
          : '  recall is biased AGAINST the trim — the gold records'
                ' frame-cut slivers as complete recipes, so retained debris'
                ' scores as a hit. ${_frameCutCensus.fragment} are marked'
                ' `frameCut: fragment` and ${_frameCutCensus.tail} `frameCut: tail`'
                ' (BUT-1818/BUT-1847); pass --no-frame-cut to drop the fragments.'
                ' The figures'
                ' below KEEP that bias and are an upper bound on the cost.',
    )
    ..writeln()
    ..writeln('  trimmed pages        : $trimmed')
    ..writeln(
      '  right block count    : $alignedBefore -> $alignedAfter '
      'of $scored   (fixed $fixed, broke $broke)',
    )
    ..writeln()
    ..writeln('                       before     after')
    ..writeln(
      '    recall             : ${pct(hitBefore, goldTot)}    '
      '${pct(hitAfter, goldTot)}',
    )
    ..writeln(
      '    precision          : ${pct(hitBefore, emitBefore)}    '
      '${pct(hitAfter, emitAfter)}',
    )
    ..writeln('    tokens emitted     : $emitBefore -> $emitAfter');

  // Gold-vs-gold movement, printed rather than left to a probe. The shipped
  // fixed/broke counters compare BEFORE and AFTER the trim within ONE gold;
  // this is the other axis — the same blocks scored against the biased count
  // and the unbiased one. Without it a net gain reads as that many clean gains
  // when it is more gained and some lost, and the lost ones are the informative
  // case — the biased gold was scoring a real false split as RIGHT.
  // `orphan_tail.dart` and the BUT-1818 entry in
  // `docs/architecture/ACCEPTED_DEVIATIONS.md` carry the block-by-block reading
  // of that page — two copies, agreeing in substance but not word for word, so
  // do not diff them for drift; read either. It is the one claim in this batch
  // that NO printed table can re-derive (the photograph gradings are hand work
  // too, but those are recorded per entry in the corpus). Do not add a third
  // copy here, and above all do not infer it from these counts. A count
  // matching gold never tells you WHICH blocks came out, which is the whole
  // reason this table exists.
  if (dropFrameCut) {
    final moved = <({String id, int biased, int now, int blocks})>[];
    for (final page in pages) {
      if (page.frameCutDropped == 0) continue;
      // Same admission test the scoring loop above applies, so the table and
      // the aggregate can never describe different page sets. `goldTokens`
      // matters: a page that lost its last gold entry sits outside
      // alignedBefore/alignedAfter and must sit outside this too.
      if (page.goldTokens.isEmpty) continue;
      final blocks = blocksAfterByPage['${page.bookSlug}/${page.imageId}'];
      if (blocks == null) continue;
      moved.add((
        id: '${page.bookSlug}/${page.imageId}',
        biased: page.goldRecipes + page.frameCutDropped,
        now: page.goldRecipes,
        blocks: blocks,
      ));
    }
    var gained = 0, lost = 0;
    for (final m in moved) {
      final wasRight = m.blocks == m.biased;
      final isRight = m.blocks == m.now;
      if (!wasRight && isRight) gained++;
      if (wasRight && !isRight) lost++;
    }
    b
      ..writeln()
      ..writeln(
        '  pages carrying a dropped fragment: ${moved.length}  '
        '(gained $gained, lost $lost)',
      );
    for (final m in moved) {
      final was = m.blocks == m.biased ? 'ok ' : '   ';
      final now = m.blocks == m.now ? 'ok ' : '   ';
      b.writeln(
        '    gold ${m.biased} -> ${m.now}   blocks ${m.blocks}   '
        '$was-> $now  ${m.id}',
      );
    }
    movement.addAll(
      moved.map(
        (m) => {
          'page': m.id,
          'goldBiased': m.biased,
          'goldUnbiased': m.now,
          'blocks': m.blocks,
        },
      ),
    );
    movementGained = gained;
    movementLost = lost;
  }

  if (trimmedPages.isNotEmpty) {
    b
      ..writeln()
      ..writeln('  every page trimmed, and what came off it:');
    for (final t in trimmedPages..sort((x, y) => x.chars.compareTo(y.chars))) {
      b.writeln(
        '    ${t.chars.toString().padLeft(3)} chars after  '
        '${t.head.length > 34 ? '${t.head.substring(0, 33)}…' : t.head}'
        '   ${t.id}',
      );
    }
  }

  return (
    text: b.toString(),
    summary: {
      'frameCutFragmentsDropped': dropFrameCut,
      'frameCutMovement': movement,
      'frameCutPagesGained': movementGained,
      'frameCutPagesLost': movementLost,
      'scoredPages': scored,
      'trimmedPages': trimmed,
      'trimmedDetail': [
        for (final t in trimmedPages)
          {'page': t.id, 'heading': t.head, 'charsAfter': t.chars},
      ],
      'alignedBefore': alignedBefore,
      'alignedAfter': alignedAfter,
      'pagesFixed': fixed,
      'pagesBroken': broke,
      'goldTokens': goldTot,
      'recallBefore': hitBefore,
      'recallAfter': hitAfter,
      'emittedBefore': emitBefore,
      'emittedAfter': emitAfter,
    },
  );
}

/// The `--leading-trim` arm: what dropping leading noise does to the TEXT.
///
/// BEFORE is `withoutOrphanTail` alone on top of the shipped edge crop —
/// production minus this rule. AFTER is `withoutFrameNoise`, which is
/// production. So the delta is the leading rule and nothing else.
///
/// It is NOT "the leading trim applied to the tail trim's output": since
/// `frame_trim.dart` the two no longer run in sequence, both decisions come
/// from the untouched page, and measuring the old chain would measure a
/// pipeline nobody runs. See `leading_noise.dart` for why this rule's budget
/// is a provisional placeholder rather than a measured one — running this arm
/// and reading its output is the step that placeholder is waiting on.
({String text, Map<String, dynamic> summary}) _formatLeadingTrim(
  List<_Page> pages,
  MultiRecipeSplitter splitter, {
  bool dropFrameCut = false,
}) {
  var scored = 0, trimmed = 0;
  var goldTot = 0, hitBefore = 0, hitAfter = 0, emitBefore = 0, emitAfter = 0;
  var alignedBefore = 0, alignedAfter = 0;
  var fixed = 0, broke = 0;
  // WHICH pages, mirroring `_formatTrim`'s own `trimmedPages` — a figure this
  // file quotes anywhere must stay re-derivable by a printed list, not a
  // throwaway probe.
  final trimmedPages = <({String id, String firstLine, int chars})>[];

  for (final page in pages) {
    final doc = page.layout;
    final gold = page.goldTokens;
    if (doc == null || gold.isEmpty) continue;
    final single = doc.pages.first;
    if (single == null) continue;

    // Both columns start edge-cropped, which is what tier 0 stores. They
    // then DIVERGE by this rule and nothing else: BEFORE applies the tail
    // rule alone, AFTER applies both from the untouched page. Neither is
    // "what this rule is fed in production" — since `frame_trim.dart` it is
    // never fed the tail trim's output at all.
    final croppedDoc = DocumentLayout([cropEdgeBleed(single)]);
    final baseText = croppedDoc.text;
    if (baseText == null) continue;
    final tailCut = withoutOrphanTail(baseText, croppedDoc);

    // BOTH decisions from the untouched page, exactly as production does
    // since `frame_trim.dart` — measuring the old chained order would
    // measure a pipeline nobody runs. `tailCut` stays the BEFORE column:
    // it is production minus this rule, so the delta is this rule alone.
    final cut = withoutFrameNoise(baseText, croppedDoc);
    // CONTENT, not identity. `_formatTrim` can use `identical` because it
    // compares one applier's output with that applier's own input, and the
    // rule returns the input object untouched when it declines. Here the two
    // columns come from DIFFERENT calls, so they are always distinct objects
    // on any tail-trimmed page and `identical` would count every one of them
    // as a leading trim — inflating the headline number this arm exists to
    // produce, with a `(blank)` 0-char row in the per-page list to match.
    if (cut.text != tailCut.text) {
      trimmed++;
      // The removed span is a strict PREFIX here, the mirror of `_formatTrim`
      // reading a strict suffix — so it is recovered from the ROW COUNT
      // difference rather than a substring length, which would be wrong the
      // moment the cut removes a row shorter than the newline it replaces.
      final beforeRows = tailCut.text.split('\n');
      final afterRows = cut.text.split('\n');
      final removed = beforeRows
          .take(beforeRows.length - afterRows.length)
          .map((r) => r.trim())
          .where((r) => r.isNotEmpty)
          .toList();
      trimmedPages.add((
        id: '${page.bookSlug}/${page.imageId}',
        firstLine: removed.isEmpty ? '(blank)' : removed.first,
        chars: removed.fold<int>(0, (a, r) => a + r.length),
      ));
    }
    scored++;

    final before = splitter.split(tailCut.text, layout: tailCut.layout);
    final after = splitter.split(cut.text, layout: cut.layout);
    final rightBefore = before.length == page.goldRecipes;
    final rightAfter = after.length == page.goldRecipes;
    if (rightBefore) alignedBefore++;
    if (rightAfter) alignedAfter++;
    if (!rightBefore && rightAfter) fixed++;
    if (rightBefore && !rightAfter) broke++;

    final tB = _tokens(before.join('\n')), tA = _tokens(after.join('\n'));
    goldTot += gold.length;
    hitBefore += tB.intersection(gold).length;
    hitAfter += tA.intersection(gold).length;
    emitBefore += tB.length;
    emitAfter += tA.length;
  }

  String pct(int a, int b) =>
      b == 0 ? '   -  ' : '${(100 * a / b).toStringAsFixed(2)} %';

  final b = StringBuffer()
    ..writeln('\nLeading-noise trim vs gold tokens — $scored pages')
    ..writeln()
    ..writeln(
      '  Both columns sit on the shipped edge crop. BEFORE is the orphan-tail',
    )
    ..writeln('  trim ALONE, i.e. production MINUS this rule; AFTER is')
    ..writeln('  production. So the delta is this rule and nothing else.')
    ..writeln('  BEFORE is NOT what this rule is fed in production: since')
    ..writeln('  frame_trim.dart both cuts are decided from the untouched')
    ..writeln('  page, so it is never handed the tail trim\'s output. Same')
    ..writeln('  PROXY caveat: the geometry is the winocr capture, not ML Kit.')
    ..writeln()
    ..writeln(
      '  UNMEASURED BUDGET: _leadingBudget (60) was set without corpus',
    )
    ..writeln(
      '  access, borrowed from the tail trim\'s OTHER measured row.',
    )
    ..writeln(
      '  Read the per-page list below against the photographs before',
    )
    ..writeln('  trusting this rule at scale.')
    ..writeln()
    ..writeln(
      dropFrameCut
          ? '  --no-frame-cut is ON: the `frameCut: fragment` gold entries'
                ' are excluded from this run\'s population.'
          : '  recall may be biased against this trim the same way it is'
                ' against the tail trim — pass --no-frame-cut to check.',
    )
    ..writeln()
    ..writeln('  trimmed pages        : $trimmed')
    ..writeln(
      '  right block count    : $alignedBefore -> $alignedAfter '
      'of $scored   (fixed $fixed, broke $broke)',
    )
    ..writeln()
    ..writeln('                       before     after')
    ..writeln(
      '    recall             : ${pct(hitBefore, goldTot)}    '
      '${pct(hitAfter, goldTot)}',
    )
    ..writeln(
      '    precision          : ${pct(hitBefore, emitBefore)}    '
      '${pct(hitAfter, emitAfter)}',
    )
    ..writeln('    tokens emitted     : $emitBefore -> $emitAfter');

  if (trimmedPages.isNotEmpty) {
    b
      ..writeln()
      ..writeln('  every page trimmed, and what came off its front:');
    for (final t in trimmedPages..sort((x, y) => x.chars.compareTo(y.chars))) {
      b.writeln(
        '    ${t.chars.toString().padLeft(3)} chars removed  '
        '${t.firstLine.length > 34 ? '${t.firstLine.substring(0, 33)}…' : t.firstLine}'
        '   ${t.id}',
      );
    }
  }

  return (
    text: b.toString(),
    summary: {
      'frameCutFragmentsDropped': dropFrameCut,
      'scoredPages': scored,
      'trimmedPages': trimmed,
      'trimmedDetail': [
        for (final t in trimmedPages)
          {'page': t.id, 'firstLine': t.firstLine, 'charsRemoved': t.chars},
      ],
      'alignedBefore': alignedBefore,
      'alignedAfter': alignedAfter,
      'pagesFixed': fixed,
      'pagesBroken': broke,
      'goldTokens': goldTot,
      'recallBefore': hitBefore,
      'recallAfter': hitAfter,
      'emittedBefore': emitBefore,
      'emittedAfter': emitAfter,
    },
  );
}

/// Every word of one verified gold recipe — title, ingredient lines as written,
/// and instructions. Returns empty for an unverified or unreadable record, so a
/// page with no usable gold simply drops out of the token arm.
String _goldTextOf(String goldPath) {
  final f = File(goldPath);
  if (!f.existsSync()) return '';
  try {
    final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    if (m['verified'] != true) return '';
    final parts = <String>[(m['title'] ?? '') as String];
    for (final i in (m['ingredients'] as List? ?? const [])) {
      parts.add(((i as Map)['originalLine'] ?? '') as String);
    }
    for (final i in (m['instructions'] as List? ?? const [])) {
      parts.add(i as String);
    }
    return parts.join(' ');
  } catch (_) {
    return '';
  }
}

/// Sentinel for a `frameCut` key that is present with a value that is not a
/// usable string — `""`, a number, a bool. Kept distinct from Dart `null` so
/// [_FrameCutCensus] can count it. An explicit JSON `frameCut: null` is NOT one
/// of these: it means "no marking", same as an absent key, and is treated so.
const String _frameCutMalformed = '<malformed>';

/// `fragment`, `tail`, ANY OTHER non-empty string verbatim (a hand-graded typo
/// such as `Tail` — the census buckets it as unrecognised), [_frameCutMalformed]
/// when the key is present but unusable, or null when there is no key, no file,
/// or nothing parseable. **Do not read the first two as the whole set**: writing
/// `else { /* absent */ }` at a call site is how a typo disappears into the
/// absent bucket. Two different mechanisms keep that from happening and it is
/// worth not confusing them — the sentinel covers a present-but-unusable VALUE,
/// while a typo is caught by the caller's FINAL branch, which tests `!= null`
/// rather than assuming a closed set. (Its earlier branches do match `fragment`
/// and `tail` by equality; it is the fall-through that has to stay open.)
/// Written by hand against
/// the PHOTOGRAPH, never inferred from the text — the whole point of BUT-1818 is
/// that a text-only reading is what recorded these as complete recipes in the
/// first place.
String? _frameCutOf(String goldPath) {
  final f = File(goldPath);
  if (!f.existsSync()) return null;
  try {
    final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final v = m['frameCut'];
    if (v == null) return null;
    // Present but unusable — `frameCut: ""`, `frameCut: true`. Returning null
    // here would make it indistinguishable from ABSENT, which is how the census
    // would under-report a malformed corpus while claiming to be computed.
    if (v is! String || v.isEmpty) return _frameCutMalformed;
    return v;
  } catch (_) {
    return null;
  }
}

final _anyLetter = RegExp(r'[a-zåäö]');
final _tokenPattern = RegExp(r'[a-z0-9åäö]{3,}');
final _shortTokenPattern = RegExp(
  r'(?<![a-z0-9åäö])[a-z0-9åäö]{1,2}(?![a-z0-9åäö])',
);

/// One- and two-character words, which [_tokens] deliberately excludes.
///
/// Bounded by explicit lookarounds rather than `\b`: Dart's `\b` is ASCII-only,
/// so `å`/`ä`/`ö` would create false word boundaries mid-token and `mjöl` would
/// yield a spurious `mj`.
Set<String> _shortTokens(String s) =>
    _shortTokenPattern.allMatches(s.toLowerCase()).map((m) => m[0]!).toSet();

/// Words of three characters or more, lowercased. Short tokens are dropped
/// because a two-letter fragment matches too much by accident to say anything
/// about whether real content survived.
///
/// **This floor is a known blind spot in the recall figure, not a neutral
/// choice.** `dl`, `g`, `st`, `ml` and `cl` never enter the gold set, and a
/// right-hand quantity column is exactly the shape a "narrow line outside the
/// body margins" rule deletes. So read `recall 91.56 -> 91.54` as an upper bound
/// on what survived, not a proof that nothing real was lost — and read the
/// BLIND SPOT line beside it, which counts the rows that pair cannot see.
/// Lowering the floor here would close the blind spot and move every other
/// figure at the same time, so it is a deliberate constant, not an oversight.
///
/// The character class is the other half of the same caveat: it covers å, ä and
/// ö but not é, ü or ç, so `Provençalska` tokenises as `proven` + `alska`. That
/// is symmetric across both arms, so the BEFORE/AFTER pair this file exists to
/// print is unaffected — only the absolute recall sits a little low.
Set<String> _tokens(String s) =>
    _tokenPattern.allMatches(s.toLowerCase()).map((m) => m[0]!).toSet();

/// One photographed page: how many recipes gold says it holds, and its text.
class _Page {
  final String bookSlug;
  final String imageId;
  final int goldRecipes;

  /// How many `frameCut: fragment` entries `--no-frame-cut` removed from THIS
  /// page. Zero on a default run. Carried so the arm can print the gold-vs-gold
  /// movement instead of leaving it to a probe — a net block-count gain is a
  /// MASKED SWAP (pages gained minus pages lost), and this file's whole
  /// thesis is that an average must never hide the trade.
  final int frameCutDropped;
  final String ocrText;

  /// The stored geometry, in `--layout` runs only. [ocrText] is then derived
  /// FROM it, so the pair is self-consistent by construction.
  final DocumentLayout? layout;

  /// Every word of this page's verified gold recipes, for the `--edge-crop`
  /// arm. Empty on the arms that score block counts, which need no text.
  final Set<String> goldTokens;

  /// The SHORT words of the same gold — one and two characters, which
  /// [goldTokens] deliberately excludes. Only used to size the blind spot that
  /// exclusion creates: `dl`, `g`, `st` are exactly what a quantity column is
  /// made of, and a rule that deletes narrow marginal lines could take one
  /// without moving the recall figure at all.
  final Set<String> goldShortTokens;

  const _Page({
    required this.bookSlug,
    required this.imageId,
    required this.goldRecipes,
    this.frameCutDropped = 0,
    required this.ocrText,
    this.layout,
    this.goldTokens = const {},
    this.goldShortTokens = const {},
  });
}

class _Scored {
  final _Page page;
  final int blocks;

  const _Scored(this.page, this.blocks);

  bool get isMulti => page.goldRecipes > 1;
  bool get aligned => blocks == page.goldRecipes;

  /// Recipes on the page that no block was opened for.
  int get missed => blocks < page.goldRecipes ? page.goldRecipes - blocks : 0;

  /// Blocks beyond what the page holds — the silent-data-loss direction.
  int get spurious => blocks > page.goldRecipes ? blocks - page.goldRecipes : 0;

  Map<String, dynamic> toJson() => {
    'book': page.bookSlug,
    'page': page.imageId,
    'goldRecipes': page.goldRecipes,
    'blocks': blocks,
    'missed': missed,
    'spurious': spurious,
  };
}

/// The run's OWN tally of how the corpus gold is graded, counted while loading
/// it and interpolated into the banners.
///
/// **Never type these counts into a string.** They live in the corpus, which is
/// re-graded from the photographs from time to time (BUT-1818, BUT-1847), and a
/// hard-coded copy makes this tool misreport its own input the moment that
/// happens — silently, since no test can reach a corpus that lives outside the
/// repo. Reading them costs a third read-and-parse of each gold file on an
/// offline CLI that already does two (`_isVerified`, `_goldTextOf`) — nothing is
/// held open. Populated by [_loadPages]; reset there so a second call cannot
/// double.
class _FrameCutCensus {
  int fragment = 0;
  int tail = 0;

  /// A `frameCut` value that is neither — a typo in hand-edited gold, or a key
  /// present with a non-string value. Counted so it cannot hide inside a floor
  /// these docs treat as authoritative BECAUSE it is computed.
  int unrecognised = 0;

  /// WHICH files, not just how many: a bare count leaves the next grader
  /// grepping a corpus of several hundred gold files by hand.
  final List<String> offenders = <String>[];

  int get marked => fragment + tail;

  void reset() {
    fragment = 0;
    tail = 0;
    unrecognised = 0;
    offenders.clear();
  }
}

final _frameCutCensus = _FrameCutCensus();

/// Groups `recipeEntries` back up to the PAGE level — the eval engine flattens
/// a spread into one entry per recipe, but a splitter is judged per page.
List<_Page> _loadPages(
  CorpusPaths paths, {
  required bool layoutMode,
  bool dropFrameCut = false,
}) {
  final pages = <String, _Page>{};
  // Printed below. A run whose POPULATION changed silently is the one mistake
  // this whole file exists to prevent — see the header.
  var dropped = 0;
  _frameCutCensus.reset();
  for (final bookDir in paths.books()) {
    final bookSlug = _basename(bookDir.path);
    final byImage = <String, int>{};
    final droppedByImage = <String, int>{};
    final ocrPathByImage = <String, String>{};
    final goldByImage = <String, Set<String>>{};
    final goldShortByImage = <String, Set<String>>{};
    for (final entry in paths.recipeEntries(bookSlug)) {
      if (!_isVerified(entry.goldPath)) continue;
      // Only `fragment`: an entry that is not a recipe this page holds at all,
      // just the sliver of the next one. Dropping it lowers the page's expected
      // COUNT and removes its tokens together, so a splitter that correctly
      // emits nothing for a sliver stops being marked wrong for it. `tail` is
      // deliberately kept — see the flag's own comment in `main`.
      //
      // A page whose EVERY verified entry is a fragment would leave the
      // population entirely, breaking the one-population property this scoping
      // exists to protect. No page is all-fragment today, and the PRINTED page
      // count is the guard rather than any number typed here: if it ever falls
      // below the default run's, that is why.
      // Read unconditionally, so the DEFAULT arm has a count of its own too —
      // the old `dropFrameCut && _frameCutOf(...)` short-circuited, which is why
      // its banner had to hard-code one.
      // Tallied per VERIFIED ENTRY (this sits below the `_isVerified` gate) and
      // before pages without a usable capture drop out below, so the census spans
      // the whole corpus's verified gold while the report around it is population-
      // scoped. A marking on an unscored page would make the banner and the table
      // describe different sets. **Print settles half of that and only half.** For
      // FRAGMENTS it does: the `--no-frame-cut` movement table's page count and
      // its per-page gold deltas both reconcile against the banner's fragment
      // count, so a fragment on an unscored page would show up as a mismatch.
      // TAILS never enter that table — they are never dropped — so nothing
      // printed reaches them; check those directly before quoting the banner
      // against the report. (No count written here on purpose, for the reason
      // the file header gives.)
      final frameCut = _frameCutOf(entry.goldPath);
      if (frameCut == 'fragment') {
        _frameCutCensus.fragment++;
      } else if (frameCut == 'tail') {
        _frameCutCensus.tail++;
      } else if (frameCut != null) {
        // Neither bucket AND not dropped — invisible in the one number these docs
        // call trustworthy because it is computed. The gold is hand-edited, so
        // `"Tail"`, `"fragmnet"` or a non-string are all live possibilities.
        _frameCutCensus.unrecognised++;
        _frameCutCensus.offenders.add(entry.goldPath);
      }
      if (dropFrameCut && frameCut == 'fragment') {
        dropped++;
        droppedByImage[entry.imageId] =
            (droppedByImage[entry.imageId] ?? 0) + 1;
        continue;
      }
      byImage[entry.imageId] = (byImage[entry.imageId] ?? 0) + 1;
      ocrPathByImage[entry.imageId] = entry.ocrTextPath;
      final gold = _goldTextOf(entry.goldPath);
      (goldByImage[entry.imageId] ??= <String>{}).addAll(_tokens(gold));
      (goldShortByImage[entry.imageId] ??= <String>{}).addAll(
        _shortTokens(gold),
      );
    }
    byImage.forEach((imageId, count) {
      if (layoutMode) {
        final doc = _loadLayout(paths.ocrLayout(bookSlug, imageId));
        // `text` is null unless the document is complete; a capture that
        // decoded to nothing is not a page this arm can score.
        final derived = doc?.text;
        if (derived == null || derived.trim().isEmpty) return;
        pages['$bookSlug/$imageId'] = _Page(
          bookSlug: bookSlug,
          imageId: imageId,
          goldRecipes: count,
          frameCutDropped: droppedByImage[imageId] ?? 0,
          ocrText: derived,
          layout: doc,
          goldTokens: goldByImage[imageId] ?? const {},
          goldShortTokens: goldShortByImage[imageId] ?? const {},
        );
        return;
      }
      final ocr = File(ocrPathByImage[imageId]!);
      if (!ocr.existsSync()) return;
      final text = ocr.readAsStringSync();
      if (text.trim().isEmpty) return;
      pages['$bookSlug/$imageId'] = _Page(
        bookSlug: bookSlug,
        imageId: imageId,
        goldRecipes: count,
        frameCutDropped: droppedByImage[imageId] ?? 0,
        ocrText: text,
      );
    });
  }
  if (dropFrameCut) {
    stdout.writeln(
      '  --no-frame-cut: dropped $dropped `frameCut: fragment` gold entries; '
      '${pages.length} pages scored.',
    );
  }
  if (_frameCutCensus.unrecognised > 0) {
    stdout.writeln(
      '  WARNING: ${_frameCutCensus.unrecognised} gold entries carry a '
      '`frameCut` value that is neither `fragment` nor `tail`. They fall in no '
      'bucket and are dropped by nothing — fix the gold; every frameCut figure '
      'in the docs is a floor until you do:',
    );
    for (final path in _frameCutCensus.offenders.take(10)) {
      stdout.writeln('    $path');
    }
    if (_frameCutCensus.offenders.length > 10) {
      stdout.writeln(
        '    ... and ${_frameCutCensus.offenders.length - 10} more',
      );
    }
  }
  return pages.values.toList()..sort(
    (a, b) =>
        '${a.bookSlug}/${a.imageId}'.compareTo('${b.bookSlug}/${b.imageId}'),
  );
}

_Scored _score(_Page page, int blocks) => _Scored(page, blocks);

bool _isVerified(String goldPath) {
  final f = File(goldPath);
  if (!f.existsSync()) return false;
  try {
    final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    return m['verified'] == true;
  } catch (_) {
    return false;
  }
}

/// One stored capture as a single-page document. Every corpus image is one
/// photographed page, so the multi-page arithmetic in `DocumentLayout` is NOT
/// exercised here, and never can be by this corpus.
///
/// The gap is covered by synthetic two-page unit tests — plural, and worth
/// counting rather than assuming: `orphan_tail_test.dart` pins the last-page
/// rule, the flat-index offset, and the first-row guard, each with its own
/// two-page fixture. A single one covered only the first two, and the third
/// looked redundant because of it.
DocumentLayout? _loadLayout(String path) {
  final f = File(path);
  if (!f.existsSync()) return null;
  try {
    final decoded = jsonDecode(f.readAsStringSync());
    if (decoded is! Map) return null;
    final page = PageLayout.fromJson(decoded.cast<String, dynamic>());
    if (page.lines.isEmpty) return null;
    return DocumentLayout([page]);
  } catch (_) {
    return null;
  }
}

Map<String, dynamic> _summary(List<_Scored> scored) {
  final single = scored.where((s) => !s.isMulti).toList();
  final multi = scored.where((s) => s.isMulti).toList();
  return {
    'singlePages': single.length,
    'singleAligned': single.where((s) => s.aligned).length,
    'multiPages': multi.length,
    'multiAligned': multi.where((s) => s.aligned).length,
    'recipesMissed': scored.fold<int>(0, (a, s) => a + s.missed),
    'spuriousBlocks': scored.fold<int>(0, (a, s) => a + s.spurious),
  };
}

String _format(List<_Scored> scored) {
  final s = _summary(scored);
  final b = StringBuffer()
    ..writeln('\nBlock count vs gold — ${scored.length} pages\n')
    ..writeln(
      '  single-recipe pages : '
      '${_pct(s['singleAligned'] as int, s['singlePages'] as int)}  '
      'still one block',
    )
    ..writeln(
      '  multi-recipe pages  : '
      '${_pct(s['multiAligned'] as int, s['multiPages'] as int)}  '
      'right number of blocks',
    )
    ..writeln('  recipes never emitted : ${s['recipesMissed']}')
    ..writeln('  spurious extra blocks : ${s['spuriousBlocks']}');

  final worst = scored.where((x) => x.isMulti && !x.aligned).toList()
    ..sort((x, y) => y.missed.compareTo(x.missed));
  if (worst.isNotEmpty) {
    b.writeln('\n  worst multi-recipe pages:');
    for (final w in worst.take(10)) {
      b.writeln(
        '    gold=${w.page.goldRecipes} blocks=${w.blocks}  '
        '${w.page.bookSlug}/${w.page.imageId}',
      );
    }
  }
  final falseSplits = scored.where((x) => !x.isMulti && !x.aligned).toList();
  if (falseSplits.isNotEmpty) {
    b.writeln(
      '\n  single-recipe pages wrongly split (the expensive direction):',
    );
    for (final f in falseSplits.take(10)) {
      b.writeln(
        '    blocks=${f.blocks}  ${f.page.bookSlug}/${f.page.imageId}',
      );
    }
  }
  return b.toString();
}

/// The two arms side by side over one input string, plus the only number that
/// says whether the geometry did anything at all: how many pages the two arms
/// disagreed on, split by direction.
String _formatPaired(List<_Scored> text, List<_Scored> layout) {
  final t = _summary(text);
  final l = _summary(layout);
  var helped = 0, hurt = 0, changed = 0;
  for (var i = 0; i < text.length; i++) {
    if (text[i].blocks == layout[i].blocks) continue;
    changed++;
    if (!text[i].aligned && layout[i].aligned) helped++;
    if (text[i].aligned && !layout[i].aligned) hurt++;
  }

  String row(String label, String key, String total) =>
      '  $label  text ${_pct(t[key] as int, t[total] as int)}   '
      'layout ${_pct(l[key] as int, l[total] as int)}';

  return (StringBuffer()
        ..writeln('\nBlock count vs gold — ${text.length} pages, PAIRED\n')
        ..writeln(
          '  Input for BOTH arms is the layout capture\'s own text, not '
          'ocr.txt.\n'
          '  A different OCR engine, so these absolutes are NOT the default '
          'run\'s.\n'
          '  Only the two columns below may be compared with each other.\n',
        )
        ..writeln(row('single-recipe pages :', 'singleAligned', 'singlePages'))
        ..writeln(row('multi-recipe pages  :', 'multiAligned', 'multiPages'))
        ..writeln(
          '  recipes never emitted :  text ${t['recipesMissed']}   '
          'layout ${l['recipesMissed']}',
        )
        ..writeln(
          '  spurious extra blocks :  text ${t['spuriousBlocks']}   '
          'layout ${l['spuriousBlocks']}',
        )
        ..writeln(
          '\n  pages the geometry changed : $changed   '
          '(fixed $helped, broke $hurt)',
        ))
      .toString();
}

String _pct(int hit, int total) {
  if (total == 0) return 'n/a';
  final p = (100 * hit / total).toStringAsFixed(0).padLeft(3);
  return '${hit.toString().padLeft(3)}/${total.toString().padLeft(3)} ($p%)';
}

String _basename(String p) {
  final c = p.replaceAll('\\', '/');
  final i = c.lastIndexOf('/');
  return i < 0 ? c : c.substring(i + 1);
}
