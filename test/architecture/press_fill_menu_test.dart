// A popup menu's rows and a dropdown's rows take Theme.highlightColor and
// hoverColor and have no colour setting of their own, so every
// PopupMenuButton and DropdownButton under lib/ sits directly inside a
// PressFill: the menu route captures the themes around its button (BUT-2205;
// Malin 2026-10-04: menu rows and dropdown rows follow the same rule as rows).
// The menus open on surface.base, so the surface is base, or raised when the
// menu builds a ListTile, whose theme paints surface.raised.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/theme/app_theme.dart';

final _menu = RegExp(
  r'(?<![\w.])(PopupMenuButton|DropdownButtonFormField|DropdownButton)'
  r'(<[^>(]*>)?\(',
);

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

/// Whether [call] has the top-level argument [name].
bool _hasArgument(String call, String name) {
  var depth = 0;
  for (var i = 0; i < call.length; i++) {
    final c = call[i];
    if ('([{'.contains(c)) depth++;
    if (')]}'.contains(c)) depth--;
    final atStart = i == 0 || !RegExp(r'\w').hasMatch(call[i - 1]);
    if (depth == 1 && atStart && call.startsWith('$name:', i)) return true;
  }
  return false;
}

/// The menus in [code] that are not the direct `child:` argument of the
/// nearest enclosing `PressFill(`, whose PressFill names another surface than
/// their rows rest on, or that move their menu onto another surface.
List<String> menuFindings(String path, String code) {
  final found = <String>[];
  for (final m in _menu.allMatches(code)) {
    final before = code.substring(0, m.start);
    final where = '$path:${'\n'.allMatches(before).length + 1} ${m.group(1)}';
    final menu = _call(code, m.end - 1);
    if (_hasArgument(menu, 'color') || _hasArgument(menu, 'dropdownColor')) {
      found.add('$where sets its own menu colour');
    }
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
    final expected = RegExp(r'(?<![\w.])ListTile\(').hasMatch(menu)
        ? 'raised'
        : 'base';
    if (!RegExp(
      '^PressFill\\(\\s*surface:\\s*PressSurface\\.$expected\\s*,',
    ).hasMatch(code.substring(open))) {
      found.add('$where PressFill is not on PressSurface.$expected');
    }
  }
  return found;
}

void main() {
  test('every menu and dropdown under lib/ sits in a PressFill on the '
      'surface its rows rest on', () {
    final found = <String>[];
    var menus = 0;
    for (final f in Directory('lib').listSync(recursive: true)) {
      if (f is! File || !f.path.endsWith('.dart')) continue;
      final code = f.readAsStringSync().replaceAll(
        RegExp(r'(?<!:)//[^\n]*'),
        '',
      );
      menus += _menu.allMatches(code).length;
      found.addAll(menuFindings(f.path.replaceAll('\\', '/'), code));
    }
    expect(menus, greaterThan(0));
    expect(found, isEmpty);
  });

  test('the menus open on surface.base, as the scan assumes', () {
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final cs = theme.colorScheme;
      // A popup menu paints surfaceContainer when its theme sets no colour;
      // a dropdown menu paints canvasColor.
      expect(theme.popupMenuTheme.color, isNull);
      expect(cs.surfaceContainer, cs.surface);
      expect(theme.canvasColor, cs.surface);
      // Every ListTile paints a raised tile.
      expect(theme.listTileTheme.tileColor, cs.surfaceContainerHighest);
    }
  });

  group('the scan', () {
    test('passes a wrapped menu, a wrapped typed dropdown and a menu of '
        'ListTile rows on raised', () {
      for (final shape in [
        'PressFill(surface: PressSurface.base, child: PopupMenuButton())',
        ('PressFill(surface: PressSurface.base, '
            'child: DropdownButtonFormField<String>())'),
        ('PressFill(surface: PressSurface.raised, child: PopupMenuButton('
            'itemBuilder: (_) => [PopupMenuItem(child: ListTile())]))'),
      ]) {
        expect(menuFindings('x', shape), isEmpty, reason: shape);
      }
    });

    test('reports a bare menu, a menu after a closed PressFill, a wrong '
        'surface and a menu colour of its own', () {
      for (final shape in [
        'return DropdownButton<int>()',
        'PressFill(surface: s, child: a),\nPadding(child: PopupMenuButton())',
        'PressFill(surface: PressSurface.raised, child: PopupMenuButton())',
        ('PressFill(surface: PressSurface.base, child: PopupMenuButton('
            'itemBuilder: (_) => [PopupMenuItem(child: ListTile())]))'),
        ('PressFill(surface: PressSurface.base, '
            'child: PopupMenuButton(color: c))'),
        ('PressFill(surface: PressSurface.base, '
            'child: DropdownButton(dropdownColor: c))'),
      ]) {
        expect(menuFindings('x', shape), hasLength(1), reason: shape);
      }
    });
  });
}
