import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// A `*_test.dart` file without `main` makes `flutter test` fail to load it, so
// the whole run is red even though no test is wrong. Helpers belong in a file
// whose name does not end in `_test.dart`.
const _allowedWithoutMain = <String>{
  // Renamed to base_unit_support.dart when its importers are rewritten.
  'test/test_support/base_unit_test.dart',
};

final _mainDeclaration = RegExp(r'\bmain\s*\(');

List<String> _testFiles() => [
  for (final dir in ['test', 'integration_test'])
    if (Directory(dir).existsSync())
      for (final e in Directory(dir).listSync(recursive: true))
        if (e is File && e.path.endsWith('_test.dart'))
          e.path.replaceAll(r'\', '/'),
];

void main() {
  test('every *_test.dart file declares main', () {
    final files = _testFiles();
    expect(files, isNotEmpty, reason: 'run from the repository root');
    final offenders = <String>[
      for (final path in files)
        if (!_allowedWithoutMain.contains(path) &&
            !_mainDeclaration.hasMatch(File(path).readAsStringSync()))
          path,
    ];
    expect(
      offenders,
      isEmpty,
      reason:
          'Rename the helper so it does not end in _test.dart, or add main().',
    );
  });

  test('the allow-list only names files that exist and still lack main', () {
    for (final path in _allowedWithoutMain) {
      final file = File(path);
      expect(file.existsSync(), isTrue, reason: '$path is gone; drop it');
      expect(
        _mainDeclaration.hasMatch(file.readAsStringSync()),
        isFalse,
        reason: '$path declares main now; drop it from the allow-list',
      );
    }
  });
}
