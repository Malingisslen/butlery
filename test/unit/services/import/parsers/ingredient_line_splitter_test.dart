import 'package:butlery/services/import/parsers/ingredient_line_splitter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('two ingredients on one printed line', () {
    test('bullets give one row per ingredient', () {
      expect(
        IngredientLineSplitter.process(
          '125 g mjukt smör • 1 tsk citronsaft • 1 äggula',
        ),
        '125 g mjukt smör\n1 tsk citronsaft\n1 äggula',
      );
    });

    test('a plus between two amounts splits', () {
      expect(
        IngredientLineSplitter.process('2 purjolökar + 1 stor morot'),
        '2 purjolökar\n1 stor morot',
      );
    });

    test('a comma before an amount and a name splits', () {
      expect(
        IngredientLineSplitter.process('10 vitpepparkorn, 2 lagerblad'),
        '10 vitpepparkorn\n2 lagerblad',
      );
    });

    test('a comma before a bare amount does not split', () {
      expect(
        IngredientLineSplitter.process('1 burk ananas, 400 g'),
        '1 burk ananas, 400 g',
      );
      expect(
        IngredientLineSplitter.process('4 äggvitor, 1 dl'),
        '4 äggvitor, 1 dl',
      );
    });

    test('a time and a yield after a comma stay on the row', () {
      expect(
        IngredientLineSplitter.process('4 portioner, 30 minuter'),
        '4 portioner, 30 minuter',
      );
    });

    test('a long part after a bullet stays with the row before it', () {
      expect(
        IngredientLineSplitter.process(
          '125 g smör • rivet skal av ½ citron • 1 äggula',
        ),
        '125 g smör rivet skal av ½ citron\n1 äggula',
      );
    });

    test('a sentence of the method with a bullet is left alone', () {
      const step =
          'Mjölken, salta och peppra lite. • Skala potatisen och skär den.';
      expect(IngredientLineSplitter.process(step), step);
    });
  });
}
