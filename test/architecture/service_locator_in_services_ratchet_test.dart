// BUT-1508: a service gets what it needs through its constructor (or a
// closure for app/user-scoped things), not by reaching into ServiceLocator
// itself. Nothing in lib/services may look one up; the DI modules and the
// `*_from_locator.dart` helpers in lib/core/di are where lookups live.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/design_migration_census.dart' show stripComments;

final _lookup = RegExp(r'ServiceLocator\.(?:get|tryGet|isRegistered)\b');

void main() {
  test('no service looks up ServiceLocator', () {
    final offenders = <String>[];
    for (final entity in Directory('lib/services').listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final path = entity.path.replaceAll(r'\', '/');
      final n = _lookup
          .allMatches(stripComments(entity.readAsStringSync()))
          .length;
      if (n > 0) offenders.add('$path looks up ServiceLocator $n time(s)');
    }
    expect(
      offenders,
      isEmpty,
      reason: 'Take the dependency in the constructor.',
    );
  });
}
