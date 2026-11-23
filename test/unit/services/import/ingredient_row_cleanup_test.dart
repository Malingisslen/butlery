import 'package:butlery/services/import/parsers/ingredient_row_joiner.dart';
import 'package:butlery/services/import/parsers/ingredient_row_judge.dart';
import 'package:butlery/services/import/text_import_strategy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../infrastructure/di/test_service_locator.dart';

void main() {
  group(
    'IngredientRowJoiner: an ingredient the column broke over two lines',
    () {
      test('an open "eller" takes the next word row', () {
        expect(
          IngredientRowJoiner.join('1-2 msk röd- eller', 'vitvinsvinäger'),
          '1-2 msk röd- eller vitvinsvinäger',
        );
      });

      test('a row that opens with "eller" continues the row above', () {
        expect(
          IngredientRowJoiner.join(
            '1 tsk spirulina, vetegräs',
            'eller nässelpulver',
          ),
          '1 tsk spirulina, vetegräs eller nässelpulver',
        );
      });

      test('a hyphen at the line end only marked the break', () {
        expect(
          IngredientRowJoiner.join(
            '2 kött- eller grönsaks-',
            'buljongtärningar',
          ),
          '2 kött- eller grönsaksbuljongtärningar',
        );
      });

      test('an amount and unit with no name takes the name below', () {
        expect(
          IngredientRowJoiner.join('½ knippa', 'gräslök'),
          '½ knippa gräslök',
        );
      });

      test('a row ending on a word that needs a noun takes the line below', () {
        expect(
          IngredientRowJoiner.join('2 msk neutral rapsolja till', 'stekning'),
          '2 msk neutral rapsolja till stekning',
        );
        expect(
          IngredientRowJoiner.join('24 små tomater, gärna i olika', 'färger'),
          '24 små tomater, gärna i olika färger',
        );
      });

      test('an amount, unit and describing words take the name below', () {
        expect(
          IngredientRowJoiner.join('1 msk koncentrerad', 'grönsaksfond'),
          '1 msk koncentrerad grönsaksfond',
        );
        expect(
          IngredientRowJoiner.join('3 msk mjukt', 'smör'),
          '3 msk mjukt smör',
        );
        expect(
          IngredientRowJoiner.join('2 msk hackade, syltade', 'apelsinskal'),
          '2 msk hackade, syltade apelsinskal',
        );
      });

      test('a row that names its ingredient is not joined to a bare word', () {
        expect(IngredientRowJoiner.join('3 dl salt', 'peppar'), isNull);
        expect(IngredientRowJoiner.join('100 g choklad', 'Garnering'), isNull);
        expect(IngredientRowJoiner.join('2 dl sallad', 'dressing'), isNull);
        expect(IngredientRowJoiner.join('2 msk smör', 'apelsinskal'), isNull);
      });

      test('two complete rows stay two rows', () {
        expect(IngredientRowJoiner.join('1 tsk salt', 'svartpeppar'), isNull);
        expect(IngredientRowJoiner.join('2 dl vatten', '1 msk smör'), isNull);
      });

      test(
        'an open "och" takes the word row below it',
        () {
          expect(
            IngredientRowJoiner.join('2 dl mjölk och', 'grädde'),
            '2 dl mjölk och grädde',
          );
        },
      );

      test('a row below that is a sentence is not pulled up', () {
        expect(
          IngredientRowJoiner.join(
            '1 msk smör eller',
            'Blanda allt och rör om väl nu.',
          ),
          isNull,
        );
      });
    },
  );

  group('IngredientRowJudge.endsMidSentence', () {
    test('method text cut at a dangling word is not an ingredient', () {
      expect(
        IngredientRowJudge.endsMidSentence('1 msk av detta i pannan och'),
        isTrue,
      );
      expect(
        IngredientRowJudge.endsMidSentence('3 st av dem i skivor och'),
        isTrue,
      );
    });

    test('a row of fewer than four words is kept', () {
      expect(IngredientRowJudge.endsMidSentence('1 msk och'), isFalse);
    });

    test('rows naming a food with an allergen are kept', () {
      for (final row in [
        '1 dl vitt vin och',
        '2 msk tahini och',
        '1 burk ansjovis i olja och',
        '2 dl dinkelflingor och',
        '4 st hummer och',
      ]) {
        expect(IngredientRowJudge.endsMidSentence(row), isFalse, reason: row);
      }
    });

    test('a four-word row naming an allergen carrier is kept', () {
      expect(IngredientRowJudge.endsMidSentence('2 dl mjölk och'), isFalse);
      expect(
        IngredientRowJudge.endsMidSentence('1 dl vetemjöl till pannan och'),
        isFalse,
      );
    });

    test('a complete row is not', () {
      expect(IngredientRowJudge.endsMidSentence('1 msk smör'), isFalse);
      expect(IngredientRowJudge.endsMidSentence('2 dl grädde eller'), isFalse);
    });
  });

  test(
    'a photographed list with a broken row and a caption comes out clean',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await TestServiceLocator.initialize();
      final result = await TextImportStrategy().import(
        'Smoothie\n4 portioner\nIngredienser\n1 dl vatten\n'
        '1 tsk spirulina, vetegräs\neller nässelpulver\n1 banan, i bitar\n'
        '1-2 msk röd- eller\nvitvinsvinäger\n1 tsk salt\n'
        'Gör så här\nVispa ihop allt och stek i smör.\n',
      );
      final rows = result.recipe!.ingredients;
      expect(rows, contains('1 tsk spirulina, vetegräs eller nässelpulver'));
      expect(rows, contains('1-2 msk röd- eller vitvinsvinäger'));
      expect(rows, isNot(contains('eller nässelpulver')));
      expect(rows, isNot(contains('vitvinsvinäger')));
    },
  );

  test(
    'a row cut off in the middle of a sentence is not an ingredient',
    () async {
      TestWidgetsFlutterBinding.ensureInitialized();
      SharedPreferences.setMockInitialValues(const <String, Object>{});
      await TestServiceLocator.initialize();
      final result = await TextImportStrategy().import(
        'Pannbiff\n4 portioner\nIngredienser\n1 dl vatten\n'
        '1 msk av detta i pannan och\n2 tsk salt\n'
        'Gör så här\nVispa ihop allt och stek i smör.\n',
      );
      final rows = result.recipe!.ingredients;
      expect(rows, contains('2 tsk salt'));
      expect(rows.any((r) => r.contains('i pannan och')), isFalse);
    },
  );

  test('a word row under a cut-off row is not glued onto it', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestServiceLocator.initialize();
    final result = await TextImportStrategy().import(
      'Pannbiff\n4 portioner\nIngredienser\n1 dl vatten\n'
      '1 msk av detta i pannan och\nsmör\n2 tsk salt\n'
      'Gör så här\nVispa ihop allt och stek i smör.\n',
    );
    final rows = result.recipe!.ingredients;
    expect(rows.any((r) => r.contains('i pannan och')), isFalse);
    expect(rows, contains('2 tsk salt'));
  });

  test('an ingredient broken over three lines comes out as one row', () async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues(const <String, Object>{});
    await TestServiceLocator.initialize();
    final result = await TextImportStrategy().import(
      'Pannbiff\n4 portioner\nIngredienser\n1 dl vatten\n'
      '2 dl vatten eller\nmjölk eller\nbuljong\n2 tsk salt\n'
      'Gör så här\nVispa ihop allt och stek i smör.\n',
    );
    final rows = result.recipe!.ingredients;
    expect(rows, contains('2 dl vatten eller mjölk eller buljong'));
  });
}
