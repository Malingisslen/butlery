@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/shadow_eval.dart';
import '../../tools/shadow_promote.dart';

/// The same recipe as the AI states it (`ExtractedRecipe`).
const _ai = {
  'title': 'Pannkakor',
  'portions': 4,
  'prepTimeMinutes': 10,
  'cookTimeMinutes': 20,
  'ingredients': [
    {
      'amount': 3,
      'unit': 'dl',
      'name': 'vetemjöl',
      'preparation': null,
      'section': null,
    },
    {
      'amount': null,
      'unit': null,
      'name': 'salt',
      'preparation': 'en nypa',
      'section': null,
    },
  ],
  'instructions': ['Vispa ihop.', 'Stek tunna pannkakor.'],
  'tags': ['frukost'],
};

/// ...and as the parser sends it (the corpus GoldRecipe shape).
const _parser = {
  'title': 'Pannkakor',
  'portions': '4',
  'timeMinutes': 30,
  'ingredients': [
    {
      'name': 'vetemjöl',
      'originalLine': '3 dl vetemjöl',
      'quantity': '3',
      'unit': 'dl',
    },
    {'name': 'salt', 'originalLine': 'salt', 'preparation': 'en nypa'},
  ],
  'instructions': ['Vispa ihop.', 'Stek tunna pannkakor.'],
};

Map<String, dynamic> _row(
  Object? ai,
  Map<String, dynamic>? parser, {
  String channel = 'text',
  String tier = 'rules',
}) => {
  'id': 'a1',
  'scrubbedInput': 'Pannkakor\n3 dl vetemjöl',
  'scrubbedOutput': ai is String ? ai : jsonEncode(ai),
  'parserOutput': parser,
  'channel': channel,
  'successfulTier': tier,
};

void main() {
  group('shadowGold: one adapter for both sides', () {
    test('golden: the AI shape reads as this GoldRecipe', () {
      expect(shadowGold(_ai).toJson(), {
        'verified': false,
        'title': 'Pannkakor',
        'portions': '4',
        'timeMinutes': 30,
        'ingredients': [
          {
            'name': 'vetemjöl',
            'originalLine': '3 dl vetemjöl',
            'quantity': '3',
            'unit': 'dl',
          },
          {'name': 'salt', 'originalLine': 'salt', 'preparation': 'en nypa'},
        ],
        'instructions': ['Vispa ihop.', 'Stek tunna pannkakor.'],
      });
    });

    test('the same recipe agrees fully with itself across the two shapes', () {
      final s = scoreSample(_row(_ai, _parser))!;

      expect(s.score.ingredientNames.f1, 1.0);
      expect(s.score.ingredientsFull.f1, 1.0);
      expect(s.channel, 'text');
      expect(s.tier, 'rules');
    });

    test('a parser that lost a line agrees less on names', () {
      final lost = Map<String, dynamic>.from(_parser)
        ..['ingredients'] = [(_parser['ingredients'] as List).first];

      expect(
        scoreSample(_row(_ai, lost))!.score.ingredientNames.f1,
        lessThan(1.0),
      );
    });

    test('a truncated AI answer is skipped, not scored', () {
      expect(scoreSample(_row('{"title": "Pannk', _parser)), isNull);
      expect(scoreSample(_row(_ai, null)), isNull);
    });
  });

  test(
    'the report names the figure as agreement and splits channel and tier',
    () {
      final report = formatShadowReport([
        _row(_ai, _parser),
        _row(_ai, _parser, channel: 'photo', tier: 'ocr'),
        _row('{broken', _parser),
      ]);

      expect(report, contains('Agreement with the AI (not accuracy)'));
      expect(report, contains('3 samples, 1 unreadable'));
      expect(report, contains('| photo / ocr | 1 | 100.0 % | 100.0 % |'));
      expect(report, contains('| text / rules | 1 | 100.0 % | 100.0 % |'));
    },
  );

  test('corrections are counted per tier and type', () {
    final report = formatCorrectionsReport([
      {
        'originalLine': 'a',
        'correctedLine': 'b',
        'type': 'ingredients',
        'successfulTier': 'rules',
      },
      {
        'originalLine': 'c',
        'correctedLine': 'd',
        'type': 'ingredients',
        'successfulTier': 'rules',
      },
    ]);

    expect(report, contains('| rules / ingredients | 2 |'));
  });

  group('shadow_promote', () {
    test(
      'a draft is in the import gate format, allergens left to a person',
      () {
        final draft = gateDraft(_ai, side: 'AI');

        expect(draft['title'], 'Pannkakor');
        expect(draft['steps'], 2);
        expect(draft['lastStepKey'], 'Stek tunna pannkakor.');
        expect(draft['portions'], 4);
        expect(draft['ingredients'], [
          {'key': 'vetemjöl'},
          {'key': 'salt'},
        ]);
        expect(draft['headings'], isEmpty);
        expect(draft['absent'], isEmpty);
      },
    );

    test('drafts may not be written inside the repository', () {
      expect(insideRepo('/repo', '/repo'), isTrue);
      expect(insideRepo('/repo/test/import_gate', '/repo'), isTrue);
      expect(insideRepo('/repo/../butlery-shadow-drafts', '/repo'), isFalse);
      expect(insideRepo('/repo-other', '/repo'), isFalse);
    });

    test('the repository is found from any directory inside it', () {
      final root = Directory.systemTemp.createTempSync('shadow_promote_');
      addTearDown(() => root.deleteSync(recursive: true));
      Directory('${root.path}/.git').createSync();
      final sub = Directory('${root.path}/tools/corpus')
        ..createSync(recursive: true);

      final found = repoRootFrom(sub.path);

      expect(insideRepo(root.path, found), isTrue);
      expect(insideRepo('${root.path}/test', found), isTrue);
    });
  });
}
