import 'package:butlery/services/parsing/crf/crf_ingredient_parser.dart';
import 'package:butlery/services/parsing/crf/crf_viterbi_decoder.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('a range at the start of the row is one amount', () {
    test('plain, spaced and dashed with an en dash', () {
      expect(CrfIngredientParser.withWrittenRange('6–8 ägg'), '6-8 ägg');
      expect(
        CrfIngredientParser.withWrittenRange('3 – 4 äggvitor'),
        '3-4 äggvitor',
      );
      expect(
        CrfIngredientParser.withWrittenRange('4-6 dl rödvin'),
        '4-6 dl rödvin',
      );
    });

    test('with fractions and mixed numbers at either end', () {
      expect(
        CrfIngredientParser.withWrittenRange('1/2 – 3/4 dl florsocker'),
        '1/2-3/4 dl florsocker',
      );
      expect(
        CrfIngredientParser.withWrittenRange('1 1/2–2 dl vispgrädde'),
        '1 1/2-2 dl vispgrädde',
      );
      expect(
        CrfIngredientParser.withWrittenRange('1–1 ½ msk soja'),
        '1-1 ½ msk soja',
      );
    });

    test('a row without a leading range is left alone', () {
      expect(CrfIngredientParser.withWrittenRange('2 dl mjölk'), '2 dl mjölk');
      expect(
        CrfIngredientParser.withWrittenRange('salt 1-2 tsk'),
        'salt 1-2 tsk',
      );
    });
  });

  test('a second amount further along the row is not this ingredient\'s', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['2', 'dl', 'mjöl', '+', '4', 'dl', 'vatten'],
      [
        BioLabel.bQty,
        BioLabel.bUnit,
        BioLabel.bName,
        BioLabel.other,
        BioLabel.bQty,
        BioLabel.bUnit,
        BioLabel.bName,
      ],
      '2 dl mjöl + 4 dl vatten',
    );
    expect(parsed.quantity, '2');
    expect(parsed.unit, 'dl');
  });

  test('a known unit straight after the amount is the unit', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['2', 'dl', 'vinbärsgelé'],
      [BioLabel.bQty, BioLabel.bName, BioLabel.iName],
      '2 dl vinbärsgelé',
    );
    expect(parsed.unit, 'dl');
    expect(parsed.name, 'vinbärsgelé');
  });

  test('a fraction with no unit after it is the amount', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['½', 'röd', 'chili'],
      [BioLabel.bUnit, BioLabel.bName, BioLabel.iName],
      '½ röd chili',
    );
    expect(parsed.quantity, '½');
    expect(parsed.unit, isNull);
    expect(parsed.name, 'röd chili');
  });

  test('a bunch is counted as a unit, the herb is the name', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['1', 'knippa', 'persilja'],
      [BioLabel.bQty, BioLabel.bName, BioLabel.iName],
      '1 knippa persilja',
    );
    expect(parsed.unit, 'knippa');
    expect(parsed.name, 'persilja');
  });

  test('a unit after the name, with no amount before the name, is kept', () {
    final parsed = CrfIngredientParser.assembleFromLabels(
      ['salt', '1', 'tsk'],
      [BioLabel.bName, BioLabel.bQty, BioLabel.bUnit],
      'salt 1 tsk',
    );
    expect(parsed.unit, 'tsk');
  });
}
