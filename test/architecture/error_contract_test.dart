// P5-U00: the error contract (content-style-guide.md:87-97).
//
// A failure says what happened, what was kept when something was at stake,
// and what you can do, as a button that is never "OK"
// (content-style-guide.md:96; Komponentark v1:750). New code shows it with
// SnackBarUtils.showFailure or the InlineError widget; both always carry
// that structure.
//
// The legacy error channels (SnackBarUtils.showError,
// UtilityComponents.showErrorSnackbar, SnackbarWidgets.showErrorSnackbar and
// the context.showError extension) now show "Stäng" rather than OK, but they
// take one free-text line. Their calls are frozen here per file: a count may
// only go down, a file that is not listed may not start calling them, and a
// count that went down must be lowered here too. Package 7 removes the rest.
//
// Q-E7 (nattplan, package 5): an errorPrefix is shown to the user as the
// whole message (base_viewmodel.dart:183-198), so a hard-coded string there
// is untranslated user text. Those are frozen the same way.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Calls into the legacy one-line error channels, per file, on the day the
/// contract was introduced. Only shrinks.
const _legacyErrorCalls = <String, int>{
  'lib/core/base/base_action_handler.dart': 1,
  'lib/core/utils/snackbar_utils.dart': 1,
  'lib/views/account/data_export_view.dart': 2,
  'lib/views/auth_view.dart': 1,
  'lib/views/fran_sociala_medier_view.dart': 2,
  'lib/views/importera_fran_arkiv_view.dart': 2,
  'lib/views/menu_placement_view.dart': 1,
  'lib/views/messaging/chat_view/chat_message_stream.dart': 3,
  'lib/views/messaging/conversation_group_detail_view.dart': 4,
  'lib/views/messaging/conversations_list_view.dart': 3,
  'lib/views/messaging/create_group_conversation_view.dart': 1,
  'lib/views/mina_recept/selection_app_bar.dart': 2,
  'lib/views/mina_recept_view.dart': 2,
  'lib/views/onboarding/onboarding_view.dart': 2,
  'lib/views/personal_tags/personal_tag_dialogs.dart': 6,
  'lib/views/photo_import_view.dart': 1,
  'lib/views/quick_capture_view.dart': 1,
  'lib/views/realtime/conflict_diff_view.dart': 2,
  'lib/views/recipe_detail/handlers/recipe_management_handler.dart': 6,
  'lib/views/recipe_detail/handlers/recipe_menu_handler.dart': 1,
  'lib/views/recipe_detail/handlers/recipe_personal_tag_handler.dart': 1,
  'lib/views/recipe_detail/handlers/recipe_shopping_handler.dart': 5,
  'lib/views/recipe_detail/handlers/recipe_social_handler.dart': 4,
  'lib/views/recipe_detail/handlers/recipe_tagging_handler.dart': 2,
  'lib/views/recipe_detail/recipe_detail_actions.dart': 2,
  'lib/views/recipe_detail/recipe_detail_comments.dart': 1,
  'lib/views/recipe_detail/recipe_detail_metadata.dart': 2,
  'lib/views/recipe_detail/recipe_detail_shared_widgets.dart': 2,
  'lib/views/recipe_detail/recipe_detail_sharing_status.dart': 4,
  'lib/views/recipe_detail_view.dart': 2,
  'lib/views/settings/household_size_view.dart': 1,
  'lib/views/settings/notification_preferences_view.dart': 1,
  'lib/views/settings/settings_hub_view.dart': 2,
  'lib/views/settings/widgets/household_allergen_filter_tile.dart': 1,
  'lib/views/settings/widgets/household_allergen_sharing_tile.dart': 3,
  'lib/views/skriv_sjalv_recept_view.dart': 2,
  'lib/views/social/collaborative_shopping_view.dart': 1,
  'lib/views/social/friend_profile_view.dart': 2,
  'lib/views/social/friends_list/feed_tab.dart': 1,
  'lib/views/social/friends_list/group_invitation_card.dart': 3,
  'lib/views/social/friends_list/requests_tab.dart': 2,
  'lib/views/social/friends_list/search_result_card.dart': 6,
  'lib/views/social/friends_list_view.dart': 1,
  'lib/views/social/group_detail/group_detail_actions.dart': 5,
  'lib/views/social/group_detail/group_invitation_card.dart': 1,
  'lib/views/social/group_detail_view.dart': 3,
  'lib/views/social/menu_preview_view.dart': 2,
  'lib/views/social/shared_with_me/shared_content_actions.dart': 11,
  'lib/views/social/shared_with_me/shared_recipe_card.dart': 1,
  'lib/views/social/user_profile_edit/privacy_section.dart': 1,
  'lib/views/social/user_profile_edit_view.dart': 2,
  'lib/views/tag_detail_view.dart': 9,
  'lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart':
      1,
  'lib/views/unified_shopping/widgets/shopping_dialogs.dart': 1,
  'lib/views/unified_shopping_view.dart': 1,
  'lib/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart':
      1,
  'lib/widgets/common/dialogs/recipe_selection/group_recipe_sharing_dialog.dart':
      1,
  'lib/widgets/common/dialogs/unknown_ingredient_dialog.dart': 1,
  'lib/widgets/common/feedback_form_dialog.dart': 2,
  'lib/widgets/common/input/shopping_list_actions.dart': 4,
  'lib/widgets/common/input/shopping_list_selector.dart': 2,
  'lib/widgets/common/menu_persistence/menu_load_dialog.dart': 4,
  'lib/widgets/common/menu_persistence/menu_save_dialog.dart': 2,
  'lib/widgets/common/profile/handlers/auth_action_handler.dart': 1,
  'lib/widgets/common/profile/handlers/gdpr_consent_handler.dart': 3,
  'lib/widgets/common/universal_share_dialog.dart': 2,
  'lib/widgets/common/utility_components.dart': 2,
  'lib/widgets/image/image_picker_dialogs.dart': 1,
  'lib/widgets/image/image_picker_widget.dart': 1,
  'lib/widgets/legal/legal_contact_footer.dart': 1,
  'lib/widgets/menu/calendar_weekly_menu_widget.dart': 2,
  'lib/widgets/menu/group_menu_entry_button.dart': 1,
  'lib/widgets/menu/group_weekly_menu_widget.dart': 1,
  'lib/widgets/messaging/new_conversation_dialog.dart': 1,
  'lib/widgets/realtime/conflict_snackbar.dart': 1,
  'lib/widgets/recipe/recipe_draft_recovery_handler.dart': 2,
  'lib/widgets/recipe/recipe_image_picker.dart': 1,
  'lib/widgets/shopping/shopping_template_browser.dart': 1,
  'lib/widgets/social/block_user_action.dart': 1,
  'lib/widgets/social/groups/group_shared_content_section.dart': 6,
  'lib/widgets/social/ping_compose_sheet.dart': 1,
  'lib/widgets/social/report_content_dialog.dart': 2,
  'lib/widgets/tagging/rule_builder_sheet.dart': 3,
};

