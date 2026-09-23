// Package 4, track 4 (P4-U12..P4-U15, P4-U17, P3-U10): the social,
// messaging, settings, legal, auth, onboarding and admin views adopt the
// design system.
//
// B-18 (beslutslogg.md:25) and produktregler.md:163: no spinner, no sliding
// bar; the plate line plus text, so a page loading state names what it
// fetches. B-45 (beslutslogg.md:52): one top bar on both platforms, so these
// views draw ButleryTopBar, never a Material AppBar, SliverAppBar or
// AdaptiveAppBar. Komponentark v1:300 and :745-750: a snackbar is the ink
// snackbar and never a filled status colour, so no view builds its own
// SnackBar with a backgroundColor.
//
// This test reddens when one of those comes back into a file this track
// cleaned.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _files = [
  'lib/admin_main.dart',
  'lib/views/account/consent_management_view.dart',
  'lib/views/account/data_export_view.dart',
  'lib/views/admin/admin_shell.dart',
  'lib/views/admin/feedback_inbox_view.dart',
  'lib/views/admin/metric_tab_view.dart',
  'lib/views/admin/moderator_review_view.dart',
  'lib/views/admin/ops_log_view.dart',
  'lib/views/admin/parsing_details_view.dart',
  'lib/views/admin/widgets/metric_drilldown.dart',
  'lib/views/auth_view.dart',
  'lib/views/faq_view.dart',
  'lib/views/legal/community_guidelines_view.dart',
  'lib/views/legal/privacy_policy_view.dart',
  'lib/views/legal/terms_of_service_view.dart',
  'lib/views/messaging/chat_view/chat_action_handler.dart',
  'lib/views/messaging/chat_view/chat_view_facade.dart',
  'lib/views/messaging/conversation_group_detail_view.dart',
  'lib/views/messaging/create_group_conversation_view.dart',
  'lib/views/notifications/notifications_view.dart',
  'lib/views/onboarding/onboarding_age_gate_blocked_view.dart',
  'lib/views/onboarding/onboarding_import_page.dart',
  'lib/views/onboarding/onboarding_view.dart',
  'lib/views/realtime/conflict_diff_view.dart',
  'lib/views/settings/about_butlery_view.dart',
  'lib/views/settings/account_security_view.dart',
  'lib/views/settings/allergen_preferences_view.dart',
  'lib/views/settings/collection_stats_view.dart',
  'lib/views/settings/household_size_view.dart',
  'lib/views/settings/licenses_view.dart',
  'lib/views/settings/mfa_settings_view.dart',
  'lib/views/settings/my_reports_view.dart',
  'lib/views/settings/notification_preferences_view.dart',
  'lib/views/settings/settings_hub_view.dart',
  'lib/views/social/add_members_to_group_view.dart',
  'lib/views/social/collaborative_shopping/collaborative_shopping_actions.dart',
  'lib/views/social/collaborative_shopping/collaborative_shopping_header.dart',
  'lib/views/social/create_shared_shopping_list_view.dart',
  'lib/views/social/friend_profile_view.dart',
  'lib/views/social/friend_requests/friend_request_builders.dart',
  'lib/views/social/friend_requests/friend_request_card.dart',
  'lib/views/social/friends_list/feed_tab.dart',
  'lib/views/social/friends_list/search_result_card.dart',
  'lib/views/social/friends_list_view.dart',
  'lib/views/social/group_detail/group_detail_actions.dart',
  'lib/views/social/group_detail/group_detail_app_bar.dart',
  'lib/views/social/group_detail/group_invitation_card.dart',
  'lib/views/social/group_detail_view.dart',
  'lib/views/social/menu_preview_view.dart',
  'lib/views/social/public_profile_view.dart',
  'lib/views/social/shared_with_me/shared_content_actions.dart',
  'lib/views/social/shared_with_me/shared_content_app_bar.dart',
  'lib/views/social/shared_with_me/shared_content_lists.dart',
  'lib/views/social/shared_with_me/shared_recipes_by_friend_view.dart',
  'lib/views/social/shared_with_me_view.dart',
  'lib/views/social/user_profile_edit_view.dart',
  'lib/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart',
  'lib/widgets/common/dialogs/recipe_selection/group_recipe_sharing_dialog.dart',
  'lib/widgets/common/feedback_form_dialog.dart',
  'lib/widgets/common/friends/friend_category_manager.dart',
  'lib/widgets/common/profile/handlers/auth_action_handler.dart',
  'lib/widgets/common/settings/blocked_users_section.dart',
  'lib/widgets/common/share_dialog/share_dialog_states.dart',
  'lib/widgets/common/social/invitation_target_states.dart',
  'lib/widgets/common/social/social_builders.dart',
  'lib/widgets/common/social_components/invitation_states.dart',
  'lib/widgets/common/social_components/social_avatar_components.dart',
  'lib/widgets/common/social_components/social_builder_components.dart',
  'lib/widgets/common/social_components/social_group_components.dart',
  'lib/widgets/messaging/builders/message_content_builder.dart',
  'lib/widgets/messaging/chat_app_bar.dart',
  'lib/widgets/messaging/dialogs/block_group_member_dialog.dart',
  'lib/widgets/messaging/fullscreen_image_viewer.dart',
  'lib/widgets/messaging/new_conversation_dialog.dart',
  'lib/widgets/recipe/collection_insights_card.dart',
  'lib/widgets/social/collaborative/components/collaborative_status_widgets.dart',
  'lib/widgets/social/groups/group_shared_content_section.dart',
  'lib/widgets/social/groups/shared/group_dialog_components.dart',
  'lib/widgets/social/ping_compose_sheet.dart',
  'lib/widgets/social/report_content_dialog.dart',
];

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//.*'), '');

List<String> _offenders(RegExp pattern) => [
  for (final path in _files)
    if (pattern.hasMatch(_code(path))) path,
];

/// Every `SnackBar(` whose own argument list sets a backgroundColor.
List<String> _snackBarsWithBackground() {
  final out = <String>[];
  for (final path in _files) {
    final code = _code(path);
    for (final m in RegExp(r'(?<![\w.])SnackBar\(').allMatches(code)) {
      var depth = 0;
      var end = m.end;
      for (var i = m.end - 1; i < code.length; i++) {
        final c = code[i];
        if (c == '(') depth++;
        if (c == ')') {
          depth--;
          if (depth == 0) {
            end = i;
            break;
          }
        }
      }
      if (code.substring(m.start, end).contains('backgroundColor')) {
        out.add('$path:${code.substring(0, m.start).split('\n').length}');
      }
    }
  }
  return out;
}

void main() {
  test('no spinner or sliding bar (B-18)', () {
    expect(
      _offenders(
        RegExp(
          r'\b(CircularProgressIndicator|LinearProgressIndicator|'
          r'CupertinoActivityIndicator|LoadingIndicator)\s*\(',
        ),
      ),
      isEmpty,
    );
  });

  test('a page loading state says what it fetches', () {
    expect(_offenders(RegExp(r'StateWidget\.loading\(\s*\)')), isEmpty);
  });

  test('one top bar: ButleryTopBar only (B-45)', () {
    expect(
      _offenders(
        RegExp(r'\b(AdaptiveAppBar|SliverAppBar)\s*\(|[^\w.]AppBar\s*\('),
      ),
      isEmpty,
    );
  });

  test('no view builds its own snackbar in a status colour '
      '(Komponentark v1:300, :745-750)', () {
    expect(_snackBarsWithBackground(), isEmpty);
  });
}
