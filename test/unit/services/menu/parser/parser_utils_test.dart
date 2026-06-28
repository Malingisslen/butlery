/// Direct unit tests for the parser_utils helpers (BUT-1149 coverage burndown —
/// previously zero direct coverage).
///
/// Pure low-level scanning + lexicon-lookup helpers shared by the menu-constraint
/// parser sub-modules. No mocks, no IO. The fuzzy-lookup chain (exact →
/// diacritic-stripped → Levenshtein≤1) is the interesting behavior — the rest are
/// small scanners whose edge cases (empty, out-of-range, non-word chars) are what
/// a parser actually trips over.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/services/menu/parser/parser_utils.dart';

void main() {
  group('skipSpaces', () {
    test('advances past a run of spaces to the first non-space', () {
      expect(skipSpaces('   abc', 0), 3);
    });

    test('returns the start index when there is no leading space', () {
      expect(skipSpaces('abc', 0), 0);
    });

    test('an all-spaces tail returns the string length', () {
      expect(skipSpaces('ab   ', 2), 5);
    });
  });

  group('readWord', () {
    test('reads a lowercase Swedish word from the given offset', () {
      expect(readWord('  kyckling', 2), 'kyckling');
    });

    test('reads Swedish diacritic letters as part of the word', () {
      expect(readWord('kött', 0), 'kött');
    });

    test('stops at the first non-letter', () {
      expect(readWord('ris och bönor', 0), 'ris');
    });

    test('returns null when the offset is not on a lowercase letter', () {
      expect(readWord('123', 0), isNull);
      expect(readWord('Kyckling', 0), isNull); // regex is lowercase-only
    });
  });

  group('isWordChar', () {
    test('true for ASCII letters, digits and the Swedish vowels', () {
      for (final c in ['a', 'z', 'A', 'Z', '0', '9', 'å', 'ä', 'ö']) {
        expect(isWordChar(c.codeUnitAt(0)), isTrue, reason: c);
      }
    });

    test('false for separators and punctuation', () {
      for (final c in [' ', '-', ',', '.', '/']) {
        expect(isWordChar(c.codeUnitAt(0)), isFalse, reason: c);
      }
    });
  });

  group('lexiconLookup', () {
    const map = {
      'kyckling': 'chicken',
      'kott': 'meat', // stored already diacritic-stripped
      'vegansk': 'vegan',
    };

    test('exact match wins', () {
      expect(lexiconLookup('kyckling', map), 'chicken');
    });

    test('falls back to the diacritic-stripped form', () {
      // 'kött' has no exact entry; stripped → 'kott' hits the map.
      expect(lexiconLookup('kött', map), 'meat');
    });

    test('falls back to a Levenshtein-1 match for long-enough tokens', () {
      // 'vagansk' is one substitution from 'vegansk' (length ≥ 6).
      expect(lexiconLookup('vagansk', map), 'vegan');
    });

    test('returns null when nothing matches', () {
      expect(lexiconLookup('xyz', map), isNull);
    });
  });
}
