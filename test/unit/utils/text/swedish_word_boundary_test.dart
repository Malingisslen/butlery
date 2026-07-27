/// Pins the two failure modes of Dart's ASCII `\b` on Swedish text that
/// [SwedishWordBoundary] exists to remove (BUT-1691).
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/utils/text/swedish_word_boundary.dart';

void main() {
  group('phantom boundary beside å/ä/ö', () {
    // These are the cases that made `\bl\b` and `\bst\b` fire inside ordinary
    // words: å/ä/ö are not ASCII word characters, so `\b` sees a word edge.
    const trapWords = ['kål', 'mjöl', 'öl', 'höst', 'råg'];

    test('ASCII \\b matches inside them (the bug being guarded against)', () {
      expect(RegExp(r'\bl\b').hasMatch('kål'), isTrue);
      expect(RegExp(r'\bl\b').hasMatch('mjöl'), isTrue);
      expect(RegExp(r'\bst\b').hasMatch('höst'), isTrue);
      expect(RegExp(r'\bg\b').hasMatch('råg'), isTrue);
    });

    test('the shared boundary does not', () {
      for (final unit in ['l', 'st', 'g']) {
        final re = SwedishWordBoundary.boundedRegExp(unit);
        for (final word in trapWords) {
          expect(re.hasMatch(word), isFalse, reason: '$unit in $word');
        }
      }
    });
  });

  group('missing boundary after å/ä/ö', () {
    test('ASCII \\b never fires after a Swedish vowel', () {
      // Assembled rather than written inline: `tools/check_swedish_boundary.sh`
      // rejects a literal \b touching å/ä/ö in any .dart file, and this test
      // needs the broken pattern in order to prove it is broken.
      final asciiBounded = RegExp('${r'\b'}två${r'\b'}');
      expect(asciiBounded.hasMatch('två middagar'), isFalse);
    });

    test('the shared boundary does', () {
      expect(
        SwedishWordBoundary.boundedRegExp('två').hasMatch('två middagar'),
        isTrue,
      );
    });
  });

  test('a standalone token still matches between separators', () {
    final re = SwedishWordBoundary.boundedRegExp('dl');
    expect(re.hasMatch('2 dl mjölk'), isTrue);
    expect(re.hasMatch('2dl mjölk'), isFalse, reason: 'digit continues a word');
    // "medlem", not "handduk": handduk contains no "dl" at all, so asserting
    // isFalse on it holds no matter what the boundary does.
    expect(re.hasMatch('medlem'), isFalse, reason: 'dl inside a word');
  });

  test('an alternation binds inside the boundaries, not around them', () {
    final re = SwedishWordBoundary.boundedRegExp('kvart|halvtimme');
    expect(re.hasMatch('en kvart'), isTrue);
    expect(re.hasMatch('en halvtimme'), isTrue);
    expect(re.hasMatch('kvartsfinal'), isFalse);
  });

  test('extraLetters widens the class without reordering semantics', () {
    final plain = SwedishWordBoundary.boundedRegExp('fil');
    final withAccent = SwedishWordBoundary.boundedRegExp(
      'fil',
      extraLetters: 'é',
    );
    // `é` is not an ASCII word character either, so without it in the class
    // the boundary treats "filé" as a bare "fil".
    expect(plain.hasMatch('lax filé'), isTrue);
    expect(withAccent.hasMatch('lax filé'), isFalse);
    expect(withAccent.hasMatch('2 dl fil'), isTrue);
  });

  // The character class is lowercase-only, so the ONE affordance that could
  // silently break it is compiling case-insensitively: if Dart did not apply
  // the flag inside the lookaround's class, an uppercase "KÅL" would sail past
  // the boundary the lowercase "kål" is stopped by. Callers that lowercase the
  // subject themselves never reach this; a caller matching raw OCR text does.
  test(
    'caseSensitive: false keeps the boundary intact for uppercase å/ä/ö',
    () {
      final re = SwedishWordBoundary.boundedRegExp('l', caseSensitive: false);
      expect(
        re.hasMatch('2 L Mjölk'),
        isTrue,
        reason: 'genuine standalone unit',
      );
      expect(
        re.hasMatch('KÅL'),
        isFalse,
        reason: 'Å must still continue a word',
      );
      expect(re.hasMatch('MJÖL'), isFalse);
    },
  );

  // Pinned against the LITERALS, not against the constants: comparing
  // `beforeWith('')` to `before` reduces to `before == before` and would pass
  // even if the shared constant were changed back to a bare ASCII `\b`, which
  // is the one thing this file exists to prevent.
  test('empty extraLetters yields the documented boundary literals', () {
    expect(SwedishWordBoundary.before, r'(?<![a-zåäö0-9])');
    expect(SwedishWordBoundary.after, r'(?![a-zåäö0-9])');
    expect(SwedishWordBoundary.beforeWith(''), r'(?<![a-zåäö0-9])');
    expect(SwedishWordBoundary.afterWith(''), r'(?![a-zåäö0-9])');
  });
}
