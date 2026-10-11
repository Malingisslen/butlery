// Komponentark §09 locks every sheet to one frame: 12 px top edge, a handle
// in border-control, a sharp bottom edge. The frame is the theme's and the
// handle is showButlerySheet's (BUT-2373), so a sheet opened any other way
// drops the handle and can set its own corners. The files below have not
// moved yet because another track owns them; each count is pinned, so a new
// raw sheet reddens, and so does a move that forgets to shrink the list.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _helper = 'lib/widgets/common/sheets/butlery_sheet.dart';

const _notYetMoved = <String, int>{
  // Genomgångens spår F owns this file after #641.
  'lib/app/auth/auth_wrapper.dart': 1,
  // Genomgångens spår A owns lib/widgets/common/dialogs/**.
  'lib/widgets/common/dialogs/slot_picker_dialog.dart': 2,
  // Genomgångens spår B owns these two.
  'lib/views/family/who_is_eating_sheet.dart': 1,
  'lib/widgets/common/layout_components.dart': 1,
  // Landed on main while the sheets moved (BUT-1325, BUT-722).
  'lib/views/cookbooks/cookbook_edit_sheet.dart': 1,
  'lib/views/cookbooks/cookbook_recipe_sheets.dart': 1,
  'lib/views/cookbooks/cookbook_shelf.dart': 1,
  'lib/widgets/whats_new/whats_new_sheet.dart': 1,
};

/// Strips comments so a sentence that names the call is not counted.
String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

final _rawSheet = RegExp(r'\bshowModalBottomSheet\s*(<[^(]*>)?\s*\(');

Map<String, int> _rawSheetCounts() {
  final counts = <String, int>{};
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final path = file.path.replaceAll(r'\', '/');
    if (path == _helper) continue;
    final n = _rawSheet.allMatches(_code(path)).length;
    if (n > 0) counts[path] = n;
  }
  return counts;
}

void main() {
  test('every bottom sheet in lib/ opens through showButlerySheet', () {
    expect(
      _rawSheet.hasMatch(_code(_helper)),
      isTrue,
      reason: 'the helper no longer calls showModalBottomSheet; the scan is '
          'aimed at the wrong place',
    );
    expect(_rawSheetCounts(), _notYetMoved);
  });

  test('the helper takes no shape and no colour', () {
    final helper = _code(_helper);
    expect(helper, isNot(contains('shape:')));
    expect(helper, isNot(contains('backgroundColor:')));
    expect(helper, contains('showDragHandle: true'));
    expect(helper, contains('isScrollControlled: true'));
    expect(helper, contains('useSafeArea: true'));
  });
}
