// BUT-2183: the old opacity steps (AppDimensions.opacity*) leave the app for
// the design system's tokens, per the per-step mapping that Malin's B83
// decisions settle (Butlery design system fas2/produktbeslut-2026-09-30.json).
// This ratchet holds the files that still use a step and how many times; a
// file may not gain a use, and a file that drops one lowers its row in the
// same change.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/design_migration_census.dart' show stripComments;

const _residue = <String, int>{
  'lib/theme/components/feedback_themes.dart': 1,
  'lib/theme/components/input_themes.dart': 6,
  'lib/widgets/common/indicators/progress_overlay.dart': 1,
  'lib/widgets/common/loading/loading_widgets.dart': 1,
  'lib/widgets/common/service/service_widgets.dart': 1,
  'lib/widgets/menu/calendar/calendar_drag.dart': 1,
};

// Aligned with symbolSpecs' 'AppDimensions.opacity*' pattern in
// design_migration_census.dart.
final _step = RegExp(r'\bAppDimensions\.opacity\w+');

Map<String, int> _counts() {
  final out = <String, int>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path == 'lib/theme/app_dimensions.dart') continue;
    // Comments stripped (line, trailing and block), string contents kept —
    // the same scanner the census uses, so a use quoted in a comment is
    // never counted here or there.
    final code = stripComments(entity.readAsStringSync());
    final n = _step.allMatches(code).length;
    if (n > 0) out[path] = n;
  }
  return out;
}

String _grownMessage(String file, int actual, int allowed) =>
    '$file uses AppDimensions.opacity* $actual time(s), residue allows '
    '$allowed. Use the token the B83 mapping names instead.';

String _staleMessage(String file, int actual, int allowed) =>
    '$file is down to $actual from $allowed. Lower the row.';

void main() {
  final counts = _counts();

  test('no file gains an old opacity step', () {
    final grown = [
      for (final e in counts.entries)
        if (e.value > (_residue[e.key] ?? 0))
          _grownMessage(e.key, e.value, _residue[e.key] ?? 0),
    ];
    expect(grown, isEmpty);
  });

  test('the residue only shrinks: every row is still needed', () {
    final stale = [
      for (final e in _residue.entries)
        if ((counts[e.key] ?? 0) < e.value)
          _staleMessage(e.key, counts[e.key] ?? 0, e.value),
    ];
    expect(stale, isEmpty);
  });
}
