/// BUT-2157: the dish names a kept week draft carries so the resume card can
/// show the week without reading the library. They go through the real JSON
/// codec, because that is how the device keeps them.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/menu/weekly_menu_draft.dart';

final _written = DateTime(2026, 10, 1, 12);

Map<String, Object?> _json({Object? names, bool withNames = true}) => {
  'prompt': 'två middagar',
  'meals': [
    {
      'mealType': 'Middag',
      'recipeIds': ['r1', 'r2'],
    },
  ],
  'requested': {'middag': 2},
  'lastModifiedAt': _written.toIso8601String(),
  if (withNames) 'names': names,
};

WeeklyMenuDraft _read(Map<String, Object?> json) =>
    WeeklyMenuDraft.fromJson(jsonDecode(jsonEncode(json)))!;

void main() {
  group('recipeNames', () {
    test('survive a write and a read through the JSON codec', () {
      final draft = WeeklyMenuDraft(
        prompt: 'två middagar',
        recipeIdsByMealType: const {
          'Middag': ['r1', 'r2'],
        },
        requestedByMealType: const {'middag': 2},
        lastModifiedAt: _written,
        recipeNames: const {'r1': 'Köttbullar', 'r2': 'Fiskgratäng'},
      );

      final back = _read(draft.toJson());

      expect(back.recipeNames, {'r1': 'Köttbullar', 'r2': 'Fiskgratäng'});
      expect(back.recipeIdsByMealType['Middag'], ['r1', 'r2']);
    });

    test('a draft written before names existed reads with none', () {
      final old = _json(withNames: false);
      expect(old.containsKey('names'), isFalse);

      final draft = _read(old);

      expect(draft.recipeNames, isEmpty);
      expect(draft.recipeCount, 2, reason: 'the rest of the draft still reads');
    });

    test('only non-empty text names are kept', () {
      final draft = _read(
        _json(
          names: {
            'r1': 'Köttbullar',
            'empty': '',
            'number': 7,
            'nothing': null,
            'list': ['x'],
            'map': {'a': 'b'},
            'r2': 'Fiskgratäng',
          },
        ),
      );

      expect(draft.recipeNames, {'r1': 'Köttbullar', 'r2': 'Fiskgratäng'});
    });

    test('a names value that is not a map reads as none', () {
      expect(_read(_json(names: 'Köttbullar')).recipeNames, isEmpty);
      expect(_read(_json(names: ['Köttbullar'])).recipeNames, isEmpty);
      expect(_read(_json()).recipeNames, isEmpty);
    });
  });
}
