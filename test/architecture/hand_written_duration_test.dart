// Motion is spoken in AppMotion's tokens (micro, standard, pulse). A duration
// typed out in a widget is a fourth speed nobody decided, so the files that
// still hold one are pinned by count and the number only falls. The scan
// covers every layer that draws or times UI; bootstrap, repositories and
// services that only time network calls are left out.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _handWritten = <String, int>{
  'lib/app/auth/auth_wrapper.dart': 1,
  'lib/app/butlery_app.dart': 1,
  'lib/core/base/base_action_handler.dart': 3,
  'lib/core/utils/captured_snackbars.dart': 3,
  'lib/core/utils/connectivity_check.dart': 6,
  'lib/core/utils/os_permission_helper.dart': 2,
  'lib/core/utils/retry_helper.dart': 6,
  'lib/core/utils/snackbar_utils.dart': 9,
  'lib/core/utils/undo_window.dart': 1,
  'lib/services/performance/optimized_image_loader.dart': 3,
  'lib/services/performance/performance_monitoring_service.dart': 3,
  'lib/views/account/data_export_helpers/download_web.dart': 2,
  'lib/views/account/data_export_view.dart': 1,
  'lib/views/auth/email_verification_view.dart': 3,
  'lib/views/auth/post_sign_in_navigation.dart': 2,
  'lib/views/file_import_view.dart': 1,
  'lib/views/messaging/chat_view/chat_action_handler.dart': 1,
  'lib/views/mina_recept_view.dart': 2,
  'lib/views/onboarding/onboarding_setup_page.dart': 1,
  'lib/views/onboarding/onboarding_view.dart': 3,
  'lib/views/recipe_detail/recipe_detail_comments.dart': 1,
  'lib/views/social/group_detail_view.dart': 1,
  'lib/views/social/menu_preview_view.dart': 2,
  'lib/views/social/shared_with_me/shared_content_actions.dart': 3,
  'lib/views/social/user_profile_edit_view.dart': 1,
  'lib/views/sync/sync_queue_view.dart': 1,
  'lib/widgets/common/animations/animated_list_item.dart': 3,
  'lib/widgets/common/brand/start_splash.dart': 1,
  'lib/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart':
      1,
  'lib/widgets/common/dialogs/recipe_selection/group_recipe_sharing_dialog.dart':
      1,
  'lib/widgets/common/dialogs/session_timeout_warning_dialog.dart': 1,
  'lib/widgets/common/first_recipe_celebration_overlay.dart': 1,
  'lib/widgets/common/icons/butlery_expansion_chevron.dart': 1,
  'lib/widgets/common/profile/utils/result_displayer.dart': 1,
  'lib/widgets/common/state/delayed_skeleton.dart': 1,
  'lib/widgets/image/avatar_image_widget.dart': 1,
  'lib/widgets/legal/legal_document.dart': 1,
  'lib/widgets/menu/calendar/calendar_drag.dart': 2,
  'lib/widgets/menu/group_menu_entry_button.dart': 1,
  'lib/widgets/menu/menu_list_rows.dart': 1,
  'lib/widgets/menu/veckomeny_selection_widgets.dart': 1,
  'lib/widgets/onboarding/onboarding_parts.dart': 1,
  'lib/widgets/realtime/conflict_snackbar.dart': 1,
};

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'(?<!:)//[^\n]*'), '');

final _literal = RegExp(r'\bDuration\(\s*(milliseconds|seconds)\s*:');

Map<String, int> _counts() {
  final counts = <String, int>{};
  for (final root in [
    'lib/views',
    'lib/widgets',
    'lib/app',
    'lib/core/base',
    'lib/core/utils',
    'lib/services/performance',
  ]) {
    for (final file in Directory(root).listSync(recursive: true)) {
      if (file is! File || !file.path.endsWith('.dart')) continue;
      final path = file.path.replaceAll(r'\', '/');
      final n = _literal.allMatches(_code(path)).length;
      if (n > 0) counts[path] = n;
    }
  }
  return counts;
}

void main() {
  test('no widget writes a new duration by hand', () {
    expect(_counts(), _handWritten);
  });
}
