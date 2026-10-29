/// Rejoins the lines a camera frame or an OCR reader broke in the middle of
/// a sentence, so "Smält ner" / "smöret i en kastrull" reads as one step and
/// "kar-" / "damumma" as one word (BUT-2455).
///
/// Pure function, no Flutter imports, same category as `page_reflow.dart`
/// (see `lib/services/CLAUDE.md`). Text rules only: it runs where no
/// geometry reaches the parser.
///
/// A line that carries a quantity is never joined to the line after it unless it ends
/// in a comma or a hyphen, because two ingredient rows that read as prose
/// ("salt och vitpeppar" over "Gör så här") would otherwise fold into one.
library;

import 'package:butlery/services/import/parsers/heading_word_lists.dart';
import 'package:butlery/services/import/parsers/recipe_section_detector.dart';
import 'package:butlery/utils/text/swedish_word_boundary.dart';

/// Joins each wrapped line to its continuation. Idempotent: a second pass
/// over the result changes nothing.
String reflowWrappedLines(String text) {
  final lines = text.split('\n');
  final out = <String>[];
  var i = 0;
  while (i < lines.length) {
    var current = lines[i];
    var j = i + 1;
    while (j < lines.length && _continues(current, lines[j])) {
      current = _join(current, lines[j]);
      j++;
    }
    out.add(current);
    i = j;
  }
  return out.join('\n');
}

/// Whether [next] is the rest of [line] rather than a line of its own.
bool _continues(String line, String next) {
  final a = line.trimRight();
  final b = next.trim();
  // Also what keeps a blank line, a bullet, a numbered step and a row that
  // opens with a digit on their own: none of them starts with a lowercase
  // letter.
  if (!_startsLowercase(b)) return false;
  if (_opensALine(b)) return false;

  if (_hyphenated.hasMatch(a)) return true;
  if (a.endsWith(',')) return true;

  // Out of a quantity row only through a comma or a hyphen, handled above.
  // A numbered step is never one, however many "smör och olja" it carries.
  if (!_stepMarker.hasMatch(a.trim()) &&
      RecipeSectionDetector.looksLikeIngredient(a)) {
    return false;
  }
  if (_isListHeading(a)) return false;
  if (_terminal.hasMatch(a)) return false;

  if (_danglingWord.hasMatch(a)) return true;

  // Prose: three words or more, or a line that opens with a step number or
  // a capital. A short capitalised line ("Deg") takes a continuation only
  // when the continuation is itself prose, so a bare ingredient under a
  // one-word heading stays on its own row.
  final words = a.trim().split(_whitespace).length;
  if (words >= 3) return true;
  if (_stepNumber.hasMatch(a) || _startsUppercase(a.trim())) {
    return b.split(_whitespace).length >= 3;
  }
  return false;
}

String _join(String line, String next) {
  final a = line.trimRight();
  final b = next.trim();
  if (_hyphenated.hasMatch(a)) {
    // "Potatis- och purjolökssoppa" keeps its hyphen; "kar-" / "damumma"
    // loses it.
    final keep = _coordinator.hasMatch(b);
    return keep ? '$a $b' : '${a.substring(0, a.length - 1)}$b';
  }
  return '$a $b';
}

/// A continuation never starts a heading (a "steg 2" row is one) or a
/// quantity row ("ca 2 dl") of its own. The quantity test here is the narrow
/// one: the detector the refusing side uses takes "37 grader" for "37 g", and
/// a step's second half is full of such numbers.
bool _opensALine(String b) {
  if (_quantityRow.hasMatch(b)) return true;
  if (_isListHeading(b)) return true;
  return false;
}

bool _isListHeading(String line) {
  final t = line.trim();
  if (t.endsWith(':')) return true;
  if (RecipeSectionDetector.isIngredientHeader(t)) return true;
  final lower = t.toLowerCase();
  if (HeadingWordLists.genericBlockMarkers.contains(lower)) return true;
  if (RecipeSectionDetector.isInstructionHeader(lower)) return true;
  return false;
}

bool _startsLowercase(String s) => _lowerFirst.hasMatch(s);
bool _startsUppercase(String s) => _upperFirst.hasMatch(s);

final _whitespace = RegExp(r'\s+');
final _lowerFirst = RegExp('^[a-zåäöé]');
final _upperFirst = RegExp('^[A-ZÅÄÖÉ]');
final _hyphenated = RegExp('[a-zA-ZåäöÅÄÖ]-\$');
final _terminal = RegExp(r'[.!?:;]\s*$');
final _stepNumber = RegExp(
  r'^(?:\d{1,2}[.):]|steg\s*\d|[0-9]️?⃣)',
  caseSensitive: false,
);
// A step marker needs the space after it, so "1.5 dl" stays a quantity.
final _stepMarker = RegExp(
  r'^(?:\d{1,2}[.):]\s|steg\s*\d|[0-9]️?⃣)',
  caseSensitive: false,
);
final _coordinator = RegExp(r'^(?:och|eller|samt)(?:\s|$)');
final _quantityRow = RegExp(
  r'^ca\.?\s+\d+(?:[,.]\d+)?\s*'
  r'(?:dl|cl|ml|l|kg|g|hg|msk|tsk|krm|st|bit|skiva|klyfta|burk|pkt|påse|port)'
  '${SwedishWordBoundary.after}',
);

/// Words a Swedish sentence does not end on: the line wrapped after them.
final _danglingWord = RegExp(
  r'(?:^|\s)(?:och|eller|samt|med|i|på|till|av|för|som|att|om|under|över|utan|från|vid|hos|mot|efter|innan|tills|så|en|ett|den|det|de)$',
);
