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
  'lib/views/account/consent_management_view.dart': 7,
  'lib/views/account/data_export_view.dart': 2,
  'lib/views/legal/privacy_policy_view.dart': 2,
  'lib/views/messaging/chat_view/chat_input_section.dart': 1,
  'lib/views/onboarding/onboarding_import_page.dart': 2,
  'lib/views/personal_tags/personal_tag_widgets.dart': 2,
  'lib/views/photo_import/heirloom_section.dart': 2,
  'lib/views/photo_import_view.dart': 2,
  'lib/views/realtime/conflict_diff_view.dart': 2,
  'lib/views/receive_share_view.dart': 2,
  'lib/views/recipe_detail/recipe_detail_content.dart': 10,
  'lib/views/settings/allergen_preferences_view.dart': 2,
  'lib/views/social/add_members_to_group_view.dart': 1,
  'lib/views/social/collaborative_shopping/collaborative_shopping_actions.dart':
      1,
  'lib/views/social/collaborative_shopping/collaborative_shopping_header.dart':
      2,
  'lib/views/social/collaborative_shopping/collaborative_shopping_items.dart':
      3,
  'lib/views/social/create_shared_shopping_list_view.dart': 4,
  'lib/views/social/friend_requests/friend_request_builders.dart': 4,
  'lib/views/social/friend_requests/friend_request_card.dart': 1,
  'lib/views/social/friends_list/friends_list_cards.dart': 1,
  'lib/views/social/friends_list/group_invitation_card.dart': 4,
  'lib/views/social/friends_list/requests_tab.dart': 2,
  'lib/views/social/friends_list_view.dart': 2,
  'lib/views/social/group_detail/group_invitation_card.dart': 2,
  'lib/views/social/user_profile_edit/preferences_sections.dart': 2,
  'lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart':
      3,
  'lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart':
      5,
  'lib/views/unified_shopping/widgets/shopping_app_bar.dart': 4,
  'lib/views/unified_shopping/widgets/shopping_item_tiles.dart': 2,
  'lib/views/unified_shopping/widgets/shopping_list_header.dart': 1,
  'lib/widgets/branding/app_logo.dart': 1,
  'lib/widgets/common/content_cards/menu_card.dart': 2,
  'lib/widgets/common/content_cards/shopping_list_card.dart': 4,
  'lib/widgets/common/emoji_reaction_display.dart': 1,
  'lib/widgets/common/filter_status_chip.dart': 2,
  'lib/widgets/common/indicators/admin_badge.dart': 1,
  'lib/widgets/common/indicators/emoji_avatar.dart': 1,
  'lib/widgets/common/indicators/progress_overlay.dart': 1,
  'lib/widgets/common/indicators/realtime_status_widgets.dart': 1,
  'lib/widgets/common/indicators/status_indicator.dart': 1,
  'lib/widgets/common/input/portion_scaler_ui.dart': 1,
  'lib/widgets/common/loading/loading_widgets.dart': 3,
  'lib/widgets/common/menu_persistence/menu_load_dialog.dart': 1,
  'lib/widgets/common/menu_persistence/menu_save_dialog.dart': 1,
  'lib/widgets/common/permissions/permission_widgets.dart': 1,
  'lib/widgets/common/profile/builders/menu_item_builders.dart': 2,
  'lib/widgets/common/profile/builders/profile_section_builders.dart': 1,
  'lib/widgets/common/profile/profile_menu.dart': 1,
  'lib/widgets/common/scaffolds/empty_state_scaffold.dart': 1,
  'lib/widgets/common/search_filter/search_stats_widget.dart': 2,
  'lib/widgets/common/service/service_widgets.dart': 3,
  'lib/widgets/cooking/inline_timer_text.dart': 1,
  'lib/widgets/image/avatar_image_widget.dart': 1,
  'lib/widgets/image/components/upload_progress_widgets.dart': 6,
  'lib/widgets/image/recipe_image_widget.dart': 1,
  'lib/widgets/import/components/add_item_field.dart': 1,
  'lib/widgets/import/confidence_indicator.dart': 6,
  'lib/widgets/import/platform_badge_widget.dart': 6,
  'lib/widgets/import/text_line_selector.dart': 1,
  'lib/widgets/menu/calendar/calendar_drag.dart': 1,
  'lib/widgets/menu/menu_content_widgets.dart': 1,
  'lib/widgets/messaging/builders/message_content_builder.dart': 1,
  'lib/widgets/messaging/poll_message_widget.dart': 6,
  'lib/widgets/recipe/comment_item_widgets.dart': 2,
  'lib/widgets/recipe/duplicate_merge_sheet.dart': 1,
  'lib/widgets/recipe/ingredient_substitution_sheet.dart': 2,
  'lib/widgets/recipe/recipe_card.dart': 11,
  'lib/widgets/recipe/recipe_shelf.dart': 2,
  'lib/widgets/recipe/related_recipes_editor.dart': 2,
  'lib/widgets/recipe/related_recipes_picker_dialog.dart': 1,
  'lib/widgets/social/collaborative/components/collaborative_connection_widgets.dart':
      3,
  'lib/widgets/social/collaborative/components/collaborative_live_widgets.dart':
      2,
  'lib/widgets/social/collaborative/components/collaborative_participants_widgets.dart':
      2,
  'lib/widgets/social/collaborative/components/collaborative_permissions_widgets.dart':
      2,
  'lib/widgets/social/collaborative/components/collaborative_status_widgets.dart':
      4,
  'lib/widgets/social/groups/group_shared_content_section.dart': 1,
  'lib/widgets/social/groups/shared/group_dialog_components.dart': 3,
  'lib/widgets/social/groups/shared_content_card.dart': 2,
  'lib/widgets/tagging/personal_tag_rule_dialog.dart': 2,
  'lib/widgets/tagging/personal_tag_selector.dart': 3,
  'lib/widgets/tagging/tag_detail_header.dart': 1,
  'lib/widgets/tagging/tag_result_display.dart': 2,
  'lib/widgets/tagging/tag_status_badge.dart': 2,
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
