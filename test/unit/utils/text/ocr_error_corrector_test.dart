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

      test('corrects di -> dl (OCR.space engine 2 misreads the unit)', () {
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
    });

    group('correctLines', () {
      test('corrects multiple lines', () {
        final lines = ['2 dl rnorot', '1 msk 0lja'];
        final corrected = OcrErrorCorrector.correctLines(lines);
        expect(corrected, ['2 dl morot', '1 msk olja']);
      });
    });
  });
}
