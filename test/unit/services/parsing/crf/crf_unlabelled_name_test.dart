import 'package:butlery/services/parsing/crf/crf_ingredient_parser.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('without a name span the name is the line minus amount and unit', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['3', 'medelstora', 'äpplen'],
      [BioLabel.bQty, BioLabel.other, BioLabel.other],
      '3 medelstora äpplen',
    );
    expect(parsed.quantity, '3');
    expect(parsed.name, 'medelstora äpplen');
  });

  test('commas in the remainder stay attached to the word before them', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['6', 'medelstora', ',', 'råskalade', 'potatisar'],
      [
        BioLabel.bQty,
        BioLabel.other,
        BioLabel.other,
        BioLabel.other,
        BioLabel.other,
      ],
      '6 medelstora, råskalade potatisar',
    );
    expect(parsed.name, 'medelstora, råskalade potatisar');
  });

  test('a line that is only an amount keeps the line as its name', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['2', 'dl'],
      [BioLabel.bQty, BioLabel.bUnit],
      '2 dl',
    );
    expect(parsed.name, '2 dl');
  });

  test('a labelled name is untouched', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['2', 'ägg'],
      [BioLabel.bQty, BioLabel.bName],
      '2 ägg',
    );
    expect(parsed.name, 'ägg');
  });

  test('size and preparation words are not repeated in the name', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['3', 'stora', 'äpplen'],
      [BioLabel.bQty, BioLabel.bSize, BioLabel.other],
      '3 stora äpplen',
    );
    expect(parsed.size, 'stora');
    expect(parsed.name, 'äpplen');
  });

  test('a remainder without letters or digits falls back to the line', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['1', 'burk', '(', '400', 'ml', ')'],
      [
        BioLabel.bQty,
        BioLabel.bUnit,
        BioLabel.other,
        BioLabel.bQty,
        BioLabel.bUnit,
        BioLabel.other,
      ],
      '1 burk (400 ml)',
    );
    expect(parsed.name, '1 burk (400 ml)');
  });
}
