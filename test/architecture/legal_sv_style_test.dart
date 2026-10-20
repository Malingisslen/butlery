/// The Swedish legal texts follow the content style guide: no emoji in system
/// text, en dash as the dash, Swedish quotation marks and no exclamation marks.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final emoji = RegExp(
    '[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}\u{2B50}]',
    unicode: true,
  );

  for (final name in [
    'privacy_policy',
    'terms_of_service',
    'community_guidelines',
  ]) {
    test('${name}_sv.md keeps to the Swedish text style', () {
      final text = File('assets/legal/${name}_sv.md').readAsStringSync();

      expect(emoji.hasMatch(text), isFalse, reason: 'no emoji in system text');
      expect(text.contains('—'), isFalse, reason: 'em dash; use the en dash');
      expect(text.contains('"'), isFalse, reason: 'straight quotes; use ”…”');
      expect(text.contains('!'), isFalse, reason: 'no exclamation marks');
    });
  }

  test('the privacy policy names the anonymous daily channel count', () {
    final sv = File('assets/legal/privacy_policy_sv.md').readAsStringSync();
    final en = File('assets/legal/privacy_policy_en.md').readAsStringSync();

    expect(sv, contains('helt anonymt och per dag'));
    expect(sv, contains('Anonym kanalräkning per dag'));
    expect(en, contains('Count, anonymously and per day'));
    expect(en, contains('Anonymous daily channel count'));
  });

  test('the privacy policy names the temporary storage of unsent photos', () {
    final sv = File('assets/legal/privacy_policy_sv.md').readAsStringSync();
    final en = File('assets/legal/privacy_policy_en.md').readAsStringSync();

    expect(sv, contains('Matbilder som väntar på att skickas'));
    expect(sv, contains('slängs automatiskt efter 30 dagar'));
    expect(en, contains('Food photos waiting to be sent'));
    expect(en, contains('thrown away automatically after 30 days'));
  });
}
