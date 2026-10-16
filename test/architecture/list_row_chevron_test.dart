// A row that leads somewhere draws its chevron with ButleryChevron (12 px,
// text.secondary, no semantics node); a hand-placed ButleryIcons.chevronRight
// next to a row drifts from that. Pager arrows and buttons legitimately use
// the glyph, so this is a ratchet, not a ban.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The ceiling only goes down: owners of the remaining files move their row
// chevrons to ButleryChevron.
const _ceiling = 4;

const _owners = {
  'lib/widgets/common/icons/butlery_icons.dart',
  'lib/widgets/common/list/butlery_list.dart',
};

void main() {
  test('hand-placed chevronRight glyphs under lib/ do not grow', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final path = f.path.replaceAll('\\', '/');
      if (_owners.contains(path)) continue;
      final code = f.readAsStringSync().replaceAll(
        RegExp(r'(?<!:)//[^\n]*'),
        '',
      );
      final hits = 'ButleryIcons.chevronRight'.allMatches(code).length;
      for (var i = 0; i < hits; i++) {
        found.add(path);
      }
    }
    expect(
      found.length,
      lessThanOrEqualTo(_ceiling),
      reason: 'use ButleryChevron for a row chevron:\n${found.join('\n')}',
    );
  });
}
