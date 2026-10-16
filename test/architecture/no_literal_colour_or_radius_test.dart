// A view or widget takes colours from the theme and corners from the radius
// scale (B-27 and tokens.json space.radius). Nothing else scanned lib/views and
// lib/widgets for a typed colour or a typed corner, so a single `Color(0xFF...)`
// or `Colors.red` in a view would have gone unnoticed. Transparent is the one
// named colour that is not a palette colour. The radius sites below are the
// ones that exist; the list only shrinks.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _typedRadius = <String, int>{
  'lib/views/recipe_detail/recipe_detail_shared_widgets.dart': 1,
  'lib/widgets/common/brand/butlery_cloche.dart': 1,
  'lib/widgets/onboarding/onboarding_parts.dart': 2,
};

final _typedColour = RegExp(
  r'Color\(\s*0x|Color\.fromRGBO|Color\.fromARGB|(?<![A-Za-z])Colors\.(?!transparent\b)[a-z]\w*',
);
final _typedRadiusCall = RegExp(r'Radius\.circular\(\s*[0-9]');

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

Iterable<String> _libFiles() sync* {
  for (final root in ['lib/views', 'lib/widgets']) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is File && entity.path.endsWith('.dart')) {
        yield entity.path.replaceAll(r'\', '/');
      }
    }
  }
}

void main() {
  test('no view or widget types a colour', () {
    final hits = <String>[
      for (final path in _libFiles())
        for (final m in _typedColour.allMatches(_code(path)))
          '$path: ${m.group(0)}',
    ];
    expect(hits, isEmpty);
  });

  test('typed corner radii are only the ones listed', () {
    final counts = <String, int>{};
    for (final path in _libFiles()) {
      final n = _typedRadiusCall.allMatches(_code(path)).length;
      if (n > 0) counts[path] = n;
    }
    expect(counts, _typedRadius);
  });
}
