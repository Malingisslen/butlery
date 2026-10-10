import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/file_import_strategy.dart';

Uint8List _latin1(String text) => Uint8List.fromList(latin1.encode(text));
Uint8List _utf8(String text) => Uint8List.fromList(utf8.encode(text));

void main() {
  late FileImportStrategy strategy;

  setUp(() => strategy = FileImportStrategy());

  group('Swedish Excel CSV', () {
    test(
      'proves a semicolon file saved as Latin-1, with commas inside a cell, '
      'imports with its å/ä/ö, ingredients and steps intact',
      () async {
        final bytes = _latin1(
          'Titel;Ingredienser;Gör så här\n'
          'Köttbullar på Åland;"2 dl mjöl, 1 tsk salt";'
          '1. Blanda mjölet. 2. Stek i ugnen på 175.\n',
        );

        final recipes = await strategy.importMultipleFromContent(bytes, 'csv');

        expect(recipes, hasLength(1));
        expect(recipes.single.title, 'Köttbullar på Åland');
        expect(recipes.single.ingredients, ['2 dl mjöl, 1 tsk salt']);
        expect(recipes.single.instructions, [
          'Blanda mjölet.',
          'Stek i ugnen på 175.',
        ]);
      },
    );

    test(
      'proves a leading sep=; line sets the separator and is not a recipe',
      () async {
        final bytes = _utf8('sep=;\nTitel;Ingredienser\nPannkakor;2 ägg\n');

        final recipes = await strategy.importMultipleFromContent(bytes, 'csv');

        expect(recipes.map((r) => r.title), ['Pannkakor']);
        expect(recipes.single.ingredients, ['2 ägg']);
      },
    );
  });

  group('FileImportStrategy.csvDelimiter', () {
    test('proves a delimiter inside a quoted header does not count', () {
      expect(
        FileImportStrategy.csvDelimiter('"titel, svensk";ingredienser\nx;y'),
        ';',
      );
    });

    test('proves tab, comma and the no-delimiter default are chosen', () {
      expect(FileImportStrategy.csvDelimiter('a\tb'), '\t');
      expect(FileImportStrategy.csvDelimiter('a,b'), ',');
      expect(FileImportStrategy.csvDelimiter('titel'), ',');
    });
  });

  group('JSON import', () {
    test(
      'proves a list of objects with Swedish keys gives one recipe each',
      () async {
        final bytes = _utf8(
          jsonEncode([
            {
              'Titel': 'Pannkakor',
              'Ingredienser': ['2 ägg', '3 dl mjölk'],
              'Gör så här': '1. Vispa. 2. Stek.',
            },
            {'titel': 'Våfflor', 'Taggar': 'Fika'},
          ]),
        );

        final recipes = await strategy.importMultipleFromContent(bytes, 'json');

        expect(recipes.map((r) => r.title), ['Pannkakor', 'Våfflor']);
        expect(recipes.first.ingredients, ['2 ägg', '3 dl mjölk']);
        expect(recipes.first.instructions, ['Vispa.', 'Stek.']);
        expect(recipes.last.personalTagIds, ['Fika']);
      },
    );

    test(
      'proves malformed JSON gives no recipes instead of an error',
      () async {
        expect(
          await strategy.importMultipleFromContent(_utf8('{not json'), 'json'),
          isEmpty,
        );
      },
    );

    test(
      'proves an item that is not an object is skipped, its neighbours kept',
      () async {
        final bytes = _utf8(
          jsonEncode([
            42,
            {'titel': 'Soppa'},
            'text',
          ]),
        );

        final recipes = await strategy.importMultipleFromContent(bytes, 'json');

        expect(recipes.map((r) => r.title), ['Soppa']);
      },
    );

    test('proves a top-level number gives no recipes', () async {
      expect(
        await strategy.importMultipleFromContent(_utf8('42'), 'json'),
        isEmpty,
      );
    });
  });
}
