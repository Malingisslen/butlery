// The saffron line under the top bar is off only in views that carry a
// profile header (friend profile, public profile). Every other social,
// family and chat view keeps it (megagenomgång F8).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('only the profile-header views turn the saffron line off', () {
    const allowed = {
      'lib/views/social/friend_profile_view.dart',
      'lib/views/social/public_profile_view.dart',
    };
    final off = RegExp(r'ruleUnderBar\s*:\s*false');
    final found = <String>[];
    for (final dir in [
      'lib/views/social',
      'lib/views/family',
      'lib/views/messaging',
    ]) {
      for (final entity in Directory(dir).listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (off.hasMatch(entity.readAsStringSync()) &&
            !allowed.contains(path)) {
          found.add(path);
        }
      }
    }
    final weekMenu = File('lib/views/group_weekly_menu_view.dart');
    if (off.hasMatch(weekMenu.readAsStringSync())) {
      found.add(weekMenu.path);
    }

    expect(found, isEmpty);
    for (final path in allowed) {
      expect(
        off.hasMatch(File(path).readAsStringSync()),
        isTrue,
        reason: '$path has a profile header, so the line stays off there',
      );
    }
  });

  test('Ny delad lista is a form and draws no bottom menu', () {
    final source = File(
      'lib/views/social/create_shared_shopping_list_view.dart',
    ).readAsStringSync();
    expect(source.contains('showTabBar: false'), isTrue);
  });
}
