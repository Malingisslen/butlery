import 'package:butlery/services/import/parsers/inline_bullet_list_splitter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('splits a wrapped bullet-separated list into one item per line', () {
    const input =
        'Till 4 portioner behövs:\n'
        '750 g potatis - 100 g fläsk • 2 lökar • 1 me\n'
        'delstor gurka 2 msk mjöl • 1/2\n'
        'l köttbuljong • salt\n'
        'Ca 1675 kJ per portion';
    expect(
      InlineBulletListSplitter.split(input).split('\n'),
      [
        'Till 4 portioner behövs:',
        '750 g potatis',
        '100 g fläsk',
        '2 lökar',
        '1 me delstor gurka 2 msk mjöl',
        '1/2 l köttbuljong',
        'salt',
        'Ca 1675 kJ per portion',
      ],
    );
  });

  test('keeps number ranges and lists with fewer than two bullets', () {
    const ranges = 'Du behöver:\n2 - 3 msk smör • 1 dl mjölk • salt';
    expect(
      InlineBulletListSplitter.split(ranges).split('\n'),
      ['Du behöver:', '2 - 3 msk smör', '1 dl mjölk', 'salt'],
    );
    const plain = 'Ingredienser:\n2 dl mjölk • salt';
    expect(InlineBulletListSplitter.split(plain), plain);
  });

  test('leaves an ordinary one-bullet-per-line list and its steps alone', () {
    const input = [
      'Ingredienser:',
      '• 2 dl smör - rumstempererat',
      '• 1 tsk salt',
      '• 3 ägg',
      '1. Smält smöret.',
    ];
    expect(InlineBulletListSplitter.split(input.join('\n')), input.join('\n'));
  });

  test('does not glue a numbered step onto the last item', () {
    const input = [
      'Till 4 portioner behövs:',
      '2 dl mjölk • salt • 1 tsk socker',
      '1. Koka mjölken.',
    ];
    expect(
      InlineBulletListSplitter.split(input.join('\n')).split('\n').last,
      '1. Koka mjölken.',
    );
  });
}
