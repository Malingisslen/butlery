/// P7-U08 icon census (beslutslogg.md:9, B-02; Q16 / Q-P7-15).
///
/// Every icon in lib/ is a Butlery glyph (ButleryIcons, rendered by
/// ButleryIcon) except the Material residue below: uses whose meaning has no
/// glyph in icons.json yet. The list only SHRINKS. When design draws a glyph
/// (icons.json + master in assets/icons, rerun
/// tools/generate_butlery_icons.dart), replace the uses and delete the rows.
/// A new Material icon, a larger count, or a row that no longer matches the
/// code fails this test, so the list always states the truth.
///
/// Also enforced: no CupertinoIcons and no AdaptiveIcon(s) anywhere in lib
/// (plattformsmatris.md:75: the icon family is identical on both
/// platforms), and every icon is built with ButleryIcon, never a plain Icon,
/// outside the two files package 7 deletes (P7-Z).
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// file -> Material icon name -> number of uses.
const Map<String, Map<String, int>> _residue = {
  'lib/core/utils/common_dialog_actions.dart': {'exit_to_app': 1},
  'lib/services/notifications/notification_permission_service.dart': {
    'notifications_off_outlined': 1,
  },
  'lib/services/performance/optimized_image_loader.dart': {'broken_image': 1},
  'lib/viewmodels/recipe_form/image_management/image_display_info.dart': {
    'cloud_done': 1,
    'cloud_upload': 1,
  },
  'lib/views/account/consent_management_view.dart': {
    'analytics_rounded': 1,
    'auto_awesome_rounded': 1,
    'fact_check_outlined': 1,
    'notifications_rounded': 1,
    'privacy_tip_rounded': 1,
    'security': 1,
  },
  'lib/views/admin/admin_shell.dart': {
    'feedback': 1,
    'feedback_outlined': 1,
    'rule': 1,
    'rule_outlined': 1,
  },
  'lib/views/admin/feedback_inbox_view.dart': {
    'broken_image_outlined': 1,
    'inbox_outlined': 1,
    'logout': 1,
  },
  'lib/views/admin/moderator_review_view.dart': {'shield_outlined': 1},
  'lib/views/admin/parsing_details_view.dart': {'rule': 1},
  'lib/views/admin/widgets/admin_stat_card.dart': {
    'arrow_downward': 1,
    'arrow_upward': 1,
  },
  'lib/views/auth/email_verification_view.dart': {
    'mark_email_unread_outlined': 1,
  },
  'lib/views/cooking_mode_view.dart': {'no_meals': 1, 'touch_app': 1},
  'lib/views/edit_recipe_view.dart': {'cloud_done_outlined': 1},
  'lib/views/family/family_member_form_view.dart': {'save': 1, 'undo': 1},
  'lib/views/family/who_is_eating_sheet.dart': {'how_to_reg': 1},
  'lib/views/file_import_view.dart': {'file_upload': 1},
  'lib/views/fran_sociala_medier_view.dart': {'preview': 1},
  'lib/views/importera_fran_arkiv_view.dart': {'search_off': 1, 'upload': 1},
  'lib/views/ingredient_search/ingredient_search_view.dart': {
    'no_meals_outlined': 1,
  },
  'lib/views/messaging/chat_view/chat_input_section.dart': {'poll_outlined': 1},
  'lib/views/messaging/conversation_group_detail_view.dart': {
    'exit_to_app': 1,
    'person_add': 1,
  },
  'lib/views/messaging/conversations_list_view.dart': {
    'exit_to_app': 1,
    'mark_chat_read': 1,
    'search_off': 1,
    'unarchive': 1,
  },
  'lib/views/mina_recept/empty_state_widgets.dart': {'celebration_outlined': 1},
  'lib/views/mina_recept/recipe_card_widget.dart': {'circle_outlined': 1},
  'lib/views/mina_recept_view.dart': {
    'grid_view': 1,
    'kitchen_outlined': 1,
    'view_list': 1,
  },
  'lib/views/notifications/notifications_view.dart': {
    'circle_outlined': 1,
    'notifications_outlined': 1,
  },
  'lib/views/onboarding/onboarding_allergen_page.dart': {
    'catching_pokemon': 3,
    'eco_outlined': 3,
    'egg_outlined': 1,
    'grain': 1,
    'grass_outlined': 1,
    'local_florist_outlined': 3,
    'science_outlined': 1,
    'spa_outlined': 1,
    'water_drop_outlined': 2,
  },
  'lib/views/onboarding/onboarding_dietary_page.dart': {
    'eco': 1,
    'no_food': 1,
    'spa': 1,
    'water_drop_outlined': 1,
  },
  'lib/views/onboarding/onboarding_import_page.dart': {'content_paste': 1},
  'lib/views/pantry/pantry_item_card.dart': {'circle_outlined': 1},
  'lib/views/pantry/pantry_view.dart': {
    'ac_unit': 1,
    'grass_outlined': 1,
    'inventory_2_outlined': 1,
    'kitchen': 1,
  },
  'lib/views/personal_tags/personal_tag_dialogs.dart': {
    'folder_off': 1,
    'play_arrow': 1,
  },
  'lib/views/personal_tags/personal_tag_widgets.dart': {
    'auto_awesome': 1,
    'check_box': 1,
    'check_box_outline_blank': 1,
    'label_off': 1,
  },
  'lib/views/personal_tags_view.dart': {'merge': 1},
  'lib/views/photo_import_view.dart': {
    'draw_outlined': 1,
    'library_books': 1,
    'no_photography_outlined': 1,
    'restore': 2,
  },
  'lib/views/receive_share_view.dart': {
    'content_paste': 1,
    'public': 1,
    'text_fields': 1,
  },
  'lib/views/recipe_detail/recipe_detail_shared_widgets.dart': {
    'music_note': 1,
    'open_in_new': 1,
    'play_circle_outline': 1,
    'tips_and_updates_outlined': 1,
  },
  'lib/views/recipe_detail/recipe_source_artefact_sheet.dart': {
    'history_outlined': 1,
  },
  'lib/views/recipe_detail_view.dart': {
    'description_outlined': 1,
    'flag_outlined': 1,
    'group_add_outlined': 1,
    'group_off_outlined': 1,
    'history': 1,
    'print_outlined': 1,
    'rate_review_outlined': 1,
  },
  'lib/views/settings/about_butlery_view.dart': {'article_outlined': 1},
  'lib/views/settings/account_security_view.dart': {
    'code': 1,
    'description_outlined': 1,
    'flag_outlined': 1,
    'gavel_outlined': 1,
    'phone_android': 1,
    'security': 1,
  },
  'lib/views/settings/allergen_preferences_view.dart': {'shield_outlined': 1},
  'lib/views/settings/collection_stats_view.dart': {
    'local_fire_department': 1,
    'menu_book': 1,
  },
  'lib/views/settings/licenses_view.dart': {'code': 1},
  'lib/views/settings/mfa_settings_view.dart': {
    'phone': 1,
    'phone_android': 1,
    'security': 1,
  },
  'lib/views/settings/my_reports_view.dart': {'flag_outlined': 1},
  'lib/views/settings/notification_category_items.dart': {
    'group_work_outlined': 1,
  },
  'lib/views/settings/notification_preferences_view.dart': {
    'do_not_disturb_on_outlined': 1,
    'notifications_active_outlined': 1,
    'notifications_off_outlined': 1,
    'summarize_outlined': 1,
  },
  'lib/views/settings/settings_hub_view.dart': {
    'description_outlined': 1,
    'help_outline': 1,
    'kitchen_outlined': 1,
    'language': 1,
    'logout': 1,
    'notifications_outlined': 1,
    'security': 1,
    'shield_outlined': 1,
    'upload_outlined': 1,
  },
  'lib/views/skriv_sjalv_recept_view.dart': {'cloud_done_outlined': 1},
  'lib/views/smart_import/import_widgets.dart': {'content_paste': 2},
  'lib/views/smart_import_view.dart': {'videocam_off': 1},
  'lib/views/social/collaborative_shopping/collaborative_shopping_actions.dart':
      {'clear_all': 2, 'hourglass_empty': 2},
  'lib/views/social/collaborative_shopping/collaborative_shopping_items.dart': {
    'swipe': 1,
  },
  'lib/views/social/create_shared_shopping_list_view.dart': {'title': 1},
  'lib/views/social/friend_profile_view.dart': {
    'flag_outlined': 1,
    'folder_shared_outlined': 1,
  },
  'lib/views/social/friend_requests/friend_request_builders.dart': {
    'inbox': 1,
    'inbox_outlined': 1,
    'outbox': 1,
    'outbox_outlined': 1,
  },
  'lib/views/social/friend_requests/friend_request_card.dart': {'timer_off': 1},
  'lib/views/social/friends_list/requests_tab.dart': {'inbox': 1, 'outbox': 1},
  'lib/views/social/friends_list_view.dart': {
    'dynamic_feed': 1,
    'person_add_alt_1': 1,
  },
  'lib/views/social/group_detail/group_action_buttons.dart': {'exit_to_app': 1},
  'lib/views/social/group_detail/group_detail_actions.dart': {'exit_to_app': 1},
  'lib/views/social/group_detail/group_detail_app_bar.dart': {
    'exit_to_app': 1,
    'flag_outlined': 1,
    'person_add': 1,
  },
  'lib/views/social/group_detail/group_detail_header.dart': {
    'home': 1,
    'update': 1,
  },
  'lib/views/social/group_detail/group_member_card.dart': {
    'circle_outlined': 1,
    'flag_outlined': 1,
  },
  'lib/views/social/group_detail/group_members_list.dart': {'person_add': 1},
  'lib/views/social/menu_preview_view.dart': {
    'cake': 1,
    'category': 1,
    'cookie': 1,
    'free_breakfast': 1,
    'local_cafe': 1,
  },
  'lib/views/social/shared_with_me/shared_content_actions.dart': {
    'link_off': 3,
  },
  'lib/views/social/shared_with_me/shared_menu_card.dart': {'category': 1},
  'lib/views/social/shared_with_me/shared_recipe_card.dart': {'reply': 1},
  'lib/views/social/shared_with_me/shared_shopping_list_card.dart': {
    'add_shopping_cart': 2,
  },
  'lib/views/social/user_profile_edit/preferences_sections.dart': {
    'dark_mode': 1,
    'language': 1,
    'light_mode': 1,
    'save': 1,
    'settings_suggest': 1,
  },
  'lib/views/social/user_profile_edit/privacy_section.dart': {
    'dynamic_feed': 1,
    'podcasts': 1,
  },
  'lib/views/tag_detail_view.dart': {'play_arrow': 1},
  'lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart':
      {'admin_panel_settings': 1, 'manage_accounts': 1, 'person_add': 1},
  'lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart':
      {'admin_panel_settings': 4, 'history': 1, 'manage_accounts': 1},
  'lib/views/unified_shopping/widgets/shopping_app_bar.dart': {
    'admin_panel_settings': 1,
    'check_box_outline_blank': 1,
    'list_alt_outlined': 1,
  },
  'lib/views/unified_shopping/widgets/shopping_item_tiles.dart': {
    'circle_outlined': 1,
    'drive_file_move_outline': 1,
  },
  'lib/views/unified_shopping/widgets/shopping_list_header.dart': {
    'admin_panel_settings': 2,
  },
  'lib/views/unified_shopping_view.dart': {'kitchen_outlined': 1},
  'lib/views/veckomeny_view.dart': {'save': 1},
  'lib/widgets/common/content_cards/shopping_list_card.dart': {
    'hourglass_empty': 1,
    'radio_button_unchecked': 1,
  },
  'lib/widgets/common/dialogs/base_dialog.dart': {'save': 1},
  'lib/widgets/common/dialogs/dialog_form_fields.dart': {
    'description_outlined': 1,
    'numbers': 1,
    'phone_outlined': 1,
  },
  'lib/widgets/common/dialogs/draft_recovery_dialog.dart': {
    'article_outlined': 1,
    'restore': 2,
  },
  'lib/widgets/common/dialogs/rate_limit_dialog.dart': {
    'attach_money_outlined': 1,
    'auto_fix_off_outlined': 1,
    'smart_toy_outlined': 1,
    'speed_outlined': 1,
  },
  'lib/widgets/common/dialogs/shopping_list_selection_dialog.dart': {
    'radio_button_checked': 2,
    'radio_button_unchecked': 2,
  },
  'lib/widgets/common/dialogs/slot_picker_dialog.dart': {
    'check_box': 1,
    'check_box_outline_blank': 1,
  },
  'lib/widgets/common/feedback/snackbar_widgets.dart': {'warning_outlined': 1},
  'lib/widgets/common/friends/category_display_widgets.dart': {
    'analytics': 1,
    'category': 2,
    'category_outlined': 1,
    'emoji_emotions': 3,
  },
  'lib/widgets/common/friends/category_selection_widgets.dart': {
    'category': 1,
    'clear_all': 1,
    'emoji_emotions': 1,
  },
  'lib/widgets/common/friends/friend_category_manager.dart': {
    'category_outlined': 1,
  },
  'lib/widgets/common/icons/pending_glyphs.dart': {
    'bookmark': 1,
    'bookmark_border': 1,
  },
  'lib/widgets/common/illustrations/vegetable_illustration.dart': {
    'circle': 1,
    'eco': 2,
    'grass': 1,
    'search_off': 1,
  },
  'lib/widgets/common/indicators/admin_badge.dart': {'admin_panel_settings': 1},
  'lib/widgets/common/indicators/sync_indicator.dart': {
    'cloud_done_outlined': 1,
    'cloud_off_outlined': 1,
    'cloud_upload_outlined': 1,
  },
  'lib/widgets/common/input/editable_menu_items_preview_dialog.dart': {
    'clear_all': 1,
  },
  'lib/widgets/common/input/portion_scaler_ui.dart': {
    'calculate': 1,
    'language': 2,
  },
  'lib/widgets/common/loading_state_builder.dart': {'inbox_outlined': 3},
  'lib/widgets/common/menus/sort_menu_builder.dart': {
    'arrow_downward': 1,
    'arrow_upward': 1,
    'history': 1,
    'repeat': 1,
    'title': 1,
  },
  'lib/widgets/common/permissions/permission_widgets.dart': {'save': 4},
  'lib/widgets/common/profile/builders/profile_section_builders.dart': {
    'logout': 1,
    'policy_rounded': 1,
    'privacy_tip_rounded': 1,
    'upload': 1,
  },
  'lib/widgets/common/profile/profile_menu.dart': {
    'bar_chart': 1,
    'health_and_safety': 1,
    'help_outline': 1,
    'notifications_outlined': 1,
    'security': 1,
  },
  'lib/widgets/common/pwa_install_banner.dart': {'install_mobile': 1},
  'lib/widgets/common/routing/deferred_route_loader.dart': {'home': 1},
  'lib/widgets/common/scaffolds/empty_state_scaffold.dart': {
    'inbox_outlined': 1,
  },
  'lib/widgets/common/scaffolds/form_scaffold.dart': {'save': 1},
  'lib/widgets/common/search_filter/filter_models.dart': {
    'cake': 1,
    'child_care': 1,
    'cookie': 1,
    'eco_outlined': 2,
  },
  'lib/widgets/common/search_filter/filters_panel_widget.dart': {
    'clear_all': 1,
  },
  'lib/widgets/common/search_filter/quick_filter_chips.dart': {
    'kitchen_outlined': 1,
  },
  'lib/widgets/common/settings/blocked_users_section.dart': {
    'check_box': 1,
    'check_box_outline_blank': 1,
  },
  'lib/widgets/common/share_dialog/share_dialog_states.dart': {'person_add': 1},
  'lib/widgets/common/share_dialog/share_mode_selection.dart': {
    'radio_button_checked': 2,
    'radio_button_unchecked': 2,
  },
  'lib/widgets/common/share_dialog/share_target_selection.dart': {
    'search_off': 1,
  },
  'lib/widgets/common/share_dialog/share_target_selection_enhanced.dart': {
    'search_off': 2,
  },
  'lib/widgets/common/social/invitation_target_states.dart': {'search_off': 1},
  'lib/widgets/common/social_components/invitation_actions.dart': {
    'group_add': 1,
  },
  'lib/widgets/common/social_components/invitation_displays.dart': {
    'pending': 1,
  },
  'lib/widgets/common/social_components/invitation_states.dart': {
    'search_off': 1,
  },
  'lib/widgets/common/social_components/social_builder_components.dart': {
    'inbox': 1,
    'menu_book': 1,
    'pending': 1,
  },
  'lib/widgets/common/social_components/social_collaborative_components.dart': {
    'admin_panel_settings': 1,
    'history': 1,
  },
  'lib/widgets/common/social_components/social_group_components.dart': {
    'analytics': 1,
    'category': 1,
    'category_outlined': 1,
  },
  'lib/widgets/common/social_components/social_invitation_components.dart': {
    'search_off': 1,
  },
  'lib/widgets/common/star_rating_row.dart': {'star_half': 1},
  'lib/widgets/common/state/empty_states.dart': {
    'category': 1,
    'group_add': 1,
    'notifications_none': 1,
    'person_add': 1,
    'search_off': 3,
  },
  'lib/widgets/common/swipe_hint_banner.dart': {'swipe': 1},
  'lib/widgets/common/sync/sync_queue_indicator.dart': {
    'sync_problem_outlined': 1,
  },
  'lib/widgets/consent/consent_renewal_dialog.dart': {'privacy_tip_rounded': 1},
  'lib/widgets/cooking/step_timer_widget.dart': {'play_arrow': 2},
  'lib/widgets/image/components/upload_progress_widgets.dart': {
    'clear_all': 1,
    'stop': 1,
  },
  'lib/widgets/image/image_gallery_widget.dart': {'circle_outlined': 1},
  'lib/widgets/import/allergen_setup_banner.dart': {
    'health_and_safety_outlined': 1,
  },
  'lib/widgets/import/assisted_import_dialog.dart': {'format_list_numbered': 1},
  'lib/widgets/import/batch_import_preview.dart': {'deselect': 1},
  'lib/widgets/import/components/import_dialog_footer.dart': {'save': 1},
  'lib/widgets/import/platform_badge_widget.dart': {
    'language': 1,
    'music_note': 1,
    'play_circle_outline': 1,
    'text_snippet_outlined': 1,
  },
  'lib/widgets/import/text_line_selector.dart': {
    'auto_awesome': 1,
    'format_list_numbered': 1,
    'text_fields': 1,
  },
  'lib/widgets/maintenance_mode_blocker.dart': {'build_circle_outlined': 1},
  'lib/widgets/menu/calendar/calendar_cells.dart': {
    'cake_outlined': 1,
    'check_box': 2,
    'check_box_outline_blank': 2,
  },
  'lib/widgets/menu/calendar/calendar_header.dart': {
    'drive_file_move_outline': 1,
  },
  'lib/widgets/menu/calendar_weekly_menu_widget.dart': {
    'arrow_upward': 1,
    'cake_outlined': 1,
  },
  'lib/widgets/menu/menu_content_widgets.dart': {'no_meals': 1},
  'lib/widgets/menu/menu_vote_card.dart': {'timer_off': 1},
  'lib/widgets/messaging/builders/message_content_builder.dart': {
    'broken_image': 1,
    'list_alt': 1,
    'play_arrow': 1,
  },
  'lib/widgets/messaging/chat_app_bar.dart': {
    'exit_to_app': 1,
    'notifications_off_outlined': 1,
  },
  'lib/widgets/messaging/components/message_status_widget.dart': {
    'done_all': 2,
  },
  'lib/widgets/messaging/conversation_list_item.dart': {'unarchive': 1},
  'lib/widgets/messaging/fullscreen_image_viewer.dart': {'broken_image': 1},
  'lib/widgets/messaging/message_bubble.dart': {'reply': 1},
  'lib/widgets/messaging/new_conversation_dialog.dart': {'group_add': 1},
  'lib/widgets/messaging/reply_banner.dart': {'reply': 1},
  'lib/widgets/messaging/typing_indicator.dart': {'more_horiz': 1},
  'lib/widgets/recipe/collection_insights_card.dart': {'insights': 1},
  'lib/widgets/recipe/comment_form_widget.dart': {'reply': 1},
  'lib/widgets/recipe/comment_image_attachments.dart': {'broken_image': 2},
  'lib/widgets/recipe/comment_item_widgets.dart': {
    'flag_outlined': 1,
    'reply': 1,
  },
  'lib/widgets/recipe/cook_snap_gallery.dart': {'broken_image': 1, 'flag': 1},
  'lib/widgets/recipe/cook_snap_photo_carousel.dart': {'broken_image': 2},
  'lib/widgets/recipe/draft_recovery_dialog.dart': {
    'description_outlined': 1,
    'restore': 1,
  },
  'lib/widgets/recipe/duplicate_merge_sheet.dart': {
    'broken_image_outlined': 1,
    'merge_type': 1,
  },
  'lib/widgets/recipe/heirloom_section.dart': {'broken_image_outlined': 1},
  'lib/widgets/recipe/recipe_card.dart': {
    'help_outline': 1,
    'pending_outlined': 1,
    'pie_chart_outline': 1,
    'public': 1,
  },
  'lib/widgets/recipe/recipe_form/sectioned_ingredient_list_builder.dart': {
    'low_priority': 1,
  },
  'lib/widgets/shopping/shopping_template_browser.dart': {
    'list_alt': 1,
    'list_alt_outlined': 1,
  },
  'lib/widgets/social/groups/create_group_dialog.dart': {'group_add': 2},
  'lib/widgets/social/groups/edit_group_dialog.dart': {
    'description': 1,
    'save': 1,
  },
  'lib/widgets/social/ping_compose_sheet.dart': {
    'back_hand_outlined': 1,
    'help_outline': 1,
  },
  'lib/widgets/social/shared_card_header.dart': {'link_off': 1},
  'lib/widgets/styled/styled_input.dart': {'phone': 1},
  'lib/widgets/tagging/dietary_status_badge.dart': {
    'cancel_outlined': 1,
    'eco_outlined': 1,
  },
  'lib/widgets/tagging/personal_tag_rule_dialog.dart': {
    'all_inclusive': 1,
    'call_split': 1,
  },
  'lib/widgets/tagging/tag_detail_rules_section.dart': {
    'auto_awesome': 1,
    'rule': 1,
  },
  'lib/widgets/tagging/tag_editor_dialog.dart': {'undo': 1},
  'lib/widgets/tagging/tag_result_display.dart': {
    'analytics_outlined': 1,
    'update': 1,
  },
  'lib/widgets/user/user_avatar_widgets.dart': {
    'circle': 2,
    'circle_outlined': 2,
  },
  'lib/widgets/user/user_display_models.dart': {
    'circle': 1,
    'circle_outlined': 1,
    'do_not_disturb': 1,
  },
};

