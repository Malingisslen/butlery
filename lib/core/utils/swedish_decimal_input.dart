// lib/core/utils/swedish_decimal_input.dart

import 'package:flutter/services.dart';

/// Input plumbing for a quantity a Swedish user types by hand.
///
/// Swedish writes the decimal separator as a comma, Dart's `double` parses only
/// a period, and a phone keyboard offers whichever one the OS locale feels like.
/// Every field that takes a fractional amount therefore needs all three of:
/// accept both separators, show back the comma, and hand a parseable string to
/// `double`. Splitting those across a formatter here and an ad-hoc
/// `replaceAll(',', '.')` at the call site is how BUT-1891 happened — the field
/// stripped the separator before the parse ever saw it, so the parse looked
/// correct and was unreachable.
class SwedishDecimalInputFormatter extends TextInputFormatter {
  const SwedishDecimalInputFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    final buffer = StringBuffer();
    var separatorTaken = false;
    // Counted rather than derived from the length delta: the transform is not
    // length-preserving (a rejected keystroke drops a character) and it is not
    // a pure filter either (a period becomes a comma), so the only reliable
    // cursor is "how many characters SURVIVED from before the caret".
    var caret = 0;

    for (var i = 0; i < newValue.text.length; i++) {
      final char = newValue.text[i];
      final isSeparator = char == ',' || char == '.';
      final keep = _isDigit(char) || (isSeparator && !separatorTaken);
      if (!keep) continue;

      if (isSeparator) separatorTaken = true;
      // A typed period is rewritten, not refused. Refusing it would be a
      // second, invisible rule for anyone whose keyboard offers a period, and
      // the app's own display convention is the comma.
      buffer.write(isSeparator ? ',' : char);
      if (i < newValue.selection.baseOffset) caret++;
    }

    final text = buffer.toString();
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret.clamp(0, text.length)),
    );
  }

  static bool _isDigit(String char) {
    final code = char.codeUnitAt(0);
    return code >= 0x30 && code <= 0x39;
  }
}

/// Reads a hand-typed Swedish amount, or null when there is no number in it.
///
/// Returns null rather than a default so the caller decides what an unreadable
/// field means — on the add dialog that is 1, on the edit dialog it is the
/// amount the item already had, and those are not the same answer.
double? parseSwedishDecimal(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;

  // Load-bearing, measured: `double.tryParse` accepts "Infinity" and "NaN",
  // and an amount of either shape reaches `formatSwedishDecimal`, whose own
  // guard exists because `round()` throws on them. Requiring a digit refuses
  // them here instead. "," and "abc" would return null without this line.
  if (!trimmed.contains(RegExp(r'[0-9]'))) return null;

  // No padding for a leading or trailing separator: `tryParse` already reads
  // ".5" as 0.5 and "2." as 2.0, measured on this SDK and inside Dart's
  // documented grammar. The two padding lines that used to sit here were
  // no-ops on every input the field can produce.
  return double.tryParse(trimmed.replaceAll(',', '.'));
}

/// The Swedish spelling of an amount, with no trailing `,0` on a whole number.
///
/// Kept beside the parser because the two are meant as one round trip — but the
/// trip production actually takes is format -> FIELD -> parse, and the field is
/// the part that loses the value.
///
/// It holds down to 1e-6 and no further, measured: `0,000001` survives,
/// `9.99e-7` does not. Below that `toString()` switches to exponent notation,
/// and [SwedishDecimalInputFormatter] keeps only digits and one separator — so
/// it eats the `e` and the `-`, and `5e-7` comes back out of the field as `57`,
/// eight orders of magnitude high.
///
/// It takes a KEYSTROKE to fire. Input formatters do not run on a programmatic
/// `controller.text`, so opening the edit dialog on such an item and pressing
/// Save preserves the number; the corruption needs the user to touch the amount
/// field, and then the first keystroke rewrites the whole string.
///
/// [parseSwedishDecimal] is NOT the culprit and a fix aimed at it is a no-op:
/// `double.tryParse` reads `5e-7` correctly. The repair belongs here, in what
/// this function is allowed to emit, or in the formatter. Stated rather than
/// guarded because seven decimal places on a shopping quantity is not a real
/// path; BUT-1912 carries it, along with the large end, where `round()`
/// saturates at int64 and `1e21` is written as `9223372036854775807`.
String formatSwedishDecimal(double amount) {
  // Infinity is what this guards. `round()` throws on it, and this function now
  // seeds the edit dialog's field where a plain `toString()` used to sit — so
  // the throw would land when the dialog OPENS rather than on save. Through that
  // FIELD the only way in is a pasted ~309-digit quantity, which
  // `double.tryParse` turns into infinity; the amount can also arrive from
  // stored data via `formattedAmount`.
  //
  // NaN lands here too — `double.nan.isFinite` is false — but it never NEEDED
  // to: with the guard removed, `NaN == NaN.roundToDouble()` is false, so NaN
  // would fall to the fraction branch and `toString()` its way to the same
  // "NaN". Named because both routes print the identical string, which makes it
  // easy to assert the wrong one; this comment has already done so twice.
  if (!amount.isFinite) return amount.toString();
  if (amount == amount.roundToDouble()) return amount.round().toString();
  return amount.toString().replaceAll('.', ',');
}