/// Hard-coded errorPrefix strings per file (Q-E7). Only shrinks.
///
/// Pinned after the package-5 phase-A merge: ingredient_search moved to
/// l10n, and the week menu's and the pantry's save messages
/// ("Veckan kunde inte sparas", "Kunde inte uppdatera objektet") now come
/// from AppLocale.current, which lowered both counts by two. The moderator
/// queue's and the feedback inbox's actions no longer set an errorPrefix:
/// their views show the refusal with showFailure.
const _errorPrefixLiterals = <String, int>{
  'lib/viewmodels/admin/metrics_tab_viewmodel.dart': 1,
  'lib/viewmodels/admin/ops_log_viewmodel.dart': 1,
  'lib/viewmodels/admin/parsing_details_viewmodel.dart': 1,
  'lib/viewmodels/family/family_rating_breakdown_viewmodel.dart': 1,
  'lib/viewmodels/family/family_rating_entry_viewmodel.dart': 2,
  'lib/viewmodels/family/min_familj_viewmodel.dart': 4,
  'lib/viewmodels/family/who_is_eating_viewmodel.dart': 1,
  'lib/viewmodels/menu/menu_placement_viewmodel.dart': 2,
  'lib/viewmodels/menu/weekly_menu_plan_viewmodel.dart': 11,
  'lib/viewmodels/pantry/pantry_viewmodel.dart': 7,
  'lib/viewmodels/settings/my_reports_viewmodel.dart': 1,
  'lib/viewmodels/shared_shopping_lists_viewmodel.dart': 1,
  'lib/viewmodels/social/activity_feed_viewmodel.dart': 2,
};

