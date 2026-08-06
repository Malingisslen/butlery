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
/// heading index from the capture does not address the stored text: 0 of 247
/// pages are byte-identical and only 34 share a row count. Feeding the two
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
library;

import 'dart:convert';
import 'dart:io';

import 'package:butlery/services/import/multi_recipe_splitter.dart';
import 'package:butlery/services/ocr/text_layout.dart';

import 'corpus/corpus_paths.dart';

void main(List<String> args) {
  final layoutMode = args.contains('--layout');
  final paths = CorpusPaths.resolve();
  stdout.writeln('Corpus root: ${paths.root}');
  if (!paths.exists) {
    stderr.writeln('Corpus directory not found.');
    exit(1);
  }

  final pages = _loadPages(paths, layoutMode: layoutMode);
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

  final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
  final suffix = layoutMode ? 'layout' : 'text';
  final file = File('${paths.reportsDir()}/split-eval-$suffix-$ts.json');
  file.parent.createSync(recursive: true);
  report['generatedAt'] = ts;
  report['arm'] = layoutMode ? 'winocr-text, paired' : 'ocr.txt, text rules';
  file.writeAsStringSync(const JsonEncoder.withIndent('  ').convert(report));
  stdout.writeln('Report written: ${file.path}');
}

/// One photographed page: how many recipes gold says it holds, and its text.
class _Page {
  final String bookSlug;
  final String imageId;
  final int goldRecipes;
  final String ocrText;

  /// The stored geometry, in `--layout` runs only. [ocrText] is then derived
  /// FROM it, so the pair is self-consistent by construction.
  final DocumentLayout? layout;

  const _Page({
    required this.bookSlug,
    required this.imageId,
    required this.goldRecipes,
    required this.ocrText,
    this.layout,
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
List<_Page> _loadPages(CorpusPaths paths, {required bool layoutMode}) {
  final pages = <String, _Page>{};
  for (final bookDir in paths.books()) {
    final bookSlug = _basename(bookDir.path);
    final byImage = <String, int>{};
    final ocrPathByImage = <String, String>{};
    for (final entry in paths.recipeEntries(bookSlug)) {
      if (!_isVerified(entry.goldPath)) continue;
      byImage[entry.imageId] = (byImage[entry.imageId] ?? 0) + 1;
      ocrPathByImage[entry.imageId] = entry.ocrTextPath;
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
          ocrText: derived,
          layout: doc,
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
        ocrText: text,
      );
    });
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
/// exercised here — that gap is covered by a synthetic two-page unit test and
/// can never be covered by this corpus.
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
