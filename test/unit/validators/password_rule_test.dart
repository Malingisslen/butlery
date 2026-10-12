import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/validators/password_rule.dart';

void main() {
  group('PasswordRule.accepts', () {
    test('twelve characters is enough, whatever they are', () {
      expect(PasswordRule.accepts('x' * 12), isTrue);
      expect(PasswordRule.accepts('x' * 11), isFalse);
    });

    test('three words are enough below twelve characters', () {
      // 11 characters: only the phrase path can accept it.
      expect('ab cd ef gh'.length, lessThan(PasswordRule.minLength));
      expect(PasswordRule.accepts('ab cd ef gh'), isTrue);
      expect(PasswordRule.accepts('ett två'), isFalse);
    });

    test('a phrase must reach the shortest length', () {
      expect(PasswordRule.accepts('abcd ef gh'), isTrue); // exactly 10
      expect(PasswordRule.accepts('abc de fg'), isFalse); // 9
      expect(PasswordRule.accepts('abcdef ghij'), isFalse); // two words
      expect(PasswordRule.accepts('a b c'), isFalse);
    });

    test('spaces around a phrase do not count towards its length', () {
      // Three words and ten characters before trimming, five after.
      expect(PasswordRule.accepts('   a b c  '), isFalse);
    });

    test('twelve blanks are not a password', () {
      expect(PasswordRule.accepts(' ' * 12), isFalse);
    });

    test('any run of whitespace separates words', () {
      expect(PasswordRule.accepts('ab\tcd \n ef'), isTrue);
    });

    test('å, ä and ö count as one character each', () {
      expect(PasswordRule.accepts('åäöåäöåäöåäö'), isTrue);
      expect(PasswordRule.accepts('åäöåäöåäöåä'), isFalse);
    });

    test('empty is refused', () {
      expect(PasswordRule.accepts(''), isFalse);
    });
  });
}
