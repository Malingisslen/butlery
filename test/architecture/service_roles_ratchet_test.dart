// BUT-1507: a file that needs only part of UserService or UnifiedFriendsService
// takes the role it uses (user_service_roles.dart, friends_service_roles.dart)
// instead of importing the whole service. The lists below are the files that
// still import a whole service; they may only shrink.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _userServiceImporters = <String>{
  'lib/app/auth/auth_wrapper.dart',
  'lib/app/butlery_app.dart',
  'lib/core/di/attribution_from_locator.dart',
  'lib/core/di/modules/collaboration_module.dart',
  'lib/core/di/modules/content_module.dart',
  'lib/core/di/modules/messaging_module.dart',
  'lib/core/di/modules/offline_registrations.dart',
  'lib/core/di/modules/pantry_module.dart',
  'lib/core/di/modules/social_module.dart',
  'lib/core/di/modules/ui_module.dart',
  'lib/core/di/service_roles_registration.dart',
  'lib/core/providers/locale_provider.dart',
  'lib/repositories/firebase/firebase_shopping_repository.dart',
  'lib/services/account/terms_acceptance.dart',
  'lib/services/household_service.dart',
  'lib/services/offline/offline_service_links.dart',
  'lib/services/social/activity_feed_service.dart',
  'lib/services/unified/modules/social_coordination/base_social_coordinator.dart',
  'lib/services/unified/operations/social_menu_operations.dart',
  'lib/services/unified/unified_friends_service.dart',
  'lib/services/user_service/own_profile_loader.dart',
  'lib/viewmodels/allergen_preferences_viewmodel.dart',
  'lib/viewmodels/auth/provider_terms_viewmodel.dart',
  'lib/viewmodels/friends_viewmodel.dart',
  'lib/viewmodels/hem/hem_viewmodel.dart',
  'lib/viewmodels/onboarding_viewmodel.dart',
  'lib/viewmodels/profile/profile_viewmodel.dart',
  'lib/viewmodels/social_group_detail_viewmodel.dart',
  'lib/viewmodels/unified_shopping_viewmodel.dart',
  'lib/viewmodels/user_profile_viewmodel.dart',
  'lib/views/auth/guest_upgrade_view.dart',
  'lib/views/family/min_familj_view.dart',
  'lib/views/fran_sociala_medier_view.dart',
  'lib/views/group_weekly_menu_view.dart',
  'lib/views/messaging/conversations_list/conversation_actions.dart',
  'lib/views/mina_recept_view.dart',
  'lib/views/more/account_area_view.dart',
  'lib/views/more/app_settings_view.dart',
  'lib/views/more/more_view.dart',
  'lib/views/photo_import_view.dart',
  'lib/views/realtime/conflict_diff_view.dart',
  'lib/views/recipe_detail/handlers/recipe_social_handler.dart',
  'lib/views/recipe_detail/nutrition/recipe_nutrition_section.dart',
  'lib/views/recipe_detail/recipe_detail_actions.dart',
  'lib/views/recipe_detail/recipe_detail_shared_widgets.dart',
  'lib/views/recipe_detail/recipe_detail_tablet_content.dart',
  'lib/views/recipe_detail/recipe_profile_visibility.dart',
  'lib/views/recipe_detail_view.dart',
  'lib/views/settings/widgets/household_allergen_filter_tile.dart',
  'lib/views/settings/widgets/household_allergen_sharing_tile.dart',
  'lib/views/settings/widgets/meal_allergen_scope_tile.dart',
  'lib/views/settings/widgets/nutrition_strip_tile.dart',
  'lib/views/smart_import/import_result_handler.dart',
  'lib/views/social/group_detail_view.dart',
  'lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart',
  'lib/views/unified_shopping/widgets/shopping_dialogs.dart',
  'lib/widgets/common/settings/blocked_users_section.dart',
  'lib/widgets/import/recipe_form_handoff.dart',
  'lib/widgets/messaging/dialogs/block_group_member_dialog.dart',
  'lib/widgets/tagging/tag_editor_dialog.dart',
};

