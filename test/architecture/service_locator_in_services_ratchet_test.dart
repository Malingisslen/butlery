// BUT-1508: a service gets what it needs through its constructor (or a
// closure for app/user-scoped things), not by reaching into ServiceLocator
// itself. This ratchet holds the services that still do and how many times;
// a file may not gain a lookup, and a file that drops one lowers its row in
// the same change.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/design_migration_census.dart' show stripComments;

const _residue = <String, int>{
  'lib/services/account/account_deletion_service.dart': 2,
  'lib/services/account/export/activity_export_manager.dart': 4,
  'lib/services/account/export/compliance_export_manager.dart': 2,
  'lib/services/account/export/content_export_manager.dart': 10,
  'lib/services/account/export/family_export_manager.dart': 4,
  'lib/services/account/export/preferences_export_manager.dart': 1,
  'lib/services/account/export/social_export_manager.dart': 1,
  'lib/services/analytics/recipe_edit_analytics_emitter.dart': 1,
  'lib/services/analytics_service.dart': 2,
  'lib/services/attribution_source.dart': 1,
  'lib/services/auth/guest_auth_service.dart': 1,
  'lib/services/auth/sign_out_guard.dart': 2,
  'lib/services/backup_service.dart': 2,
  'lib/services/cook_snap_service.dart': 11,
  'lib/services/deep_link_service.dart': 6,
  'lib/services/family/active_household.dart': 3,
  'lib/services/family/family_rating_service.dart': 4,
  'lib/services/family/household_roster_service.dart': 3,
  'lib/services/family/own_allergen_share_mirror.dart': 2,
  'lib/services/feedback/feedback_service.dart': 2,
  'lib/services/household_service.dart': 6,
  'lib/services/import/fallbacks/llm_extraction_fallback.dart': 1,
  'lib/services/import/import_manager.dart': 7,
  'lib/services/import/photo_llm_vision.dart': 1,
  'lib/services/import/text_import_strategy.dart': 1,
  'lib/services/import/url_import_strategy.dart': 2,
  'lib/services/menu/meal_dislikes.dart': 3,
  'lib/services/menu/present_diner_prefs_resolver.dart': 12,
  'lib/services/menu_voting_service.dart': 2,
  'lib/services/messaging/message_sending_operations.dart': 1,
  'lib/services/messaging_media_service.dart': 1,
  'lib/services/messaging_service.dart': 6,
  'lib/services/notifications/fcm_service.dart': 8,
  'lib/services/notifications/modules/notification_analytics_manager.dart': 1,
  'lib/services/notifications/notification_deep_link_router.dart': 1,
  'lib/services/notifications/notification_service.dart': 3,
  'lib/services/nutrition/nutrition_service.dart': 1,
  'lib/services/ocr_extraction_service.dart': 2,
  'lib/services/offline/queued_image_transport.dart': 5,
  'lib/services/offline/sync_queue_source.dart': 5,
  'lib/services/offline/upload_queue_wiring.dart': 7,
  'lib/services/offline_service.dart': 2,
  'lib/services/parsing/feedback/import_correction_snapshot.dart': 1,
  'lib/services/parsing/ingredient_parsing_strategy.dart': 1,
  'lib/services/parsing/recipe_parser_service.dart': 2,
  'lib/services/parsing/tiers/parsing_tier.dart': 1,
  'lib/services/performance/intelligent_cache_manager.dart': 6,
  'lib/services/permission_service.dart': 3,
  'lib/services/permissions/group_permission_module.dart': 1,
  'lib/services/pwa_install_service_web.dart': 2,
  'lib/services/realtime/realtime_menu_service.dart': 1,
  'lib/services/recipe_suggestion_service.dart': 1,
  'lib/services/share_service.dart': 3,
  'lib/services/shopping/menu_shopping_list_generator.dart': 8,
  'lib/services/shopping/recipe_pantry_check.dart': 2,
  'lib/services/social/activity_feed_service.dart': 4,
  'lib/services/social/blocking/blocked_user_filter.dart': 2,
  'lib/services/social/modules/recipe_share_request_module.dart': 2,
  'lib/services/social/ping_service.dart': 3,
  'lib/services/social_recipe_service.dart': 1,
  'lib/services/storage_service.dart': 7,
  'lib/services/tagging/cookbook_cover_cleanup.dart': 1,
  'lib/services/tagging/cookbook_service.dart': 4,
  'lib/services/tagging/ingredient_lookup_service.dart': 1,
  'lib/services/tagging/personal_tag_crud_service.dart': 1,
  'lib/services/tagging/personal_tag_rule_evaluator.dart': 1,
  'lib/services/tagging/tag_editing_service.dart': 1,
  'lib/services/tagging/tag_generator.dart': 3,
  'lib/services/tagging/tagging_service.dart': 1,
  'lib/services/trash/trash_service.dart': 2,
  'lib/services/unified/friends/friends_internal_operations.dart': 3,
  'lib/services/unified/helpers/personal_recipe_crud.dart': 1,
  'lib/services/unified/helpers/social_operations_initializer.dart': 6,
  'lib/services/unified/modules/personal_recipe_module.dart': 3,
  'lib/services/unified/modules/shopping_item_management_module.dart': 1,
  'lib/services/unified/modules/social_coordination/base_social_coordinator.dart':
      1,
  'lib/services/unified/modules/social_menu/social_menu_coordinator.dart': 2,
  'lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart':
      6,
  'lib/services/unified/modules/social_recipe/social_recipe_query_service.dart':
      5,
  'lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart':
      1,
  'lib/services/unified/modules/social_shopping/social_shopping_coordinator.dart':
      2,
  'lib/services/unified/operations/collaborative_shopping/list_activity_operations.dart':
      6,
  'lib/services/unified/operations/collaborative_shopping/list_item_operations.dart':
      1,
  'lib/services/unified/operations/collaborative_shopping/list_lifecycle_operations.dart':
      4,
  'lib/services/unified/operations/collaborative_shopping/list_member_operations.dart':
      3,
  'lib/services/unified/operations/cooking/cooking_session_module.dart': 3,
  'lib/services/unified/operations/friend_categories_operations.dart': 7,
  'lib/services/unified/operations/friends_management_operations.dart': 5,
  'lib/services/unified/operations/list_invitation_operations.dart': 1,
  'lib/services/unified/operations/modules/comment_crud_operations.dart': 4,
  'lib/services/unified/operations/modules/recipe_rating_system.dart': 2,
  'lib/services/unified/operations/modules/recipe_sharing_manager.dart': 5,
  'lib/services/unified/operations/modules/shopping_social_share_module.dart':
      2,
  'lib/services/unified/operations/realtime_recipe/collaboration_management_module.dart':
      2,
  'lib/services/unified/operations/shopping/shopping_presence_module.dart': 1,
  'lib/services/unified/operations/shopping_share_operations.dart': 1,
  'lib/services/unified/operations/social_menu_operations.dart': 18,
  'lib/services/unified/operations/social_recipe_operations.dart': 1,
  'lib/services/unified/unified_friends_service.dart': 2,
  'lib/services/unified/unified_menu_service.dart': 5,
  'lib/services/unified/unified_recipe_service.dart': 17,
  'lib/services/unified/unified_shopping_service.dart': 7,
  'lib/services/upload/image_upload_service.dart': 1,
  'lib/services/user_service.dart': 3,
};

final _lookup = RegExp(r'ServiceLocator\.(?:get|tryGet|isRegistered)\b');

Map<String, int> _counts() {
  final out = <String, int>{};
  for (final entity in Directory('lib/services').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    final n = _lookup
        .allMatches(stripComments(entity.readAsStringSync()))
        .length;
    if (n > 0) out[path] = n;
  }
  return out;
}

void main() {
  final counts = _counts();

  test('no service gains a ServiceLocator lookup', () {
    final grown = [
      for (final e in counts.entries)
        if (e.value > (_residue[e.key] ?? 0))
          ('${e.key} looks up ServiceLocator ${e.value} time(s), residue '
              'allows ${_residue[e.key] ?? 0}. Take the dependency in the '
              'constructor instead.'),
    ];
    expect(grown, isEmpty);
  });

  test('the residue only shrinks: every row is still needed', () {
    final stale = [
      for (final e in _residue.entries)
        if ((counts[e.key] ?? 0) < e.value)
          ('${e.key} is down to ${counts[e.key] ?? 0} from ${e.value}. '
              'Lower the row.'),
    ];
    expect(stale, isEmpty);
  });
}
