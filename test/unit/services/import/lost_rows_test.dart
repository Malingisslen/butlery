/// Rows a pasted recipe must keep: items written on one line, rows that
/// mention how they are used, words split across lines, and a title typed
/// without capitals.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/import/text_import_strategy.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

void main() {
  late TextImportStrategy strategy;

  setUp(() async {
    await BaseUnitTest.setupUnit();
    await TestServiceLocator.initialize();
    strategy = TextImportStrategy();
  });

  tearDown(() async {
    await TestServiceLocator.reset();
    BaseUnitTest.resetMocks();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  Future<Recipe> parse(String text) async {
    final result = await strategy.import(text);
    expect(result.isSuccess, isTrue, reason: result.errorMessage);
    return result.recipe!;
  }

  bool hasRow(Recipe r, String row) =>
      r.ingredients.any((i) => i.toLowerCase().trim() == row);

  test('a list on one line is one row per item', () async {
    final r = await parse(
      'Enkel tomatsoppa\n\n'
      'Ingredienser: 1 gul lök, 2 burkar krossade tomater, '
      '5 dl grönsaksbuljong, 1 tsk socker, salt\n\n'
      'Gör så här: Fräs löken mjuk. Tillsätt tomater och buljong.',
    );
    expect(hasRow(r, '1 gul lök'), isTrue);
    expect(hasRow(r, '2 burkar krossade tomater'), isTrue);
    expect(hasRow(r, 'salt'), isTrue);
    expect(r.ingredients, hasLength(5));
    expect(r.instructions.first, 'Fräs löken mjuk.');
  });

  test('a preparation note stays with its item', () async {
    final r = await parse(
      'Soppa\n\nIngredienser: 1 lök, skuren i tärningar, 2 dl vatten, '
      'helst kallt, 1 tsk salt\n\nGör så här: Koka soppan i tio minuter.',
    );
    expect(hasRow(r, '1 lök, skuren i tärningar'), isTrue);
    expect(hasRow(r, '2 dl vatten, helst kallt'), isTrue);
    expect(r.ingredients, hasLength(3));
  });

  test('a bare ingredient between measured items stays its own row', () async {
    final r = await parse(
      'Gryta\n\nIngredienser: 1 lök, 2 morötter, lagerblad, riven ost, '
      '100 g smör, choklad\n\nGör så här: Koka gryta i tio minuter.',
    );
    expect(hasRow(r, 'lagerblad'), isTrue);
    expect(hasRow(r, 'riven ost'), isTrue);
    expect(hasRow(r, 'choklad'), isTrue);
  });

  test('a seasoning list on one line stays one row', () async {
    final r = await parse(
      'Kycklinggryta\nIngredienser\n500 g kyckling\n'
      'Salt, svartpeppar, paprikapulver\nGör så här\nStek kycklingen.',
    );
    expect(hasRow(r, 'salt, svartpeppar, paprikapulver'), isTrue);
  });

  test('rows that say how they are used are kept', () async {
    final r = await parse(
      'Pasta\nIngredienser\n400 g pasta\nRiven parmesan till servering.\n'
      'Ströbröd att strö över\nSmör att pensla med\nGör så här\nKoka pastan.',
    );
    expect(r.ingredients.any((i) => i.contains('parmesan')), isTrue);
    expect(r.ingredients.any((i) => i.contains('ströbröd')), isTrue);
    expect(r.ingredients.any((i) => i.contains('smör')), isTrue);
  });

  test('a shop offer beside the recipe is not a row', () async {
    final r = await parse(
      'Laxpasta\n400 g pasta\n300 g laxfilé\nKöp 3 betala för 2 på all pasta\n'
      'Koka pastan enligt anvisningen.',
    );
    expect(r.ingredients.any((i) => i.contains('betala')), isFalse);
  });

  test('a method sentence under the ingredient list is a step', () async {
    final r = await parse(
      'Laxpasta\nIngredienser\n400 g pasta\n300 g laxfilé\n'
      'skär laxen i tärningar och stek dem snabbt.\n'
      'Koka pastan enligt anvisningen.',
    );
    expect(r.ingredients.any((i) => i.contains('tärningar')), isFalse);
    expect(r.ingredients.any((i) => i.contains('laxfilé')), isTrue);
    expect(r.instructions.join(' '), contains('tärningar'));
  });

  test('a word split across two lines is joined', () async {
    final r = await parse(
      'Kanelbullar\nDeg\n5 dl mjölk\n2 tsk stött kar-\ndamumma\n'
      '1. Värm mjölken.',
    );
    expect(hasRow(r, '2 tsk stött kardamumma'), isTrue);
  });

  test('a hyphen before "och" stays', () async {
    final r = await parse(
      'Soppa\nIngredienser\n2 purjolökar\n1 l buljong\nGör så här\n'
      'Skölj och skiva purjo-\noch lägg i grytan.',
    );
    expect(r.instructions.join(' '), contains('purjo- och'));
  });

  test('a title typed without capitals above the rows is the title', () async {
    final r = await parse(
      'korvstroganoff\n\n400 g falukorv\n1 gul lök\n\n'
      'skär korven i strimlor och stek med löken.',
    );
    expect(r.title, 'korvstroganoff');
    expect(hasRow(r, 'korvstroganoff'), isFalse);
  });

  test('an account name above the post is still not the title', () async {
    final r = await parse(
      'mat_med_mia\nFredagstacos\nIngredienser:\n500 g nötfärs\n'
      'Gör så här:\nBryn färsen.',
    );
    expect(r.title, 'Fredagstacos');
  });

  test('an account name right above the rows is not the title', () async {
    for (final handle in ['mat_med_mia', 'mia.lagar', 'mia2']) {
      final r = await parse(
        '$handle\n500 g nötfärs\n1 gul lök\nBryn färsen och löken.',
      );
      expect(r.title, isNot(handle), reason: handle);
    }
  });

  test('a step with a list of amounts stays one step', () async {
    final r = await parse(
      'Pannkakor\nIngredienser\n3 dl vetemjöl\n5 dl mjölk\nGör så här\n'
      '1. Vispa mjölet\n2. Tillsätt 2 dl mjölk, 1 dl vatten, 1 tsk salt\n'
      '3. Stek i smör',
    );
    expect(
      r.instructions,
      contains('Tillsätt 2 dl mjölk, 1 dl vatten, 1 tsk salt.'),
    );
    expect(r.ingredients, hasLength(2));

    final unnumbered = await parse(
      'Pannkakor\n3 dl vetemjöl\n5 dl mjölk\n'
      'Blanda 2 dl mjöl, 1 dl socker, 1 tsk salt och vispa',
    );
    expect(unnumbered.ingredients, hasLength(2));
  });
}
