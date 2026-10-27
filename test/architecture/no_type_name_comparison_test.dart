// Release builds are compiled with --obfuscate, which renames classes. A check
// on a type's NAME is then false in the shipped app and true in every test,
// so it can never be caught by a test that runs the code. This happened: the
// Timestamp check in SerializationUtils read every date as null in release,
// and the trash list hid every row. Compare types with `is` instead.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _nameComparison = RegExp(
  r'runtimeType\.toString\(\)\s*(==|!=|\.contains\(|\.startsWith\(|\.endsWith\()'
  r'|(==|!=)\s*[\w.]*runtimeType\.toString\(\)'
  r'|switch\s*\(\s*[\w.]*runtimeType\.toString\(\)',
);

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

void main() {
  test('no code in lib/ compares a type by its name', () {
    final offenders = <String>[];
    final files = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'));
    for (final file in files) {
      final lines = _code(file.path).split('\n');
      for (var i = 0; i < lines.length; i++) {
        if (_nameComparison.hasMatch(lines[i])) {
          offenders.add('${file.path.replaceAll(r'\', '/')}:${i + 1}');
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason: 'a class name is renamed in release builds; use `is`',
    );
  });

  test('the scan catches the shape that broke the trash list', () {
    expect(
      _nameComparison.hasMatch(
        "if (value.runtimeType.toString() == 'Timestamp') {",
      ),
      isTrue,
    );
    expect(
      _nameComparison.hasMatch(
        "x.runtimeType.toString().contains('Timestamp')",
      ),
      isTrue,
    );
    expect(
      _nameComparison.hasMatch('_ => error.runtimeType.toString(),'),
      isFalse,
    );
  });
}
