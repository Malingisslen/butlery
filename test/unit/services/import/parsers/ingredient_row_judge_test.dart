/// A line decides what it is from its own form, so a cookbook photo whose
/// columns were read side by side still sorts into ingredients and method.
/// Every fixture is a line the corpus's OCR actually produced.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/parsers/ingredient_row_judge.dart';

void main() {
  RowVerdict judge(String line) => IngredientRowJudge.judge(line);

  group('a measured row is an ingredient', () {
    for (final line in [
      '125 g margarin eller smör',
      '1 3/4 dl strösocker',
      '1–2 msk arrak, rom eller konjak.',
      '2 tsk vanillinsocker/vanila',
      'ca 2 tsk arrowrotsmjöl + 2 msk kallt vatten',
      // OCR reads the digit 1 as a letter in front of the unit.
      'i tsk hackad färsk timjan',
      'a tsk salt',
      '} liter fint strimlad vitkål',
      // The amount stands inside the row, with no unit beside it.
      'saft av ½ citron',
      'finrivet skal och saft av 1 citron',
    ]) {
      test(line, () => expect(judge(line), RowVerdict.ingredient));
    }
  });

  group('a sentence is method text, wherever the page put it', () {
    for (final line in [
      'Smörj botten på en form, ca 24 cm',
      'Låt krämen svalna, rör då och då i den, och smaka av med vanillin-',
      'Fyll mördegsskalet med den kalla',
      'ten med kallt vatten, och sedan',
      'Kör kraftigt och sjud ytterligare 1',
      '1 dygn för innerfilé och 2 dygn för ytterfilé.',
      'smaksätt eventuellt med lite timjan',
      '25 minuter',
    ]) {
      test(line, () => expect(judge(line), RowVerdict.step));
    }
  });

  group('a stray piece of a line is dropped', () {
    for (final line in ['1 r', '2 n', '1 t', '{ kål']) {
      test(line, () => expect(judge(line), RowVerdict.noise));
    }
  });

  group('a short name with no amount is left to the caller', () {
    for (final line in ['salt', 'smör till formen', 'vispad grädde']) {
      test(line, () => expect(judge(line), RowVerdict.undecided));
    }
  });

  group('a row with no amount stays only when it names a food', () {
    for (final line in [
      'salt',
      'vitpeppar',
      'till formen: smör',
      'färska blåbär',
      'persilja',
      'rostade solroskärnor',
      'creme fraiche, 2 dl',
    ]) {
      test('keeps $line', () {
        expect(IngredientRowJudge.isPlausibleBareRow(line), isTrue);
      });
    }
    for (final line in [
      'csas',
      'alternativ',
      'smält blockchokladen och rör ner',
      'gör ugnsbakade chips av rotfruktsskalen',
      'mormorsmors, callas, receptsamling.',
      'unc',
    ]) {
      test('drops $line', () {
        expect(IngredientRowJudge.isPlausibleBareRow(line), isFalse);
      });
    }
  });

  group('two rows with different amounts are not a repeat', () {
    test('the dough flour and the cream flour', () {
      expect(
        IngredientRowJudge.differentAmounts('2 dl vetemjöl', '4 dl vetemjöl'),
        isTrue,
      );
    });
    test('the same row twice is a repeat', () {
      expect(
        IngredientRowJudge.differentAmounts('2 dl vetemjöl', '2 dl vetemjöl'),
        isFalse,
      );
    });
    test('a bare row and its measured twin are a repeat', () {
      expect(
        IngredientRowJudge.differentAmounts('salt', '1 tsk salt'),
        isFalse,
      );
    });
  });
}
