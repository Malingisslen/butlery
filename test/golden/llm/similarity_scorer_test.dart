// BUT-889 — unit tests for the deterministic lexical similarity scorer.
//
// These pin the contract of [lexicalSimilarity] (character-trigram cosine):
// identical → 1.0, disjoint → ~0, partial overlap strictly between, and
// case/whitespace/punctuation insensitivity. Determinism matters: golden
// regression tests rely on these scores being reproducible offline, so the
// metric must never reach for a network/embedding API.

import 'package:flutter_test/flutter_test.dart';

import '_golden_runner.dart';

void main() {
  group('lexicalSimilarity', () {
    test('identical strings score exactly 1.0', () {
      expect(
        lexicalSimilarity('tomatsås med basilika', 'tomatsås med basilika'),
        1.0,
      );
    });

    test('empty vs empty scores 1.0', () {
      expect(lexicalSimilarity('', ''), 1.0);
    });

    test('empty vs non-empty scores 0.0', () {
      expect(lexicalSimilarity('', 'ris'), 0.0);
      expect(lexicalSimilarity('ris', ''), 0.0);
    });

    test('totally different strings score near 0', () {
      final score = lexicalSimilarity('mjölk', 'potatisgratäng');
      expect(score, lessThan(0.1));
    });

    test('disjoint short words with no shared trigrams score 0.0', () {
      expect(lexicalSimilarity('abc', 'xyz'), 0.0);
    });

    test('partial overlap scores strictly between 0 and 1', () {
      final score = lexicalSimilarity('smör', 'smöret');
      expect(score, greaterThan(0.0));
      expect(score, lessThan(1.0));
    });

    test('partial overlap exceeds disjoint pair', () {
      final overlap = lexicalSimilarity('löken', 'lök');
      final disjoint = lexicalSimilarity('löken', 'ris');
      expect(overlap, greaterThan(disjoint));
    });

    test('case-insensitive: differs only by case → 1.0', () {
      expect(lexicalSimilarity('Tomatsås', 'tomatsås'), 1.0);
      expect(lexicalSimilarity('MJÖLK', 'mjölk'), 1.0);
    });

    test('whitespace-insensitive: collapses runs and trims', () {
      expect(
        lexicalSimilarity('  två   dl   mjölk ', 'två dl mjölk'),
        1.0,
      );
    });

    test('punctuation-insensitive: strips punctuation before comparing', () {
      expect(lexicalSimilarity('mjölk, smör!', 'mjölk smör'), 1.0);
    });

    test('result is bounded in [0,1]', () {
      for (final pair in const [
        ['', ''],
        ['a', 'a'],
        ['abc', 'xyz'],
        ['smör', 'smöret'],
        ['en lång svensk mening', 'en helt annan mening här'],
      ]) {
        final score = lexicalSimilarity(pair[0], pair[1]);
        expect(score, inInclusiveRange(0.0, 1.0));
      }
    });

    test('deterministic: same inputs yield identical score across calls', () {
      final a = lexicalSimilarity('basilika och tomat', 'tomat och basilika');
      final b = lexicalSimilarity('basilika och tomat', 'tomat och basilika');
      expect(a, b);
    });
  });

  group('scoreCase with similarity tolerance', () {
    test('identical actual/expected passes', () {
      final c = GoldenCase(
        id: 'sim-1',
        input: 'x',
        expected: 'tomatsås med basilika',
        tolerance: 'similarity',
      );
      final result = scoreCase(c, 'tomatsås med basilika');
      expect(result.passed, isTrue);
      expect(result.failureReason, isNull);
    });

    test('disjoint actual/expected fails with a similarity reason', () {
      final c = GoldenCase(
        id: 'sim-2',
        input: 'x',
        expected: 'mjölk',
        tolerance: 'similarity',
      );
      final result = scoreCase(c, 'potatisgratäng');
      expect(result.passed, isFalse);
      expect(result.failureReason, contains('similarity='));
    });
  });
}
