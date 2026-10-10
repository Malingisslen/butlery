// BUT-1625: the family form's "ogillar" chips decide where the weekly menu
// places a dish, so every chip needs a row in the vocabulary and each row
// must recognise real Swedish ingredient lines without catching its decoys.

import 'dart:io';

import 'package:butlery/models/menu/dislike_vocabulary.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../infrastructure/factories/recipe_factory.dart';

Recipe _recipeWith(List<String> ingredients) =>
    RecipeFactory.build(id: 'r', ingredients: ingredients);

bool _matches(String key, String line) =>
    DislikeVocabulary.recipeContainsAny(_recipeWith([line]), {key});

/// Chip keys read straight from the form's private `_dislikeOptions` map.
Set<String> _formChipKeys() {
  final source = File(
    'lib/views/family/family_member_form_view.dart',
  ).readAsStringSync();
  final start = source.indexOf('_dislikeOptions = {');
  expect(start, isNonNegative, reason: 'the chip map moved or was renamed');
  final end = source.indexOf('};', start);
  final body = source.substring(start, end);
  return {
    for (final m in RegExp(r"'([^']+)'\s*:").allMatches(body)) m.group(1)!,
  };
}

void main() {
  // Per chip: lines that must match, and decoys that must not. The decoys are
  // the real hazards named in the plan (vitlök vs lök, olivolja vs oliver,
  // paprikapulver vs paprika, ketchup vs tomat).
  const table = <String, ({List<String> yes, List<String> no})>{
    'lök': (
      yes: [
        '1 gul lök, hackad',
        '2 rödlökar',
        '1 purjolök',
        '2 st schalottenlökar',
        '1 knippe salladslök',
        '1 tsk lökpulver',
      ],
      no: ['3 vitlöksklyftor', '2 klyftor vitlök', '1 dl mjölk'],
    ),
    'vitlök': (
      yes: ['3 vitlöksklyftor', '2 klyftor vitlök', '1 vitlök'],
      no: ['1 gul lök, hackad', '1 purjolök', '1 dl grädde'],
    ),
    'svamp': (
      yes: [
        '250 g champinjoner',
        '200 g kantareller',
        '1 dl torkad svamp',
        '100 g shiitake',
      ],
      no: ['400 g kycklingfilé', '1 dl mjölk'],
    ),
    'oliver': (
      yes: ['10 gröna oliver', '100 g kalamataoliver', '1 burk oliver'],
      no: ['2 msk olivolja', '2 msk extra virgin olivolja'],
    ),
    'koriander': (
      yes: ['1 kruka färsk koriander', '1 tsk korianderfrön'],
      no: ['1 dl persilja', '1 tsk spiskummin'],
    ),
    'tomat': (
      yes: [
        '1 burk krossade tomater',
        '2 msk tomatpuré',
        '10 körsbärstomater',
        '4 tomater',
      ],
      no: ['2 msk ketchup', '1 dl grädde'],
    ),
    'paprika': (
      yes: ['1 röd paprika', '2 paprikor', '1 gul paprika, strimlad'],
      no: [
        '1 tsk paprikapulver',
        '1 tsk rökt paprika',
        '1 tsk paprika pulver',
        '1 tsk söt paprika',
        '1 dl mjölk',
      ],
    ),
    'aubergine': (
      yes: ['1 aubergine', '2 auberginer'],
      no: ['1 zucchini'],
    ),
    'rödbetor': (
      yes: ['500 g rödbetor', '1 burk inlagda rödbetor'],
      no: ['2 morötter', '1 röd lök'],
    ),
    'blåmögelost': (
      yes: ['100 g gorgonzola', '100 g ädelost', '75 g blåmögelost'],
      no: ['150 g cheddar', '1 dl grädde'],
    ),
    'lever': (
      yes: ['400 g kycklinglever', '300 g leverpastej', '400 g lever'],
      no: ['2 dl grädde', '1 dl mjölk'],
    ),
    'inlagd sill': (
      yes: ['2 msk inlagd sill', '300 g sillfilé'],
      // Silverlök starts with "sil" but is an onion, dill is a herb.
      no: ['1 knippe dill', '1 st silverlök'],
    ),
    'chili': (
      yes: [
        'chiliflakes',
        '1 tsk chilipulver',
        '1 röd chili',
        '1 msk sambal oelek',
        '1 msk sriracha',
      ],
      no: ['1 msk soja', '1 tsk svartpeppar'],
    ),
    'russin': (
      yes: ['1 dl russin'],
      no: ['1 dl solrosfrön', '1 dl nötter'],
    ),
  };

  group('every chip in the family form has a vocabulary row', () {
    test('the source scan finds the form chips', () {
      expect(_formChipKeys(), isNotEmpty);
    });

    test('no form chip is missing from DislikeVocabulary.keys', () {
      final missing = _formChipKeys().difference(
        DislikeVocabulary.keys.toSet(),
      );
      expect(missing, isEmpty, reason: 'chips without a vocabulary row');
    });

    test('this suite has a both-ways table row for every chip', () {
      expect(table.keys.toSet(), _formChipKeys());
    });
  });

  group('per chip, real ingredient lines match and decoys do not', () {
    for (final entry in table.entries) {
      test('${entry.key}: recognises its own ingredient lines', () {
        for (final line in entry.value.yes) {
          expect(_matches(entry.key, line), isTrue, reason: line);
        }
      });
      test('${entry.key}: leaves the look-alikes alone', () {
        for (final line in entry.value.no) {
          expect(_matches(entry.key, line), isFalse, reason: line);
        }
      });
    }
  });

  group('recipeContainsAny', () {
    test('an unknown key matches nothing', () {
      expect(_matches('ananas', '1 burk ananas'), isFalse);
      expect(_matches('ananas', '1 gul lök, hackad'), isFalse);
    });

    test('an empty dislike set matches nothing', () {
      expect(
        DislikeVocabulary.recipeContainsAny(
          _recipeWith(['1 gul lök, hackad', '250 g champinjoner']),
          const {},
        ),
        isFalse,
      );
    });

    test('an unknown key beside a known one does not hide the known one', () {
      expect(
        DislikeVocabulary.recipeContainsAny(
          _recipeWith(['250 g champinjoner']),
          {'ananas', 'svamp'},
        ),
        isTrue,
      );
    });

    test('any ingredient line of the recipe can carry the match', () {
      expect(
        DislikeVocabulary.recipeContainsAny(
          _recipeWith(['400 g pasta', '1 dl grädde', '2 rödlökar']),
          {'lök'},
        ),
        isTrue,
      );
    });

    test('matching ignores case', () {
      expect(_matches('lök', '1 GUL LÖK'), isTrue);
    });

    test('a recipe with no ingredients matches nothing', () {
      expect(
        DislikeVocabulary.recipeContainsAny(_recipeWith(const []), {'lök'}),
        isFalse,
      );
    });
  });
}
