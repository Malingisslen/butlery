// A chip takes Theme.highlightColor and hoverColor for its press and has no
// colour setting of its own, so every chip under lib/ sits directly inside a
// PressFill that names the surface it rests on (BUT-2205; Malin 2026-10-04:
// chips follow the same rule as rows). The surface is derived from the chip's
// own colours, so a flipped or wrong surface is caught as well as a missing
// wrapper.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

final _chip = RegExp(
  r'(?<![\w.])(FilterChip|ChoiceChip|ActionChip|InputChip|RawChip|Chip)(\.\w+)?\(',
);

/// The text of the call's own top-level argument [name], or null.
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

String _squash(String s) => s.replaceAll(RegExp(r'\s+'), '');

/// The surface a chip fill rests on, from the colour expression that paints it.
String? _surfaceOf(String? colour, String fallback) {
  if (colour == null) return fallback;
  final c = _squash(colour);
  if (c.endsWith('.primaryContainer')) return 'raised';
  if (c.endsWith('.surfaceContainerHighest')) return 'raised';
  if (c.endsWith('.primary')) return 'ink';
  if (c.endsWith('.surface')) return 'base';
  // errorContainer is the raised value in both schemes (app_colors.dart).
  if (c.endsWith('.errorContainer')) return 'raised';
  return null;
}

/// The `surface:` expression a chip call must be given, or null when its
/// colours are not ones this guard knows how to read.
String? expectedSurface(String chipCall) {
  final selected = _argument(chipCall, 'selected');
  final background = _argument(chipCall, 'backgroundColor');
  String s(String x) => 'PressSurface.$x';
  String pick(String condition, String a, String b) =>
      a == b ? s(a) : '$condition?${s(a)}:${s(b)}';

  final conditional = background == null
      ? null
      : RegExp(r'^(.+?)\?(.+):(.+)$').firstMatch(_squash(background));
  if (selected != null && selected != 'false') {
    final whenSelected = _surfaceOf(
      _argument(chipCall, 'selectedColor'),
      'ink',
    );
    final whenUnselected = conditional != null
        ? _surfaceOf(conditional.group(3), 'base')
        : _surfaceOf(background, 'base');
    if (whenSelected == null || whenUnselected == null) return null;
    return pick(_squash(selected), whenSelected, whenUnselected);
  }
  if (conditional != null) {
    final a = _surfaceOf(conditional.group(2), 'base');
    final b = _surfaceOf(conditional.group(3), 'base');
    if (a == null || b == null) return null;
    return pick(conditional.group(1)!, a, b);
  }
  final only = _surfaceOf(background, 'base');
  return only == null ? null : s(only);
}

/// The chips in [code] that are not the direct `child:` argument of the
/// nearest enclosing `PressFill(`, or whose PressFill names another surface
/// than the chip's own colours give.
List<String> chipFindings(String path, String code) {
  final found = <String>[];
  for (final m in _chip.allMatches(code)) {
    // A plain Chip only presses through its delete button.
    if (m.group(1) == 'Chip' &&
        !_call(code, m.end - 1).contains('onDeleted:')) {
      continue;
    }
    final before = code.substring(0, m.start);
    final where = '$path:${'\n'.allMatches(before).length + 1} ${m.group(1)}';
    final open = before.lastIndexOf('PressFill(');
    var depth = 0;
    var closed = false;
    if (open >= 0) {
      for (final c in before.substring(open + 'PressFill'.length).split('')) {
        if ('([{'.contains(c)) depth++;
        if (')]}'.contains(c)) depth--;
        if (depth == 0) closed = true;
      }
    }
    final wrapped =
        open >= 0 &&
        !closed &&
        depth == 1 &&
        RegExp(r'child:\s*$').hasMatch(before);
    if (!wrapped) {
      found.add('$where not inside a PressFill');
      continue;
    }
    final pressFill = _call(code, open + 'PressFill'.length);
    final chip = _call(code, m.end - 1);
    final expected = expectedSurface(chip);
    final actual = _squash(_argument(pressFill, 'surface') ?? '');
    if (expected == null) {
      found.add('$where has colours the guard cannot read');
    } else if (actual != expected) {
      found.add('$where surface $actual, expected $expected');
    }
  }
  return found;
}

void main() {
  test(
    'every chip under lib/ sits inside a PressFill with its own surface',
    () {
      final found = <String>[];
      var chips = 0;
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final code = f.readAsStringSync().replaceAll(
          RegExp(r'(?<!:)//[^\n]*'),
          '',
        );
        chips += _chip.allMatches(code).length;
        found.addAll(chipFindings(f.path.replaceAll('\\', '/'), code));
      }
      expect(chips, greaterThan(0));
      expect(found, isEmpty);
    },
  );

  group('the scan', () {
    test('passes a chip wrapped with the surface its colours give', () {
      for (final shape in [
        'PressFill(surface: PressSurface.base, child: ActionChip(label: a))',
        ('PressFill(surface: on ? PressSurface.ink : PressSurface.base, '
            'child: FilterChip(selected: on, label: a))'),
        ('PressFill(surface: on ? PressSurface.raised : PressSurface.base, '
            'child: FilterChip(selected: on, '
            'selectedColor: cs.surfaceContainerHighest, '
            'backgroundColor: cs.surface))'),
        ('PressFill(surface: mine ? PressSurface.raised : PressSurface.base, '
            'child: InputChip(backgroundColor: mine ? cs.primaryContainer : '
            'cs.surface))'),
      ]) {
        expect(chipFindings('x', shape), isEmpty, reason: shape);
      }
    });

    test('reports a bare chip and a chip after a closed PressFill', () {
      expect(chipFindings('x', 'return ActionChip(label: a)'), hasLength(1));
      expect(
        chipFindings(
          'x',
          'PressFill(surface: s, child: a),\nPadding(child: FilterChip(label: a))',
        ),
        hasLength(1),
      );
    });

    test('reports a flipped, a constant and a mismatched surface', () {
      for (final shape in [
        ('PressFill(surface: on ? PressSurface.base : PressSurface.ink, '
            'child: FilterChip(selected: on, label: a))'),
        ('PressFill(surface: PressSurface.base, '
            'child: FilterChip(selected: on, label: a))'),
        ('PressFill(surface: on ? PressSurface.ink : PressSurface.base, '
            'child: FilterChip(selected: on, '
            'selectedColor: cs.surfaceContainerHighest))'),
        ('PressFill(surface: other ? PressSurface.ink : PressSurface.base, '
            'child: FilterChip(selected: on, label: a))'),
      ]) {
        expect(chipFindings('x', shape), hasLength(1), reason: shape);
      }
    });

    test('reads a plain Chip only when it can be deleted', () {
      expect(chipFindings('x', 'return Chip(label: a)'), isEmpty);
      expect(
        chipFindings('x', 'return Chip(label: a, onDeleted: remove)'),
        hasLength(1),
      );
    });

    test('reports a named constructor too', () {
      expect(
        chipFindings('x', 'return FilterChip.elevated(label: a)'),
        hasLength(1),
      );
    });
  });
}
