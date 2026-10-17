// Ratchet over design/beslutslogg.md: every locked decision is named by id (or by
// its question alias, such as Q5-07) in some test or tool, or sits in
// [_notNamed] below. Naming a decision is the minimum, not proof that its test
// is sound; the list exists so a new decision cannot be locked without either
// a test that names it or a visible entry here, and so a decision that gets a
// test must leave the list.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// Decisions that no test or tool names today. Product and process decisions
// belong here when nothing in the code can measure them.
const _notNamed = <String>{
  'B-05',
  'B-06',
  'B-10',
  'B-11',
  'B-13',
  'B-22',
  'B-23',
  'B-25',
  'B-26',
  'B-28',
  'B-29',
  'B-30',
  'B-31',
  'B-35',
  'B-37',
  'B-49',
  'B-66',
  'B-67',
  'B-68',
  'B-69',
  'B-70',
  'B-71',
  'B-72',
  'B-73',
  'B-74',
  'B-77',
  'B-78',
  'B-79',
  'B-80',
  'B-81',
  'B-82',
  'B-83',
  'B-84',
  'B-85',
  'B-90',
  'B-91',
  'B-92',
  'B-97',
  'B-98',
  'B-100',
  'B-105',
  'B-106',
  'B-107',
  'B-112',
  'B-113',
  'B-116',
  'B-128',
  'B-130',
  'B-138',
  'B-156',
  'B-157',
  'B-159',
  'B-160',
  'B-163',
  'B-164',
  'B-168',
};

final _token = RegExp(r'[A-Z]{1,3}[0-9]*-[A-Za-z0-9]+');

Set<String> _namesInTestsAndTools() {
  final names = <String>{};
  for (final root in ['test', 'tools']) {
    for (final entity in Directory(root).listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      // This file lists the ids it excludes, so it cannot count as naming them.
      if (entity.path
          .replaceAll('\\', '/')
          .endsWith(
            'architecture/decision_coverage_test.dart',
          )) {
        continue;
      }
      for (final m in _token.allMatches(entity.readAsStringSync())) {
        names.add(m.group(0)!);
      }
    }
  }
  return names;
}

void main() {
  test('every locked decision is named by a test or listed in _notNamed', () {
    final log = File('design/beslutslogg.md').readAsStringSync();
    final rows = RegExp(
      r'^\| (B-\d+) \| (.*)$',
      multiLine: true,
    ).allMatches(log).toList();
    expect(rows.length, greaterThan(150), reason: 'the log lost its rows');

    final names = _namesInTestsAndTools();
    final unnamed = <String>{};
    for (final row in rows) {
      final id = row.group(1)!;
      final question = row.group(2)!.split('|').first;
      final aliases = RegExp(
        r'\*\*([A-Z]{1,3}[0-9]*-\w+)\*\*',
      ).allMatches(question).map((m) => m.group(1)!);
      if (![id, ...aliases].any(names.contains)) unnamed.add(id);
    }

    expect(
      unnamed.difference(_notNamed),
      isEmpty,
      reason: 'a decision no test names: add a test that cites it, or list it',
    );
    expect(
      _notNamed.difference(unnamed),
      isEmpty,
      reason: 'now named by a test: remove it from _notNamed',
    );
  });
}
