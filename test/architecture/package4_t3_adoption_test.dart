// Package 4, track T3 (P4-U08, U09, U10, U11, U16): the week menu, the
// shopping list, the import family, family and tags adopt the design system.
//
// B-18 (beslutslogg.md:25) and produktregler.md:163, :304: loading is the
// plate line plus text, never a spinner, a sliding bar or the animated pea
// pod. ux-beslut.json D-03: generation has no long-wait state and no
// "Fortsätt i bakgrunden". B-45 (beslutslogg.md:52): one top bar, so these
// views draw ButleryTopBar. PQ-09 = A (produktbeslut-2026-09-23.json): a view
// never builds its own SnackBar; every snackbar is the ink snackbar from
// SnackBarUtils.
//
// This test reddens when one of those comes back into a file this track
// cleaned.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Files whose progress this track moved to the plate line.
const _plateLineFiles = [
  'lib/widgets/menu/veckomeny_selection_widgets.dart',
  'lib/widgets/menu/menu_vote_card.dart',
  'lib/views/unified_shopping/widgets/shopping_list_content.dart',
  'lib/views/personal_tags/personal_tag_widgets.dart',
  'lib/widgets/tagging/tag_result_display.dart',
  'lib/widgets/import/import_progress_widget.dart',
  'lib/views/smart_import/import_widgets.dart',
  'lib/views/import_via_url_view.dart',
  'lib/views/file_import_view.dart',
  'lib/widgets/import/voice_section_card.dart',
  'lib/widgets/common/menu_persistence/menu_load_dialog.dart',
  'lib/widgets/common/menu_persistence/menu_save_dialog.dart',
  'lib/widgets/common/dialogs/menu_selection_dialog.dart',
  'lib/widgets/common/dialogs/shopping_list_selection_dialog.dart',
  'lib/widgets/common/dialogs/group_shopping_list_selection_dialog.dart',
  'lib/widgets/shopping/shopping_template_browser.dart',
];

/// Views this track moved onto the canonical top bar.
const _topBarFiles = [
  'lib/views/veckomeny_view.dart',
  'lib/views/unified_shopping_view.dart',
  'lib/widgets/menu/group_weekly_menu_widget.dart',
  'lib/views/smart_import_view.dart',
  'lib/views/file_import_view.dart',
  'lib/views/fran_sociala_medier_view.dart',
  'lib/views/importera_fran_arkiv_view.dart',
  'lib/views/voice_import_view.dart',
  'lib/widgets/import/batch_import_preview.dart',
  'lib/views/family/min_familj_view.dart',
  'lib/views/family/family_member_form_view.dart',
  'lib/views/family/family_rating_entry_view.dart',
  'lib/views/personal_tags_view.dart',
  'lib/views/tag_detail_view.dart',
  'lib/views/ingredient_search/ingredient_search_view.dart',
];

/// Files whose own snackbars this track moved to SnackBarUtils. The shopping
/// list's category-move receipt (shopping_list_content.dart) belongs to
/// P3-U09 and is not in this list.
const _inkSnackbarFiles = [
  'lib/widgets/common/menu_persistence/menu_load_dialog.dart',
  'lib/widgets/common/menu_persistence/menu_save_dialog.dart',
  'lib/views/unified_shopping/widgets/dialogs/shopping_leave_list_action.dart',
  'lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart',
  'lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart',
  'lib/views/unified_shopping/widgets/shopping_dialogs.dart',
  'lib/widgets/shopping/shopping_template_browser.dart',
  'lib/views/photo_import_view.dart',
  'lib/views/tag_detail_view.dart',
  'lib/widgets/tagging/tag_editor_dialog.dart',
  'lib/widgets/common/dialogs/unknown_ingredient_dialog.dart',
];

String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//.*'), '');

List<String> _offenders(List<String> files, RegExp pattern) => [
  for (final path in files)
    if (pattern.hasMatch(_code(path))) path,
];

void main() {
  test('no spinner, sliding bar or pea pod in the cleaned files (B-18)', () {
    expect(
      _offenders(
        _plateLineFiles,
        RegExp(
          r'\b(CircularProgressIndicator|LinearProgressIndicator|'
          r'CupertinoActivityIndicator|LoadingIndicator|PeaLoadingOverlay|'
          r'PeaLoadingAnimation)\b',
        ),
      ),
      isEmpty,
    );
  });

  test('week generation offers no "continue in the background" (D-03)', () {
    final code = _code('lib/widgets/menu/veckomeny_selection_widgets.dart');
    expect(code.contains('pea_loading_animation'), isFalse);
    expect(RegExp('[Bb]ackground').hasMatch(code), isFalse);
  });

  test('the views draw ButleryTopBar only (B-45)', () {
    expect(
      _offenders(
        _topBarFiles,
        RegExp(
          r'\b(AdaptiveAppBar|ButleryHeader|MainViewHeader)\s*\(|'
          r'[^\w.]AppBar\s*\(',
        ),
      ),
      isEmpty,
    );
  });

  test('views never build their own SnackBar (PQ-09 = A)', () {
    expect(
      _offenders(_inkSnackbarFiles, RegExp(r'[^\w.]SnackBar\s*\(')),
      isEmpty,
    );
  });

  test('the radio rows carry the focus ring and 48 dp (P4-U10, P4-U16)', () {
    for (final path in [
      'lib/widgets/common/dialogs/share_selection/shopping_list_selection_dialog.dart',
      'lib/views/personal_tags/personal_tag_bulk_dialogs.dart',
    ]) {
      final code = _code(path);
      expect(
        RegExp(
          r'ButleryControlFocus\(\s*child:\s*RadioListTile',
        ).hasMatch(code),
        isTrue,
        reason: '$path must wrap each RadioListTile in ButleryControlFocus',
      );
    }
  });
}
