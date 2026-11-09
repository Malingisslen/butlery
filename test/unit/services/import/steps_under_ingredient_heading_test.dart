/// A short recipe with an "Ingredienser" heading but no heading over the
/// method: the steps that follow the rows are steps, not rows, and none of
/// them is lost.
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

  bool mentions(List<String> lines, String word) =>
      lines.any((l) => l.toLowerCase().contains(word));

  test('steps after the rows become steps, the first one included', () async {
    final r = await parse(
      'Laxpasta\nIngredienser\n400 g pasta\n300 g laxfilé\n'
      'Koka pastan enligt anvisningen.\nStek laxen i en het panna.',
    );
    expect(r.instructions, hasLength(2));
    expect(r.instructions.first.toLowerCase(), contains('koka pastan'));
    expect(r.instructions.last.toLowerCase(), contains('stek laxen'));
    expect(mentions(r.ingredients, 'stek'), isFalse);
    expect(mentions(r.ingredients, 'pasta'), isTrue);
    expect(mentions(r.ingredients, 'laxfilé'), isTrue);
  });

  test('long steps after the rows are kept', () async {
    final r = await parse(
      'Laxpasta\nIngredienser\n400 g pasta\n300 g laxfilé\n'
      'Koka pastan enligt anvisningen på paketet.\n'
      'Stek laxen i en het panna i ca 3 minuter per sida.',
    );
    expect(r.instructions, hasLength(2));
    expect(r.ingredients, hasLength(2));
  });

  test('short steps under "Ingredienser:" do not become rows', () async {
    final r = await parse(
      'Laxpasta\nIngredienser:\n400 g pasta\n300 g laxfilé\n1 citron\n'
      'Koka pastan.\nStek laxen.\nPressa citron över.',
    );
    expect(r.ingredients, hasLength(3));
    expect(mentions(r.instructions, 'koka pastan'), isTrue);
    expect(mentions(r.instructions, 'stek laxen'), isTrue);
  });

  test('"Så här gör du" opens the method', () async {
    final r = await parse(
      'Laxpasta\nIngredienser\n400 g pasta\n300 g laxfilé\nSå här gör du\n'
      'Koka pastan enligt anvisningen.\nStek laxen i en het panna.',
    );
    expect(r.ingredients, hasLength(2));
    expect(mentions(r.ingredients, 'så här'), isFalse);
    expect(r.instructions, hasLength(2));
  });

  test(
    'a row ending in a period that starts like a verb stays a row',
    () async {
      final r = await parse(
        'Pasta\nIngredienser\n400 g pasta\nRiven parmesan.\n'
        'Strösocker att toppa med.\nKoka pastan enligt anvisningen.',
      );
      expect(mentions(r.ingredients, 'parmesan'), isTrue);
      expect(mentions(r.ingredients, 'strösocker'), isTrue);
      expect(r.instructions, hasLength(1));
    },
  );

  test('a step that ends on an ingredient word stays a step', () async {
    final r = await parse(
      'Pannbiff med lök\n400 g nötfärs\n2 gula lökar\nsmör till stekning\n'
      'Blanda färsen och forma fyra biffar.\n'
      'Skiva löken och stek den mjuk i smör.\n'
      'Stek biffarna 4 minuter per sida.',
    );
    expect(r.instructions, hasLength(3));
    expect(r.instructions[1].toLowerCase(), contains('skiva löken'));
  });

  // BUT-2505, Malin's call 2026-11-07: one paragraph of method is one step.
  test('a paragraph of several sentences is one step', () async {
    final r = await parse(
      'Laxpasta\nIngredienser\n400 g pasta\n300 g laxfilé\nGör så här\n'
      'Koka pastan enligt anvisningen. Häll av vattnet.\n'
      'Stek laxen i en het panna. Vänd efter tre minuter.',
    );
    expect(r.instructions, [
      'Koka pastan enligt anvisningen. Häll av vattnet.',
      'Stek laxen i en het panna. Vänd efter tre minuter.',
    ]);
  });

  test('sentences after a label on the same line stay apart', () async {
    final r = await parse(
      'Laxpasta\nIngredienser\n400 g pasta\n300 g laxfilé\n'
      'Tips: Koka pastan enligt anvisningen. Stek laxen i en het panna.',
    );
    expect(r.instructions, hasLength(2));
  });
}
