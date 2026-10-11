// BUT-2369: a section heading inside a page is SectionHeading. A file that
// marks text as a header and styles it in the overline role is drawing its
// own copy, which is how five copies in three colours came about.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _home = 'lib/widgets/common/section_heading.dart';

/// Comments out, so a doc line naming the role does not count.
String _code(File file) => file
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

/// A `header: true` with the overline role within the next few lines.
final _ownCopy = RegExp(
  r'header:\s*true,(?:[^\n]*\n){0,6}?[^\n]*AppTextStyles\.(overline|sectionHeading)\b',
);

void main() {
  test('no view draws its own overline section heading', () {
    final offenders = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path == _home) continue;
      final code = _code(entity);
      if (_ownCopy.hasMatch(code)) offenders.add(path);
      if (code.contains('AppTextStyles.sectionHeading')) offenders.add(path);
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Use SectionHeading (lib/widgets/common/section_heading.dart).',
    );
  });

  test('the guard catches the shape it is written for', () {
    const copy = '''
      Semantics(
        header: true,
        child: Text(
          text.toUpperCase(),
          style: AppTextStyles.overline.copyWith(color: cs.tertiary),
        ),
      )''';
    expect(_ownCopy.hasMatch(copy), isTrue);
  });
}
