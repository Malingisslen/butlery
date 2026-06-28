/// Direct unit tests for [FieldResult] + [ParseConfidence] (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// Per-field parse result with confidence tracking — the basis for smart tier
/// merging and targeted LLM patching. Covers the confidence score/needsReview
/// extension, every named factory, the score→level thresholds in
/// fromConfidenceScore, the value/review getters, generic JSON (de)serialization
/// with a value converter, and value+confidence+reason equality.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/parsing/field_result.dart';

void main() {
  group('ParseConfidence extension', () {
    test('score maps each level', () {
      expect(ParseConfidence.high.score, 1.0);
      expect(ParseConfidence.medium.score, 0.7);
      expect(ParseConfidence.low.score, 0.3);
      expect(ParseConfidence.failed.score, 0.0);
    });

    test('needsReview is true for low + failed only', () {
      expect(ParseConfidence.high.needsReview, isFalse);
      expect(ParseConfidence.medium.needsReview, isFalse);
      expect(ParseConfidence.low.needsReview, isTrue);
      expect(ParseConfidence.failed.needsReview, isTrue);
    });
  });

  group('named factories', () {
    test('success / uncertain / low / failed set the right level', () {
      expect(FieldResult.success('v').confidence, ParseConfidence.high);
      expect(FieldResult.uncertain('v').confidence, ParseConfidence.medium);
      final low = FieldResult.low('v', reason: 'iffy');
      expect(low.confidence, ParseConfidence.low);
      expect(low.failureReason, 'iffy');
      final failed = FieldResult<String>.failed('nope');
      expect(failed.confidence, ParseConfidence.failed);
      expect(failed.value, isNull);
      expect(failed.failureReason, 'nope');
    });
  });

  group('fromConfidenceScore thresholds', () {
    FieldResult<String> r(double s) =>
        FieldResult.fromConfidenceScore<String>('v', s, 'jsonld');

    test('≥0.7 → high (success)', () {
      expect(r(0.8).confidence, ParseConfidence.high);
    });

    test('≥0.5 → medium with source reason', () {
      final m = r(0.6);
      expect(m.confidence, ParseConfidence.medium);
      expect(m.failureReason, 'Parsed via jsonld');
    });

    test('≥0.3 → low (some unstructured)', () {
      final l = r(0.4);
      expect(l.confidence, ParseConfidence.low);
      expect(l.failureReason, contains('some items unstructured'));
    });

    test('<0.3 → low (most unstructured)', () {
      final l = r(0.1);
      expect(l.confidence, ParseConfidence.low);
      expect(l.failureReason, contains('most items unstructured'));
    });
  });

  group('getters', () {
    test('hasValue / needsReview / confidenceScore', () {
      final ok = FieldResult.success('v');
      expect(ok.hasValue, isTrue);
      expect(ok.needsReview, isFalse);
      expect(ok.confidenceScore, 1.0);

      final bad = FieldResult<String>.failed('x');
      expect(bad.hasValue, isFalse);
      expect(bad.needsReview, isTrue);
      expect(bad.confidenceScore, 0.0);
    });
  });

  group('JSON', () {
    test('toJson carries confidence name and omits null failureReason', () {
      final json = FieldResult.success('v').toJson();
      expect(json['value'], 'v');
      expect(json['confidence'], 'high');
      expect(json.containsKey('failureReason'), isFalse);
    });

    test('toJson applies the value converter', () {
      final json = FieldResult<int>.success(5).toJson((v) => v.toString());
      expect(json['value'], '5');
    });

    test('fromJson round-trips with a value converter', () {
      final restored = FieldResult.fromJson(
        {'value': '5', 'confidence': 'high'},
        (v) => int.parse(v as String),
      );
      expect(restored.value, 5);
      expect(restored.confidence, ParseConfidence.high);
    });

    test('fromJson falls back to medium for an unknown confidence', () {
      final restored = FieldResult.fromJson(
        {'value': 'v', 'confidence': 'bogus'},
        (v) => v as String,
      );
      expect(restored.confidence, ParseConfidence.medium);
    });
  });

  group('equality', () {
    test('is by value + confidence + failureReason', () {
      expect(FieldResult.success('v'), equals(FieldResult.success('v')));
      expect(
        FieldResult.success('v') == FieldResult.uncertain('v'),
        isFalse,
      );
    });
  });
}
