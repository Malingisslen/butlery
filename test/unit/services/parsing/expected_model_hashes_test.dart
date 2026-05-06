import 'dart:convert';

import 'package:butlery/services/parsing/_expected_model_hashes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('verifyOnnxBytes (BUT-792)', () {
    // Derive the canonical hash via the same code path under test so the
    // tamper assertion is always self-consistent across crypto-package
    // version drift.
    final canonicalBytes = utf8.encode('butlery-test-onnx-bytes-v1');
    final canonicalHash = verifyOnnxBytes(
      modelBytes: canonicalBytes,
      version: 0,
      hashRegistry: const <int, String>{},
    ).actualHash;

    test('returns unverified=true when no hash is registered', () {
      final bytes = utf8.encode('butlery-test-onnx-bytes-v1');
      final result = verifyOnnxBytes(
        modelBytes: bytes,
        version: 99,
        hashRegistry: const <int, String>{},
      );

      expect(result.ok, isTrue,
          reason:
              'Unverified bytes still pass during transitional rollout, but a '
              'non-fatal Crashlytics event must surface the gap.');
      expect(result.unverified, isTrue);
      expect(result.expectedHash, isNull);
      expect(result.actualHash, hasLength(64));
    });

    test('returns ok=true when bytes match the registered hash', () {
      final result = verifyOnnxBytes(
        modelBytes: canonicalBytes,
        version: 1,
        hashRegistry: <int, String>{1: canonicalHash},
      );

      expect(result.ok, isTrue);
      expect(result.unverified, isFalse);
      expect(result.actualHash, equals(canonicalHash));
    });

    test('returns ok=false with both hashes when bytes are tampered', () {
      // Register the canonical hash for v1, then feed tampered bytes —
      // the actual hash must differ from the expected one.
      final tamperedBytes = utf8.encode('butlery-test-onnx-bytes-v1-TAMPERED');

      final result = verifyOnnxBytes(
        modelBytes: tamperedBytes,
        version: 1,
        hashRegistry: <int, String>{1: canonicalHash},
      );

      expect(result.ok, isFalse);
      expect(result.expectedHash, equals(canonicalHash));
      expect(result.actualHash, isNot(equals(canonicalHash)));
      expect(result.actualHash, hasLength(64));
    });
  });

  group('ModelIntegrityCheckFailure', () {
    test('toString includes model name, version, and both hashes', () {
      const failure = ModelIntegrityCheckFailure(
        modelName: 'ingredient_ner',
        version: 3,
        expected: 'aaa',
        actual: 'bbb',
      );
      final s = failure.toString();
      expect(s, contains('ingredient_ner'));
      expect(s, contains('v3'));
      expect(s, contains('aaa'));
      expect(s, contains('bbb'));
    });
  });
}
