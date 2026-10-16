// B-86: a confirmation snackbar stays 4-5 s, so no caller of showSuccess
// picks a shorter time.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('no showSuccess caller picks a duration under four seconds', () {
    final call = RegExp(r'showSuccess\(([^;]*?)\);', dotAll: true);
    final tooShort = RegExp(
      r'Duration\(\s*(milliseconds:\s*[0-3]\d{0,3}\b|seconds:\s*[0-3]\b)',
    );
    final found = <String>[];
    for (final entity in Directory('lib').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      if (path == 'lib/core/utils/snackbar_utils.dart') continue;
      for (final m in call.allMatches(entity.readAsStringSync())) {
        if (tooShort.hasMatch(m.group(1)!)) found.add(path);
      }
    }
    expect(found, isEmpty, reason: 'B-86: bekräftelser följer primitivens tid');
  });
}
