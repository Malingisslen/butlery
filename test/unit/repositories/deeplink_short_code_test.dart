import 'dart:math';

import 'package:flutter_test/flutter_test.dart';

/// Tests for the short code generation algorithm used in
/// FirebaseDeepLinkRepository._generateShortCode().
///
/// Since the method is private, we test the same algorithm directly
/// to verify the Random.secure() approach produces unique, valid codes.
void main() {
  group('Short code generation (Random.secure)', () {
    late Random secureRandom;

    setUp(() {
      secureRandom = Random.secure();
    });

    String generateShortCode() {
      const chars =
          'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
      final buffer = StringBuffer();
      for (int i = 0; i < 8; i++) {
        buffer.write(chars[secureRandom.nextInt(chars.length)]);
      }
      return buffer.toString();
    }

    test('generates 8-character alphanumeric codes', () {
      final validChars = RegExp(r'^[a-zA-Z0-9]{8}$');
      for (int i = 0; i < 10; i++) {
        expect(generateShortCode(), matches(validChars));
      }
    });

    test('two sequential calls produce different results', () {
      final code1 = generateShortCode();
      final code2 = generateShortCode();
      expect(code1, isNot(equals(code2)),
          reason:
              'With 62^8 possible codes, collision is astronomically unlikely');
    });

    test('20 sequential calls produce all unique codes', () {
      final codes = <String>{};
      for (int i = 0; i < 20; i++) {
        codes.add(generateShortCode());
      }
      expect(codes.length, equals(20));
    });
  });
}
