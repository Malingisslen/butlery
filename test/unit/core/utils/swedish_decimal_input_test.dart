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
      // Scoped to ordinary quantities on purpose. The universal version of the
      // claim is still false: an amount past the field's digit bound is shown
      // in full and cannot be retyped as it stands.
      for (final amount in <double>[1.5, 0.5, 2.25]) {
        final written = formatSwedishDecimal(amount);
        expect(typed(written), written);
      }
    });

    test('a non-finite amount is described, not thrown on', () {
      // Neither value has a digit spelling, and this function seeds a field
      // that opens with the amount already in it, so whatever happens here
      // happens while the dialog is building.
      //
      // These three lines pin the behaviour, not the guard: since BUT-1912 the
      // branches below the guard no longer throw on a non-finite amount, they
      // just answer by accident. The guard is what makes the answer deliberate.
      expect(formatSwedishDecimal(double.infinity), 'Infinity');
      expect(formatSwedishDecimal(double.negativeInfinity), '-Infinity');
      expect(formatSwedishDecimal(double.nan), 'NaN');
    });

    test('no amount is ever written in exponent notation (BUT-1912)', () {
      // The contract, stated over both ends of `toString()`'s decimal range.
      // The formatter keeps only digits and one separator, so an `e` or a `-`
      // in what this function emits is eaten by the field the value is about to
      // be shown in — which is how `5e-7` came back out of it as `57`.
      for (final amount in <double>[
        5e-7,
        9.99e-7,
        1e-320,
        1e21,
        1e30,
        double.maxFinite,
        -5e-7,
        -1e21,
      ]) {
        expect(
          formatSwedishDecimal(amount),
          isNot(contains('e')),
          reason: '$amount was written in exponent notation',
        );
      }
    });

    test(
      'a huge amount keeps its magnitude instead of saturating (BUT-1912)',
      () {
        // `round()` used to spell these and it saturates at int64: 1e21 was
        // written as 9223372036854775807, a plausible-looking number two orders
        // of magnitude off, and 1e30 as the identical string.
        expect(formatSwedishDecimal(1e21), '1000000000000000000000');
        expect(formatSwedishDecimal(1e19), '10000000000000000000');
        expect(formatSwedishDecimal(1.5e21), '1500000000000000000000');
        expect(formatSwedishDecimal(-1e21), '-1000000000000000000000');
        expect(
          formatSwedishDecimal(1e30),
          isNot(formatSwedishDecimal(1e21)),
          reason: 'saturation made every large amount print the same digits',
        );
      },
    );

    test('a tiny amount survives the FIELD, not just the parser (BUT-1912)', () {
      // format -> FIELD -> parse is the trip production takes, and the field is
      // the leg that used to destroy it. `0,000001` always survived; below that
      // the value was rewritten by orders of magnitude.
      expect(formatSwedishDecimal(5e-7), '0,0000005');
      expect(typed(formatSwedishDecimal(5e-7)), '0,0000005');
      expect(parseSwedishDecimal(typed(formatSwedishDecimal(5e-7))), 5e-7);

      expect(typed(formatSwedishDecimal(1e-6)), '0,000001');
      expect(parseSwedishDecimal(formatSwedishDecimal(1e-6)), 1e-6);
    });

    test('an amount rounded away entirely is written as a plain zero', () {
      // 20 decimals is as deep as `toStringAsFixed` goes. "-0" is a worse
      // answer than "0" and neither is the amount, so it says the one a reader
      // can act on. The NEGATIVE fixtures are the load-bearing ones: `1e-320`
      // returns '0' with or without the guard, only `-1e-320` discriminates it.
      expect(formatSwedishDecimal(1e-320), '0');
      expect(formatSwedishDecimal(-1e-320), '0');
      expect(formatSwedishDecimal(-0.0), '0');
    });

    test('the zero floor straddled, and it is ROUNDING not truncation', () {
      // Measured 2026-08-25, because the comment here first named 1e-20 and
      // that was wrong by 2x. `toStringAsFixed(20)` rounds, so 9e-21 rounds UP
      // into the last place it can spell and 5e-21 is the first to vanish.
      expect(formatSwedishDecimal(9e-21), '0,00000000000000000001');
      expect(formatSwedishDecimal(5e-21), '0');
    });

    test('a 1e-20 amount still fits the field', () {
      // An exact tie that nothing else asserts: the deep branch spells 20
      // fraction digits via `toStringAsFixed(20)` and the field's bound is 20.
      // Drop the bound to 19 and a seeded amount stops being typeable back,
      // which is the BUT-1912 defect class returning.
      final written = formatSwedishDecimal(1e-20);
      expect(written, '0,00000000000000000001');
      expect(typed(written), written);
      expect(parseSwedishDecimal(typed(written)), 1e-20);
    });

    test('the one shape format -> parse does NOT round-trip', () {
      // Stated so the asymmetry is deliberate rather than incidental: a
      // non-finite amount is spelled with letters, and the parser's digit
      // guard then refuses its own output.
      expect(formatSwedishDecimal(double.infinity), 'Infinity');
      expect(
        parseSwedishDecimal(formatSwedishDecimal(double.infinity)),
        isNull,
      );
    });
  });

  group('the field is bounded (BUT-1912)', () {
    test('a paste long enough to reach infinity is refused', () {
      // Measured: `double.tryParse` answers infinity at 309 nines and stays
      // finite at 308. Unbounded, that paste made an infinite amount storable.
      expect(typed('9' * 400), '');
      expect(parseSwedishDecimal(typed('9' * 400)), isNull);
    });

    test('the integer bound refuses the keystroke', () {
      final atBound = '9' * SwedishDecimalInputFormatter.maxIntegerDigits;
      expect(typed(atBound), atBound);
      // One digit further: the field keeps what it had, so the magnitude the
      // user is looking at never changes behind their back.
      expect(typed('${atBound}9', previous: atBound), atBound);
    });

    test('the fraction bound holds at its own limit', () {
      final atBound =
          '0,${'9' * SwedishDecimalInputFormatter.maxFractionDigits}';
      expect(typed(atBound), atBound);
      expect(typed('${atBound}9', previous: atBound), atBound);
    });

    test('the formatter can emit more digits than the field accepts', () {
      // The documented gap, pinned so widening either number is deliberate.
      // Measured 2026-08-25: 22 fraction digits, from the `toString()` branch
      // that never touches `toStringAsFixed`. This test reddens if
      // `maxFractionDigits` is raised to 22 — which is arguably the real fix.
      final written = formatSwedishDecimal(1.2345678901234567e-6);
      expect(written, '0,0000012345678901234567');
      expect(typed(written), '');
    });

    test('an over-long amount from stored data can still be edited down', () {
      // A flat refusal would freeze the field for anyone holding an amount
      // over the bound: every keystroke rejected, including backspace.
      final seeded = '9' * 30;
      expect(typed('9' * 29, previous: seeded), '9' * 29);
    });
  });
}
