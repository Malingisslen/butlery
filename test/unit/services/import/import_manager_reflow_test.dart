/// `ImportManager.recipeBlocks` rejoins OCR-wrapped lines only when asked,
/// before the split on the text path and per block when a layout is usable
/// (BUT-2455).
library;

import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/services/ocr/text_layout.dart';
import 'package:flutter_test/flutter_test.dart';

const _wrapped =
    'Kycklinggryta\n'
    'Ingredienser\n'
    '500 g kycklingfilé\n'
    '2 dl grädde\n'
    'Salt, peppar, paprika,\n'
    'kycklingkrydda\n'
    'Gör så här\n'
    'Smält ner\n'
    'smöret i en kastrull på medelvärme.\n'
    'Häll i grädden och låt sjuda i\n'
    'tio minuter.';

const _joined =
    'Kycklinggryta\n'
    'Ingredienser\n'
    '500 g kycklingfilé\n'
    '2 dl grädde\n'
    'Salt, peppar, paprika, kycklingkrydda\n'
    'Gör så här\n'
    'Smält ner smöret i en kastrull på medelvärme.\n'
    'Häll i grädden och låt sjuda i tio minuter.';

DocumentLayout _layoutFor(String text) => DocumentLayout([
  PageLayout(
    lines: [
      for (final (i, line) in text.split('\n').indexed)
        OcrLine(
          text: line,
          box: LayoutBox(
            left: 0,
            top: i * 24.0,
            width: line.length * 12.0,
            height: 20,
          ),
        ),
    ],
  ),
]);

void main() {
  group('ImportManager.recipeBlocks reflow', () {
    test('without reflow the text is handed on as it is', () {
      expect(ImportManager.recipeBlocks(_wrapped), [_wrapped]);
    });

    test('with reflow and no layout the wrapped lines are rejoined', () {
      expect(ImportManager.recipeBlocks(_wrapped, reflow: true), [_joined]);
    });

    test('with reflow and a usable layout the block is rejoined too', () {
      final layout = _layoutFor(_wrapped);
      expect(layout.matchesLineCountOf(_wrapped), isTrue);
      expect(
        ImportManager.recipeBlocks(_wrapped, layout: layout, reflow: true),
        [_joined],
      );
    });

    test('a fragment left unjoined would open a false recipe', () {
      // Two recipes on a page. The first ends on a serving note the OCR broke
      // after two words; the splitter reads that short capitalised fragment
      // as the second recipe's title unless the lines are rejoined BEFORE the
      // split, which makes it too long to be one.
      const page =
          'Italiensk frittata\n'
          'Ingredienser\n'
          '6 ägg\n'
          '1 dl grädde\n'
          '2 dl riven ost\n'
          'Gör så här\n'
          'Vispa äggen med grädden och osten.\n'
          'Häll i en smord form och grädda i 20 minuter.\n'
          'Gott med\n'
          'en grön sallad, ett gott bröd och lite olivolja ringlad över alltihop.\n'
          'Fransk omelett\n'
          'Ingredienser\n'
          '3 ägg\n'
          '1 msk smör\n'
          '1 krm salt\n'
          'Gör så här\n'
          'Vispa äggen med saltet.\n'
          'Smält smöret i pannan och häll i äggen.\n'
          'Rör tills omeletten stelnat och vik ihop den.';
      final blocks = ImportManager.recipeBlocks(page, reflow: true);
      expect(blocks, hasLength(2));
      expect(blocks[0], endsWith('ringlad över alltihop.'));
      expect(blocks[1], startsWith('Fransk omelett'));
    });
  });
}
