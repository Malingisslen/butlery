// BUT-1891: the shopping quantity field discarded the decimal separator while
// the user typed, so "1,5 liter" was stored as 15 and the dialog's own
// comma-to-period parse could never be reached.
//
// The formatter and the parser are tested together because they are one round
// trip: the formatter decides what a field may contain, the parser has to read
// exactly that, and a rule added to one without the other is how the field
// silently falls back to its default amount.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/swedish_decimal_input.dart';

void main() {
  const formatter = SwedishDecimalInputFormatter();

  /// Types [next] into a field that already holds [previous], the way the
  /// framework does: the caret sits at the end of what was typed.
  String typed(String next, {String previous = ''}) => formatter
      .formatEditUpdate(
        TextEditingValue(
          text: previous,
          selection: TextSelection.collapsed(offset: previous.length),
        ),
        TextEditingValue(
          text: next,
          selection: TextSelection.collapsed(offset: next.length),
        ),
      )
      .text;

  group('SwedishDecimalInputFormatter', () {
    test('a comma survives — this is the whole defect', () {
      expect(typed('1,5'), '1,5');
    });

    test('a typed period is rewritten to a comma rather than refused', () {
      // Refusing it would be an invisible second rule for anyone whose keyboard
      // offers a period, and it would leave a period on screen in a Swedish UI.
      expect(typed('1.5'), '1,5');
    });

    test('only the first separator is kept', () {
      expect(typed('1,5,5'), '1,55');
      expect(typed('1.5.5'), '1,55');
      expect(typed('1,5.5'), '1,55');
    });

    test('a leading separator may be typed', () {
      expect(typed(',5'), ',5');
    });

    test('letters and spaces never reach the field', () {
      expect(typed('1,5 kg'), '1,5');
      expect(typed('abc'), '');
    });

    test('a whole number is untouched', () {
      expect(typed('2'), '2');
    });

    test('the caret lands after the characters that survived', () {
      // Typing 'x' in the middle of "15": the character is dropped, so the caret
      // stays where the KEPT characters put it rather than following the raw
      // offset. This case discriminates the naive strategy (take the incoming
      // offset, here 2) — it does NOT discriminate a length-delta strategy,
      // which happens to agree on this fixture. Said plainly because the first
      // version of this comment claimed it caught both.
      final result = formatter.formatEditUpdate(
        const TextEditingValue(
          text: '15',
          selection: TextSelection.collapsed(offset: 1),
        ),
        const TextEditingValue(
          text: '1x5',
          selection: TextSelection.collapsed(offset: 2),
        ),
      );
      expect(result.text, '15');
      expect(result.selection.baseOffset, 1);
    });
  });

  group('parseSwedishDecimal', () {
    test('reads both separators', () {
      expect(parseSwedishDecimal('1,5'), 1.5);
      expect(parseSwedishDecimal('1.5'), 1.5);
    });

    test('reads a leading separator as a leading zero', () {
      expect(parseSwedishDecimal(',5'), 0.5);
    });

    test('reads a trailing separator as a whole number', () {
      expect(parseSwedishDecimal('2,'), 2.0);
    });

    test('returns null rather than a default when there is no number', () {
      expect(parseSwedishDecimal(''), isNull);
      expect(parseSwedishDecimal('   '), isNull);
      expect(parseSwedishDecimal(','), isNull);
      // The two that discriminate the digit guard: `double.tryParse` accepts
      // both of these words. Delete the guard and these are the assertions
      // that redden; the empty/blank/comma cases above stay green without it.
      expect(parseSwedishDecimal('Infinity'), isNull);
      expect(parseSwedishDecimal('NaN'), isNull);
    });

    test('surrounding whitespace is not an error', () {
      expect(parseSwedishDecimal('  1,5  '), 1.5);
    });
  });

  group('formatSwedishDecimal', () {
    test('a whole number carries no decimals', () {
      expect(formatSwedishDecimal(2), '2');
      expect(formatSwedishDecimal(10), '10');
      expect(formatSwedishDecimal(0), '0');
    });

    test('a fraction is written with a comma', () {
      expect(formatSwedishDecimal(1.5), '1,5');
      expect(formatSwedishDecimal(0.001), '0,001');
    });

    test('what it writes, the parser reads back unchanged', () {
      for (final amount in <double>[0, 1, 1.5, 0.5, 2.25, 999999.99]) {
        expect(
          parseSwedishDecimal(formatSwedishDecimal(amount)),
          amount,
          reason: 'round trip must hold for $amount',
        );
      }
    });

    test('an ordinary shopping quantity is typeable back into the field', () {
      // format -> FIELD -> parse is the trip production takes: the edit dialog
      // seeds the controller from `formatSwedishDecimal` and reads it back
      // through the formatter. A seeded value that its own formatter mangles
      // shows the user a number they cannot retype.
      //
      // Scoped to ordinary quantities on purpose — the universal version of
      // this claim is false, and the pair below is where it breaks.
      for (final amount in <double>[1.5, 0.5, 2.25]) {
        final written = formatSwedishDecimal(amount);
        expect(typed(written), written);
      }
    });

    test('a non-finite amount is described, not thrown on', () {
      // `round()` throws on infinity, and this function seeds the edit dialog's
      // field — so before the guard the throw landed during a build. A pasted
      // ~309-digit quantity is all it takes for `double.tryParse` to hand back
      // infinity.
      //
      // The two infinity lines discriminate the guard: delete it and `round()`
      // throws on both. The NaN line does NOT — NaN reaches the guard as well
      // (`isFinite` is false for NaN), and without the guard it would reach the
      // fraction branch instead and print the same "NaN", so it passes either
      // way. Kept as a behaviour pin, not as coverage of the guard.
      expect(formatSwedishDecimal(double.infinity), 'Infinity');
      expect(formatSwedishDecimal(double.negativeInfinity), '-Infinity');
      expect(formatSwedishDecimal(double.nan), 'NaN');
    });

    test('the round trip holds at 1e-6 and breaks below it (BUT-1912)', () {
      // The measured flip, straddled. `0,000001` is decimal notation and
      // survives; `9.99e-7` is written in exponent notation, and the formatter
      // keeps only digits and one separator — so it eats the `e` and the `-`
      // and the value comes back eight orders of magnitude high.
      //
      // The parser is NOT at fault: `double.tryParse` reads both correctly. It
      // is the field that loses the value, which is where BUT-1912's fix has to
      // land. This case reddens when that ships — deliberately, as the receipt.
      expect(typed(formatSwedishDecimal(1e-6)), '0,000001');
      expect(parseSwedishDecimal(formatSwedishDecimal(1e-6)), 1e-6);

      expect(
        parseSwedishDecimal(formatSwedishDecimal(5e-7)),
        5e-7,
        reason: 'the parser alone round-trips fine',
      );
      expect(
        typed(formatSwedishDecimal(5e-7)),
        '57',
        reason:
            'the FIELD is what destroys it — pinned so the fix is aimed '
            'at the right component',
      );
    });
  });
}
