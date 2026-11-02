// BUT-1508: a service gets what it needs through its constructor (or a
// closure for app/user-scoped things), not by reaching into ServiceLocator
// itself. This ratchet holds the services that still do and how many times;
// a file may not gain a lookup, and a file that drops one lowers its row in
// the same change.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/design_migration_census.dart' show stripComments;

const _residue = <String, int>{
  'lib/services/analytics_service.dart': 1,
  'lib/services/attribution_source.dart': 1,
  'lib/services/deep_link_service.dart': 3,
  'lib/services/ocr_extraction_service.dart': 2,
  'lib/services/pwa_install_service_web.dart': 2,
  'lib/services/social/blocking/blocked_user_filter.dart': 1,
};

final _lookup = RegExp(r'ServiceLocator\.(?:get|tryGet|isRegistered)\b');

Map<String, int> _counts() {
  final out = <String, int>{};
  for (final entity in Directory('lib/services').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    final n = _lookup
        .allMatches(stripComments(entity.readAsStringSync()))
        .length;
    if (n > 0) out[path] = n;
  }
  return out;
}

void main() {
  final counts = _counts();

  test('no service gains a ServiceLocator lookup', () {
    final grown = [
      for (final e in counts.entries)
        if (e.value > (_residue[e.key] ?? 0))
          ('${e.key} looks up ServiceLocator ${e.value} time(s), residue '
              'allows ${_residue[e.key] ?? 0}. Take the dependency in the '
              'constructor instead.'),
    ];
    expect(grown, isEmpty);
  });

  test('the residue only shrinks: every row is still needed', () {
    final stale = [
      for (final e in _residue.entries)
        if ((counts[e.key] ?? 0) < e.value)
          ('${e.key} is down to ${counts[e.key] ?? 0} from ${e.value}. '
              'Lower the row.'),
    ];
    expect(stale, isEmpty);
  });
}
