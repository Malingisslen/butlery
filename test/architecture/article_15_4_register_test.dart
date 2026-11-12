// BUT-1811: the Art. 15(4) balancing decisions must be producible from
// docs/security, not only from the deviation files. This holds the register to
// the always-on deviation list, so a new export decision cannot land without
// its ticket id in the register.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _registerPath = 'docs/security/article-15-4-balancing-register.md';
const _rulesPath = '.claude/rules/accepted-deviations.md';
const _rationalePath = 'docs/architecture/ACCEPTED_DEVIATIONS.md';

final _id = RegExp(r'\b(?:BUT|ADR)-\d+\b');
final _aboutExport = RegExp(
  r'art\. 15|export|bundle|gdpr section',
  caseSensitive: false,
);

Set<String> _ids(String text) =>
    _id.allMatches(text).map((m) => m.group(0)!).toSet();

void main() {
  final register = File(_registerPath).readAsStringSync();
  final registerIds = _ids(register);

  test('every export line in the deviation list has an id in the register', () {
    final missing = <String>[];
    var parentIds = <String>{};
    for (final line in File(_rulesPath).readAsLinesSync()) {
      final isTopLevel = line.startsWith('- ');
      final isNested = line.startsWith('  - ');
      if (!isTopLevel && !isNested) continue;
      final own = _ids(line);
      if (isTopLevel) parentIds = own;
      if (!_aboutExport.hasMatch(line)) continue;
      // A sub-bullet carries its parent's ticket implicitly.
      final ids = isNested ? {...own, ...parentIds} : own;
      if (ids.intersection(registerIds).isEmpty) {
        missing.add(line.trim());
      }
    }
    expect(
      missing,
      isEmpty,
      reason:
          'Add these export decisions to $_registerPath (a row, or the '
          '"not about other people" list):\n${missing.join('\n')}',
    );
  });

  test('every id in the register is a recorded decision', () {
    final recorded = {
      ..._ids(File(_rulesPath).readAsStringSync()),
      ..._ids(File(_rationalePath).readAsStringSync()),
      for (final f in Directory('docs/org/adr').listSync())
        ..._ids(f.uri.pathSegments.last),
    };
    expect(registerIds.difference(recorded), isEmpty);
  });

  test('every file the register cites exists', () {
    final cited = RegExp(
      r'`(docs/[^`]+\.md)`',
    ).allMatches(register).map((m) => m.group(1)!);
    final absent = cited.where((p) => !File(p).existsSync()).toList();
    expect(absent, isEmpty);
  });
}
