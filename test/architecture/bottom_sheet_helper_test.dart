// Komponentark §09 locks every sheet to one frame: 12 px top edge, a handle
// in border-control, a sharp bottom edge. The frame is the theme's and the
// handle is showButlerySheet's (BUT-2373), so a sheet opened any other way
// drops the handle and can set its own corners. Outside the helper,
// showModalBottomSheet is not called.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _helper = 'lib/widgets/common/sheets/butlery_sheet.dart';

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
      reason:
          'the helper no longer calls showModalBottomSheet; the scan is '
          'aimed at the wrong place',
    );
    expect(_rawSheetCounts(), isEmpty);
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
