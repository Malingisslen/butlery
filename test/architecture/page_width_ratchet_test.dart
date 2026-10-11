// BUT-2368: a page takes its width from ButleryPageBody (PageWidth), never
// from its own number. This ratchet holds the views that still set one and
// how many times; a file may not gain one, and a file that drops one lowers
// its row in the same change.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/design_migration_census.dart' show stripComments;

const _residue = <String, int>{
  'lib/views/auth/set_new_password_view.dart': 1,
  'lib/views/auth_view.dart': 1,
  'lib/views/cooking_mode_view.dart': 1,
  'lib/views/edit_recipe_view.dart': 2,
  'lib/views/fran_sociala_medier_view.dart': 1,
  'lib/views/importera_fran_arkiv_view.dart': 1,
  'lib/views/more/more_view.dart': 1,
  'lib/views/photo_import_view.dart': 1,
  'lib/views/quick_capture_view.dart': 1,
  'lib/views/recipe_detail_view.dart': 2,
  'lib/views/skriv_sjalv_recept_view.dart': 2,
  'lib/views/smart_import_view.dart': 1,
  'lib/views/social/menu_preview_view.dart': 1,
  'lib/views/social/public_profile_view.dart': 1,
  'lib/views/unified_shopping_view.dart': 2,
  'lib/views/veckomeny_view.dart': 1,
};

// A literal (`maxWidth: 600`) or a breakpoint pick written in the view
// (`maxWidth: LayoutComponents.valueFor(`).
final _ownWidth = RegExp(
  r'maxWidth:\s*(?:\d|(?:LayoutComponents|Breakpoints)\.valueFor\b)',
);

Map<String, int> _counts() {
  final out = <String, int>{};
  for (final entity in Directory('lib/views').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    final code = stripComments(entity.readAsStringSync());
    final n = _ownWidth.allMatches(code).length;
    if (n > 0) out[path] = n;
  }
  return out;
}

void main() {
  final counts = _counts();

  test('no view gains a width of its own', () {
    final grown = [
      for (final e in counts.entries)
        if (e.value > (_residue[e.key] ?? 0))
          ('${e.key} sets maxWidth itself ${e.value} time(s), residue allows '
              '${_residue[e.key] ?? 0}. Wrap the page in ButleryPageBody and '
              'pick a PageWidth instead.'),
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
