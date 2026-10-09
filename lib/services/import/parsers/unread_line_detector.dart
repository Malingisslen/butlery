/// Decides whether an imported ingredient line could not be read, so the
/// review shows it empty and marked instead of as guessed text
/// (flows-roles-budget.md, BUT-2158).
///
/// Two shapes count as unread:
/// - the marker the image reader writes where it could not read a line
///   ([unreadMarker]);
/// - an amount the reader garbled: the word right before a unit is neither a
///   number nor a counting word ("} dl", "2z dl", "1i2 tsk", "% tsk").
///
/// Pure Dart, no Flutter, so `tools/corpus_unread_eval.dart` can measure it
/// against the cookbook corpus. Run that before changing a rule here: a false
/// alarm empties a correct line in front of the user.
class UnreadLineDetector {
  UnreadLineDetector._();

  /// What the image reader writes in place of text it could not read. Must
  /// match the server prompt in functions/src/llm/gemini-client.ts.
  static const String unreadMarker = '[oläsligt]';

  static const String _unitWords =
      r'(dl|cl|ml|l|msk|tsk|krm|g|kg|hg|st|förp|paket|pkt|burk|burkar|påse|'
      r'påsar|bit|bitar|skiva|skivor|klyfta|klyftor|kruka|knippe|liter|nypa|'
      r'droppar|portion|portioner|kilo)';

  static final RegExp _unit = RegExp('^$_unitWords\$', caseSensitive: false);

  static const String _fractions = '½¼¾⅓⅔⅛⅕';
  static const String _number =
      r'(\d+([.,]\d+)?|\d*[' + _fractions + r']|\d+ ?\d*/\d+)';

  static final RegExp _quantity = RegExp(
    '^$_number([-–]$_number)?\$',
  );

  /// The second half of a range written with a space: "2 -3 dl".
  static final RegExp _rangeTail = RegExp('^[-–]$_number\$');

  /// A size glued to its unit ("400g burk") or a multiple ("2x400 g",
  /// "1+1 msk") is an amount, not a garbled one.
  static final RegExp _compound = RegExp(
    '^$_number($_unitWords|[x×+]$_number)\$',
    caseSensitive: false,
  );

  static final RegExp _countingWord = RegExp(
    r'^(ca\.?|cirka|drygt|knappt|en|ett|två|tre|fyra|fem|sex|sju|åtta|nio|'
    r'tio|några|någon|lite)$',
    caseSensitive: false,
  );

  static final RegExp _letters = RegExp(r'^\p{L}+$', unicode: true);

  static bool isUnread(String line) {
    if (line.contains(unreadMarker)) return true;

    final tokens = line
        .trim()
        .split(RegExp(r'\s+'))
        .map((t) => t.replaceAll(RegExp(r'^[(\[]+|[)\]]+$'), ''))
        .toList();

    for (var i = 0; i < tokens.length - 1; i++) {
      final next = tokens[i + 1].replaceAll(RegExp(r'[.,]+$'), '');
      if (!_unit.hasMatch(next)) continue;

      final token = tokens[i];
      if (token.isEmpty) continue;
      if (_quantity.hasMatch(token) || _countingWord.hasMatch(token)) {
        return false;
      }
      if (token == '-' ||
          token == '–' ||
          _rangeTail.hasMatch(token) ||
          _compound.hasMatch(token)) {
        return false;
      }
      // A word before a unit ("fisk i paket", "banan, i bitar") is text, not
      // an amount. A lone letter only reads as a garbled amount when it opens
      // the line ("a tsk salt" for "½ tsk salt").
      if (_letters.hasMatch(token) && (token.length > 1 || i > 0)) {
        return false;
      }
      return true;
    }
    return false;
  }
}
