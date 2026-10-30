// A field that draws
// the search glyph as its own prefix, or uses StyledInput.search, is a search
// field built by hand, and none is left.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _notYetMoved = <String, int>{};

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

final _searchPrefix = RegExp(
  r'prefixIcon\s*[:=]\s*(const\s+)?(ButleryIcon\s*\(\s*)?ButleryIcons\.search\b',
);
final _styledSearch = RegExp(r'\bStyledInput\.search\s*\(');

int _handBuilt(String code) =>
    _searchPrefix.allMatches(code).length +
    _styledSearch.allMatches(code).length;

void main() {
  test('no search field is built by hand outside the list', () {
    final found = <String, int>{};
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path == 'lib/widgets/common/butlery_search_box.dart') continue;
      final count = _handBuilt(_code(path));
      if (count > 0) found[path] = count;
    }
    expect(found, _notYetMoved);
  });

  test('the patterns find the shapes they guard', () {
    expect(
      _handBuilt('''
        TextField(decoration: InputDecoration(
          prefixIcon: const ButleryIcon(ButleryIcons.search)));
        StyledInput(prefixIcon: ButleryIcon(ButleryIcons.search));
        StyledInput.search(hint: 'x');
        x = ButleryIcons.searchOff;
        prefixIcon: ButleryIcons.searchOff;
      '''),
      3,
    );
  });
}
