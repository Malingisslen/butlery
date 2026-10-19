// A recipe's owner is `Recipe.ownerUid`. The older spelling, `socialData?.ownerId
// ?? createdBy`, stops at an EMPTY ownerId and reads it as a real uid that
// matches nobody, so an owner with an empty ownerId was refused. The files
// that still spell it that way are pinned by count and the number only falls.
// A file that is not listed may not use the spelling at all.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _oldSpelling = <String, int>{};

String _code(String source) => source
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

final _spelling = RegExp(
  r'socialData\s*\?\.\s*ownerId\s*\?\?\s*(?:[A-Za-z_][\w]*\s*(?:\?\.|\.)\s*)*createdBy\b',
);

int _countIn(String source) => _spelling.allMatches(_code(source)).length;

Map<String, int> _counts() {
  final counts = <String, int>{};
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final path = file.path.replaceAll(r'\', '/');
    final n = _countIn(file.readAsStringSync());
    if (n > 0) counts[path] = n;
  }
  return counts;
}

void main() {
  test('no code works out a recipe owner by the old spelling', () {
    expect(_counts(), _oldSpelling);
  });

  test('the pattern finds the spellings the code has used', () {
    expect(_countIn('a.socialData?.ownerId ?? a.createdBy'), 1);
    expect(_countIn('(r.socialData?.ownerId ?? r.core.createdBy)'), 1);
    expect(
      _countIn('x.socialData?.ownerId ??\n    x.createdBy ?? fallback'),
      1,
    );
    expect(_countIn('(x.socialData?.ownerId ?? x.createdBy)\n.orEmpty()'), 1);
    expect(
      _countIn(
        'a.socialData?.ownerId ?? a.createdBy; b.socialData?.ownerId ?? b.createdBy',
      ),
      2,
    );
  });

  test('the pattern leaves the new spelling and commented text alone', () {
    expect(_countIn('recipe.ownerUid'), 0);
    expect(_countIn('final o = recipe.socialData?.ownerId;'), 0);
    expect(_countIn('x.socialData?.ownerId ?? fallback'), 0);
    expect(_countIn('// a.socialData?.ownerId ?? a.createdBy'), 0);
    expect(_countIn('/* a.socialData?.ownerId ?? a.createdBy */'), 0);
  });
}
