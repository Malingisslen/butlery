@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

import '../../tools/corpus/corpus_paths.dart';
import '../../tools/corpus/tag_eval_core.dart';

/// Builds a minimal corpus tree in a temp dir: one book, one flat recipe with
/// a `gold.json`, plus the given tag answer-key / prediction JSON.
CorpusPaths _corpusWith({
  required String tagsGoldJson,
  String? tagsDraftJson,
}) {
  final root = Directory.systemTemp.createTempSync('tag_eval_test');
  addTearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
  // gold.json is required: recipeEntries' flat-layout detection gates on it, so
  // without it the recipe is invisible to loadTagEntries.
  final recipeDir = Directory('${root.path}/book/recipe-01')
    ..createSync(recursive: true);
  File('${recipeDir.path}/gold.json').writeAsStringSync(
    '{"verified": true, "title": "x", '
    '"ingredients": [], "instructions": []}',
  );
  File('${recipeDir.path}/tags.gold.json').writeAsStringSync(tagsGoldJson);
  if (tagsDraftJson != null) {
    File('${recipeDir.path}/tags.draft.json').writeAsStringSync(tagsDraftJson);
  }
  return CorpusPaths(root.path);
}

void main() {
  test('scores a verified answer key against its prediction', () {
    final paths = _corpusWith(
      tagsGoldJson:
          '{"verified": true, "allergens": {"gluten": "contains", "nötter": "free"}}',
      tagsDraftJson:
          '{"allergens": {"gluten": "contains", "nötter": "free"}, "coverage": 1.0}',
    );

    final load = loadTagEntries(paths);
    expect(load.entries, hasLength(1));
    expect(load.skipped, isEmpty);

    final score = scoreTagEntry(load.entries.single).score;
    expect(score.allergens.total, 2);
    expect(score.allergens.correct, 2);
    expect(score.allergens.falseFree, 0);
  });

  test('catches a false-FREE: gold CONTAINS, prediction FREE', () {
    final paths = _corpusWith(
      tagsGoldJson: '{"verified": true, "allergens": {"nötter": "contains"}}',
      tagsDraftJson: '{"allergens": {"nötter": "free"}, "coverage": 1.0}',
    );

    final score = scoreTagEntry(loadTagEntries(paths).entries.single).score;
    expect(score.allergens.falseFree, 1);
    expect(score.allergens.missedContains, 1);
  });

  test('skips an unverified answer key and reports the reason', () {
    final paths = _corpusWith(
      tagsGoldJson: '{"verified": false, "allergens": {"gluten": "free"}}',
      tagsDraftJson: '{"allergens": {"gluten": "free"}, "coverage": 1.0}',
    );

    final load = loadTagEntries(paths);
    expect(load.entries, isEmpty);
    expect(load.skipped.single, contains('not verified yet'));
  });

  test('skips a verified key with no prediction (no silent pass)', () {
    final paths = _corpusWith(
      tagsGoldJson: '{"verified": true, "allergens": {"gluten": "free"}}',
    );

    final load = loadTagEntries(paths);
    expect(load.entries, isEmpty);
    expect(load.skipped.single, contains('prediction) missing'));
  });

  test('tagsGoldPath / tagsDraftPath normalize Windows backslashes', () {
    expect(
      tagsGoldPath('a/b/recipe-01/gold.json'),
      'a/b/recipe-01/tags.gold.json',
    );
    expect(
      tagsDraftPath(r'a\b\recipe-01\draft.json'),
      'a/b/recipe-01/tags.draft.json',
    );
  });
}
