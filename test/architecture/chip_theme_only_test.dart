// A chip takes its colours, edge, shape and padding from the chip theme
// (Komponentark v1 §03; BUT-2373), so a change in the component sheet
// reaches every chip. The files below still give chips their own: each count
// is pinned, so a new override reddens, and so does a move that forgets to
// shrink the list.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _notYetMoved = <String, int>{
  // Genomgångens spår D1 owns the admin views.
  'lib/views/admin/feedback_inbox_view.dart': 2,
  // Inmatningsrutor del 3 owns the search and filter fields.
  'lib/views/social/shared_with_me/shared_content_search_bar.dart': 1,
  'lib/widgets/common/search_filter/personal_tag_filter_chips.dart': 2,
  'lib/widgets/common/search_filter_widget.dart': 1,
  'lib/widgets/common/social_components/invitation_selectors.dart': 1,
};

const _overrides = [
  'selectedColor',
  'backgroundColor',
  'side',
  'shape',
  'padding',
  'labelPadding',
  'labelStyle',
  'checkmarkColor',
  'disabledColor',
  'deleteIconColor',
  'color',
  'showCheckmark',
  'visualDensity',
  'materialTapTargetSize',
];

final _chip = RegExp(
  r'(?<![\w.])(FilterChip|ChoiceChip|ActionChip|InputChip|RawChip|Chip)(\.\w+)?\(',
);

/// Strips comments so a sentence that names a chip is not counted.
String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

/// The call's own arguments, without nested calls' arguments.
String _ownArguments(String code, int open) {
  final own = StringBuffer();
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    final c = code[i];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    if (depth == 1 && c != '(') own.write(c);
    if (depth == 0) break;
  }
  return own.toString();
}

int _overridingChips(String code) {
  var n = 0;
  for (final m in _chip.allMatches(code)) {
    final own = _ownArguments(code, m.end - 1);
    if (_overrides.any(
      (k) => RegExp('(?<![\\w.])$k\\s*:').hasMatch(own),
    )) {
      n++;
    }
  }
  return n;
}

void main() {
  test('no chip in lib/ sets its own colours, edge, shape or padding', () {
    final counts = <String, int>{};
    var chips = 0;
    for (final file in Directory('lib').listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll(r'\', '/');
      final code = _code(path);
      chips += _chip.allMatches(code).length;
      final n = _overridingChips(code);
      if (n > 0) counts[path] = n;
    }
    expect(chips, greaterThan(0), reason: 'no chip found; the scan is broken');
    expect(counts, _notYetMoved);
  });
}
