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
  'lib/views/mina_recept_view.dart',
  'lib/views/more/app_settings_view.dart',
  'lib/views/recipe_detail/handlers/recipe_social_handler.dart',
  'lib/views/recipe_detail/recipe_detail_shared_widgets.dart',
  'lib/views/recipe_detail/recipe_detail_tablet_content.dart',
  'lib/views/recipe_detail_view.dart',
  'lib/views/settings/widgets/household_allergen_filter_tile.dart',
  'lib/views/settings/widgets/household_allergen_sharing_tile.dart',
  'lib/views/settings/widgets/meal_allergen_scope_tile.dart',
  'lib/views/settings/widgets/nutrition_strip_tile.dart',
  'lib/views/social/group_detail_view.dart',
  'lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart',
};

const _friendsServiceImporters = <String>{
  'lib/core/di/modules/collaboration_module.dart',
  'lib/core/di/modules/content_module.dart',
  'lib/core/di/modules/performance_module.dart',
  'lib/core/di/modules/social_module.dart',
  'lib/core/di/modules/ui_module.dart',
  'lib/core/di/service_roles_registration.dart',
  'lib/services/unified/operations/social_menu_operations.dart',
  'lib/utils/shopping_list_live_share.dart',
  'lib/viewmodels/add_members_to_group_viewmodel.dart',
  'lib/viewmodels/chat_viewmodel.dart',
  'lib/viewmodels/create_group_viewmodel.dart',
  'lib/viewmodels/friends/friend_lookups.dart',
  'lib/viewmodels/friends_viewmodel.dart',
  'lib/viewmodels/group_invitations_viewmodel.dart',
  'lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart',
  'lib/viewmodels/shared_content/social_sharing_viewmodel.dart',
  'lib/viewmodels/social_group_detail_viewmodel.dart',
  'lib/viewmodels/universal_share_dialog_viewmodel.dart',
  'lib/views/mina_recept/selection_app_bar.dart',
  'lib/views/personal_tags/personal_tag_dialogs.dart',
  'lib/views/recipe_detail/handlers/recipe_management_handler.dart',
  'lib/views/recipe_detail/handlers/recipe_social_handler.dart',
  'lib/views/social/create_shared_shopping_list_view.dart',
  'lib/views/social/friends_list/groups_tab.dart',
  'lib/views/social/friends_list_view.dart',
  'lib/views/social/group_detail_view.dart',
  'lib/views/social/menu_preview_view.dart',
  'lib/views/social/public_profile_view.dart',
  'lib/views/unified_shopping/widgets/dialogs/shopping_list_operations.dart',
  'lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart',
  'lib/views/unified_shopping/widgets/shopping_dialogs.dart',
  'lib/widgets/menu/veckomeny_dialogs.dart',
  'lib/widgets/social/groups/create_group_dialog.dart',
  'lib/widgets/social/groups/edit_group_dialog.dart',
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
