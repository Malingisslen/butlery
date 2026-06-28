/// Direct unit tests for [ExtractedContentAnalyzer] (BUT-1149 coverage burndown
/// — previously zero direct coverage).
///
/// Pure scoring heuristic over extracted import text (extracted from
/// UrlImportViewModel in BUT-1273). Tests assert the deterministic score +
/// quality bucket and the shape of the issues/positives lists; they do NOT
/// assert the localized issue/positive strings themselves (brittle + locale
/// dependent), only that the right number appear.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/import/extracted_content_analyzer.dart';

/// Pad a seed string with neutral filler (no scoring keywords) to a target
/// length, so length-based scoring is controlled independently of keywords.
String _pad(String seed, int toLength) {
  if (seed.length >= toLength) return seed;
  return seed + ('x' * (toLength - seed.length));
}

void main() {
  group('ExtractedContentAnalyzer.analyze', () {
    test('null or empty text → quality "none", score 0, one issue', () {
      for (final input in <String?>[null, '']) {
        final r = ExtractedContentAnalyzer.analyze(input);
        expect(r['quality'], 'none');
        expect(r['score'], 0);
        expect((r['issues'] as List), hasLength(1));
      }
    });

    test('all indicators + long content → score 100, excellent', () {
      // ingrediens(+25) instruktion(+25) minut(+15) portion(+10) recept(+10)
      // length>500(+15) = 100.
      final text = _pad(
        'ingrediens instruktion minut portion recept ',
        600,
      );
      final r = ExtractedContentAnalyzer.analyze(text);
      expect(r['score'], 100);
      expect(r['quality'], 'excellent');
      expect((r['issues'] as List), isEmpty);
      expect((r['positives'] as List), isNotEmpty);
    });

    test('ingredients + instructions, neutral length → score 50, good', () {
      // 25 + 25, length in 200..500 so neither bonus nor too-short.
      final text = _pad('ingredient instruction ', 300);
      final r = ExtractedContentAnalyzer.analyze(text);
      expect(r['score'], 50);
      expect(r['quality'], 'good');
    });

    test('ingredients only, neutral length → score 25, fair, flags missing '
        'instructions', () {
      final text = _pad('ingredient ', 300);
      final r = ExtractedContentAnalyzer.analyze(text);
      expect(r['score'], 25);
      expect(r['quality'], 'fair');
      // At least the "no instructions found" issue is present.
      expect((r['issues'] as List), isNotEmpty);
    });

    test('no recipe indicators, neutral length → score 0, poor, multiple '
        'issues', () {
      final text = _pad('lorem ', 300); // no keywords
      final r = ExtractedContentAnalyzer.analyze(text);
      expect(r['score'], 0);
      expect(r['quality'], 'poor');
      // Missing ingredients AND missing instructions.
      expect((r['issues'] as List).length, greaterThanOrEqualTo(2));
    });

    test('short content adds a too-short issue', () {
      final r = ExtractedContentAnalyzer.analyze('tiny'); // < 200 chars
      expect((r['issues'] as List), isNotEmpty);
      // No length bonus, no keywords → poor.
      expect(r['quality'], 'poor');
    });

    test('keyword matching is case-insensitive', () {
      final text = _pad('INGREDIENT INSTRUCTION ', 300);
      final r = ExtractedContentAnalyzer.analyze(text);
      expect(r['score'], 50); // matched despite uppercase
    });

    test('long content with no keywords still gets the length bonus only', () {
      final text = _pad('lorem ', 600); // >500, no keywords
      final r = ExtractedContentAnalyzer.analyze(text);
      expect(r['score'], 15); // length bonus only
      expect(r['quality'], 'poor'); // 15 < 25
    });
  });
}
