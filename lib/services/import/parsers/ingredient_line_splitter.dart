import 'package:butlery/utils/text/unit_definitions.dart';

/// Puts one ingredient on one line, whatever the cookbook did to the row.
///
/// Cookbooks run several ingredients together on one printed line ("125 g
/// smör • 1 tsk salt", "2 purjolökar + 1 morot"). The import reads a line as
/// one ingredient, so the line is cut apart before it gets there.
class IngredientLineSplitter {
  const IngredientLineSplitter._();

  static const _amount = r'(?:\d+(?:[.,]\d+)?(?:/\d+)?|[½¼¾⅓⅔⅛])';
  static final _startsWithAmount = RegExp('^$_amount(?:[\\s–-]|\$)');
  static final _amountOnly = RegExp(r'^[\d½¼¾⅓⅔⅛\s/.,–-]+$');
  static final _bullet = RegExp(r'\s*•\s*');
  static final _plus = RegExp('\\s+\\+\\s+(?=$_amount\\s)');
  static final _comma = RegExp('(?<=[a-zåäö]),\\s+(?=$_amount\\s)');
  static const _maxBareWords = 2;
  static const _maxRunPartWords = 7;
  // "4 portioner, 30 minuter" is a time and a yield, not two ingredients.
  static final _notAnIngredient = RegExp(
    r'^\S+\s+(?:minut|timm|sekund|portion|person|gång)',
    caseSensitive: false,
  );

  /// Rows that open with an amount (or a short bulleted run) are cut; every
  /// other line, method text included, is returned as it came.
  static String process(String text) {
    return [for (final line in text.split('\n')) ..._split(line)].join('\n');
  }

  static List<String> _split(String line) {
    final text = line.trim();
    if (!_startsWithAmount.hasMatch(text) && !_isBulletedRun(text)) {
      return [line];
    }
    var parts = <String>[text];
    for (final separator in [_bullet, _plus, _comma]) {
      parts = [
        for (final part in parts) ..._cut(part, separator),
      ];
    }
    if (parts.length == 1) return [line];
    return _withDanglingAmountsJoined(parts);
  }

  // A line that opens with a word is a run of ingredients only when every
  // bulleted part is short and none is a sentence ("salt • vitpeppar"), so
  // method text with a stray bullet is left alone.
  static bool _isBulletedRun(String text) {
    if (!text.contains('•')) return false;
    for (final part in text.split(_bullet)) {
      final words = part.trim().split(RegExp(r'\s+'));
      if (words.length > _maxRunPartWords || part.contains('. ')) return false;
      if (part.trim().endsWith('.') &&
          !_startsWithAmount.hasMatch(part.trim()) &&
          words.length > 3) {
        return false;
      }
    }
    return true;
  }

  // A comma or plus only separates when the next part is an ingredient of
  // its own: an amount and a name ("10 vitpepparkorn, 2 lagerblad"), not
  // "1 burk ananas, 400 g".
  static List<String> _cut(String part, RegExp separator) {
    if (separator == _bullet) {
      // A part that opens with a word and runs on ("rivet skal av ½ citron")
      // reads as a sentence of the method once it stands alone, so it stays
      // with the row before it.
      final pieces = <String>[];
      for (final raw in part.split(separator)) {
        final piece = raw.trim();
        if (piece.isEmpty) continue;
        final standsAlone =
            _startsWithAmount.hasMatch(piece) ||
            piece.split(RegExp(r'\s+')).length <= _maxBareWords;
        if (pieces.isEmpty || standsAlone) {
          pieces.add(piece);
        } else {
          pieces[pieces.length - 1] = '${pieces.last} $piece';
        }
      }
      return pieces;
    }
    final pieces = <String>[];
    var start = 0;
    for (final m in separator.allMatches(part)) {
      final rest = part.substring(m.end);
      if (!_hasName(rest) ||
          _notAnIngredient.hasMatch(rest) ||
          !RegExp(r'[a-zåäö]{2}').hasMatch(part.substring(start, m.start))) {
        continue;
      }
      pieces.add(part.substring(start, m.start).trim());
      start = m.end;
    }
    pieces.add(part.substring(start).trim());
    return pieces.where((p) => p.isNotEmpty).toList();
  }

  static bool _hasName(String rest) {
    final words = rest.split(RegExp(r'\s+')).skip(1).toList();
    if (words.isNotEmpty && UnitDefinitions.isKnownUnit(words.first)) {
      words.removeAt(0);
    }
    return words.isNotEmpty && RegExp(r'^[a-zåäö]{3,}').hasMatch(words.first);
  }

  // The column edge can leave a bare amount at the end of one part ("• 2");
  // it belongs to the words that follow.
  static List<String> _withDanglingAmountsJoined(List<String> parts) {
    final out = <String>[];
    for (var i = 0; i < parts.length; i++) {
      if (_amountOnly.hasMatch(parts[i]) && i + 1 < parts.length) {
        parts[i + 1] = '${parts[i]} ${parts[i + 1]}';
        continue;
      }
      out.add(parts[i]);
    }
    return out;
  }
}
