import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/corpus/block_drafts.dart';
import '../../tools/corpus/corpus_models.dart';

GoldRecipe _r(String t) => GoldRecipe(
  verified: false,
  title: t,
  ingredients: const [],
  instructions: const [],
);

void main() {
  late Directory page;
  setUp(() => page = Directory.systemTemp.createTempSync('blocks_'));
  tearDown(() => page.deleteSync(recursive: true));

  void block(String id, {required bool draft}) {
    final d = Directory('${page.path}/$id')..createSync();
    File('${d.path}/gold.json').writeAsStringSync('{}');
    if (draft) File('${d.path}/draft.json').writeAsStringSync('{}');
  }

  test('lists blocks that carry gold, in numeric order', () {
    block('recipe-02', draft: false);
    block('recipe-01', draft: false);
    block('recipe-10', draft: true);
    Directory('${page.path}/recipe-04').createSync();
    expect(goldBlocks(page), ['recipe-01', 'recipe-02', 'recipe-10']);
  });

  test('pairs by position only when the counts match', () {
    final paired = pairBlocksWithDrafts(
      ['recipe-01', 'recipe-02'],
      [
        _r('a'),
        _r('b'),
      ],
    );
    expect(paired['recipe-02']!.title, 'b');
    expect(
      pairBlocksWithDrafts(['recipe-01', 'recipe-02'], [_r('a')]),
      isEmpty,
    );
  });
}
