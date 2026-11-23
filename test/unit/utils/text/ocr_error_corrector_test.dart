import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/utils/text/ocr_error_corrector.dart';

void main() {
  group('OcrErrorCorrector', () {
    group('correctLine', () {
      test('corrects rn -> m substitution', () {
        // "rnorot" -> "morot" (carrot)
        expect(OcrErrorCorrector.correctLine('2 dl rnorot'), '2 dl morot');
      });

      test('corrects 0 -> o substitution', () {
        // "0lja" -> "olja" (oil)
        expect(OcrErrorCorrector.correctLine('1 msk 0lja'), '1 msk olja');
      });

      test('corrects 1 -> l substitution', () {
        // "1\u00F6k" -> "l\u00F6k" (onion)
        expect(
          OcrErrorCorrector.correctLine('1 st 1\u00F6k'),
          '1 st l\u00F6k',
        );
      });

      test('does not change already-known words', () {
        expect(
          OcrErrorCorrector.correctLine('2 dl mj\u00F6lk'),
          '2 dl mj\u00F6lk',
        );
        expect(OcrErrorCorrector.correctLine('salt'), 'salt');
      });

      test('does not change unknown words with no valid correction', () {
        expect(OcrErrorCorrector.correctLine('xyzabc'), 'xyzabc');
      });

      test('handles empty string', () {
        expect(OcrErrorCorrector.correctLine(''), '');
      });

      test('preserves spacing', () {
        expect(
          OcrErrorCorrector.correctLine('2  dl  rnorot'),
          '2 dl morot',
        );
      });

      test('corrects di -> dl (cookbook OCR misreads the unit)', () {
        // The systematic cookbook-OCR error: "4 di apelsinjuice" should be dl.
        expect(
          OcrErrorCorrector.correctLine('4 di apelsinjuice'),
          '4 dl apelsinjuice',
        );
      });

      test('di -> dl does not corrupt real words containing "di"', () {
        // "dill" must survive — the candidate "dlll" is not a known word, so
        // the gate rejects the swap.
        expect(OcrErrorCorrector.correctLine('1 kruka dill'), '1 kruka dill');
        expect(OcrErrorCorrector.correctLine('dijonsenap'), 'dijonsenap');
      });

      test('reads a pipe glued to a unit as l, never a lone pipe', () {
        expect(OcrErrorCorrector.correctLine('2 d|'), '2 dl');
        expect(OcrErrorCorrector.correctLine('2 dl | grädde'), '2 dl | grädde');
      });

      test('reads a lone d after an amount as dl', () {
        expect(
          OcrErrorCorrector.correctLine('creme fraiche naturell, 2 d'),
          'creme fraiche naturell, 2 dl',
        );
        expect(OcrErrorCorrector.correctLine('1,5 d |'), '1,5 dl |');
        expect(OcrErrorCorrector.correctLine('vitamin d'), 'vitamin d');
      });
    });

    group('correctLines', () {
      test('corrects multiple lines', () {
        final lines = ['2 dl rnorot', '1 msk 0lja'];
        final corrected = OcrErrorCorrector.correctLines(lines);
        expect(corrected, ['2 dl morot', '1 msk olja']);
      });
    });

    test('reads a whole number glued to its fraction as a mixed amount', () {
      expect(
        OcrErrorCorrector.correctLine('21/2 dl grädde'),
        '2 1/2 dl grädde',
      );
      expect(OcrErrorCorrector.correctLine('11/4 dl mjölk'), '1 1/4 dl mjölk');
      expect(OcrErrorCorrector.correctLine('1/2 dl mjölk'), '1/2 dl mjölk');
    });

    test('reads a percent sign before a unit as the half sign', () {
      expect(OcrErrorCorrector.correctLine('% dl sirap'), '½ dl sirap');
      expect(OcrErrorCorrector.correctLine('1% dl socker'), '1½ dl socker');
      expect(OcrErrorCorrector.correctLine('1%½ dl socker'), '1½ dl socker');
      expect(OcrErrorCorrector.correctLine('v½ dl mjölk'), '½ dl mjölk');
      expect(OcrErrorCorrector.correctLine('1% mjölk'), '1% mjölk');
      expect(OcrErrorCorrector.correctLine('% grädde'), '% grädde');
      expect(OcrErrorCorrector.correctLine('v½ grädde'), 'v½ grädde');
    });

    group('letters the reader could not make out', () {
      test('restores the marks a Swedish vowel lost', () {
        expect(
          OcrErrorCorrector.correctLine('7 dl vetemjol'),
          '7 dl vetemjöl',
        );
        expect(OcrErrorCorrector.correctLine('2 dl gradde'), '2 dl grädde');
        expect(
          OcrErrorCorrector.correctLine('2 msk strosocker'),
          '2 msk strösocker',
        );
      });

      test('reads the dotless i and a stray mark as what they stand for', () {
        expect(OcrErrorCorrector.correctLine('persılja'), 'persilja');
        expect(OcrErrorCorrector.correctLine('blåbăr'), 'blåbär');
        expect(OcrErrorCorrector.correctLine('3 üggulor'), '3 äggulor');
      });

      test('reads an i for the l and a u for the v', () {
        expect(OcrErrorCorrector.correctLine('halion'), 'hallon');
        expect(
          OcrErrorCorrector.correctLine('2 vitlökskiyftor'),
          '2 vitlöksklyftor',
        );
        expect(OcrErrorCorrector.correctLine('3 ägguitor'), '3 äggvitor');
      });

      test('leaves a short word and a real word one swap away alone', () {
        expect(OcrErrorCorrector.correctLine('kal'), 'kal');
        expect(OcrErrorCorrector.correctLine('platt'), 'platt');
      });
    });
  });

  group('an amount the reader garbled', () {
    test('a one read as the letter i or l', () {
      expect(OcrErrorCorrector.correctLine('i dl kakao'), '1 dl kakao');
      expect(OcrErrorCorrector.correctLine('i morot'), '1 morot');
      expect(OcrErrorCorrector.correctLine('i botten'), 'i botten');
      expect(OcrErrorCorrector.correctLine('½ i vinäger'), '½ i vinäger');
      expect(OcrErrorCorrector.correctLine('i en kastrull'), 'i en kastrull');
    });

    test('dl read as d/ or al, litre read as i, | or /', () {
      expect(OcrErrorCorrector.correctLine('5½ d/ vetemjöl'), '5½ dl vetemjöl');
      expect(
        OcrErrorCorrector.correctLine('4 al tjock grädde'),
        '4 dl tjock grädde',
      );
      expect(OcrErrorCorrector.correctLine('½ | gräddfil'), '½ l gräddfil');
      expect(OcrErrorCorrector.correctLine('1 ½ / vatten'), '1 ½ l vatten');
      expect(
        OcrErrorCorrector.correctLine('1/2 i köttbuljong'),
        '1/2 l köttbuljong',
      );
    });

    test('11 ahead of a liquid is 1 l, ahead of a countable is left', () {
      expect(
        OcrErrorCorrector.correctLine('11 köttbuljong'),
        '1 l köttbuljong',
      );
      expect(OcrErrorCorrector.correctLine('11 äpplen'), '11 äpplen');
    });
  });
}
