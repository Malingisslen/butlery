// The input theme gives a filled field the hover of the surface it fills:
// fields fill surface.raised, so hover takes the step on raised (BUT-2205).
// A field that fills another colour must say its own hover, or it inherits
// the raised step: on a field that fills the page colour, that step equals
// the page in dark mode and the hover disappears.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _decoration = RegExp(r'(?<![\w.])InputDecoration\(');

/// The call that opens at [open] (the index of its `(`), parentheses included.
String _call(String code, int open) {
  var depth = 0;
  for (var i = open; i < code.length; i++) {
    if ('([{'.contains(code[i])) depth++;
    if (')]}'.contains(code[i])) depth--;
    if (depth == 0) return code.substring(open, i + 1);
  }
  return code.substring(open);
}

/// The text of [call]'s own top-level argument [name], or null.
String? _argument(String call, String name) {
  var depth = 0;
  for (var i = 0; i < call.length; i++) {
    final c = call[i];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    final atStart = i == 0 || !RegExp(r'\w').hasMatch(call[i - 1]);
    if (depth == 1 && atStart && call.startsWith('$name:', i)) {
      var j = i + name.length + 1;
      var inner = 0;
      while (j < call.length) {
        final d = call[j];
        if ('([{'.contains(d)) inner++;
        if (')]}'.contains(d)) {
          if (inner == 0) break;
          inner--;
        }
        if (d == ',' && inner == 0) break;
        j++;
      }
      return call.substring(i + name.length + 1, j).trim();
    }
  }
  return null;
}

/// The decorations in [code] that fill something other than surface.raised
/// and set no hover of their own.
List<String> fieldFindings(String path, String code) {
  final found = <String>[];
  for (final m in _decoration.allMatches(code)) {
    final call = _call(code, m.end - 1);
    final fill = _argument(call, 'fillColor');
    if (fill == null) continue;
    final raised = RegExp(r'\.surfaceContainerHighest$').hasMatch(
      fill.replaceAll(RegExp(r'\s+'), ''),
    );
    if (!raised && _argument(call, 'hoverColor') == null) {
      final line = '\n'.allMatches(code.substring(0, m.start)).length + 1;
      found.add('$path:$line fills $fill with no hoverColor');
    }
  }
  return found;
}

void main() {
  test('a field that fills another surface than raised sets its own hover', () {
    final found = <String>[];
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final code = f.readAsStringSync().replaceAll(
        RegExp(r'(?<!:)//[^\n]*'),
        '',
      );
      found.addAll(fieldFindings(f.path.replaceAll('\\', '/'), code));
    }
    expect(found, isEmpty);
  });

  test('the scan reports only a non-raised fill without a hover', () {
    expect(
      fieldFindings(
        'x',
        'InputDecoration(filled: true, fillColor: cs.surface)',
      ),
      hasLength(1),
    );
    expect(
      fieldFindings(
        'x',
        'InputDecoration(fillColor: cs.surface, hoverColor: cs.surfaceContainerHighest)',
      ),
      isEmpty,
    );
    expect(
      fieldFindings(
        'x',
        'InputDecoration(fillColor: cs.surfaceContainerHighest)',
      ),
      isEmpty,
    );
    expect(fieldFindings('x', 'InputDecoration(hintText: a)'), isEmpty);
  });
}