const _friendsServiceImporters = <String>{
  'lib/core/di/modules/collaboration_module.dart',
  'lib/core/di/modules/content_module.dart',
  'lib/core/di/modules/performance_module.dart',
  'lib/core/di/modules/social_module.dart',
  'lib/core/di/modules/ui_module.dart',
  'lib/core/di/service_roles_registration.dart',
  'lib/services/cook_snap_links.dart',
  'lib/services/household_service.dart',
  'lib/services/performance/intelligent_cache_manager.dart',
  'lib/services/permission_service.dart',
  'lib/services/permissions/group_permission_module.dart',
  'lib/services/recipe_suggestion_service.dart',
  'lib/services/social/ping_service.dart',
  'lib/services/unified/operations/cooking/cooking_session_module.dart',
  'lib/services/unified/operations/social_menu_operations.dart',
  'lib/services/unified/unified_shopping_service.dart',
  'lib/utils/shopping_list_live_share.dart',
  'lib/viewmodels/add_members_to_group_viewmodel.dart',
  'lib/viewmodels/chat_viewmodel.dart',
  'lib/viewmodels/create_group_conversation_viewmodel.dart',
  'lib/viewmodels/create_group_viewmodel.dart',
  'lib/viewmodels/create_shared_list_viewmodel.dart',
  'lib/viewmodels/friends/friend_lookups.dart',
  'lib/viewmodels/friends/friend_request_manager.dart',
  'lib/viewmodels/friends/friends_search_manager.dart',
  'lib/viewmodels/friends_viewmodel.dart',
  'lib/viewmodels/group_detail_viewmodel.dart',
  'lib/viewmodels/group_invitations_viewmodel.dart',
  'lib/viewmodels/shared_content/base_shared_content_viewmodel.dart',
  'lib/viewmodels/shared_content/menu_dish_credit_viewmodel.dart',
  'lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart',
  'lib/viewmodels/shared_content/social_sharing_viewmodel.dart',
  'lib/viewmodels/shopping_share_viewmodel.dart',
  'lib/viewmodels/social_group_detail_viewmodel.dart',
  'lib/viewmodels/social_recipe/social_comments_manager.dart',
  'lib/viewmodels/social_recipe/social_profile_manager.dart',
  'lib/viewmodels/social_recipe_viewmodel.dart',
  'lib/viewmodels/universal_share_dialog_viewmodel.dart',
  'lib/views/messaging/conversations_list/conversation_actions.dart',
  'lib/views/mina_recept/selection_app_bar.dart',
  'lib/views/mina_recept_view.dart',
  'lib/views/more/more_view.dart',
  'lib/views/personal_tags/personal_tag_dialogs.dart',
  'lib/views/realtime/recipe_suggestion_view.dart',
  'lib/views/recipe_detail/handlers/recipe_management_handler.dart',
  'lib/views/recipe_detail/handlers/recipe_social_handler.dart',
  'lib/views/recipe_detail/recipe_detail_comments.dart',
  'lib/views/recipe_detail/recipe_detail_sharing_status.dart',
  'lib/views/recipe_detail_view.dart',
  'lib/views/social/create_shared_shopping_list_view.dart',
  'lib/views/social/friends_list/group_invitation_card.dart',
  'lib/views/social/friends_list/groups_tab.dart',
  'lib/views/social/friends_list_view.dart',
  'lib/views/social/group_detail/group_detail_actions.dart',
  'lib/views/social/group_detail/group_invitation_card.dart',
  'lib/views/social/group_detail/group_share_actions.dart',
  'lib/views/social/group_detail_view.dart',
  'lib/views/social/menu_preview_view.dart',
  'lib/views/social/public_profile_view.dart',
  'lib/views/unified_shopping/widgets/dialogs/shopping_list_operations.dart',
  'lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart',
  'lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart',
  'lib/views/unified_shopping/widgets/shopping_dialogs.dart',
  'lib/views/veckomeny_view.dart',
  'lib/widgets/common/settings/blocked_users_section.dart',
  'lib/widgets/menu/veckomeny_dialogs.dart',
  'lib/widgets/menu/veckomeny_selection_widgets.dart',
  'lib/widgets/messaging/new_conversation_dialog.dart',
  'lib/widgets/realtime/recipe_suggestion_notice.dart',
  'lib/widgets/social/activity_pings_feed.dart',
  'lib/widgets/social/family_presence_bar.dart',
  'lib/widgets/social/groups/create_group_dialog.dart',
  'lib/widgets/social/groups/edit_group_dialog.dart',
  'lib/widgets/social/groups/group_dialogs.dart',
  'lib/widgets/social/groups/remove_member_dialog.dart',
};

Set<String> _importersOf(String fileName, String self) {
  final import = RegExp(
    "^(?:import|export) '[^']*(?<!\\w)${RegExp.escape(fileName)}'",
    multiLine: true,
  );
  final found = <String>{};
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path == self) continue;
    if (import.hasMatch(entity.readAsStringSync())) found.add(path);
  }
  return found;
}

void _expectRatchet(String target, String self, Set<String> allowed) {
  final actual = _importersOf(target, self);
  expect(actual, isNotEmpty, reason: 'the scan found no importers of $target');
  expect(
    actual.difference(allowed),
    isEmpty,
    reason:
        'New file imports $target. Take the role it uses instead '
        '(see the roles file next to the service).',
  );
  expect(
    allowed.difference(actual),
    isEmpty,
    reason: 'These no longer import $target: remove them from the list.',
  );
}

void main() {
  test('only listed files import the whole UserService', () {
    _expectRatchet(
      'user_service.dart',
      'lib/services/user_service.dart',
      _userServiceImporters,
    );
  });

  test('only listed files import the whole UnifiedFriendsService', () {
    _expectRatchet(
      'unified_friends_service.dart',
      'lib/services/unified/unified_friends_service.dart',
      _friendsServiceImporters,
    );
  });
}
