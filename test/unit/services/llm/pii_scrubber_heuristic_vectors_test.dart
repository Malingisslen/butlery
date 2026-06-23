/// BUT-694: cross-port contract test for the Swedish street-address +
/// person-name PII heuristics.
///
/// The vector file is a byte-identical COPY of the source of truth at
/// functions/src/__tests__/fixtures/pii-heuristic-vectors.json (next to the
/// TS implementation's HEURISTIC CONTRACT block). The copy is the sync
/// mechanism: if the rules change, the TS side updates the vectors and this
/// file is re-copied. Every vector runs — full-string equality, no
/// handpicking — so a regex-semantics divergence between the ports fails
/// loudly here.
library;

import 'dart:convert';
import 'dart:io';

import 'package:butlery/services/llm/pii_scrubber.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('scrubPii - BUT-694 heuristic vectors (shared with TS port)', () {
    final file = File(
      'test/unit/services/llm/fixtures/pii-heuristic-vectors.json',
    );
    final fixture = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
    final vectors = (fixture['vectors'] as List).cast<Map<String, dynamic>>();

    test('fixture contains the full 28-vector contract', () {
      expect(vectors, hasLength(28));
    });

    test('fixture is a byte-identical copy of the TS source of truth', () {
      // The copy convention is the sync mechanism between the ports; this
      // pin turns silent content drift (same count, edited vector) into a
      // loud failure. Both files live in this repo, so compare bytes.
      final source = File(
        'functions/src/__tests__/fixtures/pii-heuristic-vectors.json',
      );
      expect(
        file.readAsBytesSync(),
        equals(source.readAsBytesSync()),
        reason:
            'Dart fixture copy has drifted from the TS source of truth — '
            're-copy functions/src/__tests__/fixtures/pii-heuristic-vectors.json',
      );
    });

    for (final vector in vectors) {
      test(vector['name'] as String, () {
        final input = vector['input'] as String;
        final expected = vector['expected'] as String;
        expect(scrubPii(input), equals(expected));
      });
    }
  });
}
