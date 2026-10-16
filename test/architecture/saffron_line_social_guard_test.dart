// The saffron line under the top bar is off only in views that carry a
// profile header (friend profile, public profile) and in the feedback modal.
// Every other view keeps it (B-166).

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'only the profile-header views and one modal turn the saffron line off',
    () {
      const allowed = {
        'lib/views/social/friend_profile_view.dart',
        'lib/views/social/public_profile_view.dart',
        'lib/widgets/common/feedback_form_dialog.dart',
      };
      final off = RegExp(r'ruleUnderBar\s*:\s*false');
      final found = <String>[];
      for (final entity in Directory('lib').listSync(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        final path = entity.path.replaceAll(r'\', '/');
        if (off.hasMatch(entity.readAsStringSync()) &&
            !allowed.contains(path)) {
          found.add(path);
        }
      }

      expect(found, isEmpty);
      for (final path in allowed) {
        expect(
          off.hasMatch(File(path).readAsStringSync()),
          isTrue,
          reason: '$path turns the line off, so the allowance is still needed',
        );
      }
    },
  );

  test('Ny delad lista is a form and draws no bottom menu', () {
    final source = File(
      'lib/views/social/create_shared_shopping_list_view.dart',
    ).readAsStringSync();
    expect(source.contains('showTabBar: false'), isTrue);
  });
}
