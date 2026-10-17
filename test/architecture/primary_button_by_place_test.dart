// Malin's decision (megagenomgången): the primary button's colour follows the
// place. Saffron (HeroButton) opens a flow: Hem, sign-in, start cooking. Dark
// green (FormButton) is the button on forms and account
// pages. A file outside the flow starts cannot draw a saffron
// button.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _flowStarts = <String>{
  'lib/views/hem/hem_empty_state.dart',
  'lib/views/hem/hem_section.dart',
  'lib/views/auth_view.dart',
  'lib/views/auth/guest_start_view.dart',
  'lib/views/auth/mfa_challenge_view.dart',
  'lib/views/recipe_detail/recipe_detail_hero_buttons.dart',
  'lib/views/recipe_detail_view.dart',
  // Dark focus mode: the sketch draws a saffron "Nästa steg" on the ink surface,
  // where the ink form button would disappear.
  'lib/views/cooking_mode_view.dart',
  'lib/widgets/common/buttons/hero_button.dart',
};

// Friend-request and friend-profile buttons that the sketch draws in saffron
// under B-75 (Acceptera on every request row) and B-76 (one saffron action on
// the friend profile). B-169 keeps them saffron as drawn; the pins keep the
// list from growing.
const _friendButtons = <String, int>{
  'lib/views/social/friend_profile_view.dart': 1,
  'lib/views/social/friend_requests/friend_request_card.dart': 1,
  'lib/views/social/friend_requests/friend_requests_view.dart': 1,
  'lib/widgets/social/public_profile_friend_button.dart': 2,
};

// The Inköp add button and its empty-state button are drawn saffron on the
// shopping-list sketch frame, and a list is neither a form nor an account page,
// so B-158 does not move them. They wait for Malin's call.
const _shoppingButtons = <String, int>{
  'lib/views/unified_shopping/widgets/shopping_app_bar.dart': 1,
  'lib/views/unified_shopping/widgets/shopping_list_content.dart': 1,
};

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

final _hero = RegExp(r'\bHeroButton\s*\(');

Map<String, int> _heroOutsideFlowStarts() {
  final counts = <String, int>{};
  for (final root in ['lib/views', 'lib/widgets']) {
    for (final file in Directory(root).listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll(r'\', '/');
      if (_flowStarts.contains(path)) continue;
      final n = _hero.allMatches(_code(path)).length;
      if (n > 0) counts[path] = n;
    }
  }
  return counts;
}

void main() {
  test('the saffron button is drawn only where a flow starts', () {
    for (final path in _flowStarts) {
      expect(
        File(path).existsSync(),
        isTrue,
        reason: '$path moved; update the list',
      );
    }
    expect(_heroOutsideFlowStarts(), {..._friendButtons, ..._shoppingButtons});
  });
}
