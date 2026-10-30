// The tagging vocabulary is compiled from a data file, so the generated Dart
// file can drift from it if someone edits either side by hand. This test turns
// that drift red without spawning the generator: it renders the data file the
// way the generator does and compares the result, ignoring layout, with the
// committed file. To fix a red run: dart run tools/gen_tag_vocabulary.dart

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../tools/gen_tag_vocabulary.dart' as gen;

const _source = 'lib/services/tagging/config/data/occasions.json';
const _target =
    'lib/services/tagging/config/generated/occasion_vocabulary.g.dart';

// Formatting is `dart format`'s business, so line breaks, indentation and
// trailing commas are stripped, but only outside string literals: a space or a
// comma inside a word is content.
final _stringLiteral = RegExp(r"'(?:[^'\\\n]|\\.)*'");
String _withoutLayout(String dart) {
  final out = StringBuffer();
  var last = 0;
  for (final m in _stringLiteral.allMatches(dart)) {
    out
      ..write(dart.substring(last, m.start).replaceAll(RegExp(r'[\s,]'), ''))
      ..write(m.group(0));
    last = m.end;
  }
  out.write(dart.substring(last).replaceAll(RegExp(r'[\s,]'), ''));
  return out.toString();
}

void main() {
  final data =
      jsonDecode(File(_source).readAsStringSync()) as Map<String, dynamic>;

  test('the data file passes the generator\'s validation', () {
    expect(gen.validate(data), isEmpty);
  });

  test('the generated vocabulary matches the data file', () {
    expect(
      _withoutLayout(File(_target).readAsStringSync()),
      _withoutLayout(gen.render(data)),
      reason:
          '$_target is out of date. Run: dart run tools/gen_tag_vocabulary.dart',
    );
  });

  test('a space inside a word counts as a change', () {
    expect(
      _withoutLayout("const a = <String>[\n  'foie gras',\n];"),
      isNot(_withoutLayout("const a = <String>['foiegras'];")),
    );
    expect(
      _withoutLayout("const a = <String>[\n  'foie gras',\n];"),
      _withoutLayout("const a = <String>['foie gras'];"),
    );
  });

  test('validation refuses a bad field name and a name generated twice', () {
    final errors = gen.validate({
      'a': {'Tag': 'x', 'bC': <String>[]},
      'aB': {'c': <String>[]},
    });
    expect(errors, hasLength(2));
  });

  test('validation refuses upper case, empty words and a reused tag', () {
    final errors = gen.validate({
      'a': {
        'tag': 'x',
        'words': ['Sill', ''],
      },
      'b': {'tag': 'x'},
    });
    expect(errors, hasLength(3));
  });
}
