/// A line an OCR reader broke mid-sentence is rejoined; a line that is a row
/// of its own is not (BUT-2455).
library;

import 'dart:io';

import 'package:butlery/services/import/layout/line_reflow.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('reflowWrappedLines', () {
    test('a numbered step naming ingredients is still rejoined', () {
      expect(
        reflowWrappedLines(
          '2. Hetta upp en panna med smör och olja och stek\n'
          'kycklingen tills den tar färg.',
        ),
        '2. Hetta upp en panna med smör och olja och stek '
        'kycklingen tills den tar färg.',
      );
    });

    group('inside a numbered step', () {
      const method = [
        'Gör såhär',
        '1. Skär kycklingen i tärningar och krydda med de',
        'angivna kryddorna. Finhacka schalottenlök och',
        'vitlök och riv parmesan. Smält ner',
        'buljongtärningarna i hett vatten.',
        '',
        '2. Hetta upp en panna med smör och olja och stek',
        'kycklingen tills den tar färg. Tillsätt schalottenlök',
        'och vitlök och stek ihop i ca 1min. Häll i',
        'buljongvattnet och koka upp.',
        '',
        '3. Blanda i creme fraiche och tillsätt resterande',
        'ingredienser. Låt småkoka på svag värme i ca 2min.',
        'Om det behövs kan du smaka av med kryddorna',
        'som du använde till kycklingen. Servera med ris,',
        'potatis eller pasta! mindre',
        'För 6 dagar sedan',
      ];

      test('a capital after a full stop keeps the step whole', () {
        final out = reflowWrappedLines(method.join('\n')).split('\n');
        expect(
          out,
          contains(
            '3. Blanda i creme fraiche och tillsätt resterande ingredienser. '
            'Låt småkoka på svag värme i ca 2min. Om det behövs kan du smaka av '
            'med kryddorna som du använde till kycklingen. Servera med ris, '
            'potatis eller pasta! mindre',
          ),
        );
        expect(out.where((l) => l.startsWith('1. ')), hasLength(1));
        expect(out.where((l) => l.startsWith('2. ')), hasLength(1));
        expect(out.last, 'För 6 dagar sedan');
      });

      test('the next number, a blank line and a heading end the step', () {
        final out = reflowWrappedLines(
          '1. Blanda allt.\n2. Grädda i ugnen.\nServera varmt.\n\nTips\n'
          '3. Vila.\nIngredienser\n2 dl mjölk',
        ).split('\n');
        expect(out.first, '1. Blanda allt.');
        expect(out[1], '2. Grädda i ugnen. Servera varmt.');
        expect(out, contains('Ingredienser'));
        expect(out, contains('2 dl mjölk'));
      });

      test('prose without a number keeps its sentences apart', () {
        const prose = 'Blanda allt.\nGrädda i ugnen.\nServera varmt.';
        expect(reflowWrappedLines(prose), prose);
      });

      test('a second pass changes nothing', () {
        final once = reflowWrappedLines(method.join('\n'));
        expect(reflowWrappedLines(once), once);
      });
    });

    test('a decimal quantity is not a step number', () {
      expect(reflowWrappedLines('1.5 dl grädde\nsalt'), '1.5 dl grädde\nsalt');
    });

    test('a step broken after a dangling word is rejoined', () {
      expect(
        reflowWrappedLines(
          '1. Smält smöret och häll i\nmjölken. Värm till 37 grader.',
        ),
        '1. Smält smöret och häll i mjölken. Värm till 37 grader.',
      );
    });

    test('a short line ending on a dangling word is rejoined', () {
      expect(
        reflowWrappedLines('häll i\nmjölken och rör om.'),
        'häll i mjölken och rör om.',
      );
    });

    test('a step broken mid-prose is rejoined', () {
      expect(
        reflowWrappedLines(
          '2. Smula jästen i en bunke\noch häll över degvätskan.',
        ),
        '2. Smula jästen i en bunke och häll över degvätskan.',
      );
    });

    test('a hyphenated word is mended', () {
      expect(
        reflowWrappedLines('2 tsk stött kar-\ndamumma'),
        '2 tsk stött kardamumma',
      );
      expect(
        reflowWrappedLines(
          '3. Tillsätt resten av ingre-\ndienserna och knåda degen\ni 10 minuter.',
        ),
        '3. Tillsätt resten av ingredienserna och knåda degen i 10 minuter.',
      );
    });

    test('a hyphen before och, eller or samt stays', () {
      expect(
        reflowWrappedLines('Potatis-\noch purjolökssoppa'),
        'Potatis- och purjolökssoppa',
      );
    });

    test('a two-word step opening joins its prose continuation', () {
      expect(
        reflowWrappedLines('Smält ner\nsmöret i en kastrull på medelvärme.'),
        'Smält ner smöret i en kastrull på medelvärme.',
      );
    });

    test('a spice row that ends in a comma takes its last item', () {
      expect(
        reflowWrappedLines('Salt, peppar, paprika,\nkycklingkrydda'),
        'Salt, peppar, paprika, kycklingkrydda',
      );
    });

    test('a quantity row never takes the row after it', () {
      const text = '1 tsk salt\nvatten';
      expect(reflowWrappedLines(text), text);
    });

    test('a one-word heading never takes a bare ingredient', () {
      const text = 'Deg\nsalt\n50 g jäst';
      expect(reflowWrappedLines(text), text);
    });

    test('nothing joins into a numbered step, a bullet or a heading', () {
      const text =
          'Rör om och låt sjuda\n2. Häll i grädden\n- en nypa salt\nFyllning\nServera med\ningredienser:\nRör om och låt sjuda\n2 dl grädde';
      expect(reflowWrappedLines(text), text);
    });

    test('a lowercase step number or quantity row is a line of its own', () {
      const text =
          'Rör om och låt sjuda\nsteg 2 koka upp\n\nRör om och låt sjuda\nca 2 dl grädde';
      expect(reflowWrappedLines(text), text);
    });

    test('a heading never takes the prose under it', () {
      const text = 'Gör så här\nsmält smöret i en kastrull';
      expect(reflowWrappedLines(text), text);
    });

    test('a lowercase prose line takes a short continuation', () {
      expect(
        reflowWrappedLines('värm mjölken till fingervarmt\noch häll över.'),
        'värm mjölken till fingervarmt och häll över.',
      );
    });

    test('nothing joins across a blank line', () {
      const text = 'Servera med\n\nris';
      expect(reflowWrappedLines(text), text);
    });

    test('a sentence that ended stays ended', () {
      const text = 'Låt jäsa 30 minuter.\nkavla ut degen';
      expect(reflowWrappedLines(text), text);
    });

    test('a continuation that opens with a capital is a line of its own', () {
      const text = 'Purjolök innehåller mycket\nC-vitamin och fibrer.';
      expect(reflowWrappedLines(text), text);
    });

    test('a two-word numbered step joins its prose continuation', () {
      expect(
        reflowWrappedLines('2. Vänta\ntills degen har jäst klart.'),
        '2. Vänta tills degen har jäst klart.',
      );
      expect(
        reflowWrappedLines('3) Grädda\ni ugnen tills den är gyllene.'),
        '3) Grädda i ugnen tills den är gyllene.',
      );
    });

    test('is idempotent over every gold text in the import gate', () {
      final files = [
        for (final dir in ['test/import_gate/text', 'test/import_gate/stokig'])
          ...Directory(dir).listSync().whereType<File>().where(
            (f) => f.path.endsWith('.txt'),
          ),
      ];
      expect(files, isNotEmpty);
      for (final file in files) {
        final once = reflowWrappedLines(file.readAsStringSync());
        expect(reflowWrappedLines(once), once, reason: file.path);
      }
    });

    test(
      'the kanelbullar page keeps its ingredient rows and joins its steps',
      () {
        final text = File(
          Directory('test/import_gate/stokig')
              .listSync()
              .map((f) => f.path)
              .firstWhere((p) => p.contains('03') && p.endsWith('.txt')),
        ).readAsStringSync();
        final out = reflowWrappedLines(text).split('\n');
        expect(out, contains('2 tsk stött kardamumma'));
        expect(out, contains('50 g jäst'));
        expect(out, contains('1 dl socker'));
        expect(out, contains('Fyllning'));
        expect(
          out,
          contains('1. Smält smöret och häll i mjölken. Värm till 37 grader.'),
        );
        expect(
          out,
          contains(
            '4. Låt jäsa 30 minuter. Kavla ut och bred på fyllningen. '
            'Grädda i 250 grader 5-6 min.',
          ),
        );
        expect(out, contains('FOTO: ANNA SVENSSON'));
      },
    );
  });
}
