import 'dart:convert';

import 'package:butlery/services/parsing/_expected_model_hashes.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('verifyModelBytes (BUT-792)', () {
    // Derive the canonical hash via the same code path under test so the
    // tamper assertion is always self-consistent across crypto-package
    // version drift.
    final canonicalBytes = utf8.encode('butlery-test-onnx-bytes-v1');
    final canonicalHash = verifyModelBytes(
      modelBytes: canonicalBytes,
      version: 0,
      hashRegistry: const <int, String>{},
    ).actualHash;

    test('returns unverified=true when no hash is registered', () {
      final bytes = utf8.encode('butlery-test-onnx-bytes-v1');
      final result = verifyModelBytes(
        modelBytes: bytes,
        version: 99,
        hashRegistry: const <int, String>{},
      );

      expect(
        result.ok,
        isTrue,
        reason:
            'Pure result reports unverified via the flag, not ok=false '
            '— policy lives in verifyModelDownload, which since BUT-877 '
            'refuses unverified loads (fail-close).',
      );
      expect(result.unverified, isTrue);
      expect(result.expectedHash, isNull);
      expect(result.actualHash, hasLength(64));
    });

    test('returns ok=true when bytes match the registered hash', () {
      final result = verifyModelBytes(
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

      final result = verifyModelBytes(
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

  group('hash-format guard (BUT-827)', () {
    final hexSha256 = RegExp(r'^[0-9a-f]{64}$');

    test('every kExpectedNerModelHashes entry is 64 lowercase hex chars', () {
      for (final entry in kExpectedNerModelHashes.entries) {
        expect(
          hexSha256.hasMatch(entry.value),
          isTrue,
          reason:
              'kExpectedNerModelHashes[v${entry.key}] = "${entry.value}" '
              'must be 64 lowercase hex chars (SHA-256). A typo, uppercase, '
              'or whitespace would silently turn a real mismatch into '
              '`unverified` because the registry lookup would never match.',
        );
      }
    });

    test(
      'every kExpectedLineClassifierModelHashes entry is 64 lowercase hex chars',
      () {
        for (final entry in kExpectedLineClassifierModelHashes.entries) {
          expect(
            hexSha256.hasMatch(entry.value),
            isTrue,
            reason:
                'kExpectedLineClassifierModelHashes[v${entry.key}] = '
                '"${entry.value}" must be 64 lowercase hex chars (SHA-256).',
          );
        }
      },
    );
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
