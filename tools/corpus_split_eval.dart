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
library;

import 'dart:convert';
import 'dart:io';

import 'package:butlery/services/import/multi_recipe_splitter.dart';

import 'corpus/corpus_paths.dart';

void main(List<String> args) {
  final paths = CorpusPaths.resolve();
  stdout.writeln('Corpus root: ${paths.root}');
  if (!paths.exists) {
    stderr.writeln('Corpus directory not found.');
    exit(1);
  }

  final pages = _loadPages(paths);
  if (pages.isEmpty) {
    stderr.writeln('No pages with verified gold found.');
    exit(1);
  }

  final splitter = MultiRecipeSplitter();
  final scored = pages
      .map((p) => _score(p, splitter.split(p.ocrText).length))
      .toList();

  stdout.writeln(_format(scored));

  final ts = DateTime.now().toIso8601String().replaceAll(':', '-');
  final file = File('${paths.reportsDir()}/split-eval-$ts.json');
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(
    const JsonEncoder.withIndent('  ').convert({
      'generatedAt': ts,
      'pages': scored.map((s) => s.toJson()).toList(),
      'summary': _summary(scored),
    }),
  );
  stdout.writeln('Report written: ${file.path}');
}

/// One photographed page: how many recipes gold says it holds, and its text.
class _Page {
  final String bookSlug;
  final String imageId;
  final int goldRecipes;
  final String ocrText;

  const _Page({
    required this.bookSlug,
    required this.imageId,
    required this.goldRecipes,
    required this.ocrText,
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
List<_Page> _loadPages(CorpusPaths paths) {
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
