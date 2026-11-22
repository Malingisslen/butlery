import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/corpus/block_drafts.dart';
import '../../tools/corpus/corpus_models.dart';

GoldRecipe _full(String title, List<String> ingredients, List<String> steps) =>
    GoldRecipe(
      verified: true,
      title: title,
      ingredients: [
        for (final i in ingredients) GoldIngredient(name: i, originalLine: i),
      ],
      instructions: steps,
    );

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

  group('assignDraftsToGolds', () {
    final pasta = _full(
      'Pasta med tomat',
      ['400 g pasta', '2 dl tomatsås'],
      ['Koka pastan.', 'Värm tomatsåsen.'],
    );
    final soppa = _full(
      'Nässelsoppa',
      ['2 liter nässlor', '3 msk vetemjöl'],
      ['Skölj nässlorna.', 'Smält smöret och rör ner mjölet.'],
    );

    test('matches by content even when the parser lists them in reverse', () {
      final result = assignDraftsToGolds([pasta, soppa], [soppa, pasta]);
      expect(result[0]!.draftIndex, 1);
      expect(result[1]!.draftIndex, 0);
    });

    test('a gold nothing resembles is left out instead of paired', () {
      final result = assignDraftsToGolds([pasta, soppa], [pasta]);
      expect(result.keys, [0]);
    });

    test('one draft is never given to two golds', () {
      final result = assignDraftsToGolds([pasta, pasta], [pasta]);
      expect(result, hasLength(1));
    });

    test('a draft under the floor is not a match', () {
      final other = _full('Äppelkaka', ['3 äpplen'], ['Grädda kakan.']);
      expect(assignDraftsToGolds([pasta], [other]), isEmpty);
    });
  });
}
