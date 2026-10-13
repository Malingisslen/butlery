// The top of a screen is chosen by kind of view, not by each view
// (.claude/rules/design-system.md, "The top of a screen"). A view builds its
// page with ButleryPage; it does not construct ButleryTopBar itself.
//
// The files below still do, from before the rule. The list only shrinks: move
// a view onto ButleryPage and delete its line. A file that no longer builds a
// bar fails here until its line is gone, so the list cannot go stale.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/design_migration_census.dart' show stripComments;

const _builtDirectly = {
  'lib/views/auth/mfa_challenge_view.dart',
  'lib/views/family/family_rating_entry_view.dart',
  'lib/views/notifications/notifications_view.dart',
  'lib/views/personal_tags_view.dart',
  'lib/views/photo_import_view.dart',
  'lib/views/quick_capture_view.dart',
  'lib/views/sync/sync_queue_view.dart',
  'lib/views/unified_shopping_view.dart',
  'lib/widgets/common/image/fullscreen_image_viewer.dart',
};

final _bar = RegExp(r'\bButleryTopBar\.(?:rot|undersida)\(');

const _theComponents = {
  'lib/widgets/common/butlery_top_bar.dart',
  'lib/widgets/common/layout/butlery_page.dart',
};

void main() {
  final builders = <String>{
    for (final dir in ['lib/views', 'lib/widgets', 'lib/core'])
      for (final entity in Directory(dir).listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart'))
          if (!_theComponents.contains(entity.path.replaceAll(r'\', '/')))
            if (_bar.hasMatch(stripComments(entity.readAsStringSync())))
              entity.path.replaceAll(r'\', '/'),
  };

  test('no new file builds its own top bar', () {
    expect(
      builders.difference(_builtDirectly),
      isEmpty,
      reason: 'Use ButleryPage (rot, undersida) instead of ButleryTopBar.',
    );
  });

  test('the list of files that build their own bar has no stale line', () {
    expect(
      _builtDirectly.difference(builders),
      isEmpty,
      reason: 'These files moved onto ButleryPage: delete their lines.',
    );
  });
}
