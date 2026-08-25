// lib/core/utils/swedish_decimal_input.dart

import 'package:flutter/services.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';

// WHICH FORMATTER APPLIES (BUT-1910)
//
// This app has several places that turn a period into a comma and read one
// back, and nothing said when each wins, so the next reader picks at random.
// This is a ROUTING rule, not a census — deliberately, because a count of them
// would be wrong the week after it was written. Each entry carries the property
// that decides it.
//
//   * `parseSwedishDecimal` / `formatSwedishDecimal` (here) — every hand-typed,
//     round-tripped field. The parser returns NULL and lets the caller decide
//     what an unreadable field means.
//   * `TextFormatting.parseSwedishNumber` / `formatFractional` — non-interactive
//     recipe-text parsing. `parseSwedishNumber` falls back to 1.0 on input it
//     cannot read, which is an accepted default when scraping a recipe and a
//     silent corruption in a form field. `formatFractional` also ROUNDS to two
//     decimals, so it cannot round-trip what this file's parser accepts.
//   * `formatRatingComma` (`butlery_betyg_pill.dart`) — rating pills. It forces
//     exactly one decimal place, which the ones above must not.
//
// They are not merged because those behaviours are genuinely different answers,
// not several spellings of one. Note that a comma-aware parse also lives inside
// `FormValidators.numberRange` — which is why the rating field could report
// itself VALID while its `onChanged` silently dropped the value.

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
///
/// It also bounds how many digits may be entered (BUT-1912). Without a bound the
/// field accepts a paste long enough for `double.tryParse` to answer infinity,
/// and an infinite amount is then stored and re-displayed as one.
class SwedishDecimalInputFormatter extends TextInputFormatter {
  const SwedishDecimalInputFormatter();

  /// Digits allowed before the separator.
  ///
  /// Measured: `double.tryParse` needs a 309-digit run of nines before it
  /// answers infinity, so this bound closes that route with a wide margin.
  static const int maxIntegerDigits = 15;

  /// Digits allowed after the separator. NOT wide enough for every string
  /// [formatSwedishDecimal] emits: its `toString()` branch can run past this
  /// bound, and such a value is refused on retype.
  static const int maxFractionDigits = 20;

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
    // Over the bound the keystroke is REFUSED rather than truncated: truncating
    // would silently change the magnitude of what the user is looking at.
    // Refusing only what does not shrink the field is what lets someone edit
    // their way out of an over-long amount that arrived from stored data — a
    // flat refusal would freeze that field for good.
    if (_exceedsBounds(text) && text.length >= oldValue.text.length) {
      return oldValue;
    }
    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: caret.clamp(0, text.length)),
    );
  }

  /// [text] has already been filtered to digits and at most one comma.
  static bool _exceedsBounds(String text) {
    final separator = text.indexOf(',');
    final integerDigits = separator < 0 ? text.length : separator;
    final fractionDigits = separator < 0 ? 0 : text.length - separator - 1;
    return integerDigits > maxIntegerDigits ||
        fractionDigits > maxFractionDigits;
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
  // guard exists because that function must not print an exponent. Requiring a
  // digit refuses them here instead. "," and "abc" would return null without
  // this line.
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
/// the part that used to lose the value.
///
/// **It never emits exponent notation** (BUT-1912). That is the contract, not a
/// side effect: [SwedishDecimalInputFormatter] keeps only digits and one
/// separator, so an `e` and a `-` reaching the field are eaten and the amount
/// comes back a different number — `5e-7` returned as `57`, eight orders of
/// magnitude high. `toString()` gives up on decimal notation at both ends, so
/// both ends are spelled out here instead.
///
/// Precision it does not keep: the deep end is rounded to 20 decimals by
/// `toStringAsFixed`, so anything under half of the last place is written as
/// `0`, and digits below the 20th are lost above that. A quantity that small is
/// noise, and the alternative — a 300-character field — is not a quantity
/// anyone can read or retype.
String formatSwedishDecimal(double amount) {
  // Infinity and NaN are what this guards. Neither has a digit spelling, and
  // this function seeds a field that opens with the value already in it.
  // Since BUT-1912 the FIELD can no longer produce infinity. Other producers
  // can: `QuantityParser.parse` has no finiteness guard.
  if (!amount.isFinite) return amount.toString();
  // Also catches -0.0, which `toStringAsFixed` spells "-0".
  if (amount == 0) return '0';
  if (amount == amount.roundToDouble()) return _wholeDigits(amount);

  final decimal = amount.toString();
  if (!decimal.contains('e')) return decimal.replaceAll('.', ',');
  return _digitsBelowExponentThreshold(amount);
}

/// A whole amount, written out in full.
///
/// `round().toString()` is what used to sit here and it cannot be used: `round()`
/// saturates at int64, so `1e21` was written as `9223372036854775807` — a real
/// number, wrong by two orders of magnitude, with nothing to mark it as a
/// failure. `toStringAsFixed(0)` spells the digits instead, but it falls back to
/// exponent notation from 1e21 upwards exactly as `toString()` does, so above
/// that the digits are shifted out of the exponent by hand.
String _wholeDigits(double amount) {
  if (amount.abs() < 1e21) return amount.toStringAsFixed(0);

  final exponential = amount.toStringAsExponential();
  final match = _positiveExponentShape.firstMatch(exponential);
  if (match == null) return exponential;

  final fraction = match[3].orEmpty();
  final zeros = int.parse(match[4]!) - fraction.length;
  return '${match[1]}${match[2]}$fraction${'0' * (zeros > 0 ? zeros : 0)}';
}

/// An amount too small for `toString()` to write in decimal notation.
///
/// Measured: the switch happens under 1e-6, so `0,000001` arrives here already
/// decimal and only what is smaller reaches this function.
String _digitsBelowExponentThreshold(double amount) {
  final fixed = amount.toStringAsFixed(20);
  var trimmed = fixed.replaceFirst(RegExp(r'0+$'), '');
  if (trimmed.endsWith('.')) {
    trimmed = trimmed.substring(0, trimmed.length - 1);
  }
  // Everything rounded away: "-0" is a worse answer than "0", and neither is
  // the amount, so say the one a reader can act on.
  if (!trimmed.contains(RegExp(r'[1-9]'))) return '0';
  return trimmed.replaceAll('.', ',');
}

final RegExp _positiveExponentShape = RegExp(r'^(-?)(\d)(?:\.(\d+))?e\+(\d+)$');
