/// Puts back together an ingredient the cookbook column broke over two lines
/// ("1-2 msk röd- eller" / "vitvinsvinäger", "½ knippa" / "gräslök").
library;

import 'package:butlery/utils/text/unit_definitions.dart';

abstract final class IngredientRowJoiner {
  static final _startsWithAmount = RegExp(r'^\(?\s*(?:ca\.?\s*)?[\d½¼¾⅓⅔⅛+]');
  static final _anyDigit = RegExp(r'[\d½¼¾⅓⅔⅛]');
  static final _whitespace = RegExp(r'\s+');
  static final _openEnded = RegExp(
    r'(?:[\s-](?:eller|och|samt|alt\.?|t\.?\s?ex\.?)|[a-zåäö]-)$',
    caseSensitive: false,
  );
  static final _wordOnly = RegExp(r'^[A-Za-zÅÄÖåäöéü][A-Za-zÅÄÖåäöéü ,\-]*$');
  static final _opensAsContinuation = RegExp(
    r'^(?:eller|och|samt|av|t\.?\s?ex\.?)\s',
    caseSensitive: false,
  );
  static final _countUnit = RegExp(
    r'^(?:knippa|knippe|klyfta|klyftor|kvist|kvistar|nypa|näve|burk|påse|paket|skiva|skivor)$',
  );
  static const _maxContinuationWords = 4;

  /// The two rows as one row when [row] is the rest of [above], else null.
  static String? join(String above, String row) {
    final top = above.trim();
    final rest = row.trim();
    if (top.isEmpty || rest.isEmpty) return null;
    if (!_startsWithAmount.hasMatch(top)) return null;
    if (_startsWithAmount.hasMatch(rest) || _anyDigit.hasMatch(rest)) {
      return null;
    }
    if (!_wordOnly.hasMatch(rest)) return null;
    if (rest.split(_whitespace).length > _maxContinuationWords) return null;

    if (_endsOnAmountAndUnit(top) || _opensAsContinuation.hasMatch(rest)) {
      return '$top $rest';
    }
    if (!_openEnded.hasMatch(top)) return null;
    // "grönsaks-" + "buljong": the hyphen only marked the line break.
    if (top.endsWith('-')) return '${top.substring(0, top.length - 1)}$rest';
    return '$top $rest';
  }

  static bool _endsOnAmountAndUnit(String top) {
    final words = top.replaceAll(RegExp(r'[,.]$'), '').split(_whitespace);
    if (words.length < 2 || words.length > 3) return false;
    final last = words.last.toLowerCase();
    if (!UnitDefinitions.isKnownUnit(last) && !_countUnit.hasMatch(last)) {
      return false;
    }
    return words
        .take(words.length - 1)
        .every(
          (w) => _anyDigit.hasMatch(w) || w.toLowerCase() == 'ca',
        );
  }
}