/// The one private inline-error copy left: the week menu's full-section
/// generation error, which is a state view with two actions, not a line.
/// ping_compose_sheet.dart's copy became InlineError.
const _privateInlineErrors = {'lib/widgets/menu/menu_content_widgets.dart'};

final _legacy = RegExp(
  r'(?:\bSnackBarUtils\s*\.\s*showError\s*\('
  r'|\bUtilityComponents\s*\.\s*showErrorSnackbar(?:WithRetry)?\s*\('
  r'|\bSnackbarWidgets\s*\.\s*showErrorSnackbar(?:WithRetry)?\s*\('
  r'|\bcontext\s*\.\s*showError\s*\()',
);

final _prefix = RegExp(r'''errorPrefix\s*:\s*['"]''');

final _okAction = RegExp(
  r'''(?:actionLabel\s*:\s*[\w.]*\bcommonOk\b|actionLabel\s*:\s*['"]OK['"]'''
  r'''|FailureAction\s*\.\s*named\s*\(\s*(?:[\w.]*\bcommonOk\b|['"]OK['"]))''',
);

final _inlineErrorCopy = RegExp(
  r'(?:class\s+_\w*InlineError\b|\b_build\w*InlineError\s*\()',
);

Iterable<String> _libFiles() sync* {
  for (final entity in Directory('lib').listSync(recursive: true)) {
    if (entity is! File || !entity.path.endsWith('.dart')) continue;
    final path = entity.path.replaceAll(r'\', '/');
    if (path.startsWith('lib/l10n/')) continue;
    yield path;
  }
}

/// The source without whole-line comments, so a doc comment that names a
/// call is not counted as one.
String _code(String path) => File(path)
    .readAsLinesSync()
    .where((line) => !line.trimLeft().startsWith('//'))
    .join('\n');

Map<String, int> _count(RegExp pattern) {
  final out = <String, int>{};
  for (final path in _libFiles()) {
    final n = pattern.allMatches(_code(path)).length;
    if (n > 0) out[path] = n;
  }
  return out;
}

List<String> _ratchet(Map<String, int> found, Map<String, int> frozen) {
  final problems = <String>[];
  for (final entry in found.entries) {
    final allowed = frozen[entry.key] ?? 0;
    if (entry.value > allowed) {
      problems.add('${entry.key}: ${entry.value} (frozen at $allowed)');
    }
  }
  for (final entry in frozen.entries) {
    final now = found[entry.key] ?? 0;
    if (now < entry.value) {
      problems.add(
        '${entry.key}: $now, lower the frozen count from ${entry.value}',
      );
    }
  }
  return problems;
}

void main() {
  test('no new call into the legacy one-line error channels (ratchet)', () {
    expect(
      _ratchet(_count(_legacy), _legacyErrorCalls),
      isEmpty,
      reason:
          'Show a failure with SnackBarUtils.showFailure(what:, preserved:, '
          'action:) or InlineError (content-style-guide.md:87-97).',
    );
  });

  test('no new hard-coded errorPrefix (Q-E7 ratchet)', () {
    expect(
      _ratchet(_count(_prefix), _errorPrefixLiterals),
      isEmpty,
      reason: 'An errorPrefix is user text: pass AppLocale.current.<key>.',
    );
  });

  test('no snackbar action is named OK', () {
    final offenders = <String>[];
    for (final path in _libFiles()) {
      if (_okAction.hasMatch(_code(path))) offenders.add(path);
    }
    expect(
      offenders,
      isEmpty,
      reason:
          'content-style-guide.md:96: a snackbar never has OK as its '
          'action; name what it does, or Stäng.',
    );
  });

  test('inline errors come from InlineError, not a private copy', () {
    final found = _count(_inlineErrorCopy).keys.toSet();
    expect(found.difference(_privateInlineErrors), isEmpty);
    expect(
      _privateInlineErrors.difference(found),
      isEmpty,
      reason: 'remove the entry that no longer has a private copy',
    );
  });
}
