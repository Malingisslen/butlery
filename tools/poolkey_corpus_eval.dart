// BUT-1520 C6/C7: runs the production pool key over the cookbook corpus.
//
// Run on the machine that holds the corpus (it never leaves it):
//   BUTLERY_CORPUS_DIR=<corpus root> dart run tools/poolkey_corpus_eval.dart
// Add --detail to also print the titles behind each false-merge candidate, for
// local review only. Exit code 1 when any candidate is found.
import 'dart:io';

import 'package:butlery/services/rating/canonical_pool_key.dart';

import 'corpus/corpus_paths.dart';
import 'corpus/poolkey_corpus_core.dart';

void main(List<String> args) {
  final paths = CorpusPaths.resolve();
  if (!paths.exists) {
    stderr.writeln(
      'Corpus not found at ${paths.root}. Set BUTLERY_CORPUS_DIR.',
    );
    exitCode = 2;
    return;
  }
  final result = measure(
    loadPages(paths.rootDir),
    CanonicalPoolKey.compute,
  );
  stdout.writeln(formatSummary(result));
  if (args.contains('--detail')) stdout.writeln(formatDetail(result));
  if (result.goldCollisions.isNotEmpty || result.draftCollisions.isNotEmpty) {
    exitCode = 1;
  }
}
