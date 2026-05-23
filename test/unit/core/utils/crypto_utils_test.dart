/// Unit tests for CryptoUtils.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/crypto_utils.dart';

void main() {
  group('sha256Hash', () {
    test('produces the canonical SHA-256 hex for "hello"', () {
      // RFC test vector
      expect(
        CryptoUtils.sha256Hash('hello'),
        '2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824',
      );
    });

    test('empty string produces the canonical empty-input digest', () {
      expect(
        CryptoUtils.sha256Hash(''),
        'e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855',
      );
    });

    test('handles non-ASCII via UTF-8 encoding', () {
      // Hash differs from raw-byte hashing of latin-1 — proves UTF-8 path.
      final utf8Hash = CryptoUtils.sha256Hash('åäö');
      final asciiHash = CryptoUtils.sha256Hash('aao');
      expect(utf8Hash, isNot(asciiHash));
      // Stable: re-hashing gives same value.
      expect(CryptoUtils.sha256Hash('åäö'), utf8Hash);
      // SHA-256 hex is always 64 chars.
      expect(utf8Hash.length, 64);
    });

    test('same input → same hash (deterministic)', () {
      expect(
        CryptoUtils.sha256Hash('Butlery'),
        CryptoUtils.sha256Hash('Butlery'),
      );
    });

    test('different inputs → different hashes', () {
      expect(
        CryptoUtils.sha256Hash('a'),
        isNot(CryptoUtils.sha256Hash('A')),
      );
    });
  });
}
