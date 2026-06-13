/// BUT-1053: per-provider OCR language-hint mapping from the active UI locale.
///
/// Pins that each provider's helper maps locale → its own code convention,
/// puts the user's locale FIRST, and retains a fallback language for
/// bilingual robustness (no single-language regression).
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/ocr_extraction_service.dart';

void main() {
  group('OCR provider language hints (BUT-1053)', () {
    group('ocrSpaceLanguage (ISO 639-2, single code)', () {
      test('sv → swe', () {
        expect(OCRExtractionService.ocrSpaceLanguage('sv'), 'swe');
      });
      test('en → eng', () {
        expect(OCRExtractionService.ocrSpaceLanguage('en'), 'eng');
      });
      test('unknown locale falls back to eng', () {
        expect(OCRExtractionService.ocrSpaceLanguage('de'), 'eng');
      });
      test('regional locale en_US strips region → eng (not the sv default)',
          () {
        expect(OCRExtractionService.ocrSpaceLanguage('en_US'), 'eng');
        expect(OCRExtractionService.ocrSpaceLanguage('en-GB'), 'eng');
      });
    });

    group('googleVisionLanguageHints (ISO 639-1 array, user-locale first)', () {
      test('sv → [sv, en] (user locale first, fallback retained)', () {
        expect(
            OCRExtractionService.googleVisionLanguageHints('sv'), ['sv', 'en']);
      });
      test('en → [en, sv] (user locale first, fallback retained)', () {
        expect(
            OCRExtractionService.googleVisionLanguageHints('en'), ['en', 'sv']);
      });
      test('unknown locale → [sv, en] (Swedish-first default, both retained)',
          () {
        expect(
            OCRExtractionService.googleVisionLanguageHints('de'), ['sv', 'en']);
      });
      test('regional locale en_US strips region → [en, sv] (English-first)',
          () {
        expect(OCRExtractionService.googleVisionLanguageHints('en_US'),
            ['en', 'sv']);
      });
    });

    group("tesseractLanguage ('+'-joined ISO 639-2, user-locale first)", () {
      test('sv → swe+eng', () {
        expect(OCRExtractionService.tesseractLanguage('sv'), 'swe+eng');
      });
      test('en → eng+swe (user locale first)', () {
        expect(OCRExtractionService.tesseractLanguage('en'), 'eng+swe');
      });
      test('unknown locale → swe+eng (Swedish-first default)', () {
        expect(OCRExtractionService.tesseractLanguage('de'), 'swe+eng');
      });
      test('regional locale en_US strips region → eng+swe (English-first)', () {
        expect(OCRExtractionService.tesseractLanguage('en_US'), 'eng+swe');
      });
    });
  });
}
