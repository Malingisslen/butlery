import 'package:butlery/services/parsing/crf/crf_ingredient_parser.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a fraction after the whole number stays in the amount', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['3', '½', 'dl', 'vetemjöl'],
      [BioLabel.bQty, BioLabel.other, BioLabel.bUnit, BioLabel.bName],
      '3 ½ dl vetemjöl',
    );
    expect(parsed.quantity, '3 ½');
    expect(parsed.unit, 'dl');
    expect(parsed.name, 'vetemjöl');
  });

  test('an ascii fraction after the whole number stays in the amount', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['2', '1/2', 'dl', 'mjölk'],
      [BioLabel.bQty, BioLabel.other, BioLabel.bUnit, BioLabel.bName],
      '2 1/2 dl mjölk',
    );
    expect(parsed.quantity, '2 1/2');
  });

  test('a fraction that starts the name part is left alone', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['salt', '1/2', 'tsk'],
      [BioLabel.bName, BioLabel.other, BioLabel.bUnit],
      'salt 1/2 tsk',
    );
    expect(parsed.quantity, isNull);
  });
}
