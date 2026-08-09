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
/// ## `--no-frame-cut`: scoring against gold that is not frame-cut debris
///
///   dart run tools/corpus_split_eval.dart --trim --no-frame-cut
///
/// The only flag that changes the POPULATION rather than the algorithm, which
/// is why it is documented here and not just where it is parsed. BUT-1818
/// graded 14 verified gold entries against their PHOTOGRAPHS and marked them
/// `frameCut`. This drops the 11 `fragment` ones — an entry that is not a
/// recipe the page holds at all, just the sliver of the next one — and keeps
/// the 3 `tail` ones, which are real recipes whose last line the frame took.
/// Off by default, so every figure quoted elsewhere keeps reproducing.
///
/// Prints how many entries it dropped and how many pages remain; add `--trim`
/// and that arm also prints the per-page gold-vs-gold movement for every page
/// that lost a fragment, and carries it in the report. That last table
/// exists because the aggregate lies: `139 -> 144` is six pages gained and one
/// lost, and the lost one is the case worth reading.
///
/// ## Size
///
/// This file is past the repo's 500-line guideline, and stays that way
/// deliberately. `ACCEPTED_LARGE_FILES.md` is scoped to `lib/`, so there is no
/// row to add — the waiver is recorded here instead.
///
/// The three arms are one measurement seen three ways: they share the corpus
/// loader, the `_Page` model, the gold tokeniser and the same
/// `MultiRecipeSplitter` instance, and each exists to be comparable with the
/// others. Splitting the newest arm into its own file would move `_formatTrim`
/// plus its doc — the largest of the three, and still growing — without
/// reducing what a reader has to hold — they would still need both
/// halves to know which population a number describes, which is the one mistake
/// this tool exists to prevent. Revisit if a FOURTH arm lands.
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

import 'package:butlery/services/import/layout/orphan_tail.dart';
import 'package:butlery/services/import/multi_recipe_splitter.dart';
import 'package:butlery/services/ocr/edge_crop.dart';
import 'package:butlery/services/ocr/text_layout.dart';

import 'corpus/corpus_paths.dart';

void main(List<String> args) {
  // BUT-1818: the gold records 11 frame-cut SLIVERS as complete recipes
  // (`frameCut: fragment`, graded against the photographs 2026-08-09). Scoring
  // them rewards KEEPING debris, which is the opposite of what the splitter and
  // the orphan-tail trim are for. Off by default so every figure already quoted
  // in the docs keeps reproducing; pass the flag to see the run without that
  // bias.
  //
  // **`frameCut: tail` is NOT dropped, and that is the whole design.** A `tail`
  // entry is a real recipe the page holds whose LAST LINE the frame took, so its
  // gold is SHORT of tokens, not long — dropping it removes no bias. It would
  // only remove a page: all three `tail` entries are flat single-recipe pages,
  // so an earlier draft that dropped them took the population 181 -> 178 and
  // took one TRIMMED page (`Köttsa/l`) with it, which made the two columns of
  // the comparison different populations. Worse on a multi-recipe page: a
  // dropped `tail` lowers the expected count while the recipe is still there,
  // marking a CORRECT split as spurious — the opposite bias, introduced by the
  // fix.
  final dropFrameCut = args.contains('--no-frame-cut');
  final trimMode = args.contains('--trim');
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

  final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
  final fc = dropFrameCut ? '-nofc' : '';
  final suffix = trimMode
      ? 'trim'
      : (edgeCropMode ? 'edge-crop' : (layoutMode ? 'layout' : 'text'));
  final file = File('${paths.reportsDir()}/split-eval-$suffix$fc-$ts.json');
  file.parent.createSync(recursive: true);
  report['generatedAt'] = ts;
  report['arm'] = trimMode
      ? 'winocr-text, paired + edge-crop + orphan-tail trim'
      : (edgeCropMode
            ? 'winocr-text, paired + edge-crop'
            : (layoutMode ? 'winocr-text, paired' : 'ocr.txt, text rules'));
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
/// It can only compare two columns because `withoutOrphanTail` lives OUTSIDE
/// `MultiRecipeSplitter.split`, in `ImportManager`. Move it inside `split` and
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
                ' are excluded, so the figures below carry no KNOWN frame-cut'
                ' bias — 14 were found by hand and that is a floor, not a'
                ' count. Residual bias only makes the trim look WORSE.'
                ' `frameCut: tail` entries are still scored, on purpose.'
          : '  recall is biased AGAINST the trim — the gold records'
                ' frame-cut slivers as complete recipes, so retained debris'
                ' scores as a hit. 11 are marked `frameCut: fragment`'
                ' (BUT-1818); pass --no-frame-cut to drop them. The figures'
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
  // and the unbiased one. Without it `139 -> 144` reads as five clean gains
  // when it is six gained and one lost, and the one lost is the informative
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

/// `fragment`, `tail`, or null. Written by hand against the PHOTOGRAPH, never
/// inferred from the text — the whole point of BUT-1818 is that a text-only
/// reading is what recorded these as complete recipes in the first place.
String? _frameCutOf(String goldPath) {
  final f = File(goldPath);
  if (!f.existsSync()) return null;
  try {
    final m = jsonDecode(f.readAsStringSync()) as Map<String, dynamic>;
    final v = m['frameCut'];
    return v is String && v.isNotEmpty ? v : null;
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
  /// movement instead of leaving it to a probe — an aggregate `139 -> 144` is a
  /// MASKED SWAP (measured: six pages gained, one lost), and this file's whole
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
      // exists to protect. None today — the 11 fragments sit on 8 pages and
      // each keeps a non-fragment entry — and the printed page count is the
      // guard: if it ever falls below the default run's, that is why.
      if (dropFrameCut && _frameCutOf(entry.goldPath) == 'fragment') {
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