/// Files the package 7 closing track (P7-Z) deletes; left untouched by
/// P7-U08. Their residue rows only count while the file exists, so the two
/// package 7 tracks can merge in either order. After P7-Z lands, delete
/// their rows here and in [_residue].
const Set<String> _deletedByClosingTrack = {
  'lib/widgets/common/feedback/snackbar_widgets.dart',
  'lib/widgets/common/indicators/sync_indicator.dart',
};

/// Files allowed to build a plain Icon: the glyph widget itself and the
/// files [_deletedByClosingTrack] names.
const Set<String> _plainIconAllowed = {
  ..._deletedByClosingTrack,
  'lib/widgets/common/icons/butlery_glyph.dart',
};

Iterable<File> _dartFiles() => Directory('lib')
    .listSync(recursive: true)
    .whereType<File>()
    .where((f) => f.path.endsWith('.dart'));

String _rel(File f) => f.path.replaceAll(r'\', '/');

void main() {
  final materialUse = RegExp(r'(?<![\w.$])Icons\.(\w+)');

  test('Material icons in lib are exactly the shrinking residue', () {
    final actual = <String, Map<String, int>>{};
    for (final f in _dartFiles()) {
      for (final m in materialUse.allMatches(f.readAsStringSync())) {
        final names = actual.putIfAbsent(_rel(f), () => {});
        names[m.group(1)!] = (names[m.group(1)!] ?? 0) + 1;
      }
    }
    final problems = <String>[];
    for (final MapEntry(key: file, value: names) in actual.entries) {
      for (final MapEntry(key: name, value: count) in names.entries) {
        final allowed = _residue[file]?[name] ?? 0;
        if (count > allowed) {
          problems.add(
            '$file uses Icons.$name $count time(s), residue allows $allowed. '
            'Use a ButleryIcons glyph with the same meaning, or ask design '
            'for one (icons.json new_icons).',
          );
        }
      }
    }
    for (final MapEntry(key: file, value: names) in _residue.entries) {
      if (_deletedByClosingTrack.contains(file) && !File(file).existsSync()) {
        continue;
      }
      for (final MapEntry(key: name, value: allowed) in names.entries) {
        final count = actual[file]?[name] ?? 0;
        if (count < allowed) {
          problems.add(
            '$file: Icons.$name is down to $count from $allowed. Shrink '
            'the residue row to $count.',
          );
        }
      }
    }
    expect(problems, isEmpty, reason: problems.join('\n'));
  });

  test('no CupertinoIcons or AdaptiveIcon(s) in lib', () {
    final banned = RegExp(r'\bCupertinoIcons\.|\bAdaptiveIcons?[.(]');
    final hits = [
      for (final f in _dartFiles())
        if (banned.hasMatch(f.readAsStringSync())) _rel(f),
    ];
    expect(hits, isEmpty);
  });

  test('icons are built with ButleryIcon, not a plain Icon', () {
    final plainIcon = RegExp(r'(?<![\w.$])Icon\(');
    final hits = [
      for (final f in _dartFiles())
        if (!_plainIconAllowed.contains(_rel(f)) &&
            plainIcon.hasMatch(f.readAsStringSync()))
          _rel(f),
    ];
    expect(
      hits,
      isEmpty,
      reason:
          'A ButleryGlyph has no font; wrap it in '
          'ButleryIcon (lib/widgets/common/icons/butlery_glyph.dart).',
    );
  });
}
