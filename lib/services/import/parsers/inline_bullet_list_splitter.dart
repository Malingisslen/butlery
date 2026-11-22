/// Cookbooks often print the whole ingredient list as one run-in paragraph
/// under a heading such as "Till 4 portioner behövs:", items separated by
/// bullets and wrapped mid-item at the column edge. Line-based parsing then
/// sees three or four giant "ingredients"; this turns the run back into one
/// ingredient per line.
class InlineBulletListSplitter {
  const InlineBulletListSplitter._();

  static final _heading = RegExp(
    r'(?:beh[öo]vs|du beh[öo]ver|ingredienser)\s*:?\s*$',
    caseSensitive: false,
  );

  // Spaced dashes and dots are separators only outside a number range
  // ("2 - 3 msk"); unspaced hyphens belong to the words.
  static final _separator = RegExp(r'\s*•\s*|(?<!\d)\s+[-–.]\s+');

  // An uppercase start means a new section ("Ca 1675 kJ", "Gör så här").
  // A one-letter start is OCR noise for "1" or "l", not a section.
  static final _continuation = RegExp(r'^(?:[a-zåäö]|\d(?!\.)|[A-ZÅÄÖ]\s)');

  static const _minBullets = 2;

  static String split(String text) {
    final lines = text.split('\n');
    final out = <String>[];
    var i = 0;
    while (i < lines.length) {
      out.add(lines[i]);
      if (!_heading.hasMatch(lines[i])) {
        i++;
        continue;
      }
      var end = i + 1;
      while (end < lines.length && _continuation.hasMatch(lines[end])) {
        end++;
      }
      final run = lines.sublist(i + 1, end);
      final joined = run.join(' ');
      if ('•'.allMatches(joined).length >= _minBullets) {
        out.addAll(
          joined
              .split(_separator)
              .map((item) => item.trim())
              .where((item) => item.isNotEmpty),
        );
      } else {
        out.addAll(run);
      }
      i = end;
    }
    return out.join('\n');
  }
}
