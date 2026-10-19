// A shared-list permission change is only refused as stale if the base it
// declares is the copy the user was looking at (BUT-1777). Handing it the live
// stream copy makes base and stored the same read, and the refusal can never
// fire. The parameter is a plain list, so nothing in the type system says which
// copy it is; this lists everyone who passes one, and a new caller fails here
// until someone checks which copy it holds.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// file -> how many `viewedBase:` arguments it passes
const _passers = <String, int>{
  'lib/services/unified/operations/collaborative_shopping_operations.dart': 1,
  'lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart':
      1,
};

String _code(String source) => source
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

final _pass = RegExp(r'\bviewedBase:');

int _passedIn(String source) => _pass.allMatches(_code(source)).length;

Map<String, int> _found() {
  final found = <String, int>{};
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final n = _passedIn(file.readAsStringSync());
    if (n > 0) found[file.path.replaceAll(r'\', '/')] = n;
  }
  return found;
}

void main() {
  test('only the member dialog starts a viewedBase', () {
    expect(_found(), _passers);
  });

  test('the pattern finds the spellings the code uses', () {
    expect(_passedIn('f(viewedBase: _declaredBase, x: 1)'), 1);
    expect(_passedIn('f(\n  viewedBase: viewedBase,\n)'), 1);
    expect(_passedIn('f(viewedBase: a.copyWith(\n x: 1,\n ))'), 1);
    expect(_passedIn('f(viewedBase: c\n ? a\n : b,\n)'), 1);
    expect(_passedIn('// f(viewedBase: live)'), 0);
    expect(_passedIn('required UnifiedShoppingList viewedBase,'), 0);
  });
}
