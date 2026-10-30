/// P7-U08 icon census (B-02; Q16 / Q-P7-15).
///
/// Every icon in lib/ is a Butlery glyph (ButleryIcons, rendered by
/// ButleryIcon) except the Material residue below: uses whose meaning has no
/// glyph in icons.json yet. The list only SHRINKS. When design draws a glyph
/// (design/icons.json + master in design/assets/icons, rerun
/// tools/generate_butlery_icons.dart), replace the uses and delete the rows.
/// A new Material icon, a larger count, or a row that no longer matches the
/// code fails this test, so the list always states the truth.
///
/// Also enforced: no CupertinoIcons and no AdaptiveIcon(s) anywhere in lib
/// and every icon is built with ButleryIcon, never a plain Icon.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// file -> Material icon name -> number of uses.
const Map<String, Map<String, int>> _residue = {};

/// Files allowed to build a plain Icon: the glyph widget itself.
const Set<String> _plainIconAllowed = {
  'lib/widgets/common/icons/butlery_glyph.dart',
};

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _rel(File f) => f.path.replaceAll(r'\', '/');

void main() {
  final materialUse = RegExp(r'(?<![\w.$])Icons\.(\w+)');

  test('Material icons in lib are exactly the shrinking residue', () {
    final actual = <String, Map<String, int>>{};
    for (final f in _dartFiles()) {
      for (final m in materialUse.allMatches(f.readAsStringSync())) {
        final names = actual.putIfAbsent(_rel(f), () => {});
        names[m.group(1)!] = (names[m.group(1)!] ?? 0) + 1;
      }
    }
    final problems = <String>[];
    for (final MapEntry(key: file, value: names) in actual.entries) {
      for (final MapEntry(key: name, value: count) in names.entries) {
        final allowed = _residue[file]?[name] ?? 0;
        if (count > allowed) {
          problems.add(
            '$file uses Icons.$name $count time(s), residue allows $allowed. '
            'Use a ButleryIcons glyph with the same meaning, or ask design '
            'for one (icons.json new_icons).',
          );
        }
      }
    }
    for (final MapEntry(key: file, value: names) in _residue.entries) {
      for (final MapEntry(key: name, value: allowed) in names.entries) {
        final count = actual[file]?[name] ?? 0;
        if (count < allowed) {
          problems.add(
            '$file: Icons.$name is down to $count from $allowed. Shrink '
            'the residue row to $count.',
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('no CupertinoIcons or AdaptiveIcon(s) in lib', () {
    final banned = RegExp(r'\bCupertinoIcons\.|\bAdaptiveIcons?[.(]');
    final hits = [
      for (final f in _dartFiles())
        if (banned.hasMatch(f.readAsStringSync())) _rel(f),
    ];
    expect(hits, isEmpty);
  });

  test('icons are built with ButleryIcon, not a plain Icon', () {
    final plainIcon = RegExp(r'(?<![\w.$])Icon\(');
    final hits = [
      for (final f in _dartFiles())
        if (!_plainIconAllowed.contains(_rel(f)) &&
            plainIcon.hasMatch(f.readAsStringSync()))
          _rel(f),
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'A ButleryGlyph has no font; wrap it in '
          'ButleryIcon (lib/widgets/common/icons/butlery_glyph.dart).',
    );
  });
}
