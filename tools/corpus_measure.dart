/// One command for "how good is the recipe reader now": re-derive the parser's
/// drafts from the stored OCR text, score them against the verified facit, and
/// print the change since the previous run.
///
///   dart run tools/corpus_measure.dart
///
/// Run it from the app repo root after any change to the recipe reading. It
/// costs nothing: no OCR provider and no AI is called. The corpus stays outside
/// the repo (copyright), so this cannot run in CI; point `BUTLERY_CORPUS_DIR`
/// at it if it is not the sibling `butlery-corpus` folder.
library;

import 'dart:convert';
import 'dart:io';

import 'corpus/corpus_paths.dart';

Future<void> main() async {
  final paths = CorpusPaths.resolve();
  if (!paths.exists) {
    stderr.writeln('Corpus root not found: ${paths.root}');
    exit(2);
  }
  final before = _lastTrend(paths);

  stdout.writeln('1/2  Re-deriving drafts from stored OCR text ...');
  final rederive = await Process.start(
    'flutter',
    ['test', 'test/corpus/corpus_rederive_test.dart', '-t', 'corpus-tools'],
    environment: {
      ...Platform.environment,
      'RUN_CORPUS_REDERIVE': '1',
      'BUTLERY_CORPUS_DIR': paths.root,
    },
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  if (await rederive.exitCode != 0) {
    stderr.writeln('Re-derive failed; scores below would be stale. Stopping.');
    exit(1);
  }

  stdout.writeln('2/2  Scoring against the verified facit ...');
  final eval = await Process.start(
    Platform.resolvedExecutable,
    ['run', 'tools/corpus_eval.dart'],
    environment: {...Platform.environment, 'BUTLERY_CORPUS_DIR': paths.root},
    runInShell: true,
    mode: ProcessStartMode.inheritStdio,
  );
  final code = await eval.exitCode;

  final after = _lastTrend(paths);
  if (code == 0 && after != null) stdout.writeln(_delta(before, after));
  exit(code);
}

Map<String, dynamic>? _lastTrend(CorpusPaths paths) {
  final file = File('${paths.reportsDir()}/trend.jsonl');
  if (!file.existsSync()) return null;
  final lines = file
      .readAsLinesSync()
      .where((l) => l.trim().isNotEmpty)
      .toList();
  if (lines.isEmpty) return null;
  return jsonDecode(lines.last) as Map<String, dynamic>;
}

String _delta(Map<String, dynamic>? before, Map<String, dynamic> after) {
  String pct(Object? v) => v is num ? '${(v * 100).toStringAsFixed(1)}%' : '-';
  String change(String key) {
    final a = after[key], b = before?[key];
    if (a is! num || b is! num) return '';
    final d = (a - b) * 100;
    return ' (${d >= 0 ? '+' : ''}${d.toStringAsFixed(1)} points)';
  }

  final b = StringBuffer('\n=== Result ===\n');
  b.writeln(
    'Verified recipes scored: ${after['verified']}  '
    'missed by the parser: ${after['missed'] ?? '-'}',
  );
  for (final (label, key) in [
    ('Ingredient name', 'ingredientNameF1'),
    ('Full ingredient', 'ingredientFullF1'),
    ('Instructions   ', 'instructionF1'),
    ('Preparation/alt', 'ingredientDetailF1'),
  ]) {
    b.writeln('$label: ${pct(after[key])}${change(key)}');
  }
  if (before != null && before['nameKey'] != after['nameKey']) {
    b.writeln(
      'Note: the previous trend line compared ingredient names another way '
      '(nameKey ${before['nameKey'] ?? 'whole name'}), so the change above is '
      'a change of yardstick, not of the parser.',
    );
  }
  if (before != null && before['missed'] == null) {
    b.writeln(
      'Note: the previous trend line was scored before missed recipes counted '
      'as zero, so the change above is not a like-for-like parser change.',
    );
  }
  return b.toString();
}
