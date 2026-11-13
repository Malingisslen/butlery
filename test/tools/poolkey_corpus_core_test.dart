import 'dart:convert';
import 'dart:io';

import 'package:butlery/services/rating/canonical_pool_key.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../tools/corpus/poolkey_corpus_core.dart';

Map<String, dynamic> _recipe(
  String title,
  List<String> lines, {
  bool verified = false,
}) => {
  'verified': verified,
  'title': title,
  'ingredients': [
    for (final l in lines) {'originalLine': l},
  ],
};

/// Keys on the title alone, so a test decides collisions by choosing titles.
String? _titleKeyer({
  required String title,
  required List<String> ingredients,
}) => title.isEmpty ? null : 'k:${title.toLowerCase()}';

void main() {
  late Directory root;

  setUp(() => root = Directory.systemTemp.createTempSync('poolkey_corpus'));
  tearDown(() => root.deleteSync(recursive: true));

  void write(String rel, Object json) {
    final f = File('${root.path}/$rel')..createSync(recursive: true);
    f.writeAsStringSync(jsonEncode(json));
  }

  group('loadPages', () {
    test('uses gold.json only when every gold on the page is verified', () {
      write('book/p1/gold.json', _recipe('A', ['1 ägg'], verified: true));
      write('book/p1/gold.proposed.json', _recipe('B', ['1 ägg']));
      write('book/p2/gold.json', _recipe('C', ['1 ägg']));
      write('book/p2/gold.proposed.json', _recipe('D', ['1 ägg']));

      final pages = {for (final p in loadPages(root).pages) p.pageId: p};

      expect(pages['book/p1']!.goldSource, GoldSource.verified);
      expect(pages['book/p1']!.gold.single.title, 'A');
      expect(pages['book/p2']!.goldSource, GoldSource.proposed);
      expect(pages['book/p2']!.gold.single.title, 'D');
    });

    test('a page with only a draft is unlabeled, not measured', () {
      write('book/p1/draft.json', _recipe('A', ['1 ägg']));

      final load = loadPages(root);

      expect(load.pages, isEmpty);
      expect(load.unlabeled, 1);
    });

    test('nested recipe-NN blocks belong to their page', () {
      write('book/p1/recipe-01/draft.json', _recipe('A', ['1 ägg']));
      write('book/p1/recipe-02/draft.json', _recipe('B', ['1 ägg']));
      write('book/p1/gold.proposed.json', {
        'recipes': [
          _recipe('A', ['1 ägg']),
          _recipe('B', ['1 ägg']),
        ],
      });

      final page = loadPages(root).pages.single;

      expect(page.pageId, 'book/p1');
      expect(page.drafts.map((r) => r.title), unorderedEquals(['A', 'B']));
      expect(page.gold.map((r) => r.title), ['A', 'B']);
    });

    test('a top-level list of recipes is read', () {
      write('book/p1/gold.proposed.json', [
        _recipe('A', ['1 ägg']),
        _recipe('B', ['2 dl mjölk']),
      ]);

      expect(loadPages(root).pages.single.gold.map((r) => r.title), [
        'A',
        'B',
      ]);
    });

    test('directories starting with _ or . are skipped', () {
      write('_reports/p1/gold.proposed.json', _recipe('A', ['1 ägg']));
      write('book/.tmp/gold.proposed.json', _recipe('B', ['1 ägg']));

      final load = loadPages(root);

      expect(load.pages, isEmpty);
      expect(load.unlabeled, 0);
    });

    test('ingredient lines fall back from originalLine to name', () {
      write('book/p1/gold.proposed.json', {
        'title': 'A',
        'ingredients': [
          {'name': 'salt'},
          {'originalLine': '1 tsk peppar', 'name': 'peppar'},
          '2 ägg',
        ],
      });

      expect(loadPages(root).pages.single.gold.single.lines, [
        'salt',
        '1 tsk peppar',
        '2 ägg',
      ]);
    });
  });

  group('measure', () {
    test('C7 sorts each keyed answer into same key, other key or no draft', () {
      write('b/p1/gold.proposed.json', _recipe('A', ['x']));
      write('b/p1/draft.json', _recipe('A', ['x']));
      write('b/p2/gold.proposed.json', _recipe('B', ['x']));
      write('b/p2/draft.json', _recipe('B misread', ['x']));
      write('b/p3/gold.proposed.json', _recipe('C', ['x']));
      write('b/p4/gold.proposed.json', _recipe('', ['x']));

      final r = measure(loadPages(root), _titleKeyer);

      expect(r.goldRecipes, 4);
      expect(r.goldKeyed, 3);
      expect(r.draftSameKey, 1);
      expect(r.draftOtherKey, 1);
      expect(r.noDraft, 1);
      expect(r.preliminary, isTrue);
    });

    test(
      'the same recipe photographed twice is a duplicate, not a collision',
      () {
        write(
          'b/p1/gold.proposed.json',
          _recipe('Potatispizza', ['2 potatis']),
        );
        write(
          'b/p2/gold.proposed.json',
          _recipe('Potatispizza', ['2 potatis']),
        );

        final r = measure(loadPages(root), _titleKeyer);

        expect(r.duplicateGroups, 1);
        expect(r.goldCollisions, isEmpty);
      },
    );

    test('different recipes sharing a key are a false-merge candidate', () {
      write('b/p1/gold.proposed.json', _recipe('Kaka', ['2 ägg']));
      write('b/p2/gold.proposed.json', _recipe('Kaka', ['3 dl mjöl']));

      final r = measure(loadPages(root), _titleKeyer);

      expect(r.goldCollisions, hasLength(1));
      expect(r.goldCollisions.single.members.map((m) => m.pageId), [
        'b/p1',
        'b/p2',
      ]);
      expect(formatSummary(r), contains('STOP'));
    });

    test(
      'a draft key shared across pages counts only when the answers differ',
      () {
        // p1/p2: same dish, drafts agree with their answers -> explained.
        write('b/p1/gold.proposed.json', _recipe('Pizza', ['1 deg']));
        write('b/p1/draft.json', _recipe('Pizza', ['1 deg']));
        write('b/p2/gold.proposed.json', _recipe('Pizza', ['1 deg']));
        write('b/p2/draft.json', _recipe('Pizza', ['1 deg']));
        // p3/p4: different dishes whose OCR drafts both misread as "Gryta".
        write('b/p3/gold.proposed.json', _recipe('Fiskgryta', ['torsk']));
        write('b/p3/draft.json', _recipe('Gryta', ['torsk']));
        write(
          'b/p4/gold.proposed.json',
          _recipe('Kycklinggryta', ['kyckling']),
        );
        write('b/p4/draft.json', _recipe('Gryta', ['kyckling']));

        final r = measure(loadPages(root), _titleKeyer);

        expect(r.draftCollisions, hasLength(1));
        expect(r.draftCollisions.single.key, 'k:gryta');
      },
    );

    test('a draft key shared by two photos of one recipe is no collision', () {
      write('b/p1/gold.proposed.json', _recipe('Pizza', ['1 deg']));
      write('b/p1/draft.json', _recipe('Sidonot', ['1 deg']));
      write('b/p2/gold.proposed.json', _recipe('Pizza', ['1 deg']));
      write('b/p2/draft.json', _recipe('Sidonot', ['1 deg']));

      final r = measure(loadPages(root), _titleKeyer);

      expect(r.duplicateGroups, 1);
      expect(r.draftCollisions, isEmpty);
    });

    test('the summary carries no title or page id', () {
      write('b/hemligsida/gold.proposed.json', _recipe('Hemlig', ['2 ägg']));
      write('b/annan/gold.proposed.json', _recipe('Hemlig', ['3 ägg']));

      final r = measure(loadPages(root), _titleKeyer);
      final summary = formatSummary(r);

      expect(summary, isNot(contains('Hemlig')));
      expect(summary, isNot(contains('hemligsida')));
      expect(formatDetail(r), contains('Hemlig'));
    });

    test('runs with the production key', () {
      write(
        'b/p1/gold.json',
        _recipe('Köttbullar', ['500 g köttfärs', '1 ägg'], verified: true),
      );
      write(
        'b/p1/draft.json',
        _recipe('Köttbullar', ['500 g köttfärs', '1 ägg']),
      );
      write(
        'b/p2/gold.json',
        _recipe('Sockerkaka', ['3 ägg', '3 dl socker'], verified: true),
      );
      write('b/p2/draft.json', _recipe('Sockerkaka', ['3 ägg', '3 dl socker']));

      final r = measure(loadPages(root), CanonicalPoolKey.compute);

      expect(r.preliminary, isFalse);
      expect(r.goldKeyed, 2);
      expect(r.draftSameKey, 2);
      expect(r.goldCollisions, isEmpty);
      expect(formatSummary(r), contains('verdict: PASS'));
    });
  });
}
