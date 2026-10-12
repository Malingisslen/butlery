// Every checkbox in the app is ButleryCheckbox or ButleryCheckboxTile, so the
// 24 dp box, the edge, the tick, the focus ring and the touch target are drawn
// in one place (tokens.json controls.checkbox). A Material Checkbox or
// CheckboxListTile built by hand is a second checkbox, and none is left
// outside the list.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Files another open branch rewrites; whoever merges after them deletes the
// entry in the same change.
const _notYetMoved = <String, int>{
  'lib/views/social/add_members_to_group_view.dart': 1,
  'lib/widgets/import/batch_import_preview.dart': 1,
};

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

final _handBuilt = RegExp(
  r'\b(Checkbox|CheckboxListTile)(\.adaptive)?\s*\(',
);

void main() {
  test('no checkbox is built by hand outside the list', () {
    final found = <String, int>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path == 'lib/widgets/common/input/butlery_checkbox.dart') continue;
      final count = _handBuilt.allMatches(_code(path)).length;
      if (count > 0) found[path] = count;
    }
    expect(found, _notYetMoved);
  });

  test('the pattern finds the shapes it guards', () {
    expect(
      _handBuilt.allMatches(
        '''
        Checkbox(value: a, onChanged: b);
        CheckboxListTile(value: a);
        Checkbox.adaptive(value: a);
        ButleryCheckbox(value: a);
        DebouncedCheckbox(value: a);
        ButleryCheckboxTile(value: a);
      ''',
      ).length,
      3,
    );
  });
}
