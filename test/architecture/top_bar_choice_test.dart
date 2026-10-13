// The top of a screen is chosen by kind of view, not by each view
// (.claude/rules/design-system.md, "The top of a screen"). A view builds its
// page with ButleryPage; it does not construct ButleryTopBar itself.
//
// The files below still do, from before the rule. The list only shrinks: move
// a view onto ButleryPage and delete its line. A file that no longer builds a
// bar fails here until its line is gone, so the list cannot go stale.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../tools/design_migration_census.dart' show stripComments;

const _builtDirectly = {
  'lib/core/router/app_router.dart',
  'lib/views/admin/moderator_review_view.dart',
  'lib/views/auth/mfa_challenge_view.dart',
  'lib/views/cookbooks/cookbook_detail_view.dart',
  'lib/views/edit_recipe_view.dart',
  'lib/views/family/family_rating_entry_view.dart',
  'lib/views/importera_fran_arkiv_view.dart',
  'lib/views/ingredient_search/ingredient_search_view.dart',
  'lib/views/messaging/chat_view/chat_view_facade.dart',
  'lib/views/mina_recept/selection_app_bar.dart',
  'lib/views/more/more_view.dart',
  'lib/views/notifications/notifications_view.dart',
  'lib/views/personal_tags_view.dart',
  'lib/views/photo_import_view.dart',
  'lib/views/quick_capture_view.dart',
  'lib/views/realtime/conflict_diff_view.dart',
  'lib/views/realtime/recipe_suggestion_view.dart',
  'lib/views/recipe_detail_view.dart',
  'lib/views/settings/mfa_settings_view.dart',
  'lib/views/skriv_sjalv_recept_view.dart',
  'lib/views/smart_import_view.dart',
  'lib/views/social/add_members_to_group_view.dart',
  'lib/views/social/collaborative_shopping/collaborative_shopping_actions.dart',
  'lib/views/social/create_shared_shopping_list_view.dart',
  'lib/views/social/group_detail/group_detail_app_bar.dart',
  'lib/views/social/menu_preview_view.dart',
  'lib/views/sync/sync_queue_view.dart',
  'lib/views/tag_detail_view.dart',
  'lib/views/unified_shopping_view.dart',
  'lib/views/veckomeny_view.dart',
  'lib/widgets/common/feedback_form_dialog.dart',
  'lib/widgets/common/image/fullscreen_image_viewer.dart',
  'lib/widgets/common/layout/layout_scaffolds.dart',
  'lib/widgets/common/routing/deferred_route_loader.dart',
  'lib/widgets/common/scaffolds/base_scaffold.dart',
  'lib/widgets/import/batch_import_preview.dart',
  'lib/widgets/menu/group_weekly_menu_widget.dart',
  'lib/widgets/messaging/chat_app_bar.dart',
  'lib/widgets/social/collaborative/components/collaborative_status_widgets.dart',
};

final _bar = RegExp(r'\bButleryTopBar\.(?:rot|undersida)\(');

const _theComponents = {
  'lib/widgets/common/butlery_top_bar.dart',
  'lib/widgets/common/layout/butlery_page.dart',
};

void main() {
  final builders = <String>{
    for (final dir in ['lib/views', 'lib/widgets', 'lib/core'])
      for (final entity in Directory(dir).listSync(recursive: true))
        if (entity is File && entity.path.endsWith('.dart'))
          if (!_theComponents.contains(entity.path.replaceAll(r'\', '/')))
            if (_bar.hasMatch(stripComments(entity.readAsStringSync())))
              entity.path.replaceAll(r'\', '/'),
  };

  test('no new file builds its own top bar', () {
    expect(
      builders.difference(_builtDirectly),
      isEmpty,
      reason: 'Use ButleryPage (rot, undersida) instead of ButleryTopBar.',
    );
  });

  test('the list of files that build their own bar has no stale line', () {
    expect(
      _builtDirectly.difference(builders),
      isEmpty,
      reason: 'These files moved onto ButleryPage: delete their lines.',
    );
  });
}
