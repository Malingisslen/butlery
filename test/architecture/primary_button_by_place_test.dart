// Malin's decision (megagenomgången): the primary button's colour follows the
// place. Saffron (HeroButton) opens a flow: Hem, sign-in, start cooking. Dark
// green (ActionButtons.primaryButton) is the button on forms and account
// pages. Files outside the flow starts that still draw a saffron button are
// pinned by count; the owning track lowers its number when it moves the view
// to the green button, and a new file cannot join the list.

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
  'lib/widgets/common/buttons/hero_button.dart',
};

const _notYetMoved = <String, int>{
  'lib/views/account/consent_management_view.dart': 1,
  'lib/views/account/data_export_view.dart': 2,
  'lib/views/account/pending_deletion_view.dart': 1,
  'lib/views/auth/guest_upgrade_view.dart': 1,
  'lib/views/auth/provider_link_view.dart': 1,
  'lib/views/auth/provider_terms_view.dart': 1,
  'lib/views/auth/set_new_password_view.dart': 2,
  'lib/views/cooking_mode_view.dart': 2,
  'lib/views/edit_recipe_view.dart': 1,
  'lib/views/family/household_portions_sheet.dart': 1,
  'lib/views/ingredient_search/ingredient_search_view.dart': 1,
  'lib/views/menu_placement_view.dart': 1,
  'lib/views/messaging/create_group_conversation_view.dart': 1,
  'lib/views/photo_import_view.dart': 1,
  'lib/views/quick_capture_view.dart': 1,
  'lib/views/realtime/conflict_diff_view.dart': 1,
  'lib/views/realtime/recipe_suggestion_view.dart': 1,
  'lib/views/settings/mfa_enrollment_forms.dart': 2,
  'lib/views/skriv_sjalv_recept_view.dart': 1,
  'lib/views/social/add_members_to_group_view.dart': 1,
  'lib/views/social/create_shared_shopping_list_view.dart': 1,
  'lib/views/social/friend_profile_view.dart': 1,
  'lib/views/social/friend_requests/friend_request_card.dart': 1,
  'lib/views/social/friend_requests/friend_requests_view.dart': 1,
  'lib/views/social/group_detail_view.dart': 1,
  'lib/views/social/menu_preview_view.dart': 1,
  'lib/views/social/user_profile_edit/preferences_sections.dart': 1,
  'lib/views/unified_shopping/widgets/shopping_app_bar.dart': 1,
  'lib/views/unified_shopping/widgets/shopping_list_content.dart': 1,
  'lib/widgets/common/feedback_form_dialog.dart': 1,
  'lib/widgets/common/navigation/add_sheet.dart': 1,
  'lib/widgets/common/profile/dialogs/profile_dialogs.dart': 1,
  'lib/widgets/menu/shopping_merge_sheet.dart': 1,
  'lib/widgets/menu/veckomeny_selection_widgets.dart': 1,
  'lib/widgets/social/public_profile_friend_button.dart': 2,
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
    expect(_heroOutsideFlowStarts(), _notYetMoved);
  });
}
