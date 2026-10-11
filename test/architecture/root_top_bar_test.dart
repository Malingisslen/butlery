// BUT-2368: the root bar belongs to the main tabs. Every other page is a
// subpage and gets ButleryTopBar.undersida (Komponentark v1 §01: "Inga andra
// varianter"). A new root bar means a new main tab, so it is added here on
// purpose or not at all.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/design_migration_census.dart' show stripComments;

const _rootBarFiles = {
  // The template itself, for ButleryPage.rot.
  'lib/widgets/common/layout/butlery_page.dart',
  'lib/views/veckomeny_view.dart',
  'lib/views/unified_shopping_view.dart',
  'lib/views/more/more_view.dart',
  // Hem in selection mode (B-46): the counter and the bulk actions.
  'lib/views/mina_recept/selection_app_bar.dart',
};

final _rootBar = RegExp(r'\b(?:ButleryTopBar|ButleryPage)\.rot\(');

void main() {
  test('only the main tabs draw the root bar', () {
    final offenders = <String>[];
    for (final dir in ['lib/views', 'lib/widgets']) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (path == 'lib/widgets/common/butlery_top_bar.dart') continue;
        if (_rootBarFiles.contains(path)) continue;
        if (_rootBar.hasMatch(stripComments(entity.readAsStringSync()))) {
          offenders.add(path);
        }
      }
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'A page that is not a main tab uses ButleryPage.undersida '
          '(ButleryTopBar.undersida).',
    );
  });
}
