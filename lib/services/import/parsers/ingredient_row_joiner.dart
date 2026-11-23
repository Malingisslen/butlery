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
  // Words a row can never end on: the noun is on the next line.
  static final _danglingWord = RegExp(
    r'[\s,](?:till|i|på|med|av|för|som|att|gärna|helst|olika|eller)$',
    caseSensitive: false,
  );
  // A row that is amount, unit and one describing word ("1 msk
  // koncentrerad") has not named the ingredient yet.
  static final _describingWord = RegExp(
    r'^(?:\p{L}+(?:erad|erade)|\p{L}*hackad|\p{L}*hackade|syltade|skalade|kokade|rivna|skivade|riven|skuren|kokt|kokta|stekt|rökt|mjukt|mjuka|färska?|frysta?|svarta|vita|röda|gröna|gula|torkade|flytande)$',
    caseSensitive: false,
    unicode: true,
  );

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

    if (_endsOnAmountAndUnit(top) ||
        _opensAsContinuation.hasMatch(rest) ||
        _danglingWord.hasMatch(top) ||
        _endsOnDescribingWord(top)) {
      return '$top $rest';
    }
    if (!_openEnded.hasMatch(top)) return null;
    // "grönsaks-" + "buljong": the hyphen only marked the line break.
    if (top.endsWith('-')) return '${top.substring(0, top.length - 1)}$rest';
    return '$top $rest';
  }

  static bool _endsOnDescribingWord(String top) {
    final words = top.replaceAll(RegExp(r'[,.]$'), '').split(_whitespace);
    for (var amountWords = 2; amountWords <= 3; amountWords++) {
      if (words.length <= amountWords) return false;
      final described = words.skip(amountWords);
      if (described.length <= 2 &&
          described.every(
            (w) => _describingWord.hasMatch(w.replaceAll(',', '')),
          ) &&
          _endsOnAmountAndUnit(words.take(amountWords).join(' '))) {
        return true;
      }
    }
    return false;
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
